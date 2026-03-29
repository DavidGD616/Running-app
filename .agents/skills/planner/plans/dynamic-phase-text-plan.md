# Dynamic Phase Text via ARB Placeholders

## Purpose

Workout phase strings in the session detail screen contain numbers (reps, distances, durations) that are tied to the specific training plan. If the plan changes — e.g. the intervals session goes from 6×400m to 8×400m, or a run is extended from 22 to 30 minutes — those numbers need to update automatically across all languages without touching the ARB translation files.

The solution is Flutter's ARB placeholder system: translation files hold text templates with named slots (`{minutes}`, `{reps}`, `{repDistance}`, `{recoverySeconds}`), and the actual numbers come from `TrainingSession` model fields at runtime. This means a plan change only requires updating the data — translations stay untouched and remain correct in every language.

---

## Status

**Phase 1 — DONE** (committed `3862ac3`): Main-phase durations + intervals-specific keys parameterized.
**Phase 2 — PENDING**: Warm/cool durations, intervals description, legacy key cleanup.

---

## What Was Implemented (Phase 1)

### Fields added to `TrainingSession`
```dart
final int? intervalReps;
final String? intervalRepDistance;
final int? intervalRecoverySeconds;
```
Seed data `seed-thu` populated: `intervalReps: 6`, `intervalRepDistance: '400 m'`, `intervalRecoverySeconds: 90`.

### ARB keys parameterized (7 keys — both EN + ES)
| Key | Placeholder(s) |
|---|---|
| `sessionPhaseEasyRunMainDuration` | `{minutes}` |
| `sessionPhaseIntervalsMainDuration` | `{minutes}` |
| `sessionPhaseLongRunMainDuration` | `{minutes}` |
| `sessionPhaseRecoveryRunMainDuration` | `{minutes}` |
| `sessionPhaseTempoRunMainDuration` | `{minutes}` |
| `sessionPhaseIntervalsMainNote` | `{reps}`, `{repDistance}` |
| `sessionPhaseIntervalsMainRecovery` | `{recoverySeconds}` |

`_phasesFor()` in `session_detail_screen.dart` updated to pass session fields to all 7 call sites.

---

## Remaining Hardcoded Numbers (Phase 2)

### 1 — Warm-up & cool-down durations (10 keys, same `{minutes}` pattern)

These need the same treatment as the main-phase durations. Requires adding warm/cool duration fields to `TrainingSession` (or reusing a generic approach).

| Key | Current value |
|---|---|
| `sessionPhaseEasyRunWarmDuration` | `"5 min"` |
| `sessionPhaseEasyRunCoolDuration` | `"3 min"` |
| `sessionPhaseIntervalsWarmDuration` | `"10 min"` |
| `sessionPhaseIntervalsCoolDuration` | `"10 min"` |
| `sessionPhaseLongRunWarmDuration` | `"10 min"` |
| `sessionPhaseLongRunCoolDuration` | `"10 min"` |
| `sessionPhaseRecoveryRunWarmDuration` | `"3 min"` |
| `sessionPhaseRecoveryRunCoolDuration` | `"3 min"` |
| `sessionPhaseTempoRunWarmDuration` | `"10 min"` |
| `sessionPhaseTempoRunCoolDuration` | `"10 min"` |

**New fields needed on `TrainingSession`:**
```dart
final int? warmUpMinutes;
final int? coolDownMinutes;
```
Seed data would need `warmUpMinutes` and `coolDownMinutes` per session.

### 2 — Intervals session description (1 key)

```
sessionDescIntervals: "4×800m @ 5K pace. 90s recovery jog between each rep."
```
Has hardcoded reps (4), distance (800m), recovery (90s). Could use `intervalReps`, `intervalRepDistance`, `intervalRecoverySeconds` already on the model.

Proposed placeholder key:
```json
"sessionDescIntervals": "{reps}×{repDistance} @ 5K pace. {recoverySeconds}s recovery jog between each rep.",
"@sessionDescIntervals": {
  "placeholders": {
    "reps": { "type": "int" },
    "repDistance": { "type": "String" },
    "recoverySeconds": { "type": "int" }
  }
}
```
Call site in `session_detail_screen.dart`:
```dart
l10n.sessionDescIntervals(session.intervalReps ?? 0, session.intervalRepDistance ?? '—', session.intervalRecoverySeconds ?? 0)
```

### 3 — Legacy `sessionDetail*` keys (6 keys — delete or ignore)

These appear to be leftover mock keys from before the screen rewrite. Verify they are unused, then delete.

| Key | Value |
|---|---|
| `sessionDetailSessionName` | `"6 km Intervals"` |
| `sessionDetailDistanceValue` | `"6.0 km"` |
| `sessionDetailDurationValue` | `"45 min"` |
| `sessionDetailWarmUpDuration` | `"10 min"` |
| `sessionDetailIntervalsDuration` | `"5 × 3 min"` |
| `sessionDetailIntervalsRecovery` | `"2 min recovery between sets"` |

---

## Phase 2 Execution Order

1. Add `warmUpMinutes` + `coolDownMinutes` to `TrainingSession` (constructor + `copyWith`)
2. Populate warm/cool minutes in seed data for all 5 session types
3. Update 10 warm/cool ARB keys in `app_en.arb` + `app_es.arb` with `{minutes}` placeholder
4. Update `sessionDescIntervals` in both ARB files with 3 placeholders
5. Run `flutter gen-l10n`
6. Update all 10 warm/cool duration call sites + `sessionDescIntervals` call site in `_phasesFor()`
7. Verify legacy keys are unused → delete from both ARB files

## Files to Change (Phase 2)

| File | Change |
|---|---|
| `lib/features/training_plan/domain/models/training_session.dart` | +2 fields (`warmUpMinutes`, `coolDownMinutes`) |
| `lib/features/training_plan/data/training_plan_seed_data.dart` | Populate warm/cool minutes on all sessions |
| `lib/l10n/app_en.arb` | 11 keys gain placeholders; 6 legacy keys deleted |
| `lib/l10n/app_es.arb` | Same |
| `lib/features/session_detail/presentation/screens/session_detail_screen.dart` | 11 call sites updated |
| `lib/l10n/app_localizations*.dart` | Auto-generated — run `flutter gen-l10n` |
