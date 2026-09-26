import Foundation

/// A single night's inputs to the sleep debt estimate. `date` is the wake date.
struct SleepDebtNight: Equatable, Sendable {
    let date: Date
    /// Hours asleep.
    let hours: Double
    /// Sleep efficiency in percent (0–100), if known.
    var efficiencyPercent: Double? = nil
    /// Deep + REM minutes, if known.
    var deepRemMinutes: Double? = nil
    /// Exercise minutes logged the day before this night.
    var exerciseMinutesPrevDay: Double? = nil
    /// Sleep score for the night, used only to pick the best-rested stretch
    /// when estimating baseline need.
    var score: Double? = nil

    init(date: Date, hours: Double, efficiencyPercent: Double? = nil, deepRemMinutes: Double? = nil,
         exerciseMinutesPrevDay: Double? = nil, score: Double? = nil) {
        self.date = date
        self.hours = hours
        self.efficiencyPercent = efficiencyPercent
        self.deepRemMinutes = deepRemMinutes
        self.exerciseMinutesPrevDay = exerciseMinutesPrevDay
        self.score = score
    }

    init(_ n: NightSummary) {
        self.init(
            date: n.night,
            hours: n.durationHours ?? 0,
            efficiencyPercent: n.efficiencyPercent,
            deepRemMinutes: (n.deepMinutes ?? 0) + (n.remMinutes ?? 0) > 0 ? (n.deepMinutes ?? 0) + (n.remMinutes ?? 0) : nil,
            exerciseMinutesPrevDay: n.exerciseMinutes,
            score: n.score > 0 ? n.score : nil
        )
    }
}

/// One row of the 14-night ledger shown in the debt card.
struct SleepDebtLedgerEntry: Equatable, Sendable, Identifiable {
    let date: Date
    /// Need for that night (baseline + strain bonus).
    let need: Double
    /// Quality-adjusted hours actually banked.
    let effectiveHours: Double
    /// Raw hours asleep.
    let hours: Double
    /// Weight this night carries in the total.
    let weight: Double
    var id: Date { date }
    /// Positive = shortfall.
    var delta: Double { need - effectiveHours }
}

struct SleepDebtSummary: Equatable, Sendable {
    /// Weighted hours behind need over the last 14 nights, floor 0.
    let totalDebt: Double
    let nightsCounted: Int
    let avgHours: Double
    /// Baseline nightly need before strain adjustments.
    let need: Double
    let trend: Trend
    /// Most recent night last.
    let ledger: [SleepDebtLedgerEntry]

    enum Trend: Equatable, Sendable { case improving, steady, worsening }

    enum Severity: Equatable, Sendable { case low, mild, moderate, high }

    /// Rise-style framing: anything under the target is fine, nothing is "zero".
    var severity: Severity {
        let t = SleepDebt.targetDebt
        if totalDebt < t * 0.6 { return .low }
        if totalDebt < t       { return .mild }
        if totalDebt < t * 1.6 { return .moderate }
        return .high
    }

    init(totalDebt: Double, nightsCounted: Int, avgHours: Double, need: Double, trend: Trend,
         ledger: [SleepDebtLedgerEntry] = []) {
        self.totalDebt = totalDebt
        self.nightsCounted = nightsCounted
        self.avgHours = avgHours
        self.need = need
        self.trend = trend
        self.ledger = ledger
    }
}

/// 14-night weighted sleep debt.
///
/// Modelled on how Rise, Whoop and Garmin frame it:
///   need_t   = baseline + strain bonus (prior-day exercise)
///   banked_t = hours × quality factor (efficiency, deep+REM vs personal baseline)
///   debt     = Σ w_k · (need − banked)   over the last 14 nights
///
/// Weights sum to `weightTotal`, with the most recent night carrying 15 % and
/// the remaining 85 % declining geometrically over the prior 13 nights. So a
/// steady 1 h nightly shortfall reads as `weightTotal` hours of debt — right
/// on the "keep it under 5 h" line Rise recommends.
enum SleepDebt {

    static let windowNights   = 14
    static let weightTotal    = 5.0
    static let lastNightShare = 0.15
    static let decayRatio     = 0.85
    static let surplusCredit  = 0.5
    static let targetDebt     = 5.0
    static let defaultNeed    = 7.5
    /// Nights under this are almost certainly tracking failures, not sleep.
    static let minValidHours  = 3.0
    /// Quality factor never removes more than this fraction of a night.
    static let minQualityFactor = 0.7

    // MARK: - Weights

    /// `weights[k]` is the weight of the night `k` nights before the selected one.
    static let weights: [Double] = {
        let first = weightTotal * lastNightShare
        let restTotal = weightTotal - first
        let n = windowNights - 1
        let a = restTotal * (1 - decayRatio) / (1 - pow(decayRatio, Double(n)))
        return [first] + (0..<n).map { a * pow(decayRatio, Double($0)) }
    }()

    // MARK: - Need

    /// Baseline need: p75 of durations in the best-rested 14-night stretch
    /// (highest mean score) of the supplied history, clamped 6.5–9 h.
    /// With fewer than 14 scored nights, falls back to p60 of whatever exists;
    /// with fewer than 5, to `defaultNeed`. Unlike a rolling mean, this does
    /// not chase a bad fortnight downwards.
    static func baselineNeed(from history: [SleepDebtNight]) -> Double {
        let valid = history.filter { $0.hours >= minValidHours }.sorted { $0.date < $1.date }
        guard valid.count >= 5 else { return defaultNeed }
        let scored = valid.filter { $0.score != nil }
        let window = windowNights
        if scored.count >= window {
            var best: (mean: Double, hours: [Double])? = nil
            for start in 0...(scored.count - window) {
                let slice = scored[start..<(start + window)]
                let mean = slice.compactMap(\.score).reduce(0, +) / Double(window)
                if best == nil || mean > best!.mean {
                    best = (mean, slice.map(\.hours))
                }
            }
            if let best {
                return clampNeed(percentile(best.hours, 0.75))
            }
        }
        return clampNeed(percentile(valid.map(\.hours), 0.6))
    }

    static func clampNeed(_ v: Double) -> Double { Swift.min(9.0, Swift.max(6.5, v)) }

    /// Extra need from a hard day: 15 min per hour of exercise beyond 45 min, up to 30 min.
    static func strainBonus(exerciseMinutes: Double?) -> Double {
        guard let m = exerciseMinutes, m > 45 else { return 0 }
        return Swift.min(0.5, 0.25 * (m - 45) / 60)
    }

    /// Quality-adjusted hours. Efficiency under 85 % and deep+REM under the
    /// personal baseline both shrink what a night is worth, bounded at 30 %.
    static func effectiveHours(_ n: SleepDebtNight, baselineDeepRem: Double?) -> Double {
        var factor = 1.0
        if let eff = n.efficiencyPercent, eff > 0 {
            factor *= Swift.min(1, eff / 85)
        }
        if let dr = n.deepRemMinutes, let base = baselineDeepRem, base > 0 {
            factor *= 1 - 0.5 * Swift.max(0, (base - dr) / base)
        }
        return n.hours * Swift.max(minQualityFactor, factor)
    }

    // MARK: - Compute

    /// - Parameters:
    ///   - nights: Up to 14 nights ending at the selected night. Order doesn't
    ///     matter; age is taken from each date relative to the newest.
    ///   - need: Baseline need, from `baselineNeed(from:)`.
    ///   - baselineDeepRem: Personal average deep+REM minutes, if known.
    static func compute(
        nights: [SleepDebtNight],
        need: Double = defaultNeed,
        baselineDeepRem: Double? = nil
    ) -> SleepDebtSummary {
        let valid = nights.filter { $0.hours >= minValidHours }
        guard let reference = valid.map(\.date).max() else {
            return SleepDebtSummary(totalDebt: 0, nightsCounted: 0, avgHours: 0, need: need, trend: .steady)
        }
        let cal = Calendar.current
        let refDay = cal.startOfDay(for: reference)

        var ledger: [SleepDebtLedgerEntry] = []
        var aged: [(age: Int, delta: Double)] = []
        for n in valid {
            let age = cal.dateComponents([.day], from: cal.startOfDay(for: n.date), to: refDay).day ?? 0
            guard age >= 0, age < windowNights else { continue }
            let nightNeed = need + strainBonus(exerciseMinutes: n.exerciseMinutesPrevDay)
            let banked = effectiveHours(n, baselineDeepRem: baselineDeepRem)
            ledger.append(SleepDebtLedgerEntry(
                date: cal.startOfDay(for: n.date), need: nightNeed, effectiveHours: banked,
                hours: n.hours, weight: weights[age]
            ))
            aged.append((age, nightNeed - banked))
        }
        ledger.sort { $0.date < $1.date }

        let current = weightedDebt(aged, need: need)
        let past = weightedDebt(
            aged.filter { $0.age >= 3 }.map { (age: $0.age - 3, delta: $0.delta) },
            need: need
        )
        let trend: SleepDebtSummary.Trend
        switch current - past {
        case ..<(-0.5): trend = .improving
        case ...0.5:    trend = .steady
        default:        trend = .worsening
        }

        return SleepDebtSummary(
            totalDebt: current,
            nightsCounted: ledger.count,
            avgHours: ledger.map(\.hours).reduce(0, +) / Double(Swift.max(ledger.count, 1)),
            need: need,
            trend: trend,
            ledger: ledger
        )
    }

    private static func weightedDebt(_ nights: [(age: Int, delta: Double)], need: Double) -> Double {
        var debt = 0.0
        for n in nights where n.age < windowNights {
            let contribution = n.delta >= 0 ? n.delta : n.delta * surplusCredit
            debt += contribution * weights[n.age]
        }
        return Swift.min(Swift.max(0, debt), need * 2)
    }

    // MARK: - Formatting

    static func hoursText(_ h: Double) -> String {
        let rounded = (h * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded))h"
            : "\(rounded.formatted(.number.precision(.fractionLength(1))))h"
    }

    static func summaryText(for summary: SleepDebtSummary) -> String {
        hoursText(summary.totalDebt)
    }

    private static func percentile(_ values: [Double], _ p: Double) -> Double {
        let s = values.sorted()
        guard s.count >= 2 else { return s.first ?? defaultNeed }
        let idx = p * Double(s.count - 1)
        let lo = Int(idx), hi = Swift.min(lo + 1, s.count - 1)
        let frac = idx - Double(lo)
        return s[lo] * (1 - frac) + s[hi] * frac
    }
}
