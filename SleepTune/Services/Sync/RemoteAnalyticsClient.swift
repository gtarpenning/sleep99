import Foundation

struct RemoteAnalyticsClient: AnalyticsClient {
    let endpointURL: URL?
    let session: URLSession

    init(endpointURL: URL? = AnalyticsConfiguration.endpointURL, session: URLSession = .shared) {
        self.endpointURL = endpointURL
        self.session = session
    }

    func send(_ batch: AnalyticsBatch) async throws {
        guard let endpointURL else {
            throw AnalyticsClientError.missingEndpoint
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(batch)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalyticsClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AnalyticsClientError.invalidResponse
        }
    }
}
