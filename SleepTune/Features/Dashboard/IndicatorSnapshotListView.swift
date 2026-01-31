import SwiftUI

struct IndicatorSnapshotListView: View {
    let indicators: [SleepIndicator]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Key Signals")
                .font(.headline)

            ForEach(indicators.prefix(4)) { indicator in
                NavigationLink(value: indicator) {
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
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
