import SwiftUI

// MARK: - Main block

struct InsightsBlockView: View {
    let tagCorrelations: [TagCorrelation]
    let activitySnapshot: DailyActivitySnapshot?
    let activityMonthlyStats: [String: MetricStats]
    let selectedDate: Date

    @State private var selectedCorrelation: TagCorrelation?
    @State private var selectedActivityMetric: ActivityMetricItem?

    private var hasContent: Bool {
        !tagCorrelations.isEmpty || activitySnapshot != nil
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 16) {
                if !tagCorrelations.isEmpty {
                    tagInsightsSection
                }
                if !stripItems.isEmpty {
                    activitySection
                }
            }
            .sheet(item: $selectedCorrelation) { correlation in
                TagCorrelationDetailSheet(correlation: correlation)
            }
            .sheet(item: $selectedActivityMetric) { item in
                ActivityMetricDetailSheet(item: item, snapshot: activitySnapshot, activityMonthlyStats: activityMonthlyStats)
            }
        }
    }

    // MARK: - Tag insights

    private var tagInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSSectionHeader(title: "Tag Insights")
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(tagCorrelations.prefix(3)) { correlation in
                    TagInsightRow(correlation: correlation)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedCorrelation = correlation }
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Activity section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSSectionHeader(title: activityDateLabel)
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ForEach(stripItems) { item in
                    Button { selectedActivityMetric = item } label: {
                        ActivityStripChip(item: item, average: activityMonthlyStats[item.id]?.avg)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// The three numbers worth a glance; everything else lives on the Trends screen.
    private var stripItems: [ActivityMetricItem] {
        let wanted = ["steps", "ex", "peakhr"]
        let all = activityItems(expanded: true)
        return wanted.compactMap { id in all.first { $0.id == id } }
    }

    private var activityDateLabel: String {
        let activityDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        if Calendar.current.isDateInYesterday(activityDate) { return "Yesterday" }
        return "Day before · " + activityDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func activityItems(expanded: Bool) -> [ActivityMetricItem] {
        guard let snap = activitySnapshot else { return [] }
        var items: [ActivityMetricItem] = []

        if let v = snap.steps       { items.append(.init(id: "steps",    label: "Steps",    value: v,        unit: "steps", icon: "figure.walk")) }
        if let v = snap.activeCalories { items.append(.init(id: "kcal",  label: "Calories", value: v,        unit: "kcal",  icon: "flame.fill")) }
        if let v = snap.exerciseMinutes { items.append(.init(id: "ex",   label: "Exercise", value: v,        unit: "min",   icon: "bolt.fill")) }
        if let v = snap.peakHR      { items.append(.init(id: "peakhr",   label: "Peak HR",  value: v,        unit: "bpm",   icon: "heart.fill")) }

        if expanded {
            if let v = snap.floorsClimbed { items.append(.init(id: "floors",  label: "Floors",  value: v, unit: "fl",  icon: "arrow.up.right")) }
            if let v = snap.standMinutes  { items.append(.init(id: "stand",   label: "Stand",   value: v, unit: "min", icon: "figure.stand")) }
            if let v = snap.vo2Max        { items.append(.init(id: "vo2",     label: "VO₂ Max", value: v, unit: "ml/kg·min", icon: "lungs.fill")) }
            if !snap.workouts.isEmpty {
                let totalMins = snap.workouts.map(\.durationMinutes).reduce(0, +)
                items.append(.init(id: "workouts", label: "Workouts", value: Double(snap.workouts.count), unit: snap.workouts.count == 1 ? "session" : "sessions", icon: "dumbbell.fill", detail: totalMinsLabel(totalMins)))
            }
        }
        return items
    }

    private func totalMinsLabel(_ mins: Double) -> String {
        let m = Int(mins.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}

// MARK: - ActivityMetricItem

struct ActivityMetricItem: Identifiable {
    let id: String
    let label: String
    let value: Double
    let unit: String
    let icon: String
    var detail: String? = nil

    var formattedValue: String {
        switch unit {
        case "steps": return value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value))"
        case "kcal":  return value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value.rounded()))"
        case "ml/kg·min": return String(format: "%.1f", value)
        default:      return "\(Int(value.rounded()))"
        }
    }
}

// MARK: - TagInsightRow

private struct TagInsightRow: View {
    let correlation: TagCorrelation

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(correlation.tag.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text("·  \(correlation.taggedNights) nights")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                }
                if let top = correlation.metricImpacts.first {
                    Text(topImpactSummary(top))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            scoreDeltaView
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(14)
    }

    private var scoreDeltaView: some View {
        let delta = correlation.scoreDelta
        let color: Color = delta < 0 ? .red.opacity(0.85) : DS.purple
        return VStack(spacing: 1) {
            Text("\(delta >= 0 ? "+" : "")\(Int(delta.rounded()))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text("score")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
    }

    private func topImpactSummary(_ impact: MetricImpact) -> String {
        let from = formatMetricValue(impact.baselineAvg, unit: impact.unit)
        let to   = formatMetricValue(impact.taggedAvg,   unit: impact.unit)
        return "\(impact.metricName): \(from) → \(to)"
    }

    private func formatMetricValue(_ v: Double, unit: String) -> String {
        switch unit {
        case "hr":
            let h = Int(v); let m = Int((v - Double(h)) * 60)
            return m == 0 ? "\(h)h" : "\(h)h\(m)m"
        case "br/min":
            return String(format: "%.1f", v)
        default:
            return "\(Int(v.rounded())) \(unit)"
        }
    }
}

// MARK: - ActivityStripChip

/// Label, value, and an arrow against the 30-day average.
private struct ActivityStripChip: View {
    let item: ActivityMetricItem
    let average: Double?

    private enum Direction { case up, down, flat }

    private var direction: Direction? {
        guard let average, average > 0 else { return nil }
        let rel = (item.value - average) / average
        if rel > 0.05 { return .up }
        if rel < -0.05 { return .down }
        return .flat
    }

    private var averageText: String? {
        guard let average, average > 0 else { return nil }
        let avgItem = ActivityMetricItem(id: item.id, label: item.label, value: average, unit: item.unit, icon: item.icon)
        return "avg \(avgItem.formattedValue)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.formattedValue)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                if item.unit == "min" || item.unit == "bpm" {
                    Text(item.unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.textTertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                if let direction {
                    Image(systemName: symbol(direction))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(color(direction))
                }
                Text(averageText ?? "no average yet")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .dsCard(14)
        .accessibilityElement(children: .combine)
    }

    private func symbol(_ d: Direction) -> String {
        switch d { case .up: return "arrowtriangle.up.fill"; case .down: return "arrowtriangle.down.fill"; case .flat: return "minus" }
    }
    // Direction is descriptive, not a verdict: more activity is green, less is muted.
    private func color(_ d: Direction) -> Color {
        switch d { case .up: return DS.green; case .down: return DS.textSecondary; case .flat: return DS.textTertiary }
    }
}
