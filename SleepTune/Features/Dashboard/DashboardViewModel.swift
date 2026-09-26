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
    /// Weekday / weekend split of the same 30-day window, by metric name.
    var monthlySplitStats: [String: MetricSplitStats] = [:]
    var activityMonthlyStats: [String: MetricStats] = [:]
    var sleepDebt: SleepDebtSummary?
    /// Alcohol heuristic for the selected night; nil when nothing fired.
    var alcoholResult: AlcoholHeuristic.Result?
    /// The user's confirmation for the selected night, if any.
    var alcoholConfirmed: Bool?

    /// Effective baselines for scoreMetric() — delegates to effectiveBaseline() which is
    /// the single source of truth for aspirational percentile targets across all metrics.
    var monthlyAverages: [String: Double] {
        monthlyStats.reduce(into: [:]) { result, pair in
            result[pair.key] = effectiveBaseline(name: pair.key, stats: pair.value)
        }
    }

    var selectedDayType: DayType { DayType.classify(wakeDate: selectedDate) }

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
    let nightStore: NightRecordStore
    var tagStore: SleepTagStore?
    /// Set by the container; kicks off the one-time history import once authorized.
    var backfill: HistoryBackfill?

    init(
        healthKitClient: HealthKitClient,
        scoreEngine: SleepScoreEngine,
        localStore: SleepLocalStore,
        authService: AuthService,
        cloudKitService: CloudKitService,
        nightStore: NightRecordStore
    ) {
        self.healthKitClient = healthKitClient
        self.scoreEngine = scoreEngine
        self.localStore = localStore
        self.nightStore = nightStore
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

        backfill?.startIfNeeded()

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
            await upsertNightRecord(indicators: capturedIndicators, summary: capturedSummary, date: capturedDate)
            await evaluateAlcohol()
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
                    await upsertNightRecord(indicators: fetched, summary: daySummary, date: day)
                }
            }
            if await localStore.loadActivitySnapshot(for: day) == nil {
                let snap = await healthKitClient.fetchActivitySnapshot(for: day)
                await localStore.saveActivitySnapshot(snap, for: day)
            }
        }
        await importLegacyCacheIfNeeded()
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

    // MARK: - Alcohol heuristic

    static let drinksTagName = "Drinks"

    private func evaluateAlcohol() async {
        let cal = Calendar.current
        let selected = cal.startOfDay(for: selectedDate)
        guard let historyStart = cal.date(byAdding: .day, value: -60, to: selected),
              let historyEnd = cal.date(byAdding: .day, value: -1, to: selected),
              let night = AlcoholHeuristic.night(from: indicators) else {
            alcoholResult = nil; alcoholConfirmed = nil; return
        }
        let history = (try? await nightStore.records(from: historyStart, to: historyEnd)) ?? []
        let stored = try? await nightStore.record(for: selected)
        alcoholConfirmed = stored?.alcoholFlag
        guard let baseline = AlcoholHeuristic.baseline(from: history) else { alcoholResult = nil; return }
        let result = AlcoholHeuristic.evaluate(night: night, baseline: baseline)
        // Show the pill when the heuristic fired, or when the user already confirmed.
        alcoholResult = (result.verdict != .none || alcoholConfirmed == true) ? result : nil
    }

    /// Records the user's answer: flags the night record and syncs the "Drinks" tag.
    func confirmAlcohol(_ drank: Bool) {
        alcoholConfirmed = drank
        let date = selectedDate
        Task { @MainActor in
            try? await nightStore.update(key: NightSummary.key(for: Calendar.current.startOfDay(for: date))) {
                $0.alcoholFlag = drank
            }
            if let tagStore {
                if tagStore.availableTags.first(where: { $0.name == Self.drinksTagName }) == nil, drank {
                    tagStore.addTag(name: Self.drinksTagName)
                }
                if let tag = tagStore.availableTags.first(where: { $0.name == Self.drinksTagName }),
                   tagStore.isActive(tag, for: date) != drank {
                    tagStore.toggle(tag, for: date)
                }
            }
            await refreshTagInsights()
        }
    }

    // MARK: - Night record plumbing

    /// Writes the selected night into the long-range store. Activity is the
    /// previous day's, signals give max HR, stages give the sleep window.
    private func upsertNightRecord(indicators: [SleepIndicator], summary: SleepScoreSummary, date: Date) async {
        let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let activity = await localStore.loadActivitySnapshot(for: prevDay)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        var record = NightSummary.make(
            night: date,
            indicators: indicators,
            summary: summary,
            activity: activity,
            signals: [],
            sleepInterval: isSelected ? sleepInterval : nil
        )
        if isSelected, let hr = lastNightHeartRateSeries {
            record.maxHR = hr.points.map(\.value).max()
        }
        // Keep fields we can't recompute here.
        if let existing = try? await nightStore.record(for: date) {
            record.alcoholFlag = existing.alcoholFlag
            if record.maxHR == nil { record.maxHR = existing.maxHR }
            if record.sleepStart == nil { record.sleepStart = existing.sleepStart; record.sleepEnd = existing.sleepEnd }
        }
        try? await nightStore.upsert(record)
    }

    /// One-time import of the UserDefaults cache so existing installs have
    /// their 30 days of stats immediately, before the HealthKit backfill lands.
    private func importLegacyCacheIfNeeded() async {
        let key = "nightStore.legacyImportDone"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let cal = Calendar.current
        let today = Date()
        for offset in 0..<60 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let existing = try? await nightStore.record(for: day), existing.score > 0 { continue }
            let indicators = await localStore.loadIndicators(for: day)
            guard !indicators.isEmpty else { continue }
            let scores = await localStore.loadScores(from: day, to: day)
            let daySummary = scores.first.map {
                SleepScoreSummary(date: day, score: $0.score, trend: 0,
                                  sleepScore: $0.sleepScore ?? 0, recoveryScore: $0.recoveryScore ?? 0,
                                  confidence: 0, primarySource: .appleHealth)
            } ?? scoreEngine.score(indicators: indicators, weights: .default)
            await upsertNightRecord(indicators: indicators, summary: daySummary, date: day)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Nights in the 30 days before `selectedDate` (exclusive), from the night store.
    private func recentNights(days: Int, before date: Date) async -> [NightSummary] {
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: -1, to: date),
              let start = cal.date(byAdding: .day, value: -days, to: date) else { return [] }
        return (try? await nightStore.records(from: start, to: end)) ?? []
    }

    private static func stats(from values: [Double]) -> MetricStats? {
        guard let mn = values.min(), let mx = values.max(), !values.isEmpty else { return nil }
        return MetricStats(
            avg: values.reduce(0, +) / Double(values.count),
            min: mn, max: mx, count: values.count, sortedValues: values.sorted()
        )
    }

    private func loadMonthlyStats() async {
        let nights = await recentNights(days: 30, before: Date())
        var all: [String: [Double]] = [:]
        var weekday: [String: [Double]] = [:]
        var weekend: [String: [Double]] = [:]
        for n in nights {
            for (name, value) in n.metrics {
                all[name, default: []].append(value)
                if n.dayType == .weekend { weekend[name, default: []].append(value) }
                else { weekday[name, default: []].append(value) }
            }
        }
        var split: [String: MetricSplitStats] = [:]
        for (name, values) in all {
            guard let a = Self.stats(from: values) else { continue }
            let wd = (weekday[name] ?? []).count >= MetricSplitStats.minNights ? Self.stats(from: weekday[name] ?? []) : nil
            let we = (weekend[name] ?? []).count >= MetricSplitStats.minNights ? Self.stats(from: weekend[name] ?? []) : nil
            split[name] = MetricSplitStats(all: a, weekday: wd, weekend: we)
        }
        guard !nights.isEmpty else { return }
        monthlySplitStats = split
        // Scoring baseline: all nights, or weekday-only when the user opted in
        // (falls back per metric when there aren't enough weekday nights).
        let weekdayOnly = ScoringBaselineSetting.weekdayOnly
        monthlyStats = split.mapValues { weekdayOnly ? ($0.weekday ?? $0.all) : $0.all }
    }

    /// Called when the scoring-baseline setting changes.
    func reloadBaselines() async {
        await loadMonthlyStats()
        recalculateScore()
    }

    private func loadActivityMonthlyStats() async {
        let nights = await recentNights(days: 30, before: Date())
        var totals: [String: [Double]] = [:]
        func collect(_ v: Double?, key: String) {
            guard let v, v > 0 else { return }
            totals[key, default: []].append(v)
        }
        for n in nights {
            collect(n.steps,           key: "steps")
            collect(n.activeCalories,  key: "kcal")
            collect(n.exerciseMinutes, key: "ex")
            collect(n.peakHR,          key: "peakhr")
            collect(n.vo2Max,          key: "vo2")
        }
        // Floors / stand time aren't on the night record; keep reading the day cache.
        let cal = Calendar.current
        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()),
                  let snap = await localStore.loadActivitySnapshot(for: day) else { continue }
            collect(snap.floorsClimbed, key: "floors")
            collect(snap.standMinutes,  key: "stand")
        }
        let newStats = totals.compactMapValues(Self.stats(from:))
        // Only overwrite if we actually found data — preserves mock-seeded stats in DEBUG mode.
        if !newStats.isEmpty { activityMonthlyStats = newStats }
    }

    /// Debt for the *selected* night: that night is age 0, plus the 13 before it.
    /// Need comes from the best-rested fortnight in the last 90 nights.
    private func loadSleepDebt() async {
        let cal = Calendar.current
        let selected = cal.startOfDay(for: selectedDate)
        guard let windowStart = cal.date(byAdding: .day, value: -(SleepDebt.windowNights - 1), to: selected),
              let historyStart = cal.date(byAdding: .day, value: -90, to: selected) else { return }

        var window = (try? await nightStore.records(from: windowStart, to: selected)) ?? []
        // The selected night may not be persisted yet on first load; synthesise it.
        if !window.contains(where: { cal.isDate($0.night, inSameDayAs: selected) }),
           let hours = indicators.first(where: { $0.name == "Sleep Duration" })?.value, hours > 0 {
            window.append(NightSummary.make(night: selected, indicators: indicators, summary: summary,
                                            activity: nil))
        }
        let nights = window.map(SleepDebtNight.init)
        guard !nights.isEmpty else { sleepDebt = nil; return }

        let history = ((try? await nightStore.records(from: historyStart, to: selected)) ?? []).map(SleepDebtNight.init)
        let need = SleepDebt.baselineNeed(from: history)
        let deepRem = history.compactMap(\.deepRemMinutes)
        let baselineDeepRem = deepRem.isEmpty ? nil : deepRem.reduce(0, +) / Double(deepRem.count)
        sleepDebt = SleepDebt.compute(nights: nights, need: need, baselineDeepRem: baselineDeepRem)
    }

    private func refreshTagInsights() async {
        var correlations: [TagCorrelation] = []
        if let tagStore, !tagStore.availableTags.isEmpty {
            correlations = await tagInsightEngine.compute(tagStore: tagStore, nightStore: nightStore)
        }
        // Activity-level correlation (active vs rest days) — independent of user tags,
        // so it surfaces even before the user has tagged any nights.
        let activityCorrelations = await tagInsightEngine.computeActivityCorrelations(nightStore: nightStore)
        tagCorrelations = correlations + activityCorrelations
    }

    private func loadTrendHistory() async {
        let end   = Date().startOfDay
        let start = Calendar.current.date(byAdding: .day, value: -(trendRange.daySpan - 1), to: end) ?? end
        let nights = (try? await nightStore.records(from: start, to: end)) ?? []
        let fromStore = nights.filter { $0.score > 0 }.map {
            SleepScoreTrendPoint(date: $0.night, score: $0.score, sleepScore: $0.sleepScore, recoveryScore: $0.recoveryScore)
        }
        scoreHistory = fromStore.isEmpty ? await localStore.loadScores(from: start, to: end) : fromStore
    }
}
