import SwiftUI

struct IndicatorDetailView: View {
    @Binding var indicator: SleepIndicator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(indicator.name)
                    .font(.title2)
                    .bold()

                Text(indicator.detail)
                    .foregroundStyle(.secondary)

                IndicatorValueEditorView(indicator: $indicator)

                Toggle("Manual Override", isOn: $indicator.isManualOverride)

                IndicatorMetadataView(indicator: indicator)
            }
            .padding()
        }
        .navigationTitle(indicator.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
