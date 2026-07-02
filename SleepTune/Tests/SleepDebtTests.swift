import XCTest
@testable import SleepTune

final class SleepDebtTests: XCTestCase {

    private func nights(_ hours: [Double], exerciseMins: [Double?]? = nil) -> [SleepDebtNight] {
        let base = Date()
        return hours.enumerated().map { i, h in
            SleepDebtNight(
                date: base.addingTimeInterval(-Double(i) * 86400),
                hours: h,
                exerciseMinutes: exerciseMins?[i] ?? nil
            )
        }
    }

    func testZeroDebtWhenAlwaysAtTarget() {
        let summary = SleepDebt.compute(nights: nights([8, 8, 8, 8, 8, 8, 8]))
        XCTAssertEqual(summary.totalDebt, 0, accuracy: 0.001)
        XCTAssertEqual(summary.severity, .none)
        XCTAssertEqual(summary.nightsAtOrAboveTarget, 7)
    }

    func testAccumulatesDebtForShortNights() {
        // 7 nights at 6h vs 8h target → 14h debt.
        let summary = SleepDebt.compute(nights: nights([6, 6, 6, 6, 6, 6, 6]))
        XCTAssertEqual(summary.totalDebt, 14, accuracy: 0.001)
        XCTAssertEqual(summary.severity, .high)
        XCTAssertEqual(summary.nightsAtOrAboveTarget, 0)
    }

    func testOversleepDoesNotReduceDebtBelowZero() {
        // Oversleeping doesn't subtract from debt — debt is one-directional.
        let summary = SleepDebt.compute(nights: nights([10, 10, 10]))
        XCTAssertEqual(summary.totalDebt, 0)
    }

    func testActivityBumpAddsToDebt() {
        // Slept 7h with a heavy 90-min workout — extra training adds debt.
        let withActivity = SleepDebt.compute(
            nights: nights([7], exerciseMins: [90])
        )
        let withoutActivity = SleepDebt.compute(nights: nights([7]))
        XCTAssertGreaterThan(withActivity.totalDebt, withoutActivity.totalDebt)
    }

    func testActivityBumpSkippedOnFullySleepNights() {
        // Hard workout but slept 8h — no extra debt, fully recovered.
        let summary = SleepDebt.compute(
            nights: nights([8], exerciseMins: [120])
        )
        XCTAssertEqual(summary.totalDebt, 0)
    }

    func testSeverityBuckets() {
        XCTAssertEqual(SleepDebt.compute(nights: nights([8, 8, 8])).severity, .none)
        XCTAssertEqual(SleepDebt.compute(nights: nights([7, 7, 7])).severity, .mild)      // 3h debt
        XCTAssertEqual(SleepDebt.compute(nights: nights([6, 6, 6, 6])).severity, .moderate) // 8h
        XCTAssertEqual(SleepDebt.compute(nights: nights([5, 5, 5, 5, 5])).severity, .high)  // 15h
    }

    func testEmptyInputReturnsZero() {
        let summary = SleepDebt.compute(nights: [])
        XCTAssertEqual(summary.totalDebt, 0)
        XCTAssertEqual(summary.nightsCounted, 0)
    }

    func testSummaryTextLabels() {
        let caughtUp = SleepDebt.compute(nights: nights([8, 8, 8]))
        XCTAssertEqual(SleepDebt.summaryText(for: caughtUp), "Caught up")

        let behind = SleepDebt.compute(nights: nights([6, 6, 6]))
        XCTAssertEqual(SleepDebt.summaryText(for: behind), "6h behind")
    }
}
