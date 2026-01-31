import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var weights: SleepScoreWeights
    var isEditingTunedWeights = false
    var isSignedIn = false
    var isReduceMotionEnabled = false
    var isHighContrastEnabled = false
    var isCompactLayoutEnabled = false
    var healthAuthorizationState: HealthAuthorizationState

    private let localStore: SleepLocalStore
    private let healthKitClient: HealthKitClient

    init(localStore: SleepLocalStore, healthKitClient: HealthKitClient) {
        self.localStore = localStore
        self.healthKitClient = healthKitClient
        self.weights = .default
        self.healthAuthorizationState = .needsPermission

        Task { @MainActor in
            await load()
        }
    }

    var accountStatusText: String {
        isSignedIn ? "Signed In" : "Signed Out"
    }

    func load() async {
        weights = await localStore.loadWeights()
        await refreshHealthAuthorizationState()
    }

    func updateWeights(_ weights: SleepScoreWeights) {
        self.weights = weights
        Task { @MainActor in
            await localStore.saveWeights(weights)
        }
    }

    func setTunedWeightsEditing(_ isEditing: Bool) {
        isEditingTunedWeights = isEditing
    }

    func toggleTunedWeightsEditing() {
        isEditingTunedWeights.toggle()
    }

    func logIn() {
        isSignedIn = true
    }

    func logOut() {
        isSignedIn = false
    }

    var healthStatusTitle: String {
        switch healthAuthorizationState {
        case .unavailable:
            return "Health data unavailable"
        case .needsPermission:
            return "Connect to Health"
        case .denied:
            return "Health access denied"
        case .authorized:
            return "Health connected"
        }
    }

    var healthStatusMessage: String {
        switch healthAuthorizationState {
        case .unavailable:
            return "Health data isn’t available on this device."
        case .needsPermission:
            return "Connect to Apple Health to sync sleep signals."
        case .denied:
            return "Open Settings to allow SleepTune to read Health data."
        case .authorized:
            return "SleepTune can read your Health data."
        }
    }

    var healthStatusIconName: String {
        switch healthAuthorizationState {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.octagon.fill"
        case .needsPermission:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "slash.circle.fill"
        }
    }

    var healthStatusIconStyle: AnyShapeStyle {
        switch healthAuthorizationState {
        case .authorized:
            return AnyShapeStyle(.green)
        case .denied:
            return AnyShapeStyle(.orange)
        case .needsPermission:
            return AnyShapeStyle(.yellow)
        case .unavailable:
            return AnyShapeStyle(.secondary)
        }
    }

    var showsHealthConnectButton: Bool {
        switch healthAuthorizationState {
        case .needsPermission:
            return true
        default:
            return false
        }
    }

    var showsHealthSettingsButton: Bool {
        switch healthAuthorizationState {
        case .denied:
            return true
        default:
            return false
        }
    }

    func refreshHealthAuthorizationState() async {
        healthAuthorizationState = await healthKitClient.authorizationState()
    }

    func requestHealthAccess() async {
        do {
            try await healthKitClient.requestAuthorization()
        } catch {
            // Swallow errors here so the UI can still reflect the current state.
        }
        await refreshHealthAuthorizationState()
    }

    var appSettingsURL: URL? {
        URL(string: "app-settings:")
    }
}
