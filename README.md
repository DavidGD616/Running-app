# StrivIQ

StrivIQ is a personal running coach app built around adaptive race training. The product helps runners create a goal-based plan, follow weekly sessions, track live runs, log completed workouts, and review progress over time.

The repository contains the Flutter mobile app, the static public website, and Supabase backend assets used by the app.

## What It Does

- Onboards runners through goal, fitness, schedule, health, training preference, and device setup flows.
- Supports account creation, email/password auth, Google sign-in, password reset, and profile setup.
- Generates personalized training plans from runner profile data.
- Displays the current session, weekly plan, full plan, progress summaries, completed sessions, and training history.
- Tracks active runs with GPS, pace smoothing, distance accumulation, splits, route points, and timer-only fallback.
- Persists local run data in SQLite and lightweight user/app state in `SharedPreferences`.
- Syncs authenticated profile, preferences, activities, device connections, adaptations, and plan versions through Supabase repositories.
- Supports English and Spanish via Flutter localization ARB files.
- Includes iOS Live Activity and Android foreground-service support for active run status.
- Ships a static marketing/legal website for StrivIQ.

## Repository Layout

```text
.
|-- apps/
|   |-- mobile/              # Flutter app for iOS, Android, and generated platform shells
|   `-- website/             # Static StrivIQ marketing, privacy, and terms pages
|-- docs/                    # Product plans, data model notes, readiness docs, and design references
|-- supabase/
|   |-- functions/           # Edge functions, including AI plan generation
|   `-- migrations/          # Database schema migrations
`-- AGENTS.md                # Project-specific agent/development instructions
```

## Mobile App

The mobile app lives in `apps/mobile`.

Core stack:

- Flutter / Dart `sdk: ^3.11.1`
- Material 3
- `go_router` for navigation
- `flutter_riverpod` for state management
- `supabase_flutter` for auth and remote data
- `shared_preferences` for lightweight local persistence
- `sqflite` for active run storage
- `geolocator` and `permission_handler` for location-based run tracking
- `firebase_core` and `firebase_crashlytics` for crash reporting
- `google_sign_in` for Google auth
- `flutter_localizations` and `intl` for English/Spanish localization

The app starts at `/`, resolves auth/profile/onboarding state, and then routes authenticated, onboarded users into a four-tab shell:

- Today
- Plan
- Progress
- Settings

Additional flows cover auth, account setup, onboarding, session detail, pre-run checks, active run tracking, run logging, full plan, training history, completed sessions, settings, subscriptions, integrations, language, units, and plan updates.

## Backend

Supabase assets live in `supabase`.

Current migrations define tables for:

- runner profiles
- user preferences
- activity records
- device connections
- adaptation records
- plan versions

The `generate-plan` edge function:

- validates the authenticated Supabase user
- loads the runner profile
- calls OpenAI for structured plan generation
- applies deterministic plan rules for schedule safety and consistency
- builds phone-first workout steps
- stores a new active plan version in Supabase

Important function environment variables:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SB_PUBLISHABLE_KEY
OPENAI_API_KEY
```

## Website

The static website lives in `apps/website`.

It includes:

- landing page
- privacy policy
- terms of service
- CSS modules for reset, variables, layout, components, sections, and animations
- small JavaScript files for visual effects and scroll animations

GitHub Pages deployment is configured in `.github/workflows/deploy-website.yml` and runs when files under `apps/website/**` change on `main`.

## Prerequisites

- Flutter SDK compatible with Dart `^3.11.1`
- Xcode for iOS builds
- Android Studio / Android SDK for Android builds
- Supabase CLI for local database/function work
- Deno for Supabase function tests
- Firebase project configuration for Crashlytics

## Mobile Setup

From the repository root:

```sh
cd apps/mobile
flutter pub get
```

Create a local dart-define file from the example:

```sh
cp config/dart_defines.env.example config/dart_defines.env
```

Fill in the values you need:

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
GOOGLE_WEB_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

Run the app with configured dart defines:

```sh
flutter run --dart-define-from-file=config/dart_defines.env
```

For a local UI-only pass, the app can start without Supabase values, but auth and remote data actions will show a not-configured state.

## Localization

Localization source files are:

```text
apps/mobile/lib/l10n/app_en.arb
apps/mobile/lib/l10n/app_es.arb
```

After editing ARB files, regenerate the localization classes:

```sh
cd apps/mobile
flutter gen-l10n
```

Do not hand-edit generated `app_localizations*.dart` files.

## Verification

Run Flutter checks from `apps/mobile`:

```sh
flutter analyze
flutter test
```

Run Supabase function tests from `supabase/functions/generate-plan`:

```sh
deno test
```

The repository currently has broad Flutter unit/widget coverage and focused Deno tests for plan generation rules and workout-step generation.

## Common Commands

Mobile development:

```sh
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=config/dart_defines.env
flutter analyze
flutter test
flutter gen-l10n
```

Android release build:

```sh
cd apps/mobile
flutter build appbundle --release --dart-define-from-file=config/dart_defines.env
```

iOS build without codesigning:

```sh
cd apps/mobile
flutter build ios --no-codesign --dart-define-from-file=config/dart_defines.env
```

Supabase local development:

```sh
supabase start
supabase db push
supabase functions serve generate-plan
```

Deploy the plan generation function:

```sh
supabase functions deploy generate-plan
```

## Architecture Notes

The mobile app is feature-first under `apps/mobile/lib`:

```text
core/
  config/          # app config from dart defines
  persistence/     # SharedPreferences and SQLite database setup
  router/          # route constants and GoRouter setup
  supabase/        # Supabase client provider
  theme/           # dark theme tokens
  utils/           # formatting and time helpers
  widgets/         # reusable app UI components

features/
  active_run/      # live run tracking, GPS, splits, route storage, live status
  activity/        # completed activity records
  auth/            # Supabase auth flows
  goals/           # goal domain and presentation mapping
  home/            # app shell and today screen
  integrations/    # device connection models and state
  localization/    # locale state
  onboarding/      # account and plan setup flows
  pre_run/         # run readiness and permission checks
  profile/         # runner profile model/repository/provider
  progress/        # stats, charts, history, streaks
  settings/        # account, units, language, subscription, integrations
  training_plan/   # plan domain, plan versions, session state, adaptation
```

State is owned mostly through Riverpod providers. Local-first repositories cache important authenticated data in `SharedPreferences`, while signed-in users can read/write through Supabase-backed repositories. Active run details use SQLite because route points and splits are structured, append-heavy data.

## Documentation

Useful project docs:

- `docs/running_app_mvp_plan.md` - MVP scope and product direction
- `docs/data-models.md` - domain model and provider ownership map
- `docs/app-store-readiness-analysis.md` - release readiness notes and build history

## Current Product Status

StrivIQ is beyond a visual prototype: the app has real auth wiring, local and remote persistence boundaries, active run tracking, localization, plan-version storage, and an AI-backed plan generation function. Some product areas are still evolving, especially subscription flows, device integrations, adaptive coaching depth, and production release operations.
