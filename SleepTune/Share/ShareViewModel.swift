import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ShareViewModel {
    private let dashboardViewModel: DashboardViewModel

    init(dashboardViewModel: DashboardViewModel) {
        self.dashboardViewModel = dashboardViewModel
    }

    var shareText: String {
        let score = dashboardViewModel.summary.score
        let formattedScore = score.formatted(.number.precision(.fractionLength(0)))
        return "My Sleep Score: \(formattedScore)"
    }

    var sharePreviewImage: Image {
        ShareReportRenderer(summary: dashboardViewModel.summary).renderImage()
    }
}
