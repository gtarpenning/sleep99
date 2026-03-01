enum SleepIndicatorCategory: String, CaseIterable, Hashable, Codable {
    case recovery
    case sleepArchitecture
    case behavior

    var displayName: String {
        switch self {
        case .recovery:          return "Recovery"
        case .sleepArchitecture: return "Sleep"
        case .behavior:          return "Activity"
        }
    }

    var iconName: String {
        switch self {
        case .recovery:          return "heart.fill"
        case .sleepArchitecture: return "moon.fill"
        case .behavior:          return "figure.walk"
        }
    }
}
