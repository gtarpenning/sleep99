import Foundation

@MainActor
final class AnalyticsInstallIDStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "analytics.install.id") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func installID() -> UUID {
        if let stored = userDefaults.string(forKey: key), let uuid = UUID(uuidString: stored) {
            return uuid
        }

        let newID = UUID()
        userDefaults.set(newID.uuidString, forKey: key)
        return newID
    }
}
