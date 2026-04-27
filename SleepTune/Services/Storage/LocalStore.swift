import Foundation

@MainActor
protocol SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator]
    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async
    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint]
    func saveScore(_ score: Double, sleepScore: Double, recoveryScore: Double, for date: Date) async
    func loadActivitySnapshot(for date: Date) async -> DailyActivitySnapshot?
    func saveActivitySnapshot(_ snapshot: DailyActivitySnapshot, for date: Date) async
}

// MARK: - Mock store (used by mock/preview container)
// Returns MockSleepData for any recent date so that load() populates monthly stats,
// trend history, and insights correctly — no real UserDefaults reads/writes.

#if DEBUG
@MainActor
final class MockSleepStore: SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator] {
        let days = Calendar.current.dateComponents([.day], from: date.startOfDay, to: Date().startOfDay).day ?? 0
        guard days >= 0, days < 60 else { return [] }
        return MockSleepData.indicators
    }

    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async {}

    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint] {
        let start = startDate.startOfDay
        let end   = endDate.startOfDay
        return MockSleepData.scoreHistory.filter { $0.date >= start && $0.date <= end }
    }

    func saveScore(_ score: Double, sleepScore: Double, recoveryScore: Double, for date: Date) async {}

    func loadActivitySnapshot(for date: Date) async -> DailyActivitySnapshot? {
        // Return nil so loadActivityMonthlyStats() doesn't overwrite AppContainer.mock()-seeded stats.
        nil
    }

    func saveActivitySnapshot(_ snapshot: DailyActivitySnapshot, for date: Date) async {}
}
#endif

// MARK: - UserDefaults store (production)

@MainActor
final class UserDefaultsSleepStore: SleepLocalStore {
    // Bump this when the indicator schema changes (names, units, added/removed fields).
    // Old indicator cache is automatically cleared on next launch.
    private static let currentSchemaVersion = 6
    private let schemaVersionKey = "indicatorSchemaVersion"

    private let defaults = UserDefaults.standard
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    init() {
        if defaults.integer(forKey: schemaVersionKey) != Self.currentSchemaVersion {
            // Clear all cached indicators (keyed by "indicators_<date>")
            defaults.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("indicators_") }
                .forEach { defaults.removeObject(forKey: $0) }
            defaults.set(Self.currentSchemaVersion, forKey: schemaVersionKey)
        }
    }

    // MARK: - Indicators

    func loadIndicators(for date: Date) async -> [SleepIndicator] {
        let key = indicatorKey(for: date)
        guard let data = defaults.data(forKey: key),
              let indicators = try? decoder.decode([SleepIndicator].self, from: data)
        else { return [] }
        return indicators
    }

    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async {
        let key = indicatorKey(for: date)
        guard let data = try? encoder.encode(indicators) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Scores

    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint] {
        let formatter = iso8601Formatter()
        let start = startDate.startOfDay
        let end   = endDate.startOfDay

        let overall   = loadDoubleDict(forKey: "sleepScores")
        let sleepSub  = loadDoubleDict(forKey: "sleepSubScores_sleep")
        let recSub    = loadDoubleDict(forKey: "sleepSubScores_recovery")

        return overall.compactMap { key, score -> SleepScoreTrendPoint? in
            guard let date = formatter.date(from: key),
                  date >= start, date <= end
            else { return nil }
            return SleepScoreTrendPoint(
                date:          date,
                score:         score,
                sleepScore:    sleepSub[key],
                recoveryScore: recSub[key]
            )
        }.sorted { $0.date < $1.date }
    }

    func saveScore(_ score: Double, sleepScore: Double, recoveryScore: Double, for date: Date) async {
        let formatter = iso8601Formatter()
        let key = formatter.string(from: date.startOfDay)

        saveValue(score,         forKey: key, inDictKey: "sleepScores")
        saveValue(sleepScore,    forKey: key, inDictKey: "sleepSubScores_sleep")
        saveValue(recoveryScore, forKey: key, inDictKey: "sleepSubScores_recovery")
    }

    // MARK: - Activity Snapshots

    func loadActivitySnapshot(for date: Date) async -> DailyActivitySnapshot? {
        let key = "activity_\(iso8601Formatter().string(from: date.startOfDay))"
        guard let data = defaults.data(forKey: key),
              let snapshot = try? decoder.decode(DailyActivitySnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    func saveActivitySnapshot(_ snapshot: DailyActivitySnapshot, for date: Date) async {
        let key = "activity_\(iso8601Formatter().string(from: date.startOfDay))"
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Helpers

    private func indicatorKey(for date: Date) -> String {
        "indicators_\(iso8601Formatter().string(from: date.startOfDay))"
    }

    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }

    private func loadDoubleDict(forKey key: String) -> [String: Double] {
        guard let data = defaults.data(forKey: key),
              let dict = try? decoder.decode([String: Double].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveValue(_ value: Double, forKey key: String, inDictKey dictKey: String) {
        var dict = loadDoubleDict(forKey: dictKey)
        dict[key] = value
        if let data = try? encoder.encode(dict) {
            defaults.set(data, forKey: dictKey)
        }
    }
}
