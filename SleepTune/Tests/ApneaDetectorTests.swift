import XCTest
@testable import SleepTune

final class ApneaDetectorTests: XCTestCase {

    private func points(_ values: [(min: Double, value: Double)]) -> [SleepChartPoint] {
        let base = Date()
        return values.map { SleepChartPoint(date: base.addingTimeInterval($0.min * 60), value: $0.value) }
    }

    func testReturnsEmptyForFlatBaseline() {
        // 20 stable readings at ~14 br/min — should detect zero apnea events.
        let pts = points((0..<20).map { (Double($0) * 5, 14.0) })
        XCTAssertEqual(ApneaDetector.detect(in: pts), [])
    }

    func testDetectsClearSpikeAboveThreshold() {
        // Mostly flat with one obvious spike to 23 br/min.
        var raw: [(Double, Double)] = (0..<20).map { (Double($0) * 5, 14.0) }
        raw.append((100, 23.0))
        let events = ApneaDetector.detect(in: points(raw))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.value, 23.0)
    }

    func testClustersNearbySpikesIntoSingleEvent() {
        // Two spikes within 10 minutes — should collapse to one event.
        var raw: [(Double, Double)] = (0..<20).map { (Double($0) * 5, 14.0) }
        raw.append((100, 22.0))
        raw.append((105, 24.0))
        raw.append((110, 21.0))
        let events = ApneaDetector.detect(in: points(raw))
        XCTAssertEqual(events.count, 1)
        // Cluster's peak (24) is reported.
        XCTAssertEqual(events.first?.value, 24.0)
    }

    func testReturnsMultipleEventsWhenSeparatedByGap() {
        // Two clusters separated by 30 min — should produce 2 events.
        var raw: [(Double, Double)] = (0..<10).map { (Double($0) * 5, 14.0) }  // 0..45min
        raw.append((50, 22.0))                                                  // event 1
        for i in 0..<10 { raw.append((Double(60 + i * 5), 14.0)) }              // cooldown
        raw.append((130, 23.0))                                                 // event 2
        let events = ApneaDetector.detect(in: points(raw))
        XCTAssertEqual(events.count, 2)
    }

    func testReturnsEmptyForTinySample() {
        // Need at least 5 points to compute meaningful baseline.
        let pts = points([(0, 14), (5, 22), (10, 25), (15, 14)])
        XCTAssertEqual(ApneaDetector.detect(in: pts), [])
    }

    func testAbsoluteFloorPreventsFalsePositiveOnHighVariance() {
        // 2σ threshold could fire on small absolute deltas if σ is large; the +3 br/min
        // floor prevents this. Here: alternating 12/16 — σ is 2 br/min, so 2σ = 4.
        // Mean = 14, threshold = max(14+4, 14+3) = 18. A single 16 reading shouldn't fire.
        let raw: [(Double, Double)] = (0..<20).map { (Double($0) * 5, $0.isMultiple(of: 2) ? 12.0 : 16.0) }
        let events = ApneaDetector.detect(in: points(raw))
        XCTAssertEqual(events, [])
    }
}
