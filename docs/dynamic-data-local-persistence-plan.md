# Dynamic Data & Local Persistence Plan

## Overview

This document describes the local persistence strategy for dynamic run data, including active runs, completed runs, GPS route points, and splits. It supersedes any earlier mock-tracking or SharedPreferences-only approaches.

---

## Scope

- Persisting active run state during GPS tracking sessions
- Storing completed run summaries with route and split data
- Supporting mid-run app kills and resume without data loss
- **Out of scope**: Strava export, HealthKit/Health Connect sync, watch integration

---

## Storage Boundaries

| Data type | Storage |
| --- | --- |
| Active run summary (id, elapsed, distance) | `SharedPreferences` via `activeRunProgressProvider` |
| Completed run records | `sqflite` (`runflow_runs.db`) |
| GPS route points | `sqflite` (`run_route_points` table) |
| Run splits | `sqflite` (`run_splits` table) |
| Onboarding/profile data | `SharedPreferences` (versioned JSON) |
| User preferences | `SharedPreferences` |

> **Note**: Route points and splits are never stored in `SharedPreferences`. They are always persisted to `sqflite` to avoid size limits and enable structured queries.

---

## SQLite Database Schema

**Database**: `runflow_runs.db` (version 1)
**Foreign keys**: Enabled via `PRAGMA foreign_keys = ON`

### `runs` table

```sql
CREATE TABLE runs (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL,           -- 'active' or 'completed'
  started_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER,            -- NULL until run finishes
  duration_ms INTEGER,           -- accumulated time in ms
  distance_km REAL,               -- accumulated GPS distance in km
  session_id TEXT,                -- linked TrainingSession.id
  session_type TEXT,              -- canonical key (e.g. 'easy', 'tempo')
  timer_only INTEGER NOT NULL DEFAULT 0,  -- 1 if GPS unavailable
  source TEXT                     -- optional source identifier
);
```

### `run_route_points` table

```sql
CREATE TABLE run_route_points (
  run_id TEXT NOT NULL,
  idx INTEGER NOT NULL,            -- sequential index within the run
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  accuracy REAL NOT NULL,         -- meters; >60m points are rejected
  altitude REAL,
  speed REAL,
  heading REAL,
  ts_ms INTEGER NOT NULL,
  PRIMARY KEY (run_id, idx),
  FOREIGN KEY (run_id) REFERENCES runs (id) ON DELETE CASCADE
);
```

### `run_splits` table

```sql
CREATE TABLE run_splits (
  run_id TEXT NOT NULL,
  idx INTEGER NOT NULL,
  boundary_meters INTEGER NOT NULL,  -- e.g. 1000 for km splits
  started_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  pace_seconds_per_km REAL NOT NULL,
  PRIMARY KEY (run_id, idx),
  FOREIGN KEY (run_id) REFERENCES runs (id) ON DELETE CASCADE
);
```

---

## Active Run Persistence Strategy

1. **Run start**: Generate a UUID `runId`, insert `runs(status='active')` row.
2. **During run**: Update `runs.duration_ms` and `runs.distance_km` every ~5 seconds and on app background via `updateActiveRunSummary`.
3. **GPS fixes**: Batch-insert every 25 accepted fixes via `flushPendingRoutePoints`. Also flush on pause, background, and finish.
4. **Run finish**: Transactionally update `runs(status='completed')`, insert final route points, and insert all splits via `finishRun`.

### Cold restore

On app reopen mid-run:
1. Query `runs(status='active')` for any existing active run.
2. If found, restore `activeRunProgressProvider` from the run summary (runId, startedAt, sessionId, timerOnlyMode).
3. Resume GPS subscription; the controller re-derives distance from the last accepted point to avoid jumps.

---

## Deprecated: Mock Tracking

Previous active-run implementations used simulated timer-based distance increments and placeholder `getRunState` native bridge calls. These have been **removed**:

- No simulated distance math in `ActiveRunController` (GPS mode)
- No mock pace/distance branches in `ActiveRunScreen`
- Native live activity/background service is passive and mirrors controller state only

Timer-only mode remains valid for duration-only workouts when GPS is denied, but it does not use mock distance tracking.

---

## Future: Strava Export

Strava upload is **post-local-recording work**. It will be addressed after:

1. Core GPS recording loop is validated on physical iOS and Android devices
2. Run finish flow end-to-end is stable (start → GPS tracking → pause/resume → finish → log screen)
3. Database round-trips for route points and splits are tested

The export pipeline will be a separate feature layer on top of `RunRepository.getCompletedRun`.

---

## Key Classes

| Class | File | Role |
| --- | --- | --- |
| `RunDatabase` | `core/persistence/run_database.dart` | Opens `runflow_runs.db`, runs migrations |
| `RunRepository` | `features/active_run/data/run_repository.dart` | All run/splits/route CRUD |
| `ActiveRunController` | `features/active_run/presentation/active_run_controller.dart` | Owns active run state and GPS subscription |
| `ActiveRunProgressNotifier` | `features/active_run/presentation/active_run_progress_provider.dart` | SharedPreferences snapshot for mid-run restore |