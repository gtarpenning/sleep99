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

    /// Personal-average with a flat perfect zone. Score = 1 within `deadband` of monthlyAvg,
    /// then linear decay to 0 at `hardMax` away. Falls back to `fallback` with no history.
    case personalAverageDeadband(deadband: Double, hardMax: Double, fallback: Double = 0.5)

    /// Lower-than-personal-average is perfect. Score = 1 when value ≤ monthlyAvg,
    /// decays linearly to 0 at monthlyAvg + hardMaxDelta. Falls back to `fallback` with no history.
    case lowerIsBetterRelative(hardMaxDelta: Double, fallback: Double = 0.5)
}

// MARK: - Scoring function

/// Converts a raw value to a 0…1 score.
/// Scoring shapes and parameters come from MetricRegistry — add metrics there, not here.
func scoreMetric(name: String, value: Double, monthlyAvg: Double?) -> Double? {
    guard let shape = MetricRegistry.definition(for: name)?.scoring else { return nil }

    // Blood Oxygen: combines an absolute quality floor with a steep personal decay.
    // Handled before the avg-only block because both curves apply regardless of history.
    if name == "Blood Oxygen" {
        // Absolute curve: 97%+ = perfect, exactly 95% = 1/3, 88% = 0.
        // 95–97%: linear ramp 1/3 → 1.0
        // 88–95%: linear ramp 0 → 1/3
        let absoluteScore: Double = {
            if value >= 97 { return 1.0 }
            if value >= 95 { return 1.0/3.0 + (value - 95.0) / 2.0 * (2.0/3.0) }
            return max(0, (value - 88.0) / 7.0 * (1.0/3.0))
        }()

        if let avg = monthlyAvg {
            // At or above personal avg: absolute floor is the score (e.g. avg of 96% still isn't perfect).
            if value >= avg { return absoluteScore }
            // 1% below avg → −30 pts. Take the more conservative of personal and absolute.
            let personalScore = max(0.0, 1.0 - (avg - value) * 0.30)
            return min(personalScore, absoluteScore)
        }

        return absoluteScore
    }

    // Per-metric sensitivity tuning when we have a personal baseline.
    // These curves intentionally penalize meaningful regressions harder than the generic
    // hardMin/idealMin and idealMax/hardMax shapes.
    if let avg = monthlyAvg {
        switch name {
        case "Sleep Duration":
            // At or above avg → 100%. -25% per hour below avg. 4h short → 0%.
            if value >= avg { return 1 }
            return max(0, 1 - (avg - value) / 4.0)

        case "HRV":
            // 10 ms below baseline -> 50% score. 20 ms below baseline -> ~0%.
            if value >= avg { return 1 }
            return max(0, 1 - (avg - value) / 20)

        case "Overnight Heart Rate", "Lowest Overnight HR":
            // -10% per bpm above personal avg. At or below = perfect.
            // +3 bpm → 70%, +10 bpm → 0%.
            if value <= avg { return 1 }
            return max(0, 1 - (value - avg) * 0.10)

        case "Respiratory Rate":
            // Very sensitive: +0.2 br/min above avg = -30%. At or below = perfect.
            // Slope: 1.5 per br/min → 0.3 penalty per 0.2 br/min.
            if value <= avg { return 1 }
            return max(0, 1 - (value - avg) * 1.5)

        default:
            break
        }
    }

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

    case .personalAverageDeadband(let deadband, let hardMax, let fallback):
        guard let avg = monthlyAvg else { return fallback }
        let delta = abs(value - avg)
        if delta <= deadband { return 1 }
        let decaySpan = hardMax - deadband
        guard decaySpan > 0 else { return 0 }
        return max(0, 1 - (delta - deadband) / decaySpan)

    case .lowerIsBetterRelative(let hardMaxDelta, let fallback):
        guard let avg = monthlyAvg else { return fallback }
        if value <= avg { return 1 }
        guard hardMaxDelta > 0 else { return 0 }
        return max(0, 1 - (value - avg) / hardMaxDelta)
    }
}
