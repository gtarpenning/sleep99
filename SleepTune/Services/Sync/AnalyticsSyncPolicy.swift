import Foundation

struct AnalyticsSyncPolicy: Sendable {
    let minimumInterval: TimeInterval
    let maxBatchSize: Int
    let retryDelays: [TimeInterval]

    static let `default` = AnalyticsSyncPolicy(
        minimumInterval: 15 * 60,
        maxBatchSize: 50,
        retryDelays: [30, 120, 300, 900, 3600]
    )

    func canAttemptSync(lastAttempt: Date?, consecutiveFailures: Int, now: Date) -> Bool {
        guard let lastAttempt else { return true }
        let requiredDelay = max(minimumInterval, delay(for: consecutiveFailures))
        return now.timeIntervalSince(lastAttempt) >= requiredDelay
    }

    func delay(for consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return 0 }
        let index = min(consecutiveFailures - 1, retryDelays.count - 1)
        return retryDelays[index]
    }
}
