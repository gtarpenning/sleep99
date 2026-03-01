import Foundation

@MainActor
protocol SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator]
    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async
    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint]
    func saveScore(_ score: Double, for date: Date) async
}

@MainActor
final class UserDefaultsSleepStore: SleepLocalStore {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint] {
        guard let data = defaults.data(forKey: "sleepScores"),
              let dict = try? decoder.decode([String: Double].self, from: data)
        else { return [] }

        let start = startDate.startOfDay
        let end = endDate.startOfDay
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        return dict.compactMap { key, score -> SleepScoreTrendPoint? in
            guard let date = formatter.date(from: key),
                  date >= start, date <= end
            else { return nil }
            return SleepScoreTrendPoint(date: date, score: score)
        }.sorted { $0.date < $1.date }
    }

    func saveScore(_ score: Double, for date: Date) async {
        var dict: [String: Double] = [:]
        if let data = defaults.data(forKey: "sleepScores"),
           let existing = try? decoder.decode([String: Double].self, from: data) {
            dict = existing
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        dict[formatter.string(from: date.startOfDay)] = score
        if let data = try? encoder.encode(dict) {
            defaults.set(data, forKey: "sleepScores")
        }
    }

    private func indicatorKey(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "indicators_\(formatter.string(from: date.startOfDay))"
    }
}
