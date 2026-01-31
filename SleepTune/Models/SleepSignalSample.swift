import Foundation

struct SleepSignalSample: Hashable {
    var name: String
    var value: Double
    var unit: String
    var date: Date
    var source: SleepIndicatorSource
}
