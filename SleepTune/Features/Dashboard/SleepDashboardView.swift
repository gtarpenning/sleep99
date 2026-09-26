import SwiftUI

#if DEBUG
#Preview("Dashboard") {
    let container = AppContainer.mock()
    return SleepDashboardView(viewModel: container.dashboardViewModel)
        .environment(container)
        .colorScheme(.dark)
}
#endif

/// Which score card was tapped; drives the breakdown sheet.
struct BreakdownSelection: Identifiable {
    let category: SleepIndicatorCategory
    var id: String { "\(category)" }
}

/// Full per-metric score breakdown, opened from the Sleep / Recovery cards.
struct ScoreBreakdownSheet: View {
    let indicators: [SleepIndicator]
    let monthlyStats: [String: MetricStats]
    let splitStats: [String: MetricSplitStats]
    let dayType: DayType
    let sleepScore: Double
    let recoveryScore: Double
    let initialCategory: SleepIndicatorCategory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MetricBreakdownView(
                    indicators: indicators, monthlyStats: monthlyStats, splitStats: splitStats,
                    dayType: dayType, sleepScore: sleepScore, recoveryScore: recoveryScore,
                    initialCategory: initialCategory
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .background(DS.bg)
            .navigationTitle("Score Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.fraction(0.9), .large])
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
        .preferredColorScheme(.dark)
    }
}

struct SleepDashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(AppContainer.self) private var container
    @Environment(\.openURL) private var openURL
    @State private var showsAlcoholSheet = false
    @State private var breakdownCategory: BreakdownSelection?

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
                    onNextDay: { shiftDate(by: 1) },
                    isLoading: viewModel.isSyncing && viewModel.summary.score == 0,
                    sleepInterval: viewModel.sleepInterval,
                    alcohol: viewModel.alcoholResult,
                    alcoholConfirmed: viewModel.alcoholConfirmed,
                    onAlcoholTap: { showsAlcoholSheet = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Breakdown cards
                ScoreBreakdownView(
                    summary: viewModel.summary,
                    indicators: viewModel.indicators,
                    onSelect: viewModel.indicators.isEmpty ? nil : { breakdownCategory = BreakdownSelection(category: $0) }
                )

                // Rolling sleep debt (7-night)
                if let debt = viewModel.sleepDebt {
                    SleepDebtCardView(summary: debt)
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

                // Tag insights + yesterday's activity strip
                InsightsBlockView(
                    tagCorrelations: viewModel.tagCorrelations,
                    activitySnapshot: viewModel.activitySnapshot,
                    activityMonthlyStats: viewModel.activityMonthlyStats,
                    selectedDate: viewModel.selectedDate
                )

                // Trend
                ScoreTrendsSectionView(viewModel: viewModel)
                    .padding(.horizontal, 20)

                // Subjective "how did you sleep" rating
                SubjectiveRatingButton(
                    store: container.subjectiveRatingStore,
                    date: viewModel.selectedDate
                )
                .padding(.horizontal, 20)

                // Tags — at the very bottom, low friction
                SleepTagBarView(store: container.tagStore, date: viewModel.selectedDate)
                    .padding(.top, 4)

                // Bottom breathing room
                Color.clear.frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
        .sheet(item: $breakdownCategory) { selection in
            ScoreBreakdownSheet(
                indicators: viewModel.indicators,
                monthlyStats: viewModel.monthlyStats,
                splitStats: viewModel.monthlySplitStats,
                dayType: viewModel.selectedDayType,
                sleepScore: viewModel.summary.sleepScore,
                recoveryScore: viewModel.summary.recoveryScore,
                initialCategory: selection.category
            )
        }
        .sheet(isPresented: $showsAlcoholSheet) {
            if let result = viewModel.alcoholResult {
                AlcoholDetailSheet(
                    result: result,
                    date: viewModel.selectedDate,
                    confirmed: viewModel.alcoholConfirmed,
                    onConfirm: { viewModel.confirmAlcohol($0) }
                )
            }
        }
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
