import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var healthAuthorizationState: HealthAuthorizationState = .needsPermission

    private let healthKitClient: HealthKitClient

    init(healthKitClient: HealthKitClient) {
        self.healthKitClient = healthKitClient
        Task { @MainActor in
            await refreshHealthAuthorizationState()
        }
    }

    var healthStatusTitle: String {
        switch healthAuthorizationState {
        case .unavailable: return "Health data unavailable"
        case .needsPermission: return "Connect to Health"
        case .denied: return "Health access denied"
        case .authorized: return "Health connected"
        }
    }

    var healthStatusMessage: String {
        switch healthAuthorizationState {
        case .unavailable: return "Health data isn't available on this device."
        case .needsPermission: return "Connect to Apple Health to sync sleep signals."
        case .denied: return "Open Settings to allow SleepTune to read Health data."
        case .authorized: return "SleepTune can read your Health data."
        }
    }

    var healthStatusIconName: String {
        switch healthAuthorizationState {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.octagon.fill"
        case .needsPermission: return "exclamationmark.triangle.fill"
        case .unavailable: return "slash.circle.fill"
        }
    }

    var healthStatusIconStyle: AnyShapeStyle {
        switch healthAuthorizationState {
        case .authorized: return AnyShapeStyle(.green)
        case .denied: return AnyShapeStyle(.orange)
        case .needsPermission: return AnyShapeStyle(.yellow)
        case .unavailable: return AnyShapeStyle(.secondary)
        }
    }

    var showsHealthConnectButton: Bool { healthAuthorizationState == .needsPermission }
    var showsHealthSettingsButton: Bool { healthAuthorizationState == .denied }

    func refreshHealthAuthorizationState() async {
        healthAuthorizationState = await healthKitClient.authorizationState()
    }

    func requestHealthAccess() async {
        do { try await healthKitClient.requestAuthorization() } catch {}
        await refreshHealthAuthorizationState()
    }

    var appSettingsURL: URL? { URL(string: "app-settings:") }
}
