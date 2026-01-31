import Foundation

protocol AnalyticsEventStore: Sendable {
    func enqueue(_ event: AnalyticsEvent) async
    func fetchBatch(limit: Int) async -> [AnalyticsEventRecord]
    func remove(ids: [UUID]) async
    func markAttempt(ids: [UUID], at date: Date) async
    func count() async -> Int
}
