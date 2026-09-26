import XCTest
@testable import SleepTune

final class SleepDebtTests: XCTestCase {

    /// hours[0] is last night (age 0), hours[1] the night before, etc.
    private func nights(_ hours: [Double]) -> [SleepDebtNight] {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        return hours.enumerated().map { i, h in
            SleepDebtNight(date: cal.date(byAdding: .day, value: -i, to: base)!, hours: h)
        }
    }

    func testZeroDebtWhenAlwaysAtNeed() {
        let summary = SleepDebt.compute(nights: nights(Array(repeating: 7.5, count: 10)), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 0, accuracy: 0.001)
        XCTAssertEqual(summary.severity, .none)
        XCTAssertEqual(summary.trend, .steady)
    }

    func testTwoNormalNightsCrushOneHourDebt() {
        // 1h shortfall two nights ago, normal sleep since → 1 × 0.7² = 0.49,
        // below the 0.5h "caught up" display threshold.
        let summary = SleepDebt.compute(nights: nights([7.5, 7.5, 6.5]), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 0.49, accuracy: 0.001)
        XCTAssertEqual(SleepDebt.summaryText(for: summary), "Caught up")
    }

    func testRecentShortfallCountsInFull() {
        let summary = SleepDebt.compute(nights: nights([6.5]), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 1.0, accuracy: 0.001)
    }

    func testSurplusRepaysAtHalfRate() {
        // 2h shortfall last night (age 1, weight 0.7 → 1.4h), then a 2h
        // surplus night (credit 2 × 0.5 = 1h) → 0.4h remaining.
        let summary = SleepDebt.compute(nights: nights([9.5, 5.5]), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 0.4, accuracy: 0.001)
    }

    func testSurplusNeverPushesDebtBelowZero() {
        let summary = SleepDebt.compute(nights: nights([10, 10, 10]), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 0, accuracy: 0.001)
    }

    func testChronicShortfallIsBoundedNotUnbounded() {
        // 1h short every night for 10 nights: Σ 0.7^i ≈ 3.24 — reads as
        // "persistently a few hours behind" instead of 10h and climbing.
        let summary = SleepDebt.compute(nights: nights(Array(repeating: 6.5, count: 10)), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 3.24, accuracy: 0.01)
        XCTAssertEqual(summary.severity, .moderate)
    }

    func testDebtIsCappedAtTwiceNeed() {
        // 3h nights against a 9h need: 6 × Σ0.7^i ≈ 19.4h raw → capped at 18.
        let summary = SleepDebt.compute(nights: nights(Array(repeating: 3, count: 10)), need: 9)
        XCTAssertEqual(summary.totalDebt, 18, accuracy: 0.001)
        XCTAssertEqual(summary.severity, .high)
    }

    func testSubThreeHourNightsExcludedAsTrackingNoise() {
        // A 1h "night" (watch died) contributes nothing — same as untracked.
        let withNoise = SleepDebt.compute(nights: nights([7.5, 1.0, 7.5]), need: 7.5)
        XCTAssertEqual(withNoise.totalDebt, 0, accuracy: 0.001)
        XCTAssertEqual(withNoise.nightsCounted, 2)

        // Exactly 3h is kept — a real (terrible) night.
        let boundary = SleepDebt.compute(nights: nights([3.0]), need: 7.5)
        XCTAssertEqual(boundary.totalDebt, 4.5, accuracy: 0.001)
    }

    func testAllNoiseNightsReturnsEmptySummary() {
        let summary = SleepDebt.compute(nights: nights([1, 2, 0.5]), need: 7.5)
        XCTAssertEqual(summary.totalDebt, 0)
        XCTAssertEqual(summary.nightsCounted, 0)
    }

    func testTrendImprovingAfterRecoveryNights() {
        // Big shortfalls 3-5 nights ago, normal since → debt is melting.
        let summary = SleepDebt.compute(nights: nights([7.5, 7.5, 7.5, 5, 5, 5]), need: 7.5)
        XCTAssertEqual(summary.trend, .improving)
    }

    func testTrendWorseningWithFreshShortfalls() {
        let summary = SleepDebt.compute(nights: nights([5, 5, 7.5, 7.5, 7.5, 7.5]), need: 7.5)
        XCTAssertEqual(summary.trend, .worsening)
    }

    func testSeverityBuckets() {
        XCTAssertEqual(SleepDebt.compute(nights: nights([7.5]), need: 7.5).severity, .none)
        XCTAssertEqual(SleepDebt.compute(nights: nights([6]), need: 7.5).severity, .mild)       // 1.5h
        XCTAssertEqual(SleepDebt.compute(nights: nights([4.5]), need: 7.5).severity, .moderate) // 3h
        XCTAssertEqual(SleepDebt.compute(nights: nights([3, 4]), need: 7.5).severity, .high)    // 4.5 + 3.5×0.7 = 6.95h
    }

    func testEmptyInputReturnsZero() {
        let summary = SleepDebt.compute(nights: [])
        XCTAssertEqual(summary.totalDebt, 0)
        XCTAssertEqual(summary.nightsCounted, 0)
    }

    func testSummaryTextRoundsToHalfHours() {
        let behind = SleepDebt.compute(nights: nights([4.5]), need: 7.5) // 3h
        XCTAssertEqual(SleepDebt.summaryText(for: behind), "3h behind")

        let fractional = SleepDebt.compute(nights: nights([6]), need: 7.5) // 1.5h
        XCTAssertEqual(SleepDebt.summaryText(for: fractional), "1.5h behind")
    }

    // MARK: - Sleep need estimation

    private func stats(_ values: [Double]) -> MetricStats {
        let sorted = values.sorted()
        return MetricStats(
            avg: values.reduce(0, +) / Double(values.count),
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            count: values.count,
            sortedValues: sorted
        )
    }

    func testSleepNeedUsesP60OfHistory() {
        // p60 of [6, 6.5, 7, 7.5, 8] → index 2.4 → 7 + 0.4 × 0.5 = 7.2
        XCTAssertEqual(SleepDebt.sleepNeed(from: stats([6, 6.5, 7, 7.5, 8])), 7.2, accuracy: 0.001)
    }

    func testSleepNeedIsFloorClamped() {
        // Chronic short sleeper can't define deprivation away.
        XCTAssertEqual(SleepDebt.sleepNeed(from: stats([5, 5.2, 5.4, 5.6, 5.8])), 6.5)
    }

    func testSleepNeedIsCeilingClamped() {
        XCTAssertEqual(SleepDebt.sleepNeed(from: stats([9.5, 9.6, 9.7, 9.8, 9.9])), 9.0)
    }

    func testSleepNeedFallsBackWithSparseHistory() {
        XCTAssertEqual(SleepDebt.sleepNeed(from: nil), SleepDebt.defaultNeed)
        XCTAssertEqual(SleepDebt.sleepNeed(from: stats([7, 8])), SleepDebt.defaultNeed)
    }
}
