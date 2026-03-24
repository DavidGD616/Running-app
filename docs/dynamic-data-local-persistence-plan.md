# Plan: Dynamic Data with Local Persistence

**Generated**: 2026-03-22
**Estimated Complexity**: Medium

## Overview

The app currently has two problems:
1. User selections (units, gender, DOB, all onboarding answers) are lost on every app restart — there is no persistence layer
2. Static data like race distances is hardcoded in miles, ignoring the unit preference the user picks

This plan introduces `shared_preferences` as the local storage layer, wires it to Riverpod providers, and makes every screen that displays unit-sensitive data react to the user's preference. The approach is **local-first**: no backend needed, everything works offline and survives restarts.

**Key assumptions made (no clarification needed):**
- Units preference lives in `AccountSetupScreen` (km/miles) — this is the source of truth
- Race distances in `GoalScreen` ("3.1 miles", "6.2 miles", etc.) update based on the unit preference
- All onboarding answers persist so the user never re-does setup
- SharedPreferences is the persistence layer (simpler than Hive for this data shape)
- A settings screen is out of scope for this sprint

## Prerequisites

- Flutter SDK ^3.11.1 (already installed)
- `flutter_riverpod: ^2.6.1` (already in pubspec.yaml)
- `shared_preferences` package (needs to be added — free, official Flutter plugin)

---

## Sprint 1: Foundation — Add SharedPreferences & User Preferences Provider

**Goal**: Add the persistence package, create a `UserPreferencesNotifier` that reads/writes from SharedPreferences on startup, and expose a clean `unitSystem` value (km vs miles) to the whole app.

**Demo/Validation**:
- Hot restart the app → unit preference is still the same as before restart
- Change unit to miles → restart → still miles

---

### Task 1.1: Add `shared_preferences` to pubspec.yaml

- **Location**: [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml)
- **Description**: Add `shared_preferences: ^2.3.0` under `dependencies`
- **Dependencies**: None
- **Acceptance Criteria**:
  - `flutter pub get` runs without errors
- **Validation**:
  - Run `flutter pub get` in `apps/mobile/`

---

### Task 1.2: Create `UserPreferences` model

- **Location**: `apps/mobile/lib/features/user_preferences/domain/user_preferences.dart` *(new file)*
- **Description**: Create a simple immutable data class:
  ```dart
  enum UnitSystem { km, miles }

  class UserPreferences {
    final UnitSystem unitSystem;
    final String? gender;
    final DateTime? dateOfBirth;

    const UserPreferences({
      this.unitSystem = UnitSystem.km,
      this.gender,
      this.dateOfBirth,
    });

    UserPreferences copyWith({
      UnitSystem? unitSystem,
      String? gender,
      DateTime? dateOfBirth,
    }) => UserPreferences(
      unitSystem: unitSystem ?? this.unitSystem,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
  ```
- **Dependencies**: None
- **Acceptance Criteria**:
  - Model compiles with no errors
  - `copyWith` correctly merges fields

---

### Task 1.3: Create `UserPreferencesNotifier` with SharedPreferences persistence

- **Location**: `apps/mobile/lib/features/user_preferences/presentation/user_preferences_provider.dart` *(new file)*
- **Description**: Create an `AsyncNotifier` that:
  1. On `build()`: calls `SharedPreferences.getInstance()`, reads saved keys, returns a `UserPreferences` object
  2. Exposes a `setUnitSystem(UnitSystem)` method that updates state AND writes to SharedPreferences
  3. Exposes `setGender(String)` and `setDateOfBirth(DateTime)` similarly

  ```dart
  class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
    static const _keyUnit = 'pref_unit_system';
    static const _keyGender = 'pref_gender';
    static const _keyDob = 'pref_dob_ms';

    @override
    Future<UserPreferences> build() async {
      final prefs = await SharedPreferences.getInstance();
      final unitRaw = prefs.getString(_keyUnit);
      final gender = prefs.getString(_keyGender);
      final dobMs = prefs.getInt(_keyDob);
      return UserPreferences(
        unitSystem: unitRaw == 'miles' ? UnitSystem.miles : UnitSystem.km,
        gender: gender,
        dateOfBirth: dobMs != null
            ? DateTime.fromMillisecondsSinceEpoch(dobMs)
            : null,
      );
    }

    Future<void> setUnitSystem(UnitSystem unit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUnit, unit.name);
      state = AsyncData(
        (state.valueOrNull ?? const UserPreferences()).copyWith(unitSystem: unit),
      );
    }

    // setGender and setDateOfBirth follow the same pattern
  }

  final userPreferencesProvider =
      AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
    UserPreferencesNotifier.new,
  );
  ```
- **Dependencies**: Task 1.1, Task 1.2
- **Acceptance Criteria**:
  - On first launch, defaults to `UnitSystem.km`
  - After calling `setUnitSystem(UnitSystem.miles)` and hot-restarting, the provider loads `miles`
- **Validation**:
  - Add a temporary `print` in `build()` and confirm it logs the correct value after restart

---

### Task 1.4: Pre-warm SharedPreferences in `main.dart`

- **Location**: [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart)
- **Description**: Call `WidgetsFlutterBinding.ensureInitialized()` and optionally pre-warm SharedPreferences before `runApp` so the first frame has data:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const ProviderScope(child: RunningApp()));
  }
  ```
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - App launches without async init errors
- **Validation**:
  - App runs on simulator without errors

---

## Sprint 2: Wire AccountSetupScreen to UserPreferencesNotifier

**Goal**: The unit (km/miles), gender, and date of birth selected in `AccountSetupScreen` are saved to SharedPreferences via the provider. After setup, these values persist across restarts.

**Demo/Validation**:
- Complete account setup with miles + Female + DOB
- Kill and reopen the app
- Navigate back to account setup → shows the previously saved values pre-filled

---

### Task 2.1: Convert `AccountSetupScreen` to `ConsumerStatefulWidget`

- **Location**: [apps/mobile/lib/features/account_setup/presentation/screens/account_setup_screen.dart](apps/mobile/lib/features/account_setup/presentation/screens/account_setup_screen.dart)
- **Description**:
  - Change `StatefulWidget` → `ConsumerStatefulWidget`
  - Change `State` → `ConsumerState`
  - In `initState`, read from `ref.read(userPreferencesProvider)` to pre-populate `_unitIndex`, `_genderIndex`, `_dateOfBirth`
  - On the "Continue" button tap, call:
    ```dart
    final notifier = ref.read(userPreferencesProvider.notifier);
    await notifier.setUnitSystem(_unitIndex == 0 ? UnitSystem.km : UnitSystem.miles);
    await notifier.setGender(['Male', 'Female', 'Other'][_genderIndex]);
    if (_dateOfBirth != null) await notifier.setDateOfBirth(_dateOfBirth!);
    ```
- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Tapping Continue saves all three fields
  - Re-opening the screen shows previously saved values
- **Validation**:
  - Save miles → restart → open AccountSetupScreen → unit toggle shows "mi" selected

---

## Sprint 3: Unit-Aware UI — Race Distances & Pace Labels

**Goal**: Anywhere the app shows distances or pace, it reads the unit preference and displays the correct unit. The primary place is the race cards in `GoalScreen`.

**Demo/Validation**:
- Set unit to km → go to Goal screen → races show "5 km", "10 km", "21.1 km", "42.2 km"
- Set unit to miles → go to Goal screen → races show "3.1 mi", "6.2 mi", "13.1 mi", "26.2 mi"

---

### Task 3.1: Create a `UnitFormatter` utility

- **Location**: `apps/mobile/lib/core/utils/unit_formatter.dart` *(new file)*
- **Description**: A pure utility with static methods so any widget can format distances:
  ```dart
  class UnitFormatter {
    static String raceDistance(String raceName, UnitSystem unit) {
      const km = {
        '5K': '5 km',
        '10K': '10 km',
        'Half Marathon': '21.1 km',
        'Marathon': '42.2 km',
        'Other': 'Custom distance',
      };
      const mi = {
        '5K': '3.1 mi',
        '10K': '6.2 mi',
        'Half Marathon': '13.1 mi',
        'Marathon': '26.2 mi',
        'Other': 'Custom distance',
      };
      return unit == UnitSystem.km
          ? (km[raceName] ?? raceName)
          : (mi[raceName] ?? raceName);
    }

    static String unitLabel(UnitSystem unit) =>
        unit == UnitSystem.km ? 'km' : 'mi';

    static String paceLabel(UnitSystem unit) =>
        unit == UnitSystem.km ? 'min/km' : 'min/mi';
  }
  ```
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - All race names return correct values for both unit systems
- **Validation**:
  - Manual check: `UnitFormatter.raceDistance('5K', UnitSystem.miles)` == `'3.1 mi'`

---

### Task 3.2: Make `GoalScreen` race subtitles unit-aware

- **Location**: [apps/mobile/lib/features/onboarding/presentation/screens/goal_screen.dart](apps/mobile/lib/features/onboarding/presentation/screens/goal_screen.dart)
- **Description**:
  - `GoalScreen` is already a `ConsumerStatefulWidget` — add a `ref.watch(userPreferencesProvider)` call in `build()`
  - Replace the hardcoded `_Race` subtitle strings with calls to `UnitFormatter.raceDistance(name, unitSystem)`
  - Handle the async state (show default km while preferences load)
  - The `_races` list becomes:
    ```dart
    List<_Race> _buildRaces(UnitSystem unit) => [
      _Race('5K', UnitFormatter.raceDistance('5K', unit), 'assets/icons/flame.svg'),
      _Race('10K', UnitFormatter.raceDistance('10K', unit), 'assets/icons/flame.svg'),
      _Race('Half Marathon', UnitFormatter.raceDistance('Half Marathon', unit), 'assets/icons/trophy.svg'),
      _Race('Marathon', UnitFormatter.raceDistance('Marathon', unit), 'assets/icons/medal.svg'),
      _Race('Other', UnitFormatter.raceDistance('Other', unit), 'assets/icons/mountain.svg'),
    ];
    ```
- **Dependencies**: Task 3.1, Task 2.1
- **Acceptance Criteria**:
  - Distances update immediately when unit preference changes
  - No hardcoded "miles" or "km" strings remain in this file
- **Validation**:
  - Change unit in AccountSetupScreen → navigate to GoalScreen → distances reflect new unit

---

### Task 3.3: Make `CurrentFitnessScreen` weekly volume options unit-aware

- **Location**: [apps/mobile/lib/features/onboarding/presentation/screens/current_fitness_screen.dart](apps/mobile/lib/features/onboarding/presentation/screens/current_fitness_screen.dart)
- **Description**: The weekly volume and longest run options likely show distances (e.g. "20-30 km" or "12-18 mi"). Read `userPreferencesProvider` and swap the option strings accordingly.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Volume/distance labels match the selected unit system
- **Validation**:
  - Switch units → options update

---

## Sprint 4: Persist Onboarding Answers

**Goal**: The `onboardingProvider` data currently lives in memory only. After completing onboarding, answers are saved to SharedPreferences so the app can check "has the user done onboarding?" and skip it on re-launch.

**Demo/Validation**:
- Complete full onboarding → kill app → reopen → goes directly to Home screen (not onboarding)
- Summary screen shows all the same answers as before

---

### Task 4.1: Add onboarding completion flag to `OnboardingNotifier`

- **Location**: [apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart](apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart)
- **Description**:
  - Add `static const _keyCompleted = 'onboarding_completed'`
  - Add a `markCompleted()` method that saves a bool flag to SharedPreferences
  - Add a static `Future<bool> isCompleted()` helper that reads that flag:
    ```dart
    static Future<bool> isCompleted() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyCompleted) ?? false;
    }

    Future<void> markCompleted() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCompleted, true);
    }
    ```
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - After `markCompleted()` is called, `isCompleted()` returns `true`
  - Survives app restart
- **Validation**:
  - Call `markCompleted()` → restart → `isCompleted()` returns `true`

---

### Task 4.2: Call `markCompleted()` from `PlanGenerationScreen` (or `SummaryScreen`)

- **Location**: [apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart](apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart)
- **Description**: When the user successfully generates their plan (or taps "Build My Plan"), call:
  ```dart
  await ref.read(onboardingProvider.notifier).markCompleted();
  context.go(RouteNames.home);
  ```
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - After plan generation, onboarding is marked complete

---

### Task 4.3: Add onboarding skip logic to `app_router.dart`

- **Location**: [apps/mobile/lib/core/router/app_router.dart](apps/mobile/lib/core/router/app_router.dart)
- **Description**: Add a redirect on the splash/welcome route that checks `OnboardingNotifier.isCompleted()` and routes directly to home if true:
  ```dart
  redirect: (context, state) async {
    final completed = await OnboardingNotifier.isCompleted();
    if (completed && state.matchedLocation == '/') {
      return RouteNames.home;
    }
    return null;
  },
  ```
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - First launch → shows welcome/onboarding
  - After completing onboarding → subsequent launches go straight to home
- **Validation**:
  - Complete onboarding → kill app → relaunch → lands on home screen

---

## Testing Strategy

| Sprint | How to test |
|--------|-------------|
| Sprint 1 | Hot-restart app, check `print` logs in notifier `build()` |
| Sprint 2 | Set miles in AccountSetupScreen → restart → confirm "mi" is selected |
| Sprint 3 | Toggle unit → navigate to GoalScreen → verify distances change |
| Sprint 4 | Complete full onboarding → kill app → relaunch → confirm home screen |

---

## Potential Risks & Gotchas

1. **`AsyncNotifier` first frame flicker** — `userPreferencesProvider` is async, so on first render the unit is `null`. Use `userPreferencesProvider.select(...)` with a default fallback (`UnitSystem.km`) in widgets to avoid showing wrong distances for a frame.

2. **`account_setup_screen.dart` currently uses `setState` with index** — When converting to `ConsumerStatefulWidget`, `initState` cannot call `ref.watch` — use `ref.read` there and move reactive reads to `build()`.

3. **SharedPreferences is async but widgets are sync** — All writes are fire-and-forget (don't `await` in UI callbacks). The Riverpod state updates immediately (optimistic update), and the disk write happens asynchronously.

4. **`onboarding_provider` data is `Map<String, dynamic>` with no type safety** — Leaving it as-is for now is fine; adding typed models would be a separate refactor and is out of scope.

5. **Router redirect is async** — GoRouter's `redirect` callback supports async in newer versions, but double-check the `go_router: ^14.0.0` API. If async redirect isn't supported, use a `FutureProvider` for the completed state and watch it in the redirect instead.

---

## Rollback Plan

- All changes are additive (new files + modifications to existing screens)
- To revert: delete the new `user_preferences/` folder, revert `account_setup_screen.dart` and `goal_screen.dart` to their current form, and remove `shared_preferences` from pubspec.yaml
- SharedPreferences data can be cleared via device Settings > App > Clear Data
