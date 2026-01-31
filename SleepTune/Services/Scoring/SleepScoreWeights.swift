struct SleepScoreWeights: Hashable {
    var duration: Double
    var efficiency: Double
    var consistency: Double
    var recovery: Double
    var architecture: Double
    var environment: Double
    var behavior: Double

    static var `default`: SleepScoreWeights {
        SleepScoreWeights(
            duration: 0.22,
            efficiency: 0.18,
            consistency: 0.16,
            recovery: 0.18,
            architecture: 0.16,
            environment: 0.05,
            behavior: 0.05
        )
    }
}
