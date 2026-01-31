import Foundation

struct SleepScoreEngine {
    func score(
        indicators: [SleepIndicator],
        weights: SleepScoreWeights,
        feeling: SleepFeeling?
    ) -> SleepScoreSummary {
        let normalized = normalizeIndicators(indicators)
        let components = buildComponents(from: normalized, weights: weights)
        let baseScore = components.map { $0.contribution }.reduce(0, +)
        let adjustedScore = applyFeelingAdjustment(baseScore, feeling: feeling)
        let clampedScore = min(max(adjustedScore, 0), 100)

        return SleepScoreSummary(
            date: Date(),
            score: clampedScore,
            trend: 0,
            components: components,
            confidence: confidence(for: indicators),
            note: note(for: indicators, feeling: feeling)
        )
    }

    private func normalizeIndicators(_ indicators: [SleepIndicator]) -> [SleepIndicator] {
        indicators.map { indicator in
            guard let range = indicator.range else { return indicator }
            let normalizedValue = normalize(indicator.value, within: range)
            var updated = indicator
            updated.contribution = normalizedValue
            return updated
        }
    }

    private func buildComponents(
        from indicators: [SleepIndicator],
        weights: SleepScoreWeights
    ) -> [SleepScoreComponent] {
        let grouped = Dictionary(grouping: indicators, by: \ .category)

        return grouped.map { category, categoryIndicators in
            let average = averageContribution(for: categoryIndicators)
            let weight = weight(for: category, weights: weights)
            return SleepScoreComponent(
                name: category.rawValue.capitalized,
                value: average,
                weight: weight,
                contribution: average * weight * 100
            )
        }
    }

    private func weight(for category: SleepIndicatorCategory, weights: SleepScoreWeights) -> Double {
        switch category {
        case .recovery:
            return weights.recovery
        case .sleepArchitecture:
            return weights.architecture
        case .consistency:
            return weights.consistency
        case .environment:
            return weights.environment
        case .behavior:
            return weights.behavior
        }
    }

    private func averageContribution(for indicators: [SleepIndicator]) -> Double {
        let valid = indicators
            .filter { $0.range != nil }
            .map(\ .contribution)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private func normalize(_ value: Double, within range: ClosedRange<Double>) -> Double {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(normalized, 0), 1)
    }

    private func applyFeelingAdjustment(_ score: Double, feeling: SleepFeeling?) -> Double {
        guard let feeling else { return score }
        switch feeling {
        case .low:
            return score - 6
        case .okay:
            return score
        case .good:
            return score + 4
        case .energized:
            return score + 8
        }
    }

    private func confidence(for indicators: [SleepIndicator]) -> Double {
        let hasWatchData = indicators.contains { $0.source == .appleWatch }
        let diversity = Set(indicators.map(\ .category)).count
        let base = hasWatchData ? 0.8 : 0.6
        return min(base + (Double(diversity) * 0.04), 1)
    }

    private func note(for indicators: [SleepIndicator], feeling: SleepFeeling?) -> String {
        let count = indicators.count
        let feelingNote = feeling == nil ? "Add a feeling check-in to personalize your score." : ""
        return "Using \(count) inputs. \(feelingNote)"
    }
}
