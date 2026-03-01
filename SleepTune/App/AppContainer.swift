import Observation
import Foundation

#if DEBUG
extension AppContainer {
    /// Creates a container wired to MockHealthKitClient.
    /// Auth is pre-seeded so Sign In is skipped.
    static func mock() -> AppContainer {
        // InMemorySleepStore ensures MockHealthKitClient is always called —
        // no stale UserDefaults cache can shadow the mock indicators.
        let container = AppContainer(
            healthKitClient: MockHealthKitClient(),
            localStore: InMemorySleepStore()
        )
        container.authService.userID = "mock-user"
        container.authService.displayName = "You (Mock)"
        container.dashboardViewModel.monthlyStats = MockSleepData.monthlyStats
        container.dashboardViewModel.scoreHistory = MockSleepData.scoreHistory
        return container
    }
}
#endif

@MainActor
@Observable
final class AppContainer {
    let authService: AuthService
    let cloudKitService: CloudKitService
    let dashboardViewModel: DashboardViewModel
    let settingsViewModel: SettingsViewModel
    let familyFeedViewModel: FamilyFeedViewModel

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let localStore: SleepLocalStore

    init(
        healthKitClient: HealthKitClient = HealthKitClient(),
        scoreEngine: SleepScoreEngine = SleepScoreEngine(),
        localStore: SleepLocalStore = UserDefaultsSleepStore()
    ) {
        let auth = AuthService()
        let cloudKit = CloudKitService()

        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.localStore = localStore
        self.authService = auth
        self.cloudKitService = cloudKit

        self.dashboardViewModel = DashboardViewModel(
            healthKitClient: healthKitClient,
            scoreEngine: scoreEngine,
            localStore: localStore,
            authService: auth,
            cloudKitService: cloudKit
        )
        self.settingsViewModel = SettingsViewModel(healthKitClient: healthKitClient)
        self.familyFeedViewModel = FamilyFeedViewModel(
            authService: auth,
            cloudKitService: cloudKit
        )
    }
}
