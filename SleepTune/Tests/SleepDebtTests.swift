import XCTest
@testable import SleepTune

final class SleepDebtTests: XCTestCase {

    private let cal = Calendar.current

    /// hours[0] is the selected night (age 0), hours[1] the night before, etc.
    private func nights(_ hours: [Double], efficiency: Double? = nil, exercise: [Double?]? = nil) -> [SleepDebtNight] {
        let base = cal.startOfDay(for: Date())
        return hours.enumerated().map { i, h in
            SleepDebtNight(
                date: cal.date(byAdding: .day, value: -i, to: base)!,
                hours: h,
                efficiencyPercent: efficiency,
                exerciseMinutesPrevDay: exercise?[i] ?? nil
            )
        }
    }

    // MARK: Weights

    func testWeightsSumToTotalAndLastNightIsFifteenPercent() {
        XCTAssertEqual(SleepDebt.weights.count, 14)
        XCTAssertEqual(SleepDebt.weights.reduce(0, +), SleepDebt.weightTotal, accuracy: 1e-9)
        XCTAssertEqual(SleepDebt.weights[0], SleepDebt.weightTotal * 0.15, accuracy: 1e-9)
        for k in 1..<13 { XCTAssertGreaterThan(SleepDebt.weights[k], SleepDebt.weights[k + 1]) }
    }

    // MARK: Compute

    func testZeroDebtWhenAlwaysAtNeed() {
        let s = SleepDebt.compute(nights: nights(Array(repeating: 7.5, count: 14)), need: 7.5)
        XCTAssertEqual(s.totalDebt, 0, accuracy: 1e-9)
        XCTAssertEqual(s.severity, .low)
        XCTAssertEqual(s.trend, .steady)
        XCTAssertEqual(s.ledger.count, 14)
    }

    func testSteadyOneHourShortfallLandsOnTarget() {
        // 1h short every night for 14 nights → weights sum × 1h = 5h = target.
        let s = SleepDebt.compute(nights: nights(Array(repeating: 6.5, count: 14)), need: 7.5)
        XCTAssertEqual(s.totalDebt, SleepDebt.targetDebt, accuracy: 1e-9)
        XCTAssertEqual(s.severity, .moderate)
    }

    func testSelectedNightCountsAtLastNightShare() {
        let s = SleepDebt.compute(nights: nights([5.5]), need: 7.5)
        XCTAssertEqual(s.totalDebt, 2 * SleepDebt.weights[0], accuracy: 1e-9)
    }

    func testSurplusRepaysAtHalfRateOffStreak() {
        // Surplus two nights ago, but last night was short, so no streak: half credit.
        let short = SleepDebt.compute(nights: nights([5.5, 7.5, 5.5]), need: 7.5).ledgerDebt
        let repaid = SleepDebt.compute(nights: nights([5.5, 9.5, 5.5]), need: 7.5).ledgerDebt
        XCTAssertEqual(short - repaid, 2 * 0.5 * SleepDebt.weights[1], accuracy: 1e-9)
    }

    // MARK: Recovery streak

    func testStreakCountsConsecutiveOnTargetNightsFromSelected() {
        XCTAssertEqual(SleepDebt.compute(nights: nights([7.5, 7.5, 5.5, 7.5]), need: 7.5).recoveryStreak, 2)
        XCTAssertEqual(SleepDebt.compute(nights: nights([5.5, 7.5, 7.5]), need: 7.5).recoveryStreak, 0)
        // 5 % slack: 7.2h against a 7.5h need still counts.
        XCTAssertEqual(SleepDebt.compute(nights: nights([7.2, 5.5]), need: 7.5).recoveryStreak, 1)
        XCTAssertEqual(SleepDebt.compute(nights: nights([7.0, 5.5]), need: 7.5).recoveryStreak, 0)
    }

    func testStreakDiscountsLedger() {
        let bad = Array(repeating: 5.5, count: 14)
        let base = SleepDebt.compute(nights: nights(bad), need: 7.5)
        XCTAssertEqual(base.recoveryStreak, 0)
        XCTAssertEqual(base.totalDebt, base.ledgerDebt, accuracy: 1e-9)

        let one = SleepDebt.compute(nights: nights([7.5] + bad.dropLast(1)), need: 7.5)
        XCTAssertEqual(one.recoveryStreak, 1)
        XCTAssertEqual(one.totalDebt, one.ledgerDebt * 0.6, accuracy: 1e-9)

        let two = SleepDebt.compute(nights: nights([7.5, 7.5] + bad.dropLast(2)), need: 7.5)
        XCTAssertEqual(two.totalDebt, two.ledgerDebt * 0.3, accuracy: 1e-9)

        let three = SleepDebt.compute(nights: nights([7.5, 7.5, 7.5] + bad.dropLast(3)), need: 7.5)
        XCTAssertEqual(three.totalDebt, three.ledgerDebt * 0.1, accuracy: 1e-9)
        XCTAssertEqual(three.severity, .low)

        let five = SleepDebt.compute(nights: nights(Array(repeating: 7.5, count: 5) + bad.dropLast(5)), need: 7.5)
        XCTAssertEqual(five.totalDebt, five.ledgerDebt * 0.1, accuracy: 1e-9, "factor floors at 3+")
    }

    func testStreakNightsGetFullSurplusCredit() {
        let bad = Array(repeating: 5.5, count: 12)
        let atNeed = SleepDebt.compute(nights: nights([7.5, 7.5] + bad), need: 7.5)
        let over   = SleepDebt.compute(nights: nights([9.5, 9.5] + bad), need: 7.5)
        let expected = 2 * (SleepDebt.weights[0] + SleepDebt.weights[1])
        XCTAssertEqual(atNeed.ledgerDebt - over.ledgerDebt, expected, accuracy: 1e-9)
    }

    func testShortNightAfterStreakBringsLedgerBack() {
        let bad = Array(repeating: 5.5, count: 11)
        let cleared = SleepDebt.compute(nights: nights([7.5, 7.5, 7.5] + bad), need: 7.5)
        let relapse = SleepDebt.compute(nights: nights([5.0, 7.5, 7.5, 7.5] + bad.dropLast(1)), need: 7.5)
        XCTAssertEqual(relapse.recoveryStreak, 0)
        XCTAssertGreaterThan(relapse.totalDebt, cleared.totalDebt * 3)
    }

    func testDebtNeverNegative() {
        let s = SleepDebt.compute(nights: nights(Array(repeating: 9.5, count: 14)), need: 7.5)
        XCTAssertEqual(s.totalDebt, 0)
    }

    func testDebtCappedAtTwiceNeed() {
        let s = SleepDebt.compute(nights: nights(Array(repeating: 3.0, count: 14)), need: 7.5)
        XCTAssertEqual(s.totalDebt, 15, accuracy: 1e-9)
    }

    func testSubThreeHourNightsAreDropped() {
        let s = SleepDebt.compute(nights: nights([7.5, 1.0, 7.5]), need: 7.5)
        XCTAssertEqual(s.nightsCounted, 2)
        XCTAssertEqual(s.totalDebt, 0, accuracy: 1e-9)
    }

    func testOlderThanFourteenNightsIgnored() {
        let s = SleepDebt.compute(nights: nights(Array(repeating: 7.5, count: 14) + [3.5]), need: 7.5)
        XCTAssertEqual(s.totalDebt, 0, accuracy: 1e-9)
        XCTAssertEqual(s.nightsCounted, 14)
    }

    func testAgeComesFromDatesNotOrder() {
        let base = cal.startOfDay(for: Date())
        let shuffled = [
            SleepDebtNight(date: cal.date(byAdding: .day, value: -3, to: base)!, hours: 7.5),
            SleepDebtNight(date: base, hours: 5.5),
            SleepDebtNight(date: cal.date(byAdding: .day, value: -1, to: base)!, hours: 7.5),
        ]
        XCTAssertEqual(SleepDebt.compute(nights: shuffled, need: 7.5).totalDebt, 2 * SleepDebt.weights[0], accuracy: 1e-9)
    }

    // MARK: Quality adjustment

    func testLowEfficiencyShrinksBankedHours() {
        let good = SleepDebt.compute(nights: nights([7.5], efficiency: 95), need: 7.5).totalDebt
        let poor = SleepDebt.compute(nights: nights([7.5], efficiency: 70), need: 7.5).totalDebt
        XCTAssertEqual(good, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(poor, 0)
        // 7.5 × (70/85) = 6.18 → 1.32h short × w0
        XCTAssertEqual(poor, (7.5 - 7.5 * 70 / 85) * SleepDebt.weights[0], accuracy: 1e-6)
    }

    func testQualityFactorFloorsAtSeventyPercent() {
        let n = SleepDebtNight(date: Date(), hours: 8, efficiencyPercent: 40, deepRemMinutes: 10)
        XCTAssertEqual(SleepDebt.effectiveHours(n, baselineDeepRem: 180), 8 * 0.7, accuracy: 1e-9)
    }

    func testThinDeepRemReducesBankedHours() {
        let n = SleepDebtNight(date: Date(), hours: 8, deepRemMinutes: 90)
        // 50 % below baseline → factor 1 − 0.5 × 0.5 = 0.75
        XCTAssertEqual(SleepDebt.effectiveHours(n, baselineDeepRem: 180), 6, accuracy: 1e-9)
    }

    // MARK: Strain

    func testStrainBonusOnlyAboveFortyFiveMinutesAndCapped() {
        XCTAssertEqual(SleepDebt.strainBonus(exerciseMinutes: nil), 0)
        XCTAssertEqual(SleepDebt.strainBonus(exerciseMinutes: 30), 0)
        XCTAssertEqual(SleepDebt.strainBonus(exerciseMinutes: 105), 0.25, accuracy: 1e-9)
        XCTAssertEqual(SleepDebt.strainBonus(exerciseMinutes: 400), 0.5, accuracy: 1e-9)
    }

    func testHardDayRaisesNeedForThatNight() {
        let s = SleepDebt.compute(nights: nights([7.5], exercise: [105]), need: 7.5)
        XCTAssertEqual(s.ledger.first?.need ?? 0, 7.75, accuracy: 1e-9)
        XCTAssertEqual(s.ledgerDebt, 0.25 * SleepDebt.weights[0], accuracy: 1e-9)
        // 15 min under an adjusted need is within the 5 % slack, so it still streaks.
        XCTAssertEqual(s.recoveryStreak, 1)
    }

    // MARK: Need

    func testBaselineNeedFallsBackWithLittleHistory() {
        XCTAssertEqual(SleepDebt.baselineNeed(from: nights([7, 7, 7])), SleepDebt.defaultNeed)
    }

    func testBaselineNeedUsesBestRestedFortnight() {
        // 14 great nights at 8.2h (score 90) followed by 14 bad nights at 6h (score 50).
        // A rolling mean would say ~7.1; the best-rested window says ~8.2.
        let base = cal.startOfDay(for: Date())
        var history: [SleepDebtNight] = []
        for i in 0..<28 {
            let good = i >= 14
            history.append(SleepDebtNight(
                date: cal.date(byAdding: .day, value: -i, to: base)!,
                hours: good ? 8.2 : 6.0, score: good ? 90 : 50
            ))
        }
        XCTAssertEqual(SleepDebt.baselineNeed(from: history), 8.2, accuracy: 0.01)
    }

    func testBaselineNeedIsClamped() {
        XCTAssertEqual(SleepDebt.baselineNeed(from: nights(Array(repeating: 5.0, count: 10))), 6.5)
        XCTAssertEqual(SleepDebt.baselineNeed(from: nights(Array(repeating: 10.0, count: 10))), 9.0)
    }

    // MARK: Trend

    func testTrendWorseningAfterRecentShortNights() {
        let s = SleepDebt.compute(nights: nights([5, 5, 5] + Array(repeating: 7.5, count: 11)), need: 7.5)
        XCTAssertEqual(s.trend, .worsening)
    }

    func testTrendImprovingAfterRecentGoodNights() {
        let s = SleepDebt.compute(nights: nights([7.5, 7.5, 7.5, 5, 5, 5] + Array(repeating: 7.5, count: 8)), need: 7.5)
        XCTAssertEqual(s.trend, .improving)
    }

    // MARK: Formatting

    func testHoursText() {
        XCTAssertEqual(SleepDebt.hoursText(0.2), "0h")
        XCTAssertEqual(SleepDebt.hoursText(2.3), "2.5h")
        XCTAssertEqual(SleepDebt.hoursText(3.0), "3h")
    }
}
