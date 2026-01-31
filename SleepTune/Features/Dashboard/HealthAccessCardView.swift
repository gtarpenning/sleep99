import SwiftUI

struct HealthAccessCardView: View {
    let authorizationState: HealthAuthorizationState
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)

            Text(message)
                .foregroundStyle(.secondary)

            if showsButton {
                Button("Connect Apple Health", systemImage: "heart.text.square", action: requestAccess)
                    .buttonStyle(.borderedProminent)
            }

            if showsSettingsButton {
                Button("Open Settings", systemImage: "gearshape", action: openSettings)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var title: String {
        switch authorizationState {
        case .unavailable:
            return "Health data unavailable"
        case .needsPermission:
            return "Connect Apple Health"
        case .denied:
            return "Health access denied"
        case .authorized:
            return "Health data connected"
        }
    }

    private var message: String {
        switch authorizationState {
        case .unavailable:
            return "Health data isn’t available on this device."
        case .needsPermission:
            return "We’ll use sleep and recovery signals to power your score."
        case .denied:
            return "Enable access in Settings to sync sleep signals."
        case .authorized:
            return "We’ll keep syncing your latest sleep signals."
        }
    }

    private var showsButton: Bool {
        switch authorizationState {
        case .needsPermission:
            return true
        default:
            return false
        }
    }

    private var showsSettingsButton: Bool {
        switch authorizationState {
        case .denied:
            return true
        default:
            return false
        }
    }
}
