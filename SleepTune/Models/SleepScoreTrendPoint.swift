import Foundation

struct SleepScoreTrendPoint: Identifiable, Hashable {
    var date: Date
    var score: Double

    var id: Date {
        date
    }
}
