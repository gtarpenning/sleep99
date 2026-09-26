import XCTest
@testable import SleepTune

final class AlcoholHeuristicTests: XCTestCase {

    private let base = AlcoholHeuristic.Baseline(avgHR: 55, hrv: 50, deepMinutes: 80, minutesToLowestHR: 180)

    func testNormalNightIsNotFlagged() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 56, hrv: 48, deepMinutes: 78, minutesToLowestHR: 175), baseline: base)
        XCTAssertEqual(r.verdict, .none)
        XCTAssertEqual(r.points, 0)
    }

    func testTwentyPercentHRPlusLowHRVIsLikely() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 67, hrv: 34, deepMinutes: 75, minutesToLowestHR: 180), baseline: base)
        XCTAssertEqual(r.verdict, .likely)
        XCTAssertEqual(r.points, 3)
        XCTAssertEqual(r.hrElevation, 12.0 / 55.0, accuracy: 1e-9)
        XCTAssertTrue(r.reasons.contains { $0.hasPrefix("HR +") })
    }

    func testWeakHRAloneIsNotEnough() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 62, hrv: 50, deepMinutes: 80, minutesToLowestHR: 180), baseline: base)
        XCTAssertEqual(r.verdict, .none)
        XCTAssertEqual(r.points, 1)
    }

    func testWeakHRPlusOneSecondarySignalIsPossible() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 62, hrv: 50, deepMinutes: 40, minutesToLowestHR: 180), baseline: base)
        XCTAssertEqual(r.verdict, .possible)
    }

    func testSecondarySignalsWithoutHRElevationNeverFlag() {
        // Illness / overtraining pattern: HRV and deep tank but HR is normal.
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 55, hrv: 20, deepMinutes: 20, minutesToLowestHR: 320), baseline: base)
        XCTAssertEqual(r.verdict, .none)
    }

    func testLateTroughCounts() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 67, hrv: 50, deepMinutes: 80, minutesToLowestHR: 300), baseline: base)
        XCTAssertEqual(r.points, 3)
        XCTAssertEqual(r.verdict, .likely)
    }

    func testMissingOptionalSignalsStillWork() {
        let r = AlcoholHeuristic.evaluate(night: .init(avgHR: 70), baseline: .init(avgHR: 55))
        XCTAssertEqual(r.points, 2)
        XCTAssertEqual(r.verdict, .possible)
        XCTAssertNil(r.hrvDrop)
    }

    func testBaselinePrefersWeekdaysAndExcludesFlaggedNights() {
        var nights = MockSleepData.nightSummaries(count: 40)
        // Flag every weekend night as alcohol; baseline must ignore them.
        for i in nights.indices where nights[i].dayType == .weekend { nights[i].alcoholFlag = true }
        let b = AlcoholHeuristic.baseline(from: nights)
        XCTAssertNotNil(b)
        let weekdayHR = nights.filter { $0.dayType == .weekday }.compactMap(\.avgHR)
        XCTAssertEqual(b!.avgHR, weekdayHR.reduce(0, +) / Double(weekdayHR.count), accuracy: 1e-9)
    }

    func testBaselineNilWithTooFewNights() {
        XCTAssertNil(AlcoholHeuristic.baseline(from: MockSleepData.nightSummaries(count: 4)))
    }

    func testMockDrinkNightsAreMostlyCaught() {
        // Mock history bakes in HR +22 % / HRV −30 % on ~45 % of weekend nights.
        let nights = MockSleepData.nightSummaries(count: 120)
        let b = AlcoholHeuristic.baseline(from: nights)!
        let weekendHits = nights.filter { $0.dayType == .weekend }.filter {
            AlcoholHeuristic.evaluate(night: AlcoholHeuristic.night(from: $0)!, baseline: b).verdict != .none
        }.count
        let weekdayHits = nights.filter { $0.dayType == .weekday }.filter {
            AlcoholHeuristic.evaluate(night: AlcoholHeuristic.night(from: $0)!, baseline: b).verdict == .likely
        }.count
        XCTAssertGreaterThan(weekendHits, 8)
        XCTAssertLessThan(weekdayHits, 6)   // few false "likely" on weekdays
    }
}
