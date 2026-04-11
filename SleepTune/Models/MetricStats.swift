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
    /// Raw values sorted ascending — used for percentile-based scoring thresholds.
    let sortedValues: [Double]

    init(avg: Double, min: Double, max: Double, count: Int, sortedValues: [Double] = []) {
        self.avg = avg
        self.min = min
        self.max = max
        self.count = count
        self.sortedValues = sortedValues
    }

    /// Returns the value at the given percentile (0.0–1.0) using linear interpolation.
    /// Falls back to `avg` when fewer than 2 data points are available.
    func percentile(_ p: Double) -> Double {
        guard sortedValues.count >= 2 else { return avg }
        let clamped = Swift.max(0, Swift.min(1, p))
        let idx = clamped * Double(sortedValues.count - 1)
        let lo = Int(idx)
        let hi = Swift.min(lo + 1, sortedValues.count - 1)
        let frac = idx - Double(lo)
        return sortedValues[lo] * (1 - frac) + sortedValues[hi] * frac
    }

    /// 0–1 position of `value` within the observed min–max range.
    /// Used for placing a marker on a range bar.
    func normalizedPosition(of value: Double) -> Double {
        guard max > min else { return 0.5 }
        return Swift.min(Swift.max((value - min) / (max - min), 0), 1)
    }

    var normalizedAvg: Double { normalizedPosition(of: avg) }
}
