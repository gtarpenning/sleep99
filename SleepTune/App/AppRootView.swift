import SwiftUI

struct AppRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            SleepDashboardView(viewModel: container.dashboardViewModel)
                .tabItem { Label("Sleep", systemImage: "moon.fill") }

            FamilyFeedView(viewModel: container.familyFeedViewModel)
                .tabItem { Label("Family", systemImage: "person.2.fill") }
                .onAppear { syncCurrentUserScore() }
                .onChange(of: container.dashboardViewModel.summary.score) { _, _ in syncCurrentUserScore() }

            NavigationStack {
                SettingsView(viewModel: container.settingsViewModel)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(DS.purple)
        .colorScheme(.dark)
    }

    private func syncCurrentUserScore() {
        let dash = container.dashboardViewModel
        guard dash.summary.score > 0 else { return }
        let totalMinutes = dash.indicators.first(where: { $0.name == "Sleep Duration" })
            .map { Int($0.value * 60) } ?? 0
        container.familyFeedViewModel.currentUserScore = DailySleepScore(
            id: "current-user",
            memberID: container.authService.userID ?? "me",
            date: dash.selectedDate,
            score: dash.summary.score,
            sleepScore: dash.summary.sleepScore,
            recoveryScore: dash.summary.recoveryScore,
            totalSleepMinutes: totalMinutes,
            primarySource: .appleHealth
        )
    }
}
