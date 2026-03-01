import Foundation

/// Aggregated statistics for a single metric over a historical window (typically 30 days).
/// Computed from cached SleepIndicator values — all metrics including calculated ones
/// (Time to Lowest HR, Lowest Overnight HR, etc.) are covered as long as they've been cached.
struct MetricStats: Sendable {
    let avg: Double
    let min: Double
    let max: Double
    /// Number of nights contributing to these stats.
    let count: Int

    /// 0–1 position of `value` within the observed min–max range.
    /// Used for placing a marker on a range bar.
    func normalizedPosition(of value: Double) -> Double {
        guard max > min else { return 0.5 }
        return Swift.min(Swift.max((value - min) / (max - min), 0), 1)
    }

    var normalizedAvg: Double { normalizedPosition(of: avg) }
}
