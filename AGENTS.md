# Codex Rules

Don't use never your sign or your message of "Co-Authored-By: Codex Sonnet 4.6 <noreply@anthropic.com>" or similar

## MCP Tools

Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Project Context

- This project is a running app. Its core product purpose is to create training plans, track user progress, and help users follow their plan and individual sessions.
- This repo is a single Flutter app rooted at `apps/mobile/`. There are no local packages or backend services in this repository. `docs/` contains design references, plans, and screen specs; it is not executable app code.
- Current mobile stack:
  - Flutter/Dart (`sdk: ^3.11.1`)
  - Material 3
  - `go_router` for navigation
  - `flutter_riverpod` for app state
  - `shared_preferences` for lightweight persistence
  - `google_fonts` for typography
  - `flutter_svg` for icons
  - Flutter `intl`/`flutter_localizations` for i18n
- Architecture is feature-first under `apps/mobile/lib/`:
  - `core/router/` holds route constants and the global `GoRouter`
  - `core/theme/` holds design tokens and the dark theme
  - `core/widgets/` holds reusable app-specific UI building blocks
  - `features/*/presentation/screens/` holds screen widgets
  - `features/*/domain/` and `features/*/data/` exist only where lightweight models/seed data are already needed
  - `l10n/` contains ARB files plus generated localization Dart files
- Navigation shape:
  - App starts at `/` via `SplashScreen`
  - Router redirect checks `OnboardingNotifier.isCompleted()` and sends completed users to `/today`
  - Main in-app navigation is a `StatefulShellRoute.indexedStack` with 4 tabs: `today`, `plan`, `progress`, `settings`
  - Additional flows exist for auth, account setup, onboarding, session detail, pre-run, log run, and full-plan screens
- Data/persistence boundaries are important:
  - There is no backend, API client, database, Firebase, Supabase, or network layer in the repo today
  - `training_plan_provider` builds an in-memory 12-week seed plan from `training_plan_seed_data.dart`
  - `progress_provider` derives chart/streak stats from the training plan plus static seed recent-session data
  - Session skip/restore mutates Riverpod state only for the current run of the app
  - `SharedPreferences` is currently used for locale, user preferences, and the onboarding-completed flag
  - Onboarding answers themselves are still stored in an in-memory `Map<String, dynamic>` inside `onboarding_provider.dart`; they are not fully persisted yet
- Implementation status:
  - The app is currently UI-heavy and mock-data-driven
  - Auth/account/settings/device integrations are mostly presentation flows and local state, not real service integrations
  - Many screens are complete visually, but some actions are still placeholders with empty `onTap` handlers
- Visual/design conventions:
  - Dark mode is the only implemented theme
  - Theme tokens live in `core/theme/`; prefer those over raw values
  - Inter is the app font via `google_fonts`
  - Icons are SVG assets in `apps/mobile/assets/icons/`
  - `docs/running-app-system-desing.md` is the main design-token/design-system reference
- Localization conventions:
  - Supported locales are English and Spanish
  - Locale defaults from device locale, then persists via `localeProvider`
  - Treat `app_en.arb` and `app_es.arb` as the source of truth; never hand-edit generated localization Dart files
  - Never use visible UI text as internal state, persisted values, model fields, or provider keys. Store canonical keys/enums/ids and localize only at the UI boundary.
  - When creating or modifying any user-facing screen, widget, provider, formatter, seed data, or summary view, audit every visible string and confirm it comes from localization or from locale-aware formatting.
  - If a stored value will later be rendered to the user, do not store the translated label. Store a stable canonical value and map it through `AppLocalizations` when displaying it.
  - Avoid hardcoded English or Spanish display strings in feature files outside `l10n/`, except for non-translatable internal identifiers.
  - Dates, times, month names, and any locale-sensitive formatting must use the active locale.
  - After touching localized UI flows, verify the affected path conceptually in both English and Spanish and check for mixed-language regressions.
- Useful docs when planning larger changes:
  - `docs/running_app_mvp_plan.md` for product scope
  - `docs/data-models.md` for current domain model intent
  - `docs/dynamic-data-local-persistence-plan.md` for the intended persistence direction
  - `docs/remaining-screens.md` and the HTML screen docs for UI references
- Verification baseline:
  - Run commands from `apps/mobile/`
  - `flutter analyze`      # static analysis, type errors
  - `flutter test`         # unit + widget tests
  - `flutter gen-l10n`     # regenerate if you touched .arb files

## Localization (ARB files)

Never hardcode dynamic values (numbers, distances, durations, counts) directly in ARB string values. Use Flutter's ARB placeholder system instead so the text template is fixed in translations and the actual values come from session/model data at runtime.

Example:
```json
"sessionPhaseIntervalsMainNote": "{reps} × {repDistance} at hard effort · RPE 8–9",
"@sessionPhaseIntervalsMainNote": {
  "placeholders": {
    "reps": { "type": "int" },
    "repDistance": { "type": "String" }
  }
}
```

After editing any ARB file, run `flutter gen-l10n` from `apps/mobile/` to regenerate the `.dart` l10n files. Never edit the generated files by hand.

## Localization Workflow

- If you touch or create a user-facing file, check whether any visible text is bypassing localization.
- Treat raw English or Spanish UI text in `apps/mobile/lib/` as a likely bug unless it is an intentional internal identifier.
- Do not compare logic against translated strings like `Yes`, `No`, `Half Marathon`, or `Skip for now`. Compare against canonical keys/enums instead.
- Do not place display copy in seed data, provider state, or domain models unless the field is explicitly designed as localized presentation output.
- Summary screens, review screens, and confirmation screens must localize from canonical stored values, not render previously saved labels directly.
- When adding a new option list, define stable internal values first, then map them to `app_en.arb` and `app_es.arb`.
