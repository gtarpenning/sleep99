import XCTest
@testable import SleepTune

final class MetricProfilesTests: XCTestCase {
    func testMetricTargetGuidanceUsesTopQuartileForOvernightHeartRate() {
        let stats = MetricStats(
            avg: 50,
            min: 45,
            max: 58,
            count: 10,
            sortedValues: [45, 46, 47, 48, 49, 50, 51, 52, 54, 58]
        )

        let guidance = metricTargetGuidance(name: "Overnight Heart Rate", stats: stats)

        XCTAssertNotNil(guidance)
        XCTAssertEqual(guidance?.value ?? -1, 47.25, accuracy: 0.001)
        XCTAssertEqual(guidance?.label, "Target set by your best 25% of nights over the last 30.")
    }

    func testMetricTargetGuidanceUsesUpperQuartileForHRV() {
        let stats = MetricStats(
            avg: 60,
            min: 40,
            max: 84,
            count: 8,
            sortedValues: [40, 48, 52, 56, 60, 68, 76, 84]
        )

        let guidance = metricTargetGuidance(name: "HRV", stats: stats)

        XCTAssertNotNil(guidance)
        XCTAssertEqual(guidance?.value ?? -1, 70, accuracy: 0.001)
        XCTAssertEqual(guidance?.label, "Target set by your top quartile nights over the last 30.")
    }

    func testMetricTargetGuidanceIsNilForNonPercentileMetrics() {
        let stats = MetricStats(
            avg: 7.5,
            min: 6.2,
            max: 8.4,
            count: 7,
            sortedValues: [6.2, 6.8, 7.0, 7.5, 7.8, 8.1, 8.4]
        )

        XCTAssertNil(metricTargetGuidance(name: "Sleep Duration", stats: stats))
    }
}
