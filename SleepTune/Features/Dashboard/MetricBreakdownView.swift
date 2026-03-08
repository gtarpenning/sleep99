import SwiftUI

// MARK: - Metric Contribution Model

struct MetricContribution: Identifiable {
    let id: String
    let name: String
    let formattedValue: String   // display string for the raw value
    let rawValue: Double
    let unit: String
    let normalizedScore: Double  // 0–100
    let pointContribution: Double
    let maxPointContribution: Double
    let lowerIsBetter: Bool
    let hint: String?            // static directional hint from MetricDefinition
    let stats: MetricStats?      // 30-day stats; nil for new users
    let category: SleepIndicatorCategory

    /// Display-only contribution used in the expanded breakdown.
    /// Overall score logic remains unchanged.
    var displayedPointContribution: Double { pointContribution * 2 }
    var displayedMaxPointContribution: Double { maxPointContribution * 2 }
}

// MARK: - Main View

struct MetricBreakdownView: View {
    let indicators: [SleepIndicator]
    var monthlyStats: [String: MetricStats] = [:]
    var sleepScore: Double = 0
    var recoveryScore: Double = 0

    // Category splits from default weights (architecture 40%, recovery 60%)
    private let weights = SleepScoreWeights.default

    @State private var expandedCategory: SleepIndicatorCategory? = nil

    var body: some View {
        VStack(spacing: 10) {
            DSSectionHeader(title: "Score Breakdown", trailing: "Impact")
                .padding(.horizontal, 2)

            VStack(spacing: 2) {
                MetricCategorySection(
                    category: .sleepArchitecture,
                    accentColor: DS.sleepArc,
                    metrics: contributions(for: .sleepArchitecture),
                    categoryScore: Int(sleepScore.rounded()),
                    isExpanded: expandedCategory == .sleepArchitecture,
                    onTap: {
                        withAnimation(.spring(duration: 0.35)) {
                            expandedCategory = (expandedCategory == .sleepArchitecture) ? nil : .sleepArchitecture
                        }
                    }
                )
                MetricCategorySection(
                    category: .recovery,
                    accentColor: DS.recoveryArc,
                    metrics: contributions(for: .recovery),
                    categoryScore: Int(recoveryScore.rounded()),
                    isExpanded: expandedCategory == .recovery,
                    onTap: {
                        withAnimation(.spring(duration: 0.35)) {
                            expandedCategory = (expandedCategory == .recovery) ? nil : .recovery
                        }
                    }
                )
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.border, lineWidth: 0.5))
        }
    }

    // MARK: - Build contributions
    // Driven by the actual indicators present (not the registry list), so nothing
    // is silently dropped. Registry metadata (weight, direction, hint) is looked up
    // per indicator; weight-0 and unregistered metrics appear as informational rows.

    private func contributions(for category: SleepIndicatorCategory) -> [MetricContribution] {
        // Start with indicators whose .category matches, then add cross-listed registry metrics
        // (e.g. "Overnight Heart Rate" is a .sleepArchitecture indicator but also has a .recovery
        // registry entry, so it should appear in the Recovery section too).
        let crossListedNames = MetricRegistry.all
            .filter { $0.category == category }
            .map(\.name)
        let displayIndicators = indicators.filter { indicator in
            // Only show metrics that exist in the registry; skip unregistered/junk metrics
            guard MetricRegistry.all.contains(where: { $0.name == indicator.name }) else { return false }
            return indicator.category == category || crossListedNames.contains(indicator.name)
        }
        // Deduplicate (shouldn't be needed but guard against double-add)
        var seen = Set<String>()
        let uniqueIndicators = displayIndicators.filter { seen.insert($0.name).inserted }

        let categoryWeight = category == .sleepArchitecture ? weights.architectureWeight : weights.recoveryWeight
        let scoredTotal = totalWeight(in: category)

        return uniqueIndicators.map { indicator in
            // Look up the definition for THIS category (cross-listed metrics have two definitions)
            let def      = MetricRegistry.all.first { $0.name == indicator.name && $0.category == category }
                        ?? MetricRegistry.definition(for: indicator.name)
            let weight   = def?.weight ?? 0
            let stats    = monthlyStats[indicator.name]
            let normalized = scoreMetric(name: indicator.name, value: indicator.value, monthlyAvg: stats?.avg) ?? 0
            let maxPts   = scoredTotal > 0 ? weight / scoredTotal * categoryWeight * 100 : 0
            let actualPts = normalized * maxPts

            return MetricContribution(
                id: indicator.name,
                name: indicator.name,
                formattedValue: formatted(value: indicator.value, unit: indicator.unit),
                rawValue: indicator.value,
                unit: indicator.unit,
                normalizedScore: normalized * 100,
                pointContribution: actualPts,
                maxPointContribution: maxPts,
                lowerIsBetter: def?.lowerIsBetter ?? false,
                hint: def?.hint,
                stats: stats,
                category: category
            )
        }
        // Scored metrics first (by contribution), then informational (weight 0) by name
        .sorted {
            if $0.maxPointContribution != $1.maxPointContribution {
                return $0.maxPointContribution > $1.maxPointContribution
            }
            return $0.name < $1.name
        }
    }

    private func totalWeight(in category: SleepIndicatorCategory) -> Double {
        MetricRegistry.scoredMetrics(in: category).map(\.weight).reduce(0, +)
    }
}

// MARK: - Value Formatting

func formatted(value: Double, unit: String) -> String {
    switch unit {
    case "hr":
        return "\(Int(value))h \(Int((value - Double(Int(value))) * 60))m"
    case "%":
        return String(format: "%.0f%%", value)
    case "ms", "bpm", "min":
        return "\(Int(value.rounded())) \(unit)"
    case "br/min":
        return "\(value.formatted(.number.precision(.fractionLength(1)))) br/min"
    case "fraction":
        return String(format: "%.2f", value)
    case "bedtime":
        // value = hours from noon (10 PM = 10.0, midnight = 12.0, 1 AM = 13.0)
        let minutesFromMidnight = (Int((value * 60).rounded()) + 12 * 60) % (24 * 60)
        let h = minutesFromMidnight / 60
        let m = minutesFromMidnight % 60
        let ampm = h < 12 ? "AM" : "PM"
        let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
        return String(format: "%d:%02d %@", displayH, m, ampm)
    default:
        return String(format: "%.1f \(unit)", value)
    }
}

// MARK: - Category Section

struct MetricCategorySection: View {
    let category: SleepIndicatorCategory
    let accentColor: Color
    let metrics: [MetricContribution]
    let categoryScore: Int
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var chevronPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)

                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text("\(min(max(categoryScore, 0), 99))/99")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(categoryScore >= 75 ? DS.green : DS.textSecondary)
                        .monospacedDigit()

                    ZStack {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accentColor.opacity(0.6 + (chevronPulse ? 0.4 : 0)))
                            .shadow(color: accentColor.opacity(chevronPulse ? 0.7 : 0.2), radius: chevronPulse ? 5 : 2)
                    }
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(duration: 0.3), value: isExpanded)
                    .onAppear {
                        guard !isExpanded else { return }
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            chevronPulse = true
                        }
                    }
                    .onChange(of: isExpanded) { _, expanded in
                        if expanded {
                            withAnimation(.easeOut(duration: 0.2)) { chevronPulse = false }
                        } else {
                            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                                chevronPulse = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
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
    @State private var showDetail = false

    private var contributionText: String {
        "+\(metric.displayedPointContribution.formatted(.number.precision(.fractionLength(2))))"
    }

    private var barColor: Color {
        metric.normalizedScore >= 80 ? DS.green : DS.purple
    }

    /// Subtitle: show actual 30d average (transparent) + delta tonight; fall back to static hint.
    private var subtitle: (text: String, color: Color)? {
        if let stats = metric.stats, stats.count > 0 {
            let avgText = "avg \(compactValueText(value: stats.avg, unit: metric.unit))"
            let delta = metric.rawValue - stats.avg
            let threshold: Double = metric.unit == "fraction" ? 0.05 : 0.5
            if abs(delta) < threshold {
                return (avgText, DS.textTertiary)
            }
            // Build delta string
            let deltaText = compactDeltaText(delta: delta, unit: metric.unit)
            return ("\(avgText) (\(deltaText) tonight)", DS.textTertiary)
        } else if let hint = metric.hint {
            return (hint, DS.textTertiary)
        }
        return nil
    }

    private func compactValueText(value: Double, unit: String) -> String {
        switch unit {
        case "ms", "bpm", "min":
            return "\(Int(value.rounded()))\(unit)"
        case "br/min":
            return "\(value.formatted(.number.precision(.fractionLength(1))))br/min"
        case "%":
            return "\(Int(value.rounded()))%"
        case "fraction":
            return value.formatted(.number.precision(.fractionLength(2)))
        case "hr":
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60)
            return "\(hours)h \(minutes)m"
        default:
            return formatted(value: value, unit: unit)
        }
    }

    private func compactDeltaText(delta: Double, unit: String) -> String {
        let prefix = delta > 0 ? "+" : "-"

        switch unit {
        case "hr":
            let minutes = Int(abs(delta) * 60)
            return "\(prefix)\(minutes)m"
        case "br/min":
            return "\(prefix)\(abs(delta).formatted(.number.precision(.fractionLength(1))))br/min"
        case "%":
            return "\(prefix)\(Int(abs(delta).rounded()))%"
        case "fraction":
            return "\(prefix)\(abs(delta).formatted(.number.precision(.fractionLength(2))))"
        default:
            return "\(prefix)\(Int(abs(delta).rounded()))\(unit)"
        }
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.name)
                            .font(.subheadline)
                            .foregroundStyle(DS.textPrimary)

                        if let sub = subtitle {
                            Text(sub.text)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(sub.color)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(metric.formattedValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                            .monospacedDigit()

                        Text(contributionText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                metric.displayedPointContribution > metric.displayedMaxPointContribution * 0.75
                                ? DS.green : DS.textTertiary
                            )
                            .monospacedDigit()
                    }
                }

                // Contribution bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.border).frame(height: 3)
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(geo.size.width * metric.normalizedScore / 100, 3), height: 3)
                        if metric.normalizedScore >= 80 {
                            Capsule()
                                .fill(DS.green.opacity(0.35))
                                .frame(width: max(geo.size.width * metric.normalizedScore / 100, 3), height: 5)
                                .blur(radius: 2)
                        }
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MetricDetailSheet(metric: metric)
        }
    }
}
