import SwiftUI

#if DEBUG
#Preview("Dashboard") {
    let container = AppContainer.mock()
    return SleepDashboardView(viewModel: container.dashboardViewModel)
        .environment(container)
        .colorScheme(.dark)
}
#endif

struct SleepDashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                Group {
                    if viewModel.authorizationState == .authorized {
                        authorizedView
                    } else {
                        HealthAccessFullScreenView(
                            authorizationState: viewModel.authorizationState,
                            requestAccess: { Task { await viewModel.requestHealthAccess() } },
                            openSettings: {
                                guard let url = URL(string: "x-apple-health://") else { return }
                                openURL(url)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if viewModel.isSyncing {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .tint(DS.textSecondary)
                            .scaleEffect(0.8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var authorizedView: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Hero
                ScoreHeroView(
                    summary: viewModel.summary,
                    date: viewModel.selectedDate,
                    bins: buildDopplerBins(
                        stages: viewModel.lastNightStages,
                        heartRate: viewModel.lastNightHeartRateSeries,
                        hrv: viewModel.lastNightHRVSeries,
                        monthlyAvgHR: viewModel.monthlyAverages["Overnight Heart Rate"] ?? 0
                    ),
                    hrDeviation: hrDeviationFromBaseline,
                    onPreviousDay: { shiftDate(by: -1) },
                    onNextDay: { shiftDate(by: 1) }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Breakdown cards (horizontal scroll)
                ScoreBreakdownView(
                    summary: viewModel.summary,
                    indicators: viewModel.indicators
                )

                // Full metric breakdown (expandable)
                if !viewModel.indicators.isEmpty {
                    MetricBreakdownView(
                        indicators: viewModel.indicators,
                        monthlyStats: viewModel.monthlyStats
                    )
                    .padding(.horizontal, 20)
                }

                // Sleep stages chart
                if !viewModel.lastNightStages.isEmpty || viewModel.lastNightHeartRateSeries != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Last Night")
                            .padding(.horizontal, 20)
                        SleepStagesOverlayChartView(
                            stages: viewModel.lastNightStages,
                            heartRate: viewModel.lastNightHeartRateSeries,
                            hrv: viewModel.lastNightHRVSeries,
                            respiratoryRate: viewModel.lastNightRespiratoryRateSeries
                        )
                        .padding(.horizontal, 20)
                    }
                }

                // Trend
                ScoreTrendsSectionView(viewModel: viewModel)
                    .padding(.horizontal, 20)

                // Bottom breathing room
                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Last night's mean HR minus the user's 30-day personal baseline, in bpm.
    /// Returns 0 if either value is unavailable.
    private var hrDeviationFromBaseline: Double {
        let baseline = viewModel.monthlyAverages["Overnight Heart Rate"]
        let lastNight = viewModel.indicators.first(where: { $0.name == "Overnight Heart Rate" })?.value
        guard let b = baseline, let n = lastNight, b > 0 else { return 0 }
        return n - b
    }

    private func shiftDate(by days: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .day, value: days, to: viewModel.selectedDate),
           newDate <= Date() {
            viewModel.selectedDate = newDate
            Task { await viewModel.load() }
        }
    }
}
