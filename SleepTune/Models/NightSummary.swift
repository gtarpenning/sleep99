import Foundation

/// Whether a night is a "school night" or not. Weekend nights are Friday and
/// Saturday nights — i.e. sleep that ends on a Saturday or Sunday morning.
enum DayType: String, Codable, Sendable, CaseIterable {
    case weekday, weekend

    static func classify(wakeDate: Date, calendar: Calendar = .current) -> DayType {
        let weekday = calendar.component(.weekday, from: wakeDate)   // 1 = Sunday … 7 = Saturday
        return (weekday == 1 || weekday == 7) ? .weekend : .weekday
    }
}

/// One night of sleep plus the previous day's activity, flattened into a
/// value type. This is what every long-range reader (trends, stats, debt,
/// correlations) consumes; `NightRecord` is only its persistence shape.
struct NightSummary: Codable, Sendable, Equatable, Identifiable {
    /// Start-of-day of the wake date — the same `date` the dashboard uses.
    let night: Date
    var score: Double
    var sleepScore: Double
    var recoveryScore: Double
    /// Indicator name → value, for every cached `SleepIndicator`.
    var metrics: [String: Double]
    var maxHR: Double?
    /// Previous day's activity.
    var steps: Double?
    var activeCalories: Double?
    var exerciseMinutes: Double?
    var peakHR: Double?
    var vo2Max: Double?
    var sleepStart: Date?
    var sleepEnd: Date?
    var dayType: DayType
    var alcoholFlag: Bool?

    var id: Date { night }

    static func key(for date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }

    var key: String { Self.key(for: night) }

    // Convenience accessors for the metrics we read most.
    var durationHours: Double? { metrics["Sleep Duration"] }
    var efficiencyPercent: Double? { metrics["Sleep Efficiency"] }
    var deepMinutes: Double? { metrics["Deep Sleep"] }
    var remMinutes: Double? { metrics["REM Sleep"] }
    var avgHR: Double? { metrics["Overnight Heart Rate"] }
    var minHR: Double? { metrics["Lowest Overnight HR"] }
    var hrv: Double? { metrics["HRV"] }
    var respiratoryRate: Double? { metrics["Respiratory Rate"] }

    /// Builds a summary from the dashboard's existing building blocks.
    static func make(
        night: Date,
        indicators: [SleepIndicator],
        summary: SleepScoreSummary?,
        activity: DailyActivitySnapshot?,
        signals: [SleepSignalSample] = [],
        sleepInterval: DateInterval? = nil,
        calendar: Calendar = .current
    ) -> NightSummary {
        let day = calendar.startOfDay(for: night)
        let hr = signals.filter { $0.name == SleepSignalType.heartRate.rawValue }.map(\.value)
        return NightSummary(
            night: day,
            score: summary?.score ?? 0,
            sleepScore: summary?.sleepScore ?? 0,
            recoveryScore: summary?.recoveryScore ?? 0,
            metrics: indicators.reduce(into: [:]) { $0[$1.name] = $1.value },
            maxHR: hr.max(),
            steps: activity?.steps,
            activeCalories: activity?.activeCalories,
            exerciseMinutes: activity?.exerciseMinutes,
            peakHR: activity?.peakHR,
            vo2Max: activity?.vo2Max,
            sleepStart: sleepInterval?.start,
            sleepEnd: sleepInterval?.end,
            dayType: DayType.classify(wakeDate: day, calendar: calendar),
            alcoholFlag: nil
        )
    }
}
