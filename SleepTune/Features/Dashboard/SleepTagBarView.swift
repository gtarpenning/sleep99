import SwiftUI

struct SleepTagBarView: View {
    var store: SleepTagStore
    let date: Date

    @State private var newTagName = ""
    @State private var isAddingTag = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Scrollable pill row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.availableTags) { tag in
                        let active = store.isActive(tag, for: date)
                        TagPill(name: tag.name, isActive: active) {
                            store.toggle(tag, for: date)
                        } onDelete: {
                            store.deleteTag(tag)
                        }
                    }

                    // Inline add-tag control
                    if isAddingTag {
                        HStack(spacing: 4) {
                            TextField("tag name…", text: $newTagName)
                                .focused($isFieldFocused)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textPrimary)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                                .submitLabel(.done)
                                .onSubmit { commitNewTag() }
                                .frame(minWidth: 80, maxWidth: 140)

                            Button(action: commitNewTag) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DS.purple)
                            }
                            .buttonStyle(.plain)
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                cancelAdd()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DS.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(DS.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(DS.purple.opacity(0.5), lineWidth: 1))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        // "+" button
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                isAddingTag = true
                            }
                            isFieldFocused = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Add tag")
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(DS.textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(DS.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(DS.border, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private func commitNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.addTag(name: trimmed)
            // Auto-activate the newly added tag for tonight
            if let tag = store.availableTags.last(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                store.toggle(tag, for: date)
            }
        }
        cancelAdd()
    }

    private func cancelAdd() {
        withAnimation(.spring(duration: 0.2)) {
            isAddingTag = false
        }
        newTagName = ""
        isFieldFocused = false
    }
}

// MARK: - Tag Pill

private struct TagPill: View {
    let name: String
    let isActive: Bool
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : DS.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? DS.purple : DS.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(
                    isActive ? DS.purple : DS.border, lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isActive)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Tag", systemImage: "trash")
            }
        }
    }
}
