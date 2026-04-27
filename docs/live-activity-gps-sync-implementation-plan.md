# Plan: GPS-Backed Live Activity Sync

**Generated**: 2026-04-26  
**Estimated Complexity**: High  
**Primary App Area**: `apps/mobile/lib/features/active_run/`  
**Native Areas**: `apps/mobile/android/app/src/main/kotlin/com/example/running_app/`, `apps/mobile/ios/Runner/`

## Overview

Restore iOS Live Activities and the Android active-run foreground notification so they show the same run data as `ActiveRunScreen`.

The implementation must make `ActiveRunController` the only authority for elapsed time, distance, pace, average pace, pause state, workout block progress, and finish state. Native live surfaces must only render the latest Flutter payload. The only value native should continue ticking visually is elapsed time, using the elapsed seed from Flutter and native timer/chronometer support.

Chosen behavior:

- Elapsed time must visually match the active run screen.
- Distance, current pace, average pace, block labels, and progress update immediately on important state changes.
- Distance and pace refresh every 3 seconds during normal running to avoid excessive native update churn.
- Native surfaces must never invent distance from pace.
- Geolocator remains responsible for GPS tracking and background location behavior.
- The custom Android run notification remains separate from Geolocator's foreground location service.

## Context7 Notes Used

- Riverpod docs: `ref.listen` is valid inside `build`; `ref.listenManual` is the lifecycle-safe option for `initState` side effects and should be stored/disposed through the widget lifecycle.
- `flutter_background_service` docs: configure the service once, use explicit service events for updates, and keep Android foreground service types/manifest entries aligned with what the service actually does.
- Geolocator docs: `getPositionStream` should use platform-specific settings; Android background GPS is handled through Geolocator foreground notification settings and Android foreground-service location permissions; iOS background GPS requires location background mode if true background tracking is expected.

## Current State

- `ActiveRunScreen` owns `_bridge = RunLiveActivityBridge.instance` and `_backgroundService = RunLiveActivityBackgroundService.instance`.
- `ActiveRunScreen` currently ends live surfaces in `_finishRun()` and finished `dispose()`.
- `ActiveRunScreen` does not currently call:
  - `_bridge.startActivity(...)`
  - `_bridge.updateActivity(...)`
  - `_backgroundService.start(...)`
  - `_backgroundService.update(...)`
- `RunLiveActivityData` still contains all major display fields needed by iOS and Android.
- `RunLiveActivityData` comments still describe old behavior where Android ticks distance from pace.
- Android `RunForegroundService` currently:
  - Seeds `serviceDistanceKm` and `serviceElapsedMs`.
  - Increments distance every second from `paceSecondsPerKm`.
  - Computes average pace from service-owned distance/time.
  - Advances timeline blocks natively.
  - Exposes `snapshotState()` as if native service can be authoritative.
- iOS `RunLiveActivityManager` already maps payload fields to `RunActivityAttributes.ContentState`.
- Android `MainActivity` already forwards method channel calls to `RunForegroundService`.
- `RunLiveActivityBackgroundService` already forwards background-service events back to `RunLiveActivityBridge`.
- Android manifest already has:
  - Geolocator foreground location service declaration.
  - Custom `RunForegroundService` declaration.

## Public Interfaces And Data Contracts

### Keep Existing Method Channel API

Do not rename these method channel calls:

- `startActivity`
- `updateActivity`
- `endActivity`
- `androidSdkInt`

`getRunState` may remain temporarily for compatibility, but the implementation must stop using it as an authoritative source for controller state.

### Keep Existing `RunLiveActivityData` Shape Unless A Field Is Clearly Missing

Use the existing fields:

- `workoutName`
- `elapsedSeconds`
- `elapsedLabel`
- `elapsedUnitLabel`
- `distanceTitleLabel`
- `distanceLabel`
- `currentPaceShortTitleLabel`
- `currentPaceTitleLabel`
- `currentPaceLabel`
- `avgPaceTitleLabel`
- `avgPaceLabel`
- `currentBlockLabel`
- `nextBlockLabel`
- `repLabel`
- `isPaused`
- `distanceKm`
- `paceSecondsPerKm`
- `unitFactor`
- `distanceUnit`
- `paceUnit`
- `plannedDistanceKm`
- `plannedDurationMs`
- `timeline`
- `blockProgressFraction`
- `plannedPaceLabel`
- `blockRemainingLabel`

No persistence migration is required.

### Required Semantic Changes

- `distanceKm` means the latest authoritative Flutter/controller distance.
- `paceSecondsPerKm` means the latest authoritative Flutter/controller current pace, useful for display fallback only.
- `timeline` is optional display metadata, not native state-machine ownership.
- `blockProgressFraction` is the authoritative progress value for the visible progress bar.
- `plannedDistanceKm` and `plannedDurationMs` may remain for fallback display, but Android should prefer `blockProgressFraction`.

## Sprint 1: Build A Testable Live Activity Payload Mapper

**Goal**: Create one Dart path that turns active-run state into `RunLiveActivityData`.

**Demo/Validation**:

- Unit tests can build payloads without rendering `ActiveRunScreen`.
- Mapper output matches active-run screen values for metric and imperial users.

### Task 1.1: Add Mapper File

- **Location**: `apps/mobile/lib/features/active_run/presentation/active_run_live_activity_mapper.dart`
- **Description**:
  - Create a mapper that receives all non-global inputs explicitly.
  - Suggested signature:

```dart
RunLiveActivityData buildRunLiveActivityData({
  required ActiveRunState state,
  required TrainingSession? session,
  required UnitSystem unitSystem,
  required AppLocalizations l10n,
})
```

- **Inputs**:
  - `ActiveRunState`
  - active session
  - unit preference
  - localization object
- **Output**:
  - `RunLiveActivityData`
- **Acceptance Criteria**:
  - No `ref.watch` or provider access inside mapper.
  - No widget `BuildContext` stored inside mapper.
  - No hardcoded user-facing English or Spanish strings.
  - Uses existing localization keys where possible.
  - Any missing visible labels are added to ARB during implementation.
- **Validation**:
  - `dart format` on touched Dart files.
  - Unit tests from Task 1.5.

### Task 1.2: Match ActiveRunScreen Metric Values

- **Location**: mapper file from Task 1.1
- **Description**:
  - Use the same display rules as `ActiveRunScreen` for:
    - total distance
    - current pace
    - average pace
    - elapsed label
    - planned pace
    - current block
    - next block
    - rep label
    - block remaining
    - block progress
- **Required Behavior**:
  - `distanceLabel` must match the active screen's selected unit.
  - `currentPaceLabel` must use the controller's current pace display logic, including unavailable/placeholder behavior.
  - `avgPaceLabel` must use elapsed and total distance from controller state.
  - `elapsedSeconds` must be `state.elapsed.inSeconds`.
  - `elapsedLabel` must be the static formatted elapsed value for paused display.
  - `isPaused` must be `state.isPaused`.
- **Acceptance Criteria**:
  - A 1.23 km run in km mode produces the same label as the active screen.
  - A 1.23 km run in mile mode produces the same converted label as the active screen.
  - A zero-distance run does not produce impossible average pace.

### Task 1.3: Map Workout Blocks From Controller State

- **Location**: mapper file from Task 1.1
- **Description**:
  - Build block fields from `state.currentBlock`, `state.nextBlock`, `state.blockElapsed`, `state.blockDistanceKm`, and session metadata.
  - Prefer current controller state over precomputed native timeline.
- **Required Behavior**:
  - Duration block progress = `state.blockElapsed / currentBlock.duration`.
  - Distance block progress = `state.blockDistanceKm / currentBlock.distanceKm`.
  - Missing target = `0.0` progress unless session target gives a meaningful fallback.
  - Clamp progress to `0.0..1.0`.
  - `blockRemainingLabel` must be time-left for duration blocks and distance-left for distance blocks.
  - `currentBlockLabel` must match current app terms for warm-up, work, recovery, stride, cool-down.
  - `nextBlockLabel` should be null when no next block exists.
- **Acceptance Criteria**:
  - Interval work/recovery blocks show correct rep label.
  - Easy-run duration-only sessions show a useful current block label.
  - Distance intervals do not use total run distance for block progress.

### Task 1.4: Decide Timeline Payload Handling

- **Location**: mapper file and `RunLiveActivityData`
- **Description**:
  - Keep `timeline` only if needed by existing native code during transition.
  - Long-term target is no native block advancement.
- **Required Behavior**:
  - Native UI should render `currentBlockLabel`, `nextBlockLabel`, `repLabel`, and `blockProgressFraction` from latest payload.
  - If `timeline` remains populated, Android must not use it to override current labels.
- **Acceptance Criteria**:
  - A controller block change immediately changes native labels on the next live update.
  - Android does not advance to a block Flutter has not entered.

### Task 1.5: Add Mapper Unit Tests

- **Location**: `apps/mobile/test/features/active_run/presentation/active_run_live_activity_mapper_test.dart`
- **Test Cases**:
  - running state maps elapsed, distance, current pace, and average pace.
  - paused state maps `isPaused = true` and stable elapsed label.
  - metric unit labels are correct.
  - imperial unit labels are correct.
  - duration block progress and remaining are correct.
  - distance block progress and remaining are correct.
  - zero distance does not produce invalid average pace.
  - no current block falls back to session/session type label.
- **Validation**:
  - `flutter test test/features/active_run/presentation/active_run_live_activity_mapper_test.dart`

## Sprint 2: Add A Live Activity Sync Coordinator In Flutter

**Goal**: Reconnect active-run state to native live surfaces with throttling and immediate lifecycle updates.

**Demo/Validation**:

- Starting a run starts live surfaces once.
- Normal distance/pace changes update every 3 seconds.
- Pause/resume/finish/block changes update immediately.

### Task 2.1: Add Testable Bridge And Service Abstractions

- **Location**:
  - `apps/mobile/lib/features/active_run/presentation/run_live_activity_bridge.dart`
  - `apps/mobile/lib/features/active_run/presentation/run_live_activity_background_service.dart`
  - optional provider file under active-run presentation
- **Description**:
  - Add lightweight interfaces or providers so widget tests can inject fake bridge/service objects.
  - Keep `RunLiveActivityBridge.instance` and `RunLiveActivityBackgroundService.instance` as production defaults.
- **Suggested Shape**:

```dart
abstract class RunLiveActivityBridgePort {
  Future<void> startActivity(RunLiveActivityData data);
  Future<void> updateActivity(RunLiveActivityData data);
  Future<void> endActivity();
}

abstract class RunLiveActivityBackgroundServicePort {
  Future<void> start(RunLiveActivityData data);
  Future<void> update(RunLiveActivityData data);
  Future<void> stop();
}
```

- **Acceptance Criteria**:
  - Production behavior remains unchanged.
  - Tests can capture start/update/end calls without platform channels.

### Task 2.2: Create Sync Coordinator

- **Location**: `apps/mobile/lib/features/active_run/presentation/active_run_live_activity_sync.dart`
- **Description**:
  - Create a small class that owns live-activity lifecycle flags and throttling.
  - It should receive bridge/service dependencies and a clock function for testing.
- **State To Track**:
  - `_started`
  - `_ended`
  - `_lastPayloadSignature`
  - `_lastUpdateAt`
  - optional `_lastTimelineIndex`
  - optional `_lastPauseState`
- **Suggested Methods**:

```dart
Future<void> sync({
  required RunLiveActivityData data,
  required ActiveRunState previous,
  required ActiveRunState next,
  required bool force,
})

Future<void> end()
```

- **Acceptance Criteria**:
  - First valid payload calls bridge start and background service start.
  - Later payloads call update only.
  - End calls both stop/end once.
  - Sync ignores calls after end.
  - Sync does not throw platform exceptions to the UI.

### Task 2.3: Implement Update Rules

- **Location**: `active_run_live_activity_sync.dart`
- **Immediate Update Triggers**:
  - first start
  - pause state changed
  - run resumed
  - timeline index changed
  - current block label changed
  - next block label changed
  - rep label changed
  - GPS/timer-only status causes a visible status label change
  - finish/end
- **Throttled Update Triggers**:
  - total distance changed
  - current pace changed
  - average pace changed
  - block progress changed without block transition
- **Throttle Rule**:
  - Send if at least 3 seconds passed since last native update.
  - Also send if distance changed by at least `0.01 km`, even if 3 seconds have not passed.
  - Also send if current pace changed by at least 10 seconds/km, even if 3 seconds have not passed.
- **Acceptance Criteria**:
  - Elapsed remains visually moving natively between payload updates.
  - Native does not receive every one-second controller tick unless a force trigger occurs.

### Task 2.4: Wire Coordinator Into ActiveRunScreen

- **Location**: `apps/mobile/lib/features/active_run/presentation/screens/active_run_screen.dart`
- **Description**:
  - Keep the current modal listener behavior.
  - Add live-activity sync from active-run provider changes.
  - Use either:
    - `ref.listen(activeRunControllerProvider, ...)` inside `build`, or
    - `ref.listenManual(...)` in `initState` with a stored `ProviderSubscription`.
  - Prefer `ref.listen` inside `build` if implementation stays simple and mirrors current modal listener.
- **Required Behavior**:
  - On every relevant controller change, build `RunLiveActivityData` through the mapper.
  - Do not start live activity before session/l10n/unit data are available.
  - End live surfaces in `_finishRun()` through coordinator.
  - Keep finished `dispose()` cleanup as a safety net.
  - Do not call `getRunState()` to restore controller state.
- **Acceptance Criteria**:
  - No `ref.listen` in `initState`.
  - No duplicate live activity starts.
  - No end call when user simply navigates back without finishing unless current route behavior already ends run.

### Task 2.5: Add Widget/Coordinator Tests

- **Location**:
  - `apps/mobile/test/features/active_run/presentation/active_run_live_activity_sync_test.dart`
  - optional `active_run_screen_live_activity_test.dart`
- **Test Cases**:
  - first sync starts bridge and background service.
  - repeated same payload does not update.
  - distance-only change before throttle does not update unless threshold exceeded.
  - distance-only change after 3 seconds updates.
  - pause change updates immediately.
  - resume change updates immediately.
  - block change updates immediately.
  - finish calls end/stop once.
  - platform exceptions are swallowed/logged and do not fail screen state.

## Sprint 3: Make Android Foreground Notification Display-Only

**Goal**: Remove native-owned distance, pace, average pace, and block advancement from Android custom notification.

**Demo/Validation**:

- Android notification shows Flutter payload values.
- Elapsed chronometer still moves while running.
- Distance does not advance unless Flutter sends updated distance.

### Task 3.1: Simplify Service State

- **Location**: `apps/mobile/android/app/src/main/kotlin/com/example/running_app/RunForegroundService.kt`
- **Remove Or Stop Using**:
  - `serviceDistanceKm`
  - `serviceElapsedMs` as authoritative elapsed storage
  - `blockIndex`
  - `blockElapsedMs`
  - `blockDistanceKm`
  - `timeline`
  - `advanceTimelineIfNeeded()`
  - native distance increments in `tick()`
  - native average pace calculations
- **Keep**:
  - `latestData`
  - foreground notification lifecycle
  - `lastTickRealtime` only if needed for notification refresh timing
  - a tick loop only if needed to refresh notification views, not to mutate run metrics
- **Acceptance Criteria**:
  - No code path adds distance based on pace.
  - No code path advances workout blocks natively.
  - No code path computes average pace from native-owned distance.

### Task 3.2: Render Payload Labels Directly

- **Location**: `RunForegroundService.kt`
- **Required Behavior**:
  - Collapsed view distance comes from `data.distanceLabel`.
  - Expanded view current pace comes from `data.currentPaceLabel`.
  - Expanded view average pace comes from `data.avgPaceLabel`.
  - Current block comes from `data.currentBlockLabel`.
  - Next block comes from `data.nextBlockLabel`.
  - Rep label comes from `data.repLabel`.
  - Progress bar comes from `data.blockProgressFraction`.
- **Implementation Detail**:
  - `distanceParts(data.distanceLabel, data)` can stay for split value/unit rendering.
  - Replace `computedProgressPermille(data)` with a payload-based version:

```kotlin
private fun progressPermille(data: RunNotificationData): Int {
    val progress = data.blockProgressFraction.coerceIn(0.0, 1.0)
    if (progress <= 0.0) return 0
    return (progress * 1000).toInt().coerceAtLeast(24)
}
```

- **Acceptance Criteria**:
  - Notification cannot drift from active screen for distance/pace except by the planned 3-second payload cadence.

### Task 3.3: Keep Native Elapsed Time Accurate

- **Location**: `RunForegroundService.kt`
- **Required Behavior**:
  - `bindElapsed` uses `data.elapsedSeconds`.
  - Running state uses `RemoteViews.setChronometer(...)`.
  - Paused state hides chronometer and shows `data.elapsedLabel`.
  - On each Flutter update, chronometer base is recalculated from latest `elapsedSeconds`.
- **Acceptance Criteria**:
  - Running notification elapsed continues moving between 3-second payload updates.
  - Pause freezes elapsed display.
  - Resume restarts from correct elapsed seed.

### Task 3.4: Adjust Android Snapshot/Event Semantics

- **Location**:
  - `RunForegroundService.kt`
  - `RunLiveActivityBridge`
  - any consumers if still present
- **Description**:
  - `snapshotState()` should not imply native owns distance/block state.
  - If kept, return latest payload-derived values only.
  - `emitFinishedEvent()` should not send native-computed distance.
- **Acceptance Criteria**:
  - Flutter controller does not ingest Android service state as authoritative.
  - If notification finish event remains, it only tells Flutter that user requested/caused finish.

### Task 3.5: Android Manual Validation

- **Device/Emulator Scenarios**:
  - Start run, verify notification appears.
  - Distance stays at Flutter payload value until next Flutter update.
  - Current pace changes only when Flutter sends payload.
  - Average pace matches active screen after payload update.
  - Pause freezes elapsed and updates status.
  - Resume restarts chronometer.
  - Finish removes notification.
  - Lock screen shows the same core values.

## Sprint 4: Confirm iOS Live Activity Payload Behavior

**Goal**: Ensure iOS Live Activity uses Flutter payload values and native timer only for elapsed.

**Demo/Validation**:

- iOS Live Activity starts, updates, pauses, resumes, and ends from Flutter state.
- Distance/pace never come from native calculation.

### Task 4.1: Review `RunLiveActivityManager.swift`

- **Location**: `apps/mobile/ios/Runner/RunLiveActivityManager.swift`
- **Expected Current Good Behavior**:
  - `makeContentState(from:)` reads all fields from payload.
  - `timerStartedAt` is derived from `elapsedSeconds` only when not paused.
  - `elapsedLabel` is used for paused/static display.
- **Required Changes**:
  - Only change if new mapper output needs a new field.
  - Do not add native distance or pace logic.
- **Acceptance Criteria**:
  - iOS Live Activity content state maps the same fields as `RunLiveActivityData`.

### Task 4.2: Validate Widget Extension Usage

- **Location**: iOS Live Activity widget extension files, if present in the repo.
- **Description**:
  - Confirm UI reads:
    - timer state for elapsed
    - distance label
    - current pace label
    - average pace label
    - current block label
    - next block label
    - rep label
    - block progress
    - planned pace
    - block remaining
- **Acceptance Criteria**:
  - No stale field names.
  - No hidden dependency on native-computed values.

### Task 4.3: iOS Manual Validation

- **Device Scenarios**:
  - Start run on iOS 16.1+.
  - Confirm Live Activity appears.
  - Lock screen: elapsed continues moving.
  - Distance/pace update on the 3-second cadence.
  - Pause freezes elapsed and changes status.
  - Resume restarts elapsed from the right time.
  - Finish removes Live Activity.

## Sprint 5: Documentation, Localization, And Cleanup

**Goal**: Remove stale assumptions and keep visible text localized.

### Task 5.1: Update Stale Comments

- **Location**: `apps/mobile/lib/features/active_run/domain/run_live_activity_data.dart`
- **Change**:
  - Replace comments saying Android service uses `distanceKm` as seed and ticks it.
  - Replace comments saying service advances timeline natively.
- **New Meaning**:
  - `distanceKm` is authoritative controller distance for payload/debug/native fallback.
  - `paceSecondsPerKm` is authoritative controller current pace for payload/debug/native fallback.
  - `timeline` is optional metadata and not the native source of truth.
- **Acceptance Criteria**:
  - Comments match implementation.

### Task 5.2: Add Missing Localization Keys Only If Needed

- **Location**:
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
- **Rules**:
  - Do not hardcode new visible labels in Dart.
  - If adding dynamic labels, use ARB placeholders.
  - Run `flutter gen-l10n` after ARB changes.
- **Likely Labels To Reuse Or Add**:
  - elapsed unit label
  - distance title
  - current pace title
  - average pace title
  - paused/running status
  - block remaining time/distance
- **Acceptance Criteria**:
  - English and Spanish paths have matching keys.
  - Generated l10n files are updated only via `flutter gen-l10n`.

### Task 5.3: Add Developer Notes

- **Location**: either this plan, active-run docs, or code comments near sync coordinator.
- **Content**:
  - Controller is authoritative.
  - Native surfaces are display-only.
  - Android Geolocator foreground service and custom run notification service are separate.
  - 3-second cadence is intentional.
- **Acceptance Criteria**:
  - Future maintainers do not reintroduce native distance ticking.

## Sprint 6: Full Verification

**Goal**: Verify static checks, automated tests, and real-device behavior.

### Task 6.1: Static Checks

- **Run From**: `apps/mobile/`
- **Commands**:

```bash
flutter analyze
```

- **Acceptance Criteria**:
  - No new analyzer errors.
  - No ignored analyzer warnings unless already present and unrelated.

### Task 6.2: Unit And Widget Tests

- **Run From**: `apps/mobile/`
- **Commands**:

```bash
flutter test
```

- **Acceptance Criteria**:
  - All existing tests pass.
  - New mapper/sync tests pass.

### Task 6.3: Android Field Test

- **Required Device Conditions**:
  - Android 13+ to verify notification permission path.
  - Android 14+ if available to verify foreground service type behavior.
  - Location permission granted.
  - Notification permission granted.
- **Scenario**:
  1. Start a GPS run.
  2. Confirm active screen shows elapsed, distance, current pace, average pace.
  3. Pull notification shade.
  4. Verify notification values match active screen within 3 seconds.
  5. Lock phone.
  6. Verify elapsed keeps moving.
  7. Pause run.
  8. Verify notification freezes elapsed and updates status immediately.
  9. Resume run.
  10. Verify elapsed restarts from correct value.
  11. Finish run.
  12. Verify notification is removed.
- **Acceptance Criteria**:
  - Distance never advances while active screen/controller distance does not advance.
  - Pace never changes unless controller sends a new payload.
  - Notification does not remain after finish.

### Task 6.4: iOS Field Test

- **Required Device Conditions**:
  - iOS 16.1+.
  - Live Activities enabled.
  - Location permission granted.
- **Scenario**:
  1. Start a GPS run.
  2. Confirm Live Activity appears.
  3. Verify elapsed matches active screen.
  4. Verify distance/pace match within 3 seconds.
  5. Lock phone.
  6. Pause/resume from app.
  7. Finish run.
- **Acceptance Criteria**:
  - Live Activity ends on finish.
  - Elapsed behavior remains correct while locked.
  - Distance and pace are not stale beyond expected cadence while Flutter is active.

## Risks And Gotchas

- **Two Android foreground surfaces can confuse behavior**:
  - Geolocator owns the location foreground service.
  - `RunForegroundService` owns the custom run notification.
  - Do not merge these responsibilities in this implementation.

- **Native distance ticking is tempting but wrong**:
  - It looks smooth, but it creates fake distance when GPS is stopped, inaccurate, paused, or filtered.
  - The native service must not infer distance from pace.

- **Elapsed can be native-ticked safely**:
  - Elapsed is deterministic from `elapsedSeconds` and pause state.
  - This is why elapsed can look exact while distance/pace update every 3 seconds.

- **Background behavior has real limits**:
  - If Flutter/controller stops producing GPS updates, native surfaces should keep displaying the last payload and live elapsed, not invent run movement.
  - True long-running background GPS reliability depends on Geolocator settings, OS permissions, and platform restrictions.

- **Testing platform channels directly is hard**:
  - Add Dart interfaces/providers for bridge and background service before writing widget tests.
  - Keep production singletons behind those interfaces.

- **Localization can regress quietly**:
  - Mapper must not hardcode visible labels.
  - Add ARB keys only where existing localized strings cannot be reused.

## Rollback Plan

If the live sync causes instability:

1. Disable sync calls from `ActiveRunScreen` while leaving mapper/tests in place.
2. Keep `_finishRun()` cleanup calls to avoid stale native surfaces.
3. Revert Android native simplification only if notification rendering breaks, but do not restore native distance ticking as final behavior.
4. Run `flutter analyze` and `flutter test` after rollback.

## Final Acceptance Criteria

- Active run screen remains the source of truth.
- iOS Live Activity starts, updates, pauses, resumes, and ends.
- Android active-run notification starts, updates, pauses, resumes, and ends.
- Elapsed time visually matches the app.
- Distance and pace match the app within the 3-second update cadence.
- Native Android does not compute distance, average pace, or block advancement.
- Geolocator GPS service remains separate and unchanged except for any verification-only fixes discovered during implementation.
- `flutter analyze` passes.
- `flutter test` passes.
