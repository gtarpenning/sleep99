import SwiftUI

/// Sheet shown when the user wants to rate last night's sleep subjectively.
/// 5-emoji scale + optional note. Saves into SubjectiveRatingStore.
struct SubjectiveRatingSheet: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    let store: SubjectiveRatingStore

    @State private var selected: Int? = nil
    @State private var note: String = ""

    private let options: [(value: Int, emoji: String, label: String)] = [
        (1, "😴", "Terrible"),
        (2, "😕", "Poor"),
        (3, "😐", "OK"),
        (4, "🙂", "Good"),
        (5, "😄", "Great"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        Text("How did you sleep?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .padding(.top, 12)

                        HStack(spacing: 6) {
                            ForEach(options, id: \.value) { opt in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        selected = opt.value
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(opt.emoji)
                                            .font(.system(size: 32))
                                        Text(opt.label)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(selected == opt.value ? DS.textPrimary : DS.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        selected == opt.value ? DS.purple.opacity(0.15) : DS.surface,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selected == opt.value ? DS.purple.opacity(0.5) : DS.border, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anything notable?")
                                .font(.caption.weight(.semibold))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundStyle(DS.textTertiary)
                            TextField("Optional note", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(DS.surface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.border, lineWidth: 0.5))
                        }
                        .padding(.horizontal, 20)

                        Button {
                            save()
                        } label: {
                            Text("Save")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(selected != nil ? DS.purple : DS.purpleDim, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(selected == nil)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(DS.bg)
        .colorScheme(.dark)
        .onAppear {
            if let existing = store.rating(for: date) {
                selected = existing.rating
                note = existing.note ?? ""
            }
        }
    }

    private var navTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Rate \(fmt.string(from: date))"
    }

    private func save() {
        guard let rating = selected else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.save(SubjectiveRating(date: date, rating: rating, note: trimmed.isEmpty ? nil : trimmed))
        dismiss()
    }
}

// MARK: - Entry button

/// Dashboard row that opens the subjective-rating sheet, showing the saved
/// emoji when the night has already been rated.
struct SubjectiveRatingButton: View {
    @Bindable var store: SubjectiveRatingStore
    let date: Date
    @State private var showSheet = false

    private static let emojis = ["", "😴", "😕", "😐", "🙂", "😄"]

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 12) {
                let _ = store.revision   // establish observation dependency (see store)
                let existing = store.rating(for: date)
                Text(existing.map { Self.emojis[$0.rating] } ?? "🌙")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Rate last night" : "Your rating")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(existing == nil ? "How did you actually sleep?" : "Tap to update")
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .dsCard(14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            SubjectiveRatingSheet(date: date, store: store)
        }
    }
}
