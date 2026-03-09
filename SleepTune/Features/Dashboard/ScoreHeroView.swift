import SwiftUI
import UIKit

struct ScoreHeroView: View {
    let summary: SleepScoreSummary
    let date: Date
    let bins: [DopplerBin]
    /// Deviation of last night's avg HR from 30-day personal baseline, in bpm.
    /// Negative = better than baseline, positive = elevated (worse).
    let hrDeviation: Double
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    var isLoading: Bool = false
    private let daySwipeThreshold: CGFloat = 56

    private var scoreInt: Int { Int(summary.score.rounded()) }
    private var scoreColor: Color { DS.scoreColor(for: summary.score) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// Maps hrDeviation → ambient glow color.
    /// -5+ bpm below baseline → deep cool blue
    ///  0  = neutral           → dim purple
    /// +5  bpm above baseline  → amber
    /// +10 bpm above baseline  → hot orange-red
    private var hrAmbientColor: Color {
        let stops: [(Double, Color)] = [
            (-5.0, Color(red: 0.10, green: 0.35, blue: 0.95)), // cool blue (great)
            ( 0.0, Color(red: 0.30, green: 0.22, blue: 0.65)), // dim purple (baseline)
            ( 5.0, Color(red: 1.00, green: 0.50, blue: 0.04)), // amber (elevated)
            (10.0, Color(red: 1.00, green: 0.18, blue: 0.10)), // red-orange (bad)
        ]
        let clamped = max(-5, min(10, hrDeviation))
        for i in 0..<(stops.count - 1) {
            let (t0, c0) = stops[i]
            let (t1, c1) = stops[i + 1]
            if clamped <= t1 {
                let frac = (clamped - t0) / (t1 - t0)
                return lerpHeroColor(c0, c1, t: frac)
            }
        }
        return stops.last!.1
    }

    /// Glow intensity scales with deviation magnitude; subtle at baseline.
    private var hrGlowOpacity: Double {
        let magnitude = abs(hrDeviation)
        return min(0.18 + magnitude * 0.022, 0.45)
    }

    var body: some View {
        VStack(spacing: 0) {
            dateNavRow
                .padding(.bottom, 24)

            // Score number
            scoreLabel
                .padding(.bottom, 20)

            // Doppler Stripe — full width hero
            DopplerStripeView(bins: bins, score: summary.score, height: 36)

            // Sub-score pills
            subScorePills
                .padding(.top, 16)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded(handleDaySwipe)
        )
    }

    // MARK: - Subviews

    private var dateNavRow: some View {
        HStack {
            Button(action: onPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(DS.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DS.border, lineWidth: 0.5))
            }

            Spacer()

            VStack(spacing: 1) {
                Text(date, format: .dateTime.weekday(.wide))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }

            Spacer()

            Button(action: onNextDay) {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isToday ? DS.textTertiary : DS.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(DS.surface, in: Circle())
                    .overlay(Circle().strokeBorder(DS.border, lineWidth: 0.5))
            }
            .disabled(isToday)
        }
    }

    private var scoreLabel: some View {
        VStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .tint(DS.purple)
                    .scaleEffect(1.4)
                    .frame(height: 80)
            } else {
                Text("\(scoreInt)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText())
            }

            Text(isLoading ? "Calculating…" : DS.scoreLabel(for: summary.score))
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(isLoading ? DS.textTertiary : scoreColor.opacity(0.65))
        }
        .animation(.spring(duration: 0.5), value: scoreInt)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }

    private var subScorePills: some View {
        HStack(spacing: 8) {
            ScorePill(label: "Sleep", score: summary.sleepScore, color: DS.sleepArc)
            ScorePill(label: "Recovery", score: summary.recoveryScore, color: DS.recoveryArc)
        }
    }

    private func handleDaySwipe(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        guard abs(horizontalDistance) > abs(verticalDistance) else { return }
        guard abs(horizontalDistance) >= daySwipeThreshold else { return }

        if horizontalDistance < 0 {
            if !isToday {
                onNextDay()
            }
        } else {
            onPreviousDay()
        }
    }
}

// MARK: - HR Ambient Color Lerp

private func lerpHeroColor(_ a: Color, _ b: Color, t: Double) -> Color {
    let ta = max(0, min(1, t))
    let ra = 1 - ta
    var (r0, g0, b0, a0): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    UIKit.UIColor(a).getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
    UIKit.UIColor(b).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    return Color(
        red:   Double(r0 * ra + r1 * ta),
        green: Double(g0 * ra + g1 * ta),
        blue:  Double(b0 * ra + b1 * ta)
    )
}

// MARK: - ScorePill

struct ScorePill: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(score.rounded()))")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.border, lineWidth: 0.5))
    }
}
