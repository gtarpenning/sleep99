enum SleepSignalType: String, CaseIterable, Hashable {
    case heartRate = "HKQuantityTypeIdentifierHeartRate"
    case heartRateVariability = "HKQuantityTypeIdentifierHeartRateVariabilitySDNN"
    case respiratoryRate = "HKQuantityTypeIdentifierRespiratoryRate"

    var displayName: String {
        switch self {
        case .heartRate:
            return "Heart Rate"
        case .heartRateVariability:
            return "HRV"
        case .respiratoryRate:
            return "Respiratory Rate"
        }
    }
}
