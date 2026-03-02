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
        container.authService.avatarEmoji = "😴"
        container.dashboardViewModel.monthlyStats = MockSleepData.monthlyStats
        container.dashboardViewModel.scoreHistory = MockSleepData.scoreHistory

        // Seed mock family members so the Family tab is previewable without CloudKit.
        container.familyFeedViewModel.members = [
            FamilyMember(id: "mock-user",  displayName: "You (Mock)",  avatarColor: "#5E5CE6", avatarEmoji: "😴",  isCurrentUser: true),
            FamilyMember(id: "mock-alex",  displayName: "Alex",        avatarColor: "#FF6B6B", avatarEmoji: "🏃",  isCurrentUser: false),
            FamilyMember(id: "mock-sam",   displayName: "Sam",         avatarColor: "#4ECDC4", avatarEmoji: "🌙",  isCurrentUser: false),
            FamilyMember(id: "mock-casey", displayName: "Casey",       avatarColor: "#FFE66D", avatarEmoji: nil,   isCurrentUser: false),
        ]
        container.familyFeedViewModel.scores = [
            "mock-alex":  DailySleepScore(id: "s1", memberID: "mock-alex",  date: Date(), score: 88, sleepScore: 85, recoveryScore: 91, totalSleepMinutes: 495, primarySource: .appleWatch),
            "mock-sam":   DailySleepScore(id: "s2", memberID: "mock-sam",   date: Date(), score: 62, sleepScore: 65, recoveryScore: 58, totalSleepMinutes: 390, primarySource: .oura),
            "mock-casey": DailySleepScore(id: "s3", memberID: "mock-casey", date: Date(), score: 74, sleepScore: 72, recoveryScore: 76, totalSleepMinutes: 450, primarySource: .appleHealth),
        ]
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
