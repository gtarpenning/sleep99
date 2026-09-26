import Foundation

/// A single night's contribution to the sleep debt estimate.
struct SleepDebtNight: Equatable, Sendable {
    let date: Date
    /// Actual hours slept that night.
    let hours: Double
}

struct SleepDebtSummary: Equatable, Sendable {
    /// Recency-weighted hours behind your personal sleep need. 0 = caught up.
    let totalDebt: Double
    /// Number of nights included.
    let nightsCounted: Int
    /// Average nightly hours over the window.
    let avgHours: Double
    /// Personal sleep need (hours) the debt is measured against.
    let need: Double
    /// Whether the debt is shrinking or growing vs. three nights ago.
    let trend: Trend

    enum Trend: Equatable, Sendable {
        case improving, steady, worsening
    }

    /// Qualitative bucket — used by the UI to color-code.
    var severity: Severity {
        switch totalDebt {
        case ..<1:    return .none
        case ..<2.5:  return .mild
        case ..<5:    return .moderate
        default:      return .high
        }
    }

    enum Severity: Equatable, Sendable {
        case none, mild, moderate, high
    }
}

/// Recency-weighted sleep debt.
///
/// Each night contributes its shortfall against a *personal* sleep need,
/// discounted by `decay^age` — so a bad night's influence halves roughly every
/// two nights and is negligible after ten. Surplus sleep repays debt at half
/// rate: recovery sleep genuinely helps, but lost sleep is never repaid
/// hour-for-hour. The result is bounded — debt melts on its own instead of
/// accumulating forever.
enum SleepDebt {

    /// Per-night exponential decay. At 0.7, two normal nights take a 1h debt
    /// below the 0.5h "caught up" threshold.
    static let decay = 0.7
    /// Fraction of a surplus hour that counts as repayment.
    static let surplusCredit = 0.5
    /// Fallback need when there isn't enough history to estimate one.
    static let defaultNeed = 7.5
    /// Nights of history worth fetching — beyond this, weight is under 3%.
    static let windowNights = 10
    /// Nights under this are almost certainly tracking failures (watch died,
    /// not worn), not real sleep — excluded rather than counted as deficit.
    static let minValidHours = 3.0

    /// Personal sleep need: p60 of recent nightly durations, clamped to 6.5–9h.
    /// A high-ish percentile beats the mean (which is dragged down by the short
    /// nights we're measuring against); the floor keeps chronic short sleepers
    /// from defining their deprivation away.
    static func sleepNeed(from stats: MetricStats?) -> Double {
        guard let stats, stats.count >= 5 else { return defaultNeed }
        return Swift.min(9.0, Swift.max(6.5, stats.percentile(0.6)))
    }

    /// Compute the debt summary.
    ///
    /// - Parameters:
    ///   - nights: Recent nights (any order). Gaps are fine — age is taken from
    ///             each night's date, not its position. Nights under
    ///             `minValidHours` are dropped as tracking noise.
    ///   - need: Per-night sleep need (see `sleepNeed(from:)`).
    static func compute(
        nights: [SleepDebtNight],
        need: Double = defaultNeed
    ) -> SleepDebtSummary {
        let nights = nights.filter { $0.hours >= minValidHours }
        guard !nights.isEmpty else {
            return SleepDebtSummary(totalDebt: 0, nightsCounted: 0, avgHours: 0, need: need, trend: .steady)
        }

        let cal = Calendar.current
        let reference = nights.map(\.date).max()!
        let aged: [(age: Int, hours: Double)] = nights.map { night in
            let days = cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: night.date),
                to: cal.startOfDay(for: reference)
            ).day ?? 0
            return (Swift.max(0, days), night.hours)
        }

        let current = weightedDebt(aged, need: need)
        // Debt as it stood three nights ago — the trend's comparison point.
        let past = weightedDebt(
            aged.filter { $0.age >= 3 }.map { (age: $0.age - 3, hours: $0.hours) },
            need: need
        )

        let trend: SleepDebtSummary.Trend
        switch current - past {
        case ..<(-0.25): trend = .improving
        case ...0.25:    trend = .steady
        default:         trend = .worsening
        }

        return SleepDebtSummary(
            totalDebt: current,
            nightsCounted: nights.count,
            avgHours: nights.map(\.hours).reduce(0, +) / Double(nights.count),
            need: need,
            trend: trend
        )
    }

    private static func weightedDebt(_ nights: [(age: Int, hours: Double)], need: Double) -> Double {
        var debt = 0.0
        for night in nights {
            let delta = need - night.hours
            let contribution = delta >= 0 ? delta : delta * surplusCredit
            debt += contribution * pow(decay, Double(night.age))
        }
        return Swift.min(Swift.max(0, debt), need * 2)
    }

    /// Friendly label for the UI (e.g. "2.5h behind", "Caught up").
    static func summaryText(for summary: SleepDebtSummary) -> String {
        if summary.totalDebt < 0.5 { return "Caught up" }
        let rounded = (summary.totalDebt * 2).rounded() / 2
        let text = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
        return "\(text)h behind"
    }
}
