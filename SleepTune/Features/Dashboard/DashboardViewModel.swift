import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var selectedDate: Date
    var indicators: [SleepIndicator]
    var summary: SleepScoreSummary
    var feeling: SleepFeeling?
    var isSyncing: Bool
    var weights: SleepScoreWeights
    var authorizationState: HealthAuthorizationState
    var insights: [SleepInsight]
    var lastNightStages: [SleepStageSample]
    var lastNightMetrics: LastNightMetrics
    var lastNightHeartRateSeries: SleepChartSeries?
    var lastNightHRVSeries: SleepChartSeries?
    var lastNightRespiratoryRateSeries: SleepChartSeries?
    var scoreHistory: [SleepScoreTrendPoint]
    var trendRange: SleepScoreTrendRange

    private let healthKitClient: HealthKitClient
    private let scoreEngine: SleepScoreEngine
    private let localStore: SleepLocalStore
    private let syncCoordinator: SyncCoordinator

    init(
        healthKitClient: HealthKitClient,
        scoreEngine: SleepScoreEngine,
        localStore: SleepLocalStore,
        syncCoordinator: SyncCoordinator
    ) {
        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.localStore = localStore
        self.syncCoordinator = syncCoordinator
        let today = Date()
        self.selectedDate = today
        self.indicators = []
        self.summary = SleepScoreSummary(
            date: today,
            score: 0,
            trend: 0,
            components: [],
            confidence: 0,
            note: ""
        )
        self.feeling = nil
        self.isSyncing = false
        self.weights = .default
        self.authorizationState = .needsPermission
        self.insights = []
        self.lastNightStages = []
        self.lastNightMetrics = .empty
        self.lastNightHeartRateSeries = nil
        self.lastNightHRVSeries = nil
        self.lastNightRespiratoryRateSeries = nil
        self.scoreHistory = []
        self.trendRange = .week

        Task { @MainActor in
            await load()
        }
    }

    func load() async {
        authorizationState = await healthKitClient.authorizationState()
        await syncCoordinator.track(
            AnalyticsEvent(
                name: AnalyticsEventName.dashboardLoaded,
                dimensions: [
                    "authorized": authorizationState == .authorized ? "true" : "false"
                ]
            )
        )
        let storedWeights = await localStore.loadWeights()
        weights = storedWeights
        guard authorizationState == .authorized else {
            resetDashboardData()
            return
        }

        let storedIndicators = await localStore.loadIndicators(for: selectedDate)
        if storedIndicators.isEmpty {
            indicators = sampleIndicators()
        } else {
            indicators = storedIndicators
        }

        recalculateScore()
        await loadTrendHistory()
        await refreshLastNightData()
    }

    func refreshFromHealthKit() async {
        isSyncing = true
        defer { isSyncing = false }

        await syncCoordinator.track(
            AnalyticsEvent(
                name: AnalyticsEventName.healthKitRefreshRequested,
                dimensions: [
                    "selected_date": selectedDate.formatted(.iso8601)
                ]
            )
        )

        do {
            if authorizationState != .authorized {
                try await healthKitClient.requestAuthorization()
                authorizationState = await healthKitClient.authorizationState()
            }
            guard authorizationState == .authorized else {
                resetDashboardData()
                return
            }
            let healthIndicators = try await healthKitClient.fetchSleepIndicators(for: selectedDate)
            if !healthIndicators.isEmpty {
                indicators = healthIndicators
                await localStore.saveIndicators(healthIndicators, for: selectedDate)
            }
            recalculateScore()
            await refreshLastNightData()
            await syncCoordinator.syncIfNeeded()
            await syncCoordinator.track(
                AnalyticsEvent(
                    name: AnalyticsEventName.healthKitRefreshCompleted,
                    dimensions: [
                        "result": "success",
                        "authorized": authorizationState == .authorized ? "true" : "false"
                    ],
                    measurements: [
                        "indicator_count": Double(healthIndicators.count)
                    ]
                )
            )
        } catch {
            authorizationState = await healthKitClient.authorizationState()
            if authorizationState == .authorized {
                recalculateScore()
                await loadTrendHistory()
                await refreshLastNightData()
            } else {
                resetDashboardData()
            }
            await syncCoordinator.track(
                AnalyticsEvent(
                    name: AnalyticsEventName.healthKitRefreshCompleted,
                    dimensions: [
                        "result": "failure",
                        "authorized": authorizationState == .authorized ? "true" : "false"
                    ]
                )
            )
        }
    }

    func requestHealthAccess() async {
        do {
            try await healthKitClient.requestAuthorization()
            authorizationState = await healthKitClient.authorizationState()
            if authorizationState == .authorized {
                await refreshFromHealthKit()
            } else {
                resetDashboardData()
            }
        } catch {
            authorizationState = await healthKitClient.authorizationState()
            if authorizationState != .authorized {
                resetDashboardData()
            }
        }
    }

    func updateIndicator(_ indicator: SleepIndicator) {
        guard let index = indicators.firstIndex(where: { $0.id == indicator.id }) else { return }
        indicators[index] = indicator
        Task { @MainActor in
            await localStore.saveIndicators(indicators, for: selectedDate)
            await syncCoordinator.track(
                AnalyticsEvent(
                    name: AnalyticsEventName.indicatorUpdated,
                    dimensions: [
                        "indicator": indicator.name,
                        "category": indicator.category.rawValue
                    ],
                    measurements: [
                        "value": indicator.value
                    ]
                )
            )
        }
        recalculateScore()
    }

    func updateFeeling(_ feeling: SleepFeeling?) {
        self.feeling = feeling
        Task { @MainActor in
            await syncCoordinator.track(
                AnalyticsEvent(
                    name: AnalyticsEventName.feelingUpdated,
                    dimensions: [
                        "feeling": feeling?.rawValue ?? "none"
                    ]
                )
            )
        }
        recalculateScore()
    }

    func recalculateScore() {
        guard authorizationState == .authorized else {
            resetDashboardData()
            return
        }
        summary = scoreEngine.score(
            indicators: indicators,
            weights: weights,
            feeling: feeling
        )
        insights = makeInsights()

        Task { @MainActor in
            await localStore.saveScore(summary.score, for: selectedDate)
            await loadTrendHistory()
        }
    }

    func updateTrendRange(_ range: SleepScoreTrendRange) {
        trendRange = range
        Task { @MainActor in
            await loadTrendHistory()
        }
    }

    func binding(for indicator: SleepIndicator) -> Binding<SleepIndicator> {
        Binding(
            get: {
                self.indicators.first(where: { $0.id == indicator.id }) ?? .placeholder
            },
            set: { updated in
                self.updateIndicator(updated)
            }
        )
    }

    private func sampleIndicators() -> [SleepIndicator] {
        [
            SleepIndicator(
                name: "Sleep Duration",
                detail: "Total time asleep",
                value: 7.2,
                unit: "hr",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 5...9
            ),
            SleepIndicator(
                name: "Sleep Efficiency",
                detail: "Time asleep vs in bed",
                value: 0.88,
                unit: "",
                category: .sleepArchitecture,
                source: .appleWatch,
                range: 0.7...0.98
            ),
            SleepIndicator(
                name: "Sleep Latency",
                detail: "Minutes to fall asleep",
                value: 18,
                unit: "min",
                category: .sleepArchitecture,
                source: .appleWatch
            ),
            SleepIndicator(
                name: "Long Awakenings",
                detail: "Awake periods 10+ min",
                value: 1,
                unit: "x",
                category: .sleepArchitecture,
                source: .appleWatch
            ),
            SleepIndicator(
                name: "HRV",
                detail: "Recovery signal",
                value: 52,
                unit: "ms",
                category: .recovery,
                source: .appleWatch,
                range: 25...90
            ),
            SleepIndicator(
                name: "Resting Heart Rate",
                detail: "Lower is better",
                value: 54,
                unit: "bpm",
                category: .recovery,
                source: .appleWatch,
                range: 45...70
            ),
            SleepIndicator(
                name: "Respiratory Rate",
                detail: "Breathing rate",
                value: 14,
                unit: "br/min",
                category: .recovery,
                source: .appleWatch,
                range: 10...20
            ),
            SleepIndicator(
                name: "Consistency",
                detail: "Bedtime regularity",
                value: 0.7,
                unit: "",
                category: .consistency,
                source: .inferred,
                range: 0.4...1
            ),
            SleepIndicator(
                name: "Caffeine Window",
                detail: "Hours since last caffeine",
                value: 8,
                unit: "hr",
                category: .behavior,
                source: .manual,
                range: 2...12
            )
        ]
    }

    private func makeInsights() -> [SleepInsight] {
        let duration = indicators.first(where: { $0.name == "Sleep Duration" })?.value
        let hrv = indicators.first(where: { $0.name == "HRV" })?.value
        let rhr = indicators.first(where: { $0.name == "Resting Heart Rate" })?.value
        let latency = indicators.first(where: { $0.name == "Sleep Latency" })?.value
        let longAwakenings = indicators.first(where: { $0.name == "Long Awakenings" })?.value

        var items: [SleepInsight] = []

        if let duration, duration < 6.5 {
            items.append(SleepInsight(
                id: "duration_low",
                title: "Short sleep window",
                detail: "Sleep duration was under 6.5 hours.",
                impact: .negative
            ))
        }

        if let hrv, hrv > 55 {
            items.append(SleepInsight(
                id: "hrv_high",
                title: "Strong recovery signal",
                detail: "HRV was higher than your recent baseline.",
                impact: .positive
            ))
        }

        if let rhr, rhr > 60 {
            items.append(SleepInsight(
                id: "rhr_high",
                title: "Elevated resting heart rate",
                detail: "Resting HR was above 60 bpm.",
                impact: .negative
            ))
        }

        if let latency, latency >= 30 {
            items.append(SleepInsight(
                id: "latency_high",
                title: "Long sleep latency",
                detail: "It took over 30 minutes to fall asleep.",
                impact: .negative
            ))
        }

        if let longAwakenings, longAwakenings > 0 {
            items.append(SleepInsight(
                id: "long_awakenings",
                title: "Extended night awakening",
                detail: "You were awake for 10+ minutes during the night.",
                impact: .negative
            ))
        }

        if items.isEmpty {
            items.append(SleepInsight(
                id: "steady",
                title: "Stable recovery",
                detail: "No major deviations detected yet.",
                impact: .neutral
            ))
        }

        return items
    }

    private func refreshLastNightData() async {
        guard authorizationState == .authorized else {
            lastNightStages = []
            lastNightMetrics = .empty
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
            lastNightMetrics = makeLastNightMetrics(stages: stages, signals: signals)
            lastNightHeartRateSeries = makeSignalSeries(from: signals, type: .heartRate)
            lastNightHRVSeries = makeSignalSeries(from: signals, type: .heartRateVariability)
            lastNightRespiratoryRateSeries = makeSignalSeries(from: signals, type: .respiratoryRate)
        } catch {
            lastNightStages = []
            lastNightMetrics = .empty
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
        return SleepChartSeries(
            title: type.displayName,
            unit: unit,
            points: points
        )
    }

    private func makeLastNightMetrics(
        stages: [SleepStageSample],
        signals: [SleepSignalSample]
    ) -> LastNightMetrics {
        let sleepStart = stages
            .filter { $0.stage != .awake && $0.stage != .inBed }
            .map(\.startDate)
            .min() ?? stages.map(\.startDate).min()

        let heartRateSamples = signals.filter { $0.name == SleepSignalType.heartRate.rawValue }
        let lowestHeartRateSample = heartRateSamples.min(by: { $0.value < $1.value })

        let hrvSamples = signals.filter { $0.name == SleepSignalType.heartRateVariability.rawValue }
        let hrvAverage = averageValue(for: hrvSamples)

        return LastNightMetrics(
            sleepStart: sleepStart,
            lowestHeartRate: lowestHeartRateSample?.value,
            lowestHeartRateTime: lowestHeartRateSample?.date,
            averageHRV: hrvAverage
        )
    }

    private func averageValue(for samples: [SleepSignalSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.map(\.value).reduce(0, +)
        return total / Double(samples.count)
    }

    private func resetDashboardData() {
        indicators = []
        summary = SleepScoreSummary(
            date: selectedDate,
            score: 0,
            trend: 0,
            components: [],
            confidence: 0,
            note: ""
        )
        feeling = nil
        insights = []
        lastNightStages = []
        lastNightMetrics = .empty
        lastNightHeartRateSeries = nil
        lastNightHRVSeries = nil
        lastNightRespiratoryRateSeries = nil
        scoreHistory = []
    }

    private func loadTrendHistory() async {
        let endDate = Date().startOfDay
        let startDate = Calendar.current.date(byAdding: .day, value: -(trendRange.daySpan - 1), to: endDate) ?? endDate
        scoreHistory = await localStore.loadScores(from: startDate, to: endDate)
    }
}
