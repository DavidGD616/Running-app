# Plan: ActiveRunScreen Real GPS Tracking

**Generated**: 2026-04-25  
**Estimated Complexity**: High  
**Primary Target**: `apps/mobile/lib/features/active_run/**`

## Overview

Replace the simulated `ActiveRunScreen` timer/distance model with real phone GPS tracking using `geolocator`. The app should record real distance, route points, pace, splits, pause/resume state, and completed run summaries locally before any Strava, HealthKit, Health Connect, or watch integration is added.

The main architecture change is to move run behavior out of `ActiveRunScreen`. The screen becomes a renderer. A new `ActiveRunController` owns the run state, listens to GPS, advances workout blocks, persists active snapshots, and finishes the run.

## Fixed Decisions

- **Source of truth**: Dart controller state is authoritative. Native live activity and Android notification display that state only.
- **GPS library**: `geolocator`.
- **Storage**: `SharedPreferences` for active summary restore only; `sqflite` for route points, splits, and completed runs.
- **Android background**: use `geolocator` foreground location service for GPS. Existing live activity/background service remains passive display and must not compute authoritative distance.
- **iOS background**: use background location during an active, user-started run only. Request `whileInUse`; do not request `always` in v1.
- **Timer-only mode**: allowed only for duration-only workouts. Workouts with distance-based blocks require GPS.
- **Strava**: out of scope for this implementation. Add export later after local recording works.

## Prerequisites

- Keep dependencies: `geolocator`, `sqflite`, `path`.
- Add dev dependency for DB tests: `sqflite_common_ffi`.
- Native config must include:
  - Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, and geolocator service `foregroundServiceType="location"`.
  - iOS: location usage strings and `UIBackgroundModes` containing `location`.
- Use official docs as implementation references:
  - `geolocator`: platform `LocationSettings`, `AndroidSettings`, `AppleSettings`, foreground notification config, and `getPositionStream`.
  - `sqflite`: `openDatabase`, `onCreate`, `onUpgrade`, transactions, and batch inserts.

## Sprint 1: Normalize Foundation

**Goal**: Make the partially added GPS foundation correct, localized, and safe before wiring real tracking.

**Demo/Validation**
- `flutter analyze` clean.
- `flutter test test/features/active_run/data/location_permission_service_test.dart` passes.
- Pre-run permission dialogs navigate correctly.

### Task 1.1: Verify Dependencies and Native Config
- **Location**: `apps/mobile/pubspec.yaml`, Android manifest, iOS `Info.plist`
- **Description**:
  - Confirm `geolocator`, `sqflite`, and `path` are dependencies.
  - Add `sqflite_common_ffi` to dev dependencies.
  - Confirm Android and iOS location config matches prerequisites.
- **Acceptance Criteria**:
  - App builds past manifest/plist validation.
  - No duplicate or malformed permission entries.
- **Validation**: `flutter analyze`; `flutter build apk --debug` if time allows.
- **Status**: Complete
- **Work Log**:
  - Added `geolocator: ^14.0.0`, `sqflite: ^2.4.2`, `path: ^1.9.0` to dependencies.
  - Added `sqflite_common_ffi: ^2.3.4+4` to dev_dependencies.
  - Android: Added `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK` permissions.
  - Android: Added `com.baseflow.geolocator.GeolocatorLocationService` with `foregroundServiceType="location"`.
  - iOS: Added `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription`.
  - iOS: Added `location` to `UIBackgroundModes`.
  - `flutter pub get` and `flutter analyze` passed.

### Task 1.2: Complete GPS Localization
- **Location**: `apps/mobile/lib/l10n/app_en.arb`, `app_es.arb`
- **Description**: Add missing strings:
  - GPS tracking notification title/body.
  - GPS required title/body for distance-based workouts.
  - Wait for signal.
  - End run.
  - Timer-only status label.
- **Acceptance Criteria**:
  - All new visible GPS text comes from ARB.
  - Generated localization files include the new keys.
- **Validation**: `flutter gen-l10n`; `flutter analyze`.
- **Status**: COMPLETE (2026-04-25)
- **Work Log**: Added 7 new localization keys: `activeRunGpsTrackingNotificationTitle`, `activeRunGpsTrackingNotificationBody`, `gpsRequiredTitle`, `gpsRequiredBody`, `gpsWaitForSignal`, `activeRunEndRun`, `activeRunTimerOnlyLabel` to both EN and ES ARB files.

### Task 1.3: Fix Pre-run Permission Actions
- **Location**: `features/pre_run/presentation/screens/pre_run_screen.dart`
- **Description**:
  - "Open Settings" must call `openAppSettings`.
  - "Enable Location Services" must call `openLocationSettings`.
  - Before allowing timer-only, build `ActiveRunTimeline.fromSession(session)` and block timer-only if any block has `distanceMeters`.
- **Acceptance Criteria**:
  - GPS-denied duration-only run can enter timer-only mode.
  - GPS-denied distance-block workout shows GPS-required dialog and does not start.
- **Validation**: widget tests for granted, denied, service disabled, and distance-block denied paths.
- **Status**: COMPLETE (2026-04-25)
- **Work Log**: Added injectable permission checking logic to `_onContinue()` in `pre_run_screen.dart` via `LocationPermissionService`. Added `_sessionHasDistanceBlocks()` using `ActiveRunTimeline.fromSession()`. Duration-only runs request GPS first and fall back to timer-only when GPS is unavailable or denied. Distance-block workouts require GPS and show the GPS-required path instead of starting timer-only. Added localization keys for permission dialog buttons and titles.

## Sprint 2: Core GPS Recording Services

**Goal**: Add testable GPS primitives independent of the UI.

**Demo/Validation**
- Unit tests prove GPS filtering, distance accumulation, and pace smoothing.
- A temporary debug subscription can emit GPS points on device.

### Task 2.1: Add Canonical GPS Point Model
- **Location**: `features/active_run/domain/models/run_track_point.dart`
- **Description**: Create immutable `RunTrackPoint` with latitude, longitude, timestamp, accuracy, altitude, speed, heading, and source fields. Convert from `Position`.
- **Acceptance Criteria**:
  - Domain/controller code does not persist raw `Position`.
  - JSON/DB mapping uses canonical numeric fields.
- **Validation**: model round-trip test.

### Task 2.2: Add `RunLocationTracker`
- **Location**: `features/active_run/data/run_location_tracker.dart`
- **Description**:
  - Define interface with `Stream<RunTrackPoint> get points`, `start()`, `stop()`.
  - Implement `GeolocatorRunLocationTracker`.
  - Android settings: high accuracy, 5m distance filter, 1s interval, foreground notification, wake lock, ongoing notification.
  - iOS settings: best/high accuracy, 5m distance filter, `ActivityType.fitness`, `allowBackgroundLocationUpdates: true`, `pauseLocationUpdatesAutomatically: false`, `showBackgroundLocationIndicator: true`.
- **Acceptance Criteria**:
  - Tracker starts once, stops cleanly, and exposes a broadcast stream.
  - Positions over 60m accuracy are ignored.
- **Validation**: fake stream unit tests for start, stop, duplicate start, filtering.

### Task 2.3: Add GPS Quality State
- **Location**: `features/active_run/domain/models/gps_state.dart`
- **Description**:
  - `GpsStatus`: `acquiring`, `ready`, `weak`, `lost`, `disabled`.
  - Ready <= 30m, weak 30-60m, lost after no accepted fix for 10s.
  - Store last fix and last status change timestamp.
- **Acceptance Criteria**:
  - GPS status can be computed without widget code.
- **Validation**: unit tests for all transitions.

### Task 2.4: Add Distance and Pace Calculators
- **Location**: `features/active_run/data/distance_accumulator.dart`, `pace_smoother.dart`
- **Description**:
  - Accumulate distance with Haversine or `Geolocator.distanceBetween`.
  - Reject deltas under 2m and movement over 50 m/s.
  - Pace smoother uses last 5 valid points and returns `null` until enough data exists.
  - Clamp display pace later, not raw calculations.
- **Acceptance Criteria**:
  - Calculators are pure/testable and resettable.
- **Validation**: unit tests for straight movement, jitter, teleport, stop, reset, and steady pace.

## Sprint 3: Active Run Controller

**Goal**: Move run state and tracking behavior out of `ActiveRunScreen`.

**Demo/Validation**
- Controller tests can run a fake 400m workout without rendering widgets.
- Existing screen still opens with controller-backed values.

### Task 3.1: Define Controller State and Input
- **Location**: `features/active_run/presentation/active_run_controller.dart`
- **Description**:
  - Add `ActiveRunStartInput(session, checkIn, timerOnlyMode)`.
  - Add immutable `ActiveRunState` with session, elapsed, distanceKm, currentPaceSecondsPerKm, averagePaceSecondsPerKm, gpsStatus, currentBlock, nextBlock, blockElapsed, blockDistanceKm, timelineIndex, isPaused, isSurging, routePointCount, splits, and error/modal intent.
- **Acceptance Criteria**:
  - `ActiveRunState.initial` supports restored active progress with no route args.
- **Validation**: state construction tests.

### Task 3.2: Implement `ActiveRunController`
- **Location**: same controller file
- **Description**:
  - Riverpod notifier owns timer and GPS subscription.
  - `start(input)` loads session/check-in from args or `activeRunSessionProvider`.
  - On timer tick, update elapsed and duration-based block progress.
  - On GPS point, update distance, block distance, current pace, average pace, GPS status, route buffer, splits, and timeline.
  - `pause()` freezes elapsed and pauses GPS contribution.
  - `resume()` restarts elapsed and resets last accepted point to avoid jump.
  - `finish()` stops timer/GPS and returns finish payload.
- **Acceptance Criteria**:
  - No mock distance math remains in controller.
  - GPS updates ignored while paused.
  - Distance-based blocks advance from GPS distance only.
- **Validation**: fake GPS/timer unit tests.

### Task 3.3: Extend Active Progress Snapshot
- **Location**: `active_run_progress_provider.dart`
- **Description**: Add fields for runId, timerOnlyMode, startedAtMs, currentPaceSecondsPerKm, gpsStatus, lastAcceptedPoint, and splits summary. Keep old JSON migration defaults.
- **Acceptance Criteria**:
  - Old `active_run_progress_v1` data does not crash restore.
  - Active run restore has enough data to resume distance without jump.
- **Validation**: serialization and migration tests.

### Task 3.4: Refactor `ActiveRunScreen` to Render Controller
- **Location**: `features/active_run/presentation/screens/active_run_screen.dart`
- **Description**:
  - Remove `_kmPerSecond`, `_paceMultiplier`, fake distance increments, native `getRunState` distance adoption, and local tracking timers.
  - In `initState`, call controller `start`.
  - Buttons call controller `pause`, `resume`, and `finish`.
  - Lifecycle callback forwards app state to controller.
  - UI still uses existing cards/focus panel.
- **Acceptance Criteria**:
  - Screen contains formatting and layout only, not GPS math.
  - Live activity payload uses controller state.
- **Validation**: widget smoke test and `flutter analyze`.

## Sprint 4: Local Run Persistence

**Goal**: Persist active and completed runs with route points and splits.

**Demo/Validation**
- Finish a short fake run; DB has one completed run, route points, and splits.
- Reopen app mid-run; summary and last point restore.

### Task 4.1: Add Run Database
- **Location**: `core/persistence/run_database.dart`
- **Description**:
  - Create DB version 1 with foreign keys enabled.
  - Tables:
    - `runs(id TEXT PRIMARY KEY, status TEXT, started_at_ms INTEGER, ended_at_ms INTEGER NULL, duration_ms INTEGER, distance_km REAL, session_id TEXT NULL, session_type TEXT, timer_only INTEGER, source TEXT)`
    - `run_route_points(run_id TEXT, idx INTEGER, lat REAL, lng REAL, accuracy REAL, altitude REAL NULL, speed REAL NULL, heading REAL NULL, ts_ms INTEGER, PRIMARY KEY(run_id, idx))`
    - `run_splits(run_id TEXT, idx INTEGER, boundary_meters INTEGER, started_at_ms INTEGER, ended_at_ms INTEGER, duration_ms INTEGER, pace_seconds_per_km REAL, PRIMARY KEY(run_id, idx))`
- **Acceptance Criteria**:
  - `onCreate` creates all tables.
  - `onUpgrade` is present for future migrations.
- **Validation**: `sqflite_common_ffi` tests.

### Task 4.2: Add `RunRepository`
- **Location**: `features/active_run/data/run_repository.dart`
- **Description**:
  - CRUD for active/completed runs.
  - Batch insert route points every 25 accepted points and on finish.
  - Insert/update run summary in a transaction.
  - Store canonical session type key, not localized text.
- **Acceptance Criteria**:
  - Completed run, route, and splits round-trip.
  - Deleting a run deletes route/splits.
- **Validation**: repository unit tests.

### Task 4.3: Persist During Active Run
- **Location**: controller and repository
- **Description**:
  - Generate `runId` at start.
  - Insert `runs(status='active')` at start.
  - Save active progress summary every 5s and on background.
  - Flush route points in batches of 25 and on pause/background/finish.
- **Acceptance Criteria**:
  - A 2-hour run does not hold all route points only in memory.
  - Cold restore can load active run by `runId`.
- **Validation**: fake long-run test and manual cold-kill test.

### Task 4.4: Finish Flow and Log Run
- **Location**: `run_flow_context.dart`, `log_run_screen.dart`
- **Description**:
  - Extend `LogRunArgs` with `runId`.
  - Controller `finish()` updates `runs(status='completed')`, writes final splits, clears active session/progress, and returns `LogRunArgs`.
  - `LogRunScreen` reads DB by `runId`; fallback to old args stays.
- **Acceptance Criteria**:
  - Log screen displays real duration, distance, average pace, and splits from DB.
- **Validation**: widget test with fake repository.

## Sprint 5: GPS Failure UX and Timer-only UX

**Goal**: Make degraded states explicit and safe.

**Demo/Validation**
- Acquiring/weak/lost states render clearly.
- Lost GPS pauses distance-based blocks but not duration-only blocks.

### Task 5.1: GPS Status UI
- **Location**: `active_run_screen.dart`
- **Description**:
  - `acquiring`: hero pace shows localized acquiring text and distance stays stable.
  - `weak`: show warning chip, continue tracking.
  - `lost`: show lost state.
  - `timerOnlyMode`: show timer-only label; pace is `--:--`; distance remains 0.
- **Acceptance Criteria**:
  - No hardcoded visible strings.
- **Validation**: widget tests for each status.

### Task 5.2: GPS Lost During Blocks
- **Location**: controller and screen
- **Description**:
  - If GPS becomes lost during a distance-based block, auto-pause and show non-dismissible modal with wait/end options.
  - If GPS becomes lost during a duration-based block, timer continues, distance freezes, and a dismissible warning appears.
  - When GPS recovers after auto-pause, do not auto-resume.
- **Acceptance Criteria**:
  - No duplicate modals.
  - Resume requires user action.
- **Validation**: fake GPS tests and manual airplane-mode/location-off test.

### Task 5.3: Timer-only Restrictions
- **Location**: pre-run gate and controller
- **Description**:
  - Pre-run blocks timer-only for any session with distance-based blocks.
  - Controller asserts the same rule and emits a user-visible error if called incorrectly.
- **Acceptance Criteria**:
  - Bad navigation cannot start a distance workout without GPS.
- **Validation**: unit and widget tests.

## Sprint 6: Cleanup, Device Validation, Docs

**Goal**: Remove mock behavior, verify on real devices, and update project docs.

**Demo/Validation**
- 20-30 minute outdoor run works on iOS and Android.
- `flutter analyze` and `flutter test` pass.

### Task 6.1: Remove Dead Mock Code
- **Location**: `active_run_screen.dart`, native bridge usage
- **Description**:
  - Delete mock pace/distance branches.
  - Keep `_isWorkBlock` only if focus UI needs it from current timeline block.
  - Ignore native service distance snapshots; native only mirrors controller state.
- **Acceptance Criteria**:
  - No simulated distance changes in non-timer-only GPS mode.
- **Validation**: code search for old mock helpers and tests.

### Task 6.2: Full Test Pass
- **Location**: `apps/mobile/test/features/active_run/**`
- **Description**:
  - Add fake tracker, fake repository, and fake time source.
  - Cover happy path, pause/resume, finish, cold restore, GPS lost, timer-only, and DB persistence.
- **Acceptance Criteria**:
  - Existing tests still pass.
  - New controller/repository/calculator logic has focused coverage.
- **Validation**: `flutter test`; `flutter analyze`.

### Task 6.3: Manual Device Field Test
- **Location**: physical iOS and Android devices
- **Description**:
  - Outdoor 200m short walk.
  - 20-30 minute run/walk.
  - Background app for 5 minutes during active run.
  - Kill/reopen mid-run.
  - Disable location mid-distance-block.
- **Acceptance Criteria**:
  - Distance within roughly 3-5 percent of known route.
  - Battery drain acceptable for active GPS tracking.
  - No crash when permissions change.
- **Validation**: manual checklist saved in PR notes.

### Task 6.4: Update Docs
- **Location**: `docs/data-models.md`, `docs/dynamic-data-local-persistence-plan.md`
- **Description**:
  - Document `runs`, `run_route_points`, and `run_splits`.
  - Mark previous active-run mock tracking as deprecated.
  - State that Strava export is post-local-recording work.
- **Acceptance Criteria**:
  - Docs match implemented DB and behavior.
- **Validation**: review.

## Testing Strategy

- Run from `apps/mobile/`.
- Required automated checks:
  - `flutter gen-l10n` after ARB edits.
  - `flutter analyze`.
  - `flutter test`.
  - Targeted tests for active run services, controller, repository, and pre-run gate.
- Required manual checks:
  - Android physical device GPS/background.
  - iOS physical device GPS/background.
  - Permission denial and service-disabled flows.
  - Cold-start active run restore.

## Risks and Mitigations

- **Two Android persistent notifications**: keep GPS notification for location service; existing live notification must be passive and can be consolidated later.
- **GPS noise**: accuracy filter, jitter rejection, teleport rejection, and pace smoothing are mandatory.
- **iOS review scrutiny**: usage copy must explain active run tracking only; no `always` permission in v1.
- **SharedPreferences size**: never store route arrays there.
- **Controller complexity**: keep calculators pure and independently tested.
- **Localization regressions**: no visible English/Spanish strings in feature code outside ARB files.

## Rollback Plan

- Force pre-run to use `timerOnlyMode` for duration-only sessions if GPS path fails.
- Since DB changes are additive, rollback by hiding GPS entry points and leaving unused tables.
- Keep old `LogRunScreen` fallback so finished-session logging still works without `runId`.
