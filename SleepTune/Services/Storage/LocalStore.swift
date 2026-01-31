import Foundation
import Observation

@MainActor
protocol SleepLocalStore {
    func loadIndicators(for date: Date) async -> [SleepIndicator]
    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async
    func loadWeights() async -> SleepScoreWeights
    func saveWeights(_ weights: SleepScoreWeights) async
    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint]
    func saveScore(_ score: Double, for date: Date) async
}

@MainActor
@Observable
final class InMemorySleepLocalStore: SleepLocalStore {
    private var indicatorsByDay: [Date: [SleepIndicator]] = [:]
    private var weights: SleepScoreWeights = .default
    private var scoreByDay: [Date: Double] = [:]

    func loadIndicators(for date: Date) async -> [SleepIndicator] {
        indicatorsByDay[date.startOfDay] ?? []
    }

    func saveIndicators(_ indicators: [SleepIndicator], for date: Date) async {
        indicatorsByDay[date.startOfDay] = indicators
    }

    func loadWeights() async -> SleepScoreWeights {
        weights
    }

    func saveWeights(_ weights: SleepScoreWeights) async {
        self.weights = weights
    }

    func loadScores(from startDate: Date, to endDate: Date) async -> [SleepScoreTrendPoint] {
        let start = startDate.startOfDay
        let end = endDate.startOfDay

        return scoreByDay
            .filter { $0.key >= start && $0.key <= end }
            .map { SleepScoreTrendPoint(date: $0.key, score: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func saveScore(_ score: Double, for date: Date) async {
        scoreByDay[date.startOfDay] = score
    }
}
