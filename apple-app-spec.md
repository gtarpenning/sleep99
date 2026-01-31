# Sleep-Tune iOS App Spec (Apple Health sync)

## Product vision
A personalized sleep score, synced from Apple Health, with clear explanations and experiments that improve it.

## Core goals
- One-tap HealthKit sync (read sleep + supporting signals)
- Transparent, customizable sleep score
- Lightweight habit experiments + trend tracking

## MVP scope
- HealthKit read permissions
- Nightly sleep score (last night + 7/30-day trend)
- Factors breakdown (what moved the score)
- Personalization settings (weighting + goals)

## Key user flows
- Onboarding: value prop → HealthKit permissions → baseline setup (goals, schedule, sensitivity)
- Daily: open app → last night’s score + drivers → quick recommendation
- Weekly: trend view + “sleep experiment” check-in

## HealthKit integration
- Read data types (as available):
  - SleepAnalysis (required)
  - Resting Heart Rate, HRV
  - Respiratory Rate (optional)
  - Workouts / Activity (optional context)
- Sync model:
  - Initial backfill (e.g., 90 days)
  - Daily background refresh (HKObserverQuery + HKAnchoredObjectQuery)
  - Local caching for speed

## Scoring model (initial)
- Components: duration, efficiency, consistency, deep/REM %, wake after sleep onset, HR/HRV recovery
- Score formula: weighted sum with penalties for irregularity + short sleep
- Personalization: user-tunable weights or preset profiles (e.g., “Recovery focus”, “Consistency focus”)

## Features (post-MVP)
- Experiments: “7-day earlier bedtime” with before/after score delta
- Notifications: “New sleep score ready” and “consistency streak.”
- Tags/journaling: caffeine, alcohol, exercise (manual)
- Shareable report

## Tech architecture (iOS-first)
- iOS native (Swift + SwiftUI)
- HealthKit sync engine:
  - Persistent anchor storage
  - Daily background fetch
- Local store: SQLite/Core Data for aggregates
- Optional account layer (Phase 2):
  - Cloud sync (if user wants multi-device) — store aggregates only

## Privacy
- Default local-only processing
- Clear permission UI + “why we need this” copy
- No data leaves device unless user opts in

## Screens
- Welcome + permission
- Sleep Score dashboard
- Factors breakdown
- Trends
- Personalization/weights
- Experiments
