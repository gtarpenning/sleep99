import SwiftUI

struct IndicatorCategorySectionView: View {
    let title: String
    let indicators: [SleepIndicator]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)

            ForEach(indicators) { indicator in
                NavigationLink(value: indicator) {
                    IndicatorRowView(indicator: indicator)
                }
            }
        }
    }
}
