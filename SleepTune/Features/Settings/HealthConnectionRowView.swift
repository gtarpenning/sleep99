import SwiftUI

struct HealthConnectionRowView: View {
    let title: String
    let message: String
    let statusIconName: String
    let statusIconStyle: AnyShapeStyle
    let showsConnectButton: Bool
    let showsSettingsButton: Bool
    let connectAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                Image(systemName: statusIconName)
                    .foregroundStyle(statusIconStyle)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(DS.textSecondary)

            if showsConnectButton {
                Button(action: connectAction) {
                    Label("Connect Apple Health", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.purple, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            if showsSettingsButton {
                Button(action: openSettingsAction) {
                    Label("Open Settings", systemImage: "gearshape")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DS.border, lineWidth: 0.5))
                        .foregroundStyle(DS.textPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
