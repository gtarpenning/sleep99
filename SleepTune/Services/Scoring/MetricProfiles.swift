// MARK: - Scoring shapes

/// Describes how a metric maps from a raw value → 0…1 score.
/// Monthly average is used as the personal baseline when available;
/// the hard floor/ceiling provides a fallback for new users with no history.
enum ScoringShape {
    /// More is better. Score = 0 at hardMin, 1 at max(monthlyAvg, idealMin).
    case higherIsBetter(hardMin: Double, idealMin: Double)

    /// Less is better. Score = 1 at or below min(monthlyAvg, idealMax), 0 at hardMax.
    case lowerIsBetter(idealMax: Double, hardMax: Double)

    /// Personal-average baseline. Score = 1 at monthlyAvg, drops off by
    /// `tolerance` units on either side. Falls back to `fallback` with no history.
    case personalAverage(tolerance: Double, fallback: Double = 0.5)
}

// MARK: - Registry

/// One entry per scored metric.  Add a line here to add or tune a metric.
let metricProfiles: [String: ScoringShape] = [
    // ── Sleep Architecture ───────────────────────────────────────────────
    "Sleep Duration":      .higherIsBetter(hardMin: 4,   idealMin: 8),   // max(avg, 8h)
    "Sleep Efficiency":    .higherIsBetter(hardMin: 60,  idealMin: 90),  // max(avg, 90%)
    "Sleep Latency":       .lowerIsBetter( idealMax: 10, hardMax: 60),   // min(avg, 10 min)
    "REM Sleep":           .personalAverage(tolerance: 5),               // ±5 pp from avg
    "Deep Sleep":          .personalAverage(tolerance: 3),               // ±3 pp from avg

    // ── Recovery ────────────────────────────────────────────────────────
    "Lowest Overnight HR": .lowerIsBetter( idealMax: 45, hardMax: 80),   // min(avg, 45 bpm)
    "Time to Lowest HR":   .lowerIsBetter( idealMax: 0,  hardMax: 1),    // earlier = better
    "HRV":                 .higherIsBetter(hardMin: 10,  idealMin: 50),  // max(avg, 50 ms)
    "Respiratory Rate":    .lowerIsBetter( idealMax: 12, hardMax: 22),   // min(avg, 12 br/min)
    "Blood Oxygen":        .higherIsBetter(hardMin: 88,  idealMin: 97),  // max(avg, 97%)
    "Wrist Temperature":   .personalAverage(tolerance: 0.5),
]

// MARK: - Scoring function

/// Converts a raw value to a 0…1 score using the metric's profile and optional monthly average.
func scoreMetric(name: String, value: Double, monthlyAvg: Double?) -> Double? {
    guard let shape = metricProfiles[name] else { return nil }

    switch shape {
    case .higherIsBetter(let hardMin, let idealMin):
        let target = max(monthlyAvg ?? idealMin, idealMin)
        let span   = target - hardMin
        guard span > 0 else { return 1 }
        return min(max((value - hardMin) / span, 0), 1)

    case .lowerIsBetter(let idealMax, let hardMax):
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
