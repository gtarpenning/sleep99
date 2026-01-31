import SwiftUI

@MainActor
struct ShareReportRenderer {
    var summary: SleepScoreSummary

    func renderImage() -> Image {
        let renderer = ImageRenderer(content: ShareReportCardView(summary: summary))
        renderer.scale = 2

        guard let cgImage = renderer.cgImage else {
            return Image(systemName: "moon.stars.fill")
        }

        return Image(decorative: cgImage, scale: 1)
    }
}
