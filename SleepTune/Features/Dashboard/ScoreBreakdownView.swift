import SwiftUI

struct ScoreBreakdownView: View {
    let summary: SleepScoreSummary
    let indicators: [SleepIndicator]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                BreakdownCard(
                    title: "Sleep",
                    iconName: "moon.fill",
                    score: summary.sleepScore,
                    accentColor: DS.sleepArc,
                    metrics: metrics(for: .sleepArchitecture)
                )
                BreakdownCard(
                    title: "Recovery",
                    iconName: "heart.fill",
                    score: summary.recoveryScore,
                    accentColor: DS.recoveryArc,
                    metrics: metrics(for: .recovery)
                )
            }
            .padding(.horizontal)
        }
    }

    private func metrics(for category: SleepIndicatorCategory) -> [CardMetric] {
        indicators
            .filter { $0.category == category && $0.range != nil }
            .prefix(4)
            .map { CardMetric(name: $0.name, value: formatted($0), source: $0.source) }
    }

    private func formatted(_ i: SleepIndicator) -> String {
        let v = i.value
        switch i.unit {
        case "hr":
            return "\(Int(v))h \(Int((v - Double(Int(v))) * 60))m"
        case "%", "ms", "bpm", "br/min":
            return "\(Int(v.rounded())) \(i.unit)"
        default:
            return String(format: "%.1f \(i.unit)", v)
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
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                }
                Spacer()
                Text("\(Int(score.rounded()))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(accentColor)
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
        .frame(width: 190)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DS.border, lineWidth: 0.5))
    }
}
