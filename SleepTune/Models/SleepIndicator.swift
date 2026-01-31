import Foundation

struct SleepIndicator: Identifiable, Hashable {
    let id: UUID
    var name: String
    var detail: String
    var value: Double
    var unit: String
    var category: SleepIndicatorCategory
    var source: SleepIndicatorSource
    var range: ClosedRange<Double>?
    var contribution: Double
    var isManualOverride: Bool

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
        self.range = range
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
            source: .manual
        )
    }
}
