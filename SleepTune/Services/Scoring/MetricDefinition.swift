import Foundation

// MARK: - MetricDefinition

/// Single source of truth for every tracked sleep metric.
/// Adding a new metric means adding one entry here, then wiring the HealthKit fetch.
/// Scoring, display weights, delta direction, and subtitle hints all derive from this.
struct MetricDefinition {
    let name: String
    let category: SleepIndicatorCategory
    let scoring: ScoringShape
    /// Relative weight within its category.
    /// The engine normalises by total weight so values don't need to sum to anything.
    let weight: Double
    /// True when a lower raw value is healthier (HR, latency, respiratory rate, etc.)
    /// Controls delta colour in the breakdown view.
    let lowerIsBetter: Bool
    /// Short contextual hint shown in the metric row subtitle when no monthly baseline
    /// exists yet, or when the metric needs directional context (e.g. fraction 0–1 range).
    let hint: String?
}

// MARK: - MetricRegistry

enum MetricRegistry {

    // MARK: Master list — add a line here to add or tune a metric

    static let all: [MetricDefinition] = [

        // ── Sleep Architecture ────────────────────────────────────────────────
        // Duration is the primary driver; efficiency and latency are supporting signals.
        // REM / Deep / Core scored in absolute minutes — what matters is how much you got,
        // not the percentage, and personal monthly average becomes the personal ideal.

        .init(name: "Sleep Duration",
              category: .sleepArchitecture,
              scoring: .higherIsBetter(hardMin: 4, idealMin: 8),   // hours; 8h = perfect
              weight: 0.35, lowerIsBetter: false, hint: nil),

        .init(name: "Long Awakenings",
              category: .sleepArchitecture,
              scoring: .lowerIsBetter(idealMax: 0, hardMax: 3),    // 0 = perfect, 3+ = 0
              weight: 0.05, lowerIsBetter: true,
              hint: "0 = perfect · each long waking hurts"),

        // Average HR during sleep scores in BOTH categories (see recovery entry below).
        // Physiologically it reflects sleep quality (arousal, stress) AND cardiovascular recovery.
        .init(name: "Overnight Heart Rate",
              category: .sleepArchitecture,
              scoring: .lowerIsBetter(idealMax: 50, hardMax: 80),
              weight: 0.20, lowerIsBetter: true, hint: nil),

        .init(name: "REM Sleep",
              category: .sleepArchitecture,
              scoring: .higherIsBetter(hardMin: 30, idealMin: 90), // minutes; personal avg beats 90
              weight: 0.20, lowerIsBetter: false, hint: nil),

        .init(name: "Deep Sleep",
              category: .sleepArchitecture,
              scoring: .higherIsBetter(hardMin: 10, idealMin: 60), // minutes; personal avg beats 60
              weight: 0.10, lowerIsBetter: false, hint: nil),

        // Bedtime within 30 min of personal average = perfect; 2 hr off = 0.
        // Value stored as hours-from-noon (e.g. 10 PM = 10.0, midnight = 12.0, 1 AM = 13.0).
        .init(name: "Bedtime Consistency",
              category: .sleepArchitecture,
              scoring: .personalAverageDeadband(deadband: 0.5, hardMax: 2.0), // hours
              weight: 0.10, lowerIsBetter: false,
              hint: "+/- 30 min of your usual bedtime is perfect"),

        .init(name: "Sleep Efficiency",
              category: .sleepArchitecture,
              scoring: .higherIsBetter(hardMin: 60, idealMin: 90), // %; informational
              weight: 0.04, lowerIsBetter: false, hint: nil),

        .init(name: "Sleep Latency",
              category: .sleepArchitecture,
              scoring: .lowerIsBetter(idealMax: 10, hardMax: 60),  // minutes to fall asleep
              weight: 0.02, lowerIsBetter: true, hint: "lower is better"),

        .init(name: "Core Sleep",
              category: .sleepArchitecture,
              scoring: .higherIsBetter(hardMin: 60, idealMin: 180), // minutes
              weight: 0.04, lowerIsBetter: false, hint: nil),

        // ── Recovery ──────────────────────────────────────────────────────────
        // HR and HRV together dominate (0.60 combined).
        // Respiratory rate and time-to-lowest-HR are supporting signals.
        // SpO2 is a safety floor, not a performance differentiator for healthy sleepers.

        .init(name: "Lowest Overnight HR",
              category: .recovery,
              scoring: .lowerIsBetter(idealMax: 45, hardMax: 80),  // bpm; personal avg or 45 as floor
              weight: 0.30, lowerIsBetter: true, hint: "lower is better"),

        .init(name: "Time to Lowest HR",
              category: .recovery,
              scoring: .lowerIsBetter(idealMax: 0.33, hardMax: 1), // perfect in first third; linear decay after
              weight: 0.15, lowerIsBetter: true,
              hint: "within the first third of the night is perfect"),

        .init(name: "HRV",
              category: .recovery,
              scoring: .higherIsBetter(hardMin: 10, idealMin: 50), // ms SDNN; personal avg beats 50
              weight: 0.30, lowerIsBetter: false, hint: nil),

        .init(name: "Respiratory Rate",
              category: .recovery,
              scoring: .lowerIsBetter(idealMax: 12, hardMax: 22),  // br/min; personal avg or 12
              weight: 0.10, lowerIsBetter: true, hint: "lower is better"),

        .init(name: "Blood Oxygen",
              category: .recovery,
              scoring: .higherIsBetter(hardMin: 88, idealMin: 97), // %; 97% = perfect
              weight: 0.03, lowerIsBetter: false, hint: nil),

        // Weight 0 = tracked for history / display but excluded from score

        // Average HR during sleep — light scoring signal (~9% of recovery after normalisation)
        // and drives the ambient colour on the hero view.
        .init(name: "Overnight Heart Rate",
              category: .recovery,
              scoring: .lowerIsBetter(idealMax: 50, hardMax: 80),
              weight: 0.10, lowerIsBetter: true, hint: nil),

        .init(name: "Wrist Temperature",
              category: .recovery,
              scoring: .lowerIsBetterRelative(hardMaxDelta: 1.0),  // ≤ avg = perfect; avg+1°C = 0
              weight: 0.02, lowerIsBetter: true,
              hint: "cooler than your average is better"),
    ]

    // MARK: - Lookups

    static func definition(for name: String) -> MetricDefinition? {
        all.first { $0.name == name }
    }

    /// All metrics that contribute to scoring in the given category (weight > 0).
    static func scoredMetrics(in category: SleepIndicatorCategory) -> [MetricDefinition] {
        all.filter { $0.category == category && $0.weight > 0 }
    }
}
