# Plan: Replace Hardcoded Data with Domain Models & Providers

**Generated**: 2026-03-28
**Estimated Complexity**: Medium

## Overview

The app currently has two categories of hardcoded content that must be replaced:

1. **Dynamic data hardcoded in screens** — weekly sessions, dates, distances, user stats, chart data, progress metrics, and profile info are all literal values inline in `WeeklyPlanScreen`, `ProgressScreen`, `HomeScreen`, and `SettingsScreen`.
2. **Mock values stored in l10n files** — `homePlanName`, `homeWorkoutSessionName`, `settingsProfileName`, etc. are static English strings in `app_localizations_en.dart` that should come from Riverpod providers, not the translation layer.
3. **Onboarding step counters** — `'1 / 9'` through `'9 / 9'` are hardcoded strings in 9 onboarding screens instead of using a localized template.

**Approach**: Create clean domain models → populate with Dart seed data → expose via Riverpod providers → wire screens to providers → audit and clean up l10n.

**Root path**: `apps/mobile/lib/`

---

## Prerequisites

- Flutter Riverpod 3.x already installed (`flutter_riverpod`, `riverpod_annotation`)
- SharedPreferences already used (`userPreferencesProvider`, `localeProvider`)
- Existing `UnitSystem` enum in `features/user_preferences/domain/user_preferences.dart`
- No backend — all data from Dart seed objects for now

---

## Sprint 1: Domain Models

**Goal**: Pure Dart value objects for training plan and progress data, no UI or provider logic.
**Demo/Validation**: Models compile cleanly, can be instantiated in a `main()` test.

### Task 1.1: Session type & status enums

- **Location**: `features/training_plan/domain/models/session_type.dart`
- **Description**: Create `SessionType` enum (rest, easyRun, intervals, longRun, recoveryRun, tempoRun) and `SessionStatus` enum (upcoming, today, completed, skipped). Move out of `WeeklyPlanScreen` private scope. Add `iconAsset` getter on `SessionType` (maps to existing SVG paths from `_trailingIcon()`).
- **Acceptance Criteria**:
  - Enums are importable from any feature
  - `SessionType.iconAsset` returns the correct `'assets/icons/...'` string
- **Validation**: Import in a scratch file, check all enum values compile

---

### Task 1.2: TrainingSession model

- **Location**: `features/training_plan/domain/models/training_session.dart`
- **Description**: Immutable value class with:
  ```dart
  class TrainingSession {
    final String id;
    final DateTime date;
    final SessionType type;
    final SessionStatus status;
    final double? distanceKm;       // null for rest days
    final int? durationMinutes;     // null for rest days
    final String? description;      // e.g. '4×800m @ 5K pace'
    final String? effortLabel;      // e.g. 'Easy effort'
  }
  ```
- **Acceptance Criteria**:
  - `copyWith` method present
  - No Flutter imports (pure Dart)
- **Validation**: Unit-instantiate in isolation

---

### Task 1.3: TrainingPlan model

- **Location**: `features/training_plan/domain/models/training_plan.dart`
- **Description**:
  ```dart
  class TrainingPlan {
    final String id;
    final String name;           // e.g. 'Half Marathon Plan'
    final String raceType;       // e.g. 'Half Marathon'
    final int totalWeeks;
    final int currentWeekNumber;
    final List<TrainingSession> sessions; // all sessions, all weeks
  }
  ```
  Add computed getters:
  - `currentWeekSessions` → sessions for the current ISO week
  - `todaySession` → first session where `status == today`
  - `nextUpcomingSession` → first upcoming session after today
- **Dependencies**: Task 1.2
- **Validation**: Instantiate with mock sessions, verify computed getters

---

### Task 1.4: WeekProgress model

- **Location**: `features/training_plan/domain/models/week_progress.dart`
- **Description**:
  ```dart
  class WeekProgress {
    final int completedSessions;
    final int totalSessions;
    final double completedVolumeKm;
    final double totalVolumeKm;
  }
  ```
  Factory: `WeekProgress.fromSessions(List<TrainingSession> sessions)`
- **Dependencies**: Task 1.2
- **Validation**: Pass a list of mixed completed/upcoming sessions, verify counts

---

### Task 1.5: UserStats model

- **Location**: `features/progress/domain/models/user_stats.dart`
- **Description**:
  ```dart
  class UserStats {
    final int streakWeeks;
    final double totalDistanceKm;
    final int totalTimeMinutes;
    final int totalRuns;
    final String avgPacePerKm;       // e.g. '6:15'
    final double distanceTrendPct;   // e.g. 14.0 (+14%)
    final double timeTrendPct;
  }
  ```
- **Validation**: Instantiate, verify no compile errors

---

### Task 1.6: WeeklyVolumeData model

- **Location**: `features/progress/domain/models/weekly_volume_data.dart`
- **Description**: Replaces private `_WeekData` in `ProgressScreen`:
  ```dart
  class WeeklyVolumeData {
    final double distanceKm;
    final int timeHours;
    final int timeMinutes;
    final int elevationMeters;
    final String? dateRange;   // null = current week
    bool get isCurrentWeek => dateRange == null;
  }
  ```
- **Validation**: Instantiate, verify `isCurrentWeek` logic

---

### Task 1.7: RecentSession model

- **Location**: `features/progress/domain/models/recent_session.dart`
- **Description**: Replaces private `_RecentSession` in `ProgressScreen`:
  ```dart
  class RecentSession {
    final String title;
    final String dateLabel;       // e.g. 'Yesterday', 'Tuesday'
    final double distanceKm;
    final int durationMinutes;
    final SessionType type;       // drives icon + colour
  }
  ```
- **Dependencies**: Task 1.1
- **Validation**: Instantiate with all fields

---

## Sprint 2: Seed Data

**Goal**: A single source of mock data replacing all inline literals in screens. Screens are untouched in this sprint.
**Demo/Validation**: Import seed files in a scratch `main()` and `print()` plan.name, today's session title, and stats values.

### Task 2.1: Training plan seed data

- **Location**: `features/training_plan/data/training_plan_seed_data.dart`
- **Description**: Create a `kSeedTrainingPlan` constant of type `TrainingPlan` with:
  - `name: 'Half Marathon Plan'`, `totalWeeks: 12`, `currentWeekNumber: 4`
  - 7 sessions covering the current ISO week (Mon–Sun), matching dates from the current real calendar week
  - Use `DateTime.now()` to calculate the week's Monday, so dates stay accurate
  - Session content mirrors current hardcoded data in `WeeklyPlanScreen`:
    - Mon: rest/upcoming
    - Tue: easyRun/completed (5 km, 30 min)
    - Wed: easyRun/skipped (4 km, 25 min)
    - Thu: intervals/today (6 km, 45 min, '4×800m @ 5K pace. 90s recovery jog.')
    - Fri: rest/upcoming
    - Sat: longRun/upcoming (12 km, 75 min, 'Easy effort')
    - Sun: recoveryRun/upcoming (3 km, 20 min)
- **Dependencies**: Tasks 1.2, 1.3, 1.4
- **Validation**: `kSeedTrainingPlan.todaySession` returns the intervals session

---

### Task 2.2: Progress seed data

- **Location**: `features/progress/data/progress_seed_data.dart`
- **Description**: Create constants:
  - `kSeedUserStats` — mirrors hardcoded values from `ProgressScreen` (streakWeeks: 5, totalDistanceKm: 65.2, totalTimeMinutes: 375, totalRuns: 10, avgPacePerKm: '6:15', distanceTrendPct: 14.0, timeTrendPct: 5.0)
  - `kSeedWeeklyVolume` — `List<WeeklyVolumeData>` with 6 entries mirroring `_VolumeChartCard._weeks`
  - `kSeedRecentSessions` — `List<RecentSession>` with 3 entries mirroring inline sessions in `ProgressScreen.build()`
  - `kSeedLongestRun` — `double` (e.g. 21.1 km)
- **Dependencies**: Tasks 1.5, 1.6, 1.7
- **Validation**: All constants instantiate without error

---

## Sprint 3: Riverpod Providers

**Goal**: Expose seed data through Riverpod so screens only see providers, never raw seed constants.
**Demo/Validation**: Add a temporary `print(ref.read(trainingPlanProvider).name)` in `AppShell.initState` and verify it prints.

### Task 3.1: Training plan provider

- **Location**: `features/training_plan/presentation/training_plan_provider.dart`
- **Description**:
  ```dart
  // Simple provider for now — swap body for API call later
  final trainingPlanProvider = Provider<TrainingPlan>((ref) {
    return kSeedTrainingPlan;
  });

  // Derived providers for convenience
  final weekProgressProvider = Provider<WeekProgress>((ref) {
    final plan = ref.watch(trainingPlanProvider);
    return WeekProgress.fromSessions(plan.currentWeekSessions);
  });
  ```
- **Dependencies**: Tasks 2.1, 1.4
- **Validation**: `ref.read(trainingPlanProvider)` returns the plan in a ConsumerWidget

---

### Task 3.2: Progress / stats provider

- **Location**: `features/progress/presentation/progress_provider.dart`
- **Description**:
  ```dart
  final userStatsProvider = Provider<UserStats>((ref) => kSeedUserStats);
  final weeklyVolumeProvider = Provider<List<WeeklyVolumeData>>((ref) => kSeedWeeklyVolume);
  final recentSessionsProvider = Provider<List<RecentSession>>((ref) => kSeedRecentSessions);
  ```
- **Dependencies**: Task 2.2
- **Validation**: All three providers readable in a ConsumerWidget

---

### Task 3.3: User profile provider

- **Location**: `features/user_preferences/presentation/user_preferences_provider.dart` (extend existing file)
- **Description**: Add a derived `userProfileDisplayProvider`:
  ```dart
  // Returns display strings for profile card & home header
  final userProfileDisplayProvider = Provider<UserProfileDisplay>((ref) {
    return const UserProfileDisplay(
      name: 'User Name',
      planName: 'Half Marathon Plan',
      weekInfo: 'Week 4 of 12',
    );
  });

  // Lightweight display model — lives in same file or nearby
  class UserProfileDisplay {
    final String name;
    final String planName;
    final String weekInfo;
    // ...
  }
  ```
  In a follow-up this reads from `trainingPlanProvider` + auth state; for now seed values.
- **Validation**: Readable from `SettingsScreen` and `HomeScreen`

---

## Sprint 4: Wire Screens to Providers

**Goal**: All four screens read from providers — zero hardcoded numerics or data lists.
**Demo/Validation**: Hot-reload the app; all four tab screens display identical data to the current hardcoded state.

### Task 4.1: HomeScreen → providers

- **Location**: `features/home/presentation/screens/home_screen.dart`
- **Description**:
  - Change `StatelessWidget` → `ConsumerWidget`
  - Replace `sessionsCompleted: 2`, `totalSessions: 4`, `volumeCompleted: 12.5`, `totalVolume: 25.0` in `WeekProgressCard` with values from `ref.watch(weekProgressProvider)`
  - Replace `l10n.homePlanName` with `ref.watch(userProfileDisplayProvider).planName`
  - Replace `l10n.homeWeekInfo` with `ref.watch(userProfileDisplayProvider).weekInfo`
  - Replace `l10n.homeWorkoutSessionType/Name/Duration/Distance/TargetGuidance` with fields from `ref.watch(trainingPlanProvider).todaySession`
  - Replace `l10n.homeUpNextSessionName/DayLabel/Duration/EffortLabel` with fields from `ref.watch(trainingPlanProvider).nextUpcomingSession`
- **Dependencies**: Tasks 3.1, 3.3
- **Acceptance Criteria**:
  - `WeekProgressCard` receives computed values
  - `WorkoutHeroCard` and `UpNextRowCard` receive data from provider
- **Validation**: Hot reload shows correct session data

---

### Task 4.2: WeeklyPlanScreen → providers

- **Location**: `features/weekly_plan/presentation/screens/weekly_plan_screen.dart`
- **Description**:
  - Move private `_SessionData`, `_SessionType`, `_SessionStatus` to use the domain models from Sprint 1
  - Change `StatelessWidget` → `ConsumerWidget`
  - Replace inline `sessions` list in `build()` with `ref.watch(trainingPlanProvider).currentWeekSessions`
  - Replace hardcoded `weeklyPlanTitle('1', '12')` arguments with values from `ref.watch(trainingPlanProvider)` (weekNumber and the Monday date number)
- **Dependencies**: Tasks 3.1, 1.1, 1.2
- **Acceptance Criteria**:
  - No `_SessionData`, `_SessionType`, `_SessionStatus` private enums remain in the file
  - Week title shows provider data
- **Validation**: Hot reload shows same weekly schedule

---

### Task 4.3: ProgressScreen → providers

- **Location**: `features/progress/presentation/screens/progress_screen.dart`
- **Description**:
  - Change `StatelessWidget` → `ConsumerWidget`
  - Remove inline `_RecentSession` list in `build()`, replace with `ref.watch(recentSessionsProvider)`
  - Replace `streakWeeks: 5` in `StreakBanner` with `ref.watch(userStatsProvider).streakWeeks`
  - Replace hardcoded stat values (65.2, 6/15, 4, 10) with fields from `ref.watch(userStatsProvider)`
  - Move `_WeekData` static const list in `_VolumeChartCardState` → `ref.watch(weeklyVolumeProvider)`; pass data down via constructor
  - Replace hardcoded Y-axis labels `'46 km'`, `'23 km'`, `'0 km'` with computed values from the max distance in `weeklyVolumeProvider`
  - Remove private `_RecentSession` class from the file
- **Dependencies**: Tasks 3.2, 1.6, 1.7
- **Acceptance Criteria**:
  - No literal numeric stats remain in `ProgressScreen`
  - Chart reads from provider
- **Validation**: Hot reload shows same stats and chart

---

### Task 4.4: SettingsScreen → provider

- **Location**: `features/settings/presentation/screens/settings_screen.dart`
- **Description**:
  - Change `StatelessWidget` → `ConsumerWidget`
  - Replace `l10n.settingsProfileName`, `l10n.settingsPlanBadge`, `l10n.settingsWeekInfo` in `ProfileCard` with `ref.watch(userProfileDisplayProvider)` fields
- **Dependencies**: Task 3.3
- **Validation**: Settings screen shows 'User Name', 'Half Marathon Plan', 'Week 4 of 12' from provider

---

## Sprint 5: l10n Cleanup & Audit

**Goal**: Remove mock values from translation files, add missing keys, and have 100% of visible UI strings go through `AppLocalizations`.
**Demo/Validation**: Switch app to Spanish — all strings previously using l10n still translate, all previously hardcoded strings that have been moved to l10n also show in Spanish.

### Task 5.1: Remove mock data from l10n

- **Location**: `lib/l10n/app_localizations_en.dart`, `app_localizations_es.dart`, `app_localizations.dart` base
- **Description**: Delete keys that are no longer read from l10n because screens now use providers:
  - `homePlanName`, `homeWeekInfo`
  - `homeWorkoutSessionType`, `homeWorkoutSessionName`, `homeWorkoutDuration`, `homeWorkoutDistance`, `homeWorkoutTargetGuidance`
  - `homeUpNextSessionName`, `homeUpNextDayLabel`, `homeUpNextDuration`, `homeUpNextEffortLabel`
  - `settingsProfileName`, `settingsPlanBadge`, `settingsWeekInfo`
- **Note**: Also remove the corresponding `abstract String get ...` in the base `AppLocalizations` class and the Spanish overrides.
- **Dependencies**: Sprint 4 tasks complete (screens no longer reference these keys)
- **Validation**: `flutter pub run build_runner build` (or `flutter analyze`) shows no unused l10n keys and no missing references

---

### Task 5.2: Add l10n key for onboarding step counter

- **Location**: `lib/l10n/app_localizations_en.dart`, `app_localizations_es.dart`
- **Description**: Add parameterized getter:
  ```dart
  // app_en.arb  →  "onboardingStep": "{step} / {total}"
  String onboardingStep(int step, int total) => '$step / $total';
  ```
  In Spanish: same format (`'$step / $total'`) since numeric fractions are language-neutral — but add the key anyway for completeness.
- **Validation**: Key resolves in both locales

---

### Task 5.3: Replace hardcoded step strings in all 9 onboarding screens

- **Location**: 9 files:
  - `onboarding/presentation/screens/goal_screen.dart` ('1 / 9')
  - `onboarding/presentation/screens/current_fitness_screen.dart` ('2 / 9')
  - `onboarding/presentation/screens/schedule_screen.dart` ('3 / 9')
  - `onboarding/presentation/screens/health_injury_screen.dart` ('4 / 9')
  - `onboarding/presentation/screens/training_preferences_screen.dart` ('5 / 9')
  - `onboarding/presentation/screens/watch_device_screen.dart` ('6 / 9')
  - `onboarding/presentation/screens/recovery_lifestyle_screen.dart` ('7 / 9')
  - `onboarding/presentation/screens/motivation_screen.dart` ('8 / 9')
  - `onboarding/presentation/screens/summary_screen.dart` ('9 / 9')
- **Description**: Replace each literal (e.g. `'1 / 9'`) with `l10n.onboardingStep(1, 9)`
- **Dependencies**: Task 5.2
- **Validation**: Step indicator renders identically; Spanish still shows numbers

---

### Task 5.4: Audit remaining hardcoded strings in screens

- **Location**: All files under `features/` and `core/widgets/`
- **Description**: Run `grep -rn "Text('" features/ core/widgets/ | grep -v l10n` to find any remaining `Text('...')` with literal strings not routed through l10n. For each hit:
  - If it's a pure label/UI copy → add key to both arb files and replace
  - If it's a data-driven value (a number, a formatted date) → leave it — these should be computed values from providers, not translated strings
  - Known remaining hits to handle: chart Y-axis labels `'46 km'`, `'23 km'`, `'0 km'` in `ProgressScreen` (these are computed from `weeklyVolumeProvider.maxDistance`, not hardcoded strings — handled in Task 4.3)
- **Validation**: `grep` output returns zero literal UI copy strings in feature screens

---

## Testing Strategy

- **Compile check after each sprint**: `flutter analyze` must pass with zero errors
- **Visual smoke test**: Hot-reload app after each screen wiring task, confirm no visual regression vs current state
- **Locale switch test (Sprint 5)**: In `SettingsScreen` or device settings, switch to Spanish. All UI strings that go through l10n must switch. Provider-sourced strings (names, distances) remain in their current format.
- **Provider isolation**: Each provider can be overridden in a `ProviderScope` `overrides` list for future widget tests.

---

## File Structure After Completion

```
apps/mobile/lib/
├── features/
│   ├── training_plan/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── session_type.dart       (new - Task 1.1)
│   │   │       ├── training_session.dart   (new - Task 1.2)
│   │   │       ├── training_plan.dart      (new - Task 1.3)
│   │   │       └── week_progress.dart      (new - Task 1.4)
│   │   ├── data/
│   │   │   └── training_plan_seed_data.dart (new - Task 2.1)
│   │   └── presentation/
│   │       └── training_plan_provider.dart  (new - Task 3.1)
│   ├── progress/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── user_stats.dart          (new - Task 1.5)
│   │   │       ├── weekly_volume_data.dart  (new - Task 1.6)
│   │   │       └── recent_session.dart      (new - Task 1.7)
│   │   ├── data/
│   │   │   └── progress_seed_data.dart      (new - Task 2.2)
│   │   └── presentation/
│   │       ├── progress_provider.dart       (new - Task 3.2)
│   │       └── screens/progress_screen.dart (updated - Task 4.3)
│   ├── user_preferences/
│   │   └── presentation/
│   │       └── user_preferences_provider.dart (updated - Task 3.3)
│   ├── home/presentation/screens/
│   │   └── home_screen.dart                 (updated - Task 4.1)
│   ├── weekly_plan/presentation/screens/
│   │   └── weekly_plan_screen.dart          (updated - Task 4.2)
│   └── settings/presentation/screens/
│       └── settings_screen.dart             (updated - Task 4.4)
└── l10n/
    ├── app_localizations.dart               (updated - Tasks 5.1, 5.2)
    ├── app_localizations_en.dart            (updated - Tasks 5.1, 5.2)
    └── app_localizations_es.dart            (updated - Tasks 5.1, 5.2)
```

---

## Potential Risks & Gotchas

- **`_VolumeChartCard` is a `StatefulWidget`** — it manages `_selectedIndex` locally. When wiring to the provider in Task 4.3, the `_weeks` list must be passed as a constructor parameter (not read directly from `ref`) to keep the existing selection logic intact. Convert to `ConsumerStatefulWidget`.

- **`TrainingPlan.todaySession` might be null** — if the seed data doesn't include a session matching today's date exactly, `HomeScreen` will get `null`. Guard with a fallback or ensure the seed data always sets one session's `status = today` regardless of date.

- **l10n generated files** — `app_localizations_en.dart` and `app_localizations_es.dart` are auto-generated from `.arb` files. You must edit the `.arb` source files (`lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`), then re-run `flutter gen-l10n` to regenerate. Do **not** edit the `_en.dart` and `_es.dart` files directly or changes will be overwritten.

- **Private enums in WeeklyPlanScreen** — `_SessionType` and `_SessionStatus` are currently private. Task 4.2 replaces them with the domain enums. The `_trailingIcon()` helper method's logic should be moved to a getter on `SessionType` (Task 1.1), not left in the screen.

- **Unit formatting** — `distanceKm` values from models need to respect the user's `UnitSystem` preference. Use the existing `UnitFormatter` utility when displaying distances in screens. The seed data stores raw km values; display conversion happens at the widget layer.

## Rollback Plan

- All new files (Sprint 1-3) are purely additive — delete them to revert.
- Screen changes (Sprint 4) can be reverted individually via `git checkout <file>`.
- l10n changes (Sprint 5) are the most coupled — complete Sprint 4 before touching l10n, so the app is never in a broken state.
