import Foundation

struct AnalyticsContext: Codable, Sendable {
    let appVersion: String
    let buildNumber: String
    let installID: UUID
    let osVersion: String
    let localeIdentifier: String
    let timeZoneIdentifier: String

    static func current(installID: UUID) -> AnalyticsContext {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let localeIdentifier = Locale.current.identifier
        let timeZoneIdentifier = TimeZone.current.identifier

        return AnalyticsContext(
            appVersion: appVersion,
            buildNumber: buildNumber,
            installID: installID,
            osVersion: osVersion,
            localeIdentifier: localeIdentifier,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}
