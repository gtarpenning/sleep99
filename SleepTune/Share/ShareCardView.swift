import SwiftUI

struct ShareCardView: View {
    let shareText: String
    let previewImage: Image

    var body: some View {
        VStack(alignment: .leading) {
            Text("Share your score")
                .font(.headline)

            ShareLink(
                item: shareText,
                preview: SharePreview("Sleep Score", image: previewImage)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}
