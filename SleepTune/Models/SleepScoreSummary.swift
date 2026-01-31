import Foundation

struct SleepScoreSummary: Hashable {
    var date: Date
    var score: Double
    var trend: Double
    var components: [SleepScoreComponent]
    var confidence: Double
    var note: String
}
