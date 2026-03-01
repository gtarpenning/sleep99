struct SleepScoreWeights: Hashable, Codable {
    // Architecture sub-weights (should sum to 1.0)
    var duration: Double    = 0.35  // 8h = perfect
    var efficiency: Double  = 0.20
    var latency: Double     = 0.20  // <10 min = perfect, inverted
    var remPercent: Double  = 0.15  // monthly-avg-relative
    var deepPercent: Double = 0.10  // monthly-avg-relative

    // Recovery sub-weights (should sum to 1.0)
    var lowestHR: Double       = 0.30  // monthly-avg-relative, inverted
    var avgHRV: Double         = 0.30
    var avgRR: Double          = 0.20
    var timeToLowestHR: Double = 0.15  // earlier in sleep = better
    var spo2: Double           = 0.05

    // Top-level category weights (sum to 1.0)
    var architectureWeight: Double = 0.40
    var recoveryWeight: Double     = 0.60

    static var `default`: SleepScoreWeights { SleepScoreWeights() }
}
