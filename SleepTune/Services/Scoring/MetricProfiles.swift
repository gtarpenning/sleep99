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

struct MetricTargetGuidance: Sendable, Equatable {
    let value: Double
    let label: String
}

// MARK: - Effective baseline

/// Returns the baseline value used as the "perfect" reference for a metric.
/// All metrics use an aspirational percentile target (p75 for higher-is-better,
/// p25 for lower-is-better) so the bar is set to good nights, not average nights.
/// Special cases: Duration has an 8h hard floor; HR/HRV/RR use tighter percentiles;
/// Bedtime Consistency and Wrist Temperature use avg as their deviation reference.
/// Used by both the score engine and breakdown display — single source of truth.
func effectiveBaseline(name: String, stats: MetricStats?) -> Double? {
    guard let stats else { return nil }
    switch name {
    case "Sleep Duration":               return max(stats.percentile(0.75), 8.0)
    case "Lowest Overnight HR":          return stats.min
    case "HRV", "Peak HRV",
         "REM Cycle Count":             return stats.percentile(0.75)
    case "Overnight Heart Rate":        return stats.percentile(0.25)
    case "Respiratory Rate":            return stats.percentile(0.10)
    // Deviation-based metrics: avg is the reference point, not an aspirational target
    case "Bedtime Consistency",
         "Wrist Temperature":           return stats.avg
    default:
        guard let def = MetricRegistry.definition(for: name) else { return stats.avg }
        return def.lowerIsBetter ? stats.percentile(0.25) : stats.percentile(0.75)
    }
}

/// Minimum delta considered meaningful given a unit's display precision.
/// Any delta smaller than this would display as "0" and should score/display identically.
func displayPrecisionThreshold(for unit: String, metricName: String? = nil) -> Double {
    switch unit {
    case "bpm", "ms", "min", "x", "cycles", "events": return 1.0
    case "hr":      return 1.0 / 60.0   // 1 minute in hours
    case "%":       return metricName == "Blood Oxygen" ? 0.1 : 1.0
    case "br/min":  return 0.1
    case "fraction": return 0.005
    default:        return 1.0
    }
}

/// Returns extra user-facing guidance for metrics whose "perfect" target comes from
/// percentile-based personal history rather than a plain average.
func metricTargetGuidance(name: String, stats: MetricStats?) -> MetricTargetGuidance? {
    guard let stats else { return nil }

    switch name {
    case "Lowest Overnight HR":
        return MetricTargetGuidance(
            value: stats.min,
            label: "Target set by your lowest night in the last 30."
        )
    case "HRV":
        return MetricTargetGuidance(
            value: stats.percentile(0.75),
            label: "Target set by your top quartile nights over the last 30."
        )
    case "Peak HRV":
        return MetricTargetGuidance(
            value: stats.percentile(0.75),
            label: "Target set by your top quartile peak readings over the last 30."
        )
    case "REM Cycle Count":
        return MetricTargetGuidance(
            value: stats.percentile(0.75),
            label: "Target set by your top quartile nights over the last 30."
        )
    case "Overnight Heart Rate":
        return MetricTargetGuidance(
            value: stats.percentile(0.25),
            label: "Target set by your best 25% of nights over the last 30."
        )
    case "Respiratory Rate":
        return MetricTargetGuidance(
            value: stats.percentile(0.10),
            label: "Target set by your best 10% of nights over the last 30."
        )
    default:
        return nil
    }
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
            // 8h is the hard floor for perfect. Personal avg raises the target further if > 8h.
            // -33% per hour below target. 3h short → 0%.
            let target = max(avg, 8.0)
            if value >= target - 1.0/60.0 { return 1 }   // 1-min display tolerance
            return max(0, 1 - (target - value) / 3.0)

        case "Bedtime Consistency":
            // One-sided: going to bed EARLIER than usual is never penalized.
            // Going LATER: 30-min deadband, then decays to 0 at 1.5h late.
            let delta = max(0, value - avg)
            let deadband = 0.5
            if delta <= deadband { return 1 }
            return max(0, 1 - (delta - deadband) / 1.0)

        case "HRV", "Peak HRV":
            // avg is p75. At or above → perfect.
            // Decay is relative to baseline: 30% below p75 → 0%.
            // e.g. p75=50ms → floor at 35ms; p75=100ms → floor at 70ms.
            if value >= avg - 1.0 { return 1 }   // 1-ms display tolerance
            return max(0, 1 - (avg - value) / (avg * 0.30))

        case "REM Cycle Count":
            // avg is p75 (top-quartile nights). At or above → perfect.
            // -20% per cycle below target: p75-1 = 80%, p75-2 = 60%, p75-5 = 0%.
            if value >= avg - 0.5 { return 1 }
            return max(0, 1 - (avg - value) * 0.20)

        case "Overnight Heart Rate":
            // avg is p25 (best 25% of nights = lowest HR quartile). At or below → perfect.
            // -10% per bpm above p25: +7 bpm → ~30% (≈ 5/15 pts).
            // Full marks only when at/below target to 1-decimal display precision
            // (0.05 epsilon), so a genuine 40.4 vs 40.0 miss costs a little.
            if value <= avg + 0.05 { return 1 }
            return max(0, 1 - (value - avg) * 0.10)

        case "Lowest Overnight HR":
            // avg is the monthly minimum — a night-floor reference.
            // Gentle slope since matching your absolute best night is rare.
            // Same 1-decimal boundary as Overnight Heart Rate: 41 vs a 40 floor
            // (or 40.4 vs 40.0) loses points instead of rounding up to perfect.
            if value <= avg + 0.05 { return 1 }
            return max(0, 1 - (value - avg) * 0.05)

        case "Respiratory Rate":
            // avg is p10 (best 10% / lowest readings) for respiratory rate.
            // At or below → perfect. +1 br/min above p10 → 0,
            // so being at your mean (~0.5–1.5 above p10) still scores ~50–75%.
            if value <= avg + 0.1 { return 1 }   // 0.1 br/min display tolerance
            return max(0, 1 - (value - avg) * 1.0)

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
