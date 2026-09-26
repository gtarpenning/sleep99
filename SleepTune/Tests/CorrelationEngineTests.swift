import XCTest
@testable import SleepTune

final class CorrelationEngineTests: XCTestCase {
    private func night(_ i: Int, steps: Double, hrv: Double, vo2: Double? = nil, hr: Double? = nil) -> NightSummary {
        let d = Calendar.current.date(byAdding: .day, value: -i, to: Calendar.current.startOfDay(for: Date()))!
        var m: [String: Double] = ["HRV": hrv]
        if let hr { m["Overnight Heart Rate"] = hr }
        return NightSummary(night: d, score: 70, sleepScore: 70, recoveryScore: 70, metrics: m, maxHR: nil,
                            steps: steps, activeCalories: nil, exerciseMinutes: nil, peakHR: nil, vo2Max: vo2,
                            sleepStart: nil, sleepEnd: nil, dayType: .weekday, alcoholFlag: nil)
    }

    func testDetectsSameNightPositiveCorrelation() {
        let nights = (0..<40).map { i in night(i, steps: Double(i * 300), hrv: 30 + Double(i) * 0.5 + Double(i % 3)) }
        let f = CorrelationEngine.compute(nights: nights)
        let stepsHRV = f.first { $0.x == .steps && $0.y == .hrv }
        XCTAssertNotNil(stepsHRV)
        XCTAssertGreaterThan(stepsHRV!.r, 0.8)
        XCTAssertEqual(stepsHRV!.lagNights, 0)
        XCTAssertEqual(stepsHRV!.n, 40)
    }

    func testPrefersLagWhenEffectIsDelayed() {
        // HRV tonight tracks steps from two nights earlier.
        let steps = (0..<50).map { i in Double((i * 7919) % 100) * 100 }
        let nights = (0..<50).map { i -> NightSummary in
            // index i is i days ago; "2 nights earlier" = index i + 2
            let src = i + 2 < steps.count ? steps[i + 2] : 5000
            return night(i, steps: steps[i], hrv: 20 + src / 200)
        }
        let f = CorrelationEngine.finding(x: .steps, y: .hrv, lag: 2, nights: nights)
        XCTAssertNotNil(f); XCTAssertGreaterThan(f!.r, 0.95)
        let best = CorrelationEngine.compute(nights: nights).first { $0.x == .steps && $0.y == .hrv }
        XCTAssertEqual(best?.lagNights, 2)
    }

    func testNextDayDirectionUsesFollowingRecord() {
        // Steps stored on record i describe the day before night i, i.e. the day
        // after night i+1. Make steps track the HRV of the *previous* night.
        let hrv = (0..<50).map { i in 30 + Double((i * 7919) % 40) }
        let nights = (0..<50).map { i -> NightSummary in
            let prevNightHRV = i + 1 < hrv.count ? hrv[i + 1] : 50
            return night(i, steps: prevNightHRV * 200, hrv: hrv[i])
        }
        let f = CorrelationEngine.finding(x: .hrv, y: .steps, lag: -1, nights: nights)
        XCTAssertNotNil(f)
        XCTAssertGreaterThan(f!.r, 0.95)
        XCTAssertTrue(f!.isNextDay)
        XCTAssertTrue(f!.headline.hasSuffix("next day"))
        let same = CorrelationEngine.finding(x: .hrv, y: .steps, lag: 0, nights: nights)
        XCTAssertLessThan(abs(same?.r ?? 0), f!.r)
        XCTAssertNotNil(CorrelationEngine.compute(nights: nights).first { $0.x == .hrv && $0.y == .steps && $0.isNextDay })
    }

    func testTooFewNightsYieldsNothing() {
        let nights = (0..<10).map { i in night(i, steps: Double(i), hrv: Double(i)) }
        XCTAssertTrue(CorrelationEngine.compute(nights: nights).isEmpty)
    }

    func testWeakCorrelationsFiltered() {
        let nights = (0..<40).map { i in night(i, steps: Double((i * 37) % 11), hrv: Double((i * 53) % 13)) }
        XCTAssertNil(CorrelationEngine.compute(nights: nights).first { $0.x == .steps && $0.y == .hrv })
    }

    func testFitnessSentenceNeedsBothSlopes() {
        let rising = (0..<40).map { i in night(i, steps: 0, hrv: 40, vo2: 40 + Double(40 - i) * 0.1, hr: 60 - Double(40 - i) * 0.1) }
        let s = CorrelationEngine.fitnessSentence(nights: rising)
        XCTAssertNotNil(s)
        XCTAssertTrue(s!.contains("VO₂ max up"))
        XCTAssertTrue(s!.contains("sleeping HR down"))
        let flat = (0..<40).map { i in night(i, steps: 0, hrv: 40, vo2: 42, hr: 55) }
        XCTAssertNil(CorrelationEngine.fitnessSentence(nights: flat))
    }
}
