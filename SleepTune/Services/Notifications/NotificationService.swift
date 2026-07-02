import Foundation
import UserNotifications

/// Schedules a daily prompt asking the user to rate last night's sleep.
/// Single notification, fires at the user's preferred time (default 10am local).
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private static let scheduledIdentifier = "sleeptune.dailyRatingPrompt"

    /// User's preferred reminder hour, 24h. Persisted in UserDefaults.
    /// Default 10 (10am).
    var reminderHour: Int {
        get { UserDefaults.standard.object(forKey: "notif.reminderHour") as? Int ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "notif.reminderHour") }
    }

    /// Whether the daily reminder is enabled at all.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif.dailyEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "notif.dailyEnabled") }
    }

    /// Request permission. Returns true if granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Whether the user has already responded to the system permission prompt.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedule (or reschedule) the daily 10am prompt. Idempotent — replaces any
    /// existing scheduled instance.
    func scheduleDailyReminder() async {
        let status = await currentAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        await cancelAll()

        let content = UNMutableNotificationContent()
        content.title = "How did you sleep?"
        content.body  = "Take a moment to rate last night and check your score."
        content.sound = .default

        var date = DateComponents()
        date.hour = reminderHour
        date.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: Self.scheduledIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Cancel any scheduled reminder.
    func cancelAll() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.scheduledIdentifier])
    }

    /// Convenience to enable + schedule, asking for permission if needed.
    func enable() async -> Bool {
        let status = await currentAuthorizationStatus()
        if status == .notDetermined {
            let granted = await requestAuthorization()
            guard granted else { return false }
        } else if status == .denied {
            return false
        }
        isEnabled = true
        await scheduleDailyReminder()
        return true
    }

    /// Convenience to disable + cancel.
    func disable() async {
        isEnabled = false
        await cancelAll()
    }
}
