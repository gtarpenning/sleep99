#if DEBUG
import Foundation

/// Realistic fake sleep data for Previews and on-device mock mode.
/// Values are derived from the mock stage / signal data below so everything is internally consistent.
enum MockSleepData {

    // MARK: - Reference night: 11:00 PM → 7:15 AM (435 min session, ~420 min asleep)

    private static let bedtime: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 23; c.minute = 0; c.second = 0
        return Calendar.current.date(from: c)!.addingTimeInterval(-86400) // last night
    }()

    private static func t(_ minutesFromBed: Double) -> Date {
        bedtime.addingTimeInterval(minutesFromBed * 60)
    }

    // MARK: - Sleep stages
    // Session: 11:00 PM → 7:15 AM
    // inBed: 18 min latency, then asleep cycles, 15 min in-bed at end
    // Core:  ~183 min  |  Deep: ~85 min  |  REM: ~115 min  |  Awake: ~10 min

    static let stages: [SleepStageSample] = [
        .init(stage: .inBed,      startDate: t(0),   endDate: t(18)),   // latency 18 min
        .init(stage: .asleepCore, startDate: t(18),  endDate: t(45)),   // 27 min
        .init(stage: .asleepDeep, startDate: t(45),  endDate: t(95)),   // 50 min
        .init(stage: .asleepCore, startDate: t(95),  endDate: t(120)),  // 25 min
        .init(stage: .asleepREM,  startDate: t(120), endDate: t(150)),  // 30 min
        .init(stage: .awake,      startDate: t(150), endDate: t(158)),  // 8 min
        .init(stage: .asleepCore, startDate: t(158), endDate: t(195)),  // 37 min
        .init(stage: .asleepDeep, startDate: t(195), endDate: t(230)),  // 35 min
        .init(stage: .asleepCore, startDate: t(230), endDate: t(265)),  // 35 min
        .init(stage: .asleepREM,  startDate: t(265), endDate: t(310)),  // 45 min
        .init(stage: .asleepCore, startDate: t(310), endDate: t(340)),  // 30 min
        .init(stage: .asleepREM,  startDate: t(340), endDate: t(380)),  // 40 min
        .init(stage: .awake,      startDate: t(380), endDate: t(383)),  // 3 min
        .init(stage: .asleepCore, startDate: t(383), endDate: t(420)),  // 37 min (rounds core to ~191)
        .init(stage: .inBed,      startDate: t(420), endDate: t(435)),
    ]
    // Totals: Core ≈ 191 min, Deep ≈ 85 min, REM ≈ 115 min, Awake ≈ 11 min
    // Asleep = 391 min = 6.52 h, Session = 435 min, Efficiency = 391/420 ≈ 93%

    // MARK: - Heart rate signal (bpm, ~5-min intervals)
    // Dips during deep sleep (cycles 1+2), rises in REM, slightly elevated near wake

    static let heartRateSeries: SleepChartSeries = {
        let rawValues: [(Double, Double)] = [
            (18,58),(25,56),(35,54),(50,50),(65,47),(80,45),(95,44),
            (108,46),(122,50),(135,55),(150,60),(158,56),(165,52),
            (180,48),(200,45),(215,43),(230,46),(245,50),(265,56),
            (280,60),(300,63),(320,58),(340,62),(360,65),(380,68),
            (383,59),(395,55),(410,53),(420,56),(435,58)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "Heart Rate", unit: "bpm", points: points)
    }()
    // Avg ≈ 54 bpm, Min ≈ 43 bpm  (lowest at t≈215, which is 215-18=197 min into sleep out of 402 → fraction ≈ 0.49)

    // MARK: - HRV signal (ms)

    static let hrvSeries: SleepChartSeries = {
        let rawValues: [(Double, Double)] = [
            (18,38),(30,42),(50,48),(70,55),(90,58),(110,52),(130,46),
            (150,40),(165,50),(185,56),(205,61),(225,59),(245,52),
            (265,46),(285,52),(305,48),(325,52),(345,50),(365,44),
            (383,46),(400,50),(415,48),(435,44)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "HRV", unit: "ms", points: points)
    }()
    // Avg ≈ 50 ms

    // MARK: - Respiratory rate signal (br/min)

    static let rrSeries: SleepChartSeries = {
        let rawValues: [(Double, Double)] = [
            (18,15),(30,14),(50,13),(70,13),(90,12),(110,13),(130,14),
            (150,15),(165,13),(185,12),(205,12),(225,13),(245,14),
            (265,15),(285,14),(305,13),(325,14),(345,15),(365,16),
            (383,14),(400,13),(415,14),(435,15)
        ]
        let points = rawValues.map { SleepChartPoint(date: t($0.0), value: $0.1) }
        return SleepChartSeries(title: "Respiratory Rate", unit: "br/min", points: points)
    }()
    // Avg ≈ 13.6 br/min

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
    // Matches MetricRegistry exactly (all scored metrics + weight-0 tracked metrics).
    // Values are consistent with the stage + signal data above.

    static let indicators: [SleepIndicator] = [

        // ── Sleep Architecture ─────────────────────────────────────────────────
        SleepIndicator(name: "Sleep Duration",
                       detail: "Total time asleep",
                       value: 6.52,            // 391 min ÷ 60
                       unit: "hr", category: .sleepArchitecture, source: .appleWatch,
                       range: 4...8),

        SleepIndicator(name: "Sleep Efficiency",
                       detail: "Time asleep vs time in bed",
                       value: 93,              // 391 ÷ 420 × 100
                       unit: "%", category: .sleepArchitecture, source: .appleWatch,
                       range: 70...98),

        SleepIndicator(name: "Sleep Latency",
                       detail: "Minutes to fall asleep",
                       value: 18,              // 18-min inBed before first asleep
                       unit: "min", category: .sleepArchitecture, source: .appleWatch,
                       range: 0...45),

        SleepIndicator(name: "REM Sleep",
                       detail: "Absolute REM minutes",
                       value: 115,             // 30+45+40 min
                       unit: "min", category: .sleepArchitecture, source: .appleWatch,
                       range: 30...120),

        SleepIndicator(name: "Deep Sleep",
                       detail: "Absolute deep sleep minutes",
                       value: 85,              // 50+35 min
                       unit: "min", category: .sleepArchitecture, source: .appleWatch,
                       range: 10...90),

        SleepIndicator(name: "Core Sleep",
                       detail: "Absolute core sleep minutes",
                       value: 191,             // 27+25+37+35+30+37 min
                       unit: "min", category: .sleepArchitecture, source: .appleWatch,
                       range: 60...240),

        // ── Recovery ──────────────────────────────────────────────────────────
        SleepIndicator(name: "Lowest Overnight HR",
                       detail: "Minimum HR during sleep",
                       value: 43,              // min from HR signal
                       unit: "bpm", category: .recovery, source: .appleWatch,
                       range: 40...70),

        SleepIndicator(name: "Overnight Heart Rate",
                       detail: "Average HR during sleep",
                       value: 54,              // avg from HR signal (weight-0, tracked only)
                       unit: "bpm", category: .recovery, source: .appleWatch,
                       range: 45...75),

        SleepIndicator(name: "Time to Lowest HR",
                       detail: "Lower is better · 0 = right away, 1 = never",
                       value: 0.49,            // lowest at ~t215, 197 min into 402 min sleep
                       unit: "fraction", category: .recovery, source: .appleWatch,
                       range: 0...1),

        SleepIndicator(name: "HRV",
                       detail: "Heart rate variability (SDNN)",
                       value: 50,              // avg from HRV signal
                       unit: "ms", category: .recovery, source: .appleWatch,
                       range: 20...90),

        SleepIndicator(name: "Respiratory Rate",
                       detail: "Average breaths per minute",
                       value: 14,              // avg from RR signal
                       unit: "br/min", category: .recovery, source: .appleWatch,
                       range: 10...20),

        SleepIndicator(name: "Blood Oxygen",
                       detail: "Average SpO2",
                       value: 97,
                       unit: "%", category: .recovery, source: .appleWatch,
                       range: 90...100),
    ]

    // MARK: - Monthly stats (30-day personal baselines)
    // Realistic averages — gives the detail sheet rich data to display.

    static let monthlyStats: [String: MetricStats] = [
        "Sleep Duration":       .init(avg: 7.0,  min: 5.2,  max: 8.6,  count: 28),
        "Sleep Efficiency":     .init(avg: 88,   min: 74,   max: 97,   count: 28),
        "Sleep Latency":        .init(avg: 15,   min: 4,    max: 44,   count: 26),
        "REM Sleep":            .init(avg: 108,  min: 68,   max: 145,  count: 28),
        "Deep Sleep":           .init(avg: 78,   min: 42,   max: 112,  count: 28),
        "Core Sleep":           .init(avg: 183,  min: 130,  max: 235,  count: 28),
        "Overnight Heart Rate": .init(avg: 55,   min: 49,   max: 63,   count: 27),
        "Lowest Overnight HR":  .init(avg: 46,   min: 40,   max: 55,   count: 27),
        "Time to Lowest HR":    .init(avg: 0.32, min: 0.10, max: 0.62, count: 27),
        "HRV":                  .init(avg: 48,   min: 30,   max: 70,   count: 27),
        "Respiratory Rate":     .init(avg: 13.8, min: 11.5, max: 16.5, count: 27),
        "Blood Oxygen":         .init(avg: 97.2, min: 95.5, max: 99.0, count: 25),
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
        // (overall, sleep, recovery)
        let scores: [(Double, Double, Double)] = [
            (62, 58, 65), (71, 68, 73), (68, 70, 66),
            (75, 72, 77), (73, 76, 71), (79, 77, 81), (78, 76, 81)
        ]
        return scores.enumerated().map { i, trio in
            let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: Date().startOfDay)!
            return SleepScoreTrendPoint(date: date, score: trio.0, sleepScore: trio.1, recoveryScore: trio.2)
        }
    }()
}
#endif
