import Foundation
import Observation

/// User's subjective "how did I sleep" rating for a given night.
/// 1 = terrible, 5 = excellent. Persisted to UserDefaults keyed by date.
struct SubjectiveRating: Codable, Equatable, Sendable {
    let date: Date
    let rating: Int   // 1...5
    let note: String?
}

@MainActor
@Observable
final class SubjectiveRatingStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Bumped on every write. Views that read `rating(for:)` (which pulls straight
    /// from UserDefaults and is therefore invisible to @Observable) should also touch
    /// `revision` so SwiftUI re-renders them when a rating is saved or cleared.
    private(set) var revision: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(for date: Date) -> String {
        let day = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        return "subjectiveRating_\(day)"
    }

    func rating(for date: Date) -> SubjectiveRating? {
        guard let data = defaults.data(forKey: key(for: date)) else { return nil }
        return try? decoder.decode(SubjectiveRating.self, from: data)
    }

    func save(_ rating: SubjectiveRating) {
        guard let data = try? encoder.encode(rating) else { return }
        defaults.set(data, forKey: key(for: rating.date))
        revision += 1
    }

    func clear(for date: Date) {
        defaults.removeObject(forKey: key(for: date))
        revision += 1
    }
}
