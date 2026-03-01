import Foundation

enum SleepScoreTrendRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:  return "Week"
        case .month: return "Month"
        }
    }

    var daySpan: Int {
        switch self {
        case .week:  return 7
        case .month: return 30
        }
    }
}
