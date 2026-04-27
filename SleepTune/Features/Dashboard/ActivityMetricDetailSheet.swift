import SwiftUI

struct ActivityMetricDetailSheet: View {
    let item: ActivityMetricItem
    let snapshot: DailyActivitySnapshot?
    let activityMonthlyStats: [String: MetricStats]
    @State private var selectedDetent: PresentationDetent = .fraction(0.75)

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        if let stats = activityMonthlyStats[item.id] {
                            statsSection(stats)
                        }
                        if item.id == "workouts", let snap = snapshot, !snap.workouts.isEmpty {
                            workoutsSection(snap.workouts)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle(item.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
        }
        .presentationDetents([.fraction(0.75), .large], selection: $selectedDetent)
        .presentationBackground(DS.bg)
        .presentationCornerRadius(28)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            Text(item.formattedValue)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()

            Text(item.unit)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.textSecondary)

            if let detail = item.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .dsCard(20)
    }

    // MARK: - 30-day stats

    private func statsSection(_ stats: MetricStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30-Day Range")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            HStack(spacing: 8) {
                StatPill(label: "Low",  value: stats.min, item: item)
                StatPill(label: "Avg",  value: stats.avg, item: item)
                StatPill(label: "High", value: stats.max, item: item)
            }
        }
    }

    // MARK: - Workouts list

    private func workoutsSection(_ workouts: [WorkoutSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)

            VStack(spacing: 2) {
                ForEach(workouts) { workout in
                    WorkoutRow(workout: workout)
                }
            }
            .dsCard(16)
        }
    }
}

// MARK: - WorkoutRow

private struct WorkoutRow: View {
    let workout: WorkoutSummary

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(Self.timeFmt.string(from: workout.startDate))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                if let cal = workout.activeCalories {
                    Text("\(Int(cal.rounded())) kcal")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var durationLabel: String {
        let m = Int(workout.durationMinutes.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
    }
}

// MARK: - StatPill

private struct StatPill: View {
    let label: String
    let value: Double
    let item: ActivityMetricItem

    private var formatted: String {
        // Reuse the same formatting logic as ActivityMetricItem
        let tmp = ActivityMetricItem(id: item.id, label: label, value: value, unit: item.unit, icon: item.icon)
        return tmp.formattedValue
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(formatted)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .dsCard(12)
    }
}
