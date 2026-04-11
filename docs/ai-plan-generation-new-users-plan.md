# Plan: AI Plan Generation for New Users

**Generated**: 2026-04-11
**Estimated Complexity**: High

## Overview

Build the full AI plan-generation pipeline scoped to **new users only**. When a new
user completes onboarding and reaches `PlanGenerationScreen`, the app calls a Supabase
Edge Function that reads the saved `RunnerProfile` from Supabase, calls OpenAI
(`gpt-5.4-mini`) with a Zod-typed structured-output prompt, converts the response into
`WorkoutStep` objects deterministically, saves the result to a new `plan_versions`
table, and returns the plan to Flutter. Flutter caches the active plan in
`SharedPreferences` for fast offline startup and replaces the seed-data-backed
`trainingPlanProvider` with an async repository load.

If generation fails, `PlanGenerationScreen` shows an error state with a **Retry**
button and an explicit **"Use Starter Plan for now"** fallback so users never confuse
a seed plan with a personalized one.

**Architecture decisions locked in:**
- OpenAI (`gpt-5.4-mini`) with `zodResponseFormat` Structured Outputs
- Supabase Edge Function (TypeScript / Deno) — API key never touches the device
- WorkoutStep graph built **deterministically in the Edge Function**, not by GPT
- `plan_versions` table: Supabase source of truth; SP caches **active plan only**
- `WorkoutPhase` objects are **not** serialized (presentation layer); rebuilt from
  structural fields after JSON load
- `trainingPlanProvider` migrated from sync `Notifier` → `AsyncNotifier`

---

## Prerequisites

- Supabase project created and CLI linked (`supabase link --project-ref <ref>`)
- OpenAI API key stored as Supabase Edge Function secret:
  `supabase secrets set OPENAI_API_KEY=sk-...`
- `supabase_flutter: ^2.12.2` already in `pubspec.yaml` ✅
- `flutter test` and `flutter analyze` currently pass ✅

---

## Sprint 1: Supabase — Migration + Edge Function

**Goal**: `plan_versions` table exists in Supabase; `generate-plan` Edge Function
receives a user JWT, reads their profile, calls OpenAI with a Zod schema, builds
`WorkoutStep` objects, saves the result, and returns the plan JSON. Testable end-to-end
with `curl` before Flutter touches it.

**Demo/Validation**:
- `supabase db push` applies migration without errors
- `curl` request with a real user JWT returns a valid plan JSON with sessions
- `plan_versions` table shows one row for the test user with `is_active = true`

---

### Task 1.1: Create `plan_versions` migration

- **Location**: `supabase/migrations/<timestamp>_plan_versions.sql` *(new file)*
- **Description**: Create the table that stores every generated plan version per user.

  ```sql
  create table if not exists public.plan_versions (
    id            text primary key,
    user_id       uuid references auth.users(id) on delete cascade not null,
    generated_at  timestamptz not null default now(),
    requested_by  text not null,       -- 'onboarding' | 'settings_update' | 'retry'
    is_active     boolean not null default false,
    schema_version int not null default 1,
    data          jsonb not null       -- full TrainingPlan JSON
  );

  create index if not exists plan_versions_user_active
    on public.plan_versions (user_id, is_active);

  create index if not exists plan_versions_user_generated
    on public.plan_versions (user_id, generated_at desc);

  alter table public.plan_versions enable row level security;

  create policy "Users manage own plan versions"
    on public.plan_versions for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  ```

- **Dependencies**: None
- **Acceptance Criteria**:
  - `supabase db push` succeeds
  - Table visible in Supabase dashboard with correct columns and RLS enabled
- **Validation**:
  - `supabase db push` from repo root

---

### Task 1.2: Scaffold Edge Function

- **Location**: `supabase/functions/generate-plan/index.ts` *(new file)*
- **Description**: Create the Deno Edge Function entry point. Validates the JWT
  (Supabase handles this automatically via the `Authorization` header), reads
  `runner_profiles` for the authenticated user using the service-role client, and
  returns a stub response.

  ```typescript
  import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

  Deno.serve(async (req) => {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // User-scoped client — respects RLS
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json().catch(() => ({}));
    const requestedBy: string = body.requestedBy ?? 'onboarding';

    // TODO: fetch profile, call OpenAI, save plan (Tasks 1.3–1.6)
    return new Response(JSON.stringify({ stub: true, userId: user.id }), {
      headers: { 'Content-Type': 'application/json' },
    });
  });
  ```

- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - `supabase functions serve generate-plan` starts locally without errors
  - `curl` with a valid user JWT returns `{ stub: true, userId: "..." }`
- **Validation**:
  - `supabase functions serve generate-plan --env-file .env.local`

---

### Task 1.3: Define Zod output schema

- **Location**: `supabase/functions/generate-plan/schema.ts` *(new file)*
- **Description**: Zod schema that defines what GPT must return. Keeps the AI output
  minimal and normalized; WorkoutStep graph is built deterministically in Task 1.5.

  ```typescript
  import { z } from 'https://deno.land/x/zod@v3.23.8/mod.ts';

  export const GeneratedSessionSchema = z.object({
    id: z.string(),
    date: z.string(),               // ISO 8601 date
    weekNumber: z.number().int().min(1),
    type: z.enum([
      'easyRun', 'longRun', 'progressionRun',
      'intervals', 'hillRepeats', 'fartlek',
      'tempoRun', 'thresholdRun', 'racePaceRun',
      'recoveryRun', 'crossTraining', 'restDay',
    ]),
    distanceKm: z.number().nullable(),
    durationMinutes: z.number().int().nullable(),
    coachNote: z.string().nullable(),
    // Workout intent — only for structured sessions
    targetZone: z.enum([
      'recovery', 'easy', 'steady', 'tempo',
      'threshold', 'interval', 'racePace', 'longRun',
    ]).nullable(),
    warmUpMinutes: z.number().int().nullable(),
    coolDownMinutes: z.number().int().nullable(),
    intervalReps: z.number().int().nullable(),
    intervalRepDistanceMeters: z.number().int().nullable(),
    intervalRecoverySeconds: z.number().int().nullable(),
  });

  export const GeneratedPlanSchema = z.object({
    totalWeeks: z.number().int().min(4).max(26),
    raceType: z.enum(['fiveK', 'tenK', 'halfMarathon', 'marathon', 'other']),
    sessions: z.array(GeneratedSessionSchema),
  });

  export type GeneratedSession = z.infer<typeof GeneratedSessionSchema>;
  export type GeneratedPlan = z.infer<typeof GeneratedPlanSchema>;
  ```

- **Dependencies**: None
- **Acceptance Criteria**:
  - Schema imports and compiles in Deno
  - `GeneratedPlanSchema.parse(sampleOutput)` succeeds for valid input
- **Validation**:
  - Inline Deno test or `console.log` validation during local serve

---

### Task 1.4: Implement OpenAI call with structured output

- **Location**: `supabase/functions/generate-plan/openai.ts` *(new file)*
- **Description**: Build the system + user prompt from the `RunnerProfile` JSON and call
  `gpt-5.4-mini` using `zodResponseFormat` for guaranteed schema conformance.

  ```typescript
  import OpenAI from 'https://esm.sh/openai@4';
  import { zodResponseFormat } from 'https://esm.sh/openai@4/helpers/zod';
  import { GeneratedPlanSchema, type GeneratedPlan } from './schema.ts';

  export async function generatePlanFromProfile(
    profileData: Record<string, unknown>,
  ): Promise<GeneratedPlan> {
    const client = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY')! });

    const systemPrompt = `You are an expert running coach. Generate a personalized
  training plan based on the runner profile provided. Be specific and progressive.
  Assign realistic distances and durations. For easy and long runs use targetZone easy
  or longRun. For intervals provide intervalReps, intervalRepDistanceMeters, and
  intervalRecoverySeconds. For tempo runs use targetZone tempo with warmUpMinutes and
  coolDownMinutes. Always anchor week 1 sessions starting from the nearest upcoming
  Monday. Ensure a proper taper in the final 2 weeks before the race.`;

    const userPrompt = `Runner profile:\n${JSON.stringify(profileData, null, 2)}
  
  Generate a complete personalized training plan. Return only the JSON.`;

    const completion = await client.chat.completions.parse({
      model: 'gpt-5.4-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      response_format: zodResponseFormat(GeneratedPlanSchema, 'training_plan'),
    });

    const parsed = completion.choices[0]?.message?.parsed;
    if (!parsed) throw new Error('OpenAI returned no parsed output');
    return parsed;
  }
  ```

- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Function returns a valid `GeneratedPlan` for a sample profile
  - Zod validation does not throw
- **Validation**:
  - Local test call with a hardcoded sample profile JSON

---

### Task 1.5: Deterministic WorkoutStep builder

- **Location**: `supabase/functions/generate-plan/workout-steps.ts` *(new file)*
- **Description**: Converts a `GeneratedSession`'s workout intent into a flat
  `WorkoutStep[]` that matches the Flutter `WorkoutStep` model. No AI involved — pure
  deterministic logic based on session type and intent fields.

  ```typescript
  import type { GeneratedSession } from './schema.ts';

  type StepKind = 'warmUp' | 'work' | 'recovery' | 'coolDown' | 'repeat';

  interface WorkoutStepJson {
    kind: StepKind;
    target?: { type: string; zone: string } | null;
    durationMs?: number | null;
    distanceMeters?: number | null;
    repetitions?: number | null;
    steps?: WorkoutStepJson[];
  }

  export function buildWorkoutSteps(
    session: GeneratedSession,
    guidanceType: 'effort' | 'pace' | 'heartRate',
  ): WorkoutStepJson[] {
    const zone = session.targetZone;
    if (!zone) return [];
    const target = zone ? { type: guidanceType, zone } : null;

    const steps: WorkoutStepJson[] = [];

    if (session.warmUpMinutes) {
      steps.push({
        kind: 'warmUp',
        target: { type: guidanceType, zone: 'easy' },
        durationMs: session.warmUpMinutes * 60_000,
      });
    }

    if (session.intervalReps && session.intervalRepDistanceMeters) {
      steps.push({
        kind: 'repeat',
        repetitions: session.intervalReps,
        steps: [
          {
            kind: 'work',
            target,
            distanceMeters: session.intervalRepDistanceMeters,
          },
          {
            kind: 'recovery',
            target: { type: guidanceType, zone: 'recovery' },
            durationMs: (session.intervalRecoverySeconds ?? 90) * 1000,
          },
        ],
      });
    } else if (zone) {
      steps.push({ kind: 'work', target, durationMs: (session.durationMinutes ?? 30) * 60_000 });
    }

    if (session.coolDownMinutes) {
      steps.push({
        kind: 'coolDown',
        target: { type: guidanceType, zone: 'easy' },
        durationMs: session.coolDownMinutes * 60_000,
      });
    }

    return steps;
  }
  ```

- **Dependencies**: Task 1.3
- **Acceptance Criteria**:
  - Intervals session → `repeat` step with nested work + recovery
  - Tempo session → warmUp + work + coolDown
  - Easy run with no intent → empty steps (no crash)
- **Validation**:
  - Unit test each branch with sample `GeneratedSession` objects

---

### Task 1.6: Wire Edge Function end-to-end and save to `plan_versions`

- **Location**: `supabase/functions/generate-plan/index.ts` *(update Task 1.2 stub)*
- **Description**: Replace the stub with the full pipeline:
  1. Fetch `runner_profiles.data` for the authenticated user
  2. Read `guidancePreference` from profile to determine `guidanceType`
  3. Call `generatePlanFromProfile()` (Task 1.4)
  4. Build `workoutSteps` for each session via `buildWorkoutSteps()` (Task 1.5)
  5. Deactivate any previous active plan for the user
  6. Insert new row into `plan_versions` with `is_active = true`
  7. Return `{ versionId, plan }` to Flutter

  Key snippet for steps 5–7:
  ```typescript
  // Service-role client — bypasses RLS for writes
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Deactivate previous active plans
  await adminClient
    .from('plan_versions')
    .update({ is_active: false })
    .eq('user_id', user.id)
    .eq('is_active', true);

  const versionId = crypto.randomUUID();
  await adminClient.from('plan_versions').insert({
    id: versionId,
    user_id: user.id,
    generated_at: new Date().toISOString(),
    requested_by: requestedBy,
    is_active: true,
    schema_version: 1,
    data: planJson,   // full plan with sessions including workoutSteps
  });

  return new Response(JSON.stringify({ versionId, plan: planJson }), {
    headers: { 'Content-Type': 'application/json' },
  });
  ```

- **Dependencies**: Tasks 1.2, 1.4, 1.5
- **Acceptance Criteria**:
  - End-to-end `curl` call inserts a row in `plan_versions` and returns plan JSON
  - Sessions with interval type have `workoutSteps` array populated
  - `flutter analyze` unaffected (no Flutter changes in this task)
- **Validation**:
  ```bash
  curl -X POST https://<project>.supabase.co/functions/v1/generate-plan \
    -H "Authorization: Bearer <user-jwt>" \
    -H "Content-Type: application/json" \
    -d '{"requestedBy":"onboarding"}'
  ```

---

## Sprint 2: Flutter — TrainingSession + TrainingPlan Serialization

**Goal**: `TrainingSession` and `TrainingPlan` can round-trip through JSON. Required
before the repository layer can save/load plans locally. `WorkoutPhase` is excluded
from serialization (presentation layer — rebuilt from structural fields after load).

**Demo/Validation**:
- `flutter test` passes including new serialization unit tests
- A seed plan serialized to JSON and deserialized back produces structurally identical sessions

---

### Task 2.1: Add `toJson()` / `fromJson()` to `TrainingSession`

- **Location**: [apps/mobile/lib/features/training_plan/domain/models/training_session.dart](apps/mobile/lib/features/training_plan/domain/models/training_session.dart)
- **Description**: Add JSON serialization to `TrainingSession`. Serialize all structural
  fields. **Do not serialize `phases`** — they are presentation-layer objects containing
  display strings and are rebuilt on the provider side. Reuse `model_json_utils.dart`
  helpers.

  ```dart
  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'date': date.toIso8601String(),
    'type': type.name,
    'status': status.name,
    'weekNumber': weekNumber,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'description': description,
    'effort': effort?.name,
    'workoutTarget': workoutTarget?.toJson(),
    'workoutSteps': workoutSteps.map((s) => s.toJson()).toList(),
    'supplementalType': supplementalType?.key,
    'elevationGainMeters': elevationGainMeters,
    'intervalReps': intervalReps,
    'intervalRepDistanceMeters': intervalRepDistanceMeters,
    'intervalRecoverySeconds': intervalRecoverySeconds,
    'warmUpMinutes': warmUpMinutes,
    'coolDownMinutes': coolDownMinutes,
    // phases intentionally excluded — rebuilt from structural fields
  };

  static TrainingSession? fromJson(Map<String, dynamic> json) { ... }
  ```

- **Dependencies**: None (WorkoutStep/WorkoutTarget already have toJson/fromJson ✅)
- **Acceptance Criteria**:
  - `session.toJson()` produces valid JSON for all session types ✅
  - `TrainingSession.fromJson(session.toJson())` produces structurally identical session ✅
  - `phases` is always `const []` on a deserialized session ✅
- **Validation**:
  - Unit test: round-trip 3 different session types from seed data ✅
- **Status**: ✅ COMPLETED (2026-04-11) — commit bcc0501
- **Log**: Added `toJson()`/`fromJson()` + private helpers `_sessionTypeFromName`, `_sessionStatusFromName`, `_effortFromName`, `_doubleOrNull`. Imported `model_json_utils.dart`. `phases` always empty on deserialization.
- **Files**: `apps/mobile/lib/features/training_plan/domain/models/training_session.dart`

---

### Task 2.2: Add `toJson()` / `fromJson()` to `TrainingPlan`

- **Location**: [apps/mobile/lib/features/training_plan/domain/models/training_plan.dart](apps/mobile/lib/features/training_plan/domain/models/training_plan.dart)
- **Description**: Add top-level JSON serialization wrapping sessions and support sessions.

  ```dart
  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'raceType': raceType.name,
    'totalWeeks': totalWeeks,
    'currentWeekNumber': currentWeekNumber,
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'supportSessions': supportSessions.map((s) => s.toJson()).toList(),
  };

  static TrainingPlan? fromJson(Map<String, dynamic> json) { ... }
  ```

- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - `plan.toJson()` serializes both sessions and supportSessions ✅
  - `TrainingPlan.fromJson(plan.toJson())` reconstructs plan with correct session count ✅
- **Validation**:
  - Unit test: serialize seed plan → deserialize → assert session count and first session id match ✅
- **Status**: ✅ COMPLETED (2026-04-11) — commit bcc0501
- **Log**: Added `toJson()`/`fromJson()` + private `_raceTypeFromName` helper. Imported `model_json_utils.dart`.
- **Files**: `apps/mobile/lib/features/training_plan/domain/models/training_plan.dart`

---

### Task 2.3: Unit tests for serialization round-trips

- **Location**: `apps/mobile/test/features/training_plan/domain/models/training_plan_serialization_test.dart` *(new file)*
- **Description**: Cover full round-trip for `TrainingPlan`, `TrainingSession`, `WorkoutStep`.
  Use seed data as input (already available in the test environment).
- **Dependencies**: Tasks 2.1, 2.2
- **Acceptance Criteria**:
  - All tests pass with `flutter test` ✅
  - At least 3 session types covered (easyRun, intervals, tempoRun) ✅
- **Status**: ✅ COMPLETED (2026-04-11) — commit bcc0501
- **Log**: 6 tests — easyRun, intervals (nested repeat steps), tempoRun, phases-empty, seed-plan round-trip, all raceType enum values. 117/117 suite passing, no regressions. Gotcha: `TrainingSession` is not const-constructable; changed `const session =` to `final session =`.
- **Files**: `apps/mobile/test/features/training_plan/domain/models/training_plan_serialization_test.dart` (created)

---

## Sprint 3: Flutter — PlanVersion Domain Model + Repository Layer

**Goal**: `PlanVersion` domain model exists; abstract `PlanVersionRepository` is
implemented with a Supabase backend and SharedPreferences active-plan cache; a
switching provider follows the existing `asyncAdaptationRepositoryProvider` pattern.

**Demo/Validation**:
- Call `repo.saveActivePlan(version)` → row appears in Supabase `plan_versions`
- Kill app → reopen → `repo.loadActivePlan()` returns the cached plan from SP instantly
- `flutter analyze` passes

---

### Task 3.1: `PlanVersion` domain model

- **Location**: `apps/mobile/lib/features/training_plan/domain/models/plan_version.dart` *(new file)*
- **Description**:

  ```dart
  import 'training_plan.dart';

  class PlanVersion {
    const PlanVersion({
      required this.id,
      required this.generatedAt,
      required this.requestedBy,
      required this.isActive,
      required this.plan,
    });

    static const int schemaVersion = 1;

    final String id;
    final DateTime generatedAt;
    final String requestedBy;   // 'onboarding' | 'settings_update' | 'retry'
    final bool isActive;
    final TrainingPlan plan;

    Map<String, dynamic> toJson() => {
      'schemaVersion': schemaVersion,
      'id': id,
      'generatedAt': generatedAt.toIso8601String(),
      'requestedBy': requestedBy,
      'isActive': isActive,
      'plan': plan.toJson(),
    };

    static PlanVersion? fromJson(Map<String, dynamic> json) { ... }

    PlanVersion copyWith({ bool? isActive }) => PlanVersion(
      id: id,
      generatedAt: generatedAt,
      requestedBy: requestedBy,
      isActive: isActive ?? this.isActive,
      plan: plan,
    );
  }
  ```

- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - `PlanVersion.fromJson(version.toJson())` round-trips correctly

**Status**: ✅ Completed — commit `930a283`
**Log**: Created `plan_version.dart` with full `toJson`/`fromJson`. Added 4-test suite in `plan_version_test.dart` — all GREEN. `copyWith`, null-guard on `fromJson`, and `schemaVersion` all verified.
**Files**: `domain/models/plan_version.dart` (new), `test/.../plan_version_test.dart` (new)

---

### Task 3.2: Abstract `PlanVersionRepository`

- **Location**: `apps/mobile/lib/features/training_plan/data/plan_version_repository.dart` *(new file)*
- **Description**: Define the interface. The local implementation caches only the
  active plan.

  ```dart
  abstract interface class PlanVersionRepository {
    /// Returns the active plan if one is cached locally (fast, offline-safe).
    TrainingPlan? loadActivePlanSync();

    /// Loads the active plan from the remote source of truth.
    Future<TrainingPlan?> loadActivePlanAsync();

    /// Saves a new active plan version (local cache + remote).
    Future<void> saveActivePlan(PlanVersion version);

    /// Returns true if any plan version exists locally.
    bool hasActivePlan();
  }
  ```

- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Interface compiles

**Status**: ✅ Completed — commit `43f797e`
**Log**: Interface defined in `plan_version_repository.dart`. `flutter analyze` passes.
**Files**: `data/plan_version_repository.dart` (new)

---

### Task 3.3: `SharedPreferencesPlanVersionRepository`

- **Location**: `apps/mobile/lib/features/training_plan/data/plan_version_repository.dart` *(add to same file)*
- **Description**: Caches the active plan JSON in SharedPreferences under a single key.
  Does **not** store historical versions.

  ```dart
  class SharedPreferencesPlanVersionRepository implements PlanVersionRepository {
    SharedPreferencesPlanVersionRepository(this._prefs);

    static const _activePlanKey = 'active_plan_version_v1';
    final SharedPreferences _prefs;

    @override
    TrainingPlan? loadActivePlanSync() {
      final raw = _prefs.getString(_activePlanKey);
      if (raw == null) return null;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final version = PlanVersion.fromJson(json);
        return version?.plan;
      } catch (_) { return null; }
    }

    @override
    Future<TrainingPlan?> loadActivePlanAsync() async => loadActivePlanSync();

    @override
    Future<void> saveActivePlan(PlanVersion version) async {
      await _prefs.setString(_activePlanKey, jsonEncode(version.toJson()));
    }

    @override
    bool hasActivePlan() => _prefs.containsKey(_activePlanKey);
  }
  ```

- **Dependencies**: Task 3.2
- **Acceptance Criteria**:
  - Save + sync load round-trips correctly after hot restart

**Status**: ✅ Completed — commit `43f797e`
**Log**: SP impl added to same file. Key `active_plan_version_v1`. `loadActivePlanSync` decodes via `PlanVersion.fromJson`. `sharedPreferencesPlanVersionRepositoryProvider` wired.
**Files**: `data/plan_version_repository.dart` (modified)

---

### Task 3.4: `SupabasePlanVersionRepository`

- **Location**: `apps/mobile/lib/features/training_plan/data/supabase_plan_version_repository.dart` *(new file)*
- **Description**: Reads from and writes to `plan_versions`. On load, also updates
  the SP cache.

  ```dart
  class SupabasePlanVersionRepository implements PlanVersionRepository {
    SupabasePlanVersionRepository({
      required SupabaseClient client,
      required String userId,
      required SharedPreferencesPlanVersionRepository localCache,
    });

    static const _table = 'plan_versions';

    @override
    TrainingPlan? loadActivePlanSync() => _localCache.loadActivePlanSync();

    @override
    Future<TrainingPlan?> loadActivePlanAsync() async {
      try {
        final row = await _client
          .from(_table)
          .select('id, generated_at, requested_by, is_active, data')
          .eq('user_id', _userId)
          .eq('is_active', true)
          .maybeSingle();
        if (row == null) return null;
        final version = _versionFromRow(row);
        if (version != null) await _localCache.saveActivePlan(version);
        return version?.plan;
      } catch (_) {
        return _localCache.loadActivePlanSync();
      }
    }

    @override
    Future<void> saveActivePlan(PlanVersion version) async {
      await _localCache.saveActivePlan(version);
      // Remote write is handled by the Edge Function; Flutter only reads here.
      // This local save is called after the Edge Function returns the plan.
    }

    @override
    bool hasActivePlan() => _localCache.hasActivePlan();
  }
  ```

  Note: Flutter does **not** write directly to `plan_versions`. The Edge Function
  owns all writes to that table. Flutter only reads via `loadActivePlanAsync()` and
  caches locally via `saveActivePlan()`.

- **Dependencies**: Task 3.3
- **Acceptance Criteria**:
  - `loadActivePlanAsync()` returns the plan inserted by the Edge Function smoke test
  - Falls back to SP cache on network error

**Status**: ✅ Completed — commit `a447baf`
**Log**: Created `supabase_plan_version_repository.dart`. Reads `plan_versions` table, caches via SP on success, falls back to SP on error. `userId` derived from `_client.auth.currentUser?.id` (no separate parameter needed — matches Supabase repo pattern). `flutter analyze` passes, 121 tests GREEN.
**Files**: `data/supabase_plan_version_repository.dart` (new)

---

### Task 3.5: Wire `planVersionRepositoryProvider`

- **Location**: `apps/mobile/lib/features/training_plan/data/plan_version_repository.dart` *(add providers)*
- **Description**: Follow the same switching provider pattern as
  `asyncAdaptationRepositoryProvider`.

  ```dart
  final sharedPreferencesPlanVersionRepositoryProvider =
      Provider<SharedPreferencesPlanVersionRepository>((ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SharedPreferencesPlanVersionRepository(prefs);
  });

  final planVersionRepositoryProvider = Provider<PlanVersionRepository>((ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return ref.watch(sharedPreferencesPlanVersionRepositoryProvider);
    }
    return ref.watch(supabasePlanVersionRepositoryProvider);
  });
  ```

- **Dependencies**: Tasks 3.3, 3.4
- **Acceptance Criteria**:
  - Provider resolves to Supabase impl when user is signed in
  - Provider resolves to SP impl when signed out (edge case safety)
  - `flutter analyze` passes

**Status**: ✅ Completed — commit `a447baf`
**Log**: `planVersionRepositoryProvider` and `supabasePlanVersionRepositoryProvider` defined in `supabase_plan_version_repository.dart` (same pattern as `asyncAdaptationRepositoryProvider`). Switching logic: null user → SP impl, signed-in user → Supabase impl. `flutter analyze` passes with no issues.
**Files**: `data/supabase_plan_version_repository.dart` (modified)

---

## Sprint 4: Flutter — Wire PlanGenerationScreen + Error/Retry UI

**Goal**: `PlanGenerationScreen` calls the Edge Function while the animation plays.
On success it saves the plan locally and proceeds. On failure it shows an error state
with a Retry button and an explicit "Use Starter Plan" fallback. The animation only
navigates away when both the animation is done AND the generation call has completed.

**Demo/Validation**:
- New user completes onboarding → generation screen calls Edge Function (not a timer)
- Spinner waits for call even if animation finishes first
- Force an error (wrong API key) → error state shows with Retry + Starter Plan buttons
- Tapping "Use Starter Plan" shows a clearly labelled starter-plan ready screen
- Tapping Retry re-calls the Edge Function without restarting onboarding
- `flutter test` passes

---

### Task 4.1: `PlanGenerationNotifier`

- **Location**: `apps/mobile/lib/features/onboarding/presentation/plan_generation_provider.dart` *(new file)*
- **Description**: `AsyncNotifier` that manages the three states of plan generation:
  loading, success, and failure. Called from `PlanGenerationScreen`.

  ```dart
  enum PlanGenerationMode { onboarding, editGoal, newGoal }

  sealed class PlanGenerationState {
    const PlanGenerationState();
  }
  class PlanGenerationIdle extends PlanGenerationState { const PlanGenerationIdle(); }
  class PlanGenerationLoading extends PlanGenerationState { const PlanGenerationLoading(); }
  class PlanGenerationSuccess extends PlanGenerationState {
    const PlanGenerationSuccess(this.versionId);
    final String versionId;
  }
  class PlanGenerationFailure extends PlanGenerationState {
    const PlanGenerationFailure(this.reason);
    final String reason;   // canonical key, not translated
  }

  class PlanGenerationNotifier extends Notifier<PlanGenerationState> {
    @override
    PlanGenerationState build() => const PlanGenerationIdle();

    Future<void> generate({ required String requestedBy }) async {
      state = const PlanGenerationLoading();
      try {
        final client = ref.read(supabaseClientProvider);
        final res = await client.functions.invoke(
          'generate-plan',
          body: { 'requestedBy': requestedBy },
        ).timeout(const Duration(seconds: 60));

        final data = res.data as Map<String, dynamic>?;
        if (data == null || data['versionId'] == null) {
          state = const PlanGenerationFailure('generation_no_data');
          return;
        }

        // Parse and cache the returned plan
        final planJson = data['plan'] as Map<String, dynamic>;
        final plan = TrainingPlan.fromJson(planJson);
        if (plan == null) {
          state = const PlanGenerationFailure('generation_parse_error');
          return;
        }

        final version = PlanVersion(
          id: data['versionId'] as String,
          generatedAt: DateTime.now(),
          requestedBy: requestedBy,
          isActive: true,
          plan: plan,
        );
        await ref.read(planVersionRepositoryProvider).saveActivePlan(version);

        state = PlanGenerationSuccess(data['versionId'] as String);
      } on TimeoutException {
        state = const PlanGenerationFailure('generation_timeout');
      } catch (_) {
        state = const PlanGenerationFailure('generation_error');
      }
    }
  }

  final planGenerationProvider =
      NotifierProvider<PlanGenerationNotifier, PlanGenerationState>(
    PlanGenerationNotifier.new,
  );
  ```

- **Dependencies**: Tasks 2.2, 3.5
- **Acceptance Criteria**:
  - State transitions: idle → loading → success / failure
  - Plan saved to SP cache on success
  - Timeout after 60s with `generation_timeout` failure key
- **Validation**:
  - Unit test state transitions with mock Supabase client

**Status**: ✅ Completed — commit `55da8d7`
**Log**: Created `plan_generation_provider.dart`. Sealed state: `Idle → Loading → Success(versionId) / Failure(reason)`. Calls `client.functions.invoke('generate-plan')`, parses plan JSON, saves via `planVersionRepositoryProvider`. 60s timeout via `.timeout()`. `reason_not_testable`: no mock infrastructure for `SupabaseClient.functions` — verified via `flutter analyze`.
**Files**: `presentation/plan_generation_provider.dart` (new)

---

### Task 4.2: Update `PlanGenerationScreen` to drive the notifier

- **Location**: [apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart](apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart)
- **Description**: Replace the `Timer`-only flow with one that:
  1. In `initState`, fires `planGenerationProvider.notifier.generate()` immediately
  2. Keeps the animation timer running independently (cycles through messages as before)
  3. When animation is "done" (messages exhausted), pauses at 100% and waits for
     the notifier
  4. Watches `planGenerationProvider` — navigates to `planReady` only when
     `PlanGenerationSuccess` AND animation is done
  5. On `PlanGenerationFailure` — transitions to error state UI (Task 4.3)

  Key change — replace the navigate-on-timer-end block:
  ```dart
  // When animation completes, set _animationDone = true
  // Navigation is driven by ref.listen on planGenerationProvider
  ```

  ```dart
  ref.listen<PlanGenerationState>(planGenerationProvider, (_, next) {
    if (next is PlanGenerationSuccess && _animationDone) {
      context.go(nextRoute);
    }
    if (next is PlanGenerationFailure) {
      setState(() => _showError = true);
    }
  });
  ```

- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Screen waits for both animation done AND success before navigating
  - If call finishes before animation, navigation happens as soon as animation ends
  - If animation finishes before call, screen holds at 100% with spinner
  - `flutter analyze` passes

**Status**: ✅ Completed — commit `ce122b2`
**Log**: Replaced timer-only navigation with `_animationDone` flag + `ref.listen`. `generate()` fired in `initState` via `addPostFrameCallback`. Animation completes → sets `_animationDone = true` → checks if already succeeded; listener fires → checks if animation already done. Holds at 100% with spinner when waiting. `GoRouter.of(context)` captured before async gaps to satisfy `use_build_context_synchronously`. `flutter analyze` clean.
**Files**: `screens/plan_generation_screen.dart` (modified)

---

### Task 4.3: Error state UI in `PlanGenerationScreen`

- **Location**: [apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart](apps/mobile/lib/features/onboarding/presentation/screens/plan_generation_screen.dart)
- **Description**: When `_showError == true`, replace the animation content with
  an error state. Add localization keys for all strings.

  Error state shows:
  - Error icon + localized error title + subtitle
  - **"Try Again"** primary button → calls `generate()` on the notifier, resets
    `_showError = false`
  - **"Use Starter Plan"** secondary button → calls `_useStarterPlan()` which sets
    a `_useStarter = true` flag and navigates to `planReady` with a `starterPlan`
    mode flag

  Starter plan flag must propagate to `PlanReadyScreen` so it can display a
  **"This is a general starter plan, not personalized"** banner. It must NOT be
  silent or hidden.

- **Dependencies**: Task 4.2
- **Acceptance Criteria**:
  - Error state renders when generation fails
  - Retry re-enters loading state (animation resets, error UI hides)
  - "Use Starter Plan" routes to `planReady` with visible starter-plan label
  - New ARB keys added to `app_en.arb` and `app_es.arb`, `flutter gen-l10n` run

**Status**: ✅ Completed — commit `ce122b2`
**Log**: `_showError` flag drives `_buildErrorState()` vs `_buildLoadingState()`. Error state: error icon (red border circle), `planGenerationErrorTitle`, `planGenerationErrorSubtitle`, Retry button (resets state + restarts animation), "Use Starter Plan" button (navigates with `?starter=true` query param). Retry resets `_showError`, `_animationDone`, `_messageIndex`, `_progress` and re-calls `generate()`.
**Files**: `screens/plan_generation_screen.dart` (modified)

---

### Task 4.4: Localization for plan generation error states

- **Location**: `apps/mobile/lib/l10n/app_en.arb` and `app_es.arb`
- **Description**: Add keys for error and fallback UI.

  ```json
  "planGenerationErrorTitle": "Couldn't generate your plan",
  "planGenerationErrorSubtitle": "Something went wrong. Your answers are saved.",
  "planGenerationRetry": "Try Again",
  "planGenerationUseStarter": "Use Starter Plan for now",
  "planReadyStarterBanner": "This is a general starter plan, not personalized to your profile.",
  "planReadyPersonalizeAction": "Generate my personalized plan"
  ```

- **Dependencies**: Task 4.3
- **Acceptance Criteria**:
  - `flutter gen-l10n` succeeds without errors
  - Both English and Spanish strings present and non-empty

**Status**: ✅ Completed — commit `ce122b2`
**Log**: Added 6 keys to `app_en.arb` and `app_es.arb`: `planGenerationErrorTitle`, `planGenerationErrorSubtitle`, `planGenerationRetry`, `planGenerationUseStarter`, `planReadyStarterBanner`, `planReadyPersonalizeAction`. `flutter gen-l10n` ran cleanly.
**Files**: `l10n/app_en.arb`, `l10n/app_es.arb`, generated l10n dart files

---

## Sprint 5: Flutter — Migrate `trainingPlanProvider` to Load from Repository

**Goal**: `TrainingPlanNotifier` loads from `planVersionRepository` instead of
`buildSeedTrainingPlan()`. Seed data is retained as the fallback for "Use Starter
Plan" only. Router and all downstream screens handle the async state. `flutter test`
and `flutter analyze` still pass.

**Demo/Validation**:
- New user who completed onboarding via Edge Function → `/today` screen shows
  their personalized plan sessions (not seed data)
- New user who used starter plan → sessions shown with "Starter Plan" label
- Kill and reopen app → plan still loads (from SP cache) before network resolves

---

### Task 5.1: Convert `TrainingPlanNotifier` to `AsyncNotifier<TrainingPlan>`

- **Location**: [apps/mobile/lib/features/training_plan/presentation/training_plan_provider.dart](apps/mobile/lib/features/training_plan/presentation/training_plan_provider.dart)
- **Description**: Migrate from `Notifier<TrainingPlan>` to
  `AsyncNotifier<TrainingPlan>`.

  ```dart
  class TrainingPlanNotifier extends AsyncNotifier<TrainingPlan> {
    @override
    Future<TrainingPlan> build() async {
      final repo = ref.watch(planVersionRepositoryProvider);

      // Fast sync read from cache (SP) for zero-latency first frame
      final cached = repo.loadActivePlanSync();
      if (cached != null) {
        // Trigger async refresh in background without blocking
        Future.microtask(() async {
          final refreshed = await repo.loadActivePlanAsync();
          if (refreshed != null && ref.mounted) {
            state = AsyncData(_applyActivityStatus(refreshed));
          }
        });
        return _applyActivityStatus(cached);
      }

      // No cache — full async load (first install after sign-in)
      final plan = await repo.loadActivePlanAsync();
      if (plan != null) return _applyActivityStatus(plan);

      throw const NoPlanFoundException();
    }
    // skipSession, restoreSession, recordCompletedRunFeedback — update to use
    // state.requireValue instead of state directly
  }
  ```

  Add `NoPlanFoundException` as a simple class in the same file.

- **Dependencies**: Tasks 3.5, 4.1
- **Acceptance Criteria**:
  - Provider loads cached plan synchronously on first frame (no loading flicker)
  - Provider refreshes from Supabase in background
  - All existing methods (`skipSession`, `restoreSession`) still work via `state.requireValue`
- **Validation**:
  - `flutter test` passes
  - `flutter analyze` passes

---

### Task 5.2: Handle `NoPlanFoundException` in router and shell

- **Location**: [apps/mobile/lib/core/router/app_router.dart](apps/mobile/lib/core/router/app_router.dart) and [apps/mobile/lib/features/home/presentation/screens/app_shell.dart](apps/mobile/lib/features/home/presentation/screens/app_shell.dart)
- **Description**: When `trainingPlanProvider` emits `AsyncError(NoPlanFoundException)`,
  the main app shell should show a non-blocking prompt: **"Your plan is being prepared"**
  with a retry action — not a crash or blank screen. The router does **not** need to
  change because users cannot reach `/today` until `saveProfile()` is called on
  `PlanReadyScreen`, which happens only after successful generation.

  This task is defensive only — handles the edge case where a user has a profile but
  no plan (e.g., interrupted onboarding flow).

- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - `AsyncError(NoPlanFoundException)` on `trainingPlanProvider` shows a "plan not ready"
    empty state on the today screen rather than crashing
  - `flutter analyze` passes

---

### Task 5.3: Update all `trainingPlanProvider` consumers for async state

- **Location**: All screens that call `ref.watch(trainingPlanProvider)`
- **Description**: The provider is now `AsyncNotifier`, so consumers must handle
  `AsyncValue`. Screens already using `.when()` or `AsyncValue` patterns need minimal
  changes. Screens using `ref.watch(trainingPlanProvider)` directly need to switch to
  `ref.watch(trainingPlanProvider).valueOrNull ?? fallback`.

  Files to audit:
  - `home_screen.dart`
  - `weekly_plan_screen.dart`
  - `full_plan_screen.dart`
  - `session_detail_screen.dart`
  - `progress_screen.dart`
  - `today_session_card.dart` (if exists)

- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - No runtime `_CastError` or `Null check` crashes on any tab
  - `flutter analyze` passes
- **Validation**:
  - Manually navigate all 4 main tabs after plan loads

---

### Task 5.4: Deploy Edge Function to production

- **Location**: Terminal — `supabase functions deploy`
- **Description**: Deploy the `generate-plan` function to the Supabase project.
  Verify the secret is set. Test end-to-end with a real device sign-up.

  ```bash
  supabase secrets set OPENAI_API_KEY=sk-...
  supabase functions deploy generate-plan
  ```

- **Dependencies**: Tasks 1.6, 5.1
- **Acceptance Criteria**:
  - Function appears in Supabase dashboard under Edge Functions
  - Full flow (sign up → onboarding → generation → today screen) works on device

---

## Testing Strategy

| Sprint | How to verify |
|--------|--------------|
| Sprint 1 | `curl` the deployed Edge Function with a real user JWT |
| Sprint 2 | `flutter test` serialization round-trips |
| Sprint 3 | Integration: save via notifier → kill app → reload → verify plan data matches |
| Sprint 4 | Manual: force error (disconnect network) → retry → success flow |
| Sprint 5 | Navigate all 4 tabs; hot restart; verify no seed data appears |

---

## Potential Risks & Gotchas

1. **`gpt-5.4-mini` latency** — structured output calls can take 10–25 seconds for a
   12-week plan. The `PlanGenerationScreen` animation must not navigate away before
   the call finishes. The `_animationDone` + `PlanGenerationSuccess` dual-gate in
   Task 4.2 prevents this. Set a 60s timeout on the Flutter invoke call.

2. **`WorkoutPhase` is empty after JSON load** — `TrainingSession.phases` will be
   `const []` after deserialization. Session detail screens that iterate `phases`
   will render empty. A future task should add a `buildPhases()` method that
   reconstructs phases from structural fields (`warmUpMinutes`, `workoutSteps`, etc.).
   Mark affected screens with a `// TODO(phase2): rebuild phases` comment.

3. **`trainingPlanProvider` sync → async migration** — this is the highest-impact
   change. Any screen that uses `ref.watch(trainingPlanProvider)` and expects a
   non-null `TrainingPlan` synchronously will break. Audit all consumers in Task 5.3
   before marking Sprint 5 done.

4. **Interrupted onboarding edge case** — if the user closes the app after the Edge
   Function inserts into `plan_versions` but before `saveProfile()` is called on
   `PlanReadyScreen`, the user will be in `authenticatedNeedsProfile` state on
   re-launch (profile not saved). The router redirects them back to `accountSetup`.
   Their onboarding draft is preserved in `runner_profile_drafts`, so they won't
   redo the whole flow, but they WILL re-trigger plan generation, creating a second
   `plan_versions` row. The Edge Function deactivates any previous active plan before
   inserting (Task 1.6 step 5), so this is safe — just wastes one OpenAI call. A future
   improvement would check for an existing active `plan_versions` row before calling
   OpenAI.

5. **`plan_versions.data` JSON size** — a 12-week plan with ~50 sessions is roughly
   40–80 KB of JSON. SharedPreferences can handle this, but if plan complexity grows,
   migrating SP cache to SQLite/Isar will be needed (noted in architecture decision).

6. **Zod version in Deno** — use a pinned version of the `zod` ESM import
   (`deno.land/x/zod@v3.23.8`) to avoid breaking changes on redeploy.

---

## Rollback Plan

- Sprint 1: Drop `plan_versions` table migration; delete Edge Function files
- Sprint 2: Revert `training_session.dart` and `training_plan.dart` — additive only
- Sprint 3: Delete new repository files; revert provider registrations
- Sprint 4: Revert `plan_generation_screen.dart` to timer-only version from git
- Sprint 5: Revert `training_plan_provider.dart` to sync `Notifier` + seed data call;
  re-add `import '../data/training_plan_seed_data.dart'`
