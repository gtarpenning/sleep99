import SwiftUI

// MARK: - Main block

struct InsightsBlockView: View {
    let tagCorrelations: [TagCorrelation]
    let activitySnapshot: DailyActivitySnapshot?
    let activityMonthlyStats: [String: MetricStats]
    let selectedDate: Date

    @State private var activityExpanded = false
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
                if activitySnapshot != nil {
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
            DSSectionHeader(title: "Activity  ·  \(activityDateLabel)")
                .padding(.horizontal, 20)

            let items = activityItems(expanded: activityExpanded)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items) { item in
                    ActivityChip(item: item)
                        .onTapGesture { selectedActivityMetric = item }
                }
            }
            .padding(.horizontal, 20)
            .animation(.spring(duration: 0.3), value: activityExpanded)

            if activityHasMoreItems {
                Button {
                    withAnimation(.spring(duration: 0.3)) { activityExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(activityExpanded ? "Show less" : "Show more")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.textTertiary)
                        Image(systemName: activityExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activityDateLabel: String {
        let activityDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        if Calendar.current.isDateInYesterday(activityDate) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: activityDate)
    }

    private var activityHasMoreItems: Bool {
        guard let snap = activitySnapshot else { return false }
        return snap.floorsClimbed != nil || snap.standMinutes != nil || snap.vo2Max != nil || !snap.workouts.isEmpty
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

// MARK: - ActivityChip

private struct ActivityChip: View {
    let item: ActivityMetricItem

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.textSecondary)
            Text(item.formattedValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .dsCard(12)
    }
}
