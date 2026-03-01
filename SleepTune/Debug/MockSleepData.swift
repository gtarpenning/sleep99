#if DEBUG
import Foundation

/// Realistic fake sleep data for Previews and on-device mock mode.
enum MockSleepData {

    // MARK: - Reference night: 11:00 PM → 7:15 AM

    private static let bedtime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 23; c.minute = 0; c.second = 0
        return Calendar.current.date(from: c)!.addingTimeInterval(-86400) // last night
    }()

    private static func t(_ minutesFromBed: Double) -> Date {
        bedtime.addingTimeInterval(minutesFromBed * 60)
    }

    // MARK: - Sleep stages

    static let stages: [SleepStageSample] = [
        .init(stage: .inBed,      startDate: t(0),   endDate: t(18)),
        .init(stage: .asleepCore, startDate: t(18),  endDate: t(45)),
        .init(stage: .asleepDeep, startDate: t(45),  endDate: t(95)),
        .init(stage: .asleepCore, startDate: t(95),  endDate: t(120)),
        .init(stage: .asleepREM,  startDate: t(120), endDate: t(150)),
        .init(stage: .awake,      startDate: t(150), endDate: t(158)),
        .init(stage: .asleepCore, startDate: t(158), endDate: t(195)),
        .init(stage: .asleepDeep, startDate: t(195), endDate: t(230)),
        .init(stage: .asleepCore, startDate: t(230), endDate: t(265)),
        .init(stage: .asleepREM,  startDate: t(265), endDate: t(310)),
        .init(stage: .asleepCore, startDate: t(310), endDate: t(340)),
        .init(stage: .asleepREM,  startDate: t(340), endDate: t(380)),
        .init(stage: .awake,      startDate: t(380), endDate: t(390)),
        .init(stage: .asleepCore, startDate: t(390), endDate: t(420)),
        .init(stage: .inBed,      startDate: t(420), endDate: t(435)),
    ]

    // MARK: - Heart rate signal (bpm, ~5-min intervals)

    static let heartRateSeries: SleepChartSeries = {
        // HR dips during deep sleep, rises in REM
        let rawValues: [(Double, Double)] = [
            (0,58),(15,56),(30,54),(45,50),(60,48),(75,46),(90,44),
            (105,46),(120,50),(135,55),(150,60),(158,56),(165,52),
            (180,49),(200,46),(215,44),(230,46),(245,50),(265,56),
            (280,60),(300,63),(320,58),(340,62),(360,65),(380,68),
            (390,60),(405,56),(420,58),(435,60)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "Heart Rate", unit: "bpm", points: points)
    }()

    // MARK: - HRV signal (ms, ~5-min intervals)

    static let hrvSeries: SleepChartSeries = {
        let rawValues: [(Double, Double)] = [
            (0,38),(20,42),(40,48),(60,55),(80,58),(100,52),(120,45),
            (140,48),(160,40),(175,50),(195,56),(215,60),(235,58),
            (255,50),(275,46),(295,52),(315,48),(335,52),(355,50),
            (375,42),(390,46),(410,50),(425,48),(435,44)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "HRV", unit: "ms", points: points)
    }()

    // MARK: - Respiratory rate signal (br/min, ~5-min intervals)

    static let rrSeries: SleepChartSeries = {
        let rawValues: [(Double, Double)] = [
            (0,15),(20,14),(40,13),(60,13),(80,12),(100,13),(120,14),
            (140,14),(160,15),(175,13),(195,12),(215,12),(235,13),
            (255,14),(275,15),(295,14),(315,13),(335,14),(355,15),
            (375,16),(390,14),(410,13),(425,14),(435,15)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "Respiratory Rate", unit: "br/min", points: points)
    }()

    // MARK: - SleepSignalSamples (for HealthKitClient mock)

    static let signals: [SleepSignalSample] = {
        var out: [SleepSignalSample] = []
        for p in heartRateSeries.points {
            out.append(SleepSignalSample(name: SleepSignalType.heartRate.rawValue,
                                         value: p.value, unit: "bpm", date: p.date, source: .appleWatch))
        }
        for p in hrvSeries.points {
            out.append(SleepSignalSample(name: SleepSignalType.heartRateVariability.rawValue,
                                         value: p.value, unit: "ms", date: p.date, source: .appleWatch))
        }
        for p in rrSeries.points {
            out.append(SleepSignalSample(name: SleepSignalType.respiratoryRate.rawValue,
                                         value: p.value, unit: "br/min", date: p.date, source: .appleWatch))
        }
        return out
    }()

    // MARK: - Indicators

    static let indicators: [SleepIndicator] = [
        SleepIndicator(name: "Sleep Duration",  detail: "Total time asleep",
                       value: 7.25, unit: "hr",    category: .sleepArchitecture, source: .appleWatch,
                       range: 5...9, contribution: 0.78),
        SleepIndicator(name: "Sleep Efficiency", detail: "Time asleep / time in bed",
                       value: 88,   unit: "%",     category: .sleepArchitecture, source: .appleWatch,
                       range: 70...100, contribution: 0.82),
        SleepIndicator(name: "REM Sleep",        detail: "% of sleep in REM",
                       value: 22,   unit: "%",     category: .sleepArchitecture, source: .appleWatch,
                       range: 15...30, contribution: 0.72),
        SleepIndicator(name: "Deep Sleep",       detail: "% of sleep in deep",
                       value: 18,   unit: "%",     category: .sleepArchitecture, source: .appleWatch,
                       range: 10...25, contribution: 0.80),
        SleepIndicator(name: "Long Awakenings",  detail: "Awakenings > 5 min",
                       value: 1,    unit: "count", category: .sleepArchitecture, source: .appleWatch,
                       range: 0...5, contribution: 0.80),
        SleepIndicator(name: "Overnight Heart Rate", detail: "Avg HR during sleep",
                       value: 52,   unit: "bpm",   category: .recovery, source: .appleWatch,
                       range: 40...80, contribution: 0.75),
        SleepIndicator(name: "Resting Heart Rate",   detail: "Lowest overnight HR",
                       value: 44,   unit: "bpm",   category: .recovery, source: .appleWatch,
                       range: 36...60, contribution: 0.80),
        SleepIndicator(name: "HRV",                  detail: "Heart rate variability",
                       value: 52,   unit: "ms",    category: .recovery, source: .appleWatch,
                       range: 20...80, contribution: 0.72),
        SleepIndicator(name: "Respiratory Rate",     detail: "Avg breaths per minute",
                       value: 14,   unit: "br/min",category: .recovery, source: .appleWatch,
                       range: 10...20, contribution: 0.80),
        SleepIndicator(name: "Blood Oxygen",         detail: "Avg SpO2",
                       value: 97,   unit: "%",     category: .recovery, source: .appleWatch,
                       range: 90...100, contribution: 0.88),
    ]

    // MARK: - Summary

    static let summary = SleepScoreSummary(
        date: Date(),
        score: 78,
        trend: 3,
        sleepScore: 76,
        recoveryScore: 81,
        confidence: 0.9,
        primarySource: .appleWatch
    )

    // MARK: - Score history (last 7 days)

    static let scoreHistory: [SleepScoreTrendPoint] = {
        let scores: [Double] = [62, 71, 68, 75, 73, 79, 78]
        return scores.enumerated().map { i, score in
            let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: Date().startOfDay)!
            return SleepScoreTrendPoint(date: date, score: score)
        }
    }()
}
#endif
