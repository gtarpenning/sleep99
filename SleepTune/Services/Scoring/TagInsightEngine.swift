import Foundation

@MainActor
final class TagInsightEngine {
    func compute(tagStore: SleepTagStore, localStore: SleepLocalStore) async -> [TagCorrelation] {
        let cal = Calendar.current
        let today = Date()

        // Collect up to 60 days of data
        var rows: [(indicators: [SleepIndicator], score: Double, tags: [SleepTag])] = []
        for offset in 0..<60 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let indicators = await localStore.loadIndicators(for: day)
            guard !indicators.isEmpty else { continue }
            let scores = await localStore.loadScores(from: day, to: day)
            let score = scores.first?.score ?? 0
            let tags = tagStore.activeTags(for: day)
            rows.append((indicators, score, tags))
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

            guard tagged.count >= 2, baseline.count >= 2 else { continue }

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
                guard taggedVals.count >= 2, baselineVals.count >= 2 else { continue }

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
}
