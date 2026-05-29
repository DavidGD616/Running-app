# App Store Approval Review Notes

PR: https://github.com/DavidGD616/Running-app/pull/17

## PR 17 Findings

- **P1** `apps/website/support.html:251` and `apps/website/support-es.html:251`: the FAQ says users can delete their account via `Settings -> Account -> Delete Account`, but the app's account settings currently expose profile fields, email, password, and logout only. This is risky for App Review because it advertises an account-deletion path that does not exist.
- **P2** `apps/website/support.html:270` and `apps/website/support-es.html:270`: the FAQ says skipping a session automatically adjusts future sessions, but `TrainingPlanNotifier.skipSession` only records an adjustment/revision and marks the session skipped in state. Soften the support copy unless future-session recalculation is implemented elsewhere.
- **P2** `apps/website/support.html:82` and `apps/website/support-es.html:82`: the long support email is an unbroken inline-flex link inside a padded card, with no wrapping rule. It may overflow on narrow phones.

## Approval-Critical Improvements

1. **Real in-app account deletion**
   - Add a visible `Delete Account` path in account settings.
   - Make it delete the Supabase auth account and associated app data.
   - Clear local app data after deletion.
   - If Sign in with Apple was used, handle token revocation where applicable.

2. **Working Support URL**
   - App Store Connect uses `https://striviq.fit/support`.
   - Verify that exact URL returns HTTP 200 after PR 17 deploys.
   - If GitHub Pages still returns 404 for `/support`, either add `apps/website/support/index.html` or update App Store Connect to `https://striviq.fit/support.html`.

3. **Remove or disable fake subscription UI**
   - If there is no real IAP/subscription in v1, do not show `StrivIQ Pro`, billing dates, auto-renew copy, or cancellation UI.
   - Keep subscription screens hidden until StoreKit/IAP is implemented.

4. **Accurate support/legal copy**
   - Do not claim account deletion exists until the app actually supports it.
   - Do not claim skipped sessions automatically adjust future sessions unless future-session recalculation is implemented.

5. **Reviewer access**
   - Keep the App Review demo account active, confirmed, and documented in App Review notes.
   - Mention that Sign in with Apple works as an alternate login path.
   - Ensure backend services and test data are available throughout review.

6. **Location and Health review notes**
   - Explain that background location is used only during active runs.
   - Explain that Apple Health access is only used for writing completed workouts/routes when the user connects Apple Health.

## Checks Run

- `gh pr view 17`
- `gh pr diff 17 --name-only`
- `git diff --check 3bf3ae9...HEAD`
- Internal static link check over `apps/website/*.html`
- `gh pr checks 17` returned no reported checks
