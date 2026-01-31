import Observation
import Foundation

@MainActor
@Observable
final class AppContainer {
    let dashboardViewModel: DashboardViewModel
    let settingsViewModel: SettingsViewModel
    let shareViewModel: ShareViewModel

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let localStore: SleepLocalStore
    private let syncCoordinator: SyncCoordinator

    init(
        healthKitClient: HealthKitClient = HealthKitClient(),
        scoreEngine: SleepScoreEngine = SleepScoreEngine(),
        localStore: SleepLocalStore = InMemorySleepLocalStore(),
        syncCoordinator: SyncCoordinator = SyncCoordinator()
    ) {
        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.localStore = localStore
        self.syncCoordinator = syncCoordinator

        let dashboardViewModel = DashboardViewModel(
            healthKitClient: healthKitClient,
            scoreEngine: scoreEngine,
            localStore: localStore,
            syncCoordinator: syncCoordinator
        )
        self.dashboardViewModel = dashboardViewModel
        self.settingsViewModel = SettingsViewModel(localStore: localStore, healthKitClient: healthKitClient)
        self.shareViewModel = ShareViewModel(dashboardViewModel: dashboardViewModel)

        Task { @MainActor in
            await syncCoordinator.track(AnalyticsEvent(name: AnalyticsEventName.appLaunched))
        }
    }

    func scheduleBackgroundSync() {
        syncCoordinator.scheduleBackgroundSync()
    }

    func handleBackgroundRefresh() async {
        await syncCoordinator.syncIfNeeded()
        syncCoordinator.scheduleBackgroundSync()
    }
}
