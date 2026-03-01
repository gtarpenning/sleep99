import Foundation

struct SleepScoreEngine {
    func score(
        indicators: [SleepIndicator],
        weights: SleepScoreWeights,
        monthlyAverages: [String: Double] = [:]
    ) -> SleepScoreSummary {
        let sleepScore    = buildArchitectureScore(indicators, weights: weights, avgs: monthlyAverages)
        let recoveryScore = buildRecoveryScore(indicators, weights: weights, avgs: monthlyAverages)

        let overall = (sleepScore * weights.architectureWeight +
                       recoveryScore * weights.recoveryWeight) * 100

        return SleepScoreSummary(
            date: Date(),
            score:         min(max(overall, 0), 100),
            trend:         0,
            sleepScore:    min(max(sleepScore * 100, 0), 100),
            recoveryScore: min(max(recoveryScore * 100, 0), 100),
            confidence:    confidence(for: indicators),
            primarySource: determinePrimarySource(from: indicators)
        )
    }

    // MARK: - Category scores

    private func buildArchitectureScore(
        _ indicators: [SleepIndicator],
        weights: SleepScoreWeights,
        avgs: [String: Double]
    ) -> Double {
        let arch = indicators.filter { $0.category == .sleepArchitecture }
        return weightedAverage([
            (scored(arch, name: "Sleep Duration",   avgs: avgs), weights.duration),
            (scored(arch, name: "Sleep Efficiency", avgs: avgs), weights.efficiency),
            (scored(arch, name: "Sleep Latency",    avgs: avgs), weights.latency),
            (scored(arch, name: "REM Sleep",        avgs: avgs), weights.remPercent),
            (scored(arch, name: "Deep Sleep",       avgs: avgs), weights.deepPercent),
        ])
    }

    private func buildRecoveryScore(
        _ indicators: [SleepIndicator],
        weights: SleepScoreWeights,
        avgs: [String: Double]
    ) -> Double {
        let rec = indicators.filter { $0.category == .recovery }
        return weightedAverage([
            (scored(rec, name: "Lowest Overnight HR",  avgs: avgs), weights.lowestHR),
            (scored(rec, name: "HRV",                  avgs: avgs), weights.avgHRV),
            (scored(rec, name: "Respiratory Rate",     avgs: avgs), weights.avgRR),
            (scored(rec, name: "Time to Lowest HR",    avgs: avgs), weights.timeToLowestHR),
            (scored(rec, name: "Blood Oxygen",         avgs: avgs), weights.spo2),
        ])
    }

    // MARK: - Helpers

    /// Look up the indicator by name, score it via MetricProfiles registry.
    private func scored(_ indicators: [SleepIndicator], name: String, avgs: [String: Double]) -> Double? {
        guard let indicator = indicators.first(where: { $0.name == name }) else { return nil }
        return scoreMetric(name: name, value: indicator.value, monthlyAvg: avgs[name])
    }

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
