import Foundation
import WidgetKit

/// A colored sleep-stage span, normalized to 0…1 across the night.
/// `stage` mirrors `SleepStage.sortOrder` (0 inBed · 1 deep · 2 core · 3 rem · 4 awake).
struct WidgetStageSpan: Codable, Equatable, Hashable {
    let stage: Int
    let x0: Double
    let x1: Double
}

/// One point of an overnight signal line. `x` is 0…1 across the night;
/// `y` is normalized 0…1 within that signal so HR/HRV/RR overlay cleanly.
struct WidgetLinePoint: Codable, Equatable, Hashable {
    let x: Double
    let y: Double
}

/// Thin codable struct shared between the main app and the widget extension.
/// Written by the app each time the score updates; read by the widget on refresh.
struct WidgetSnapshot: Codable, Equatable {
    let updatedAt: Date
    let score: Double
    let sleepScore: Double
    let recoveryScore: Double
    let totalSleepMinutes: Int
    // Chart payload — optional so snapshots written before the chart existed still decode.
    var stages: [WidgetStageSpan]? = nil
    var hr: [WidgetLinePoint]? = nil
    var hrv: [WidgetLinePoint]? = nil
    var rr: [WidgetLinePoint]? = nil

    var displayDate: Date { updatedAt }
}

/// Shared App Group container for widget data.
/// The App Group `group.com.sleep-tune.app` must be enabled on both the app and
/// widget targets; on simulator it works without portal registration.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.sleep-tune.app"
    private static let key = "widgetSnapshot.v1"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> WidgetSnapshot? {
        guard let data = sharedDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    // MARK: - Chart payload builders

    /// Time window shared by stage bands and signal lines so they align on the same
    /// x-axis. Prefers the HR series bounds (already clipped to the sleep window by the
    /// view model); falls back to asleep-stage bounds.
    static func chartWindow(heartRate: SleepChartSeries?, stages: [SleepStageSample]) -> ClosedRange<Date>? {
        if let hr = heartRate {
            let dates = hr.points.map(\.date)
            if let lo = dates.min(), let hi = dates.max(), lo < hi { return lo...hi }
        }
        let asleep = stages
            .filter { $0.stage != .inBed && $0.stage != .awake }
            .flatMap { [$0.startDate, $0.endDate] }
        if let lo = asleep.min(), let hi = asleep.max(), lo < hi { return lo...hi }
        return nil
    }

    static func stageSpans(from stages: [SleepStageSample], window: ClosedRange<Date>) -> [WidgetStageSpan] {
        let span = window.upperBound.timeIntervalSince(window.lowerBound)
        guard span > 0 else { return [] }
        return stages.compactMap { s in
            let x0 = (s.startDate.timeIntervalSince(window.lowerBound) / span).clamped01
            let x1 = (s.endDate.timeIntervalSince(window.lowerBound) / span).clamped01
            guard x1 > x0 else { return nil }
            return WidgetStageSpan(stage: s.stage.sortOrder, x0: x0, x1: x1)
        }
    }

    /// Downsamples and per-series normalizes a signal into ≤ `maxCount` points.
    static func linePoints(from series: SleepChartSeries?, window: ClosedRange<Date>, maxCount: Int = 60) -> [WidgetLinePoint] {
        guard let series, !series.points.isEmpty else { return [] }
        let span = window.upperBound.timeIntervalSince(window.lowerBound)
        guard span > 0 else { return [] }
        let sorted = series.points.sorted { $0.date < $1.date }
        let values = sorted.map(\.value)
        let minY = values.min() ?? 0
        let maxY = values.max() ?? 1
        let range = maxY - minY
        let step = Swift.max(1, sorted.count / maxCount)
        var out: [WidgetLinePoint] = []
        for i in Swift.stride(from: 0, to: sorted.count, by: step) {
            let p = sorted[i]
            let x = (p.date.timeIntervalSince(window.lowerBound) / span).clamped01
            let y = range > 0 ? (p.value - minY) / range : 0.5
            out.append(WidgetLinePoint(x: x, y: y))
        }
        return out
    }
}

private extension Double {
    var clamped01: Double { Swift.max(0, Swift.min(1, self)) }
}
