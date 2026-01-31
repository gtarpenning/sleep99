import Foundation

enum SleepScoreTrendRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        }
    }

    var daySpan: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        }
    }
}
