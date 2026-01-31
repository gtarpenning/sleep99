# Background Analytics Sync Scaffolding

This document outlines a minimal, resilient analytics sync ecosystem for SleepTune. The goal is to keep the app fully functional offline, queue events locally, and sync opportunistically without user interruption.

## On-device data flow

1. App emits `AnalyticsEvent` entries as users interact with core features.
2. Events are appended to a local, file-backed queue (`FileAnalyticsEventStore`).
3. `SyncCoordinator` batches queued events and sends them when policy allows.
4. Sync attempts are silent; failures do not surface to the UI and events remain queued.

## Reliability and interruption handling

- Events are persisted on device in a JSON file in the Documents directory.
- The queue is append-first; only successful uploads remove records.
- Failed uploads increment attempt metadata and back off based on policy.
- If the app is killed mid-flight, the queue persists and resumes next launch.

## Sync policy defaults (tunable)

- Minimum interval: 15 minutes.
- Batch size: 50 events.
- Retry delays: 30s, 2m, 5m, 15m, 60m.

## Background execution

The `SyncCoordinator.scheduleBackgroundSync()` entry point is the hook for background task registration. The current implementation is a no-op to keep the scaffold minimal. When we wire it up, we will:

- Register an app refresh task identifier in the app target.
- Schedule background refresh on app launch and after successful sync.
- Perform a best-effort sync inside the background task, ending early on expiration.

## Server-side minimal spec

### Ingestion API

- `POST /v1/analytics/batch`
- Accept JSON payload matching `AnalyticsBatch`.
- Validate schema and drop or quarantine unknown payloads.
- Return 2xx on acceptance (even if queued for later processing).

### Processing

- Append batches into a durable store (Postgres on Fly).
- Optionally push into a queue for aggregation.
- Aggregate into daily or hourly rollups to power the admin dashboard.

### Admin dashboard

- Minimal authenticated UI that shows event counts, error rates, and latest ingestion time.
- Keep the UI read-only for now; no destructive controls.

## Fly.io deployment sketch

- One app for the API server and one Postgres cluster.
- Use environment variables for auth secrets and allowlists.
- Add a health check route (`GET /healthz`) for Fly to monitor.

## Next steps

- Wire background tasks and register identifiers in the app target.
- Add event capture points in the UI and model layer.
- Implement a minimal ingestion server and a basic dashboard view.
- Expand the queue to support payload compression or encryption if needed.
