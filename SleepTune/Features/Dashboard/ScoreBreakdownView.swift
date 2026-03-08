import SwiftUI

struct ScoreBreakdownView: View {
    let summary: SleepScoreSummary
    let indicators: [SleepIndicator]

    var body: some View {
        HStack(spacing: 10) {
            BreakdownCard(
                title: "Sleep",
                iconName: "moon.fill",
                score: summary.sleepScore,
                accentColor: DS.sleepArc,
                metrics: metrics(for: .sleepArchitecture)
            )
            .frame(maxWidth: .infinity)

            BreakdownCard(
                title: "Recovery",
                iconName: "heart.fill",
                score: summary.recoveryScore,
                accentColor: DS.recoveryArc,
                metrics: metrics(for: .recovery)
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // Top-N metrics per card, ordered by registry weight descending (tiebreak: name).
    private static let cardLimit = 4

    private func metrics(for category: SleepIndicatorCategory) -> [CardMetric] {
        // Sort by weight desc (alpha tiebreak), map to available indicators only,
        // then take the first cardLimit that actually exist.
        let sorted = MetricRegistry.scoredMetrics(in: category)
            .sorted {
                if $0.weight != $1.weight { return $0.weight > $1.weight }
                return $0.name < $1.name
            }

        return sorted
            .compactMap { def -> CardMetric? in
                guard let indicator = indicators.first(where: { $0.name == def.name }) else { return nil }
                return CardMetric(name: shortName(def.name), value: formatted(indicator), source: indicator.source)
            }
            .prefix(Self.cardLimit)
            .map { $0 }
    }

    /// Shorter display names for the compact card layout.
    private func shortName(_ name: String) -> String {
        switch name {
        case "Sleep Duration":      return "Duration"
        case "Bedtime Consistency":  return "Bedtime"
        case "Overnight Heart Rate": return "Avg HR"
        case "Lowest Overnight HR": return "Lowest HR"
        case "Time to Lowest HR":   return "Min HR timing"
        case "Respiratory Rate":    return "Resp rate"
        default:                    return name
        }
    }

    private func formatted(_ i: SleepIndicator) -> String {
        let v = i.value
        switch i.unit {
        case "hr":       return "\(Int(v))h \(Int((v - Double(Int(v))) * 60))m"
        case "min":      return "\(Int(v.rounded()))m"
        case "fraction": return String(format: "%.2f", v)
        case "bedtime":
            let minutesFromMidnight = (Int((v * 60).rounded()) + 12 * 60) % (24 * 60)
            let h = minutesFromMidnight / 60; let m = minutesFromMidnight % 60
            let ampm = h < 12 ? "AM" : "PM"
            let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
            return String(format: "%d:%02d %@", displayH, m, ampm)
        case "%", "ms", "bpm": return "\(Int(v.rounded())) \(i.unit)"
        case "br/min":
            return "\(v.formatted(.number.precision(.fractionLength(1)))) \(i.unit)"
        default:         return String(format: "%.1f \(i.unit)", v)
        }
    }
}

struct CardMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let source: SleepIndicatorSource
}

struct BreakdownCard: View {
    let title: String
    let iconName: String
    let score: Double
    let accentColor: Color
    let metrics: [CardMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .fixedSize()
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                Text("\(Int(score.rounded()))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(accentColor)
                    .fixedSize()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(accentColor.opacity(0.10)).frame(height: 4)
                    Capsule().fill(accentColor)
                        .frame(width: max(geo.size.width * score / 100, 4), height: 4)
                }
            }
            .frame(height: 4)

            VStack(spacing: 8) {
                if metrics.isEmpty {
                    Text("No data")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                } else {
                    ForEach(metrics) { m in
                        HStack {
                            Text(m.name)
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(m.value)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.textPrimary)
                        }
                    }
                }
            }

        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DS.border, lineWidth: 0.5))
    }
}
