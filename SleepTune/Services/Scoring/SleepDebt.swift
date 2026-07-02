import Foundation

/// A single night's contribution to the rolling sleep debt window.
struct SleepDebtNight: Equatable, Sendable {
    let date: Date
    /// Actual hours slept that night.
    let hours: Double
    /// Optional activity load — exercise minutes, used to inflate the debt
    /// when a user trained hard but slept little (recovery deficit).
    let exerciseMinutes: Double?
}

struct SleepDebtSummary: Equatable, Sendable {
    /// Hours behind target across the rolling window. 0 = caught up.
    let totalDebt: Double
    /// Number of nights included.
    let nightsCounted: Int
    /// Average nightly hours over the window.
    let avgHours: Double
    /// Nights where the user slept ≥ target (indicates recovery progress).
    let nightsAtOrAboveTarget: Int

    /// Qualitative bucket — used by the UI to color-code.
    var severity: Severity {
        switch totalDebt {
        case ..<2:    return .none
        case ..<5:    return .mild
        case ..<10:   return .moderate
        default:      return .high
        }
    }

    enum Severity: Equatable, Sendable {
        case none, mild, moderate, high
    }
}

/// Rolling sleep-debt computation. Default targets the last 7 nights against an 8h goal.
enum SleepDebt {

    /// Compute the debt summary.
    ///
    /// - Parameters:
    ///   - nights: Recent nights (any order). Most recent first or last — order doesn't matter.
    ///   - targetHours: Per-night sleep goal (default 8).
    ///   - activityPenaltyPerHour: For every 60 min of exercise above 30 min, add this many
    ///                              hours to that night's debt (default 0.25h, i.e. 15 min).
    ///                              Captures the idea that hard training increases recovery need.
    static func compute(
        nights: [SleepDebtNight],
        targetHours: Double = 8.0,
        activityPenaltyPerHour: Double = 0.25
    ) -> SleepDebtSummary {
        guard !nights.isEmpty else {
            return SleepDebtSummary(totalDebt: 0, nightsCounted: 0, avgHours: 0, nightsAtOrAboveTarget: 0)
        }

        var totalDebt = 0.0
        var totalHours = 0.0
        var atOrAbove = 0

        for night in nights {
            let nightlyDebt = Swift.max(0, targetHours - night.hours)
            // Activity bump: only counts elevated training (>30 min), and only when the user
            // actually slept less than target. Hard workouts on a full 8h don't add debt.
            var bump = 0.0
            if let mins = night.exerciseMinutes, mins > 30, night.hours < targetHours {
                let extraHours = (mins - 30) / 60.0
                bump = extraHours * activityPenaltyPerHour
            }
            totalDebt += nightlyDebt + bump
            totalHours += night.hours
            if night.hours >= targetHours { atOrAbove += 1 }
        }

        return SleepDebtSummary(
            totalDebt: totalDebt,
            nightsCounted: nights.count,
            avgHours: totalHours / Double(nights.count),
            nightsAtOrAboveTarget: atOrAbove
        )
    }

    /// Friendly label for the UI (e.g. "5h behind", "Caught up").
    static func summaryText(for summary: SleepDebtSummary) -> String {
        if summary.totalDebt < 0.5 { return "Caught up" }
        let h = Int(summary.totalDebt.rounded())
        return "\(h)h behind"
    }
}
