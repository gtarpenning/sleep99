import Foundation

struct SleepIndicator: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var detail: String
    var value: Double
    var unit: String
    var category: SleepIndicatorCategory
    var source: SleepIndicatorSource
    var rangeMin: Double?
    var rangeMax: Double?
    var contribution: Double
    var isManualOverride: Bool

    var range: ClosedRange<Double>? {
        get {
            guard let min = rangeMin, let max = rangeMax else { return nil }
            return min...max
        }
        set {
            rangeMin = newValue?.lowerBound
            rangeMax = newValue?.upperBound
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        value: Double,
        unit: String,
        category: SleepIndicatorCategory,
        source: SleepIndicatorSource,
        range: ClosedRange<Double>? = nil,
        contribution: Double = 0,
        isManualOverride: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.value = value
        self.unit = unit
        self.category = category
        self.source = source
        self.rangeMin = range?.lowerBound
        self.rangeMax = range?.upperBound
        self.contribution = contribution
        self.isManualOverride = isManualOverride
    }

    static var placeholder: SleepIndicator {
        SleepIndicator(
            name: "Placeholder",
            detail: "",
            value: 0,
            unit: "",
            category: .recovery,
            source: .appleHealth
        )
    }
}
