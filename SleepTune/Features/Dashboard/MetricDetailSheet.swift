import SwiftUI

struct MetricDetailSheet: View {
    let metric: MetricContribution
    @State private var selectedDetent: PresentationDetent = .fraction(0.9)

    // The actual scoring reference — p75/p25/min/avg depending on metric.
    private var targetValue: Double? {
        guard let stats = metric.stats else { return nil }
        return effectiveBaseline(name: metric.name, stats: stats)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        currentValueSection
                        if let stats = metric.stats {
                            rangeSection(stats: stats)
                            statsGrid(stats: stats)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                }
            }
        }
        .presentationDetents([.fraction(0.9), .large], selection: $selectedDetent)
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }

    // MARK: - Current value

    private var currentValueSection: some View {
        VStack(spacing: 6) {
            Text("Tonight")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            Text(metric.formattedValue)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(currentValueColor)
                .monospacedDigit()

            if let sub = contextLabel {
                Text(sub)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(DS.border, lineWidth: 0.5))
    }

    // MARK: - 30-Day Range (unified: bar + min/avg/target/max labels)

    private func rangeSection(stats: MetricStats) -> some View {
        let target = targetValue ?? stats.avg
        let targetDiffersFromAvg = abs(target - stats.avg) > 0.01 * max(abs(stats.avg), 1)
        let accent = rangeAccentColor(stats: stats)

        return VStack(alignment: .leading, spacing: 14) {
            Text("30-Day Range")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(DS.surfaceHigh)
                        .frame(height: 8)

                    // Fill up to tonight's position
                    let tonightPos = stats.normalizedPosition(of: metric.rawValue)
                    Capsule()
                        .fill(accent.opacity(0.7))
                        .frame(width: max(w * tonightPos, 8), height: 8)

                    // Avg tick (gray, shorter) — only when target differs
                    if targetDiffersFromAvg {
                        let avgX = w * stats.normalizedAvg
                        RoundedRectangle(cornerRadius: 1)
                            .fill(DS.textSecondary.opacity(0.6))
                            .frame(width: 2, height: 12)
                            .offset(x: avgX - 1)
                    }

                    // Target tick (purple, taller)
                    let targetX = w * stats.normalizedPosition(of: target)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DS.purple)
                        .frame(width: 2, height: 18)
                        .offset(x: targetX - 1)

                    // Tonight marker
                    Circle()
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(DS.bg, lineWidth: 2))
                        .offset(x: max(w * tonightPos - 7, 0))
                }
            }
            .frame(height: 18)

            // Position the target label on the same side of avg as the target tick on the bar.
            // For higher-is-better metrics target lives to the right of avg (low · avg · target · high).
            // For lower-is-better metrics it lives to the left (low · target · avg · high).
            // When target collapses onto min/avg/max, drop to 3 labels and color that label as the target.
            let lowStr    = formatted(value: stats.min, unit: metric.unit, metricName: metric.name)
            let avgStr    = formatted(value: stats.avg, unit: metric.unit, metricName: metric.name)
            let highStr   = formatted(value: stats.max, unit: metric.unit, metricName: metric.name)
            let targetStr = formatted(value: target,    unit: metric.unit, metricName: metric.name)
            let targetIsAtMin = abs(target - stats.min) <= 0.01 * max(abs(stats.min), 1)
            let targetIsAtMax = abs(target - stats.max) <= 0.01 * max(abs(stats.max), 1)

            if !targetDiffersFromAvg {
                // 3-label row when target == avg — avg label IS the target.
                HStack {
                    rangeLabel(lowStr, subtitle: "30d low")
                    Spacer()
                    rangeLabel(avgStr, subtitle: "30d target", isTarget: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                    rangeLabel(highStr, subtitle: "30d high")
                }
            } else if targetIsAtMin {
                // 3-label row when target == min (e.g. Lowest Overnight HR).
                HStack {
                    rangeLabel(lowStr, subtitle: "30d target", isTarget: true)
                    Spacer()
                    rangeLabel(avgStr, subtitle: "30d avg")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                    rangeLabel(highStr, subtitle: "30d high")
                }
            } else if targetIsAtMax {
                // 3-label row when target == max.
                HStack {
                    rangeLabel(lowStr, subtitle: "30d low")
                    Spacer()
                    rangeLabel(avgStr, subtitle: "30d avg")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                    rangeLabel(highStr, subtitle: "30d target", isTarget: true)
                }
            } else if target < stats.avg {
                // 4-label row, lower-is-better: low · target · avg · high.
                HStack(spacing: 4) {
                    rangeLabel(lowStr,    subtitle: "30d low")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    rangeLabel(targetStr, subtitle: "30d target", isTarget: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                    rangeLabel(avgStr,    subtitle: "30d avg")
                        .frame(maxWidth: .infinity, alignment: .center)
                    rangeLabel(highStr,   subtitle: "30d high")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                // 4-label row, higher-is-better: low · avg · target · high.
                HStack(spacing: 4) {
                    rangeLabel(lowStr,    subtitle: "30d low")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    rangeLabel(avgStr,    subtitle: "30d avg")
                        .frame(maxWidth: .infinity, alignment: .center)
                    rangeLabel(targetStr, subtitle: "30d target", isTarget: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                    rangeLabel(highStr,   subtitle: "30d high")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
    }

    private func rangeLabel(_ value: String, subtitle: String, isTarget: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isTarget ? DS.purple : DS.textPrimary)
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(isTarget ? DS.purple.opacity(0.7) : DS.textTertiary)
        }
    }

    // MARK: - Stats grid

    private func statsGrid(stats: MetricStats) -> some View {
        let target = targetValue ?? stats.avg
        let deltaVsTarget = metric.rawValue - target

        return HStack(spacing: 10) {
            statCell(
                value: formatted(value: deltaVsTarget, unit: metric.unit, signed: true, metricName: metric.name),
                label: "vs target",
                valueColor: deltaColor(delta: deltaVsTarget)
            )
            statCell(
                value: "\(stats.count)",
                label: "nights tracked",
                valueColor: DS.textPrimary
            )
            statCell(
                value: pointsText,
                label: "pts",
                valueColor: pointColor
            )
        }
    }

    private func statCell(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.border, lineWidth: 0.5))
    }

    // MARK: - Helpers

    private var currentValueColor: Color {
        if let stats = metric.stats {
            if isAtOrBetterThanAverage(avg: stats.avg) { return DS.green }
            return metric.normalizedScore >= 50
                ? Color(red: 1.0, green: 0.62, blue: 0.04)
                : Color(red: 1.0, green: 0.27, blue: 0.23)
        }
        let s = metric.normalizedScore
        if s >= 85 { return DS.green }
        if s >= 70 { return DS.purple }
        if s >= 55 { return Color(red: 1.0, green: 0.62, blue: 0.04) }
        return Color(red: 1.0, green: 0.27, blue: 0.23)
    }

    private var contextLabel: String? {
        if let hint = metric.hint { return hint }
        guard let stats = metric.stats else { return nil }
        let ref = targetValue ?? stats.avg
        let refLabel = (abs((targetValue ?? stats.avg) - stats.avg) > 0.01 * max(abs(stats.avg), 1)) ? "target" : "avg"
        let delta = metric.rawValue - ref
        let threshold = displayPrecisionThreshold(for: metric.unit, metricName: metric.name)
        guard abs(delta) >= threshold else { return nil }
        let deltaStr = formatted(value: delta, unit: metric.unit, signed: true, metricName: metric.name)
        return "\(deltaStr) \(delta > 0 ? "above" : "below") your \(refLabel)"
    }

    private func rangeAccentColor(stats: MetricStats) -> Color {
        isAtOrBetterThanAverage(avg: stats.avg) ? DS.green : Color(red: 0.90, green: 0.76, blue: 0.24)
    }

    private func isAtOrBetterThanAverage(avg: Double) -> Bool {
        let delta = metric.rawValue - avg
        let threshold = baselineThreshold(for: metric.unit)
        if abs(delta) < threshold { return true }
        return metric.lowerIsBetter ? metric.rawValue < avg : metric.rawValue > avg
    }

    private func baselineThreshold(for unit: String) -> Double {
        displayPrecisionThreshold(for: unit, metricName: metric.name)
    }

    private func deltaColor(delta: Double) -> Color {
        let threshold = baselineThreshold(for: metric.unit)
        if abs(delta) < threshold { return DS.green }
        if metric.lowerIsBetter {
            return delta <= 0 ? DS.green : Color(red: 1.0, green: 0.62, blue: 0.04)
        }
        return delta >= 0 ? DS.green : Color(red: 1.0, green: 0.62, blue: 0.04)
    }

    private var pointsText: String {
        let tonight = metric.displayedPointContribution.formatted(.number.precision(.fractionLength(1)))
        let max = metric.displayedMaxPointContribution.formatted(.number.precision(.fractionLength(1)))
        return "\(tonight)/\(max)"
    }

    private var pointColor: Color {
        metric.normalizedScore >= 75 ? DS.green : Color(red: 1.0, green: 0.62, blue: 0.04)
    }
}

// MARK: - Signed formatting helper

private func formatted(value: Double, unit: String, signed: Bool, metricName: String? = nil) -> String {
    let absoluteValue = abs(value)
    let prefix: String
    if signed {
        prefix = value > 0 ? "+" : value < 0 ? "-" : ""
    } else {
        prefix = ""
    }

    switch unit {
    case "hr":
        let mins = Int((absoluteValue * 60).rounded())
        return "\(prefix)\(mins)m"
    case "%":
        let precision = metricName == "Blood Oxygen" ? 1 : 0
        return "\(prefix)\(absoluteValue.formatted(.number.precision(.fractionLength(precision))))%"
    case "fraction":
        return "\(prefix)\(absoluteValue.formatted(.number.precision(.fractionLength(2))))"
    case "ms", "bpm":
        // HR / HRV to 1 decimal for a more precise readout (e.g. 40.4 bpm).
        return "\(prefix)\(absoluteValue.formatted(.number.precision(.fractionLength(1)))) \(unit)"
    case "min", "x", "cycles", "events":
        return "\(prefix)\(Int(absoluteValue.rounded())) \(unit)"
    default:
        return "\(prefix)\(absoluteValue.formatted(.number.precision(.fractionLength(1)))) \(unit)"
    }
}

// MARK: - Close button

struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 28, height: 28)
                .background(DS.surface, in: Circle())
                .overlay(Circle().strokeBorder(DS.border, lineWidth: 0.5))
        }
    }
}
