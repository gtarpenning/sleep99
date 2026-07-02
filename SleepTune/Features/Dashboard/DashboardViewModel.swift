import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var selectedDate: Date
    var indicators: [SleepIndicator]
    var summary: SleepScoreSummary
    var isSyncing: Bool
    var authorizationState: HealthAuthorizationState
    var lastNightStages: [SleepStageSample]
    var lastNightHeartRateSeries: SleepChartSeries?
    var lastNightHRVSeries: SleepChartSeries?
    var lastNightRespiratoryRateSeries: SleepChartSeries?
    var activitySnapshot: DailyActivitySnapshot?
    var tagCorrelations: [TagCorrelation]
    var scoreHistory: [SleepScoreTrendPoint]
    var trendRange: SleepScoreTrendRange
    var monthlyStats: [String: MetricStats] = [:]
    var activityMonthlyStats: [String: MetricStats] = [:]
    var sleepDebt: SleepDebtSummary?

    /// Effective baselines for scoreMetric() — delegates to effectiveBaseline() which is
    /// the single source of truth for aspirational percentile targets across all metrics.
    var monthlyAverages: [String: Double] {
        monthlyStats.reduce(into: [:]) { result, pair in
            result[pair.key] = effectiveBaseline(name: pair.key, stats: pair.value)
        }
    }

    /// Sleep window for the selected night, derived from stage data.
    var sleepInterval: DateInterval? {
        let asleep = lastNightStages.filter { $0.stage != .inBed && $0.stage != .awake }
        guard let start = asleep.map(\.startDate).min(),
              let end   = asleep.map(\.endDate).max() else { return nil }
        return DateInterval(start: start, end: end)
    }

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let localStore: SleepLocalStore
    private let authService: AuthService
    private let cloudKitService: CloudKitService
    private let tagInsightEngine = TagInsightEngine()
    var tagStore: SleepTagStore?

    init(
        healthKitClient: HealthKitClient,
        scoreEngine: SleepScoreEngine,
        localStore: SleepLocalStore,
        authService: AuthService,
        cloudKitService: CloudKitService
    ) {
        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.localStore = localStore
        self.authService = authService
        self.cloudKitService = cloudKitService
        let today = Date()
        self.selectedDate = today
        self.indicators = []
        self.summary = SleepScoreSummary(
            date: today,
            score: 0,
            trend: 0,
            sleepScore: 0,
            recoveryScore: 0,
            confidence: 0,
            primarySource: .appleHealth
        )
        self.isSyncing = false
        self.authorizationState = .needsPermission
        self.lastNightStages = []
        self.lastNightHeartRateSeries = nil
        self.lastNightHRVSeries = nil
        self.lastNightRespiratoryRateSeries = nil
        self.activitySnapshot = nil
        self.tagCorrelations = []
        self.scoreHistory = []
        self.trendRange = .week

        Task { @MainActor in
            await load()
            await prefetchWeek()
        }
    }

    // MARK: - Load (cache-first, auto-fetches if missing)

    func load() async {
        authorizationState = await healthKitClient.authorizationState()
        guard authorizationState == .authorized else {
            resetDashboardData()
            return
        }

        let stored = await localStore.loadIndicators(for: selectedDate)
        if !stored.isEmpty {
            indicators = stored
            // Load all supporting data concurrently before touching the score.
            await loadTrendHistory()
            await refreshLastNightData()
            await loadMonthlyStats()
            await loadActivityMonthlyStats()

            // If live stages show the cached duration is significantly off, refetch and show
            // only that single corrected score. Otherwise score once from cache.
            // Either way the score is set exactly ONCE — no A→B flicker.
            if shouldRefreshCachedIndicators() {
                await refreshFromHealthKit()
            } else {
                recalculateScore()
            }
        } else {
            // No cache — fetch from HealthKit (also handles monthly stats + score inside).
            await refreshFromHealthKit()
            await loadActivityMonthlyStats()
        }
    }

    // MARK: - HealthKit fetch for selected date

    func refreshFromHealthKit() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            if authorizationState != .authorized {
                try await healthKitClient.requestAuthorization()
                authorizationState = await healthKitClient.authorizationState()
            }
            guard authorizationState == .authorized else {
                resetDashboardData()
                return
            }
            let fetched = try await healthKitClient.fetchSleepIndicators(for: selectedDate)
            if !fetched.isEmpty {
                indicators = fetched
                await localStore.saveIndicators(fetched, for: selectedDate)
            }
            // Monthly stats must be loaded BEFORE scoring so personal baselines are applied.
            // This is the single place the score is set in this path.
            await loadMonthlyStats()
            recalculateScore()
            await refreshLastNightData()
            await loadTrendHistory()
        } catch {
            authorizationState = await healthKitClient.authorizationState()
            if authorizationState == .authorized {
                await loadMonthlyStats()
                recalculateScore()
                await refreshLastNightData()
            } else {
                resetDashboardData()
            }
        }
    }

    func requestHealthAccess() async {
        do {
            try await healthKitClient.requestAuthorization()
        } catch {}
        authorizationState = await healthKitClient.authorizationState()
        if authorizationState == .authorized {
            await refreshFromHealthKit()
            await prefetchWeek()
        } else {
            resetDashboardData()
        }
    }

    func recalculateScore() {
        guard authorizationState == .authorized else { return }
        summary = scoreEngine.score(indicators: indicators, weights: .default, monthlyAverages: monthlyAverages)
        let capturedSummary = summary
        let capturedIndicators = indicators
        let capturedDate = selectedDate
        Task { @MainActor in
            await localStore.saveScore(
                capturedSummary.score,
                sleepScore: capturedSummary.sleepScore,
                recoveryScore: capturedSummary.recoveryScore,
                for: capturedDate
            )
            await loadTrendHistory()
            await loadSleepDebt()
            await publishToCloudKit(capturedSummary)
            await refreshTagInsights()
            // Write the widget snapshot only for today's score so the Home Screen
            // doesn't reflect whichever historical date the user is browsing.
            if Calendar.current.isDateInToday(capturedDate) {
                let totalMinutes = capturedIndicators
                    .first(where: { $0.name == "Sleep Duration" })
                    .map { Int($0.value * 60) } ?? 0
                let window = WidgetSnapshotStore.chartWindow(
                    heartRate: lastNightHeartRateSeries, stages: lastNightStages
                )
                WidgetSnapshotStore.save(WidgetSnapshot(
                    updatedAt: Date(),
                    score: capturedSummary.score,
                    sleepScore: capturedSummary.sleepScore,
                    recoveryScore: capturedSummary.recoveryScore,
                    totalSleepMinutes: totalMinutes,
                    stages: window.map { WidgetSnapshotStore.stageSpans(from: lastNightStages, window: $0) } ?? [],
                    hr:  window.map { WidgetSnapshotStore.linePoints(from: lastNightHeartRateSeries, window: $0) } ?? [],
                    hrv: window.map { WidgetSnapshotStore.linePoints(from: lastNightHRVSeries, window: $0) } ?? [],
                    rr:  window.map { WidgetSnapshotStore.linePoints(from: lastNightRespiratoryRateSeries, window: $0) } ?? []
                ))
            }
        }
    }

    func updateTrendRange(_ range: SleepScoreTrendRange) {
        trendRange = range
        Task { @MainActor in
            await loadTrendHistory()
        }
    }

    // MARK: - Private

    /// Silently fetches and caches the previous 30 days for monthly stats and week navigation.
    /// Already-cached days are skipped, so subsequent launches are fast.
    private func prefetchWeek() async {
        guard authorizationState == .authorized else { return }
        let today = Date()
        for offset in 1..<30 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { continue }
            let cached = await localStore.loadIndicators(for: day)
            if cached.isEmpty {
                if let fetched = try? await healthKitClient.fetchSleepIndicators(for: day), !fetched.isEmpty {
                    await localStore.saveIndicators(fetched, for: day)
                    let daySummary = scoreEngine.score(indicators: fetched, weights: .default)
                    await localStore.saveScore(
                        daySummary.score,
                        sleepScore: daySummary.sleepScore,
                        recoveryScore: daySummary.recoveryScore,
                        for: day
                    )
                }
            }
            if await localStore.loadActivitySnapshot(for: day) == nil {
                let snap = await healthKitClient.fetchActivitySnapshot(for: day)
                await localStore.saveActivitySnapshot(snap, for: day)
            }
        }
        await loadTrendHistory()
        await loadActivityMonthlyStats()
    }

    private func publishToCloudKit(_ summary: SleepScoreSummary) async {
        guard
            authService.isSignedIn,
            let userID = authService.userID,
            let displayName = authService.displayName
        else { return }
        // Sleep Duration is in hours; convert to minutes for the family feed display.
        let totalMinutes = indicators
            .first(where: { $0.name == "Sleep Duration" })
            .map { Int($0.value * 60) } ?? 0
        let avgHR  = indicators.first(where: { $0.name == "Overnight Heart Rate" }).map { Int($0.value.rounded()) }
        let avgHRV = indicators.first(where: { $0.name == "HRV" }).map { Int($0.value.rounded()) }
        do {
            try await cloudKitService.publishTodayScore(
                summary,
                totalMinutes: totalMinutes,
                userID: userID,
                displayName: displayName,
                avatarColor: "#5E5CE6",
                avatarEmoji: authService.avatarEmoji,
                avgHR: avgHR,
                avgHRV: avgHRV
            )
        } catch {}
    }

    private func refreshLastNightData() async {
        guard authorizationState == .authorized else {
            lastNightStages = []
            lastNightHeartRateSeries = nil
            lastNightHRVSeries = nil
            lastNightRespiratoryRateSeries = nil
            return
        }

        do {
            let activityDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            async let stagesTask    = healthKitClient.fetchSleepStages(for: selectedDate)
            async let signalsTask   = healthKitClient.fetchSignals(for: selectedDate)
            async let activityTask  = healthKitClient.fetchActivitySnapshot(for: activityDate)
            let (stages, signals, activity) = try await (stagesTask, signalsTask, activityTask)

            // Find the PRIMARY sleep block — the longest contiguous run of asleep stages.
            // Using min/max of all asleep records breaks when third-party apps write wide
            // inBed records or when there are isolated outlier samples outside the main block.
            if let window = primarySleepWindow(from: stages) {
                lastNightStages = stages.filter { $0.startDate < window.end && $0.endDate > window.start }
                let clipped = signals.filter { $0.date >= window.start && $0.date <= window.end }
                lastNightHeartRateSeries       = makeSignalSeries(from: clipped, type: .heartRate)
                lastNightHRVSeries             = makeSignalSeries(from: clipped, type: .heartRateVariability)
                lastNightRespiratoryRateSeries = makeSignalSeries(from: clipped, type: .respiratoryRate)
            } else {
                lastNightStages = stages
                lastNightHeartRateSeries       = makeSignalSeries(from: signals, type: .heartRate)
                lastNightHRVSeries             = makeSignalSeries(from: signals, type: .heartRateVariability)
                lastNightRespiratoryRateSeries = makeSignalSeries(from: signals, type: .respiratoryRate)
            }
            activitySnapshot = activity
            await localStore.saveActivitySnapshot(activity, for: activityDate)
        } catch {
            lastNightStages = []
            lastNightHeartRateSeries = nil
            lastNightHRVSeries = nil
            lastNightRespiratoryRateSeries = nil
        }
    }

    /// Finds the longest contiguous block of asleep stages (ignoring inBed/awake).
    /// Tolerates gaps up to 45 min between segments (brief awakenings, stage transitions).
    /// Returns nil only if there are no asleep stages at all.
    private func primarySleepWindow(from stages: [SleepStageSample]) -> DateInterval? {
        let asleep = stages
            .filter { $0.stage != .inBed && $0.stage != .awake }
            .sorted { $0.startDate < $1.startDate }
        guard !asleep.isEmpty else { return nil }

        let gapTolerance: TimeInterval = 45 * 60

        // Build contiguous blocks
        var blocks: [DateInterval] = []
        var blockStart = asleep[0].startDate
        var blockEnd   = asleep[0].endDate

        for stage in asleep.dropFirst() {
            if stage.startDate.timeIntervalSince(blockEnd) <= gapTolerance {
                blockEnd = max(blockEnd, stage.endDate)
            } else {
                blocks.append(DateInterval(start: blockStart, end: blockEnd))
                blockStart = stage.startDate
                blockEnd   = stage.endDate
            }
        }
        blocks.append(DateInterval(start: blockStart, end: blockEnd))

        // Return the longest block (most likely the main sleep session)
        return blocks.max(by: { $0.duration < $1.duration })
    }

    private func makeSignalSeries(from signals: [SleepSignalSample], type: SleepSignalType) -> SleepChartSeries? {
        let filtered = signals.filter { $0.name == type.rawValue }
        guard let unit = filtered.first?.unit, !filtered.isEmpty else { return nil }
        let points = filtered
            .map { SleepChartPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }
        return SleepChartSeries(title: type.displayName, unit: unit, points: points)
    }

    private func shouldRefreshCachedIndicators() -> Bool {
        guard let cachedSleepDuration = indicators.first(where: { $0.name == "Sleep Duration" })?.value else {
            return false
        }

        let stageDerivedHours = stageAsleepHours(from: lastNightStages)
        guard stageDerivedHours > 0 else { return false }

        // Only trigger when mismatch is large enough to indicate stale/incorrect cache.
        return abs(stageDerivedHours - cachedSleepDuration) >= 1.5
    }

    private func stageAsleepHours(from stages: [SleepStageSample]) -> Double {
        let asleepStages = stages.filter { $0.stage != .inBed && $0.stage != .awake }
        let seconds = asleepStages.reduce(0.0) { partial, sample in
            partial + sample.endDate.timeIntervalSince(sample.startDate)
        }
        return seconds / 3600
    }

    private func resetDashboardData() {
        indicators = []
        summary = SleepScoreSummary(
            date: selectedDate,
            score: 0,
            trend: 0,
            sleepScore: 0,
            recoveryScore: 0,
            confidence: 0,
            primarySource: .appleHealth
        )
        lastNightStages = []
        lastNightHeartRateSeries = nil
        lastNightHRVSeries = nil
        lastNightRespiratoryRateSeries = nil
        activitySnapshot = nil
        tagCorrelations = []
        scoreHistory = []
    }

    private func loadMonthlyStats() async {
        let cal = Calendar.current
        let today = Date()
        var totals: [String: (sum: Double, min: Double, max: Double, count: Int, values: [Double])] = [:]
        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let cached = await localStore.loadIndicators(for: day)
            for indicator in cached {
                var e = totals[indicator.name] ?? (0, .infinity, -.infinity, 0, [])
                e.sum   += indicator.value
                e.min    = Swift.min(e.min, indicator.value)
                e.max    = Swift.max(e.max, indicator.value)
                e.count += 1
                e.values.append(indicator.value)
                totals[indicator.name] = e
            }
        }
        monthlyStats = totals.compactMapValues { t in
            guard t.count > 0, t.min != .infinity else { return nil }
            return MetricStats(
                avg: t.sum / Double(t.count),
                min: t.min,
                max: t.max,
                count: t.count,
                sortedValues: t.values.sorted()
            )
        }
    }

    private func loadActivityMonthlyStats() async {
        let cal = Calendar.current
        let today = Date()
        var totals: [String: (sum: Double, min: Double, max: Double, count: Int, values: [Double])] = [:]

        func collect(_ v: Double?, key: String) {
            guard let v, v > 0 else { return }
            var e = totals[key] ?? (0, .infinity, -.infinity, 0, [])
            e.sum += v; e.min = Swift.min(e.min, v); e.max = Swift.max(e.max, v)
            e.count += 1; e.values.append(v)
            totals[key] = e
        }

        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let snap = await localStore.loadActivitySnapshot(for: day) else { continue }
            collect(snap.steps,          key: "steps")
            collect(snap.activeCalories, key: "kcal")
            collect(snap.exerciseMinutes,key: "ex")
            collect(snap.peakHR,         key: "peakhr")
            collect(snap.floorsClimbed,  key: "floors")
            collect(snap.standMinutes,   key: "stand")
            collect(snap.vo2Max,         key: "vo2")
        }

        let newStats = totals.compactMapValues { t -> MetricStats? in
            guard t.count > 0, t.min != .infinity else { return nil }
            return MetricStats(avg: t.sum / Double(t.count), min: t.min, max: t.max, count: t.count, sortedValues: t.values.sorted())
        }
        // Only overwrite if we actually found data — preserves mock-seeded stats in DEBUG mode.
        if !newStats.isEmpty { activityMonthlyStats = newStats }
    }

    private func loadSleepDebt() async {
        let cal = Calendar.current
        let today = Date()
        var nights: [SleepDebtNight] = []
        for offset in 1...7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let indicators = await localStore.loadIndicators(for: day)
            guard let duration = indicators.first(where: { $0.name == "Sleep Duration" })?.value else { continue }
            let activity = await localStore.loadActivitySnapshot(for: day)
            nights.append(SleepDebtNight(date: day, hours: duration, exerciseMinutes: activity?.exerciseMinutes))
        }
        guard !nights.isEmpty else { return }
        sleepDebt = SleepDebt.compute(nights: nights)
    }

    private func refreshTagInsights() async {
        var correlations: [TagCorrelation] = []
        if let tagStore, !tagStore.availableTags.isEmpty {
            correlations = await tagInsightEngine.compute(tagStore: tagStore, localStore: localStore)
        }
        // Activity-level correlation (active vs rest days) — independent of user tags,
        // so it surfaces even before the user has tagged any nights.
        let activityCorrelations = await tagInsightEngine.computeActivityCorrelations(localStore: localStore)
        tagCorrelations = correlations + activityCorrelations
    }

    private func loadTrendHistory() async {
        let end   = Date().startOfDay
        let start = Calendar.current.date(byAdding: .day, value: -(trendRange.daySpan - 1), to: end) ?? end
        scoreHistory = await localStore.loadScores(from: start, to: end)
    }
}
