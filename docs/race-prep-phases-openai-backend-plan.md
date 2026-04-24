# Plan: Race Prep Phases with OpenAI Drafting and Backend Validation

**Generated**: 2026-04-24
**Estimated Complexity**: Medium

## Overview
Improve generated training plans by making OpenAI aware of race-prep phases while keeping backend rules as the final source of truth. OpenAI should draft a plan with better coaching shape, workout variety, and phase-specific intent. The backend should compute the same phases deterministically and validate the plan for safe, consistent structure.

The initial implementation is backend-only from the mobile app perspective. Flutter keeps receiving normal sessions. Phase labels do not need to appear in the UI yet.

Use 5 practical race-prep phases:

- `base`
- `build`
- `specific`
- `peak`
- `taperRace`

Do not implement post-race recovery yet. That is a separate product feature after race completion exists.

## Prerequisites
- Current `generate-plan` Edge Function passes Deno checks and tests.
- New generated plans are the main target; old saved plans do not need migration for this sprint.
- OpenAI remains responsible for the first draft.
- Backend remains responsible for validation and correction.

## Sprint 1: Phase Model and Prompt Guidance
**Goal**: Tell OpenAI how to structure plans by phase, without changing saved JSON shape yet.

**Demo/Validation**:
- Generated prompt clearly explains phase purpose.
- No mobile model changes.
- Deno checks pass.

### Task 1.1: Add Phase Guidance Text to OpenAI Prompt
- **Location**: `supabase/functions/generate-plan/openai.ts`
- **Description**: Add a concise phase model to `systemPrompt`.
- **Dependencies**: None
- **Status**: ✅ COMPLETED
- **Work Log**: 2026-04-23 - Added phase guidance block to systemPrompt in openai.ts. Prompt now explains base, build, specific, peak, taperRace phases with one-sentence descriptions. Does not require OpenAI to return a phase field.
- **Files Modified**: `supabase/functions/generate-plan/openai.ts`
- **Acceptance Criteria**:
  - ✅ Prompt says plans should follow `base`, `build`, `specific`, `peak`, `taperRace`.
  - ✅ Prompt explains each phase in one short sentence.
  - ✅ Prompt does not require OpenAI to return a `phase` field yet.
- **Validation**:
  - ✅ `deno check index.ts` passes

Suggested prompt block:

```text
Structure the plan using race-prep phases:
base, build, specific, peak, taperRace.

Base: easy aerobic running, routine, and gradual long-run habit.
Build: increase weekly load and introduce controlled quality.
Specific: use race-relevant workouts and long-run development.
Peak: highest useful workload, including the peak long run.
TaperRace: reduce volume, keep light sharpness, and prepare for race/test day.
```

### Task 1.2: Add Internal Backend Phase Types
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Add:
  - `type RacePrepPhase = "base" | "build" | "specific" | "peak" | "taperRace"`
  - `phaseForWeek(weekNumber, totalWeeks, profileData)`
  - `phasePlanFor(totalWeeks, profileData)`
- **Dependencies**: None
- **Acceptance Criteria**:
  - Backend can compute a phase for any week.
  - Phase calculation does not depend on OpenAI output.
  - Final week is always `taperRace`.
- **Validation**:
  - Add unit tests in `supabase/functions/generate-plan/plan-rules_test.ts`.
- **Status**: COMPLETE
- **Work Log**: 2026-04-23
  - Implemented `RacePrepPhase` type with five values: "base", "build", "specific", "peak", "taperRace".
  - Implemented `phaseForWeek(weekNumber, totalWeeks, profileData)` returning phase for any week number.
  - Implemented `phasePlanFor(totalWeeks, profileData)` returning an array of phases for all weeks.
  - Added `phaseAllocationFor(totalWeeks)` with fixed allocations for 8/12/16/20 weeks and proportional scaling for other lengths.
  - Added `proportionalPhaseAllocation()` for non-standard plan lengths.
  - Added 14 unit tests covering all standard plan lengths and final-week taperRace guarantee.
- **Files Modified**:
  - `supabase/functions/generate-plan/plan-rules.ts` (added 50 lines)
  - `supabase/functions/generate-plan/plan-rules_test.ts` (added 14 tests)
- **Verification**: `deno test plan-rules_test.ts` — 38 tests passed, 0 failed.

### Task 1.3: Define Phase Allocation by Plan Length
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Implement phase allocation:
  - 8 weeks: 2 base, 2 build, 2 specific, 1 peak, 1 taperRace
  - 12 weeks: 3 base, 3 build, 3 specific, 1 peak, 2 taperRace
  - 16 weeks: 4 base, 4 build, 4 specific, 2 peak, 2 taperRace
  - 20 weeks: 5 base, 5 build, 5 specific, 3 peak, 2 taperRace
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Shorter or unusual plan lengths scale proportionally.
  - No phase assignment produces gaps.
- **Validation**:
  - Tests for 8, 12, 16, 20 week plans.

## Sprint 2: Peak Long Run Rules
**Goal**: Ensure each plan reaches a professional peak long run for the selected race and runner experience.

**Demo/Validation**:
- Beginner marathon plan no longer peaks too low.
- Shorter race plans use appropriate peak long runs.
- Race day remains separate from long-run peak.

### Task 2.1: Add Peak Long Run Range Table
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Add `peakLongRunRangeKm(profileData)` returning `{ minKm, targetKm, maxKm }`.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - 5K:
    - beginner target 5 km
    - intermediate target 8-10 km
    - experienced target 10-12 km
  - 10K:
    - beginner target 8-10 km
    - intermediate target 12-13 km
    - experienced target 13-16 km
  - Half marathon:
    - beginner target 13-16 km
    - intermediate target 16-18 km
    - experienced target 18-21 km
  - Marathon:
    - beginner target 26-28 km, max 30 km
    - intermediate target 30-32 km
    - experienced target 32-34 km
- **Validation**:
  - Unit tests for each race type and experience group.
- **Status**: COMPLETE
- **Work Log**: 2026-04-23
  - Added `peakLongRunRangeKm(profileData)` returning `{ minKm, targetKm, maxKm }`.
  - Implemented range table for all race types: 5K, 10K, half marathon, marathon.
  - Implemented ranges for all experience levels: beginner, intermediate, experienced.
  - Added 12 unit tests covering all combinations.
- **Files Modified**:
  - `supabase/functions/generate-plan/plan-rules.ts` (added peakLongRunRangeKm function and helper extractors)
  - `supabase/functions/generate-plan/plan-rules_test.ts` (added 12 unit tests)
- **Verification**: `deno test plan-rules_test.ts` — 68 tests passed, 1 pre-existing failure unrelated to this task.

### Task 2.2: Normalize Peak Long Run
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`, `supabase/functions/generate-plan/index.ts`
- **Description**: Add `normalizePeakLongRun(sessions, profileData, totalWeeks, locale)`.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Finds the best `longRun` in `peak` phase.
  - Raises peak long run when OpenAI undershoots.
  - Caps peak long run when OpenAI overshoots.
  - Does not touch final race/test session.
  - Keeps preferred long-run day.
- **Validation**:
  - Beginner marathon example: 20 km peak becomes about 28 km.
  - Intermediate 10K example: 8 km peak becomes about 13 km.
  - Half marathon cap test.

### Task 2.3: Recalculate Duration When Distance Changes
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Recalculate `durationMinutes` when long-run distance changes.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Uses nearby long-run pace when possible.
  - Falls back to conservative easy pace when no useful reference exists.
  - Avoids stale duration after distance edits.
- **Validation**:
  - Unit test verifies distance and duration update together.

## Sprint 3: Progression and Taper Validation
**Goal**: Prevent plans from looking mathematically correct but coaching-poor.

**Demo/Validation**:
- Long runs progress smoothly.
- Down weeks exist.
- Taper weeks reduce load before final race/test.

### Task 3.1: Smooth Long Run Progression
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Add `smoothLongRunProgression(sessions, profileData, totalWeeks, locale)`.
- **Dependencies**: Sprint 2
- **Acceptance Criteria**:
  - 5K/10K long-run jumps stay around 2 km max.
  - Half marathon jumps stay around 3 km max.
  - Marathon jumps stay around 3-4 km max.
  - Down weeks are preserved instead of flattened.
- **Validation**:
  - Tests for excessive jumps.
  - Tests that planned cutback weeks still exist.

### Task 3.2: Enforce Taper Shape
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Add `normalizeTaper(sessions, profileData, totalWeeks, locale)`.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Marathon taper reduces long run and total load in final 2 weeks.
  - Half marathon taper is shorter than marathon taper.
  - 5K/10K taper keeps light sharpening but lowers volume.
  - Final race/test remains exact goal distance.
- **Validation**:
  - Tests for marathon peak -> taper -> race.
  - Tests for 5K/10K keeping a light quality workout before race week.

### Task 3.3: Wire Validation Pipeline
- **Location**: `supabase/functions/generate-plan/index.ts`
- **Description**: Update rule pipeline to run phase validations before final race and stride cleanup.
- **Dependencies**: Tasks 2.2, 3.1, 3.2
- **Acceptance Criteria**:
  - Suggested order:
    `normalizeTrainingDayCount -> placeLongRunsOnPreferredDay -> spaceStressfulSessions -> avoidHardDayTraining -> ensureFullCalendarWeeks -> normalizePeakLongRun -> smoothLongRunProgression -> normalizeTaper -> ensureGoalRaceSession -> addStrideDefaults -> buildWorkoutSteps`
  - Full-calendar weeks remain intact.
  - Hard days remain respected.
- **Validation**:
  - Full Deno test suite.

## Sprint 4: Phase-Aware Workout Mix
**Goal**: Make workout type selection match the phase and runner level.

**Demo/Validation**:
- Beginners do not get advanced hard workouts too early.
- Experienced runners still receive specific work.

### Task 4.1: Add Phase Workout Policy
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`
- **Description**: Add `workoutPolicyForPhase(phase, raceType, experience)`.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - `base`: mostly easy, recovery, long run.
  - `build`: controlled tempo, hills, fartlek depending experience.
  - `specific`: race-relevant workouts.
  - `peak`: strongest useful workouts, not excessive weekly stress.
  - `taperRace`: reduced volume, light sharpness.
- **Validation**:
  - Unit tests for beginner, intermediate, experienced policies.

### Task 4.2: Normalize Workout Types by Phase
- **Location**: `supabase/functions/generate-plan/plan-rules.ts`, `supabase/functions/generate-plan/index.ts`
- **Description**: Add `normalizeWorkoutTypesByPhase(sessions, profileData, totalWeeks, locale)`.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Early beginner intervals can be downgraded to easy/fartlek.
  - Race-specific work appears later, not randomly in base.
  - Taper phase avoids heavy workouts too close to race/test.
- **Validation**:
  - Unit tests for early hard workout cleanup.
  - Unit tests for taper workout cleanup.

## Sprint 5: Optional Phase Display Later
**Goal**: Only expose phases to Flutter after backend behavior is stable.

**Demo/Validation**:
- App can optionally show phase labels without changing plan generation quality.

### Task 5.1: Add Optional Phase Field
- **Location**: `supabase/functions/generate-plan/schema.ts`, `apps/mobile/lib/features/training_plan/domain/models/training_session.dart`
- **Description**: Add optional `phase` field only if product wants it in UI.
- **Dependencies**: Sprints 1-4
- **Acceptance Criteria**:
  - Old plans without phase still parse.
  - New plans can include phase.
- **Validation**:
  - Deno checks.
  - Flutter model tests.

### Task 5.2: Localize Phase Labels
- **Location**: `apps/mobile/lib/l10n/`, `apps/mobile/lib/features/training_plan/presentation/`
- **Description**: Add English/Spanish labels for phase display.
- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - No hardcoded UI strings.
  - Spanish and English labels are localized.
- **Validation**:
  - `flutter gen-l10n`
  - `flutter analyze`
  - targeted widget tests if UI changes.

## Testing Strategy
- Backend:
  - `/opt/homebrew/bin/deno fmt index.ts openai.ts plan-rules.ts plan-rules_test.ts workout-steps.ts workout-steps_test.ts schema.ts`
  - `/opt/homebrew/bin/deno check index.ts plan-rules_test.ts workout-steps_test.ts`
  - `/opt/homebrew/bin/deno lint index.ts openai.ts plan-rules.ts plan-rules_test.ts workout-steps.ts workout-steps_test.ts`
  - `/opt/homebrew/bin/deno test plan-rules_test.ts workout-steps_test.ts`
- Manual generation checks:
  - Generate 5K, 10K, half marathon, marathon.
  - Check phase shape by week.
  - Check peak long run by race and experience.
  - Check taper.
  - Check final race/test distance.
  - Check hard-day behavior.
  - Check stride placement.
- Flutter only if optional phase display is added:
  - `flutter gen-l10n`
  - `flutter analyze`
  - `flutter test`

## Potential Risks & Gotchas
- OpenAI may follow phase guidance imperfectly. Backend validation must remain deterministic.
- Peak long-run normalization can create weekly volume jumps if progression smoothing is not added.
- Beginner marathon plans are inherently sensitive. For very low readiness, product may later need a warning or longer plan length.
- Adding `phase` to mobile too early increases model and localization work before behavior is proven.
- Race day/test should not be counted as the peak long run.

## Rollback Plan
- Keep prompt changes, phase calculator, peak normalization, taper normalization, and UI display in separate commits.
- If a rule overcorrects plans, disable that one rule call in `index.ts`.
- If prompt guidance makes OpenAI worse, revert only the prompt block while keeping backend validation.
- If mobile phase labels add complexity, keep phases backend-only.
