import SwiftUI

struct HealthAccessFullScreenView: View {
    let authorizationState: HealthAuthorizationState
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(DS.purpleDim)
                        .frame(width: 80, height: 80)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DS.purple)
                }
                .padding(.bottom, 28)

                // Text
                VStack(spacing: 10) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Buttons
                VStack(spacing: 10) {
                    if showsButton {
                        Button(action: requestAccess) {
                            HStack {
                                Image(systemName: "heart.text.square")
                                Text("Connect Apple Health")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.purple, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    if showsSettingsButton {
                        Button(action: openSettings) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Open Settings")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).strokeBorder(DS.border, lineWidth: 0.5)
                            )
                            .foregroundStyle(DS.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private var title: String {
        switch authorizationState {
        case .unavailable:     return "Not Available"
        case .needsPermission: return "Connect Health"
        case .denied:          return "Access Denied"
        case .authorized:      return "Connected"
        }
    }

    private var message: String {
        switch authorizationState {
        case .unavailable:     return "Health data isn't available on this device."
        case .needsPermission: return "Grant access to sleep, heart rate, and recovery signals to generate your score."
        case .denied:          return "Open the Health app, go to Sharing → Apps → SleepTune, and enable the data types you want to share."
        case .authorized:      return "Syncing your health data."
        }
    }

    private var showsButton: Bool         { authorizationState == .needsPermission }
    private var showsSettingsButton: Bool { authorizationState == .denied }
}
