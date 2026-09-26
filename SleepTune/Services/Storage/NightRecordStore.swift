import Foundation
import SwiftData

/// Single writer for `NightRecord`. Views and view models never touch a
/// `ModelContext`; they call this actor and get `NightSummary` values back.
@ModelActor
actor NightRecordStore {

    // MARK: - Container

    /// Opens the on-disk store. A store that fails to open (corrupt file,
    /// impossible migration) is moved aside and recreated: every row is
    /// re-derivable from HealthKit, so losing the cache is safe.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: NightSchemaV1.self)
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            // In-memory containers only fail on programmer error.
            return try! ModelContainer(for: schema, migrationPlan: NightMigrationPlan.self, configurations: [config])
        }
        let url = URL.applicationSupportDirectory.appending(path: "nights.store")
        // Local only: the app has iCloud entitlements, and without this SwiftData
        // silently opts the store into CloudKit mirroring.
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, migrationPlan: NightMigrationPlan.self, configurations: [config])
        } catch {
            let fm = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let f = URL(fileURLWithPath: url.path + suffix)
                let aside = URL(fileURLWithPath: url.path + suffix + ".corrupt")
                try? fm.removeItem(at: aside)
                try? fm.moveItem(at: f, to: aside)
            }
            UserDefaults.standard.set(false, forKey: HistoryBackfill.completeKey)
            if let fresh = try? ModelContainer(for: schema, migrationPlan: NightMigrationPlan.self, configurations: [config]) {
                return fresh
            }
            return makeContainer(inMemory: true)
        }
    }

    // MARK: - Writes

    func upsert(_ summary: NightSummary) throws {
        let key = summary.key
        let existing = try modelContext.fetch(
            FetchDescriptor<NightRecord>(predicate: #Predicate { $0.key == key })
        ).first
        if let existing {
            existing.apply(summary)
        } else {
            modelContext.insert(NightRecord(summary))
        }
        try modelContext.save()
    }

    func upsert(_ summaries: [NightSummary]) throws {
        for s in summaries { try upsert(s) }
    }

    /// Merges only the given fields into an existing record; no-op if missing.
    func update(key: String, _ mutate: @Sendable (inout NightSummary) -> Void) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<NightRecord>(predicate: #Predicate { $0.key == key })
        ).first else { return }
        var s = existing.summary
        mutate(&s)
        existing.apply(s)
        try modelContext.save()
    }

    func deleteAll() throws {
        try modelContext.delete(model: NightRecord.self)
        try modelContext.save()
    }

    // MARK: - Reads

    /// Nights with `from <= night <= to`, ascending.
    func records(from: Date, to: Date) throws -> [NightSummary] {
        let lo = Calendar.current.startOfDay(for: from)
        let hi = Calendar.current.startOfDay(for: to)
        var d = FetchDescriptor<NightRecord>(
            predicate: #Predicate { $0.night >= lo && $0.night <= hi },
            sortBy: [SortDescriptor(\.night)]
        )
        d.includePendingChanges = true
        return try modelContext.fetch(d).map(\.summary)
    }

    /// The `n` most recent nights ending at `to` (inclusive), ascending.
    func latest(_ n: Int, endingAt to: Date = Date()) throws -> [NightSummary] {
        let hi = Calendar.current.startOfDay(for: to)
        var d = FetchDescriptor<NightRecord>(
            predicate: #Predicate { $0.night <= hi },
            sortBy: [SortDescriptor(\.night, order: .reverse)]
        )
        d.fetchLimit = n
        return try modelContext.fetch(d).map(\.summary).reversed()
    }

    func record(for date: Date) throws -> NightSummary? {
        let key = NightSummary.key(for: Calendar.current.startOfDay(for: date))
        return try modelContext.fetch(
            FetchDescriptor<NightRecord>(predicate: #Predicate { $0.key == key })
        ).first?.summary
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<NightRecord>())
    }

    func oldestNight() throws -> Date? {
        var d = FetchDescriptor<NightRecord>(sortBy: [SortDescriptor(\.night)])
        d.fetchLimit = 1
        return try modelContext.fetch(d).first?.night
    }
}
