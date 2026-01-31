import Foundation

struct AnalyticsEventRecord: Codable, Identifiable, Sendable {
    let event: AnalyticsEvent
    var attemptCount: Int
    var lastAttemptAt: Date?
    let createdAt: Date

    var id: UUID {
        event.id
    }

    init(
        event: AnalyticsEvent,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.event = event
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.createdAt = createdAt
    }
}
