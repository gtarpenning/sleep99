import Foundation

struct LastNightMetrics: Hashable {
    var sleepStart: Date?
    var lowestHeartRate: Double?
    var lowestHeartRateTime: Date?
    var averageHRV: Double?

    static let empty = LastNightMetrics(
        sleepStart: nil,
        lowestHeartRate: nil,
        lowestHeartRateTime: nil,
        averageHRV: nil
    )
}
