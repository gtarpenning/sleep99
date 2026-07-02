# SleepTune Widget

This directory holds the Home Screen widget code. It is **not yet wired into the
Xcode project** — the widget runs in its own extension target which has to be
created via Xcode's UI (not via `pbxproj` editing).

## To enable it

1. In Xcode: File → New → Target → **Widget Extension**.
   - Product Name: `SleepTuneWidget`
   - Include Configuration Intent: **off**
   - Embed in Application: `SleepTune`

2. When Xcode generates the new target's boilerplate, **delete** the auto-generated
   `SleepTuneWidget.swift` and **add** `ScoreWidget.swift` from this directory.

3. Capabilities (both the main app target AND the widget extension):
   - Add **App Groups** capability.
   - Use identifier: `group.com.sleep-tune.app`.

4. Update `WidgetSnapshotStore.appGroupIdentifier` in the main app to match.

The main app already writes a `WidgetSnapshot` whenever `recalculateScore()` runs
for today's date — once the App Group is configured, the widget will pick it up
automatically.
