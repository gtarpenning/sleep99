import SwiftUI

struct ScoreComponentListView: View {
    let components: [SleepScoreComponent]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(components, id: \ .name) { component in
                ScoreComponentRowView(component: component)
            }
        }
    }
}
