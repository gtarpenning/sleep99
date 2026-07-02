import Foundation

/// Thin codable struct shared between the main app and the widget extension.
/// Written by the app each time the score updates; read by the widget on refresh.
struct WidgetSnapshot: Codable, Equatable {
    let updatedAt: Date
    let score: Double
    let sleepScore: Double
    let recoveryScore: Double
    let totalSleepMinutes: Int

    var displayDate: Date { updatedAt }
}

/// Shared App Group container for widget data.
/// The actual App Group identifier needs to be configured in Xcode capabilities;
/// for now we fall back to standard UserDefaults so the main-app code compiles
/// and writes data — the widget will need the App Group entitlement to read it.
enum WidgetSnapshotStore {
    /// Configure this with your App Group ID once the capability is added in Xcode:
    ///   group.com.sleep-tune.app
    /// Until then we use standard defaults so the app never crashes.
    static let appGroupIdentifier = "group.com.sleep-tune.app"
    private static let key = "widgetSnapshot.v1"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = sharedDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
