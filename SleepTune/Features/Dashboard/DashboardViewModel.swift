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
    var scoreHistory: [SleepScoreTrendPoint]
    var trendRange: SleepScoreTrendRange
    var monthlyStats: [String: MetricStats] = [:]

    /// Derived averages for use in scoreMetric() — computed from monthlyStats.
    var monthlyAverages: [String: Double] { monthlyStats.mapValues(\.avg) }

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let localStore: SleepLocalStore
    private let authService: AuthService
    private let cloudKitService: CloudKitService

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
            recalculateScore()
            await loadTrendHistory()
            await refreshLastNightData()
            await loadMonthlyStats()
        } else {
            // No cache — fetch from HealthKit
            await refreshFromHealthKit()
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
            recalculateScore()
            await refreshLastNightData()
            await loadTrendHistory()
            await loadMonthlyStats()
        } catch {
            authorizationState = await healthKitClient.authorizationState()
            if authorizationState == .authorized {
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
        Task { @MainActor in
            await localStore.saveScore(
                capturedSummary.score,
                sleepScore: capturedSummary.sleepScore,
                recoveryScore: capturedSummary.recoveryScore,
                for: selectedDate
            )
            await loadTrendHistory()
            await publishToCloudKit(capturedSummary)
        }
    }

    func updateTrendRange(_ range: SleepScoreTrendRange) {
        trendRange = range
        Task { @MainActor in
            await loadTrendHistory()
        }
    }

    // MARK: - Private

    /// Silently fetches and caches the previous 6 days so week navigation is instant.
    private func prefetchWeek() async {
        guard authorizationState == .authorized else { return }
        let today = Date()
        for offset in 1..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { continue }
            let cached = await localStore.loadIndicators(for: day)
            guard cached.isEmpty else { continue }
            if let fetched = try? await healthKitClient.fetchSleepIndicators(for: day), !fetched.isEmpty {
                await localStore.saveIndicators(fetched, for: day)
                // Persist score for trend chart
                let daySummary = scoreEngine.score(indicators: fetched, weights: .default)
                await localStore.saveScore(
                    daySummary.score,
                    sleepScore: daySummary.sleepScore,
                    recoveryScore: daySummary.recoveryScore,
                    for: day
                )
            }
        }
        await loadTrendHistory()
    }

    private func publishToCloudKit(_ summary: SleepScoreSummary) async {
        guard
            authService.isSignedIn,
            let userID = authService.userID,
            let displayName = authService.displayName
        else { return }
        let totalMinutes = indicators
            .filter { $0.category == .sleepArchitecture }
            .first
            .map { Int($0.value) } ?? 0
        try? await cloudKitService.publishTodayScore(
            summary,
            totalMinutes: totalMinutes,
            userID: userID,
            displayName: displayName,
            avatarColor: "#5E5CE6"
        )
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
            async let stagesTask = healthKitClient.fetchSleepStages(for: selectedDate)
            async let signalsTask = healthKitClient.fetchSignals(for: selectedDate)
            let (stages, signals) = try await (stagesTask, signalsTask)
            lastNightStages = stages

            // Clip signals to actual sleep stage window to avoid waking-hour outliers
            let stageStart = stages.map(\.startDate).min()
            let stageEnd   = stages.map(\.endDate).max()
            let clipped: [SleepSignalSample]
            if let start = stageStart, let end = stageEnd {
                clipped = signals.filter { $0.date >= start && $0.date <= end }
            } else {
                clipped = signals
            }

            lastNightHeartRateSeries      = makeSignalSeries(from: clipped, type: .heartRate)
            lastNightHRVSeries            = makeSignalSeries(from: clipped, type: .heartRateVariability)
            lastNightRespiratoryRateSeries = makeSignalSeries(from: clipped, type: .respiratoryRate)
        } catch {
            lastNightStages = []
            lastNightHeartRateSeries = nil
            lastNightHRVSeries = nil
            lastNightRespiratoryRateSeries = nil
        }
    }

    private func makeSignalSeries(from signals: [SleepSignalSample], type: SleepSignalType) -> SleepChartSeries? {
        let filtered = signals.filter { $0.name == type.rawValue }
        guard let unit = filtered.first?.unit, !filtered.isEmpty else { return nil }
        let points = filtered
            .map { SleepChartPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }
        return SleepChartSeries(title: type.displayName, unit: unit, points: points)
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
        scoreHistory = []
    }

    private func loadMonthlyStats() async {
        let cal = Calendar.current
        let today = Date()
        var totals: [String: (sum: Double, min: Double, max: Double, count: Int)] = [:]
        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let cached = await localStore.loadIndicators(for: day)
            for indicator in cached {
                var e = totals[indicator.name] ?? (0, .infinity, -.infinity, 0)
                e.sum   += indicator.value
                e.min    = Swift.min(e.min, indicator.value)
                e.max    = Swift.max(e.max, indicator.value)
                e.count += 1
                totals[indicator.name] = e
            }
        }
        monthlyStats = totals.compactMapValues { t in
            guard t.count > 0, t.min != .infinity else { return nil }
            return MetricStats(avg: t.sum / Double(t.count), min: t.min, max: t.max, count: t.count)
        }
    }

    private func loadTrendHistory() async {
        let end   = Date().startOfDay
        let start = Calendar.current.date(byAdding: .day, value: -(trendRange.daySpan - 1), to: end) ?? end
        scoreHistory = await localStore.loadScores(from: start, to: end)
    }
}
