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
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: statusIconName)
                    .foregroundStyle(statusIconStyle)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if showsConnectButton {
                Button("Connect Apple Health", systemImage: "heart.text.square", action: connectAction)
            }

            if showsSettingsButton {
                Button("Open Settings", systemImage: "gearshape", action: openSettingsAction)
            }
        }
    }
}
