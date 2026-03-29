# Dynamic Phase Text via ARB Placeholders

## Problem

Workout phase strings in the session detail screen have hardcoded numbers:
- `"6 × 400 m at hard effort · RPE 8–9"` — reps and rep distance
- `"90 s easy jog recovery between each rep"` — recovery seconds
- `"22 min"`, `"55 min"`, etc. — main phase durations

If the plan changes (e.g. 8×400m instead of 6), the ARB files would need to be updated manually, breaking translations.

## Solution

Use Flutter's ARB placeholder system so text templates live in translations and numbers come from session data.

**Example:**
```json
"sessionPhaseIntervalsMainNote": "{reps} × {repDistance} at hard effort · RPE 8–9"
```
Numbers come from `TrainingSession` fields → change the plan, all translations update automatically.

---

## Step 1 — New fields on `TrainingSession`

File: `lib/features/training_plan/domain/models/training_session.dart`

Add 3 new optional fields:

```dart
final int? intervalReps;            // e.g. 6
final String? intervalRepDistance;  // e.g. "400 m"
final int? intervalRecoverySeconds; // e.g. 90
```

- `durationMinutes` (already exists) drives all 5 main-phase duration strings
- `intervalRepDistance` is a `String` because it's always a pre-formatted display value (`"400 m"`, `"1 km"`)
- Update constructor and `copyWith` with the 3 new params

---

## Step 2 — ARB changes

### Keys that become parameterized (both `app_en.arb` and `app_es.arb`)

**5 main-phase duration keys** — add `minutes` placeholder:

```json
"sessionPhaseEasyRunMainDuration": "{minutes} min",
"@sessionPhaseEasyRunMainDuration": {
  "placeholders": { "minutes": { "type": "int" } }
}
```

Apply same pattern to:
- `sessionPhaseIntervalsMainDuration`
- `sessionPhaseLongRunMainDuration`
- `sessionPhaseRecoveryRunMainDuration`
- `sessionPhaseTempoRunMainDuration`

**Intervals main note** — add `reps` + `repDistance` placeholders:

```json
"sessionPhaseIntervalsMainNote": "{reps} × {repDistance} at hard effort · RPE 8–9",
"@sessionPhaseIntervalsMainNote": {
  "placeholders": {
    "reps": { "type": "int" },
    "repDistance": { "type": "String" }
  }
}
```

**Intervals recovery note** — add `recoverySeconds` placeholder:

```json
"sessionPhaseIntervalsMainRecovery": "{recoverySeconds} s easy jog recovery between each rep",
"@sessionPhaseIntervalsMainRecovery": {
  "placeholders": { "recoverySeconds": { "type": "int" } }
}
```

### Spanish equivalents (`app_es.arb`)

Same 7 keys, same placeholder slots:
- `"{minutes} min"` (same in Spanish)
- `"{reps} × {repDistance} a esfuerzo intenso · RPE 8–9"`
- `"{recoverySeconds} s de trote suave de recuperación entre cada repetición"`

> Warm-up and cool-down durations/notes have no variable numbers — leave them as zero-argument getters.

---

## Step 3 — Seed data

File: `lib/features/training_plan/data/training_plan_seed_data.dart`

Add the 3 new fields to `seed-thu` (intervals session):

```dart
TrainingSession(
  id: 'seed-thu',
  type: SessionType.intervals,
  distanceKm: 6.0,
  durationMinutes: 45,
  effortLabel: 'Hard effort',
  intervalReps: 6,
  intervalRepDistance: '400 m',
  intervalRecoverySeconds: 90,
),
```

Other sessions only need `durationMinutes` which already exists.

---

## Step 4 — Run `flutter gen-l10n`

```bash
flutter gen-l10n
```

Run from `apps/mobile/`. This regenerates the 3 `.dart` l10n files automatically. **Never edit those files by hand.**

---

## Step 5 — Update `_phasesFor()` in session detail screen

File: `lib/features/session_detail/presentation/screens/session_detail_screen.dart`

All 5 duration calls now require an argument:

```dart
l10n.sessionPhaseEasyRunMainDuration(session.durationMinutes ?? 0)
```

Intervals-specific calls:

```dart
l10n.sessionPhaseIntervalsMainNote(
  session.intervalReps ?? 0,
  session.intervalRepDistance ?? '—',
)
l10n.sessionPhaseIntervalsMainRecovery(session.intervalRecoverySeconds ?? 0)
```

---

## Files Changed

| File | Change |
|---|---|
| `lib/features/training_plan/domain/models/training_session.dart` | +3 fields, update constructor + `copyWith` |
| `lib/features/training_plan/data/training_plan_seed_data.dart` | Populate new fields on `seed-thu` |
| `lib/l10n/app_en.arb` | 7 keys gain placeholders |
| `lib/l10n/app_es.arb` | Same 7 keys, Spanish templates |
| `lib/features/session_detail/presentation/screens/session_detail_screen.dart` | 7 call sites in `_phasesFor()` updated |
| `lib/l10n/app_localizations*.dart` | Auto-generated — run `flutter gen-l10n` |

## Execution Order

1. `training_session.dart` — add fields
2. `app_en.arb` + `app_es.arb` — add placeholders
3. Run `flutter gen-l10n`
4. `session_detail_screen.dart` — update call sites
5. `training_plan_seed_data.dart` — populate seed values
