import XCTest

final class SleepScoreEngineTests: XCTestCase {
    func testScoreClampsBetweenZeroAndHundred() {
        let engine = SleepScoreEngine()
        let indicators = [
            SleepIndicator(
                name: "Duration",
                detail: "",
                value: 2,
                unit: "hr",
                category: .sleepArchitecture,
                source: .manual,
                range: 5...9
            )
        ]

        let summary = engine.score(indicators: indicators, weights: .default, feeling: .low)
        XCTAssertGreaterThanOrEqual(summary.score, 0)
        XCTAssertLessThanOrEqual(summary.score, 100)
    }
}
