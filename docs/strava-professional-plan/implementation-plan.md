# Strava Professional Plan Implementation Plan

**Goal:** Replace basic/manual plan creation with a professional Strava-informed onboarding, analysis, and plan-generation flow.

**Architecture:** Build a new plan-generation contract around a curated `StravaCoachingProfile` and user-owned preferences. Keep Strava analysis and generated plan output structured so UI screens can render localized labels, pace ranges, support sessions, race guidance, and session targets without parsing prose.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Material 3, Supabase Edge Functions, TypeScript/Deno, OpenAI structured output, ARB localization, Strava API.

---

## Implementation Principles

- Replace the old onboarding and plan-generation contract completely.
- Preserve existing app behavior only where it still matches the professional-plan direction.
- Store canonical keys and structured values. Localize only at the UI boundary except AI-written coaching text.
- Store paces internally as seconds per kilometer.
- Keep AI prose out of fields that the app needs for logic.
- Add tests before behavior changes.
- Run relevant Flutter and Supabase tests after each phase.

## Sub-Agent Execution Strategy

Use a review-gated sequential pipeline. The orchestrator owns task selection, acceptance criteria, integration, commits, and final judgment. Sub-agents can help, but only one coder should own one implementation task at a time.

### Roles

- Orchestrator: coordinates the work, assigns the next task, inspects changes, runs final checks, and commits after approval.
- Explorer: reads the codebase for one bounded task and reports exact files, existing patterns, risks, and relevant tests. Explorer does not edit files.
- Researcher: checks current external documentation only when API/library behavior matters, such as Strava API, Supabase Edge Functions, OpenAI structured output, Flutter packages, or localization tooling. Researcher does not edit files.
- Coder: implements one narrow task. The coder sub-agent is Codex using GPT-5.3 Codex. The coder writes tests first where practical, makes the implementation, runs focused verification, and reports changed files.
- Reviewer: audits the finished task for bugs, regressions, security, privacy, localization, data-model consistency, and missing tests. Reviewer does not edit files by default.
- Scribe: updates docs/spec notes when implementation decisions change. Scribe does not edit product logic.

### Task Loop

For each task:

1. Orchestrator confirms the task scope and acceptance criteria.
2. Explorer maps the current code when the task touches unfamiliar or broad surfaces.
3. Researcher checks current documentation when the task depends on external API/library behavior.
4. Coder implements exactly one task with a clear file ownership boundary.
5. Coder runs focused tests and reports results.
6. Reviewer audits the task, including security and privacy.
7. If reviewer finds issues, Coder fixes them and the task returns to review.
8. Orchestrator runs final verification for the task.
9. Orchestrator commits only that task.
10. Orchestrator updates this plan with the task status and commit hash.

No implementation task should be committed until the reviewer is satisfied. If a reviewer concern cannot be resolved inside the current task, the task stops and the orchestrator asks for direction before any commit.

### Commit Rules

- Commit every completed task separately.
- Keep commits small enough to review and revert.
- Do not mix unrelated tasks in one commit.
- Do not commit generated files without the source change that required them.
- Do not add co-author footers.
- Update this plan after each task with status, commit hash, and verification notes.

### Parallelism Rules

- Run Explorer and Researcher work in parallel when their questions are independent.
- Run Reviewer work after a coder task is complete.
- Do not run parallel coder sub-agents for this integration.
- Keep implementation sequential: one coder, one task, reviewer approval, commit, then the next task.

### Reviewer Security And Privacy Checklist

Reviewer must explicitly check Strava, Supabase, OpenAI, and plan-generation tasks for:

- No tokens, refresh tokens, authorization headers, API keys, or secrets are logged.
- Raw Strava activity history is not retained unless the task explicitly requires it.
- Strava activity names are not displayed by default.
- Upstream Strava error bodies are not leaked to the client.
- OAuth scopes remain limited to the feature requirements.
- Supabase service-role usage is server-only and does not bypass user boundaries incorrectly.
- User-owned choices are not silently overwritten by Strava-derived analysis.
- Generated AI prose is not used for app logic.
- Canonical keys are stored instead of localized display strings.
- English and Spanish localization paths are both handled for visible app text.
- Prompt payloads avoid unnecessary personal data.
- Aggressive user goals cannot bypass Strava-derived safety limits.

### Stop Conditions

Continue through fixes until reviewer approval when the task is feasible. Stop and ask for direction only when:

- Required credentials, network access, or external service state is unavailable.
- The task needs a product decision not captured in this spec.
- A reviewer concern conflicts with an existing documented decision.
- The implementation would require destructive changes outside the task scope.

## Phase 1: Data Contracts [COMPLETE]

### Task 1: Define Strava Coaching Profile Models

**Files:**

- Create: `apps/mobile/lib/features/strava/domain/models/strava_coaching_profile.dart`
- Modify: `apps/mobile/lib/features/strava/domain/athlete_summary.dart`
- Test: `apps/mobile/test/features/strava/strava_coaching_profile_test.dart`

**Build:**

- `StravaCoachingProfile`
- `StravaAnalysisProvenance`
- `StravaDataConfidence`
- `StravaEvidencePoint`
- `StravaPaceZones`
- `StravaGuardrail`
- `StravaPlanFocus`
- `StravaTerrainProfile`
- `StravaRaceTargetEstimate`

**Acceptance Criteria:**

- Model supports JSON serialization.
- Model stores pace zones in seconds per kilometer.
- Evidence points store dates but not activity names by default.
- Provenance includes source, sync time, data window, activity counts, and confidence.
- Tests cover strong, weak, and no-useful-data profiles.

### Task 2: Define New Plan Generation Input Contract

**Files:**

- Create: `apps/mobile/lib/features/onboarding/domain/models/professional_plan_input.dart`
- Modify: `apps/mobile/lib/features/profile/domain/models/runner_profile.dart`
- Test: `apps/mobile/test/features/onboarding/domain/professional_plan_input_test.dart`

**Build:**

- Goal input.
- Fitness source input.
- Optional Strava coaching profile.
- Optional manual fitness fallback.
- Accepted race target.
- Schedule preferences.
- Health constraints.
- Strength preferences.
- Plan intensity.
- Unit preference.
- Locale.
- Optional race course terrain.

**Acceptance Criteria:**

- Strong Strava data can skip manual fitness fields.
- Weak Strava data can include targeted manual fields.
- User-owned schedule fields are never overwritten by Strava.
- Serialization keeps canonical keys only.

### Task 3: Define New Generated Plan Schema

**Files:**

- Modify: `apps/mobile/lib/features/training_plan/domain/models/training_plan.dart`
- Modify: `apps/mobile/lib/features/training_plan/domain/models/training_session.dart`
- Modify: `apps/mobile/lib/features/training_plan/domain/models/workout_target.dart`
- Modify: `apps/mobile/lib/features/training_plan/domain/models/workout_step.dart`
- Create: `apps/mobile/lib/features/training_plan/domain/models/support_plan_session.dart`
- Create: `apps/mobile/lib/features/training_plan/domain/models/race_guidance.dart`
- Test: `apps/mobile/test/features/training_plan/domain/models/professional_plan_serialization_test.dart`

**Build:**

- Structured session pace targets.
- Plan-level pace zones.
- Support sessions.
- Race guidance.
- Generated locale.
- Strava coaching snapshot on the plan version.

**Acceptance Criteria:**

- Race day guidance is not represented as a normal training session.
- Support sessions can represent lower body, upper body, core/mobility, and full body.
- Session detail can render target pace ranges without parsing `coachNote`.
- Existing plan serialization tests are updated or replaced to match the new contract.

### Phase 1 Completion Notes (2026-06-03)

- Task 1 commit: `c687652` - "feat(strava): add StravaCoachingProfile data contract models"
- Task 2 commit: `7605629` - "feat(onboarding): add ProfessionalPlanInput data contract"
- Task 3 commit: `95abd67` - "feat(training_plan): add professional plan schema with pace targets, race guidance, support sessions"

## Phase 2: Strava Sync And Analysis [COMPLETE]

### Task 4: Enrich Strava Sync Summary Fields

**Files:**

- Modify: `supabase/functions/strava-sync/index.ts`
- Modify: `apps/mobile/lib/features/strava/domain/models/strava_athlete.dart`
- Modify: `apps/mobile/lib/features/strava/data/strava_service.dart`
- Test: `supabase/functions/strava-sync/index_test.ts`
- Test: `apps/mobile/test/features/strava/data/strava_service_test.dart`

**Build:**

- Include activity id.
- Include elapsed time.
- Include max speed when available.
- Include max HR when available.
- Include elevation gain.
- Include workout type or perceived exertion only if available and safe to parse.

**Acceptance Criteria:**

- Existing sync works when optional fields are missing.
- Activity names are not sent to UI-facing coaching evidence by default.
- Tests cover missing optional fields.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `ccd9615` - "feat(strava): enrich synced activity summaries"
- Reviewer approved with no findings after fix passes.
- Verification passed:
  - `supabase/functions/strava-sync`: `deno test --allow-env --allow-net --allow-read index_test.ts` (8 passed)
  - `apps/mobile`: `flutter test test/features/strava/data/strava_service_test.dart` (13 passed)
- Phase 2 remains in progress because Task 5 is next.

### Task 5: Build Coaching Profile Derivation

**Files:**

- Modify: `apps/mobile/lib/features/strava/domain/athlete_summary.dart`
- Create: `apps/mobile/lib/features/strava/domain/strava_coaching_profile_builder.dart`
- Test: `apps/mobile/test/features/strava/strava_coaching_profile_builder_test.dart`

**Build:**

- Strong/weak/no-useful-data classification.
- Training base section.
- Endurance section.
- Speed markers.
- Pace zones.
- Terrain profile.
- Recovery guardrails.
- Race target estimates.
- Plan focus.

**Acceptance Criteria:**

- Runs drive running plan inputs.
- Non-runs do not appear in Strava Analysis.
- Older best efforts up to 6 months affect confidence/stretch targets only.
- Recent 8 to 12 week data controls safety and paces.
- Guardrails are limited to 0 to 3 priority flags.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `c9a18c4` - "feat(strava): derive coaching profile analysis"
- Reviewer approved with no findings after fix passes.
- Verification passed:
  - `apps/mobile`: `flutter test test/features/strava/strava_coaching_profile_builder_test.dart` (14 passed)
  - `apps/mobile`: `flutter test test/features/strava/athlete_summary_test.dart test/features/strava/strava_coaching_profile_test.dart` (24 passed)
  - `apps/mobile`: `flutter analyze` (No issues found)
- Phase 2 is complete because Task 4 and Task 5 are complete.
- Phase 3 Task 6 is next.

### Phase 2 Completion Notes (2026-06-03)

- Task 4 commit: `ccd9615` - "feat(strava): enrich synced activity summaries"
- Task 5 commit: `c9a18c4` - "feat(strava): derive coaching profile analysis"
- Phase 2 acceptance criteria were met.
- Phase 3 Task 6 is next.

## Phase 3: Onboarding Replacement [IN PROGRESS]

### Task 6: Replace Onboarding State With Professional Flow State

**Files:**

- Modify: `apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart`
- Modify: `apps/mobile/lib/features/onboarding/presentation/onboarding_values.dart`
- Modify: `apps/mobile/lib/core/router/app_router.dart`
- Test: `apps/mobile/test/features/onboarding/presentation/onboarding_provider_test.dart`

**Build:**

- New ordered flow:
  - Goal.
  - Fitness source.
  - Strava/manual fitness.
  - Strava Analysis.
  - Race target confirmation.
  - Schedule.
  - Health.
  - Strength.
  - Preferences/intensity.
  - Generate plan.

**Acceptance Criteria:**

- Strava Analysis is mandatory after Strava connection.
- Manual fitness remains available as an alternative.
- Old flow routes are removed or redirected.
- Onboarding state stores canonical values only.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `8b805a1` - "feat(onboarding): route Strava users through analysis"
- Reviewer approved with no findings after fix pass.
- Verification passed:
  - `apps/mobile`: `flutter test test/core/router/app_router_test.dart test/features/onboarding/presentation/goal_flow_widget_test.dart test/features/onboarding/presentation/onboarding_provider_test.dart test/features/onboarding/presentation/strava_connect_screen_test.dart test/features/profile/data/runner_profile_repository_test.dart`
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test` (496 tests passed)

### Task 7: Build Strava Analysis Screen

**Files:**

- Create: `apps/mobile/lib/features/onboarding/presentation/screens/strava_analysis_screen.dart`
- Modify: `apps/mobile/lib/l10n/app_en.arb`
- Modify: `apps/mobile/lib/l10n/app_es.arb`
- Test: `apps/mobile/test/features/onboarding/presentation/strava_analysis_screen_test.dart`

**Build:**

- Training Base.
- Endurance.
- Speed and pace zones.
- Terrain.
- Recovery and guardrails.
- Race target.
- Plan focus.
- Confidence label.
- Strong/weak/no-useful-data actions.

**Acceptance Criteria:**

- Uses localized app labels.
- Formats dates and paces by locale and unit preference.
- Shows dates, not activity names.
- Shows "Use Strava Analysis" as primary action for strong data.
- Shows "Continue With Manual Details" for weak data.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `89be6df` - "feat(onboarding): build Strava analysis screen"
- Full localized Strava Analysis screen was added after Strava connect.
- The screen shows training base, endurance, pace zones, terrain, recovery guardrails, race target, plan focus, confidence, evidence, and actions.
- Strong confidence continues through the Strava-derived plan path.
- Medium and limited confidence route to manual/simple details and clear Strava-derived assumptions.
- Disconnect success and failure are handled with localized UI and no raw errors.
- Privacy and localization safeguards were preserved: no raw activity names, raw metric/category keys, guardrail messages, plan focus summaries, or tokens are displayed.
- Distance, date, and pace formatting are locale-aware, including metric/imperial units and Spanish decimal formatting.
- Reviewer approved with no findings.
- Verification passed:
  - `apps/mobile`: `flutter gen-l10n`
  - `apps/mobile`: focused onboarding tests
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test`
- Phase 3 continued with Task 8.

### Task 8: Add Strength Preference Screen

**Files:**

- Create: `apps/mobile/lib/features/onboarding/presentation/screens/strength_preferences_screen.dart`
- Modify: `apps/mobile/lib/l10n/app_en.arb`
- Modify: `apps/mobile/lib/l10n/app_es.arb`
- Test: `apps/mobile/test/features/onboarding/presentation/strength_preferences_screen_test.dart`

**Build:**

- Whether user lifts.
- Weekly frequency.
- Strength categories.
- Lower-body/preferred lifting days.
- Same-day order preference.

**Acceptance Criteria:**

- No exact exercise prescription.
- Values are canonical.
- Spanish and English strings are present.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `e35077d` - "feat(onboarding): add strength preferences step"
- New localized Strength Preferences onboarding screen added at `/onboarding/strength`.
- The screen captures whether the user lifts.
- No-lifting path stores canonical `lifts: false` and does not require lift-specific fields.
- Lifting path stores canonical weekly frequency, strength categories, preferred/lower-body lifting days, and same-day order preference.
- Scope remains running-focused with strength categories only and no exercise prescription.
- `RunnerProfile` and `RunnerProfileDraft` now persist strength preferences with backward-compatible JSON for older profiles missing strength.
- Onboarding progress was updated coherently to 9 steps across Strava and manual branches.
- English and Spanish strings were added, including plural-safe frequency labels and 9-section intro copy.
- Reviewer approved with no findings.
- Verification passed:
  - `apps/mobile`: `flutter gen-l10n`
  - `apps/mobile`: focused strength, router, provider, profile, and Strava analysis tests
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test`

### Phase 3 Completion Notes (2026-06-03)

- Phase 3 is complete because Task 6, Task 7, and Task 8 are complete.
- Phase 4 Task 9 is next.

## Phase 4: Plan Generation Backend

### Task 9: Replace Supabase Generate Plan Request Shape

**Files:**

- Modify: `supabase/functions/generate-plan/index.ts`
- Modify: `supabase/functions/generate-plan/schema.ts`
- Modify: `supabase/functions/generate-plan/openai.ts`
- Test: `supabase/functions/generate-plan/schema_test.ts`
- Test: `supabase/functions/generate-plan/openai_test.ts`

**Build:**

- Accept new professional input.
- Produce new structured output.
- Include pace zones, support sessions, race guidance, generated locale, and Strava snapshot.

**Acceptance Criteria:**

- AI-written coaching text is generated in requested locale.
- Structured paces are numeric seconds per kilometer.
- Race day is guidance only, not a session.
- Schema rejects prose-only pace targets.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `de5517c` - "feat(generate-plan): accept professional plan input"
- Generate-plan now validates and accepts `professionalPlanInput` while preserving authenticated user ownership from the JWT/user claim.
- Output schema now includes generated locale, numeric pace zones, workout targets, race guidance, support sessions, and a curated Strava coaching profile snapshot.
- AI prompt requests coaching text in the requested locale while keeping structured fields canonical.
- Race day remains guidance only; run and support sessions on the race date are filtered before persistence.
- Structured paces are numeric seconds per kilometer. Schema validation rejects prose, null, omitted, and `min > max` pace ranges.
- Strava/profile payload sent to OpenAI is allowlist-sanitized to avoid raw activities, names, tokens, streams, upstream errors, and unsafe nested fields.
- Strict OpenAI JSON schema was made compatible with `strict: true`, including recursive required-property coverage.
- Reviewer approved after privacy and security fixes.
- Verification passed:
  - `supabase/functions/generate-plan`: `deno check index.ts openai.ts schema.ts`
  - `supabase/functions/generate-plan`: focused `schema_test.ts openai_test.ts`
  - `supabase/functions/generate-plan`: full `deno test --allow-env --allow-net --allow-read`
- Phase 4 remains in progress because Task 10 is next.

### Task 10: Update Deterministic Plan Rules

**Files:**

- Modify: `supabase/functions/generate-plan/plan-rules.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`
- Test: `supabase/functions/generate-plan/weekly-volume-ramp_test.ts`

**Build:**

- Preserve user-selected run days.
- Preserve user hard-to-train days.
- Keep volume and ramp inside Strava safety limits.
- Place support sessions according to strength preferences.
- Reduce lower-body support sessions near race day.
- Avoid using older efforts to override recent safety.

**Acceptance Criteria:**

- User training-day count wins.
- Strava controls session size/intensity, not number of weekly run days.
- Aggressive race targets do not bypass safety limits.
- Lower-body support avoids day-before long runs and key workouts unless explicitly stacked after quality work.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `17d2c69` - "feat(generate-plan): apply Strava safety plan rules"
- Deterministic rules now keep `schedule.trainingDays` authoritative. Strava runs per week affects safety sizing only, not run-day count.
- Hard-to-train days remain rest when possible. Overconstrained hard days are easy or recovery only.
- New Strava coaching profile evidence and guardrails are used before legacy `athleteSummary` for weekly volume, ramp, and peak long-run safety.
- Final safety prevents later long-run normalization from bypassing Strava caps.
- Aggressive accepted race targets cannot bypass volume or long-run safety caps.
- Limited, sparse, and recovery guardrails prevent older efforts from raising long-run targets.
- Support sessions are normalized from strength preferences: weekly frequency, categories, preferred days, and same-day order.
- Lower-body and full-body support avoids race date, taper week, race week, day-before long runs, and day-before key workouts unless explicit run-first same-day stacking after quality work.
- Support guidance is categories-only, strips model exercise prescription text, and is locale-aware for English and Spanish.
- Reviewer approved.
- Verification passed:
  - `supabase/functions/generate-plan`: `deno check index.ts plan-rules.ts schema.ts openai.ts`
  - `supabase/functions/generate-plan`: focused `plan-rules_test.ts weekly-volume-ramp_test.ts`
  - `supabase/functions/generate-plan`: focused `schema_test.ts openai_test.ts`
  - `supabase/functions/generate-plan`: full `deno test --allow-env --allow-net --allow-read`

### Phase 4 Completion Notes (2026-06-03)

- Phase 4 is complete because Task 9 and Task 10 are complete.
- Phase 5 Task 11 is next.

## Phase 5: Plan UI And Session Detail

### Task 11: Update Plan Ready And Full Plan Views

**Files:**

- Modify: `apps/mobile/lib/features/onboarding/presentation/screens/plan_ready_screen.dart`
- Modify: `apps/mobile/lib/features/full_plan/presentation/screens/full_plan_screen.dart`
- Create: `apps/mobile/lib/features/training_plan/presentation/widgets/pace_zones_card.dart`
- Create: `apps/mobile/lib/features/training_plan/presentation/widgets/race_guidance_section.dart`
- Test: `apps/mobile/test/features/onboarding/presentation/plan_ready_screen_test.dart`
- Test: `apps/mobile/test/features/full_plan/presentation/full_plan_screen_test.dart`

**Build:**

- Pace zones reference.
- Race-day execution section.
- Coaching notes section.
- Support sessions in weekly plan views.

**Acceptance Criteria:**

- Race guidance appears after generation and later in plan/full-plan.
- Race day is not listed as a normal session.
- Pace zones are readable in English and Spanish.

**Status:** Complete

**Completion Notes (2026-06-03):**

- Commit: `deb7e37` - "feat(training-plan): show professional plan guidance"
- Plan ready and full plan now show race guidance and pace zones when present.
- New reusable `PaceZonesCard` and `RaceGuidanceSection` widgets were added.
- Full and weekly plan views render support sessions, including backend-style support metadata localized at the UI boundary.
- Race guidance and race day are not listed as normal session rows.
- TrainingPlan parsing handles backend-style support sessions and partial Strava snapshots safely.
- Training plan provider recomposition preserves pace zones, race guidance, generated locale, Strava snapshot, and support sessions.
- Pace zones are readable in English and Spanish, and support metadata avoids canonical key leakage.
- Reviewer approved after the support-session localization fix.
- Verification passed:
  - `apps/mobile`: `flutter gen-l10n`
  - `apps/mobile`: targeted plan ready, full plan, model, and provider tests
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test` (528 tests passed)
- Phase 5 remains in progress because Task 12 is next.

### Task 12: Update Session Detail

**Files:**

- Modify: `apps/mobile/lib/features/session_detail/presentation/screens/session_detail_screen.dart`
- Test: `apps/mobile/test/features/session_detail/presentation/session_detail_screen_test.dart`

**Build:**

- Structured target pace display.
- Effort cue display.
- Support session detail display.
- Target warnings/guidance copy before run.

**Acceptance Criteria:**

- Session detail never parses pace from coach notes.
- It shows target range and effort cue.
- It does not claim live pace feedback before a run is active.

## Phase 6: Active Run Pace Guidance

### Task 13: Add Low-Noise Live Pace Guidance

**Files:**

- Modify: `apps/mobile/lib/features/active_run/presentation/active_run_live_activity_mapper.dart`
- Modify: `apps/mobile/lib/features/active_run/presentation/active_run_live_activity_sync.dart`
- Create: `apps/mobile/lib/features/active_run/domain/live_pace_guidance.dart`
- Test: `apps/mobile/test/features/active_run/domain/live_pace_guidance_test.dart`

**Build:**

- Rolling pace evaluator.
- Tolerance windows.
- Sustained deviation detection.
- Calm guidance messages.
- Different behavior by workout zone.

**Acceptance Criteria:**

- No prompt for tiny deviations.
- No repeated alerts within a short cooldown.
- Easy/long runs warn more strongly about going too fast than too slow.
- Intervals/race-pace runs use narrower tolerances than easy runs.

## Phase 7: Verification

### Task 14: Run Localization Generation

**Command:**

```bash
cd apps/mobile
flutter gen-l10n
```

**Acceptance Criteria:**

- Generated localization files update cleanly.
- No user-facing strings in touched feature files bypass ARB.

### Task 15: Run Flutter Verification

**Command:**

```bash
cd apps/mobile
flutter analyze
flutter test
```

**Acceptance Criteria:**

- Analyzer passes.
- Tests pass.

### Task 16: Run Supabase Function Tests

**Commands:**

```bash
cd supabase/functions/strava-sync
deno test --allow-env --allow-net --allow-read
```

```bash
cd supabase/functions/generate-plan
deno test --allow-env --allow-net --allow-read
```

**Acceptance Criteria:**

- Strava sync tests pass.
- Generate plan tests pass.
- Schema tests pass.
- Plan rule tests pass.

## Recommended Implementation Order

1. Data contracts.
2. Strava sync enrichment.
3. Coaching profile derivation.
4. Onboarding replacement.
5. Strava Analysis screen.
6. Generate-plan backend contract.
7. Plan and session UI updates.
8. Support sessions.
9. Race guidance and pace zones.
10. Active run live pace guidance.

## Milestone Boundaries

### Milestone 1: Analysis Without Generation Changes

- New `StravaCoachingProfile`.
- Strava sync enrichment.
- Strava Analysis screen in isolation.

### Milestone 2: Professional Generation

- New plan-generation input.
- New generated plan schema.
- Supabase generate-plan updates.
- Plan-ready support for new output.

### Milestone 3: Full App Rendering

- Full plan.
- Session detail.
- Pace zones.
- Race guidance.
- Support sessions.

### Milestone 4: Live Guidance

- Active run pace guidance.
- Post-run pace adherence can be added later when activity data supports it.
