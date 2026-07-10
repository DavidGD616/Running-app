# PR 27 Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve every blocking finding from the PR #27 review so orchestration evidence is trustworthy, adaptive plan patches are safe at both generation and acceptance, and Flutter reports mutation failures instead of navigating as if they succeeded.

**Architecture:** Split the remediation into three independently testable boundaries. First, harden Codex hook event parsing against the current hook wire contract. Second, make adaptation reviews server-owned, validate patch semantics and dates, and revalidate at acceptance. Third, make Flutter cache server-owned reviews locally, route dismissals through the Edge Function, and navigate only on explicit success.

**Tech Stack:** Python 3 hooks and `unittest`; Deno/TypeScript, Zod, Supabase Edge Functions and PostgreSQL RLS; Flutter/Dart, Riverpod, `supabase_flutter`, ARB localization, and widget/provider tests.

---

### Task 1: Harden orchestrator evidence parsing

**Files:**
- Modify: `.codex/hooks/orchestrator_state.py`
- Modify: `.codex/hooks/subagent_stop.py`
- Modify: `.codex/hooks/stop.py`
- Test: `.codex/hooks/test_orchestrator_hooks.py`

- [ ] **Step 1: Add failing hook-contract regression tests**

Add tests that assert a string response containing a non-zero process exit is non-zero, a standard code-review section with a Major finding remains blocking, and `agent_transcript_path` is preferred for SubagentStop task recovery.

```python
def test_string_tool_response_preserves_nonzero_exit(self) -> None:
    event = {"tool_response": "Process exited with code 1"}
    self.assertEqual(orchestrator_state.parse_tool_exit_code(event), 1)

def test_standard_major_issues_section_is_blocking(self) -> None:
    review = "Major Issues (🟠)\n- App crashes on launch.\n\nOverall Assessment: APPROVE"
    self.assertTrue(subagent_stop.looks_blocking(review))
```

- [ ] **Step 2: Run the focused tests and confirm the new cases fail**

Run: `python3 .codex/hooks/test_orchestrator_hooks.py`

Expected: the new exit parsing, severity-section, and transcript-field cases fail before implementation.

- [ ] **Step 3: Implement strict event parsing**

Parse known exit-code fields recursively and recognize current string failure markers instead of treating every unknown response as success. Extend reviewer-section parsing to recognize `Critical Issues`, `Major Issues`, and `High Risk` headings with optional emoji/parenthetical suffixes, then inspect their bullets until the next section. Read `agent_transcript_path` for SubagentStop recovery and persist that path with the coder/reviewer stop record.

```python
PROCESS_EXIT_RE = re.compile(r"(?:process exited with code|exit[_ ]code\s*[:=])\s*(-?\d+)", re.I)

def extract_agent_transcript_path(event: Dict[str, Any]) -> str:
    value = event.get("agent_transcript_path")
    return value.strip() if isinstance(value, str) else ""
```

- [ ] **Step 4: Run hook tests and compilation**

Run: `python3 .codex/hooks/test_orchestrator_hooks.py`

Expected: all hook tests pass.

Run: `python3 -m py_compile .codex/hooks/*.py`

Expected: exit code 0 with no output.

### Task 2: Enforce adaptation safety at the server boundary

**Files:**
- Modify: `supabase/functions/adapt-plan/index.ts`
- Modify: `supabase/functions/adapt-plan/index_test.ts`
- Modify: `supabase/migrations/20260623000000_adaptation_reviews.sql`

- [ ] **Step 1: Add failing patch-validation and acceptance-boundary tests**

Cover missing targets, past/out-of-plan move dates, reductions that increase load, mixed `noChange` patches, and revalidation of stored patches before acceptance.

```typescript
Deno.test("validateAdaptationPatches rejects a move into the past", () => {
  const result = validateAdaptationPatches(
    [{ type: "moveSession", sessionId: "future", targetDate: "2020-01-01", reasonKey: "x" }],
    futureSessions,
    summary,
    { minDate: "2026-07-09", maxDate: "2026-09-30" },
  );
  assertEquals(result.ok, false);
});
```

- [ ] **Step 2: Run Deno tests and confirm the new cases fail**

Run from `supabase/functions/adapt-plan`: `deno test --allow-env --allow-net index_test.ts`

Expected: the new semantic/date validation cases fail before implementation.

- [ ] **Step 3: Make patch types semantically valid**

Require the fields implied by each supported patch type and reject unsupported/no-op combinations. Enforce that reductions only decrease load, replacements actually change session type, moves use a valid date within the remaining plan, and `noChange` is exclusive. Apply only the sanitized patches returned by validation.

```typescript
type PatchBounds = { minDate: string; maxDate: string };

if (patch.type === "moveSession" && patch.targetDate == null) {
  return { ok: false, reason: "move_requires_target_date" };
}
```

- [ ] **Step 4: Make reviews server-owned and revalidate on acceptance**

Replace the all-access RLS policy with a select-only policy for authenticated owners. Add a server-side `dismiss` action. During `accept`, reload the active plan, activities, and feedback, rebuild the weekly summary from trusted row dates, run the full patch validator again, and pass only the revalidated patch set to `applyPatchesToPlan`.

```sql
create policy "Users read own adaptation reviews"
  on public.adaptation_reviews for select
  using (auth.uid() = user_id);
```

- [ ] **Step 5: Run Deno tests and SQL integrity checks**

Run: `deno test --allow-env --allow-net index_test.ts`

Expected: all adaptation tests pass.

Run from repository root: `git diff --check`

Expected: exit code 0 with no output.

### Task 3: Make Flutter mutations explicit and failure-aware

**Files:**
- Modify: `apps/mobile/lib/features/training_plan/data/supabase_adaptation_repository.dart`
- Modify: `apps/mobile/lib/features/training_plan/presentation/adaptation_actions_provider.dart`
- Modify: `apps/mobile/lib/features/training_plan/presentation/screens/adaptation_review_screen.dart`
- Modify: `apps/mobile/lib/features/training_plan/presentation/screens/adaptation_diff_screen.dart`
- Modify: `apps/mobile/lib/l10n/app_en.arb`
- Modify: `apps/mobile/lib/l10n/app_es.arb`
- Test: `apps/mobile/test/features/training_plan/presentation/adaptation_actions_provider_test.dart`
- Test: `apps/mobile/test/features/training_plan/presentation/screens/adaptation_diff_screen_test.dart`

- [ ] **Step 1: Add failing provider and widget tests**

Assert that accept/dismiss return `false` on a `FunctionException`, preserve an `AdaptationActionFailure`, and leave the diff screen in place. Assert successful accept returns `true` and navigates to Today.

```dart
final applied = await container
    .read(adaptationActionsProvider.notifier)
    .acceptReview(review);
expect(applied, isFalse);
expect(container.read(adaptationActionsProvider), isA<AdaptationActionFailure>());
```

- [ ] **Step 2: Run focused Flutter tests and confirm the new cases fail**

Run from `apps/mobile`: `flutter test test/features/training_plan/presentation`

Expected: the new explicit-result and navigation cases fail before implementation.

- [ ] **Step 3: Implement server-owned review mutations**

Keep `saveAdaptationReviews` as a local-cache update for authenticated users; do not upsert server-owned review rows. Invoke the `dismiss` Edge Function action, return `Future<bool>` from accept/dismiss, check `ref.mounted` after awaits, and update local review state only after a successful server response.

```dart
Future<bool> acceptReview(AdaptationReview review) async {
  state = const AdaptationActionLoading();
  try {
    final response = await ref.read(adaptPlanFunctionClientProvider)(
      'adapt-plan',
      body: {'action': 'accept', 'reviewId': review.id},
    );
    final parsed = _mapFromDynamic(response.data);
    final versionId = parsed['versionId'];
    final rawPlan = parsed['plan'];
    final acceptedReview = _reviewFromResponse(response.data);
    if (versionId is! String || rawPlan is! Map || acceptedReview == null) {
      state = const AdaptationActionFailure('adaptation_parse_error');
      return false;
    }
    final plan = TrainingPlan.fromJson(
      rawPlan.map((key, value) => MapEntry('$key', value)),
    );
    if (plan == null) {
      state = const AdaptationActionFailure('adaptation_parse_error');
      return false;
    }
    await ref.read(planVersionRepositoryProvider).saveActivePlan(
      PlanVersion(
        id: versionId,
        generatedAt: DateTime.now(),
        requestedBy: 'adaptation',
        isActive: true,
        plan: plan,
      ),
    );
    await ref.read(adaptationReviewsProvider.notifier).recordReview(
      acceptedReview,
    );
    state = AdaptationPlanApplied(acceptedReview);
    return true;
  } catch (_) {
    if (ref.mounted) {
      state = const AdaptationActionFailure('adaptation_accept_failed');
    }
    return false;
  }
}
```

- [ ] **Step 4: Gate navigation and localize failures**

Navigate only when the notifier returns `true`. Render the typed failure state with new English and Spanish ARB entries on the review/diff screens. Do not compare logic against translated strings.

- [ ] **Step 5: Regenerate localization and run focused tests**

Run: `flutter gen-l10n`

Expected: generated localization Dart files reflect the ARB sources.

Run: `flutter test test/features/training_plan/presentation`

Expected: focused provider and widget tests pass.

### Task 4: Final verification, review, and PR update

**Files:**
- Verify every changed file in PR #27.

- [ ] **Step 1: Run the complete verification matrix**

Run from `apps/mobile`: `flutter analyze`

Run from `apps/mobile`: `flutter test`

Run from `supabase/functions/adapt-plan`: `deno test --allow-env --allow-net index_test.ts`

Run from repository root: `python3 .codex/hooks/test_orchestrator_hooks.py`

Run from repository root: `python3 -m py_compile .codex/hooks/*.py`

Run from repository root: `git diff --check`

Expected: every command exits 0.

- [ ] **Step 2: Complete an independent reviewer pass**

The reviewer must inspect correctness, security, performance, localization, and test coverage, then end with exactly one non-blocking verdict paragraph:

```text
Overall Assessment: APPROVE
```

- [ ] **Step 3: Commit and push the verified remediation**

Run:

```sh
git add .codex/hooks/orchestrator_state.py .codex/hooks/subagent_stop.py .codex/hooks/stop.py .codex/hooks/test_orchestrator_hooks.py supabase/functions/adapt-plan/index.ts supabase/functions/adapt-plan/index_test.ts supabase/migrations/20260623000000_adaptation_reviews.sql apps/mobile/lib/features/training_plan/data/supabase_adaptation_repository.dart apps/mobile/lib/features/training_plan/presentation/adaptation_actions_provider.dart apps/mobile/lib/features/training_plan/presentation/screens/adaptation_review_screen.dart apps/mobile/lib/features/training_plan/presentation/screens/adaptation_diff_screen.dart apps/mobile/lib/l10n/app_en.arb apps/mobile/lib/l10n/app_es.arb apps/mobile/lib/l10n/app_localizations.dart apps/mobile/lib/l10n/app_localizations_en.dart apps/mobile/lib/l10n/app_localizations_es.dart apps/mobile/test/features/training_plan/presentation/adaptation_actions_provider_test.dart apps/mobile/test/features/training_plan/presentation/screens/adaptation_diff_screen_test.dart docs/superpowers/plans/2026-07-09-pr27-review-remediation.md
```

Run: `git commit -m "fix: harden adaptive review approval flow"`

Run: `git push origin adaptive-coaching-review`

Expected: PR #27 updates to the new commit and remains mergeable.
