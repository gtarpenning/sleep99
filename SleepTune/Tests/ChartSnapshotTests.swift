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
