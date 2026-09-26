import XCTest
import SwiftUI
@testable import SleepTune

/// Renders dashboard charts with mock data to PNGs under /tmp so chart changes
/// can be eyeballed without driving the simulator UI. Never asserts on pixels.
@MainActor
final class ChartSnapshotTests: XCTestCase {

    func testRenderLastNightChart() throws {
        let view = SleepStagesOverlayChartView(
            stages: MockSleepData.stages,
            heartRate: MockSleepData.heartRateSeries,
            hrv: MockSleepData.hrvSeries,
            respiratoryRate: MockSleepData.rrSeries
        )
        try Self.write(view, name: "lastnight", width: 350)
    }

    static func write<V: View>(_ view: V, name: String, width: CGFloat) throws {
        let wrapped = view
            .frame(width: width)
            .padding(16)
            .background(DS.bg)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("render failed for \(name)")
        }
        let url = URL(fileURLWithPath: "/tmp/st-snap-\(name).png")
        try data.write(to: url)
    }
}
