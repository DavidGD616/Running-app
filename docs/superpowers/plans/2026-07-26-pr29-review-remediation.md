# PR 29 Review Remediation Implementation Plan

> **For agentic workers:** Execute each task test-first, keep unrelated worktree changes untouched, and commit the mobile and Edge Function fixes separately.

**Goal:** Resolve every blocking PR #29 review finding so New Goal plans cannot start in the past, retries remain idempotent, assessment results can be completed and persisted, recommendation metadata matches the generated plan, proposal navigation is reversible, and fallback race sessions never precede the plan.

**Architecture:** Enforce timeline invariants at both the Flutter draft boundary and Edge Function request boundary. Preserve proposal and assessment state through recoverable transitions instead of reconstructing it. Keep plan-length and fallback-session derivation pure and cover each repaired boundary with focused regression tests.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, SharedPreferences, ARB localization, widget/provider tests; Deno/TypeScript, Zod, Supabase Edge Functions; Git.

---

### Task 1: Harden mobile draft and recovery flows

**Files:**
- Modify: `apps/mobile/lib/features/settings/domain/new_goal_models.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/new_goal_provider.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/new_goal_schedule_screen.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/new_goal_review_screen.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/new_goal_manual_result_screen.dart`
- Test: `apps/mobile/test/features/settings/new_goal_provider_test.dart`
- Test: `apps/mobile/test/core/router/app_router_test.dart`

- [ ] Add failing tests for stale profile/restored plan dates and reject dates before today or after a dated race.
- [ ] Add a failing provider test proving an apply timeout can retry the same proposal successfully.
- [ ] Add failing provider/router tests proving a pending assessment can accept a result, retain its identity, and persist completion.
- [ ] Add a failing router test proving the full proposed plan can pop back to the proposal.
- [ ] Inject the current date into fresh-draft creation, normalize invalid restored dates, and validate the invariant before preview.
- [ ] Recover the recommendation from failure proposal state so idempotent apply retries remain possible.
- [ ] route pending assessments to the manual-result form, classify the result as assessment evidence, retain it through completion, and persist explicit cancellation.
- [ ] Push the full-plan route onto the proposal stack.
- [ ] Run focused Flutter tests, format touched Dart files, then commit the mobile fixes.

### Task 2: Align Edge Function timelines and recommendation metadata

**Files:**
- Modify: `supabase/functions/new-goal/handler.ts`
- Modify: `supabase/functions/new-goal/handler_test.ts`
- Modify: `supabase/functions/new-goal/deno.json`

- [ ] Add failing request validation tests for missing local date and plan starts before the local date.
- [ ] Add a failing recommendation test where the source plan is shorter than the new dated plan.
- [ ] Add a failing same-day race fallback test proving no session precedes the plan start.
- [ ] Require the trusted local date and reject past plan starts.
- [ ] Derive dated recommendation weeks from the new goal window rather than the source plan duration.
- [ ] Emit fallback support sessions only when their dates are inside the candidate plan window.
- [ ] Resolve production and test lint findings without suppressing functional checks.
- [ ] Run Deno format, lint, check, and focused tests, then commit the Edge Function fixes.

### Task 3: Complete verification and fresh merge-safety review

- [ ] Run `flutter gen-l10n` if ARB files changed.
- [ ] Run the full Flutter analyzer and test suite.
- [ ] Run full New Goal Deno format, lint, check, and test commands.
- [ ] Run SQL integration tests if a local Docker database is available; otherwise record the environment limitation.
- [ ] Run `git diff --check` and inspect every changed hunk plus the final commit range.
- [ ] Perform a fresh code review; fix and commit any remaining merge blockers.
- [ ] Push only the reviewed commits to the existing PR branch and report the final merge-safety verdict.
