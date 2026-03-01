enum SleepIndicatorSource: String, CaseIterable, Hashable, Codable {
    case appleWatch
    case appleHealth
    case oura
    case whoop
    case inferred
    case otherDevice

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .appleHealth: return "Apple Health"
        case .oura: return "Oura Ring"
        case .whoop: return "Whoop"
        case .inferred: return "Inferred"
        case .otherDevice: return "Other Device"
        }
    }
}
