import SwiftUI

struct IndicatorCategoryListView: View {
    let indicators: [SleepIndicator]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(SleepIndicatorCategory.allCases, id: \ .self) { category in
                let categoryIndicators = indicators.filter { $0.category == category }
                if !categoryIndicators.isEmpty {
                    IndicatorCategorySectionView(
                        title: category.rawValue.capitalized,
                        indicators: categoryIndicators
                    )
                }
            }
        }
    }
}
