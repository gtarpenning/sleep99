import Foundation

protocol AnalyticsClient: Sendable {
    func send(_ batch: AnalyticsBatch) async throws
}

enum AnalyticsClientError: Error {
    case missingEndpoint
    case invalidResponse
}
