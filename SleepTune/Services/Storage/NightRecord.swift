import Foundation
import SwiftData

// Versioned from day one. Adding optional fields is a lightweight migration;
// renames or type changes need a custom stage appended to `NightMigrationPlan`.
enum NightSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [NightRecord.self] }

    @Model
    final class NightRecord {
        /// yyyy-MM-dd of the wake date. Unique key — `Date` uniqueness is
        /// unreliable across timezone changes, a string is not.
        @Attribute(.unique) var key: String
        var night: Date
        var score: Double
        var sleepScore: Double
        var recoveryScore: Double
        var metrics: [String: Double]
        var maxHR: Double?
        var steps: Double?
        var activeCalories: Double?
        var exerciseMinutes: Double?
        var peakHR: Double?
        var vo2Max: Double?
        var sleepStart: Date?
        var sleepEnd: Date?
        var dayTypeRaw: String
        var alcoholFlag: Bool?
        var updatedAt: Date

        init(_ s: NightSummary) {
            key = s.key
            night = s.night
            score = s.score
            sleepScore = s.sleepScore
            recoveryScore = s.recoveryScore
            metrics = s.metrics
            maxHR = s.maxHR
            steps = s.steps
            activeCalories = s.activeCalories
            exerciseMinutes = s.exerciseMinutes
            peakHR = s.peakHR
            vo2Max = s.vo2Max
            sleepStart = s.sleepStart
            sleepEnd = s.sleepEnd
            dayTypeRaw = s.dayType.rawValue
            alcoholFlag = s.alcoholFlag
            updatedAt = Date()
        }

        func apply(_ s: NightSummary) {
            night = s.night
            score = s.score
            sleepScore = s.sleepScore
            recoveryScore = s.recoveryScore
            metrics = s.metrics
            maxHR = s.maxHR
            steps = s.steps
            activeCalories = s.activeCalories
            exerciseMinutes = s.exerciseMinutes
            peakHR = s.peakHR
            vo2Max = s.vo2Max
            sleepStart = s.sleepStart
            sleepEnd = s.sleepEnd
            dayTypeRaw = s.dayType.rawValue
            if let flag = s.alcoholFlag { alcoholFlag = flag }
            updatedAt = Date()
        }

        var summary: NightSummary {
            NightSummary(
                night: night, score: score, sleepScore: sleepScore, recoveryScore: recoveryScore,
                metrics: metrics, maxHR: maxHR, steps: steps, activeCalories: activeCalories,
                exerciseMinutes: exerciseMinutes, peakHR: peakHR, vo2Max: vo2Max,
                sleepStart: sleepStart, sleepEnd: sleepEnd,
                dayType: DayType(rawValue: dayTypeRaw) ?? .weekday,
                alcoholFlag: alcoholFlag
            )
        }
    }
}

typealias NightRecord = NightSchemaV1.NightRecord

enum NightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NightSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
