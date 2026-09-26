import XCTest
@testable import SleepTune

final class TrendMathTests: XCTestCase {
    private func pts(_ vs: [Double], start: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> [TrendPoint] {
        vs.enumerated().map { TrendPoint(date: start.addingTimeInterval(Double($0.offset) * 86_400), value: $0.element) }
    }

    func testRollingMeanWarmsUpThenAverages() {
        let r = TrendMath.rollingMean(pts([1, 2, 3, 4, 5]), window: 3)
        XCTAssertEqual(r.map(\.value), [1, 1.5, 2, 3, 4])
    }

    func testRollingMeanWindowOneIsIdentity() {
        let p = pts([3, 1, 2])
        XCTAssertEqual(TrendMath.rollingMean(p, window: 1).map(\.value), [3, 1, 2])
    }

    func testMonthlyBucketsAverageByMonth() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 30))!
        let feb = cal.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let p = [TrendPoint(date: jan, value: 10), TrendPoint(date: jan.addingTimeInterval(86_400), value: 20),
                 TrendPoint(date: feb, value: 50)]
        let b = TrendMath.monthlyBuckets(p, calendar: cal)
        XCTAssertEqual(b.count, 2)
        XCTAssertEqual(b[0].value, 15)
        XCTAssertEqual(b[1].value, 50)
        XCTAssertEqual(cal.component(.day, from: b[0].date), 1)
    }

    func testWeekdayAveragesGroupByWeekday() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let sun = cal.date(from: DateComponents(year: 2026, month: 9, day: 20))! // Sunday
        let p = [TrendPoint(date: sun, value: 80), TrendPoint(date: sun.addingTimeInterval(7 * 86_400), value: 60),
                 TrendPoint(date: sun.addingTimeInterval(86_400), value: 40)]
        let w = TrendMath.weekdayAverages(p, calendar: cal)
        XCTAssertEqual(w[1]?.avg, 70); XCTAssertEqual(w[1]?.n, 2)
        XCTAssertEqual(w[2]?.avg, 40)
    }

    func testLinearTrendSlope() {
        let t = TrendMath.linearTrend(pts([10, 12, 14, 16]))!
        XCTAssertEqual(t.slopePerDay, 2, accuracy: 1e-9)
        XCTAssertEqual(t.change, 6, accuracy: 1e-9)
        XCTAssertNil(TrendMath.linearTrend(pts([1, 2])))
    }

    func testPearsonAndSpearman() {
        let x = (0..<12).map(Double.init)
        let y = x.map { $0 * 2 + 1 }
        XCTAssertEqual(TrendMath.pearson(x, y)!, 1, accuracy: 1e-9)
        XCTAssertEqual(TrendMath.pearson(x, y.reversed())!, -1, accuracy: 1e-9)
        let curved = x.map { $0 * $0 }
        XCTAssertEqual(TrendMath.spearman(x, curved)!, 1, accuracy: 1e-9)
        XCTAssertNil(TrendMath.pearson([1, 2, 3], [1, 2, 3]))
        XCTAssertNil(TrendMath.pearson(x, Array(repeating: 5, count: 12)))
    }

    func testRanksHandleTies() {
        XCTAssertEqual(TrendMath.ranks([10, 20, 20, 30]), [1, 2.5, 2.5, 4])
    }
}
