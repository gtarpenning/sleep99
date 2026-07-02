import XCTest
@testable import SleepTune

final class SleepStressTests: XCTestCase {

    func testReturnsNilWhenBothInputsMissing() {
        XCTAssertNil(SleepStress.compute(hr: nil, hrv: nil))
    }

    func testIdealHRAndHRVProduceLowStress() {
        // Resting HR of 50 + HRV of 60 = essentially zero stress.
        let stress = SleepStress.compute(hr: 50, hrv: 60)
        XCTAssertNotNil(stress)
        XCTAssertLessThan(stress!, 5)
    }

    func testHighHRAndLowHRVProduceHighStress() {
        // Bad readings — should be high stress.
        let stress = SleepStress.compute(hr: 80, hrv: 15)
        XCTAssertNotNil(stress)
        XCTAssertGreaterThan(stress!, 80)
    }

    func testStressIsMonotonicInHR() {
        // Holding HRV constant, higher HR → higher stress.
        let lowHR = SleepStress.compute(hr: 55, hrv: 50)!
        let midHR = SleepStress.compute(hr: 65, hrv: 50)!
        let highHR = SleepStress.compute(hr: 75, hrv: 50)!
        XCTAssertLessThan(lowHR, midHR)
        XCTAssertLessThan(midHR, highHR)
    }

    func testStressIsMonotonicInHRV() {
        // Holding HR constant, lower HRV → higher stress.
        let highHRV = SleepStress.compute(hr: 60, hrv: 60)!
        let midHRV  = SleepStress.compute(hr: 60, hrv: 35)!
        let lowHRV  = SleepStress.compute(hr: 60, hrv: 15)!
        XCTAssertLessThan(highHRV, midHRV)
        XCTAssertLessThan(midHRV, lowHRV)
    }

    func testBaselineRelativeMode() {
        // With personal baselines, stress should be low when actual matches baseline,
        // even if absolute values are elevated.
        let stress = SleepStress.compute(hr: 65, hrv: 35, hrBaseline: 65, hrvBaseline: 35)
        XCTAssertNotNil(stress)
        XCTAssertLessThan(stress!, 5)
    }

    func testSingleSignalFallback() {
        // With only HR, the result is still meaningful (component doubled to fill 0–100).
        let stressOnlyHR = SleepStress.compute(hr: 80, hrv: nil)
        XCTAssertNotNil(stressOnlyHR)
        XCTAssertGreaterThan(stressOnlyHR!, 75)
    }

    func testLabelBuckets() {
        XCTAssertEqual(SleepStress.label(for: 10), "Low")
        XCTAssertEqual(SleepStress.label(for: 30), "Moderate")
        XCTAssertEqual(SleepStress.label(for: 60), "Elevated")
        XCTAssertEqual(SleepStress.label(for: 90), "High")
    }
}
