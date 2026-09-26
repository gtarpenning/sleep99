import Foundation

@MainActor
final class TagInsightEngine {
    /// A tag needs this many tagged nights (and as many untagged) before we
    /// show an insight; below that the averages are mostly noise.
    static let minTaggedNights = 10

    func compute(tagStore: SleepTagStore, nightStore: NightRecordStore) async -> [TagCorrelation] {
        // Up to 90 nights of history from the night store.
        let nights = (try? await nightStore.latest(90)) ?? []
        var rows: [(indicators: [SleepIndicator], score: Double, tags: [SleepTag])] = []
        for n in nights where n.score > 0 {
            let indicators = n.metrics.map { SleepIndicator(name: $0.key, detail: "", value: $0.value, unit: Self.unit(for: $0.key), category: .recovery, source: .appleHealth) }
            rows.append((indicators, n.score, tagStore.activeTags(for: n.night)))
        }

        guard rows.count >= 4 else { return [] }

        // Collect all tag IDs that appear in any night
        var tagIDsSeen: [UUID] = []
        for row in rows {
            for tag in row.tags where !tagIDsSeen.contains(tag.id) {
                tagIDsSeen.append(tag.id)
            }
        }

        var results: [TagCorrelation] = []

        for tagID in tagIDsSeen {
            guard let tag = tagStore.availableTags.first(where: { $0.id == tagID }) else { continue }

            let tagged   = rows.filter { $0.tags.contains { $0.id == tagID } }
            let baseline = rows.filter { !$0.tags.contains { $0.id == tagID } }

            guard tagged.count >= Self.minTaggedNights, baseline.count >= Self.minTaggedNights else { continue }

            let avgTagged   = tagged.map(\.score).reduce(0, +) / Double(tagged.count)
            let avgBaseline = baseline.map(\.score).reduce(0, +) / Double(baseline.count)

            // Skip tags with no meaningful score impact
            guard abs(avgTagged - avgBaseline) >= 4 else { continue }

            // Compute per-metric impacts across all sleep/recovery indicators
            let allNames = Set(rows.flatMap { $0.indicators.map(\.name) })
            var impacts: [MetricImpact] = []

            for name in allNames {
                let taggedVals   = tagged.compactMap   { $0.indicators.first(where: { $0.name == name })?.value }
                let baselineVals = baseline.compactMap { $0.indicators.first(where: { $0.name == name })?.value }
                guard taggedVals.count >= Self.minTaggedNights / 2, baselineVals.count >= Self.minTaggedNights / 2 else { continue }

                let taggedAvg   = taggedVals.reduce(0, +) / Double(taggedVals.count)
                let baselineAvg = baselineVals.reduce(0, +) / Double(baselineVals.count)

                let relativeDiff = abs(taggedAvg - baselineAvg) / max(abs(baselineAvg), 0.01)
                guard relativeDiff >= 0.06 else { continue }

                let unit = tagged.first?.indicators.first(where: { $0.name == name })?.unit ?? ""
                let lowerIsBetter = MetricRegistry.definition(for: name)?.lowerIsBetter ?? false

                impacts.append(MetricImpact(
                    metricName: name,
                    unit: unit,
                    taggedAvg: taggedAvg,
                    baselineAvg: baselineAvg,
                    lowerIsBetter: lowerIsBetter
                ))
            }

            let sortedImpacts = impacts.sorted { abs($0.delta) / max(abs($0.baselineAvg), 0.01) > abs($1.delta) / max(abs($1.baselineAvg), 0.01) }

            results.append(TagCorrelation(
                tag: tag,
                taggedNights: tagged.count,
                avgScoreTagged: avgTagged,
                avgScoreBaseline: avgBaseline,
                metricImpacts: sortedImpacts
            ))
        }

        return results.sorted { abs($0.scoreDelta) > abs($1.scoreDelta) }
    }

    /// Splits the past 60 days into high vs low activity (median split per metric)
    /// and returns score-impact correlations. Mirrors the tag correlation flow but
    /// bucketed by activity level rather than user-applied tags.
    ///
    /// Currently buckets on `steps`. Returns at most one correlation per metric.
    func computeActivityCorrelations(nightStore: NightRecordStore) async -> [TagCorrelation] {
        struct Row {
            let score: Double
            let steps: Double?
            let indicators: [SleepIndicator]
        }

        let nights = (try? await nightStore.latest(90)) ?? []
        var rows: [Row] = []
        for n in nights where n.score > 0 {
            let indicators = n.metrics.map { SleepIndicator(name: $0.key, detail: "", value: $0.value, unit: Self.unit(for: $0.key), category: .recovery, source: .appleHealth) }
            rows.append(Row(score: n.score, steps: n.steps, indicators: indicators))
        }

        let withSteps = rows.compactMap { row -> (Double, Row)? in
            guard let s = row.steps else { return nil }
            return (s, row)
        }
        guard withSteps.count >= 10 else { return [] }

        let sortedSteps = withSteps.map(\.0).sorted()
        let median = sortedSteps[sortedSteps.count / 2]
        let high = withSteps.filter { $0.0 >= median }.map(\.1)
        let low  = withSteps.filter { $0.0 <  median }.map(\.1)
        guard high.count >= 5, low.count >= 5 else { return [] }

        let avgHigh = high.map(\.score).reduce(0, +) / Double(high.count)
        let avgLow  = low.map(\.score).reduce(0, +) / Double(low.count)
        guard abs(avgHigh - avgLow) >= 4 else { return [] }

        // Per-metric impact between high vs low activity nights.
        let allNames = Set(rows.flatMap { $0.indicators.map(\.name) })
        var impacts: [MetricImpact] = []
        for name in allNames {
            let highVals = high.compactMap { $0.indicators.first(where: { $0.name == name })?.value }
            let lowVals  = low.compactMap  { $0.indicators.first(where: { $0.name == name })?.value }
            guard highVals.count >= 3, lowVals.count >= 3 else { continue }
            let highAvg = highVals.reduce(0, +) / Double(highVals.count)
            let lowAvg  = lowVals.reduce(0, +)  / Double(lowVals.count)
            let relDiff = abs(highAvg - lowAvg) / Swift.max(abs(lowAvg), 0.01)
            guard relDiff >= 0.06 else { continue }
            let unit = high.first?.indicators.first(where: { $0.name == name })?.unit ?? ""
            let lowerIsBetter = MetricRegistry.definition(for: name)?.lowerIsBetter ?? false
            // We model "high activity" as the "tagged" condition for reuse of the existing
            // TagCorrelation type — UI can render this as "Active days" tag with synthetic ID.
            impacts.append(MetricImpact(
                metricName: name,
                unit: unit,
                taggedAvg: highAvg,
                baselineAvg: lowAvg,
                lowerIsBetter: lowerIsBetter
            ))
        }

        // Reuse TagCorrelation's shape with a synthetic "Active days" pseudo-tag.
        let pseudoTag = SleepTag(id: UUID(uuidString: "AAAABBBB-0000-0000-0000-AAAA00000001")!, name: "Active days")
        let sortedImpacts = impacts.sorted { abs($0.delta) / Swift.max(abs($0.baselineAvg), 0.01) > abs($1.delta) / Swift.max(abs($1.baselineAvg), 0.01) }
        return [TagCorrelation(
            tag: pseudoTag,
            taggedNights: high.count,
            avgScoreTagged: avgHigh,
            avgScoreBaseline: avgLow,
            metricImpacts: sortedImpacts
        )]
    }

    /// Display unit for a metric name. Night records store only values, so the
    /// unit is recovered from the metric registry's known names.
    static func unit(for name: String) -> String {
        switch name {
        case "Sleep Duration":                              return "hr"
        case "Sleep Efficiency", "Blood Oxygen":            return "%"
        case "REM Sleep", "Deep Sleep", "Core Sleep",
             "Sleep Latency", "Exercise Time", "Stand Time",
             "Workout Duration":                            return "min"
        case "Overnight Heart Rate", "Lowest Overnight HR": return "bpm"
        case "HRV", "Peak HRV":                             return "ms"
        case "Respiratory Rate":                            return "br/min"
        case "Wrist Temperature":                           return "°C"
        case "Active Energy", "Basal Energy", "Workout Energy": return "kcal"
        case "Steps":                                       return "steps"
        case "REM Cycle Count":                             return "cycles"
        default:                                            return ""
        }
    }
}
