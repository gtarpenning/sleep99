import Foundation

struct SleepScoreEngine {
    func score(
        indicators: [SleepIndicator],
        weights: SleepScoreWeights,
        monthlyAverages: [String: Double] = [:]
    ) -> SleepScoreSummary {
        let sleepScore    = categoryScore(for: .sleepArchitecture, indicators: indicators, avgs: monthlyAverages)
        let recoveryScore = categoryScore(for: .recovery,          indicators: indicators, avgs: monthlyAverages)

        let overall = (sleepScore * weights.architectureWeight +
                       recoveryScore * weights.recoveryWeight) * 100

        return SleepScoreSummary(
            date: Date(),
            score:         min(max(overall, 0), 99),
            trend:         0,
            sleepScore:    min(max(sleepScore * 100, 0), 99),
            recoveryScore: min(max(recoveryScore * 100, 0), 99),
            confidence:    confidence(for: indicators),
            primarySource: determinePrimarySource(from: indicators)
        )
    }

    // MARK: - Category scoring (driven entirely by MetricRegistry)

    private func categoryScore(
        for category: SleepIndicatorCategory,
        indicators: [SleepIndicator],
        avgs: [String: Double]
    ) -> Double {
        let defs = MetricRegistry.scoredMetrics(in: category)
        let pairs: [(Double?, Double)] = defs.map { def in
            // Search ALL indicators by name — allows cross-category metrics (e.g. "Overnight Heart Rate"
            // lives in .sleepArchitecture indicator but is also defined in .recovery registry).
            let value = indicators.first(where: { $0.name == def.name }).flatMap {
                scoreMetric(name: $0.name, value: $0.value, monthlyAvg: avgs[$0.name])
            }
            return (value, def.weight)
        }
        return weightedAverage(pairs)
    }

    // MARK: - Helpers

    private func weightedAverage(_ pairs: [(Double?, Double)]) -> Double {
        var totalWeight = 0.0
        var weightedSum = 0.0
        for (value, weight) in pairs {
            guard let value else { continue }
            weightedSum += value * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0 }
        return weightedSum / totalWeight
    }

    private func confidence(for indicators: [SleepIndicator]) -> Double {
        let hasWatchData  = indicators.contains { $0.source == .appleWatch }
        let hasOura       = indicators.contains { $0.source == .oura }
        let categoryCount = Set(indicators.map(\.category)).count
        let base = (hasWatchData || hasOura) ? 0.8 : 0.6
        return min(base + Double(categoryCount) * 0.05, 1.0)
    }

    private func determinePrimarySource(from indicators: [SleepIndicator]) -> SleepIndicatorSource {
        let counts = Dictionary(grouping: indicators, by: \.source).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .appleHealth
    }
}
