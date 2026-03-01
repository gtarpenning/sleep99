import Foundation

struct SleepScoreTrendPoint: Identifiable, Hashable {
    var date: Date
    var score: Double
    /// Sub-score for sleep architecture (duration, stages, latency). nil for legacy data.
    var sleepScore: Double?
    /// Sub-score for recovery signals (HR, HRV, respiratory rate). nil for legacy data.
    var recoveryScore: Double?

    var id: Date { date }
}
