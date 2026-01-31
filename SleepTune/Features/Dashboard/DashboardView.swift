import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(AppContainer.self) private var container
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if viewModel.authorizationState == .authorized {
                ScrollView {
                    VStack(alignment: .leading) {
                        ScoreCardView(summary: viewModel.summary)

                        FeelingCheckInView(selectedFeeling: $viewModel.feeling)
                            .onChange(of: viewModel.feeling) { _, newValue in
                                viewModel.updateFeeling(newValue)
                            }

                        LastNightSectionView(
                            stages: viewModel.lastNightStages,
                            heartRate: viewModel.lastNightHeartRateSeries,
                            hrv: viewModel.lastNightHRVSeries,
                            respiratoryRate: viewModel.lastNightRespiratoryRateSeries,
                            metrics: viewModel.lastNightMetrics
                        )

                        InsightsSectionView(insights: viewModel.insights)

                        IndicatorSnapshotListView(indicators: viewModel.indicators)

                        ShareCardView(shareText: container.shareViewModel.shareText, previewImage: container.shareViewModel.sharePreviewImage)

                        ScoreTrendsSectionView(viewModel: viewModel)
                    }
                    .padding()
                }
            } else {
                HealthAccessFullScreenView(
                    authorizationState: viewModel.authorizationState,
                    requestAccess: {
                        Task {
                            await viewModel.requestHealthAccess()
                        }
                    },
                    openSettings: {
                        guard let url = URL(string: "app-settings:") else { return }
                        openURL(url)
                    }
                )
            }
        }
        .navigationTitle("sleeptune")
        .navigationDestination(for: SleepIndicator.self) { indicator in
            IndicatorDetailView(indicator: viewModel.binding(for: indicator))
        }
        .toolbar {
            if viewModel.authorizationState == .authorized {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sync", systemImage: "arrow.triangle.2.circlepath") {
                        Task {
                            await viewModel.refreshFromHealthKit()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: container.shareViewModel.shareText,
                        preview: SharePreview("Sleep Score", image: container.shareViewModel.sharePreviewImage)
                    )
                }
            }
        }
    }
}
