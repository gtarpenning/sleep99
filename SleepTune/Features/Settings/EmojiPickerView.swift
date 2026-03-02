import SwiftUI

struct EmojiPickerView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    private let emojis: [String] = [
        "😴", "🌙", "⭐️", "✨", "💤",
        "🌟", "🌛", "🌜", "🌚", "🌌",
        "🐻", "🦊", "🐼", "🐨", "🦁",
        "🐸", "🐧", "🦆", "🐙", "🦋",
        "🌸", "🌺", "🍀", "🌿", "🎋",
        "🔥", "❄️", "🌊", "⚡️", "🎯",
        "🎸", "🎹", "🎺", "🥁", "🎻",
        "🏔️", "🌄", "🌅", "🌃", "🏕️",
        "🧘", "🏃", "🚴", "🧗", "🤸",
        "🍎", "🍵", "☕️", "🫖", "🧃",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            let isSelected = container.authService.avatarEmoji == emoji
                            Button {
                                container.authService.setAvatarEmoji(emoji)
                                dismiss()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        isSelected ? DS.purple.opacity(0.25) : DS.surface,
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                isSelected ? DS.purple : DS.border,
                                                lineWidth: isSelected ? 1.5 : 0.5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DS.textSecondary)
                            .font(.title3)
                    }
                }
                if container.authService.avatarEmoji != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Remove") {
                            container.authService.avatarEmoji = nil
                            UserDefaults.standard.removeObject(forKey: "auth.avatarEmoji")
                            dismiss()
                        }
                        .foregroundStyle(DS.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }
}
