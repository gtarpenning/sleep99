import Foundation
import SwiftUI

/// Every metric the Trends screen can chart, with how to read it off a night.
enum TrendMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case score, sleepingHR, hrv, respiratoryRate, duration, deep, rem, efficiency
    case steps, exercise, peakHR, vo2Max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .score:           return "Score"
        case .sleepingHR:      return "Sleeping HR"
        case .hrv:             return "HRV"
        case .respiratoryRate: return "Resp. rate"
        case .duration:        return "Duration"
        case .deep:            return "Deep"
        case .rem:             return "REM"
        case .efficiency:      return "Efficiency"
        case .steps:           return "Steps"
        case .exercise:        return "Exercise"
        case .peakHR:          return "Peak HR"
        case .vo2Max:          return "VO₂ max"
        }
    }

    var unit: String {
        switch self {
        case .score, .steps:   return ""
        case .sleepingHR, .peakHR: return "bpm"
        case .hrv:             return "ms"
        case .respiratoryRate: return "br/min"
        case .duration:        return "h"
        case .deep, .rem, .exercise: return "min"
        case .efficiency:      return "%"
        case .vo2Max:          return "mL/kg/min"
        }
    }

    /// Activity metrics describe the *previous day*; sleep metrics the night.
    var isActivity: Bool {
        switch self {
        case .steps, .exercise, .peakHR, .vo2Max: return true
        default: return false
        }
    }

    var lowerIsBetter: Bool {
        switch self {
        case .sleepingHR, .respiratoryRate: return true
        default: return false
        }
    }

    var color: Color {
        switch self {
        case .score:           return DS.purple
        case .sleepingHR:      return Color(red: 1.0, green: 0.36, blue: 0.42)
        case .hrv:             return Color(red: 0.36, green: 0.9, blue: 0.62)
        case .respiratoryRate: return Color(red: 0.45, green: 0.7, blue: 1.0)
        case .duration:        return DS.sleepArc
        case .deep:            return DS.stageColor(for: .asleepDeep)
        case .rem:             return DS.recoveryArc
        case .efficiency:      return DS.consistencyArc
        case .steps:           return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .exercise:        return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .peakHR:          return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .vo2Max:          return Color(red: 0.15, green: 0.85, blue: 0.88)
        }
    }

    func value(from n: NightSummary) -> Double? {
        switch self {
        case .score:           return n.score > 0 ? n.score : nil
        case .sleepingHR:      return n.avgHR
        case .hrv:             return n.hrv
        case .respiratoryRate: return n.respiratoryRate
        case .duration:        return n.durationHours
        case .deep:            return n.deepMinutes
        case .rem:             return n.remMinutes
        case .efficiency:      return n.efficiencyPercent
        case .steps:           return n.steps
        case .exercise:        return n.exerciseMinutes
        case .peakHR:          return n.peakHR
        case .vo2Max:          return n.vo2Max
        }
    }

    func format(_ v: Double) -> String {
        switch self {
        case .score, .deep, .rem, .exercise, .sleepingHR, .peakHR, .hrv:
            return "\(Int(v.rounded()))\(unit.isEmpty ? "" : " " + unit)"
        case .steps:
            return v.formatted(.number.precision(.fractionLength(0)))
        case .duration:
            return "\(Int(v))h \(Int((v - Double(Int(v))) * 60))m"
        case .efficiency:
            return "\(Int(v.rounded()))%"
        case .respiratoryRate, .vo2Max:
            return "\(v.formatted(.number.precision(.fractionLength(1)))) \(unit)"
        }
    }

    static let sleepMetrics: [TrendMetric] = [.score, .sleepingHR, .hrv, .respiratoryRate, .duration, .deep, .rem, .efficiency]
    static let activityMetrics: [TrendMetric] = [.steps, .exercise, .peakHR, .vo2Max]
}

enum TrendRange: String, CaseIterable, Identifiable, Codable, Sendable {
    case oneMonth = "1M", threeMonths = "3M", sixMonths = "6M", oneYear = "1Y", all = "All"
    var id: String { rawValue }
    var days: Int? {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .all: return nil
        }
    }
    /// Ranges long enough that daily dots become noise; the chart shows monthly means instead.
    var usesMonthlyBuckets: Bool { self == .oneYear || self == .all }
    var rollingWindow: Int { self == .oneMonth ? 7 : 14 }
}

enum DayTypeFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All", weekday = "Wd", weekend = "We"
    var id: String { rawValue }
    func includes(_ n: NightSummary) -> Bool {
        switch self {
        case .all: return true
        case .weekday: return n.dayType == .weekday
        case .weekend: return n.dayType == .weekend
        }
    }
}
