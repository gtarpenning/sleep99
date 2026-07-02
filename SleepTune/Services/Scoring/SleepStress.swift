import Foundation

/// Sleep Stress — a derived metric capturing autonomic stress during sleep.
/// Combines elevated overnight HR with suppressed HRV, both of which independently
/// suggest sympathetic dominance. Result is 0–100, higher = more stressed.
///
/// This is intentionally simple — a more sophisticated version would use rolling
/// baselines per user, but until we have multi-month data this is the best we can do.
enum SleepStress {

    /// Compute stress score from overnight averages.
    ///
    /// - Parameters:
    ///   - hr: Mean overnight heart rate (bpm). Lower is better.
    ///   - hrv: Mean overnight HRV / SDNN (ms). Higher is better.
    ///   - hrBaseline: Optional personal monthly mean HR (bpm). When provided the HR
    ///                 component is scored relative to this rather than absolute.
    ///   - hrvBaseline: Optional personal monthly mean HRV (ms). Same idea.
    /// - Returns: Stress score 0–100 (higher = worse), or nil if both HR and HRV missing.
    static func compute(
        hr: Double?,
        hrv: Double?,
        hrBaseline: Double? = nil,
        hrvBaseline: Double? = nil
    ) -> Double? {
        // Need at least one signal.
        guard hr != nil || hrv != nil else { return nil }

        // Each component contributes 0–50 to the final score.
        // When both are present they sum to 0–100. With only one, we double its weight
        // so the user still gets a meaningful number.
        let hrComponent  = hrStressComponent(hr: hr, baseline: hrBaseline)
        let hrvComponent = hrvStressComponent(hrv: hrv, baseline: hrvBaseline)

        switch (hrComponent, hrvComponent) {
        case let (h?, v?): return h + v
        case let (h?, nil): return h * 2
        case let (nil, v?): return v * 2
        default:           return nil
        }
    }

    /// 0–50 scale where ideal HR (≤50 bpm or below baseline) = 0 stress,
    /// elevated HR (≥80 bpm or +20 over baseline) = 50.
    private static func hrStressComponent(hr: Double?, baseline: Double?) -> Double? {
        guard let hr else { return nil }
        if let baseline, baseline > 0 {
            // Relative to personal baseline: equal = 0, +20 bpm = 50.
            let delta = hr - baseline
            return clamp(delta / 20.0, 0, 1) * 50
        }
        // Absolute fallback: 50 bpm = 0, 80 bpm = 50.
        return clamp((hr - 50) / 30.0, 0, 1) * 50
    }

    /// 0–50 scale where ideal HRV (≥50 ms or above baseline) = 0 stress,
    /// suppressed HRV (≤15 ms or -25 below baseline) = 50.
    private static func hrvStressComponent(hrv: Double?, baseline: Double?) -> Double? {
        guard let hrv else { return nil }
        if let baseline, baseline > 0 {
            // Relative: equal or higher = 0, -25 ms below = 50.
            let deficit = baseline - hrv
            return clamp(deficit / 25.0, 0, 1) * 50
        }
        // Absolute fallback: 50 ms = 0, 15 ms = 50.
        return clamp((50 - hrv) / 35.0, 0, 1) * 50
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        Swift.max(lo, Swift.min(hi, x))
    }

    /// Categorize a stress score for display labels.
    static func label(for score: Double) -> String {
        switch score {
        case ..<25:     return "Low"
        case ..<50:     return "Moderate"
        case ..<75:     return "Elevated"
        default:        return "High"
        }
    }
}
