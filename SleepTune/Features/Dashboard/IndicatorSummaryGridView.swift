import SwiftUI

struct IndicatorSummaryGridView: View {
    let indicators: [SleepIndicator]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
            ForEach(indicators) { indicator in
                IndicatorSummaryTileView(indicator: indicator)
            }
        }
    }
}
