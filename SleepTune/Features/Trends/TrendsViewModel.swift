import Foundation
import Observation

/// Drives the Trends screen: one primary metric, an optional comparison
/// metric on a normalised secondary axis, a range, and a day-type filter.
@MainActor
@Observable
final class TrendsViewModel {
    var range: TrendRange = .threeMonths { didSet { persist(); rebuild() } }
    var dayFilter: DayTypeFilter = .all { didSet { rebuild() } }
    var primary: TrendMetric = .score { didSet { persist(); rebuild() } }
    var compare: TrendMetric? = nil { didSet { persist(); rebuild() } }

    private(set) var nights: [NightSummary] = []
    private(set) var isLoading = false

    // Derived series
    private(set) var primaryPoints: [TrendPoint] = []
    private(set) var primaryLine: [TrendPoint] = []
    private(set) var primaryAverage: Double?
    private(set) var comparePoints: [TrendPoint] = []
    private(set) var compareLine: [TrendPoint] = []
    private(set) var compareAverage: Double?
    private(set) var weekdayScores: [Int: (avg: Double, n: Int)] = [:]
    private(set) var trendSentence: String?

    private let store: NightRecordStore
    private static let prefsKey = "trends.prefs"

    init(store: NightRecordStore) {
        self.store = store
        restore()
    }

    var domainStart: Date? { nights.first?.night }
    var domainEnd: Date? { nights.last?.night }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let all = (try? await store.latest(400)) ?? []
        nights = all
        rebuild()
    }

    // MARK: - Series

    private func rebuild() {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        var scoped = nights
        if let days = range.days, let start = cal.date(byAdding: .day, value: -days, to: end) {
            scoped = nights.filter { $0.night >= start }
        }
        let filtered = scoped.filter(dayFilter.includes)

        (primaryPoints, primaryLine, primaryAverage) = series(for: primary, nights: filtered)
        if let compare {
            (comparePoints, compareLine, compareAverage) = series(for: compare, nights: filtered)
        } else {
            comparePoints = []; compareLine = []; compareAverage = nil
        }
        // Day-of-week uses the scoped range but ignores the day filter (it *is* the split).
        weekdayScores = TrendMath.weekdayAverages(
            scoped.compactMap { n in TrendMetric.score.value(from: n).map { TrendPoint(date: n.night, value: $0) } }
        )
        trendSentence = makeTrendSentence(filtered: filtered)
    }

    private func series(for metric: TrendMetric, nights: [NightSummary]) -> ([TrendPoint], [TrendPoint], Double?) {
        let points = nights.compactMap { n in metric.value(from: n).map { TrendPoint(date: n.night, value: $0) } }
        let line = range.usesMonthlyBuckets
            ? TrendMath.monthlyBuckets(points)
            : TrendMath.rollingMean(points, window: range.rollingWindow)
        return (points, line, TrendMath.mean(points))
    }

    /// "Sleeping HR down 3.1 bpm over 90 nights while VO₂ max rose 2.4."
    private func makeTrendSentence(filtered: [NightSummary]) -> String? {
        guard primaryPoints.count >= 20, let t = TrendMath.linearTrend(primaryPoints) else { return nil }
        let unitless = abs(t.change)
        guard unitless >= meaningfulChange(for: primary) else { return nil }
        let dir = t.change < 0 ? "down" : "up"
        var text = "\(primary.title) \(dir) \(primary.format(abs(t.change))) over \(primaryPoints.count) nights"
        if let compare, comparePoints.count >= 20, let c = TrendMath.linearTrend(comparePoints),
           abs(c.change) >= meaningfulChange(for: compare) {
            let cdir = c.change < 0 ? "fell" : "rose"
            text += " while \(compare.title) \(cdir) \(compare.format(abs(c.change)))"
        }
        return text + "."
    }

    private func meaningfulChange(for m: TrendMetric) -> Double {
        switch m {
        case .score: return 3
        case .sleepingHR, .peakHR: return 1.5
        case .hrv: return 3
        case .respiratoryRate: return 0.4
        case .duration: return 0.25
        case .deep, .rem, .exercise: return 8
        case .efficiency: return 2
        case .steps: return 800
        case .vo2Max: return 0.8
        }
    }

    // MARK: - Persistence of the last chart pair

    private struct Prefs: Codable { var range: TrendRange; var primary: TrendMetric; var compare: TrendMetric? }

    private func persist() {
        let p = Prefs(range: range, primary: primary, compare: compare)
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: Self.prefsKey) }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.prefsKey),
              let p = try? JSONDecoder().decode(Prefs.self, from: data) else { return }
        // Assign backing state without triggering rebuild storms.
        range = p.range; primary = p.primary; compare = p.compare
    }
}
