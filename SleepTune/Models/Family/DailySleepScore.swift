import Foundation

struct DailySleepScore: Identifiable, Hashable {
    let id: String
    var memberID: String
    var date: Date
    var score: Double
    var sleepScore: Double
    var recoveryScore: Double
    var totalSleepMinutes: Int
    var primarySource: SleepIndicatorSource

    var scoreLabel: String {
        switch score {
        case 85...:    return "Excellent"
        case 70..<85:  return "Good"
        case 55..<70:  return "Fair"
        default:       return "Poor"
        }
    }
}
