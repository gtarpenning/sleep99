import Foundation
import Observation

@MainActor
@Observable
final class SyncCoordinator {
    var lastSyncDate: Date?
    private let eventStore: any AnalyticsEventStore
    private let client: any AnalyticsClient
    private let policy: AnalyticsSyncPolicy
    private let installIDStore: AnalyticsInstallIDStore
    private let backgroundScheduler: any BackgroundSyncScheduling
    private var lastAttemptDate: Date?
    private var consecutiveFailures: Int

    init(
        eventStore: any AnalyticsEventStore = FileAnalyticsEventStore(),
        client: any AnalyticsClient = RemoteAnalyticsClient(),
        policy: AnalyticsSyncPolicy = .default,
        installIDStore: AnalyticsInstallIDStore = AnalyticsInstallIDStore(),
        backgroundScheduler: any BackgroundSyncScheduling = AppRefreshBackgroundSyncScheduler(
            identifier: AnalyticsConfiguration.backgroundTaskIdentifier,
            earliestBeginInterval: AnalyticsSyncPolicy.default.minimumInterval
        )
    ) {
        self.eventStore = eventStore
        self.client = client
        self.policy = policy
        self.installIDStore = installIDStore
        self.backgroundScheduler = backgroundScheduler
        self.lastAttemptDate = nil
        self.consecutiveFailures = 0
    }

    func scheduleBackgroundSync() {
        backgroundScheduler.schedule()
    }

    func track(_ event: AnalyticsEvent) async {
        await eventStore.enqueue(event)
    }

    func syncIfNeeded() async {
        let now = Date()
        guard policy.canAttemptSync(
            lastAttempt: lastAttemptDate,
            consecutiveFailures: consecutiveFailures,
            now: now
        ) else {
            return
        }

        lastAttemptDate = now
        let records = await eventStore.fetchBatch(limit: policy.maxBatchSize)
        guard !records.isEmpty else { return }

        await eventStore.markAttempt(ids: records.map(\.id), at: now)

        let batch = AnalyticsBatch(
            events: records.map(\.event),
            context: AnalyticsContext.current(installID: installIDStore.installID()),
            sentAt: now
        )

        do {
            try await client.send(batch)
            await eventStore.remove(ids: records.map(\.id))
            lastSyncDate = now
            consecutiveFailures = 0
        } catch {
            consecutiveFailures += 1
        }
    }
}
