import Foundation
import Observation

/// Walks HealthKit backwards night by night and fills `NightRecordStore`.
///
/// Runs once after install (or after the store is rebuilt), resumes from a
/// persisted cursor if the app is killed, and stops after `maxNights` or
/// three consecutive nights with no sleep data. Work is batched with yields
/// so the dashboard stays responsive.
@MainActor
@Observable
final class HistoryBackfill {
    enum State: Equatable {
        case idle
        case running(done: Int, estimatedTotal: Int)
        case complete(nights: Int)
    }

    nonisolated static let completeKey = "backfill.complete"
    nonisolated static let cursorKey   = "backfill.cursorOffset"
    static let maxNights   = 365
    static let emptyRunLimit = 3
    static let batchSize   = 14

    private(set) var state: State = .idle

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let store: NightRecordStore
    private let defaults = UserDefaults.standard
    private var task: Task<Void, Never>?

    init(healthKitClient: HealthKitClient, scoreEngine: SleepScoreEngine, store: NightRecordStore) {
        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.store = store
    }

    var isComplete: Bool { defaults.bool(forKey: Self.completeKey) }

    /// Starts (or resumes) the backfill if it hasn't completed. Safe to call repeatedly.
    func startIfNeeded() {
        guard !isComplete, task == nil else { return }
        task = Task { await run() }
    }

    /// Wipes the store and starts over. Triggered from Settings.
    func rebuild() async {
        task?.cancel()
        task = nil
        try? await store.deleteAll()
        defaults.set(false, forKey: Self.completeKey)
        defaults.set(0, forKey: Self.cursorKey)
        state = .idle
        startIfNeeded()
    }

    // MARK: - Work

    private func run() async {
        defer { task = nil }
        guard await healthKitClient.authorizationState() == .authorized else { return }

        var offset = defaults.integer(forKey: Self.cursorKey)
        var emptyRun = 0
        var written = (try? await store.count()) ?? 0
        state = .running(done: offset, estimatedTotal: Self.maxNights)

        while offset < Self.maxNights, emptyRun < Self.emptyRunLimit, !Task.isCancelled {
            let batchEnd = min(offset + Self.batchSize, Self.maxNights)
            for o in offset..<batchEnd {
                guard let night = Calendar.current.date(byAdding: .day, value: -o, to: Date()) else { continue }
                // Already scored by the dashboard (or a previous run) — keep it.
                if let existing = try? await store.record(for: night), existing.score > 0 {
                    emptyRun = 0
                    continue
                }
                if let summary = await fetchNight(night) {
                    try? await store.upsert(summary)
                    written += 1
                    emptyRun = 0
                } else {
                    emptyRun += 1
                    if emptyRun >= Self.emptyRunLimit { break }
                }
            }
            offset = batchEnd
            defaults.set(offset, forKey: Self.cursorKey)
            state = .running(done: offset, estimatedTotal: Self.maxNights)
            await Task.yield()
        }

        guard !Task.isCancelled else { return }
        defaults.set(true, forKey: Self.completeKey)
        state = .complete(nights: written)
    }

    /// Builds one night. Returns nil when HealthKit has no sleep for that date.
    /// Historic nights are scored without a personal baseline, matching the
    /// existing 30-day prefetch.
    func fetchNight(_ night: Date) async -> NightSummary? {
        guard let indicators = try? await healthKitClient.fetchSleepIndicators(for: night),
              !indicators.isEmpty,
              indicators.contains(where: { $0.name == "Sleep Duration" && $0.value > 0 })
        else { return nil }

        let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: night) ?? night
        async let activity = healthKitClient.fetchActivitySnapshot(for: prevDay)
        async let signals  = (try? healthKitClient.fetchSignals(for: night)) ?? []
        let summary = scoreEngine.score(indicators: indicators, weights: .default)
        return NightSummary.make(
            night: night,
            indicators: indicators,
            summary: summary,
            activity: await activity,
            signals: await signals
        )
    }
}
