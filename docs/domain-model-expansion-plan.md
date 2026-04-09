# Plan: Domain Model Expansion

**Generated**: 2026-04-07
**Estimated Complexity**: High

## Overview

This plan covers the next domain-model layer after the initial typed `RunnerProfileDraft` refactor. The goal is to move the app from a UI-first seed-data prototype toward a local-first running app with explicit models for goals, completed activities, workout targets, device connections, and future plan adaptation.

The implementation is staged so each sprint ends with a runnable, testable increment and does not require a backend. The first sprint finishes the `RunnerProfile` work already started in code. Later sprints add the missing canonical models identified in the domain review: `Goal`, `ActivityRecord`, `WorkoutTarget`, `DeviceConnection`, and the first adaptation models.

**Assumptions used for this plan:**
- Keep the app local-first. No backend, cloud sync, or auth-dependent profile storage is introduced in this plan.
- Existing onboarding and settings UX should remain visually stable unless a new model forces a small form change.
- `SharedPreferences` remains acceptable for lightweight structured persistence in this phase.
- The current seeded `TrainingPlan` remains the temporary plan source until a profile-driven generator replaces it.
- The new models should be canonical domain objects, not view models and not localized display strings.

## Prerequisites

- Flutter SDK `^3.11.1`
- Riverpod notifier/provider patterns already used in `apps/mobile/lib/features/*/presentation/`
- `shared_preferences` already present and used for onboarding-completed, locale, and user preferences
- Existing typed onboarding profile draft in [apps/mobile/lib/features/profile/domain/models/runner_profile.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/profile/domain/models/runner_profile.dart)
- Current provider architecture in [apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart) and [apps/mobile/lib/features/training_plan/presentation/training_plan_provider.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/training_plan/presentation/training_plan_provider.dart)

## Sprint 1: Finish Profile As Source Of Truth
**Goal**: Make the typed runner profile durable and make routing/profile-dependent flows rely on real structured profile state rather than an ephemeral onboarding draft plus a boolean flag.

**Demo/Validation**:
- Complete onboarding, kill the app, relaunch, and confirm the summary/review/settings screens are repopulated from persisted typed state.
- Confirm splash routing uses the persisted profile state, not only `onboarding_completed`.
- Verify `flutter analyze` and targeted profile/provider tests pass.

### Task 1.1: Add profile repository and JSON serialization
- **Location**: `apps/mobile/lib/features/profile/data/runner_profile_repository.dart`, `apps/mobile/lib/features/profile/domain/models/runner_profile.dart`
- **Description**: Add `toJson/fromJson` for `RunnerProfileDraft` and `RunnerProfile`, plus a repository abstraction and `SharedPreferences` implementation using versioned keys such as `runner_profile_draft_v1` and `runner_profile_v1`.
- **Dependencies**: None
- **Acceptance Criteria**:
  - Draft and final profile can round-trip through JSON without losing enum/value-object fidelity.
  - Stored values use canonical keys/enums, never localized labels.
- **Validation**:
  - Add unit tests for serialization/deserialization and versioned storage loading.

### Task 1.2: Hydrate onboarding/profile providers from persisted state
- **Location**: [apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart), [apps/mobile/lib/features/profile/presentation/runner_profile_provider.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/profile/presentation/runner_profile_provider.dart)
- **Description**: Refactor provider construction so onboarding state starts from persisted `RunnerProfileDraft` when available, and so finalized profile state is saved when onboarding completes or settings flows commit changes.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Relaunching the app restores draft/profile state without manual screen re-entry.
  - Settings edit flows load from the persisted profile source of truth.
- **Validation**:
  - Widget/provider test that saved state is visible after provider recreation.

### Task 1.3: Replace completion-flag-only routing with profile-aware gating
- **Location**: [apps/mobile/lib/core/router/app_router.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/core/router/app_router.dart)
- **Description**: Update the splash redirect so the app treats onboarding as complete only when a valid persisted profile exists, not only when `onboarding_completed == true`.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Incomplete or missing profile data routes the user back into onboarding.
  - Valid profile data routes the user into the main app.
- **Validation**:
  - Add router/provider tests for empty, partial, and valid persisted states.

### Task 1.4: Update data-model documentation to reflect current typed profile state
- **Location**: [docs/data-models.md](/Users/davidgd616/Documents/running-App/docs/data-models.md)
- **Description**: Replace the stale onboarding-map description with separate `Current state` and `Target state` sections. Document `RunnerProfileDraft`, `RunnerProfile`, persistence boundaries, and the remaining planned models below.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - The doc no longer claims onboarding is a `Map<String, dynamic>`.
  - The doc clearly distinguishes implemented vs planned model layers.
- **Validation**:
  - Manual review against actual files and providers.

## Sprint 2: Introduce Goal Domain
**Goal**: Extract reusable goal models out of onboarding/profile state so goals can drive training, progress, and settings independently of the onboarding flow.

**Demo/Validation**:
- The app can read a standalone goal model from the persisted profile and show it in onboarding review/settings flows.
- Goal state can represent at least race-oriented and time-oriented goals without depending on raw onboarding fields.

### Task 2.1: Define canonical goal models
- **Location**: `apps/mobile/lib/features/goals/domain/models/goal.dart`
- **Description**: Add a goal domain with models such as `Goal`, `RaceGoal`, and `RaceEvent`. Include explicit fields for goal kind, target race, optional target time, optional event date, and goal status.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Goal models are independent of onboarding UI concerns.
  - The models can represent current product needs without referencing localized strings.
- **Validation**:
  - Unit tests for model construction and serialization.

### Task 2.2: Map profile data into goal state
- **Location**: `apps/mobile/lib/features/goals/presentation/goal_provider.dart`, `apps/mobile/lib/features/profile/domain/models/runner_profile.dart`
- **Description**: Create a provider or mapper that derives the active goal from `RunnerProfile`. Keep the runner profile as the input source, but stop making screens infer goal state from raw onboarding sections.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - Settings/onboarding review flows can read a goal model directly.
  - Goal derivation is deterministic and testable.
- **Validation**:
  - Unit tests for mapping runner profile inputs into goal outputs.

### Task 2.3: Migrate goal-facing screens to goal/read-model APIs
- **Location**: onboarding/settings goal review and plan-ready screens
- **Description**: Replace any remaining goal-specific direct profile field stitching with a goal provider or goal presenter layer.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Goal screens no longer reconstruct domain rules inline.
  - Existing UI stays visually stable.
- **Validation**:
  - Widget smoke tests for goal summary/review screens.

## Sprint 3: Add Activity Domain
**Goal**: Separate planned sessions from completed activities so progress and history can be based on durable actual activity data, not only mutated `TrainingSession.status`.

**Demo/Validation**:
- Logging a run creates an `ActivityRecord`.
- Progress charts can be computed from activity records, even if the source session was planned separately.

### Task 3.1: Define activity models and repository
- **Location**: `apps/mobile/lib/features/activity/domain/models/activity_record.dart`, `apps/mobile/lib/features/activity/data/activity_repository.dart`
- **Description**: Add models such as `ActivityRecord`, `RunActivity`, and optional `ActivitySource`. Include planned-session linkage, actual duration/distance/elevation, timestamps, perceived effort, and completion status.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Activities can exist with or without a linked planned session.
  - Models support imported/manual/completed activity provenance.
- **Validation**:
  - Serialization and repository tests.

### Task 3.2: Persist activity records locally
- **Location**: `apps/mobile/lib/features/activity/presentation/activity_provider.dart`
- **Description**: Add local persistence for activity records and expose providers for all activities, recent activities, and activities by linked session ID.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Activities survive app restart.
  - The provider API supports downstream progress and session-detail flows.
- **Validation**:
  - Provider tests that load/save/reload activities.

### Task 3.3: Refactor run logging to write activity records
- **Location**: [apps/mobile/lib/features/log_run/presentation/screens/log_run_screen.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/log_run/presentation/screens/log_run_screen.dart), [apps/mobile/lib/features/pre_run/presentation/screens/pre_run_screen.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/pre_run/presentation/screens/pre_run_screen.dart)
- **Description**: Update logging flows so “complete run” creates or updates an activity record instead of only mutating session status.
- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - A logged run produces persisted activity data.
  - Planned session completion remains visible in the weekly plan UI.
- **Validation**:
  - Manual flow test: log a run, restart app, verify progress still shows it.

### Task 3.4: Move progress derivations onto activities
- **Location**: [apps/mobile/lib/features/progress/presentation/progress_provider.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/progress/presentation/progress_provider.dart), `apps/mobile/lib/features/progress/domain/services/*`
- **Description**: Change progress builders to prefer activity records for completed history, while still allowing seeded sessions to fill gaps temporarily during migration.
- **Dependencies**: Task 3.3
- **Acceptance Criteria**:
  - Recent sessions, monthly totals, and history series are driven by activity data.
  - No double-counting between planned sessions and activities.
- **Validation**:
  - Update and extend existing progress service tests.

## Sprint 4: Add Structured Workout Targets
**Goal**: Make planned workouts machine-readable so interval execution, target-based coaching, and future device sync do not depend on presentation strings.

**Demo/Validation**:
- Session detail can render structured steps/targets from typed workout data.
- A seeded interval workout can express target pace/effort/HR metadata without free-text parsing.

### Task 4.1: Define workout target and step models
- **Location**: `apps/mobile/lib/features/training_plan/domain/models/workout_target.dart`, `apps/mobile/lib/features/training_plan/domain/models/workout_step.dart`
- **Description**: Add typed models for workout structure such as `WorkoutStep`, `WorkoutTarget`, `TargetType`, and `TargetZone`. Support step repetitions, recovery blocks, time/distance-based steps, and target effort/pace/heart-rate hints.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Interval, tempo, and long-run sessions can be represented without embedding execution rules in strings.
  - The models remain localizable only at the UI boundary.
- **Validation**:
  - Unit tests for representative workout definitions.

### Task 4.2: Extend training sessions to reference structured targets
- **Location**: [apps/mobile/lib/features/training_plan/domain/models/training_session.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/training_plan/domain/models/training_session.dart), [apps/mobile/lib/features/training_plan/data/training_plan_seed_data.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/training_plan/data/training_plan_seed_data.dart)
- **Description**: Add optional structured workout fields to `TrainingSession` and update seed data for key workout types.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Existing screens still work for simple sessions.
  - At least one structured intervals session is available in seed data.
- **Validation**:
  - Analyzer/tests plus manual session-detail inspection.

### Task 4.3: Update session detail/pre-run UI to consume structured targets
- **Location**: session detail and pre-run screens/widgets
- **Description**: Render the new workout structure while preserving localized labels and current visual language.
- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - The UI does not need to parse `note` strings to explain workouts.
  - Sessions without structured targets still render correctly.
- **Validation**:
  - Widget tests for structured and unstructured sessions.

## Sprint 5: Add Integrations Domain
**Goal**: Introduce explicit device/integration models so connected-watch state is no longer represented only as onboarding preferences.

**Demo/Validation**:
- The app can store a local device connection record independent of onboarding answers.
- Settings can show a typed connection state even without real API sync.

### Task 5.1: Define integration models
- **Location**: `apps/mobile/lib/features/integrations/domain/models/device_connection.dart`, `apps/mobile/lib/features/integrations/domain/models/integration_account.dart`
- **Description**: Add canonical models for watch/app connections, provider/vendor type, connection state, supported capabilities, and last-sync metadata.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Device capability state is represented outside onboarding/profile data.
  - Models can support future Garmin/Apple Watch/Coros sync without schema rewrite.
- **Validation**:
  - Unit tests for model serialization.

### Task 5.2: Add local repository/provider for device connections
- **Location**: `apps/mobile/lib/features/integrations/data/`, `apps/mobile/lib/features/integrations/presentation/`
- **Description**: Persist local device connection records and expose providers for current connection and supported sync capabilities.
- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - Device connection survives app restart.
  - Onboarding watch preferences can seed or update the connection record.
- **Validation**:
  - Repository/provider tests.

### Task 5.3: Decouple onboarding watch answers from integration state
- **Location**: onboarding watch/device flow, settings integrations screens
- **Description**: Treat onboarding device answers as initial setup inputs only, then map them into the integration domain and stop using them as the durable source of truth.
- **Dependencies**: Task 5.2
- **Acceptance Criteria**:
  - Settings integrations UI reads from the integrations domain.
  - Existing onboarding UX remains unchanged.
- **Validation**:
  - Manual flow test for onboarding -> settings integrations.

## Sprint 6: Add Adaptation Foundations
**Goal**: Add the minimum models needed for future plan adaptation without building the adaptive engine yet.

**Demo/Validation**:
- The app can record feedback after a session and create a revision record when a plan changes.
- Training plans can support a richer session catalog, including non-run support sessions.

### Task 6.1: Define session feedback and plan revision models
- **Location**: `apps/mobile/lib/features/training_plan/domain/models/session_feedback.dart`, `apps/mobile/lib/features/training_plan/domain/models/plan_revision.dart`, `apps/mobile/lib/features/training_plan/domain/models/plan_adjustment.dart`
- **Description**: Add models that capture runner-reported session difficulty, missed-run reasons, recovery feedback, and the reason/history for plan changes.
- **Dependencies**: Sprints 3 and 4
- **Acceptance Criteria**:
  - Feedback can reference both planned session and completed activity.
  - Revision records explain why a plan changed.
- **Validation**:
  - Unit tests for revision/feedback creation and serialization.

### Task 6.2: Broaden session support types
- **Location**: [apps/mobile/lib/features/training_plan/domain/models/session_type.dart](/Users/davidgd616/Documents/running-App/apps/mobile/lib/features/training_plan/domain/models/session_type.dart)
- **Description**: Expand session support to include types such as `strength`, `mobility`, and `drills`, or add a supplemental-session model if cleaner.
- **Dependencies**: Task 6.1
- **Acceptance Criteria**:
  - The model layer can represent support work without abusing `crossTraining`.
  - Existing plan/progress code handles the new types safely.
- **Validation**:
  - Update progress/streak rules and add unit tests.

### Task 6.3: Add minimal adaptation workflow hooks
- **Location**: pre-run, post-run/log-run, training-plan providers
- **Description**: Add a minimal path for collecting feedback and storing a pending plan adjustment/revision record, without yet generating a fully adaptive replacement plan.
- **Dependencies**: Tasks 6.1 and 6.2
- **Acceptance Criteria**:
  - A completed session can produce feedback data.
  - A skipped/failed session can create a structured adjustment request.
- **Validation**:
  - Manual end-to-end flow and provider tests.

## Testing Strategy

- Add unit tests for every new domain model’s serialization, enum mapping, and validation rules.
- Add provider/repository tests for persisted `RunnerProfile`, `Goal`, `ActivityRecord`, and `DeviceConnection` state.
- Update progress service tests to cover activity-driven derivation and mixed migration states.
- Add targeted widget tests for summary/review/session-detail screens that consume new typed models.
- Run `flutter analyze` and `flutter test` after each sprint from `apps/mobile/`.

## Potential Risks & Gotchas

- `docs/data-models.md` is already stale relative to the current code. If not updated early, it will mislead future work.
- Mixing planned `TrainingSession` data and completed `ActivityRecord` data can easily create double-counting in progress metrics.
- Storing localized text in any of the new models will break i18n and migration safety. Keep canonical enums/keys only.
- `SharedPreferences` is acceptable for this phase, but large activity histories may outgrow it. If activity volume expands materially, move activity persistence to a more structured local store before sync work.
- Goal models should not be derived ad hoc in multiple screens. Centralize goal derivation early or drift will return.
- Device onboarding answers and actual integration state must be separated or later sync support will be difficult to retrofit.

## Rollback Plan

- Land each sprint as separate commits so profile persistence, goals, activity logging, structured workouts, and integrations can be reverted independently.
- Keep compatibility adapters during migration:
  - goal screens can fall back to `RunnerProfile` fields while `Goal` is introduced
  - progress can temporarily support both session-based and activity-based derivation
  - training sessions can keep `WorkoutPhase` text rendering while structured targets are phased in
- If activity persistence causes regressions, disable activity-backed progress and fall back to current session-derived stats while keeping the domain models in place.
