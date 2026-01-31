import SwiftUI

struct IndicatorValueEditorView: View {
    @Binding var indicator: SleepIndicator

    var body: some View {
        VStack(alignment: .leading) {
            Text("Value")
                .font(.headline)

            Text("\(indicator.value, format: .number.precision(.fractionLength(1))) \(indicator.unit)")
                .foregroundStyle(.secondary)

            if let range = indicator.range {
                Slider(value: $indicator.value, in: range)
            } else {
                Stepper("Adjust", value: $indicator.value)
            }
        }
    }
}
