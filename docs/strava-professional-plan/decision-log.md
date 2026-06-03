# Strava Professional Plan Decision Log

This file records the decisions made during product discovery for the Strava professional plan feature.

## Decisions

1. Strava should be used as a coaching evidence layer, not only to classify users as beginner/intermediate/experienced.
2. Use a curated Strava coaching profile with metrics plus selected evidence points.
3. Show a Strava Analysis screen before plan creation.
4. The Strava Analysis screen should include numbers plus plain-language coaching conclusions.
5. Focus this scope only on onboarding plan creation, not settings/update-plan flows.
6. Generated plans should include personalized target paces.
7. Store paces internally as seconds per kilometer and display `/mi` or `/km` by user preference.
8. Show primary and stretch race targets before plan creation.
9. Let the user adjust the primary target, but preserve Strava-derived safety limits.
10. Show 0 to 3 calm training guardrails when data suggests risk.
11. Include strength support, but ask onboarding for strength habits instead of relying on Strava.
12. Ask same-day run/lift order preference.
13. Strength should be scheduled support sessions, not only notes.
14. Strength support categories are lower body, upper body, core/mobility, and full body.
15. Do not prescribe exact strength exercises in the first version.
16. Strong Strava data should replace most manual fitness questions.
17. Weak Strava data should show limited analysis and ask targeted manual fitness questions.
18. Show the data window, especially the last 12 weeks.
19. Use last 12 weeks as the main coaching window.
20. Use older best efforts up to around 6 months as secondary evidence only.
21. Include a plan focus summary.
22. Strava Analysis is read-only. Users edit targets and preferences, not measured conclusions.
23. Plan intensity is user-selected: conservative, balanced, ambitious.
24. The app should not recommend an intensity level.
25. Phase data usage: enriched summaries first, selected detailed streams later.
26. Show evidence dates but not Strava activity names by default.
27. Store the full Strava coaching snapshot with the plan version.
28. Store only lightweight Strava state in the runner profile.
29. Include privacy-safe provenance in the plan snapshot.
30. Do not show a persistent "built from Strava" banner after plan creation.
31. Strava Analysis is mandatory after connecting Strava.
32. For strong data, present "Use Strava Analysis" as the recommended path.
33. Weekly run days are 100 percent user choice.
34. Hard-to-train days and preferred long-run day are user preferences.
35. Strava Analysis shows observed run frequency, not a recommendation.
36. Show general pace zones and race-specific pace after goal is known.
37. Include terrain/elevation context.
38. Ask optional race-course terrain: flat, rolling, hilly, not sure.
39. Use HR behind the scenes for confidence, not as primary workout targets.
40. Runs drive the running plan. Non-runs are background context only.
41. Keep the Strava Analysis screen focused on running.
42. Do not ask an extra "does this reflect your current fitness?" question.
43. Show a subtle data confidence label.
44. Create a formal spec in a new folder under `docs/`.
45. Redesign onboarding around professional plan creation.
46. Replace the old onboarding completely because the app is not live.
47. Change the plan schema/model as part of this work.
48. Include race execution guidance, but do not include race day as a session.
49. Make race guidance accessible later from plan/full-plan views.
50. Race guidance should resemble the demo with "Race-day execution" and "Coaching notes."
51. Add a post-generation pace zones card/screen.
52. Session detail should show structured pace targets; live fast/slow guidance belongs to active run.
53. Live pace guidance should be calm, coach-like, and low-noise.
54. Spanish support is required in the first implementation.
55. Store AI-written coaching text in the selected language at generation time.
56. Execute the implementation through a review-gated sequential sub-agent pipeline.
57. Use one Codex coder sub-agent per implementation task, with GPT-5.3 Codex as the coder model.
58. Commit every completed task separately after reviewer approval.
59. Update the implementation plan after each task with status, commit hash, and verification notes.

## Deferred Decisions

- Exact generated plan schema names.
- Exact confidence thresholds.
- Exact guardrail thresholds.
- Whether support sessions are stored in the same list as run/rest sessions or separately.
- Whether active run live pace guidance ships with initial professional generation or a later milestone.
- Whether post-run target adherence recaps are included later.

## Implementation Updates

### 2026-06-03 - Phase 1 Data Contracts Complete

- Task 1 completed in commit `c687652` - "feat(strava): add StravaCoachingProfile data contract models"
- Task 2 completed in commit `7605629` - "feat(onboarding): add ProfessionalPlanInput data contract"
- Task 3 completed in commit `95abd67` - "feat(training_plan): add professional plan schema with pace targets, race guidance, support sessions"
- Phase 1 acceptance criteria were met.
- Tests pass.

### 2026-06-03 - Phase 2 Task 4 Complete

- Task 4 completed in commit `ccd9615` - "feat(strava): enrich synced activity summaries"
- Reviewer approved with no findings after fix passes.
- Verification passed:
  - `supabase/functions/strava-sync`: `deno test --allow-env --allow-net --allow-read index_test.ts` (8 passed)
  - `apps/mobile`: `flutter test test/features/strava/data/strava_service_test.dart` (13 passed)
- Phase 2 remains in progress because Task 5 is next.

### 2026-06-03 - Phase 2 Task 5 Complete

- Task 5 completed in commit `c9a18c4` - "feat(strava): derive coaching profile analysis"
- Reviewer approved with no findings after fix passes.
- Verification passed:
  - `apps/mobile`: `flutter test test/features/strava/strava_coaching_profile_builder_test.dart` (14 passed)
  - `apps/mobile`: `flutter test test/features/strava/athlete_summary_test.dart test/features/strava/strava_coaching_profile_test.dart` (24 passed)
  - `apps/mobile`: `flutter analyze` (No issues found)

### 2026-06-03 - Phase 2 Strava Sync And Analysis Complete

- Phase 2 is complete because Task 4 and Task 5 are complete.
- Phase 3 Task 6 is next.

### 2026-06-03 - Phase 3 Task 6 Complete

- Task 6 completed in commit `8b805a1` - "feat(onboarding): route Strava users through analysis"
- Reviewer approved with no findings after fix pass.
- Verification passed:
  - `apps/mobile`: `flutter test test/core/router/app_router_test.dart test/features/onboarding/presentation/goal_flow_widget_test.dart test/features/onboarding/presentation/onboarding_provider_test.dart test/features/onboarding/presentation/strava_connect_screen_test.dart test/features/profile/data/runner_profile_repository_test.dart`
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test` (496 tests passed)

### 2026-06-03 - Phase 3 Task 7 Complete

- Task 7 completed in commit `89be6df` - "feat(onboarding): build Strava analysis screen"
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

### 2026-06-03 - Phase 3 Task 8 Complete

- Task 8 completed in commit `e35077d` - "feat(onboarding): add strength preferences step"
- New localized Strength Preferences onboarding screen was added at `/onboarding/strength`.
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

### 2026-06-03 - Phase 3 Onboarding Replacement Complete

- Phase 3 is complete because Task 6, Task 7, and Task 8 are complete.
- Phase 4 Task 9 is next.

### 2026-06-03 - Phase 4 Task 9 Complete

- Task 9 completed in commit `de5517c` - "feat(generate-plan): accept professional plan input"
- Generate-plan now validates and accepts `professionalPlanInput` while preserving authenticated user ownership from the JWT/user claim.
- Generated plan output now includes generated locale, numeric pace zones, workout targets, race guidance, support sessions, and a curated Strava coaching profile snapshot.
- AI prompting requests coaching text in the requested locale and keeps structured output fields canonical.
- Race day is guidance only. Run and support sessions on the race date are filtered before persistence.
- Structured paces are numeric seconds per kilometer. Schema validation rejects prose, null, omitted, and `min > max` pace ranges.
- OpenAI receives only an allowlist-sanitized Strava/profile payload, excluding raw activities, names, tokens, streams, upstream errors, and unsafe nested fields.
- Strict OpenAI JSON schema compatibility with `strict: true` was fixed, including recursive required-property coverage.
- Reviewer approved after privacy and security fixes.
- Verification passed:
  - `supabase/functions/generate-plan`: `deno check index.ts openai.ts schema.ts`
  - `supabase/functions/generate-plan`: focused `schema_test.ts openai_test.ts`
  - `supabase/functions/generate-plan`: full `deno test --allow-env --allow-net --allow-read`
- Phase 4 remains in progress because Task 10 is next.

### 2026-06-03 - Phase 4 Task 10 Complete

- Task 10 completed in commit `17d2c69` - "feat(generate-plan): apply Strava safety plan rules"
- Deterministic rules now keep `schedule.trainingDays` authoritative. Strava runs per week affects safety sizing only, not run-day count.
- Hard-to-train days remain rest when possible. Overconstrained hard days are easy or recovery only.
- Strava coaching profile evidence and guardrails are used before legacy `athleteSummary` for weekly volume, ramp, and peak long-run safety.
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

### 2026-06-03 - Phase 4 Plan Generation Backend Complete

- Phase 4 is complete because Task 9 and Task 10 are complete.
- Phase 5 Task 11 is next.

### 2026-06-03 - Phase 5 Task 11 Complete

- Task 11 completed in commit `deb7e37` - "feat(training-plan): show professional plan guidance"
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

### 2026-06-03 - Phase 5 Task 12 Complete

- Task 12 completed in commit `3a0911d` - "feat(session-detail): show structured targets and support details"
- Session detail now shows structured target pace ranges from `WorkoutTarget` and `WorkoutStep` numeric data only.
- Effort cues are displayed when present, with localized effort fallback.
- Pre-run guidance avoids promising live pace feedback before active run.
- Support session details are reachable from full and weekly plan support rows and render localized metadata/details without canonical key leakage.
- Unknown support metadata is hidden instead of humanized.
- Race/run navigation remains safe.
- Reviewer approved after the support metadata leak fix.
- Verification passed:
  - `apps/mobile`: `flutter gen-l10n`
  - `apps/mobile`: targeted session detail, full plan, and pre-run tests
  - `apps/mobile`: `flutter analyze` (No issues found)
  - `apps/mobile`: `flutter test` (535 tests passed)

### 2026-06-03 - Phase 5 Plan UI And Session Detail Complete

- Phase 5 is complete because Task 11 and Task 12 are complete.
- Phase 6 Task 13 is next.
