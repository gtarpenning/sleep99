import Foundation

actor FileAnalyticsEventStore: AnalyticsEventStore {
    private var records: [AnalyticsEventRecord]
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let resolvedURL = fileURL ?? Self.defaultFileURL
        self.fileURL = resolvedURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        self.records = Self.loadRecords(from: resolvedURL, decoder: decoder)
    }

    static var defaultFileURL: URL {
        URL.documentsDirectory.appending(path: "analytics-events.json")
    }

    func enqueue(_ event: AnalyticsEvent) async {
        records.append(AnalyticsEventRecord(event: event))
        persist()
    }

    func fetchBatch(limit: Int) async -> [AnalyticsEventRecord] {
        guard limit > 0 else { return [] }
        return Array(records.prefix(limit))
    }

    func remove(ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        records.removeAll { idSet.contains($0.id) }
        persist()
    }

    func markAttempt(ids: [UUID], at date: Date) async {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        records = records.map { record in
            guard idSet.contains(record.id) else { return record }
            var updated = record
            updated.attemptCount += 1
            updated.lastAttemptAt = date
            return updated
        }
        persist()
    }

    func count() async -> Int {
        records.count
    }

    private static func loadRecords(from url: URL, decoder: JSONDecoder) -> [AnalyticsEventRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([AnalyticsEventRecord].self, from: data)) ?? []
    }

    private func persist() {
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Ignore persistence errors to keep the app fully functional offline.
        }
    }
}
