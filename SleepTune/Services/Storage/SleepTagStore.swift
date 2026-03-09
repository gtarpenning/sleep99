import Foundation
import Observation

@MainActor
@Observable
final class SleepTagStore {
    /// All user-defined tags.
    var availableTags: [SleepTag] = []

    /// Tags active for a given date, keyed by ISO8601 date string.
    private var activeTags: [String: Set<UUID>] = [:]

    private let tagsKey   = "sleepTags.available"
    private let activeKey = "sleepTags.active"

    init() { load() }

    // MARK: - Tag management

    func addTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !availableTags.contains(where: { $0.name.lowercased() == trimmed.lowercased() })
        else { return }
        availableTags.append(SleepTag(name: trimmed))
        save()
    }

    func deleteTag(_ tag: SleepTag) {
        availableTags.removeAll { $0.id == tag.id }
        for key in activeTags.keys { activeTags[key]?.remove(tag.id) }
        save()
    }

    // MARK: - Per-night tagging

    func isActive(_ tag: SleepTag, for date: Date) -> Bool {
        (activeTags[key(for: date)] ?? []).contains(tag.id)
    }

    func toggle(_ tag: SleepTag, for date: Date) {
        let k = key(for: date)
        var set = activeTags[k] ?? []
        if set.contains(tag.id) { set.remove(tag.id) } else { set.insert(tag.id) }
        activeTags[k] = set
        save()
    }

    func activeTags(for date: Date) -> [SleepTag] {
        let ids = activeTags[key(for: date)] ?? []
        return availableTags.filter { ids.contains($0.id) }
    }

    // MARK: - Persistence

    private func key(for date: Date) -> String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(data, forKey: tagsKey)
        }
        let encoded = activeTags.mapValues { $0.map(\.uuidString) }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: activeKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let tags = try? JSONDecoder().decode([SleepTag].self, from: data) {
            availableTags = tags
        }
        if let data = UserDefaults.standard.data(forKey: activeKey),
           let encoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            activeTags = encoded.mapValues { Set($0.compactMap(UUID.init(uuidString:))) }
        }
    }
}
