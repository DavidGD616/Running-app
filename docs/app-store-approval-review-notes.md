# App Store Approval Review Notes

PR: https://github.com/DavidGD616/Running-app/pull/17

## PR 17 Findings

- **P1 — RESOLVED** `apps/website/support.html:251` and `apps/website/support-es.html:251`: the FAQ says users can delete their account via `Settings -> Account -> Delete Account`. A real `Delete Account` path now exists in account settings (see _Real in-app account deletion_ below). The advertised path matches the app. ✅
- **P2** `apps/website/support.html:270` and `apps/website/support-es.html:270`: the FAQ says skipping a session automatically adjusts future sessions, but `TrainingPlanNotifier.skipSession` only records an adjustment/revision and marks the session skipped in state. Soften the support copy unless future-session recalculation is implemented elsewhere.
- **P2** `apps/website/support.html:82` and `apps/website/support-es.html:82`: the long support email is an unbroken inline-flex link inside a padded card, with no wrapping rule. It may overflow on narrow phones.

## Approval-Critical Improvements

1. **Real in-app account deletion — DONE ✅**
   - [x] Visible `Delete Account` path in account settings (`settings_account_screen.dart`), with a confirm dialog, localized EN/ES.
   - [x] Deletes the Supabase auth account; all user tables cascade-delete via `on delete cascade` on `auth.users`. Implemented in the `delete-account` Edge Function (service-role `auth.admin.deleteUser`).
   - [x] Clears local app data after deletion (`AuthNotifier._clearAllLocalState`), preserving only the locale preference.
   - [x] Sign in with Apple token revocation implemented: Apple refresh token captured at login (`store-apple-token` function + `apple_tokens` table) and revoked on deletion via Apple `auth/revoke`. Verified end-to-end — Apple sent the "has revoked your Sign in with Apple" confirmation email.
   - Deployment: migration `20260529000000_apple_tokens` pushed; `delete-account` + `store-apple-token` functions ACTIVE; `APPLE_TEAM_ID`/`APPLE_KEY_ID`/`APPLE_BUNDLE_ID`/`APPLE_PRIVATE_KEY` secrets set on project `hedwyrmfeaqcqqwbexzf`.
   - Branch: `feat/account-deletion`.

2. **Working Support URL — VERIFIED ✅**
   - [x] `https://striviq.fit/support` (the App Store Connect URL) returns **200** and serves the real Support page (`<title>Support — StrivIQ</title>`, identical to `/support.html`).
   - [x] `/support.html`, `/support-es`, `/support-es.html` all return **200**.
   - Website source lives in `apps/website/` (`support.html`, `support-es.html`, `index.html`, `index-es.html`, `CNAME`). No fallback page needed — extensionless and `.html` forms both resolve.

3. **Remove or disable fake subscription UI — DONE ✅**
   - [x] Deleted the mock subscription screens (`settings_subscription_screen.dart`, `settings_cancel_subscription_screen.dart`) — they showed a hardcoded `StrivIQ Pro` plan, a fake next-billing date, auto-renew copy, and a cancellation flow with no StoreKit/IAP behind it.
   - [x] Removed the Settings entry row, both routes (`/settings/subscription`, `/settings/subscription/cancel`) and their `RouteNames` constants.
   - [x] Purged all subscription/`StrivIQ Pro` strings from `app_en.arb` and `app_es.arb` and regenerated l10n. No `StrivIQ Pro`, billing, auto-renew, or cancellation copy remains in the app.
   - Re-add behind StoreKit/IAP when a real subscription ships (recoverable from git history).

4. **Accurate support/legal copy**
   - [x] Account deletion now exists in the app, so the FAQ deletion claim is accurate.
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
