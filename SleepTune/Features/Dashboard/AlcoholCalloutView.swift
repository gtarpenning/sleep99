import SwiftUI

/// Small pill under the score: "Elevated HR · likely alcohol". Tapping opens
/// a sheet that explains the signals and lets the user confirm or dismiss,
/// which both tags the night and trains the baseline.
struct AlcoholCalloutPill: View {
    let result: AlcoholHeuristic.Result
    let confirmed: Bool?
    let onTap: () -> Void

    private var label: String {
        if confirmed == true { return "Alcohol night" }
        if confirmed == false { return "" }
        return result.verdict == .likely ? "Elevated HR · likely alcohol" : "Elevated HR · alcohol?"
    }

    var body: some View {
        if !label.isEmpty {
            Button(action: onTap) {
                HStack(spacing: 5) {
                    Image(systemName: "wineglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(pillColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(pillColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(pillColor.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var pillColor: Color {
        confirmed == true || result.verdict == .likely
            ? Color(red: 1.0, green: 0.62, blue: 0.04)
            : DS.textSecondary
    }
}

struct AlcoholDetailSheet: View {
    let result: AlcoholHeuristic.Result
    let date: Date
    let confirmed: Bool?
    let onConfirm: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.verdict == .likely ? "Looks like a drinking night" : "Possibly a drinking night")
                            .font(.title3.bold())
                            .foregroundStyle(DS.textPrimary)
                        Text("Alcohol keeps your heart rate high all night and flattens HRV and deep sleep. Compared with your weekday baseline:")
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(result.reasons, id: \.self) { reason in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.04))
                                Text(reason)
                                    .font(.footnote.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(DS.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 14)
                    .dsCard(14)

                    Text("Was that right? Your answer tags the night and sharpens the detector.")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)

                    HStack(spacing: 12) {
                        Button {
                            onConfirm(true); dismiss()
                        } label: {
                            Text("Yes, I drank")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(confirmed == true ? DS.purple : DS.purpleDim)

                        Button {
                            onConfirm(false); dismiss()
                        } label: {
                            Text("No")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(confirmed == false ? DS.purple : DS.textSecondary)
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseButton() } }
        }
        .presentationDetents([.medium])
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }
}
