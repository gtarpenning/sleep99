import XCTest
import SwiftUI
@testable import SleepTune

/// Renders dashboard charts with mock data to PNGs under /tmp so chart changes
/// can be eyeballed without driving the simulator UI. Never asserts on pixels.
@MainActor
final class ChartSnapshotTests: XCTestCase {

    func testRenderLastNightChart() throws {
        let view = SleepStagesOverlayChartView(
            stages: MockSleepData.stages,
            heartRate: MockSleepData.heartRateSeries,
            hrv: MockSleepData.hrvSeries,
            respiratoryRate: MockSleepData.rrSeries
        )
        try Self.write(view, name: "lastnight", width: 350)
    }

    func testRenderSleepDebtCard() throws {
        let nights = MockSleepData.nightSummaries(count: 30).map(SleepDebtNight.init)
        let need = SleepDebt.baselineNeed(from: nights)
        let summary = SleepDebt.compute(nights: Array(nights.suffix(14)), need: need, baselineDeepRem: 170)
        try Self.write(SleepDebtCardView(summary: summary), name: "debtcard", width: 390)
    }

    func testRenderTrendChartWithCompare() throws {
        let nights = MockSleepData.nightSummaries(count: 90)
        func series(_ m: TrendMetric) -> [TrendPoint] {
            nights.compactMap { n in m.value(from: n).map { TrendPoint(date: n.night, value: $0) } }
        }
        let p = series(.sleepingHR), c = series(.vo2Max)
        XCTAssertGreaterThan(p.count, 60)
        let chart = TrendChart(
            primary: .sleepingHR, points: p, line: TrendMath.rollingMean(p, window: 14), average: TrendMath.mean(p),
            compare: .vo2Max, comparePoints: c, compareLine: TrendMath.rollingMean(c, window: 14), compareAverage: TrendMath.mean(c),
            monthly: false
        ).frame(height: 200)
        try Self.write(chart, name: "trendchart", width: 358)
        let dow = DayOfWeekChart(averages: TrendMath.weekdayAverages(series(.score))).frame(height: 120)
        try Self.write(dow, name: "dow", width: 358)
    }

    func testRenderCorrelationsCard() throws {
        let nights = MockSleepData.nightSummaries(count: 90)
        let f = CorrelationEngine.compute(nights: nights)
        try Self.write(CorrelationsCardView(findings: f, fitnessSentence: CorrelationEngine.fitnessSentence(nights: nights), nightCount: nights.count), name: "corrcard", width: 358)
    }

    func testRenderStreamlinedPieces() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let snap = DailyActivitySnapshot(
            date: cal.date(byAdding: .day, value: -1, to: today)!,
            steps: 9412, activeCalories: 612, exerciseMinutes: 46, standMinutes: 660,
            floorsClimbed: 14, peakHR: 162, vo2Max: 44.1, workouts: []
        )
        let stats: [String: MetricStats] = [
            "steps": MetricStats(avg: 8100, min: 2000, max: 15000, count: 30),
            "ex": MetricStats(avg: 52, min: 0, max: 120, count: 30),
            "peakhr": MetricStats(avg: 160, min: 120, max: 182, count: 30),
        ]
        try Self.write(
            InsightsBlockView(tagCorrelations: [], activitySnapshot: snap, activityMonthlyStats: stats, selectedDate: today),
            name: "activitystrip", width: 393)

        let scores: [Double] = [72, 78, 65, 81, 84, 77, 81]
        let pts = scores.enumerated().map { i, s in
            SleepScoreTrendPoint(date: cal.date(byAdding: .day, value: i - 6, to: today)!, score: s, sleepScore: s, recoveryScore: s)
        }
        try Self.write(TrendSparkline(points: pts).frame(height: 34), name: "sparkline", width: 200)

        let card = BreakdownCard(title: "Sleep", iconName: "moon.fill", score: 81, accentColor: DS.sleepArc,
                                 metrics: [CardMetric(name: "Duration", value: "6h 31m", source: .appleHealth),
                                           CardMetric(name: "REM Sleep", value: "115m", source: .appleHealth)],
                                 showsDisclosure: true)
        try Self.write(card, name: "breakdowncard", width: 180)
    }

    static func write<V: View>(_ view: V, name: String, width: CGFloat) throws {
        let wrapped = view
            .frame(width: width)
            .padding(16)
            .background(DS.bg)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("render failed for \(name)")
        }
        let url = URL(fileURLWithPath: "/tmp/st-snap-\(name).png")
        try data.write(to: url)
    }
}
