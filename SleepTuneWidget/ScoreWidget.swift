import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model
//
// Mirrors `WidgetSnapshotStore` in the main app. Both the app and this widget
// extension read/write the same UserDefaults suite (App Group). When you create
// the widget extension target in Xcode:
//   1. Add the App Group capability to BOTH the main app target and this extension
//      with identifier `group.com.sleep-tune.app`.
//   2. Add this Swift file to the extension target only — leave the matching
//      `WidgetSnapshotStore.swift` in the main app target.

struct WidgetSnapshot: Codable, Equatable {
    let updatedAt: Date
    let score: Double
    let sleepScore: Double
    let recoveryScore: Double
    let totalSleepMinutes: Int
}

private enum SharedStore {
    static let appGroup = "group.com.sleep-tune.app"
    static let key = "widgetSnapshot.v1"

    static func load() -> WidgetSnapshot? {
        let defaults = UserDefaults(suiteName: appGroup) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - Timeline

struct ScoreEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoreEntry {
        ScoreEntry(date: Date(), snapshot: WidgetSnapshot(updatedAt: Date(), score: 78, sleepScore: 76, recoveryScore: 81, totalSleepMinutes: 435))
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(ScoreEntry(date: Date(), snapshot: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        let entry = ScoreEntry(date: Date(), snapshot: SharedStore.load())
        // Refresh hourly — the data only changes once per day after morning sync.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ScoreWidgetEntryView: View {
    var entry: ScoreProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sleep")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let s = entry.snapshot {
                Text("\(Int(s.score.rounded()))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(s.score))
                Text(sleepLabel(minutes: s.totalSleepMinutes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Open SleepTune")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.black }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let s = entry.snapshot {
                    Text("\(Int(s.score.rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(s.score))
                    Text(sleepLabel(minutes: s.totalSleepMinutes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
            }
            Spacer(minLength: 0)
            if let s = entry.snapshot {
                VStack(alignment: .trailing, spacing: 8) {
                    miniMetric(label: "Sleep",  value: s.sleepScore)
                    miniMetric(label: "Recover", value: s.recoveryScore)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Color.black }
    }

    private func miniMetric(label: String, value: Double) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(Int(value.rounded()))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(value))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func sleepLabel(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func scoreColor(_ v: Double) -> Color {
        switch v {
        case ..<55:     return .red.opacity(0.85)
        case ..<70:     return .orange
        case ..<85:     return .yellow
        default:        return .green
        }
    }
}

// MARK: - Widget definition

struct ScoreWidget: Widget {
    let kind: String = "ScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScoreProvider()) { entry in
            ScoreWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sleep Score")
        .description("Your latest sleep and recovery scores.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SleepTuneWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScoreWidget()
    }
}
