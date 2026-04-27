import SwiftUI

struct TagCorrelationDetailSheet: View {
    let correlation: TagCorrelation
    @State private var selectedDetent: PresentationDetent = .fraction(0.85)

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        scoreImpactHero
                        if !correlation.metricImpacts.isEmpty {
                            metricImpactsSection
                        }
                        footerNote
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("\"\(correlation.tag.name)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
        }
        .presentationDetents([.fraction(0.85), .large], selection: $selectedDetent)
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }

    // MARK: - Score hero

    private var scoreImpactHero: some View {
        let delta = correlation.scoreDelta
        let color: Color = delta < 0 ? .red.opacity(0.85) : DS.purple

        return VStack(spacing: 8) {
            Text("Sleep Score Impact")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(delta >= 0 ? "+" : "")\(Int(delta.rounded()))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text("pts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
            }

            HStack(spacing: 16) {
                statPill(label: "Tagged avg", value: "\(Int(correlation.avgScoreTagged.rounded()))")
                Text("vs")
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                statPill(label: "Baseline avg", value: "\(Int(correlation.avgScoreBaseline.rounded()))")
            }

            Text("\(correlation.taggedNights) tagged nights analyzed")
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .dsCard(20)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
    }

    // MARK: - Metric impacts

    private var metricImpactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metric Changes")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            VStack(spacing: 2) {
                ForEach(correlation.metricImpacts.prefix(8)) { impact in
                    MetricImpactRow(impact: impact)
                }
            }
            .dsCard(16)
        }
    }

    private var footerNote: some View {
        Text("Based on \(correlation.taggedNights) nights tagged \"\(correlation.tag.name)\" vs \(Int(correlation.avgScoreBaseline.rounded())) avg on untagged nights. Correlations may not indicate causation.")
            .font(.caption2)
            .foregroundStyle(DS.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

// MARK: - MetricImpactRow

private struct MetricImpactRow: View {
    let impact: MetricImpact

    private var deltaColor: Color {
        impact.isHarmful ? .red.opacity(0.8) : DS.purple
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(impact.metricName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                HStack(spacing: 4) {
                    Text(formattedValue(impact.baselineAvg))
                        .foregroundStyle(DS.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.textTertiary)
                    Text(formattedValue(impact.taggedAvg))
                        .foregroundStyle(DS.textPrimary)
                }
                .font(.system(size: 12))
            }
            Spacer(minLength: 0)
            deltaLabel
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var deltaLabel: some View {
        let delta = impact.delta
        let sign = delta >= 0 ? "+" : ""
        return VStack(alignment: .trailing, spacing: 1) {
            Text("\(sign)\(formattedDelta(delta))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(deltaColor)
                .monospacedDigit()
            Text(impact.unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
    }

    private func formattedValue(_ v: Double) -> String {
        switch impact.unit {
        case "hr":
            let h = Int(v); let m = Int((v - Double(h)) * 60)
            return m == 0 ? "\(h)h" : "\(h)h\(m)m"
        case "br/min":
            return String(format: "%.1f", v)
        case "%":
            return String(format: "%.1f%%", v)
        default:
            return "\(Int(v.rounded()))"
        }
    }

    private func formattedDelta(_ v: Double) -> String {
        switch impact.unit {
        case "br/min": return String(format: "%.1f", abs(v))
        case "%":      return String(format: "%.1f", abs(v))
        default:       return "\(Int(abs(v).rounded()))"
        }
    }
}
