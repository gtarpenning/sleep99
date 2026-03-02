import Foundation
import HealthKit
import Observation

private var HealthReadTypes: Set<HKObjectType> {
    var types: [HKObjectType] = []

    if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .heartRate) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .bodyTemperature) { types.append(t) }

    if #available(iOS 16.0, watchOS 9.0, *) {
        if let t = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) { types.append(t) }
    }

    if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .flightsClimbed) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .appleStandTime) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) { types.append(t) }

    if let t = HKObjectType.quantityType(forIdentifier: .vo2Max) { types.append(t) }
    if let t = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) { types.append(t) }

    types.append(HKObjectType.workoutType())

    return Set(types)
}

@MainActor
@Observable
class HealthKitClient {
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    // HealthKit intentionally never exposes read permission status to apps.
    // authorizationStatus(for:) only reflects write/share access, which we
    // never request. We track whether the user has gone through the prompt
    // ourselves via UserDefaults.
    private static let authGrantedKey = "healthkit_auth_granted"

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await healthStore.requestAuthorization(toShare: [], read: HealthReadTypes)
        // If we get here without throwing, the prompt was shown (user may have
        // allowed some or all types — HealthKit won't say which, and that's fine).
        UserDefaults.standard.set(true, forKey: Self.authGrantedKey)
    }

    func authorizationState() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let granted = UserDefaults.standard.bool(forKey: Self.authGrantedKey)
        return granted ? .authorized : .needsPermission
    }

    func fetchSignals(for date: Date) async throws -> [SleepSignalSample] {
        let sleepWindow = sleepInterval(for: date)
        let broadPredicate = HKQuery.predicateForSamples(
            withStart: sleepWindow.start,
            end: sleepWindow.end,
            options: [.strictStartDate, .strictEndDate]
        )

        // Narrow vitals to the actual sleep period (asleep samples only) so daytime
        // HR doesn't bleed into the "Last Night" chart.
        let sleepSamples: [HKCategorySample] = (try? await fetchSamples(
            type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            predicate: broadPredicate,
            limit: HKObjectQueryNoLimit,
            sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        )) ?? []
        let asleepValues: Set<Int32> = [
            Int32(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepREM.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepCore.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepDeep.rawValue),
        ]
        let asleepOnly = sleepSamples.filter { asleepValues.contains(Int32($0.value)) }
        // Use ONLY asleep samples for the HR window — inBed can start hours before actual sleep.
        // Fall back to broadPredicate only if there are literally no asleep records at all.
        let sleepStart = asleepOnly.map(\.startDate).min()
        let sleepEnd   = asleepOnly.map(\.endDate).max()

        let predicate: NSPredicate
        if let start = sleepStart, let end = sleepEnd {
            predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        } else {
            predicate = broadPredicate
        }

        let quantityTypes: [(HKQuantityTypeIdentifier, HKUnit, String)] = [
            (.heartRate, .count().unitDivided(by: .minute()), "bpm"),
            (.restingHeartRate, .count().unitDivided(by: .minute()), "bpm"),
            (.walkingHeartRateAverage, .count().unitDivided(by: .minute()), "bpm"),
            (.heartRateVariabilitySDNN, .secondUnit(with: .milli), "ms"),
            (.respiratoryRate, .count().unitDivided(by: .minute()), "br/min"),
            (.oxygenSaturation, .percent(), "%"),
            (.bodyTemperature, .degreeCelsius(), "°C"),
            (.appleSleepingWristTemperature, .degreeCelsius(), "°C")
        ]

        var signals: [SleepSignalSample] = []
        for (identifier, unit, label) in quantityTypes {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let samples: [HKQuantitySample] = try await fetchSamples(
                type: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            )
            let mapped = samples.map { sample in
                SleepSignalSample(
                    name: identifier.rawValue,
                    value: sample.quantity.doubleValue(for: unit),
                    unit: label,
                    date: sample.startDate,
                    source: .appleHealth
                )
            }
            signals.append(contentsOf: mapped)
        }

        return signals
    }

    func fetchSleepStages(for date: Date) async throws -> [SleepStageSample] {
        let sleepWindow = sleepInterval(for: date)
        let predicate = HKQuery.predicateForSamples(
            withStart: sleepWindow.start,
            end: sleepWindow.end,
            options: [.strictStartDate, .strictEndDate]
        )

        let samples: [HKCategorySample] = try await fetchSamples(
            type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        )

        return samples.compactMap { sample in
            guard let stage = sleepStage(from: sample.value) else { return nil }
            return SleepStageSample(
                stage: stage,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }
    }

    func fetchSleepIndicators(for date: Date) async throws -> [SleepIndicator] {
        let sleepWindow = sleepInterval(for: date)
        let sleepPredicate = HKQuery.predicateForSamples(
            withStart: sleepWindow.start,
            end: sleepWindow.end,
            options: [.strictStartDate, .strictEndDate]
        )
        let dayInterval = dayInterval(for: date)
        let dayPredicate = HKQuery.predicateForSamples(
            withStart: dayInterval.start,
            end: dayInterval.end,
            options: [.strictStartDate, .strictEndDate]
        )

        let sleepSamples: [HKCategorySample] = try await fetchSamples(
            type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            predicate: sleepPredicate,
            limit: HKObjectQueryNoLimit,
            sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        )

        var indicators: [SleepIndicator] = []
        indicators.append(contentsOf: buildSleepIndicators(from: sleepSamples))

        // Narrow to primary session first — same filter used by buildSleepIndicators —
        // so sleepStart/sleepEnd reflect the real sleep window, not the full 20h query span.
        let primarySamples = filteredToPrimarySession(sleepSamples)
        let asleepValues: Set<Int32> = [
            Int32(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepREM.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepCore.rawValue),
            Int32(HKCategoryValueSleepAnalysis.asleepDeep.rawValue),
        ]
        let asleepOnly = primarySamples.filter { asleepValues.contains(Int32($0.value)) }
        let sleepStart    = asleepOnly.map(\.startDate).min() ?? primarySamples.map(\.startDate).min()
        let sleepEnd      = asleepOnly.map(\.endDate).max()   ?? primarySamples.map(\.endDate).max()
        let sleepDuration = (sleepStart != nil && sleepEnd != nil)
            ? sleepEnd!.timeIntervalSince(sleepStart!) : 0

        indicators.append(contentsOf: await buildRecoveryIndicators(
            predicate: sleepPredicate,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            sleepDuration: sleepDuration
        ))
        indicators.append(contentsOf: await buildActivityIndicators(predicate: dayPredicate))
        indicators.append(contentsOf: await buildWorkoutIndicators(predicate: dayPredicate))

        return indicators
    }

    func fetchChartSeries(for date: Date, days: Int) async throws -> [SleepChartSeries] {
        let dayCount = max(days, 1)
        let dates = (0..<dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: date.startOfDay)
        }.sorted()

        var durationPoints: [SleepChartPoint] = []
        var hrvPoints: [SleepChartPoint] = []

        for day in dates {
            let window = sleepInterval(for: day)
            let predicate = HKQuery.predicateForSamples(
                withStart: window.start,
                end: window.end,
                options: [.strictStartDate, .strictEndDate]
            )

            let sleepSamples: [HKCategorySample] = try await fetchSamples(
                type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            )
            let hoursAsleep = sleepDurationHours(from: sleepSamples)
            durationPoints.append(SleepChartPoint(date: day, value: hoursAsleep))

            let hrvAverage = await fetchAverage(
                for: .heartRateVariabilitySDNN,
                predicate: predicate,
                unit: .secondUnit(with: .milli)
            ) ?? 0
            hrvPoints.append(SleepChartPoint(date: day, value: hrvAverage))
        }

        return [
            SleepChartSeries(title: "Sleep Duration", unit: "hr", points: durationPoints),
            SleepChartSeries(title: "HRV", unit: "ms", points: hrvPoints)
        ]
    }
}

private extension HealthKitClient {
    func sleepStage(from value: Int) -> SleepStage? {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .inBed
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return .asleep
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .asleepCore
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .asleepDeep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .asleepREM
        default:
            return nil
        }
    }

    func sleepInterval(for date: Date) -> DateInterval {
        let startOfDay = date.startOfDay
        // Start at 6pm the previous evening to catch early bedtimes.
        // End at 2pm the following afternoon to catch late risers.
        let start = calendar.date(byAdding: .hour, value: -18, to: startOfDay) ?? startOfDay
        let end   = calendar.date(byAdding: .hour, value: 14, to: startOfDay) ?? startOfDay.addingTimeInterval(14 * 3600)
        return DateInterval(start: start, end: end)
    }

    func dayInterval(for date: Date) -> DateInterval {
        let startOfDay = date.startOfDay
        let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 3600)
        return DateInterval(start: startOfDay, end: end)
    }

    /// Returns samples belonging only to the primary sleep session —
    /// the longest contiguous block of asleep samples with ≤45 min gaps.
    /// inBed and awake samples that overlap the chosen window are included.
    private func filteredToPrimarySession(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        let asleepValues: Set<HKCategoryValueSleepAnalysis> = [
            .asleepUnspecified, .asleepREM, .asleepCore, .asleepDeep
        ]
        let asleep = samples
            .filter { asleepValues.contains(HKCategoryValueSleepAnalysis(rawValue: $0.value) ?? .inBed) }
            .sorted { $0.startDate < $1.startDate }

        guard !asleep.isEmpty else { return samples }

        let gapTolerance: TimeInterval = 45 * 60
        var blocks: [DateInterval] = []
        var blockStart = asleep[0].startDate
        var blockEnd   = asleep[0].endDate

        for sample in asleep.dropFirst() {
            if sample.startDate.timeIntervalSince(blockEnd) <= gapTolerance {
                blockEnd = max(blockEnd, sample.endDate)
            } else {
                blocks.append(DateInterval(start: blockStart, end: blockEnd))
                blockStart = sample.startDate
                blockEnd   = sample.endDate
            }
        }
        blocks.append(DateInterval(start: blockStart, end: blockEnd))

        guard let primary = blocks.max(by: { $0.duration < $1.duration }) else { return samples }

        // Keep all samples (including inBed/awake) that fall within the primary window.
        return samples.filter { $0.startDate < primary.end && $0.endDate > primary.start }
    }

    func fetchSamples<T: HKSample>(
        type: HKSampleType?,
        predicate: NSPredicate,
        limit: Int,
        sort: [NSSortDescriptor]
    ) async throws -> [T] {
        guard let type else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [T]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    func fetchStatistics(
        type: HKQuantityType?,
        predicate: NSPredicate,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        guard let type else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    func buildSleepIndicators(from allSamples: [HKCategorySample]) -> [SleepIndicator] {
        // Narrow to the primary sleep session (longest contiguous asleep block, 45-min gap tolerance).
        // This prevents summing two nights or a nap from the same 20-hour query window.
        let samples = filteredToPrimarySession(allSamples)

        var inBed: TimeInterval = 0
        var asleep: TimeInterval = 0
        var rem: TimeInterval = 0
        var core: TimeInterval = 0
        var deep: TimeInterval = 0
        var awake: TimeInterval = 0

        let asleepSamples = samples.filter { sample in
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepUnspecified, .asleepREM, .asleepCore, .asleepDeep:
                return true
            case .inBed, .awake, .none:
                return false
            @unknown default:
                return false
            }
        }

        let inBedStart = samples
            .filter { HKCategoryValueSleepAnalysis(rawValue: $0.value) == .inBed }
            .map(\.startDate)
            .min()
        let asleepStart = asleepSamples.map(\.startDate).min()

        let sleepLatencyMinutes: Double? = {
            guard let inBedStart, let asleepStart else { return nil }
            let latency = asleepStart.timeIntervalSince(inBedStart) / 60
            return max(0, latency)
        }()

        let longAwakeningThreshold: TimeInterval = 10 * 60
        let awakeSamples = samples.filter { HKCategoryValueSleepAnalysis(rawValue: $0.value) == .awake }
        let longMiddleAwakeSamples = awakeSamples.filter { sample in
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard duration >= longAwakeningThreshold else { return false }
            let hasAsleepBefore = asleepSamples.contains { $0.endDate <= sample.startDate }
            let hasAsleepAfter = asleepSamples.contains { $0.startDate >= sample.endDate }
            return hasAsleepBefore && hasAsleepAfter
        }

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed:
                inBed += duration
            case .asleepUnspecified:
                asleep += duration
            case .asleepREM:
                asleep += duration
                rem += duration
            case .asleepCore:
                asleep += duration
                core += duration
            case .asleepDeep:
                asleep += duration
                deep += duration
            case .awake:
                awake += duration
            case .none:
                break
            @unknown default:
                break
            }
        }

        let hoursAsleep = asleep / 3600

        // Apple Watch never writes inBed samples — derive session span instead.
        // Session span = first sample start → last sample end (covers asleep + awake segments).
        let sessionInBed: TimeInterval = {
            if inBed > 0 { return inBed }
            let allStarts = samples.map(\.startDate)
            let allEnds   = samples.map(\.endDate)
            guard let earliest = allStarts.min(), let latest = allEnds.max() else { return 0 }
            return latest.timeIntervalSince(earliest)
        }()
        let hoursInBed = sessionInBed / 3600
        let efficiency = hoursInBed > 0 ? (hoursAsleep / hoursInBed) : 0
        let remMinutes  = rem  / 60
        let deepMinutes = deep / 60
        let coreMinutes = core / 60

        var indicators: [SleepIndicator] = [
            SleepIndicator(
                name: "Sleep Duration",
                detail: "Total time asleep",
                value: hoursAsleep,
                unit: "hr",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 4...8  // 8h = perfect score
            ),
            SleepIndicator(
                name: "Sleep Efficiency",
                detail: "Time asleep vs time in bed",
                value: efficiency * 100,
                unit: "%",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 70...98
            ),
            SleepIndicator(
                name: "REM Sleep",
                detail: "Absolute REM minutes",
                value: remMinutes,
                unit: "min",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 30...120
            ),
            SleepIndicator(
                name: "Deep Sleep",
                detail: "Absolute deep sleep minutes",
                value: deepMinutes,
                unit: "min",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 10...90
            ),
            SleepIndicator(
                name: "Core Sleep",
                detail: "Absolute core sleep minutes",
                value: coreMinutes,
                unit: "min",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 60...240
            ),
        ]

        if let sleepLatencyMinutes {
            indicators.append(SleepIndicator(
                name: "Sleep Latency",
                detail: "Minutes to fall asleep",
                value: sleepLatencyMinutes,
                unit: "min",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 0...45
            ))
        }

        // Bedtime Consistency — hours from noon so midnight wrap is avoided for 9 PM–2 AM range.
        if let start = asleepStart {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: start)
            let rawHour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
            // Shift so values < 12 (morning) are treated as next-day (e.g. 1 AM → 13.0)
            let hoursFromNoon = rawHour < 12 ? rawHour + 24 - 12 : rawHour - 12
            indicators.append(SleepIndicator(
                name: "Bedtime Consistency",
                detail: "Time you fell asleep",
                value: hoursFromNoon,
                unit: "bedtime",
                category: .sleepArchitecture,
                source: .appleHealth,
                range: 8...14  // 8 PM to 2 AM relative to noon
            ))
        }

        let longAwakeningCount = Double(longMiddleAwakeSamples.count)
        indicators.append(SleepIndicator(
            name: "Long Awakenings",
            detail: "Awake periods 10+ min · 0 = perfect",
            value: longAwakeningCount,
            unit: "x",
            category: .sleepArchitecture,
            source: .appleHealth,
            range: 0...3
        ))

        return indicators
    }

    func sleepDurationHours(from samples: [HKCategorySample]) -> Double {
        var asleep: TimeInterval = 0
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepUnspecified, .asleepREM, .asleepCore, .asleepDeep:
                asleep += duration
            case .inBed, .awake, .none:
                break
            @unknown default:
                break
            }
        }
        return asleep / 3600
    }

    func buildRecoveryIndicators(
        predicate: NSPredicate,
        sleepStart: Date?,
        sleepEnd: Date?,
        sleepDuration: TimeInterval
    ) async -> [SleepIndicator] {
        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        // Use a tight predicate (sleepStart→sleepEnd) for HR so daytime readings are excluded.
        let hrPredicate: NSPredicate
        if let start = sleepStart, let end = sleepEnd {
            hrPredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])
        } else {
            hrPredicate = predicate
        }

        async let lowestHRStats = fetchMin(for: .heartRate, predicate: hrPredicate, unit: hrUnit)
        async let avgHRStats    = fetchAverage(for: .heartRate, predicate: hrPredicate, unit: hrUnit)
        async let hrv       = fetchAverage(for: .heartRateVariabilitySDNN, predicate: predicate, unit: .secondUnit(with: .milli))
        async let respiratory = fetchAverage(for: .respiratoryRate, predicate: predicate, unit: hrUnit)
        async let oxygen    = fetchAverage(for: .oxygenSaturation, predicate: predicate, unit: .percent())
        async let wristTemp = fetchAverage(for: .appleSleepingWristTemperature, predicate: predicate, unit: .degreeCelsius())

        // Time to lowest HR — needs raw samples
        let timeToLowestFraction: Double? = await {
            guard let start = sleepStart, sleepDuration > 0 else { return nil }
            guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
            let samples: [HKQuantitySample] = (try? await fetchSamples(
                type: type,
                predicate: hrPredicate,
                limit: HKObjectQueryNoLimit,
                sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            )) ?? []
            guard let minSample = samples.min(by: { $0.quantity.doubleValue(for: hrUnit) < $1.quantity.doubleValue(for: hrUnit) }) else { return nil }
            return min(max(minSample.startDate.timeIntervalSince(start) / sleepDuration, 0), 1)
        }()

        var indicators: [SleepIndicator] = []

        if let value = await lowestHRStats {
            indicators.append(SleepIndicator(
                name: "Lowest Overnight HR",
                detail: "Minimum HR during sleep",
                value: value,
                unit: "bpm",
                category: .recovery,
                source: .appleWatch,
                range: 40...70  // used as fallback when no monthly avg
            ))
        }

        if let value = await avgHRStats {
            indicators.append(SleepIndicator(
                name: "Overnight Heart Rate",
                detail: "Average HR during sleep",
                value: value,
                unit: "bpm",
                category: .recovery,
                source: .appleWatch,
                range: 45...75
            ))
        }

        if let fraction = timeToLowestFraction {
            indicators.append(SleepIndicator(
                name: "Time to Lowest HR",
                detail: "First third of night = perfect · later = worse",
                value: fraction,
                unit: "fraction",
                category: .recovery,
                source: .appleWatch,
                range: 0...1  // lower = earlier = better (inverted in engine)
            ))
        }

        if let value = await hrv {
            indicators.append(SleepIndicator(
                name: "HRV",
                detail: "Recovery signal",
                value: value,
                unit: "ms",
                category: .recovery,
                source: .appleWatch,
                range: 20...90
            ))
        }

        if let value = await respiratory {
            indicators.append(SleepIndicator(
                name: "Respiratory Rate",
                detail: "Breathing rate",
                value: value,
                unit: "br/min",
                category: .recovery,
                source: .appleWatch,
                range: 10...20
            ))
        }

        if let value = await oxygen {
            indicators.append(SleepIndicator(
                name: "Blood Oxygen",
                detail: "Average saturation",
                value: value * 100,
                unit: "%",
                category: .recovery,
                source: .appleWatch,
                range: 92...100
            ))
        }

        if let value = await wristTemp {
            indicators.append(SleepIndicator(
                name: "Wrist Temperature",
                detail: "Overnight baseline",
                value: value,
                unit: "°C",
                category: .recovery,
                source: .appleWatch,
                range: 33...36
            ))
        }

        return indicators
    }

    func buildActivityIndicators(predicate: NSPredicate) async -> [SleepIndicator] {
        async let steps = fetchSum(for: .stepCount, predicate: predicate, unit: .count())
        async let activeEnergy = fetchSum(for: .activeEnergyBurned, predicate: predicate, unit: .kilocalorie())
        async let basalEnergy = fetchSum(for: .basalEnergyBurned, predicate: predicate, unit: .kilocalorie())
        async let distance = fetchSum(for: .distanceWalkingRunning, predicate: predicate, unit: .meter())
        async let flights = fetchSum(for: .flightsClimbed, predicate: predicate, unit: .count())
        async let exercise = fetchSum(for: .appleExerciseTime, predicate: predicate, unit: .minute())
        async let stand = fetchSum(for: .appleStandTime, predicate: predicate, unit: .minute())

        var indicators: [SleepIndicator] = []

        if let value = await steps {
            indicators.append(SleepIndicator(
                name: "Steps",
                detail: "Daily total",
                value: value,
                unit: "steps",
                category: .behavior,
                source: .appleHealth,
                range: 2000...12000
            ))
        }

        if let value = await activeEnergy {
            indicators.append(SleepIndicator(
                name: "Active Energy",
                detail: "Calories burned",
                value: value,
                unit: "kcal",
                category: .behavior,
                source: .appleHealth,
                range: 150...900
            ))
        }

        if let value = await basalEnergy {
            indicators.append(SleepIndicator(
                name: "Basal Energy",
                detail: "Resting calories",
                value: value,
                unit: "kcal",
                category: .behavior,
                source: .appleHealth,
                range: 1200...2200
            ))
        }

        if let value = await distance {
            indicators.append(SleepIndicator(
                name: "Distance",
                detail: "Walking + running",
                value: value / 1000,
                unit: "km",
                category: .behavior,
                source: .appleHealth,
                range: 1...12
            ))
        }

        if let value = await flights {
            indicators.append(SleepIndicator(
                name: "Flights Climbed",
                detail: "Daily total",
                value: value,
                unit: "flights",
                category: .behavior,
                source: .appleHealth,
                range: 0...20
            ))
        }

        if let value = await exercise {
            indicators.append(SleepIndicator(
                name: "Exercise Time",
                detail: "Daily minutes",
                value: value,
                unit: "min",
                category: .behavior,
                source: .appleHealth,
                range: 10...90
            ))
        }

        if let value = await stand {
            indicators.append(SleepIndicator(
                name: "Stand Time",
                detail: "Daily minutes",
                value: value,
                unit: "min",
                category: .behavior,
                source: .appleHealth,
                range: 240...720
            ))
        }

        return indicators
    }

    func buildWorkoutIndicators(predicate: NSPredicate) async -> [SleepIndicator] {
        let workouts: [HKWorkout] = (try? await fetchSamples(
            type: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sort: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        )) ?? []

        guard !workouts.isEmpty else { return [] }

        let totalDuration = workouts.map(\.duration).reduce(0, +) / 60
        let totalEnergy = workouts.compactMap { $0.totalEnergyBurned?.doubleValue(for: .kilocalorie()) }.reduce(0, +)

        return [
            SleepIndicator(
                name: "Workouts",
                detail: "Sessions logged",
                value: Double(workouts.count),
                unit: "sessions",
                category: .behavior,
                source: .appleHealth,
                range: 0...4
            ),
            SleepIndicator(
                name: "Workout Duration",
                detail: "Total minutes",
                value: totalDuration,
                unit: "min",
                category: .behavior,
                source: .appleHealth,
                range: 0...180
            ),
            SleepIndicator(
                name: "Workout Energy",
                detail: "Calories burned",
                value: totalEnergy,
                unit: "kcal",
                category: .behavior,
                source: .appleHealth,
                range: 0...1200
            )
        ]
    }

    func fetchMin(
        for identifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: identifier)
        guard let stats = try? await fetchStatistics(type: type, predicate: predicate, options: .discreteMin),
              let quantity = stats.minimumQuantity()
        else { return nil }
        return quantity.doubleValue(for: unit)
    }

    func fetchAverage(
        for identifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: identifier)
        guard let stats = try? await fetchStatistics(type: type, predicate: predicate, options: .discreteAverage),
              let quantity = stats.averageQuantity()
        else { return nil }
        return quantity.doubleValue(for: unit)
    }

    func fetchSum(
        for identifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: identifier)
        guard let stats = try? await fetchStatistics(type: type, predicate: predicate, options: .cumulativeSum),
              let quantity = stats.sumQuantity()
        else { return nil }
        return quantity.doubleValue(for: unit)
    }
}
extension NSPredicate: @unchecked Sendable {}
