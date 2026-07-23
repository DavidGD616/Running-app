# PR 28 Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve every blocking PR #28 review finding so Edit Goal drafts are account-safe, selected changes are exact, fitness evidence is recent and hard, previews show upcoming weeks, and evidence copy is localized.

**Architecture:** Make draft ownership and original-goal state explicit at the Flutter domain boundary, then enforce fitness-evidence provenance at the Edge Function boundary. Derive preview-only presentation data with pure helpers and send canonical evidence reason keys to Flutter for localization. Cover each boundary with a regression test and land each fix in an atomic commit.

**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, ARB localization, widget/provider tests; Deno/TypeScript, Zod, Supabase Edge Functions; Git and GitHub CLI.

---

### Task 1: Scope Edit Goal drafts to the authenticated account

**Files:**
- Modify: `apps/mobile/lib/features/settings/presentation/edit_goal_provider.dart`
- Test: `apps/mobile/test/features/settings/edit_goal_provider_test.dart`

- [ ] **Step 1: Add a failing account-isolation test**

Construct stores for two users sharing one `SharedPreferences` instance, save a draft as user A, and assert user B loads no local draft when user B has no remote record.

```dart
final userAStore = EditGoalDraftStore(
  preferences: preferences,
  client: null,
  userId: 'user-a',
);
final userBStore = EditGoalDraftStore(
  preferences: preferences,
  client: null,
  userId: 'user-b',
);
expect(await userBStore.load(), isNull);
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run from `apps/mobile`: `flutter test test/features/settings/edit_goal_provider_test.dart`

Expected: the account-isolation assertion fails with the current global storage key.

- [ ] **Step 3: Implement user-scoped storage**

Replace the global key with a key derived from the authenticated user ID, retaining a guest key only when there is no authenticated user. Pass the stable user ID into the store instead of letting account ownership remain implicit.

```dart
String get _storageKey => _userId == null
    ? 'edit_goal_draft_v2_guest'
    : 'edit_goal_draft_v2_$_userId';
```

- [ ] **Step 4: Run the focused tests and commit**

Run: `flutter test test/features/settings/edit_goal_provider_test.dart`

Expected: all Edit Goal provider tests pass.

Commit: `fix: isolate edit goal drafts by account`

### Task 2: Make selected goal changes authoritative

**Files:**
- Modify: `apps/mobile/lib/features/settings/domain/edit_goal_models.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/edit_goal_form_screen.dart`
- Test: `apps/mobile/test/features/settings/edit_goal_models_test.dart`
- Test: `apps/mobile/test/features/settings/presentation/edit_goal_screens_test.dart`

- [ ] **Step 1: Add failing selection regression tests**

Assert that deselecting distance restores the original race and deselecting date restores the original date. Assert the preview payload contains only the effective goal produced from selected changes.

```dart
final reverted = changed.restoreChange(
  EditGoalChange.distance,
  originalGoal: original,
);
expect(reverted.race, original.race);
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run: `flutter test test/features/settings/edit_goal_models_test.dart test/features/settings/presentation/edit_goal_screens_test.dart`

Expected: deselected fields remain mutated before implementation.

- [ ] **Step 3: Represent the original goal explicitly**

Store an immutable `originalGoal` in the draft and add a pure `withChangeSelection` method that restores the original field whenever a change is deselected. Keep JSON backward-compatible by reconstructing the original goal from the current profile when loading legacy drafts.

```dart
EditGoalDraft withChangeSelection(EditGoalChange change, bool selected) {
  final nextChanges = {...changes};
  selected ? nextChanges.add(change) : nextChanges.remove(change);
  return copyWith(
    changes: nextChanges,
    race: !selected && change == EditGoalChange.distance
        ? originalGoal.race
        : race,
  );
}
```

- [ ] **Step 4: Update the form, run tests, and commit**

Run the same focused Flutter command.

Expected: all model and screen tests pass.

Commit: `fix: apply only selected goal changes`

### Task 3: Enforce recent hard-effort evidence

**Files:**
- Modify: `supabase/functions/edit-goal/handler.ts`
- Modify: `supabase/functions/edit-goal/handler_test.ts`
- Modify: `apps/mobile/lib/features/settings/domain/edit_goal_models.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/edit_goal_form_screen.dart`
- Test: `apps/mobile/test/features/settings/presentation/edit_goal_screens_test.dart`

- [ ] **Step 1: Add failing stale/easy evidence tests**

Cover an undated stored onboarding benchmark, a recent easy activity, and a recent activity explicitly confirmed as hard. The first two must remain behind the fitness-check gate.

```typescript
Deno.test("undated stored benchmark cannot bypass the fitness check", async () => {
  const response = await handler(request(previewBody()));
  assertEquals((await response.json()).state, "fitness_check_required");
});
```

- [ ] **Step 2: Run focused Deno and Flutter tests and confirm failure**

Run from `supabase/functions/edit-goal`: `deno test --allow-env handler_test.ts`

Run from `apps/mobile`: `flutter test test/features/settings/presentation/edit_goal_screens_test.dart`

Expected: stored undated evidence and unconfirmed suggestions currently unlock a proposal.

- [ ] **Step 3: Require dated provenance and explicit hard-effort confirmation**

Do not use undated `brief.evidenceTarget` values as current evidence. Return suggested activity candidates as untrusted candidates and require the runner to confirm that the chosen effort was hard before creating `EditGoalFitnessResult(hardEffort: true)`.

```typescript
if (manual == null) return null;
```

```dart
EditGoalFitnessResult(
  source: EditGoalFitnessSource.manual,
  distanceKm: activity.distanceKm,
  elapsed: activity.elapsed,
  recordedOn: activity.recordedOn,
  hardEffort: confirmedHardEffort,
)
```

- [ ] **Step 4: Run tests and commit**

Run both focused commands again.

Expected: all evidence tests pass.

Commit: `fix: require recent hard fitness evidence`

### Task 4: Preview the actual upcoming two weeks

**Files:**
- Modify: `apps/mobile/lib/features/settings/presentation/screens/edit_goal_preview_screen.dart`
- Test: `apps/mobile/test/features/settings/presentation/edit_goal_screens_test.dart`

- [ ] **Step 1: Add a failing later-plan preview test**

Build a proposal whose preserved sessions include weeks 1-4 and whose current week is 5. Assert the “next two weeks” section renders weeks 5 and 6 and not weeks 1 and 2.

```dart
expect(find.text('Week 5'), findsOneWidget);
expect(find.text('Week 6'), findsOneWidget);
expect(find.text('Week 1'), findsNothing);
```

- [ ] **Step 2: Run the widget test and confirm failure**

Run: `flutter test test/features/settings/presentation/edit_goal_screens_test.dart`

Expected: the current implementation renders the first historical weeks.

- [ ] **Step 3: Derive upcoming weeks with a pure helper**

Filter `allWeeks` by `weekNumber >= currentWeekNumber`, take two for the primary preview, and place only later upcoming weeks in the expansion.

```dart
final upcomingWeeks = proposal.candidatePlan.allWeeks
    .where((week) => week.weekNumber >= proposal.candidatePlan.currentWeekNumber)
    .toList(growable: false);
```

- [ ] **Step 4: Run tests and commit**

Run the focused widget test.

Expected: the later-plan preview shows the current and following week.

Commit: `fix: preview upcoming goal plan weeks`

### Task 5: Localize evidence reasons at the UI boundary

**Files:**
- Modify: `supabase/functions/edit-goal/handler.ts`
- Modify: `supabase/functions/edit-goal/handler_test.ts`
- Modify: `apps/mobile/lib/features/settings/domain/edit_goal_models.dart`
- Modify: `apps/mobile/lib/features/settings/presentation/screens/edit_goal_preview_screen.dart`
- Modify: `apps/mobile/lib/l10n/app_en.arb`
- Modify: `apps/mobile/lib/l10n/app_es.arb`
- Regenerate: `apps/mobile/lib/l10n/app_localizations.dart`
- Regenerate: `apps/mobile/lib/l10n/app_localizations_en.dart`
- Regenerate: `apps/mobile/lib/l10n/app_localizations_es.dart`
- Test: `apps/mobile/test/features/settings/edit_goal_models_test.dart`
- Test: `apps/mobile/test/features/settings/presentation/edit_goal_screens_test.dart`

- [ ] **Step 1: Add failing canonical-reason and Spanish rendering tests**

Assert the API returns `reason: "manual_recent_hard_result"` rather than display prose and that Spanish renders the localized ARB value without English evidence copy.

```dart
expect(find.text('Resultado reciente de esfuerzo intenso'), findsOneWidget);
expect(find.text('Recent hard running result'), findsNothing);
```

- [ ] **Step 2: Run focused tests and confirm failure**

Run the relevant Deno handler and Flutter model/widget tests.

Expected: raw English descriptions are currently rendered.

- [ ] **Step 3: Replace descriptions with typed reason keys**

Define an enum in Dart, emit a closed reason union from TypeScript, parse it strictly, and map the enum through `AppLocalizations` only in the widget.

```dart
enum GoalEditEvidenceReason {
  manualRecentHardResult('manual_recent_hard_result'),
  completedAssessment('completed_assessment');
}
```

- [ ] **Step 4: Regenerate localization, run tests, and commit**

Run from `apps/mobile`: `flutter gen-l10n`

Run the focused Deno and Flutter tests.

Expected: English and Spanish evidence rendering pass without mixed-language output.

Commit: `fix: localize goal evidence reasons`

### Task 6: Full verification, review, and PR update

**Files:**
- Verify every file changed by the remediation and the full PR #28 diff.

- [ ] **Step 1: Run the full verification matrix**

Run from `apps/mobile`: `flutter analyze`

Run from `apps/mobile`: `flutter test`

Run from `supabase/functions/edit-goal`: `deno test --allow-env handler_test.ts`

Run from `supabase/functions/generate-plan`: `deno test --allow-env`

Run from the repository root: `python3 .codex/hooks/test_orchestrator_hooks.py`

Run from the repository root: `python3 -m py_compile .codex/hooks/*.py`

Run from the repository root: `supabase test db supabase/tests/database/edit_goal_proposals_test.sql` when Docker is available.

Run from the repository root: `git diff --check origin/main...HEAD`

Expected: every available command exits 0; an unavailable Docker database is reported explicitly rather than treated as a pass.

- [ ] **Step 2: Perform a fresh four-layer review**

Review correctness, security, performance, localization, maintainability, test coverage, and the five Laws of Elegant Defense. Fix and commit any finding at 80% or greater confidence, then rerun affected and full checks.

- [ ] **Step 3: Push and update PR #28**

Run: `git push -u origin feature/edit-goal-preview`

Use `gh pr view 28 --json isDraft,mergeable,mergeStateStatus,statusCheckRollup` to confirm the updated head. Keep the PR draft unless the user explicitly asks to mark it ready.

Expected: PR #28 points at the verified commits and remains mergeable.
