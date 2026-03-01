import SwiftUI

// MARK: - Metric Contribution Model

struct MetricContribution: Identifiable {
    let id: String
    let name: String
    let value: String
    let normalizedScore: Double     // 0–100, already inverted for "lower is better"
    let pointContribution: Double   // contribution to overall score in pts
    let maxPointContribution: Double
    let rawValue: Double
    let unit: String
    let monthlyAverage: Double?
    let isInverted: Bool
    let category: SleepIndicatorCategory
}

// MARK: - Main View

struct MetricBreakdownView: View {
    let indicators: [SleepIndicator]
    let weights: SleepScoreWeights
    var monthlyAverages: [String: Double] = [:]

    @State private var expandedCategory: SleepIndicatorCategory? = nil

    private var sections: [(SleepIndicatorCategory, Color, [MetricContribution])] {
        [
            (.sleepArchitecture, DS.sleepArc,    contributions(for: .sleepArchitecture)),
            (.recovery,          DS.recoveryArc, contributions(for: .recovery))
        ]
    }

    var body: some View {
        VStack(spacing: 10) {
            DSSectionHeader(title: "Score Breakdown", trailing: "Impact")
                .padding(.horizontal, 2)

            VStack(spacing: 2) {
                ForEach(sections, id: \.0) { category, color, metrics in
                    MetricCategorySection(
                        category: category,
                        accentColor: color,
                        metrics: metrics,
                        isExpanded: expandedCategory == category,
                        onTap: {
                            withAnimation(.spring(duration: 0.35)) {
                                expandedCategory = (expandedCategory == category) ? nil : category
                            }
                        }
                    )
                }
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
        }
    }

    // MARK: - Score Math

    private func contributions(for category: SleepIndicatorCategory) -> [MetricContribution] {
        let categoryIndicators = indicators.filter { $0.category == category && $0.range != nil }
        let categoryWeight = topLevelWeight(for: category)

        return categoryIndicators.map { indicator in
            let subWeight = subWeight(for: indicator.name, category: category)
            let isInv = isInverted(indicator.name)

            let normalized: Double = scoreMetric(
                name: indicator.name,
                value: indicator.value,
                monthlyAvg: monthlyAverages[indicator.name]
            ) ?? 0

            let maxPts = subWeight * categoryWeight * 100
            let actualPts = normalized * maxPts

            return MetricContribution(
                id: indicator.name,
                name: indicator.name,
                value: formatted(indicator),
                normalizedScore: normalized * 100,
                pointContribution: actualPts,
                maxPointContribution: maxPts,
                rawValue: indicator.value,
                unit: indicator.unit,
                monthlyAverage: monthlyAverages[indicator.name],
                isInverted: isInv,
                category: category
            )
        }
        .sorted { $0.pointContribution > $1.pointContribution }
    }

    private func topLevelWeight(for category: SleepIndicatorCategory) -> Double {
        switch category {
        case .sleepArchitecture: return weights.architectureWeight
        case .recovery:          return weights.recoveryWeight
        default:                 return 0
        }
    }

    private func subWeight(for name: String, category: SleepIndicatorCategory) -> Double {
        switch category {
        case .sleepArchitecture:
            switch name {
            case "Sleep Duration":   return weights.duration
            case "Sleep Efficiency": return weights.efficiency
            case "Sleep Latency":    return weights.latency
            case "REM Sleep":        return weights.remPercent
            case "Deep Sleep":       return weights.deepPercent
            default:                 return 0.05
            }
        case .recovery:
            switch name {
            case "Lowest Overnight HR":  return weights.lowestHR
            case "Time to Lowest HR":    return weights.timeToLowestHR
            case "HRV":                  return weights.avgHRV
            case "Respiratory Rate":     return weights.avgRR
            case "Blood Oxygen":         return weights.spo2
            default:                     return 0.05
            }
        default:
            return 0.05
        }
    }

    private func isInverted(_ name: String) -> Bool {
        ["Lowest Overnight HR", "Time to Lowest HR", "Long Awakenings",
         "Sleep Latency"].contains(name)
    }

    private func formatted(_ i: SleepIndicator) -> String {
        let v = i.value
        switch i.unit {
        case "hr":
            return "\(Int(v))h \(Int((v - Double(Int(v))) * 60))m"
        case "%":
            return String(format: "%.0f%%", v)
        case "ms", "bpm":
            return "\(Int(v.rounded())) \(i.unit)"
        case "br/min":
            return "\(Int(v.rounded())) br/min"
        default:
            return String(format: "%.1f \(i.unit)", v)
        }
    }
}

// MARK: - Category Section

struct MetricCategorySection: View {
    let category: SleepIndicatorCategory
    let accentColor: Color
    let metrics: [MetricContribution]
    let isExpanded: Bool
    let onTap: () -> Void

    private var sectionScore: Double {
        let total = metrics.reduce(0) { $0 + $1.pointContribution }
        let max   = metrics.reduce(0) { $0 + $1.maxPointContribution }
        guard max > 0 else { return 0 }
        return min(total / max * 100, 100)
    }

    private var totalContribution: Double {
        metrics.reduce(0) { $0 + $1.pointContribution }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Color dot + name
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)

                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)

                    Spacer()

                    // Points
                    Text(String(format: "+%.1f pts", totalContribution))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            totalContribution > 8 ? DS.green : DS.textSecondary
                        )
                        .monospacedDigit()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(duration: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded && !metrics.isEmpty {
                Divider()
                    .overlay(DS.border)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { idx, metric in
                        MetricContributionRow(metric: metric)

                        if idx < metrics.count - 1 {
                            Divider()
                                .overlay(DS.borderFaint)
                                .padding(.leading, 16)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Metric Row

struct MetricContributionRow: View {
    let metric: MetricContribution

    private var barColor: Color {
        metric.normalizedScore >= 80 ? DS.green : DS.purple
    }

    private func monthlyDeltaText(for metric: MetricContribution) -> String? {
        guard let avg = metric.monthlyAverage else { return nil }
        let delta = metric.rawValue - avg
        guard abs(delta) >= 0.5 else { return "≈ 30d avg" }
        let sign = delta > 0 ? "+" : "-"
        let formatted: String
        switch metric.unit {
        case "hr":
            let mins = Int(abs(delta) * 60)
            formatted = "\(mins)m"
        case "%":
            formatted = String(format: "%.0f%%", abs(delta))
        default:
            formatted = String(format: "%.0f %@", abs(delta), metric.unit)
        }
        return "\(sign)\(formatted) vs 30d avg"
    }

    private func deltaColor(for metric: MetricContribution) -> Color {
        guard let avg = metric.monthlyAverage else { return DS.textTertiary }
        let delta = metric.rawValue - avg
        guard abs(delta) >= 0.5 else { return DS.textTertiary }
        // For inverted metrics (lower=better), negative delta is good
        let isGood = metric.isInverted ? delta < 0 : delta > 0
        return isGood ? DS.green : Color(red: 1.0, green: 0.42, blue: 0.42)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                // Name + monthly delta
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.name)
                        .font(.subheadline)
                        .foregroundStyle(DS.textPrimary)

                    if let subtitle = monthlyDeltaText(for: metric) {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(deltaColor(for: metric))
                    }
                }

                Spacer()

                // Value + pts
                VStack(alignment: .trailing, spacing: 2) {
                    Text(metric.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .monospacedDigit()

                    Text(String(format: "+%.2f pts", metric.pointContribution))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            metric.pointContribution > metric.maxPointContribution * 0.75
                            ? DS.green
                            : DS.textTertiary
                        )
                        .monospacedDigit()
                }
            }

            // Contribution bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // max possible
                    Capsule()
                        .fill(DS.border)
                        .frame(height: 3)
                    // actual
                    Capsule()
                        .fill(barColor)
                        .frame(
                            width: max(geo.size.width * metric.normalizedScore / 100, 3),
                            height: 3
                        )

                    // Glow on high scores
                    if metric.normalizedScore >= 80 {
                        Capsule()
                            .fill(DS.green.opacity(0.35))
                            .frame(
                                width: max(geo.size.width * metric.normalizedScore / 100, 3),
                                height: 5
                            )
                            .blur(radius: 2)
                    }
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
