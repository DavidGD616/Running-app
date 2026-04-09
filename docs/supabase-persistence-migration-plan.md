# Plan: Supabase Persistence Migration

**Generated**: 2026-04-08
**Estimated Complexity**: High

## Overview

Move the real persisted app entities from local-only storage to Supabase while keeping
the seeded training plan local. Locale stays in SharedPreferences (needed before auth —
it affects the sign-in screen language). The migrated entities are:
- profile
- onboarding draft
- user preferences
- activities
- device connections
- session feedback
- plan adjustments
- plan revisions

**Chosen approach**: Online-first with local cache. Supabase is the source of truth and
Supabase Auth (email/password) is the account/session provider, but existing
SharedPreferences-backed repositories stay temporarily as a cache/fallback layer while
the migration stabilizes. No full offline sync queue is introduced in this plan.

**Key architectural shifts**:
1. Repository `load*` methods become async (`Future<T>`)
2. Providers migrate from sync `Notifier<T>` → `AsyncNotifier<T>` for Supabase-backed data
3. The router redirect uses a combined auth/profile bootstrap state (not direct scattered checks)
4. All tables use RLS; every row is scoped to `auth.uid()`
5. Model JSON is stored in JSONB, but with explicit metadata columns for fields the app
   already filters or sorts on (`recorded_at`, `linked_session_id`, `vendor`, etc.)

**Out of scope**:
- Training plan / seed data (stays in-memory)
- Locale (stays in SharedPreferences)
- Offline queue / sync strategy
- Data migration from existing SharedPreferences keys (fresh start)

---

## Prerequisites

- A Supabase project created at [supabase.com](https://supabase.com)
- Project URL and anon key from the Supabase dashboard → Project Settings → API
- Flutter SDK ^3.11.1 (already installed)
- `flutter_riverpod ^3.3.1` (already in pubspec.yaml)
- Supabase CLI installed (`brew install supabase/tap/supabase`)
- Supabase CLI linked to your project (`supabase login` + `supabase link --project-ref <ref>`)
- Migration files live in `supabase/migrations/` at the repo root
- Deploy schema changes with `supabase db push`

---

## Sprint 1: SDK Foundation & Auth State

**Goal**: Add the `supabase_flutter` package, initialize the client, and expose auth
state through Riverpod so the router can react to sign-in / sign-out events.

**Demo/Validation**:
- App boots without errors
- `Supabase.instance.client.auth.currentUser` is null on first launch (expected)
- Console logs auth events when you manually call signUp/signIn from DartPad or a test

---

### Task 1.1: Add `supabase_flutter` to pubspec.yaml

- **Location**: [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml)
- **Description**: Add `supabase_flutter: ^2.8.0` under `dependencies`. Run `flutter pub get`.
- **Dependencies**: None
- **Acceptance Criteria**:
  - `flutter pub get` succeeds
  - `import 'package:supabase_flutter/supabase_flutter.dart'` compiles

---

### Task 1.2: Create Supabase config constants file

- **Location**: `apps/mobile/lib/core/config/supabase_config.dart` *(new file — add to .gitignore)*
- **Description**: Store the project URL and anon key. Use `--dart-define` at build
  time so credentials are never committed.

  ```dart
  // lib/core/config/supabase_config.dart
  // DO NOT commit this file. Values injected via --dart-define at build/run time.
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

  abstract final class SupabaseConfig {
    static const url = String.fromEnvironment('SUPABASE_URL');
    static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  }
  ```

  Add to `.gitignore` if you prefer a secrets file approach instead. Either way,
  never hardcode real credentials in committed files.

- **Dependencies**: None
- **Acceptance Criteria**:
  - Config compiles; values are empty strings if `--dart-define` not passed (expected in CI without secrets)

---

### Task 1.3: Initialize Supabase in `main.dart`

- **Location**: [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart)
- **Description**: Call `Supabase.initialize()` before `runApp`. Keep the existing
  SharedPreferences init for locale only.

  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    final prefs = await SharedPreferences.getInstance();
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RunningApp(),
      ),
    );
  }
  ```

- **Dependencies**: Task 1.1, Task 1.2
- **Acceptance Criteria**:
  - App boots; no initialization errors in debug console

---

### Task 1.4: Create `supabaseClientProvider`

- **Location**: `apps/mobile/lib/core/supabase/supabase_client_provider.dart` *(new file)*
- **Description**: Expose the Supabase client as a Riverpod provider, mirroring the
  existing `sharedPreferencesProvider` pattern.

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';

  final supabaseClientProvider = Provider<SupabaseClient>((ref) {
    return Supabase.instance.client;
  });
  ```

- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - `ref.watch(supabaseClientProvider)` returns the initialized client

---

### Task 1.5: Create `authStateProvider` (stream-based)

- **Location**: `apps/mobile/lib/features/auth/presentation/auth_provider.dart` *(new file)*
- **Description**: Stream the Supabase auth state changes so the router can react
  reactively. Expose the current `User?` as a `StreamProvider`, and keep the initial
  auth bootstrap explicit so the router does not guess before Supabase emits
  `AuthChangeEvent.initialSession`.

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../../../core/supabase/supabase_client_provider.dart';

  /// Emits the current [User?] whenever auth state changes.
  /// null  → signed out
  /// User  → signed in
  final authStateProvider = StreamProvider<User?>((ref) {
    final client = ref.watch(supabaseClientProvider);
    return client.auth.onAuthStateChange.map((data) => data.session?.user);
  });

  /// Convenience: synchronous read of current user (may be null before stream emits).
  final currentUserProvider = Provider<User?>((ref) {
    return ref.watch(authStateProvider).valueOrNull;
  });
  ```

- **Dependencies**: Task 1.4
- **Acceptance Criteria**:
  - `ref.watch(authStateProvider)` settles after the initial session event
  - `ref.watch(authStateProvider)` returns `AsyncData(null)` before sign-in
  - After sign-in it emits `AsyncData(User)`

---

### Task 1.6: Update router redirect to use bootstrap state

- **Location**: [apps/mobile/lib/core/router/app_router.dart](apps/mobile/lib/core/router/app_router.dart)
- **Description**: Replace the `hasPersistedProfile()` check with a combined auth/profile
  bootstrap provider. The redirect logic becomes:

  ```
  not signed in  → allow only: splash, welcome, signUp, logIn, forgotPassword
  signed in, no profile → onboarding flow
  signed in, has profile → today
  ```

  Create a small bootstrap state provider first, then let the router redirect off that
  single state instead of reading auth and profile independently.

  ```dart
  enum AppBootstrapState {
    loading,
    unauthenticated,
    authenticatedNeedsProfile,
    authenticatedReady,
  }

  final appBootstrapProvider = Provider<AppBootstrapState>((ref) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(runnerProfileProvider);

    if (auth.isLoading || profile.isLoading) {
      return AppBootstrapState.loading;
    }

    final user = auth.valueOrNull;
    if (user == null) return AppBootstrapState.unauthenticated;

    return profile.valueOrNull == null
        ? AppBootstrapState.authenticatedNeedsProfile
        : AppBootstrapState.authenticatedReady;
  });

  final appRouterProvider = Provider<GoRouter>((ref) {
    ref.watch(appBootstrapProvider);

    return GoRouter(
      initialLocation: RouteNames.splash,
      redirect: (context, state) {
        final bootstrap = ref.read(appBootstrapProvider);
        final loc = state.matchedLocation;

        const publicRoutes = {
          RouteNames.splash,
          RouteNames.welcome,
          RouteNames.signUp,
          RouteNames.logIn,
          RouteNames.forgotPassword,
        };

        switch (bootstrap) {
          case AppBootstrapState.loading:
            return loc == RouteNames.splash ? null : RouteNames.splash;
          case AppBootstrapState.unauthenticated:
            return publicRoutes.contains(loc) ? null : RouteNames.welcome;
          case AppBootstrapState.authenticatedNeedsProfile:
            return loc.startsWith('/onboarding') || loc == RouteNames.planReady
                ? null
                : RouteNames.onboarding;
          case AppBootstrapState.authenticatedReady:
            return publicRoutes.contains(loc) || loc == RouteNames.onboarding
                ? RouteNames.today
                : null;
        }
      },
      routes: [ /* unchanged */ ],
    );
  });
  ```

- **Dependencies**: Task 1.5
- **Acceptance Criteria**:
  - Unauthenticated users landing on `/today` are redirected to `/welcome`
  - Signed-in users without a profile are redirected into onboarding
  - Signed-in users with a profile are redirected to `/today`

---

## Sprint 2: Auth Screen Wiring

**Goal**: Wire sign-up, log-in, forgot-password, and log-out to real Supabase Auth calls.
Replace the current placeholder tap handlers.

**Demo/Validation**:
- Create a real account via sign-up screen → Supabase dashboard shows the user
- Log in with the created account → lands on onboarding (no profile yet)
- Use forgot-password → receives email from Supabase
- Log out from settings → returns to welcome screen

---

### Task 2.1: Add auth error localization keys

- **Location**: `apps/mobile/l10n/app_en.arb` and `apps/mobile/l10n/app_es.arb`
- **Description**: Add keys for auth error messages and run `flutter gen-l10n`.

  ```json
  "authErrorInvalidCredentials": "Incorrect email or password.",
  "authErrorEmailInUse": "This email is already registered.",
  "authErrorWeakPassword": "Password must be at least 6 characters.",
  "authErrorNetworkFailure": "Network error. Please check your connection.",
  "authErrorUnknown": "Something went wrong. Please try again.",
  "authErrorPasswordResetSent": "Password reset email sent. Check your inbox."
  ```

  Spanish equivalents in `app_es.arb`.

- **Dependencies**: None
- **Acceptance Criteria**:
  - `flutter gen-l10n` runs without errors
  - Keys are accessible in both locales

---

### Task 2.2: Create `AuthNotifier` for sign-up / sign-in / sign-out

- **Location**: `apps/mobile/lib/features/auth/presentation/auth_notifier.dart` *(new file)*
- **Description**: Wrap Supabase auth calls in a Riverpod notifier that screens can use.

  ```dart
  class AuthNotifier extends Notifier<void> {
    @override
    void build() {}

    SupabaseClient get _client => ref.read(supabaseClientProvider);

    Future<void> signUp({required String email, required String password}) async {
      await _client.auth.signUp(email: email, password: password);
    }

    Future<void> signIn({required String email, required String password}) async {
      await _client.auth.signInWithPassword(email: email, password: password);
    }

    Future<void> signOut() async {
      await _client.auth.signOut();
    }

    Future<void> resetPassword(String email) async {
      await _client.auth.resetPasswordForEmail(email);
    }
  }

  final authNotifierProvider = NotifierProvider<AuthNotifier, void>(AuthNotifier.new);
  ```

- **Dependencies**: Task 1.4
- **Acceptance Criteria**:
  - Calling `signUp` creates a user in the Supabase Auth dashboard
  - Calling `signIn` with valid credentials returns a session
  - Calling `signOut` clears the session

---

### Task 2.3: Wire `SignUpScreen` to `AuthNotifier`

- **Location**: [apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart](apps/mobile/lib/features/auth/presentation/screens/sign_up_screen.dart)
- **Description**: Convert the screen to a `ConsumerStatefulWidget`. On submit, call
  `ref.read(authNotifierProvider.notifier).signUp(email: ..., password: ...)`. Catch
  `AuthException` and display a localized error message. On success, the auth stream
  fires and the router redirects automatically — no manual `context.go()` needed.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Valid credentials → router sends user to account setup / onboarding
  - Duplicate email → shows `authErrorEmailInUse` message
  - Network error → shows `authErrorNetworkFailure` message

---

### Task 2.4: Wire `LogInScreen` to `AuthNotifier`

- **Location**: [apps/mobile/lib/features/auth/presentation/screens/log_in_screen.dart](apps/mobile/lib/features/auth/presentation/screens/log_in_screen.dart)
- **Description**: Same pattern as Task 2.3 using `signIn()`. On `AuthException` with
  code `invalid_credentials`, show `authErrorInvalidCredentials`.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Valid credentials → router sends user to correct destination
  - Wrong password → shows error without crashing

---

### Task 2.5: Wire `ForgotPasswordScreen` to `AuthNotifier`

- **Location**: [apps/mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart](apps/mobile/lib/features/auth/presentation/screens/forgot_password_screen.dart)
- **Description**: Call `resetPassword(email)`. Show `authErrorPasswordResetSent` on
  success. Map auth exceptions to localized messages.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Valid email → Supabase sends reset email; screen shows success message

---

### Task 2.6: Wire sign-out from `SettingsScreen`

- **Location**: [apps/mobile/lib/features/settings/presentation/screens/settings_screen.dart](apps/mobile/lib/features/settings/presentation/screens/settings_screen.dart)
- **Description**: Find the logout/sign-out tap handler and call
  `await ref.read(authNotifierProvider.notifier).signOut()`. The auth stream fires,
  the router redirects to welcome automatically.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Tapping log-out clears the session and returns to welcome screen

---

## Sprint 3: Database Schema & RLS

**Goal**: Create all 8 tables in Supabase with Row Level Security enabled. Every table
uses a JSONB `data` column to store the full model JSON, but tables also keep explicit
metadata columns where the app already filters, sorts, or links records — this keeps
schema changes manageable without making future queries unnecessarily painful.

**Demo/Validation**:
- `supabase db push` runs without errors
- In the Supabase Table Editor, confirm each table exists with RLS badge
- Try inserting a row manually as an anon user → should be rejected by RLS

---

### Task 3.0: Initialize Supabase CLI in the repo

- **Location**: repo root (`/Users/davidgd616/Documents/running-App/`)
- **Description**: If not already done, set up the local Supabase project skeleton.

  ```bash
  supabase init
  supabase login
  supabase link --project-ref <your-project-ref>
  ```

  Commit `supabase/config.toml` and the migration files under `supabase/migrations/`.

- **Dependencies**: None
- **Acceptance Criteria**:
  - `supabase/` directory exists with `config.toml`
  - `supabase status` shows the linked project

---

### Task 3.1: Create `runner_profiles` and `runner_profile_drafts` tables

- **Location**: `supabase/migrations/20260408000001_runner_profile.sql`
- **Description**:

  ```sql
  -- Runner profile (completed, one per user)
  create table if not exists public.runner_profiles (
    user_id            uuid references auth.users(id) on delete cascade primary key,
    schema_version     int          not null default 1,
    created_at         timestamptz  not null default now(),
    updated_at         timestamptz  not null default now(),
    completed_onboarding_at timestamptz,
    data               jsonb        not null default '{}'::jsonb
  );

  alter table public.runner_profiles enable row level security;

  create policy "Users manage own profile"
    on public.runner_profiles for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

  -- Runner profile draft (in-progress onboarding, one per user)
  create table if not exists public.runner_profile_drafts (
    user_id    uuid references auth.users(id) on delete cascade primary key,
    updated_at timestamptz not null default now(),
    data       jsonb       not null default '{}'::jsonb
  );

  alter table public.runner_profile_drafts enable row level security;

  create policy "Users manage own draft"
    on public.runner_profile_drafts for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

- **Dependencies**: Task 1.3 (Supabase project exists)
- **Acceptance Criteria**:
  - Tables exist in Supabase dashboard
  - RLS is enabled (shown with lock icon in Table Editor)

---

### Task 3.2: Create `user_preferences` table

- **Location**: `supabase/migrations/20260408000002_user_preferences.sql`
- **Description**:

  ```sql
  create table if not exists public.user_preferences (
    user_id             uuid references auth.users(id) on delete cascade primary key,
    unit_system         text        not null default 'km',
    short_distance_unit text,
    display_name        text,
    gender              text,
    date_of_birth_ms    bigint,
    updated_at          timestamptz not null default now()
  );

  alter table public.user_preferences enable row level security;

  create policy "Users manage own preferences"
    on public.user_preferences for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

  > Note: locale is NOT in this table — it stays in SharedPreferences.

- **Dependencies**: None (run after project exists)
- **Acceptance Criteria**:
  - `user_preferences` table exists with correct columns

---

### Task 3.3: Create `activity_records` table

- **Location**: `supabase/migrations/20260408000003_activity_records.sql`
- **Description**:

  ```sql
  create table if not exists public.activity_records (
    id                text        primary key,  -- app-generated UUID
    user_id           uuid        references auth.users(id) on delete cascade not null,
    recorded_at       timestamptz not null,
    linked_session_id text,
    activity_type     text,
    data              jsonb       not null
  );

  create index if not exists activity_records_user_recorded
    on public.activity_records (user_id, recorded_at desc);

  create index if not exists activity_records_user_linked_session
    on public.activity_records (user_id, linked_session_id);

  alter table public.activity_records enable row level security;

  create policy "Users manage own activities"
    on public.activity_records for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

- **Acceptance Criteria**:
  - Table and index exist; RLS enabled

---

### Task 3.4: Create `device_connections` table

- **Location**: `supabase/migrations/20260408000004_device_connections.sql`
- **Description**:

  ```sql
  create table if not exists public.device_connections (
    id             text primary key,
    user_id        uuid references auth.users(id) on delete cascade not null,
    vendor         text not null,
    kind           text,
    state          text,
    connected_at   timestamptz,
    last_synced_at timestamptz,
    data           jsonb not null
  );

  create index if not exists device_connections_user
    on public.device_connections (user_id);

  alter table public.device_connections enable row level security;

  create policy "Users manage own device connections"
    on public.device_connections for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

- **Acceptance Criteria**:
  - Table and index exist; RLS enabled

---

### Task 3.5: Create `session_feedback`, `plan_adjustments`, `plan_revisions` tables

- **Location**: `supabase/migrations/20260408000005_adaptation.sql`
- **Description**:

  ```sql
  -- Session feedback
  create table if not exists public.session_feedback (
    id                text primary key,
    user_id           uuid references auth.users(id) on delete cascade not null,
    linked_session_id text,
    recorded_at       timestamptz not null,
    data              jsonb not null
  );

  create index if not exists session_feedback_user_recorded
    on public.session_feedback (user_id, recorded_at desc);

  create index if not exists session_feedback_user_linked_session
    on public.session_feedback (user_id, linked_session_id);

  alter table public.session_feedback enable row level security;

  create policy "Users manage own feedback"
    on public.session_feedback for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

  -- Plan adjustments
  create table if not exists public.plan_adjustments (
    id                text primary key,
    user_id           uuid references auth.users(id) on delete cascade not null,
    linked_session_id text,
    status            text,
    created_at        timestamptz not null,
    data              jsonb not null
  );

  create index if not exists plan_adjustments_user
    on public.plan_adjustments (user_id);

  create index if not exists plan_adjustments_user_status
    on public.plan_adjustments (user_id, status);

  alter table public.plan_adjustments enable row level security;

  create policy "Users manage own adjustments"
    on public.plan_adjustments for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

  -- Plan revisions
  create table if not exists public.plan_revisions (
    id         text primary key,
    user_id    uuid references auth.users(id) on delete cascade not null,
    status     text,
    created_at timestamptz not null,
    data       jsonb not null
  );

  create index if not exists plan_revisions_user
    on public.plan_revisions (user_id);

  alter table public.plan_revisions enable row level security;

  create policy "Users manage own revisions"
    on public.plan_revisions for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

- **Acceptance Criteria**:
  - All three tables and indexes exist; RLS enabled on each

---

### Task 3.6: Push all migrations to Supabase

- **Location**: repo root
- **Description**: After all migration SQL files are written, push them to the linked
  Supabase project.

  ```bash
  supabase db push
  ```

  If you want to iterate locally first:

  ```bash
  supabase start
  supabase db reset
  supabase db push
  ```

- **Dependencies**: Tasks 3.0–3.5
- **Acceptance Criteria**:
  - `supabase db push` exits with status 0
  - All 8 tables appear in the Supabase Table Editor with RLS enabled

---

## Sprint 4: Async Repository Interfaces + Supabase Implementations

**Goal**: Make repository interfaces async (required for network calls), then implement
each one backed by Supabase. The SharedPreferences implementations stay temporarily as a
cache/fallback layer instead of being deleted immediately, so the provider swap in Sprint 5
does not force a brittle cloud-only runtime.

**Demo/Validation**:
- Call each new Supabase repository method in a throwaway test or a debug button
- Confirm rows appear in the Supabase dashboard after writes
- Confirm reads return the same data
- Confirm the last cached data can still be read before or during remote refresh

---

### Task 4.1: Make `RunnerProfileRepository` interface async

- **Location**: [apps/mobile/lib/features/profile/data/runner_profile_repository.dart](apps/mobile/lib/features/profile/data/runner_profile_repository.dart)
- **Description**: Change synchronous `load*` signatures to `Future<T>`. Update
  `SharedPreferencesRunnerProfileRepository` to wrap returns in `Future.value(...)`.
  Do not remove the local implementation in this sprint.

  ```dart
  abstract interface class RunnerProfileRepository {
    Future<RunnerProfileDraft?> loadDraft();
    Future<RunnerProfile?> loadProfile();
    Future<bool> hasPersistedProfile();
    Future<void> saveDraft(RunnerProfileDraft draft);
    Future<void> saveProfile(RunnerProfile profile);
    Future<void> clearDraft();
    Future<void> clearProfile();
  }
  ```

- **Dependencies**: None
- **Acceptance Criteria**:
  - `flutter analyze` passes after updating all callers

---

### Task 4.2: Create `SupabaseRunnerProfileRepository`

- **Location**: `apps/mobile/lib/features/profile/data/supabase_runner_profile_repository.dart` *(new file)*
- **Description**: Implement the updated `RunnerProfileRepository` using Supabase.
  In this sprint, wire it as the Supabase source of truth but keep the local repository
  available for cache/fallback behavior.

  ```dart
  class SupabaseRunnerProfileRepository implements RunnerProfileRepository {
    SupabaseRunnerProfileRepository(this._client);
    final SupabaseClient _client;

    String get _uid => _client.auth.currentUser!.id;

    @override
    Future<RunnerProfile?> loadProfile() async {
      final row = await _client
          .from('runner_profiles')
          .select()
          .eq('user_id', _uid)
          .maybeSingle();
      if (row == null) return null;
      final data = row['data'] as Map<String, dynamic>;
      return RunnerProfile.fromJson({...data, 'id': _uid});
    }

    @override
    Future<void> saveProfile(RunnerProfile profile) async {
      await _client.from('runner_profiles').upsert({
        'user_id': _uid,
        'schema_version': profile.schemaVersion,
        'updated_at': DateTime.now().toIso8601String(),
        'data': profile.toJson(),
      });
    }

    @override
    Future<RunnerProfileDraft?> loadDraft() async {
      final row = await _client
          .from('runner_profile_drafts')
          .select()
          .eq('user_id', _uid)
          .maybeSingle();
      if (row == null) return null;
      return RunnerProfileDraft.fromJson(row['data'] as Map<String, dynamic>);
    }

    @override
    Future<void> saveDraft(RunnerProfileDraft draft) async {
      await _client.from('runner_profile_drafts').upsert({
        'user_id': _uid,
        'updated_at': DateTime.now().toIso8601String(),
        'data': draft.toJson(),
      });
    }

    @override
    Future<bool> hasPersistedProfile() async =>
        (await loadProfile()) != null;

    @override
    Future<void> clearDraft() async {
      await _client
          .from('runner_profile_drafts')
          .delete()
          .eq('user_id', _uid);
    }

    @override
    Future<void> clearProfile() async {
      await _client
          .from('runner_profiles')
          .delete()
          .eq('user_id', _uid);
      await clearDraft();
    }
  }

  final runnerProfileRepositoryProvider = Provider<RunnerProfileRepository>((ref) {
    return SupabaseRunnerProfileRepository(ref.watch(supabaseClientProvider));
  });
  ```

  > Set `completed_onboarding_at` in the onboarding finalization path, not in every
  > generic profile save call, because the current `RunnerProfile` model does not carry
  > a dedicated `completedOnboardingAt` field.

- **Dependencies**: Task 4.1, Task 3.1, Task 1.4
- **Acceptance Criteria**:
  - `saveProfile` creates or updates the row in `runner_profiles`
  - `loadProfile` returns the saved profile on the next call
  - Local cache strategy is still possible; this task does not delete it

---

### Task 4.3: Make `ActivityRepository` interface async + create `SupabaseActivityRepository`

- **Location**:
  - [apps/mobile/lib/features/activity/data/activity_repository.dart](apps/mobile/lib/features/activity/data/activity_repository.dart) *(update interface + SharedPreferences impl)*
  - `apps/mobile/lib/features/activity/data/supabase_activity_repository.dart` *(new file)*
- **Description**: Async interface follows the same pattern as Task 4.1. Supabase
  implementation. Keep `linked_session_id` and `activity_type` populated so queries and
  indexes remain useful.

  ```dart
  class SupabaseActivityRepository implements ActivityRepository {
    SupabaseActivityRepository(this._client);
    final SupabaseClient _client;

    String get _uid => _client.auth.currentUser!.id;

    @override
    Future<List<ActivityRecord>> loadAllActivities() async {
      final rows = await _client
          .from('activity_records')
          .select()
          .eq('user_id', _uid)
          .order('recorded_at', ascending: false);
      return rows
          .map((r) => ActivityRecord.fromJson(r['data'] as Map<String, dynamic>))
          .whereType<ActivityRecord>()
          .toList();
    }

    @override
    Future<void> saveActivity(ActivityRecord activity) async {
      await _client.from('activity_records').upsert({
        'id': activity.id,
        'user_id': _uid,
        'recorded_at': activity.recordedAt.toIso8601String(),
        'linked_session_id': activity.linkedSessionId,
        'activity_type': activity.kind.key,
        'data': activity.toJson(),
      });
    }

    @override
    Future<void> deleteActivity(String id) async {
      await _client
          .from('activity_records')
          .delete()
          .eq('id', id)
          .eq('user_id', _uid);
    }

    @override
    Future<void> clearActivities() async {
      await _client
          .from('activity_records')
          .delete()
          .eq('user_id', _uid);
    }
    // loadRecentActivities, loadActivitiesByLinkedSessionId, loadActivityById
    // are derived from loadAllActivities() or use a second query.
  }
  ```

  Swap the provider registration to use `SupabaseActivityRepository`.

- **Dependencies**: Task 3.3, Task 1.4
- **Acceptance Criteria**:
  - Saving an activity creates a row in `activity_records`
  - `loadAllActivities()` returns saved rows sorted newest-first

---

### Task 4.4: Make `DeviceConnectionRepository` interface async + create `SupabaseDeviceConnectionRepository`

- **Location**:
  - [apps/mobile/lib/features/integrations/data/device_connection_repository.dart](apps/mobile/lib/features/integrations/data/device_connection_repository.dart)
  - `apps/mobile/lib/features/integrations/data/supabase_device_connection_repository.dart` *(new file)*
- **Description**: Same async-interface + Supabase implementation pattern. Use
  `device_connections` table. Upsert on `saveConnection`, delete on `deleteConnection`.

  ```dart
  @override
  Future<void> saveConnection(DeviceConnection connection) async {
    await _client.from('device_connections').upsert({
      'id': connection.id,
      'user_id': _uid,
      'vendor': connection.vendor.key,
      'kind': connection.kind.key,
      'state': connection.state.key,
      'connected_at': connection.connectedAt?.toIso8601String(),
      'last_synced_at': connection.lastSyncedAt?.toIso8601String(),
      'data': connection.toJson(),
    });
  }
  ```

  Swap provider registration.

- **Dependencies**: Task 3.4, Task 1.4
- **Acceptance Criteria**:
  - `saveConnection` creates/updates a row; `loadConnections()` returns them

---

### Task 4.5: Make `AdaptationRepository` interface async + create `SupabaseAdaptationRepository`

- **Location**:
  - [apps/mobile/lib/features/training_plan/data/adaptation_repository.dart](apps/mobile/lib/features/training_plan/data/adaptation_repository.dart)
  - `apps/mobile/lib/features/training_plan/data/supabase_adaptation_repository.dart` *(new file)*
- **Description**: Async interface. Three tables: `session_feedback`, `plan_adjustments`,
  `plan_revisions`. Each `save*` method uses upsert by `id`; do not force a whole-table
  delete/replace pattern when the app already models distinct history records.

  ```dart
  @override
  Future<void> saveSessionFeedback(List<SessionFeedback> feedback) async {
    for (final item in feedback) {
      await _client.from('session_feedback').upsert({
        'id': item.id,
        'user_id': _uid,
        'linked_session_id': item.plannedSessionId,
        'recorded_at': item.recordedAt.toIso8601String(),
        'data': item.toJson(),
      });
    }
  }
  ```

  Swap provider registration.

- **Dependencies**: Task 3.5, Task 1.4
- **Acceptance Criteria**:
  - Saving and loading feedback/adjustments/revisions round-trips correctly

---

### Task 4.6: Create `SupabaseUserPreferencesRepository`

- **Location**: `apps/mobile/lib/features/user_preferences/data/supabase_user_preferences_repository.dart` *(new file)*
- **Description**: The `userPreferencesProvider` is already an `AsyncNotifier`. Replace
  its data source from SharedPreferences keys to the `user_preferences` Supabase table.
  Use upsert keyed by `user_id`.

  ```dart
  Future<UserPreferences> load() async {
    final row = await _client
        .from('user_preferences')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return const UserPreferences();
    return UserPreferences(
      unitSystem: row['unit_system'] == 'miles' ? UnitSystem.miles : UnitSystem.km,
      displayName: row['display_name'] as String?,
      gender: row['gender'] as String?,
      dateOfBirth: row['date_of_birth_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['date_of_birth_ms'] as int)
          : null,
    );
  }

  Future<void> save(UserPreferences prefs) async {
    await _client.from('user_preferences').upsert({
      'user_id': _uid,
      'unit_system': prefs.unitSystem.name,
      'display_name': prefs.displayName,
      'gender': prefs.gender,
      'date_of_birth_ms': prefs.dateOfBirth?.millisecondsSinceEpoch,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
  ```

  Update `UserPreferencesNotifier.build()` to call `load()` and the set* methods to
  call `save()`.

- **Dependencies**: Task 3.2, Task 1.4
- **Acceptance Criteria**:
  - Unit preference persists across sign-out and sign-in on the same account

---

## Sprint 5: Provider Migration to `AsyncNotifier`

**Goal**: Convert the Supabase-backed providers from synchronous `Notifier<T>` to
`AsyncNotifier<T>`. Update every screen that reads these providers to handle
`AsyncValue` states (loading, error, data). This is the highest-impact sprint for
the UI layer.

**Demo/Validation**:
- Sign in → home screen loads data from Supabase (may show a brief loading state)
- Log a run → activity appears in the Supabase `activity_records` table
- Kill app → reopen → data is restored from Supabase

---

### Task 5.1: Convert `runnerProfileProvider` to `AsyncNotifier`

- **Location**: [apps/mobile/lib/features/profile/presentation/runner_profile_provider.dart](apps/mobile/lib/features/profile/presentation/runner_profile_provider.dart)
- **Description**:

  ```dart
  class RunnerProfileNotifier extends AsyncNotifier<RunnerProfile?> {
    @override
    Future<RunnerProfile?> build() async {
      return ref.watch(runnerProfileRepositoryProvider).loadProfile();
    }

    Future<void> setProfile(RunnerProfile profile) async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        await ref.read(runnerProfileRepositoryProvider).saveProfile(profile);
        return profile;
      });
    }

    Future<void> clearProfile() async {
      await ref.read(runnerProfileRepositoryProvider).clearProfile();
      state = const AsyncData(null);
    }
  }

  final runnerProfileProvider =
      AsyncNotifierProvider<RunnerProfileNotifier, RunnerProfile?>(
    RunnerProfileNotifier.new,
  );
  ```

  Grep for all `ref.watch(runnerProfileProvider)` and `ref.read(runnerProfileProvider)`
  usages in screens. Update them to handle `AsyncValue`:
  ```dart
  final profileAsync = ref.watch(runnerProfileProvider);
  final profile = profileAsync.valueOrNull;  // for optional reads
  // or
  return profileAsync.when(
    data: (profile) => ...,
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => Text('Error'),
  );
  ```

- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - `flutter analyze` passes
  - Home screen loads profile from Supabase after sign-in

---

### Task 5.2: Convert `activitiesProvider` to `AsyncNotifier`

- **Location**: [apps/mobile/lib/features/activity/presentation/activity_provider.dart](apps/mobile/lib/features/activity/presentation/activity_provider.dart)
- **Description**: Same migration as Task 5.1. Optimistic updates remain — write to
  Supabase async while immediately updating Riverpod state.

  ```dart
  class ActivitiesNotifier extends AsyncNotifier<List<ActivityRecord>> {
    @override
    Future<List<ActivityRecord>> build() async {
      return ref.watch(activityRepositoryProvider).loadAllActivities();
    }

    Future<void> saveActivity(ActivityRecord activity) async {
      final current = state.valueOrNull ?? [];
      state = AsyncData(_upsertActivity(current, activity));
      await ref.read(activityRepositoryProvider).saveActivity(activity);
    }

    Future<void> deleteActivity(String id) async {
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((a) => a.id != id).toList());
      await ref.read(activityRepositoryProvider).deleteActivity(id);
    }
  }

  final activitiesProvider =
      AsyncNotifierProvider<ActivitiesNotifier, List<ActivityRecord>>(
    ActivitiesNotifier.new,
  );
  ```

  Update `recentActivitiesProvider`, `completedActivitiesProvider`, and
  `activitiesByLinkedSessionIdProvider` to watch `activitiesProvider` as `AsyncValue`:

  ```dart
  final recentActivitiesProvider = Provider<List<ActivityRecord>>((ref) {
    return ref.watch(activitiesProvider).valueOrNull?.take(3).toList() ?? [];
  });
  ```

  Grep for all consumers and update.

- **Dependencies**: Task 4.3
- **Acceptance Criteria**:
  - Logging a run saves to `activity_records` in Supabase
  - Activity list refreshes on next launch from Supabase

---

### Task 5.3: Convert `deviceConnectionsProvider` and adaptation providers to `AsyncNotifier`

- **Location**:
  - [apps/mobile/lib/features/integrations/presentation/device_connection_provider.dart](apps/mobile/lib/features/integrations/presentation/device_connection_provider.dart)
  - [apps/mobile/lib/features/training_plan/presentation/adaptation_provider.dart](apps/mobile/lib/features/training_plan/presentation/adaptation_provider.dart)
- **Description**: Same `AsyncNotifier` migration pattern. For device connections,
  update `currentWearableConnectionProvider`, `connectedWearableConnectionsProvider`,
  and `connectionForVendorProvider` to use `.valueOrNull ?? []`.

  For adaptation providers (`sessionFeedbackProvider`, `planAdjustmentsProvider`,
  `planRevisionsProvider`), each becomes an `AsyncNotifier<List<T>>`.

- **Dependencies**: Task 4.4, Task 4.5
- **Acceptance Criteria**:
  - `flutter analyze` passes
  - `flutter test` passes

---

### Task 5.4: Update `onboardingProvider` to use Supabase repository

- **Location**: [apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart](apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart)
- **Description**: The onboarding draft is currently in-memory + SharedPreferences.
  Replace with `runnerProfileRepositoryProvider.loadDraft()` and
  `runnerProfileRepositoryProvider.saveDraft()` calls. Convert to `AsyncNotifier<RunnerProfileDraft>`.

  Each onboarding screen's "next" button that calls `updateSection(...)` should
  trigger an async `saveDraft()` so progress is never lost if the user backgrounds the app.

- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - Partially completing onboarding → kill app → reopen → draft is restored from Supabase

---

## Sprint 6: Onboarding & Profile Finalization

**Goal**: Make onboarding/profile creation reliable with Supabase-backed auth and storage.

**Demo/Validation**:
- New user signs up, completes onboarding, and gets a profile row in Supabase
- Existing signed-in user without a profile is routed back into onboarding
- Settings edits update the same profile cleanly

---

### Task 6.1: Finalize onboarding save flow

- **Location**: 
- [apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart](apps/mobile/lib/features/onboarding/presentation/onboarding_provider.dart)
- onboarding/settings review and ready screens
- **Description**: Finalize the shortened onboarding flow against Supabase-backed draft
  and profile storage:
  - save draft to Supabase during onboarding progress
  - save final profile to Supabase on completion
  - clear draft after successful finalization
  - preserve the current shortened onboarding shape (no recovery/motivation step)
- **Dependencies**: Task 5.1, Task 5.4
- **Acceptance Criteria**:
  - New user can complete onboarding and land in the app
  - Settings/profile edits update the same remote profile cleanly

---

### Task 6.2: Finalize router redirect with async profile bootstrap

- **Location**: [apps/mobile/lib/core/router/app_router.dart](apps/mobile/lib/core/router/app_router.dart)
- **Description**: Finalize the bootstrap provider introduced in Task 1.6 so the app
  reacts deterministically after auth session restore and async profile load.
- **Dependencies**: Task 5.1, Task 6.1
- **Acceptance Criteria**:
  - Signed-in user with profile → lands on `/today`
  - Signed-in user without profile → lands on onboarding
  - Signed-out user → lands on `/welcome`

---

### Task 6.3: Manual auth/onboarding verification pass

- **Location**: `apps/mobile/`
- **Description**:
  1. Sign up with a new email
  2. Complete onboarding
  3. Force-quit and reopen
  4. Verify landing route, profile restoration, and draft clearing
- **Dependencies**: Task 6.1, Task 6.2
- **Acceptance Criteria**:
  - End-to-end auth + onboarding flow works without manual DB intervention

---

## Sprint 7: Cleanup & Hardening

**Goal**: Remove dead local-source-of-truth code only after the Supabase path is stable.
Keep SharedPreferences only where still needed by design.

**Demo/Validation**:
- `flutter analyze` passes with zero issues
- `flutter test` passes
- Local cache strategy remains explicit

---

### Task 7.1: Remove deprecated provider wiring

- **Location**:
  - migrated repository/provider files
- **Description**: Remove dead local-source-of-truth branches and any repository
  registrations that are no longer used. Do not remove locale persistence.
- **Dependencies**: Sprint 6 complete
- **Acceptance Criteria**:
  - No dead provider paths remain
  - `flutter analyze` passes with no unused code warnings caused by the migration

---

### Task 7.2: Decide what local cache stays

- **Location**:
  - repository/provider files for profile, activities, integrations, and adaptation
- **Description**: Make an explicit call:
  - keep SharedPreferences cache for now
  - or replace the cache later with SQLite/Drift

  This task is not “delete local persistence blindly.” It is “lock the intended local
  cache strategy after Supabase is proven.”
- **Dependencies**: Task 7.1
- **Acceptance Criteria**:
  - The codebase has one documented cache strategy, not a half-removed hybrid

---

### Task 7.3: Run `flutter analyze` and `flutter test`; fix all issues

- **Location**: `apps/mobile/`
- **Description**: Run `flutter analyze` and `flutter test` from `apps/mobile/`. Fix
  any type mismatches from the `Notifier` → `AsyncNotifier` migration.
  Common issues to watch for:
  - Screens reading `.watch(provider)` and expecting `T` but now getting `AsyncValue<T>` — add `.valueOrNull ?? fallback`
  - Providers that watch other async providers and forget to unwrap `.value`
  - `ref.read(runnerProfileProvider).loadProfile()` leftover calls — these are now `ref.read(runnerProfileProvider.notifier).something()`
- **Dependencies**: All prior tasks
- **Acceptance Criteria**:
  - `flutter analyze` output: no issues
  - `flutter test` output: all tests pass

---

## Testing Strategy

| Sprint | How to verify |
|--------|---------------|
| Sprint 1 | App boots; check Supabase dashboard for project connectivity |
| Sprint 2 | Create an account via sign-up → see user in Supabase Auth dashboard |
| Sprint 3 | Run `supabase db push`; verify tables in Table Editor |
| Sprint 4 | Call repository methods from a debug screen or test; confirm Supabase rows and cache behavior |
| Sprint 5 | Sign in → use the app → sign out → sign in again → data restored |
| Sprint 6 | Complete auth + onboarding + app relaunch end to end |
| Sprint 7 | `flutter analyze` + `flutter test` both clean |

**Manual end-to-end test** (after Sprint 5):
1. Sign up with a new email
2. Complete full onboarding → plan ready screen
3. Log a run
4. Add a device connection
5. Force-quit the app
6. Relaunch → verify: lands on `/today`, profile intact, activity visible
7. Sign out → sign in again → verify same data loads from Supabase

---

## Potential Risks & Gotchas

1. **`AsyncNotifier` cascade on UI**: Every screen that reads a migrated provider now
   gets `AsyncValue<T>` instead of `T`. Grep for `ref.watch(activitiesProvider)`,
   `ref.watch(runnerProfileProvider)`, etc. before starting Sprint 5, and audit every
   callsite. Missing one causes a runtime type error, not a compile error in some cases.

2. **Cloud-only runtime is too brittle**: This app is used in mobile conditions where
   connectivity is not guaranteed. Do not remove the local cache path before the
   Supabase-backed flows are stable and proven in real usage.

3. **Router rebuild on profile load**: If auth and profile are loaded separately
   without a combined bootstrap provider, redirects can flap or leave the user on the
   wrong screen. Keep a single loading/unauthenticated/needs-profile/ready gate.

4. **Supabase auth session persistence**: `supabase_flutter` persists the session
   locally by default on mobile, so the app should expect restored sessions on relaunch.
   The router/bootstrap flow must handle that initial restored session cleanly.

5. **`currentUser!` null crash**: The Supabase repository implementations use
   `_client.auth.currentUser!.id`. If a repository method is called before auth is
   established (e.g., during app init), this will throw. Guard by only initializing
   the repositories after `authStateProvider` emits a non-null user. The `AsyncNotifier`
   `build()` method is the right place — it only runs after providers it watches resolve.

6. **Locale stays in SharedPreferences**: The `localeProvider` still reads from
   SharedPreferences. Do not remove the `sharedPreferencesProvider` override in
   `main.dart` or the locale will break. SharedPreferences stays in `pubspec.yaml`.

7. **JSONB-only tables become painful fast**: The app already filters by linked
   session, timestamps, vendor, and status. Keep those fields as explicit columns even
   when the full model JSON lives in `data`.

8. **Supabase upsert on `runner_profiles`**: The profile table uses `user_id` as the
   primary key (one profile per user). Always use `upsert`, never `insert`, or you'll
   get a unique-constraint error on the second save.

9. **Concurrent writes race condition**: If two write calls (e.g., `saveActivity` and
   `saveProfile`) are in flight simultaneously, Supabase handles them independently
   (no transactions needed since they're different tables). But within the same table,
   be careful not to call `saveActivities` (full list replace) while `saveActivity`
   (upsert) is also in flight.

10. **Development without credentials**: The app won't connect to Supabase without
   `--dart-define=SUPABASE_URL=...`. Document this in a `README` or `.env.example`
   for the team. CI/CD pipelines need the secrets injected at build time.

---

## Rollback Plan

Since this migration is staged and the existing SharedPreferences implementations are
kept as a temporary cache/fallback path:

- **Before Sprint 7**: Revert provider registration from Supabase back to the local
  repository/cache implementation — one-line change per repository provider. No data loss
  in Supabase; cached local data remains available.
- **After Sprint 7**: Full rollback requires reverting the provider wiring and any
  cleanup commits that removed deprecated local-source-of-truth code.
- **Database rollback**: Drop the Supabase tables in a follow-up migration. Auth users
  remain unless deleted manually.
