import Foundation

struct SleepScoreSummary: Hashable {
    var date: Date
    var score: Double
    var trend: Double
    var sleepScore: Double
    var recoveryScore: Double
    var confidence: Double
    var primarySource: SleepIndicatorSource
}
