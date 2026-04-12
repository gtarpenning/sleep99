import XCTest
@testable import SleepTune

final class SleepScoreEngineTests: XCTestCase {
    func testScoreClampsBetweenZeroAndHundred() {
        let engine = SleepScoreEngine()
        let indicators = [
            SleepIndicator(
                name: "Sleep Duration",
                detail: "",
                value: 2,
                unit: "hr",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 5...9
            )
        ]

        let summary = engine.score(indicators: indicators, weights: .default)
        XCTAssertGreaterThanOrEqual(summary.score, 0)
        XCTAssertLessThanOrEqual(summary.score, 100)
    }
}
