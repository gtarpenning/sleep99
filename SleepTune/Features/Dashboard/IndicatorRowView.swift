import SwiftUI

struct IndicatorRowView: View {
    let indicator: SleepIndicator

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(indicator.name)
                Text(indicator.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(indicator.value, format: .number.precision(.fractionLength(1))) \(indicator.unit)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
}
