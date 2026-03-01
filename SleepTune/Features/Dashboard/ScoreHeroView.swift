import SwiftUI

struct ScoreHeroView: View {
    let summary: SleepScoreSummary
    let date: Date
    let bins: [DopplerBin]
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void

    private var scoreInt: Int { Int(summary.score.rounded()) }
    private var scoreColor: Color { DS.scoreColor(for: summary.score) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

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
            Text("\(scoreInt)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())

            Text(DS.scoreLabel(for: summary.score))
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(scoreColor.opacity(0.65))
        }
        .animation(.spring(duration: 0.5), value: scoreInt)
    }

    private var subScorePills: some View {
        HStack(spacing: 8) {
            ScorePill(label: "Sleep", score: summary.sleepScore, color: DS.sleepArc)
            ScorePill(label: "Recovery", score: summary.recoveryScore, color: DS.recoveryArc)
        }
    }
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
