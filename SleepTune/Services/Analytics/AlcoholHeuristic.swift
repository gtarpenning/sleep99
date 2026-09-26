import Foundation

/// Rough "did I drink last night?" detector.
///
/// Alcohol shows up as a night-long heart-rate elevation (typically 15–25 %
/// over baseline), suppressed HRV, thinner deep sleep, and a heart-rate
/// trough that arrives late. Each signal adds points; ≥ 3 flags the night,
/// 2 marks it "possible". Baselines should come from weekday nights so the
/// comparison isn't already polluted by weekends.
enum AlcoholHeuristic {

    struct Baseline: Sendable, Equatable {
        let avgHR: Double
        var hrv: Double? = nil
        var deepMinutes: Double? = nil
        /// Minutes from sleep onset to the HR minimum.
        var minutesToLowestHR: Double? = nil
    }

    struct Night: Sendable, Equatable {
        let avgHR: Double
        var hrv: Double? = nil
        var deepMinutes: Double? = nil
        var minutesToLowestHR: Double? = nil
    }

    enum Verdict: Equatable, Sendable { case none, possible, likely }

    struct Result: Equatable, Sendable {
        let verdict: Verdict
        let points: Int
        /// Fractional HR elevation vs baseline, e.g. 0.22 = +22 %.
        let hrElevation: Double
        /// Fractional HRV drop vs baseline, positive means lower HRV.
        let hrvDrop: Double?
        let deepDrop: Double?
        let troughDelayMinutes: Double?

        var reasons: [String] {
            var out: [String] = []
            if hrElevation >= AlcoholHeuristic.weakHR {
                out.append("HR +\(Int((hrElevation * 100).rounded()))%")
            }
            if let d = hrvDrop, d >= AlcoholHeuristic.hrvDropThreshold {
                out.append("HRV −\(Int((d * 100).rounded()))%")
            }
            if let d = deepDrop, d >= AlcoholHeuristic.deepDropThreshold {
                out.append("Deep −\(Int((d * 100).rounded()))%")
            }
            if let t = troughDelayMinutes, t >= AlcoholHeuristic.troughDelayThreshold {
                out.append("Late HR low +\(Int(t.rounded()))m")
            }
            return out
        }
    }

    static let strongHR = 0.20
    static let weakHR   = 0.12
    static let hrvDropThreshold  = 0.25
    static let deepDropThreshold = 0.40
    static let troughDelayThreshold = 90.0
    static let likelyPoints   = 3
    static let possiblePoints = 2
    /// Baselines need at least this many nights to be trusted.
    static let minBaselineNights = 7

    static func evaluate(night: Night, baseline: Baseline) -> Result {
        guard baseline.avgHR > 0 else {
            return Result(verdict: .none, points: 0, hrElevation: 0, hrvDrop: nil, deepDrop: nil, troughDelayMinutes: nil)
        }
        var points = 0
        let elevation = night.avgHR / baseline.avgHR - 1
        if elevation >= strongHR { points += 2 } else if elevation >= weakHR { points += 1 }

        var hrvDrop: Double? = nil
        if let h = night.hrv, let b = baseline.hrv, b > 0 {
            hrvDrop = 1 - h / b
            if hrvDrop! >= hrvDropThreshold { points += 1 }
        }
        var deepDrop: Double? = nil
        if let d = night.deepMinutes, let b = baseline.deepMinutes, b > 0 {
            deepDrop = 1 - d / b
            if deepDrop! >= deepDropThreshold { points += 1 }
        }
        var delay: Double? = nil
        if let t = night.minutesToLowestHR, let b = baseline.minutesToLowestHR {
            delay = t - b
            if delay! >= troughDelayThreshold { points += 1 }
        }

        // HR elevation is the anchor signal; without at least a weak elevation,
        // the secondary signals alone (illness, hard training) shouldn't flag.
        let verdict: Verdict
        if elevation < weakHR {
            verdict = .none
        } else if points >= likelyPoints {
            verdict = .likely
        } else if points >= possiblePoints {
            verdict = .possible
        } else {
            verdict = .none
        }
        return Result(verdict: verdict, points: points, hrElevation: elevation,
                      hrvDrop: hrvDrop, deepDrop: deepDrop, troughDelayMinutes: delay)
    }

    // MARK: - Building inputs from night records

    /// Baseline from weekday nights (falls back to all nights), excluding nights
    /// already flagged as alcohol so the reference doesn't drift upward.
    static func baseline(from history: [NightSummary]) -> Baseline? {
        let clean = history.filter { $0.alcoholFlag != true && ($0.avgHR ?? 0) > 0 }
        var pool = clean.filter { $0.dayType == .weekday }
        if pool.count < minBaselineNights { pool = clean }
        guard pool.count >= minBaselineNights else { return nil }
        func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
        return Baseline(
            avgHR: mean(pool.compactMap(\.avgHR)) ?? 0,
            hrv: mean(pool.compactMap(\.hrv)),
            deepMinutes: mean(pool.compactMap(\.deepMinutes)),
            minutesToLowestHR: mean(pool.compactMap { $0.metrics["Time to Lowest HR"] }.map { $0 * 60 })
        )
    }

    static func night(from n: NightSummary) -> Night? {
        guard let hr = n.avgHR, hr > 0 else { return nil }
        return Night(
            avgHR: hr,
            hrv: n.hrv,
            deepMinutes: n.deepMinutes,
            minutesToLowestHR: n.metrics["Time to Lowest HR"].map { $0 * 60 }
        )
    }

    static func night(from indicators: [SleepIndicator]) -> Night? {
        func v(_ name: String) -> Double? { indicators.first(where: { $0.name == name })?.value }
        guard let hr = v("Overnight Heart Rate"), hr > 0 else { return nil }
        return Night(avgHR: hr, hrv: v("HRV"), deepMinutes: v("Deep Sleep"),
                     minutesToLowestHR: v("Time to Lowest HR").map { $0 * 60 })
    }
}
