# Plan: Generated Plan Display

**Generated**: 2026-04-23
**Estimated Complexity**: Medium

## Overview

Make generated plans visible and understandable in the Flutter app. The backend already returns `description: session.coachNote` and deterministic `workoutSteps`; this plan verifies the full path from Supabase Edge Function response to Flutter model parsing to Today, Plan, Session Detail, Pre-run, and Active Run display.

For multilingual support, use the simple current approach: Flutter sends the selected app locale to `generate-plan`; OpenAI writes `coachNote` in that language; Flutter displays `TrainingSession.description` directly. Structured `workoutSteps` stay canonical and are rendered through `AppLocalizations`/ARB placeholders.

Docs consulted:
- Flutter internationalization docs: ARB files define localized strings and placeholders; generated `AppLocalizations` methods receive dynamic values.
- Supabase Dart reference: `supabase.functions.invoke('function-name', body: {...})` sends a JSON body and returns response `data`.

## Prerequisites

- Existing generated-plan Edge Function is deployed and returning active plans.
- Flutter app locale is available from the existing locale provider.
- All visible static text must remain in `app_en.arb` and `app_es.arb`; no translated strings should drive logic.
- Commands:
  - From `apps/mobile/`: `flutter gen-l10n`, `flutter analyze`, `flutter test`
  - From `supabase/functions/generate-plan`: `deno check index.ts plan-rules_test.ts`, `deno lint index.ts openai.ts plan-rules.ts plan-rules_test.ts`, `deno test plan-rules_test.ts`

## Sprint 1: Locale-Aware Coach Notes

**Goal**: Generated coach notes appear in the user-selected app language and map into `TrainingSession.description`.

**Demo/Validation**:
- Generate a plan with app language English and confirm Today/Session Detail show English coach notes.
- Generate a plan with app language Spanish and confirm Today/Session Detail show Spanish coach notes.
- Confirm no workout logic depends on translated text.

### Task 1.1: Send Locale To Edge Function

- **Location**: `apps/mobile/lib/features/onboarding/presentation/plan_generation_provider.dart`
- **Description**: Add current app locale to the Edge Function body, for example `{ requestedBy, locale: 'en' | 'es' }`.
- **Dependencies**: Existing locale provider.
- **Acceptance Criteria**:
  - Function request includes stable locale code.
  - Missing locale falls back safely.
  - `requestedBy` behavior is unchanged.
- **Validation**:
  - Unit/provider test or debug log confirms body includes locale.
  - `flutter analyze`

### Task 1.2: Accept Locale In Supabase Function

- **Location**: `supabase/functions/generate-plan/index.ts`, `supabase/functions/generate-plan/openai.ts`
- **Description**: Read `body.locale`, normalize to supported values, and pass it into `generatePlanFromProfile`.
- **Dependencies**: Task 1.1.
- **Acceptance Criteria**:
  - Only `en` and `es` are accepted; unknown/missing values become `en`.
  - Existing authenticated generation flow is unchanged.
- **Validation**:
  - `deno check index.ts plan-rules_test.ts`
  - Add or update Deno test if locale normalization is extracted.

### Task 1.3: Prompt Coach Note Language

- **Location**: `supabase/functions/generate-plan/openai.ts`
- **Description**: Tell OpenAI that `coachNote` must be written in the requested language, while structural fields remain canonical English keys.
- **Dependencies**: Task 1.2.
- **Acceptance Criteria**:
  - `coachNote` language follows locale.
  - Fields like `type`, `effort`, `workoutSteps.kind`, and target keys stay canonical.
  - Prompt explicitly says `coachNote` is display text only, not logic.
- **Validation**:
  - Generate one English plan and one Spanish plan in test/dev.
  - Confirm `coachNote` language changes but JSON keys do not.

### Task 1.4: Confirm `coachNote` Mapping

- **Location**: `supabase/functions/generate-plan/index.ts`, `apps/mobile/lib/features/training_plan/domain/models/training_session.dart`
- **Description**: Verify the backend still outputs `description: session.coachNote` and Flutter still reads `description`.
- **Dependencies**: Task 1.3.
- **Acceptance Criteria**:
  - Generated `plan.sessions[*].description` contains coach note text.
  - `TrainingSession.fromJson` preserves it.
  - Empty/null notes do not break parsing.
- **Validation**:
  - Add a Flutter model parsing test using a generated-style session JSON.

## Sprint 2: Workout Step Parsing Contract

**Goal**: Flutter parses all generated `workoutSteps` cleanly, including nested repeat blocks with strides.

**Demo/Validation**:
- A generated session with warm-up, work, repeat(stride + recovery), and cool-down parses into `TrainingSession.workoutSteps`.
- Invalid optional fields are ignored safely without dropping the whole session.

### Task 2.1: Add Generated Payload Fixture

- **Location**: `apps/mobile/test/features/training_plan/domain/models/`
- **Description**: Create a compact JSON fixture representing a Supabase/OpenAI generated session with `description` and `workoutSteps`.
- **Dependencies**: None.
- **Acceptance Criteria**:
  - Fixture includes `warmUp`, `work`, `repeat`, `stride`, `recovery`, and `coolDown`.
  - Fixture uses the same field names emitted by Flutter serialization: `kind`, `durationMs`, `repetitions`, `steps`, `target`.
- **Validation**:
  - Fixture loads in a model test.

### Task 2.2: Test `TrainingSession.fromJson`

- **Location**: `apps/mobile/test/features/training_plan/domain/models/training_session_test.dart`
- **Description**: Assert `description` maps from generated JSON and nested `workoutSteps` parse correctly.
- **Dependencies**: Task 2.1.
- **Acceptance Criteria**:
  - Parsed session keeps `description`.
  - Parsed step kinds match expected order.
  - Repeat block keeps repetitions and nested stride/recovery steps.
  - Duration values convert from milliseconds to `Duration`.
- **Validation**:
  - `flutter test test/features/training_plan/domain/models/training_session_test.dart`

### Task 2.3: Harden Map Parsing If Needed

- **Location**: `apps/mobile/lib/features/training_plan/domain/models/training_session.dart`, `apps/mobile/lib/features/pre_run/presentation/run_flow_context.dart`
- **Description**: If tests expose failures with loose JSON map types, support generic `Map` conversion consistently like `WorkoutStep.fromJson` already does.
- **Dependencies**: Task 2.2.
- **Acceptance Criteria**:
  - JSON decoded from Supabase/local cache parses without type-cast failures.
  - Bad individual steps are skipped; valid sibling steps remain.
- **Validation**:
  - Model tests with `Map<String, dynamic>` and generic `Map` shapes.

## Sprint 3: User-Facing Display Surfaces

**Goal**: The plan data is visible in the screens where users decide what to run.

**Demo/Validation**:
- Today card shows coach guidance.
- Session Detail shows coach guidance and structured workout phases.
- Pre-run shows enough workout structure before starting.
- Active Run timeline receives generated steps.

### Task 3.1: Verify Today Card Description

- **Location**: `apps/mobile/lib/features/home/presentation/screens/home_screen.dart`
- **Description**: Confirm `WorkoutHeroCard.targetGuidance` prefers `session.description` and falls back to localized generated copy.
- **Dependencies**: Sprint 1.
- **Acceptance Criteria**:
  - Generated coach note is visible on Today.
  - Missing coach note falls back to localized app text.
- **Validation**:
  - Widget test or simulator check with generated plan.

### Task 3.2: Verify Session Detail Structure

- **Location**: `apps/mobile/lib/features/session_detail/presentation/screens/session_detail_screen.dart`
- **Description**: Confirm `workoutSteps` render warm-up, main work, strides, and cool-down with localized labels and ARB placeholders.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - Strides show reps, seconds, and recovery.
  - Labels are localized in English and Spanish.
  - Remove or replace any remaining HR-zone wording if the generated plan is phone-only.
- **Validation**:
  - Widget test for a generated stride session.
  - Manual English/Spanish simulator check.

### Task 3.3: Add Pre-Run Workout Preview

- **Location**: `apps/mobile/lib/features/pre_run/presentation/screens/pre_run_screen.dart`, `apps/mobile/lib/features/pre_run/presentation/run_flow_context.dart`
- **Description**: Show a compact localized preview above readiness questions when `RunFlowSessionContext.workoutSteps` is not empty.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - User can see today’s key workout blocks before pressing continue.
  - Preview supports strides and repeat blocks.
  - Static labels use ARB; dynamic values use placeholders.
  - No logic depends on coach note text.
- **Validation**:
  - Widget test for pre-run with generated steps.
  - `flutter gen-l10n`, `flutter analyze`, `flutter test`

### Task 3.4: Verify Active Run Timeline

- **Location**: `apps/mobile/lib/features/active_run/presentation/active_run_timeline.dart`
- **Description**: Confirm generated nested repeat steps flatten into live blocks, including stride/recovery pairs.
- **Dependencies**: Sprint 2.
- **Acceptance Criteria**:
  - `repeat` expands into per-rep blocks.
  - `stride` maps to `ActiveRunBlockKind.stride`.
  - Recovery after strides appears between reps.
- **Validation**:
  - Unit test for `ActiveRunTimeline.fromSession`.

## Sprint 4: End-To-End Verification

**Goal**: Prove a generated plan is complete from backend generation to mobile display.

**Demo/Validation**:
- Generate plan in English and Spanish.
- Inspect local cached active plan JSON.
- Open Today, Plan, Session Detail, Pre-run, and Active Run.

### Task 4.1: Backend Verification

- **Location**: `supabase/functions/generate-plan/`
- **Description**: Run Deno checks and deploy only after successful local verification.
- **Dependencies**: Sprints 1-3 backend tasks.
- **Acceptance Criteria**:
  - Deno check/lint/test pass.
  - Deployed Edge Function returns localized `description` and canonical `workoutSteps`.
- **Validation**:
  - `deno check index.ts plan-rules_test.ts`
  - `deno lint index.ts openai.ts plan-rules.ts plan-rules_test.ts`
  - `deno test plan-rules_test.ts`
  - `supabase functions deploy generate-plan`

### Task 4.2: Mobile Verification

- **Location**: `apps/mobile/`
- **Description**: Run Flutter generation/analyze/tests and verify simulator display.
- **Dependencies**: Sprint 3.
- **Acceptance Criteria**:
  - No analyzer errors.
  - Tests pass.
  - English and Spanish UI do not show mixed static labels.
  - Coach note displays in selected locale.
  - Workout step labels are localized by Flutter.
- **Validation**:
  - `flutter gen-l10n`
  - `flutter analyze`
  - `flutter test`

### Task 4.3: Cached Plan Inspection

- **Location**: local simulator `SharedPreferences` active plan cache
- **Description**: Inspect `flutter.active_plan_version_v1` after generation to confirm mobile received what backend returned.
- **Dependencies**: Task 4.2.
- **Acceptance Criteria**:
  - Sessions contain `description`.
  - Sessions contain non-empty `workoutSteps` for structured workouts.
  - Stride sessions retain repeat/stride/recovery structure.
- **Validation**:
  - Local cache inspection script or one-off `plutil`/Node check.

## Testing Strategy

- Backend:
  - Existing Deno plan-rule tests remain green.
  - Add targeted tests only if locale normalization or payload shaping becomes non-trivial.
- Mobile model:
  - Unit tests for `TrainingSession.fromJson`, `WorkoutStep.fromJson`, and `RunFlowSessionContext`.
- Mobile UI:
  - Widget tests for Session Detail and Pre-run using generated-style sessions.
  - Manual simulator check in English and Spanish.
- E2E:
  - Generate real plans after deploy and inspect both database/response shape and visible screens.

## Potential Risks & Gotchas

- `coachNote` is generated display text, so quality/language can vary. Mitigation: keep it short in the prompt and never use it for logic.
- Existing plan-rule functions append English cues to `coachNote`. Mitigation: either localize those backend-appended cues or stop appending display text and rely on structured fields for schedule/stride display.
- `description: description ?? this.description` in `copyWith` cannot intentionally clear descriptions. Not a blocker for display, but worth knowing.
- `PreRunScreen` currently focuses on readiness and does not render session structure. This is the biggest UI gap.
- If Supabase returns generic maps instead of `Map<String, dynamic>`, some current parsers may silently drop data. Model tests should catch this.
- Spanish ARB currently includes `"Strides"` in at least one label. Decide whether to keep the English loanword or use `progresivos` consistently.

## Rollback Plan

- Backend rollback: remove locale from the prompt/request path and redeploy the previous Edge Function commit.
- Mobile rollback: keep parser tests but hide any new Pre-run workout preview behind a small conditional or revert the Pre-run UI commit.
- Data rollback: generated plans remain compatible because `description` and `workoutSteps` are already optional fields in Flutter models.
