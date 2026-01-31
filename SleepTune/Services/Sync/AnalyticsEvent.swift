import Foundation

struct AnalyticsEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let recordedAt: Date
    var dimensions: [String: String]
    var measurements: [String: Double]

    init(
        id: UUID = UUID(),
        name: String,
        recordedAt: Date = Date(),
        dimensions: [String: String] = [:],
        measurements: [String: Double] = [:]
    ) {
        self.id = id
        self.name = name
        self.recordedAt = recordedAt
        self.dimensions = dimensions
        self.measurements = measurements
    }
}
