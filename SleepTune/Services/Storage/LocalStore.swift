import Foundation

@MainActor
protocol SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator]
    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async
    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint]
    func saveScore(_ score: Double, sleepScore: Double, recoveryScore: Double, for date: Date) async
}

// MARK: - In-memory store (used by mock/preview container — always returns empty so
// MockHealthKitClient is always called instead of hitting stale UserDefaults cache)

#if DEBUG
@MainActor
final class InMemorySleepStore: SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator] { [] }
    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async {}
    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint] { [] }
    func saveScore(_ score: Double, sleepScore: Double, recoveryScore: Double, for date: Date) async {}
}
#endif

// MARK: - UserDefaults store (production)

@MainActor
final class UserDefaultsSleepStore: SleepLocalStore {
    private let defaults = UserDefaults.standard
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

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
