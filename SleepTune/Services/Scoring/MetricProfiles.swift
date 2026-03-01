// MARK: - Scoring shapes

/// Describes how a metric maps from a raw value → 0…1 score.
/// Monthly average is used as the personal ideal when available;
/// the hard floor/ceiling provides a safe fallback for new users with no history.
enum ScoringShape {
    /// More is better. Score = 0 at hardMin, 1 at max(monthlyAvg, idealMin).
    case higherIsBetter(hardMin: Double, idealMin: Double)

    /// Less is better. Score = 1 at or below min(monthlyAvg, idealMax), 0 at hardMax.
    case lowerIsBetter(idealMax: Double, hardMax: Double)

    /// Personal-average baseline. Score = 1 at monthlyAvg, falls off by
    /// `tolerance` units on either side. Falls back to `fallback` with no history.
    case personalAverage(tolerance: Double, fallback: Double = 0.5)
}

// MARK: - Scoring function

/// Converts a raw value to a 0…1 score.
/// Scoring shapes and parameters come from MetricRegistry — add metrics there, not here.
func scoreMetric(name: String, value: Double, monthlyAvg: Double?) -> Double? {
    guard let shape = MetricRegistry.definition(for: name)?.scoring else { return nil }

    switch shape {
    case .higherIsBetter(let hardMin, let idealMin):
        // Personal average raises the bar; fallback to idealMin for new users
        let target = max(monthlyAvg ?? idealMin, idealMin)
        let span   = target - hardMin
        guard span > 0 else { return 1 }
        return min(max((value - hardMin) / span, 0), 1)

    case .lowerIsBetter(let idealMax, let hardMax):
        // Personal average lowers the bar; fallback to idealMax for new users
        let target = min(monthlyAvg ?? idealMax, idealMax)
        let span   = hardMax - target
        guard span > 0 else { return value <= target ? 1 : 0 }
        return min(max((hardMax - value) / span, 0), 1)

    case .personalAverage(let tolerance, let fallback):
        guard let avg = monthlyAvg else { return fallback }
        guard tolerance > 0 else { return 1 }
        return max(0, 1 - abs(value - avg) / tolerance)
    }
}
