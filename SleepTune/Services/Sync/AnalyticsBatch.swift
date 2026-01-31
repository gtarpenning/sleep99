import Foundation

struct AnalyticsBatch: Codable, Sendable {
    let events: [AnalyticsEvent]
    let context: AnalyticsContext
    let sentAt: Date
}
