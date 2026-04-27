# Plan: Live Workout Status (iOS Live Activity + Android Foreground Service)

**Generated**: 2026-04-14
**Estimated Complexity**: High

## Overview

Add a live workout status card visible outside the app while the user is running.

- **iOS**: Real ActivityKit Live Activity — Lock Screen widget + Dynamic Island (compact, expanded, minimal).
- **Android**: Ongoing foreground-service notification with collapsed + expanded custom layouts.
- **Elapsed time**: Ticks natively every second without Flutter involvement (iOS: `Text(.timer)`, Android: `Chronometer`).
- **Flutter updates**: Only on meaningful events — distance threshold crossed, block change, pace shift >5 s/km, pause/resume, finish.
- **Background**: `flutter_background_service` keeps Flutter's Dart isolate alive so it can continue sending meaningful updates when the app is backgrounded.
- **Data format**: Flutter formats all display strings before sending; native layers render only.
- **Tap behaviour**: Tapping notification/live activity deep-links to the Active Run screen.
- **OS fallback**: Silent no-op on iOS < 16.1 and Android < API 26.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Flutter SDK | `^3.11.1` (already satisfied) |
| `flutter_background_service` | Add to `pubspec.yaml` |
| Xcode | 15+ required for ActivityKit + WidgetKit |
| Physical iOS device | Live Activities do not install reliably on simulator |
| Android device / emulator | API 26+ for foreground service; API 33+ for `POST_NOTIFICATIONS` |
| iOS background mode | Add `processing` + `fetch` background modes to Runner capabilities in Xcode |

---

## Sprint 1: Flutter Bridge + Data Model

**Goal**: Flutter can describe a live run state and send it to the native layer via a single MethodChannel. `ActiveRunScreen` calls the bridge on meaningful changes. No native implementation yet — bridge calls are no-ops until native is wired.

**Demo/Validation**:
- Run app in debug mode; open Flutter DevTools → log confirms bridge calls fire on block change and distance milestone.
- No crash when bridge is called before native is wired (graceful no-op).
- `flutter test` still passes.

---

### Task 1.1: Create `RunLiveActivityData` model

- **Location**: `apps/mobile/lib/features/active_run/domain/run_live_activity_data.dart`
- **Description**: Immutable data class carrying everything the native layer needs to render the card. All strings pre-formatted by Flutter (localised, unit-aware). Include a `toMap()` method for MethodChannel serialisation.
- **Dependencies**: None
- **Fields**:
  ```dart
  final String workoutName;        // "INTERVALS", "EASY RUN"
  final String statusLabel;        // "PUSH", "ON TARGET", "PICK UP"
  final int elapsedSeconds;        // total elapsed (for Android Chronometer base)
  final String elapsedLabel;       // "08:32" — shown on iOS when paused
  final String distanceLabel;      // "1.42 km" / "0.88 mi"
  final String currentPaceLabel;   // "5:06/km"
  final String avgPaceLabel;       // "5:57/km"
  final String currentBlockLabel;  // "Fast rep"
  final String? nextBlockLabel;    // null when no next block
  final String? repLabel;          // "Rep 3 / 6" — null for non-interval sessions
  final bool isPaused;
  ```
- **Acceptance Criteria**:
  - `toMap()` returns `Map<String, dynamic>` with all fields; null optionals serialised as `null`.
  - `copyWith()` helper present for partial updates.
- **Validation**: Unit test round-trips `toMap()`.

---

### Task 1.2: Create `RunLiveActivityBridge`

- **Location**: `apps/mobile/lib/features/active_run/presentation/run_live_activity_bridge.dart`
- **Description**: Thin singleton class wrapping a single `MethodChannel('com.example.runningApp/live_activity')`. Exposes three async methods. All calls are wrapped in try/catch — failures are logged, never rethrown (so native absence never crashes the app).
- **Dependencies**: Task 1.1
- **Methods**:
  ```dart
  Future<void> startActivity(RunLiveActivityData data)
  Future<void> updateActivity(RunLiveActivityData data)
  Future<void> endActivity()
  ```
- **OS guard**: Check `Platform.isIOS` / `Platform.isAndroid` at call site; no-op on other platforms.
- **Acceptance Criteria**:
  - Calling any method without native handler registered does not throw.
  - Channel name matches exactly `"com.example.runningApp/live_activity"` in all layers.
- **Validation**: Manual log check in debug run.

---

### Task 1.3: Fix elapsed time tracking in `ActiveRunScreen`

- **Location**: `apps/mobile/lib/features/active_run/presentation/screens/active_run_screen.dart`
- **Description**: Replace the current increment-counter approach with a `_runStartedAt: DateTime` + `_pausedDurationMs: int` approach. This makes elapsed time correct even if the Flutter isolate was suspended and resumed. The `_elapsed` getter computes `now - _runStartedAt - pausedDuration`.
- **Dependencies**: None (parallel with 1.1/1.2)
- **Acceptance Criteria**:
  - Elapsed time shown on screen matches wall-clock time when app is backgrounded and returned to.
  - Pause correctly freezes the clock; resume resumes from exact frozen point.
- **Validation**: Background app for 30 s during a run; verify elapsed ≈ 30 s ahead on return.

---

### Task 1.4: Integrate bridge into `ActiveRunScreen`

- **Location**: `apps/mobile/lib/features/active_run/presentation/screens/active_run_screen.dart`
- **Description**: Instantiate `RunLiveActivityBridge`. Call `startActivity()` in `initState` after the first tick. Call `updateActivity()` only when:
  1. `_timelineIndex` changes (block change).
  2. `_distanceKm` crosses the next 0.1 km milestone.
  3. Pause/resume state toggles.
  Call `endActivity()` in the finish handler and in `dispose()`.
- **Dependencies**: Tasks 1.1, 1.2, 1.3
- **Helper**: `_buildLiveActivityData()` method that formats all strings from current state using `AppLocalizations` and `UnitFormatter`.
- **Acceptance Criteria**:
  - Bridge `startActivity` called exactly once per run.
  - Bridge `updateActivity` NOT called every second.
  - Bridge `endActivity` called on finish and on unexpected dispose.
- **Validation**: Add temporary `debugPrint` in bridge methods; verify call frequency in console.

---

### Task 1.5: Add `flutter_background_service` package

- **Location**: `apps/mobile/pubspec.yaml`
- **Description**: Add `flutter_background_service: ^5.0.5` (or latest). Add required iOS background modes to `Runner/Info.plist`: `fetch` and `processing`. Add required Android permissions to `AndroidManifest.xml` (will be expanded in Sprint 2). Initialise the service in `main.dart` before `runApp`, configured to run Flutter's background isolate. The isolate listens for `"updateRun"` messages from the main isolate and forwards them to the native bridge.
- **Dependencies**: Tasks 1.2, 1.4
- **Acceptance Criteria**:
  - `flutter pub get` succeeds.
  - `flutter analyze` passes.
  - `flutter test` passes.
- **Validation**: `flutter pub get && flutter analyze`.

---

## Sprint 2: Android Foreground Service

**Goal**: On Android, a persistent foreground-service notification appears when a run starts. Elapsed time ticks natively via `Chronometer`. Flutter-formatted data renders in both collapsed and expanded notification layouts. Tapping the notification opens the Active Run screen. Dismissed only when `endActivity` is called.

**Demo/Validation**:
- Start a run → notification appears immediately with workout name, chronometer counting.
- Pull down notification → expanded view shows all fields.
- Lock device → notification persists on lock screen.
- Tap notification → app opens to Active Run screen.
- Finish run → notification dismisses.
- On Android 12 emulator (API 31) → notification appears without POST_NOTIFICATIONS prompt.
- On Android 13+ device → permission prompt fires before first run; notification appears after grant.

---

### Task 2.1: Create notification vector drawable

- **Location**: `apps/mobile/android/app/src/main/res/drawable/ic_run_notification.xml`
- **Description**: Simple running-figure vector drawable for the notification small icon. Must be monochrome (white/transparent) to comply with Android notification icon rules.
- **Dependencies**: None
- **Acceptance Criteria**: Icon renders at 24dp without colour artefacts in notification tray.

---

### Task 2.2: Create notification channel string resource

- **Location**: `apps/mobile/android/app/src/main/res/values/strings.xml`
- **Description**: Add string resource `run_notification_channel_name` = `"Active Run"`. Add Spanish variant under `values-es/strings.xml` = `"Carrera activa"`.
- **Dependencies**: None

---

### Task 2.3: Create collapsed notification layout

- **Location**: `apps/mobile/android/app/src/main/res/layout/notification_run_collapsed.xml`
- **Description**: Single-row `RemoteViews` layout matching the collapsed mockup:
  ```
  │ INTERVALS                    08:32 │
  │ PUSH                  1.42 km 5:06 │
  ```
  - `TextView` for workout name (bold, white).
  - `Chronometer` for elapsed time (monospace, white, right-aligned).
  - `TextView` for status label (secondary colour).
  - `TextView` for distance (white).
  - `TextView` for current pace (white).
- **Dependencies**: Task 2.1
- **Acceptance Criteria**: Layout renders on API 26+ without crash. No hardcoded English strings (IDs only; content set in Kotlin).

---

### Task 2.4: Create expanded notification layout

- **Location**: `apps/mobile/android/app/src/main/res/layout/notification_run_expanded.xml`
- **Description**: Full-card `RemoteViews` layout matching expanded mockup. Include all fields: workout name, status, chronometer, distance, current block, next block (gone when null), current pace label + value, avg pace label + value, rep label (gone when null).
- **Dependencies**: Task 2.1
- **Acceptance Criteria**: Visibility toggling works (GONE/VISIBLE) for optional fields. Renders correctly on API 26+ and API 33+.

---

### Task 2.5: Create `RunForegroundService.kt`

- **Location**: `apps/mobile/android/app/src/main/kotlin/com/example/running_app/RunForegroundService.kt`
- **Description**: `Service` subclass that owns and updates the notification. Key responsibilities:
  1. `onStartCommand`: call `startForeground(NOTIFICATION_ID, buildNotification(initialData))` immediately.
  2. `buildNotification(data)`: creates `NotificationCompat.Builder` with custom collapsed + expanded `RemoteViews`. Sets Chronometer base: `SystemClock.elapsedRealtime() - data.elapsedSeconds * 1000L`. Sets `showWhen = false`. Sets `ongoing = true`. Sets `PendingIntent` for tap deep-link (see Task 2.6).
  3. `updateRun(data: Map<*,*>)`: rebuilds notification and calls `notificationManager.notify(NOTIFICATION_ID, notification)`. Resets Chronometer base on each update (elapsed may have drifted).
  4. `pauseRun()` / `resumeRun()`: stop/start Chronometer. When paused, show static elapsed string instead.
  5. `endRun()`: call `stopForeground(STOP_FOREGROUND_REMOVE)` then `stopSelf()`.
  6. Notification channel creation in `createChannel()` called from `onStartCommand`.
- **Dependencies**: Tasks 2.1 – 2.4
- **Acceptance Criteria**:
  - Service starts without `RemoteServiceException`.
  - Chronometer ticks without Flutter involvement.
  - Optional fields (next block, rep label) hide correctly when data is null.
- **Validation**: `adb shell dumpsys activity services | grep RunForegroundService` shows service running.

---

### Task 2.6: Configure deep-link PendingIntent

- **Location**: `RunForegroundService.kt` (inside `buildNotification`)
- **Description**: Create a `PendingIntent` that opens `MainActivity` with `Intent.FLAG_ACTIVITY_SINGLE_TOP` and a data URI `com.example.runningapp://active-run`. Use `PendingIntent.FLAG_IMMUTABLE`. `MainActivity` will handle this intent and navigate to Active Run screen (wired in Task 2.7).
- **Dependencies**: Task 2.5
- **Acceptance Criteria**: Tapping notification when app is backgrounded brings Active Run screen to front.

---

### Task 2.7: Update `AndroidManifest.xml`

- **Location**: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- **Description**: Add:
  ```xml
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```
  Declare service:
  ```xml
  <service
      android:name=".RunForegroundService"
      android:foregroundServiceType="health"
      android:exported="false"/>
  ```
  Add intent-filter on `MainActivity` for the deep-link URI `com.example.runningapp://active-run`.
- **Dependencies**: Task 2.5
- **Acceptance Criteria**: `flutter build apk --debug` compiles without manifest errors.

---

### Task 2.8: Update `MainActivity.kt`

- **Location**: `apps/mobile/android/app/src/main/kotlin/com/example/running_app/MainActivity.kt`
- **Description**: 
  1. Register `MethodChannel("com.example.runningApp/live_activity")` in `configureFlutterEngine`.
  2. Handle `startActivity` → `startForegroundService(intent)` with data extras.
  3. Handle `updateActivity` → call `runService?.updateRun(data)` (hold weak ref to service via `ServiceConnection`).
  4. Handle `endActivity` → `stopService(intent)`.
  5. Handle incoming deep-link intent in `onNewIntent` → use GoRouter to push `/active-run` route.
  6. OS guard: wrap all service calls in `if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)`.
- **Dependencies**: Tasks 2.5, 2.6, 2.7
- **Acceptance Criteria**: MethodChannel calls from Flutter reach the service correctly.

---

### Task 2.9: Runtime `POST_NOTIFICATIONS` permission request

- **Location**: `apps/mobile/lib/features/active_run/presentation/screens/active_run_screen.dart` (or pre-run screen)
- **Description**: Before calling `bridge.startActivity()`, check Android version at runtime. On Android 13+ (API 33), request `POST_NOTIFICATIONS` permission using `permission_handler` package (add to `pubspec.yaml`). If denied, continue run without notification (silent no-op).
- **Dependencies**: Tasks 1.4, 2.8
- **Acceptance Criteria**:
  - On Android 13+ emulator, permission dialog appears before first run.
  - If user denies, run starts normally with no crash.
  - On Android ≤12, no permission dialog.

---

## Sprint 3: iOS Live Activity

**Goal**: On iOS 16.1+ physical device, a Live Activity appears on Lock Screen and in Dynamic Island when a run starts. Elapsed time ticks natively. Flutter-formatted strings render in all three Dynamic Island states (compact, expanded, minimal) and in the Lock Screen view. Tapping opens the Active Run screen. Activity ends when run finishes.

**Demo/Validation** (requires physical iPhone with iOS 16.1+):
- Start run → Live Activity appears on Lock Screen and Dynamic Island.
- Lock device → Lock Screen card shows all fields; timer counts.
- Long-press Dynamic Island → expanded view shows pace + timer + workout info.
- Compact Dynamic Island shows distance + timer.
- Pause run → timer freezes on both Lock Screen and Dynamic Island.
- Resume run → timer resumes from correct elapsed time.
- Finish run → Live Activity dismisses.
- On iOS 15 device → no crash, activity silently not started.

---

### Task 3.1: Add WidgetKit extension target in Xcode (manual step)

- **Location**: Xcode → Runner project → `File > New > Target > Widget Extension`
- **Description**: Create target named `RunLiveActivityExtension`. Uncheck "Include Configuration Intent". Product bundle identifier: `com.example.runningApp.RunLiveActivityExtension`. Deployment target: iOS 16.2. Add `CodeSignOnCopy` + `RemoveHeadersOnCopy` to the "Embed App Extensions" build phase entry. This task is a manual Xcode step — cannot be scripted safely.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Extension target appears in Xcode navigator.
  - `project.pbxproj` embed phase entry has `ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, )`.
  - `flutter build ios --debug` compiles extension without error.

---

### Task 3.2: Create `RunActivityAttributes.swift` (Runner target)

- **Location**: `apps/mobile/ios/Runner/RunActivityAttributes.swift`
- **Description**: Defines the shared `ActivityAttributes` conformance. Add to **Runner target** in Xcode.
  ```swift
  import ActivityKit

  struct RunActivityAttributes: ActivityAttributes {
      let workoutName: String
      let statusLabel: String

      struct ContentState: Codable, Hashable {
          var timerStartedAt: Date?    // nil when paused
          var elapsedLabel: String     // "08:32" — shown when paused
          var isPaused: Bool
          var distanceLabel: String
          var currentPaceLabel: String
          var avgPaceLabel: String
          var currentBlockLabel: String
          var nextBlockLabel: String?
          var repLabel: String?
      }
  }
  ```
- **Dependencies**: Task 3.1
- **Acceptance Criteria**: Compiles in Runner target. No duplicate symbol errors.

---

### Task 3.3: Create `RunActivityAttributes.swift` (Extension target — copy)

- **Location**: `apps/mobile/ios/RunLiveActivityExtension/RunActivityAttributes.swift`
- **Description**: Exact copy of Task 3.2 file, added to **RunLiveActivityExtension target** in Xcode. Both targets need the struct; sharing via framework is out of scope. Keep in sync manually.
- **Dependencies**: Task 3.2
- **Acceptance Criteria**: Extension compiles with no "undeclared type" errors.

---

### Task 3.4: Create `RunLiveActivityWidget.swift`

- **Location**: `apps/mobile/ios/RunLiveActivityExtension/RunLiveActivityWidget.swift`
- **Description**: SwiftUI `Widget` + `WidgetBundle` implementing the full UI:

  **Lock Screen (`RunLockScreenView`)**:
  ```
  ┌────────────────────────────────────┐
  │ INTERVALS                    08:32 │  ← workoutName + timer/elapsed
  │ PUSH                               │  ← statusLabel
  │                                    │
  │ 1.42 km                            │  ← distanceLabel
  │ Fast rep                           │  ← currentBlockLabel
  │ Next: Recover                      │  ← nextBlockLabel (hidden if nil)
  │                                    │
  │ CURRENT PACE              5:06/km  │  ← currentPaceLabel
  │ AVG PACE                  5:57/km  │  ← avgPaceLabel
  │                                    │
  │ Rep 3 / 6                          │  ← repLabel (hidden if nil)
  └────────────────────────────────────┘
  ```

  **Dynamic Island expanded**: pace metrics flanking central timer; workout info in bottom region.

  **Dynamic Island compact**: `distanceLabel` leading + timer trailing.

  **Dynamic Island minimal**: system running figure icon.

  **Timer rendering** (use in both Lock Screen and DI):
  ```swift
  if context.state.isPaused {
      Text(context.state.elapsedLabel)
  } else if let start = context.state.timerStartedAt {
      Text(start, style: .timer)   // OS ticks natively
  }
  ```

- **Dependencies**: Task 3.3
- **Acceptance Criteria**: Extension builds. No SwiftUI preview crashes. All optional fields use `if let` guards.

---

### Task 3.5: Create `RunLiveActivityManager.swift`

- **Location**: `apps/mobile/ios/Runner/RunLiveActivityManager.swift`
- **Description**: Class added to **Runner target** that manages the `Activity<RunActivityAttributes>` lifecycle and receives MethodChannel calls.

  ```swift
  import ActivityKit

  class RunLiveActivityManager {
      private var activity: Activity<RunActivityAttributes>?

      func startActivity(data: [String: Any]) { ... }
      func updateActivity(data: [String: Any]) { ... }
      func endActivity() { ... }

      private func makeContentState(from data: [String: Any]) -> RunActivityAttributes.ContentState {
          // Parse elapsedSeconds → timerStartedAt = Date() - elapsedSeconds
          // Parse all string fields
      }
  }
  ```

  - `startActivity`: guard `ActivityAuthorizationInfo().areActivitiesEnabled`; call `Activity.request(attributes:content:pushType:nil)`.
  - `updateActivity`: call `await activity?.update(using: newState)`.
  - `endActivity`: call `await activity?.end(nil, dismissalPolicy: .immediate)`.
  - All `Activity` calls are `async`; dispatch on a `Task { }` block.
  - Wrap all in `if #available(iOS 16.1, *) { }`.

- **Dependencies**: Tasks 3.2, 3.4
- **Acceptance Criteria**: No compile errors. Activity lifecycle calls correct API signatures.

---

### Task 3.6: Update `AppDelegate.swift`

- **Location**: `apps/mobile/ios/Runner/AppDelegate.swift`
- **Description**: Register `MethodChannel("com.example.runningApp/live_activity")` in `application(_:didFinishLaunchingWithOptions:)`. Instantiate `RunLiveActivityManager`. Wire `startActivity`, `updateActivity`, `endActivity` method calls. Return `FlutterMethodNotImplemented` for unknown methods.

  Add deep-link handling: implement `application(_:open:options:)` to parse `com.example.runningapp://active-run` and send a Flutter platform message back to navigate to `/active-run`.

- **Dependencies**: Task 3.5
- **Acceptance Criteria**: MethodChannel registered. No retain cycles (use `[weak self]`).

---

### Task 3.7: Update `Runner/Info.plist`

- **Location**: `apps/mobile/ios/Runner/Info.plist`
- **Description**: Add two keys:
  ```xml
  <key>NSSupportsLiveActivities</key>
  <true/>
  <key>NSSupportsLiveActivitiesFrequentUpdates</key>
  <true/>
  ```
  Also add background modes if not already present:
  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>fetch</string>
      <string>processing</string>
  </array>
  ```
- **Dependencies**: None (can do in parallel with 3.5)
- **Acceptance Criteria**: `flutter build ios --debug` does not warn about missing plist keys.

---

### Task 3.8: Update `RunLiveActivityExtension/Info.plist`

- **Location**: `apps/mobile/ios/RunLiveActivityExtension/Info.plist`
- **Description**: Verify extension plist has only:
  ```xml
  <key>NSExtension</key>
  <dict>
      <key>NSExtensionPointIdentifier</key>
      <string>com.apple.widgetkit-extension</string>
  </dict>
  ```
  No other extension keys needed. Confirm deployment target is 16.2 in build settings (not plist).
- **Dependencies**: Task 3.1
- **Acceptance Criteria**: Extension installs on physical device without `simctl` placeholder error.

---

## Sprint 4: Background Execution + Polish

**Goal**: Flutter timer and bridge updates continue correctly when the app is backgrounded mid-run. Pause/resume syncs timer across native layers. All edge cases handled: run finish, app kill, OS version guards verified.

**Demo/Validation**:
- Start a run → background app for 2 minutes → return to foreground → elapsed time is correct (≈2 min ahead).
- Live Activity / notification updated with latest data on foreground return.
- Pause mid-run → background → return → timer still frozen correctly.
- Kill app entirely → Android: service keeps notification alive. iOS: Live Activity stays until `endActivity`.
- Run `flutter analyze` → zero issues.

---

### Task 4.1: Wire `flutter_background_service` isolate to bridge

- **Location**: `apps/mobile/lib/main.dart` + new `apps/mobile/lib/core/background/run_background_service.dart`
- **Description**: Configure `flutter_background_service` with an isolate. Communication pattern:

  **Main isolate → Background isolate** (data forwarding):
  ```dart
  // In ActiveRunScreen, after each meaningful change:
  FlutterBackgroundService().invoke('runUpdate', data.toMap());
  ```

  **Background isolate** (receives + calls native):
  ```dart
  @pragma('vm:entry-point')
  void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    service.on('runUpdate').listen((data) async {
      // Call MethodChannel from background engine
      await const MethodChannel('com.example.runningApp/live_activity')
          .invokeMethod('updateActivity', data);
    });
  }
  ```

  **Critical**: `flutter_background_service` initialises its own Flutter engine in the background isolate. `DartPluginRegistrant.ensureInitialized()` is required so platform plugins (including MethodChannel) are registered. The MethodChannel call from the background engine reaches the native side via the background engine's binary messenger — but the native handler (MainActivity/AppDelegate) must be capable of receiving it. On Android, `MainActivity` registers the channel on the main engine only. For the background engine's channel to reach `RunForegroundService`, the native handler registration must be verified during implementation. If it doesn't work, the fallback is having the background isolate notify the main isolate to forward the call instead.

  **Android duplicate notification**: `flutter_background_service` creates its own foreground service and may show a second notification. Configure `AndroidConfiguration` with `isForegroundMode: false` and rely on `RunForegroundService` as the sole foreground service. Set `autoStartOnBoot: false`.

  **iOS**: Configure `IosConfiguration` with `onBackground` returning `true`. iOS BGTaskScheduler gives limited execution windows (~30s per fetch task). Use this to send a sync update when the app wakes from background; don't expect continuous execution.

- **Dependencies**: Task 1.5, all Sprint 2 + 3 tasks
- **Acceptance Criteria**: `updateActivity` is called from background isolate when app is backgrounded. No duplicate notifications on Android. Background isolate does not crash on iOS.
- **Note**: This task has the highest implementation risk in the plan. If background MethodChannel routing proves unreliable, the acceptable fallback is: foreground-only updates + native timers handle display when backgrounded.

---

### Task 4.2: Pause/resume timer sync

- **Location**: `RunLiveActivityManager.swift`, `RunForegroundService.kt`, `RunLiveActivityBridge` (Dart)
- **Description**: On pause:
  - Flutter sets `isPaused: true`, `elapsedLabel: "08:32"`, `timerStartedAt: null`.
  - iOS: `Text(elapsedLabel)` shown instead of `.timer`.
  - Android: `chronometer.stop()` + set static time text.
  On resume:
  - Flutter recomputes `timerStartedAt = Date.now() - totalElapsedSeconds`.
  - iOS: `.timer` from new `timerStartedAt`.
  - Android: `chronometer.base = SystemClock.elapsedRealtime() - elapsedMs; chronometer.start()`.
- **Dependencies**: Tasks 3.5, 2.5
- **Acceptance Criteria**: Elapsed shown on Live Activity / notification matches in-app elapsed after pause → resume cycle.

---

### Task 4.3: Handle run finish + app kill

- **Location**: `ActiveRunScreen`, `RunForegroundService.kt`, `RunLiveActivityManager.swift`
- **Description**:
  - On finish: `bridge.endActivity()` → both native layers clean up.
  - On `dispose()` (back nav, app kill): also call `bridge.endActivity()` as safety.
  - Android: if service is killed by OS, notification is auto-removed (foreground service guarantee).
  - iOS: Live Activity has `staleDate`. Set `staleDate = Date() + 3600` on start; activity auto-dismisses after 1h if never ended.
- **Dependencies**: Tasks 3.5, 2.5
- **Acceptance Criteria**: No orphan notifications or Live Activities after run ends.

---

### Task 4.4: OS version guards audit

- **Location**: All native files + `RunLiveActivityBridge`
- **Description**: Final audit pass:
  - Dart: `Platform.isIOS` / `Platform.isAndroid` guards in bridge.
  - Swift: every ActivityKit call inside `if #available(iOS 16.1, *) { }`.
  - Kotlin: every service call inside `if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) { }`.
  - `POST_NOTIFICATIONS` request only on API >= 33.
- **Acceptance Criteria**: App runs without crash on iOS 15 simulator and Android API 24 emulator. Live status simply absent on those versions.

---

### Task 4.5: `flutter analyze` + `flutter test` clean pass

- **Location**: `apps/mobile/`
- **Description**: Run `flutter analyze` and `flutter test`. Fix any new warnings introduced in Sprints 1–4. Verify no regressions in existing tests.
- **Dependencies**: All previous tasks
- **Acceptance Criteria**: Zero analyzer errors. All tests pass.

---

## Testing Strategy

| Sprint | How to verify |
|---|---|
| 1 | `flutter test`; `debugPrint` in bridge shows correct call frequency |
| 2 | Android emulator API 33; adb to verify service running; notification tap navigation |
| 3 | Physical iPhone; Lock Screen + Dynamic Island render correct; `.timer` ticks |
| 4 | Background app 2 min; verify elapsed sync on return; finish → clean dismissal |

---

## Potential Risks & Gotchas

| Risk | Mitigation |
|---|---|
| iOS simulator blocks Live Activity install | Always test Sprint 3 on a physical device |
| `RunActivityAttributes` struct drift between targets | Keep both files identical; add a comment at top of each: `// SYNC: must match Runner/RunActivityAttributes.swift` |
| Extension embed phase missing `CodeSignOnCopy` | Double-check `project.pbxproj` line 14 after Task 3.1 (was root cause of previous failure) |
| Android `foregroundServiceType="health"` missing on API 34+ | Task 2.7 declares it; verify in manifest after merge |
| `flutter_background_service` isolate can't share Riverpod state | Background isolate only handles bridge forwarding — no Riverpod access. State is passed via serialised `RunLiveActivityData` map from main isolate |
| Live Activity `staleDate` too short | Set 1 hour stale date; very long runs won't auto-dismiss prematurely |
| Android notification channel already registered on re-install | Use `createNotificationChannel` which is idempotent — safe to call repeatedly |
| Pace / distance freeze when backgrounded (simulated data) | Acceptable for simulated run; real GPS integration (future) will fix naturally |
| Background MethodChannel reaching native from secondary engine | Background isolate uses its own Flutter engine; MainActivity channel handler is registered on main engine only. Verify routing works during Task 4.1; fall back to foreground-only updates if not |
| `flutter_background_service` dual foreground service on Android | Set `isForegroundMode: false` in `AndroidConfiguration` so it doesn't create a second notification — `RunForegroundService` is the only foreground service |
| iOS BGTaskScheduler gives ≤30s per background window | Don't assume continuous background execution on iOS. Use window to send one sync update; native timer handles display between windows |

---

## Rollback Plan

- All new files are additions — delete them to revert.
- `AndroidManifest.xml`, `MainActivity.kt`, `AppDelegate.swift`, `Info.plist` changes are additive — revert via git.
- Extension target was added manually in Xcode — remove target and delete `RunLiveActivityExtension/` directory.
- `pubspec.yaml` package additions — remove entries and run `flutter pub get`.
