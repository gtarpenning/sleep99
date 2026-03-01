/// Top-level category weights for the overall sleep score.
/// Individual metric weights within each category live in MetricRegistry,
/// making it easy to tune or add metrics without touching this file.
struct SleepScoreWeights: Hashable, Codable {
    /// Fraction of the overall score from sleep architecture (duration, stages, latency).
    var architectureWeight: Double = 0.40
    /// Fraction of the overall score from recovery signals (HR, HRV, respiratory rate, etc.).
    var recoveryWeight: Double     = 0.60

    static var `default`: SleepScoreWeights { SleepScoreWeights() }
}
