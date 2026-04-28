# Training Plan Schedule Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make generated training plans treat `schedule.hardDays` as days the runner finds hard to train, keep those days as rest days when possible, prevent the first planned session from being a hard workout, and reject final plans with schedule/date inconsistencies before they are saved.

**Architecture:** Keep OpenAI as the initial plan drafter, then enforce product rules deterministically in the Supabase `generate-plan` Edge Function before workout steps are built and before the plan is persisted. The backend remains the source of truth; Flutter should receive only normalized, validated plans.

**Tech Stack:** Supabase Edge Functions on Deno, TypeScript, OpenAI Node SDK structured JSON output, Zod schema validation, existing Deno tests in `supabase/functions/generate-plan`.

---

## Context and Current Failure

The app saved this runner schedule correctly in local app state:

```json
{
  "trainingDays": 4,
  "longRunDay": "day_sat",
  "hardDays": ["day_sun", "day_thu", "day_tue"]
}
```

The generated plan did not fully respect that schedule:

- Tuesday and Sunday still had `easyRun` sessions even though enough non-hard days existed.
- Thursday was usually `restDay`, but that was not enforced as a general rule.
- The first plan session was `intervals`, which is too aggressive as a default first session.
- Some sessions had drift between `id`, `date`, and coach-note wording. Example pattern: ID contains one date while `date` contains another after swaps.

The current backend already has useful rule functions:

- `normalizeTrainingDayCount`
- `placeLongRunsOnPreferredDay`
- `spaceStressfulSessions`
- `avoidHardDayTraining`
- `ensureFullCalendarWeeks`
- `normalizeWorkoutTypesByPhase`
- `addStrideDefaults`

The gap is that `avoidHardDayTraining` currently only moves stressful sessions off hard days. It does not enforce the product meaning of `hardDays`: "days hard to train, prefer rest."

## Context7 Notes

Use these notes when implementing:

- OpenAI Node SDK structured outputs validate JSON shape, but not product-specific schedule correctness. Keep `GeneratedPlanSchema.parse(raw)`, then run deterministic business-rule validation before saving.
- OpenAI Node SDK also supports `client.chat.completions.parse()` with `zodResponseFormat()`. Do not migrate to that helper in this task unless the existing `chat.completions.create()` code becomes a blocker; the current strict JSON schema plus Zod parse is acceptable.
- Supabase Edge Functions are Deno functions and can be covered by `Deno.test`. Supabase docs show local function testing via `deno test --allow-all ...` and function serving via `supabase functions serve`.

## File Responsibility Map

### `supabase/functions/generate-plan/plan-rules.ts`

Primary implementation file. Add deterministic normalization and validation helpers here. Keep functions pure: input sessions/profile/locale, output cloned sessions or validation violations. Do not add database calls here.

New exported helpers to add:

```ts
export function preferRestOnHardDays(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale?: CoachNoteLocale,
): GeneratedSession[];

export function normalizeFirstPlannedSession(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale?: CoachNoteLocale,
): GeneratedSession[];

export function normalizeSessionIds(
  sessions: GeneratedSession[],
): GeneratedSession[];

export type ScheduleValidationViolation = {
  rule:
    | "stressful_session_on_hard_day"
    | "avoidable_training_on_hard_day"
    | "first_session_is_stressful"
    | "session_id_date_mismatch"
    | "long_run_not_on_preferred_day";
  sessionId: string;
  date: string;
  message: string;
};

export function validateGeneratedSchedule(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): ScheduleValidationViolation[];
```

### `supabase/functions/generate-plan/index.ts`

Pipeline orchestration. Insert the new deterministic steps after existing schedule/phase normalization and before `buildWorkoutSteps`. Validate final sessions before inserting into `plan_versions`.

### `supabase/functions/generate-plan/openai.ts`

Prompt contract only. Update language so the model is less likely to produce bad schedules, but keep deterministic validation as the authority.

### `supabase/functions/generate-plan/plan-rules_test.ts`

Main test file. Add regression tests before implementation. Every new rule must have a focused failing test first.

## Schedule Rules to Enforce

Use these rules exactly:

1. `schedule.hardDays` means days hard to train, not days for hard workouts.
2. If the requested `trainingDays` can be satisfied using non-hard days, all hard days must be `restDay`.
3. If `trainingDays` is higher than available non-hard days, hard days may be used only as `easyRun` or `recoveryRun`.
4. Stressful session types must never be placed on hard days except a fixed goal race date:

```ts
const stressfulTypes = [
  "longRun",
  "progressionRun",
  "intervals",
  "hillRepeats",
  "fartlek",
  "tempoRun",
  "thresholdRun",
  "racePaceRun",
];
```

5. The first chronological planned training session must not be stressful unless it is a fixed goal race date.
6. The preferred long-run day must be respected when it is not a hard day and a low-stress swap candidate exists.
7. `id` must be regenerated from final `weekNumber`, final `date`, and final `type` after all date/type changes.
8. Do not generate unsupported activity suggestions. The app supports run/rest sessions in this plan path; prompt and deterministic coach notes should not mention mobility or cross-training.

## Pipeline Order

Change `index.ts` pipeline to this order:

```ts
const scheduleNormalizedSessions = normalizeTrainingDayCount(
  generatedPlan.sessions,
  profileData,
  locale,
);
const longRunPlacedSessions = placeLongRunsOnPreferredDay(
  scheduleNormalizedSessions,
  profileData,
  locale,
);
const stressSpacedSessions = spaceStressfulSessions(
  longRunPlacedSessions,
  profileData,
  locale,
);
const hardDayRestedSessions = preferRestOnHardDays(
  stressSpacedSessions,
  profileData,
  locale,
);
const scheduleAdjustedSessions = avoidHardDayTraining(
  hardDayRestedSessions,
  profileData,
  locale,
);
const fullCalendarSessions = ensureFullCalendarWeeks(
  scheduleAdjustedSessions,
  locale,
);
const peakNormalizedSessions = normalizePeakLongRun(
  fullCalendarSessions,
  profileData,
  generatedPlan.totalWeeks,
  locale,
);
const progressionSmoothedSessions = smoothLongRunProgression(
  peakNormalizedSessions,
  profileData,
  generatedPlan.totalWeeks,
  locale,
);
const taperNormalizedSessions = normalizeTaper(
  progressionSmoothedSessions,
  profileData,
  generatedPlan.totalWeeks,
  locale,
);
const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
  taperNormalizedSessions,
  profileData,
  generatedPlan.totalWeeks,
  locale,
);
const firstSessionNormalizedSessions = normalizeFirstPlannedSession(
  phaseNormalizedSessions,
  profileData,
  locale,
);
const phaseStampedSessions = firstSessionNormalizedSessions.map((session) => ({
  ...session,
  phase: phaseForWeek(session.weekNumber, generatedPlan.totalWeeks, profileData),
}));
const raceFinalizedSessions = ensureGoalRaceSession(
  phaseStampedSessions,
  profileData,
  locale,
);
const idNormalizedSessions = normalizeSessionIds(raceFinalizedSessions);
const finalViolations = validateGeneratedSchedule(
  idNormalizedSessions,
  profileData,
);
if (finalViolations.length > 0) {
  console.error("Generated plan failed schedule validation:", finalViolations);
  return new Response(
    JSON.stringify({
      error: "Generated plan failed schedule validation",
      violations: finalViolations,
    }),
    { status: 500, headers: { "Content-Type": "application/json" } },
  );
}
const sessionsWithSteps = addStrideDefaults(
  idNormalizedSessions,
  profileData,
  generatedPlan.totalWeeks,
  locale,
).map((session) => ({
  ...session,
  description: session.coachNote,
  status: "upcoming",
  workoutSteps: buildWorkoutSteps(session),
}));
```

Reasoning:

- `preferRestOnHardDays` should run before full calendar fill so existing training/rest sessions are repaired first.
- `avoidHardDayTraining` remains as a safety pass for stressful sessions.
- `normalizeFirstPlannedSession` should run after phase normalization because phase normalization can still produce or preserve stressful types.
- `ensureGoalRaceSession` should run after first-session normalization so a fixed race date is restored if relevant.
- `normalizeSessionIds` must run after all date and type changes.
- `validateGeneratedSchedule` must run before `addStrideDefaults` and persistence.

## Task 1: Add Regression Tests for Hard-Day Rest Semantics

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Import new helpers**

Update the import from `./plan-rules.ts`:

```ts
import {
  addStrideDefaults,
  avoidHardDayTraining,
  ensureFullCalendarWeeks,
  ensureGoalRaceSession,
  normalizeFirstPlannedSession,
  normalizePeakLongRun,
  normalizeSessionIds,
  normalizeTaper,
  normalizeTrainingDayCount,
  peakLongRunRangeKm,
  phaseForWeek,
  phasePlanFor,
  placeLongRunsOnPreferredDay,
  preferRestOnHardDays,
  smoothLongRunProgression,
  spaceStressfulSessions,
  validateGeneratedSchedule,
  workoutPolicyForPhase,
} from "./plan-rules.ts";
```

- [ ] **Step 2: Add test for normal 4-day plan**

Add this test near the existing `avoidHardDayTraining` tests:

```ts
Deno.test("preferRestOnHardDays keeps hard days as rest when non-hard days can satisfy 4 training days", () => {
  const sessions = preferRestOnHardDays(
    [
      session({ id: "w1-mon-quality", date: "2026-04-27", type: "intervals" }),
      session({ id: "w1-tue-easy", date: "2026-04-28", type: "easyRun" }),
      session({ id: "w1-wed-rest", date: "2026-04-29", type: "restDay" }),
      session({ id: "w1-thu-easy", date: "2026-04-30", type: "easyRun" }),
      session({ id: "w1-fri-rest", date: "2026-05-01", type: "restDay" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
      session({ id: "w1-sun-easy", date: "2026-05-03", type: "easyRun" }),
    ],
    profile({
      trainingDays: 4,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
    }),
  );

  assert.equal(findByDate(sessions, "2026-04-28").type, "restDay");
  assert.equal(findByDate(sessions, "2026-04-30").type, "restDay");
  assert.equal(findByDate(sessions, "2026-05-03").type, "restDay");
  assert.equal(findByDate(sessions, "2026-05-02").type, "longRun");
  assert.equal(trainingCountForTest(sessions), 4);
  assert.ok(
    sessions.every((item) =>
      !["2026-04-28", "2026-04-30", "2026-05-03"].includes(item.date) ||
      item.type === "restDay"
    ),
  );
});
```

- [ ] **Step 3: Add test for constrained fallback**

```ts
Deno.test("preferRestOnHardDays uses only easy or recovery runs on hard days when schedule is over-constrained", () => {
  const sessions = preferRestOnHardDays(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-tue-tempo", date: "2026-04-28", type: "tempoRun" }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-thu-intervals", date: "2026-04-30", type: "intervals" }),
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
      session({ id: "w1-sun-fartlek", date: "2026-05-03", type: "fartlek" }),
    ],
    profile({
      trainingDays: 6,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
    }),
  );

  const hardDaySessions = [
    findByDate(sessions, "2026-04-28"),
    findByDate(sessions, "2026-04-30"),
    findByDate(sessions, "2026-05-03"),
  ];
  assert.ok(
    hardDaySessions.every((item) =>
      ["restDay", "easyRun", "recoveryRun"].includes(item.type)
    ),
  );
  assert.equal(trainingCountForTest(sessions), 6);
});
```

- [ ] **Step 4: Add test helpers**

Append these helpers near existing `findSession` / `strideCount` helpers:

```ts
function findByDate(sessions: GeneratedSession[], date: string): GeneratedSession {
  const found = sessions.find((item) => item.date === date);
  assert.ok(found, `Expected session on ${date} to exist`);
  return found;
}

function trainingCountForTest(sessions: GeneratedSession[]): number {
  return sessions.filter((item) => item.type !== "restDay").length;
}
```

- [ ] **Step 5: Run tests and confirm failure**

Run:

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
FAIL preferRestOnHardDays keeps hard days as rest when non-hard days can satisfy 4 training days
FAIL preferRestOnHardDays uses only easy or recovery runs on hard days when schedule is over-constrained
```

- [ ] **Step 6: Commit failing tests**

```bash
git add supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "test: cover hard-day rest scheduling rules"
```

## Task 2: Implement Hard-Day Rest Normalization

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Add exported function**

Add this function after `avoidHardDayTraining`:

```ts
export function preferRestOnHardDays(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const hardDays = hardDaySetFor(profileData);
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  if (hardDays.size === 0 || targetTrainingDays == null) return sessions;

  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      preferRestOnHardDaysForWeek(
        sessionsByWeek.get(weekNumber) ?? [],
        hardDays,
        targetTrainingDays,
        profileData,
        locale,
      )
    )
    .sort(compareSessionsByDate);
}
```

- [ ] **Step 2: Add weekly implementation**

Add this helper near `normalizeWeekTrainingDays`:

```ts
function preferRestOnHardDaysForWeek(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
  targetTrainingDays: number,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );

  const nonHardDates = new Set(
    adjusted
      .filter((session) => !hardDays.has(dayKeyForDate(session.date)))
      .map((session) => session.date.slice(0, 10)),
  );
  const canSatisfyWithoutHardDays = nonHardDates.size >= targetTrainingDays;

  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (!isTrainingDay(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;
    if (!hardDays.has(dayKeyForDate(session.date))) continue;

    if (canSatisfyWithoutHardDays) {
      const swapIndex = findNonHardRestSwapIndex(adjusted, i, hardDays);
      if (swapIndex != null) {
        const swapSession = adjusted[swapIndex];
        adjusted[swapIndex] = withScheduleNote(
          { ...session, date: swapSession.date },
          locale,
        );
        adjusted[i] = toRestDay({ ...swapSession, date: session.date }, locale);
        continue;
      }
      adjusted[i] = toRestDay(session, locale);
      continue;
    }

    if (isStressfulSession(session)) {
      adjusted[i] = toHardDayLowStressFallback(session, locale);
    }
  }

  return adjusted.sort(compareSessionsByDate);
}
```

- [ ] **Step 3: Add swap helper**

```ts
function findNonHardRestSwapIndex(
  sessions: GeneratedSession[],
  sourceIndex: number,
  hardDays: Set<string>,
): number | null {
  const source = sessions[sourceIndex];
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    if (i === sourceIndex) continue;
    const candidate = sessions[i];
    if (candidate.weekNumber !== source.weekNumber) continue;
    if (candidate.type !== "restDay") continue;
    if (hardDays.has(dayKeyForDate(candidate.date))) continue;

    const score = Math.abs(dayOffsetInWeek(source.date) - dayOffsetInWeek(candidate.date));
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}
```

- [ ] **Step 4: Add hard-day fallback helper**

```ts
function toHardDayLowStressFallback(
  session: GeneratedSession,
  locale: CoachNoteLocale,
): GeneratedSession {
  return {
    ...session,
    type: "recoveryRun",
    distanceKm: null,
    durationMinutes: Math.min(30, Math.max(20, session.durationMinutes ?? 25)),
    coachNote: trainingDayCue("hardDayRecoveryFallback", locale),
    targetZone: "recovery",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}
```

- [ ] **Step 5: Add cue key**

Extend `TrainingDayCueKey`:

```ts
  | "hardDayRecoveryFallback"
```

Add cue:

```ts
    hardDayRecoveryFallback: {
      en: "Short recovery run kept because your selected training schedule is tight.",
      es:
        "Carrera corta de recuperación mantenida porque tu horario seleccionado es ajustado.",
    },
```

- [ ] **Step 6: Run tests**

Run:

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
ok preferRestOnHardDays keeps hard days as rest when non-hard days can satisfy 4 training days
ok preferRestOnHardDays uses only easy or recovery runs on hard days when schedule is over-constrained
```

- [ ] **Step 7: Commit**

```bash
git add supabase/functions/generate-plan/plan-rules.ts supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "feat: treat hard training days as rest when possible"
```

## Task 3: Prevent Hard First Session

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Add failing test**

```ts
Deno.test("normalizeFirstPlannedSession downgrades first hard workout", () => {
  const sessions = normalizeFirstPlannedSession(
    [
      session({ id: "w1-mon-intervals", date: "2026-04-27", type: "intervals" }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_experienced" }),
  );

  const first = findByDate(sessions, "2026-04-27");
  assert.equal(first.type, "easyRun");
  assert.equal(first.targetZone, "easy");
  assert.equal(first.intervalReps, null);
  assert.equal(first.intervalRepDistanceMeters, null);
  assert.equal(first.intervalRecoverySeconds, null);
});
```

Run:

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
FAIL normalizeFirstPlannedSession downgrades first hard workout
```

- [ ] **Step 2: Add exported function**

Add this function near `preferRestOnHardDays`:

```ts
export function normalizeFirstPlannedSession(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );
  const firstTrainingIndex = adjusted.findIndex((session) =>
    isTrainingDay(session) && !isGoalRaceSession(session, profileData)
  );
  if (firstTrainingIndex < 0) return adjusted;

  const firstSession = adjusted[firstTrainingIndex];
  if (!isStressfulSession(firstSession)) return adjusted;

  adjusted[firstTrainingIndex] = toFirstSessionEasyRun(
    firstSession,
    profileData,
    locale,
  );
  return adjusted;
}
```

- [ ] **Step 3: Add downgrade helper**

```ts
function toFirstSessionEasyRun(
  session: GeneratedSession,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession {
  const fitness = objectOrNull(profileData.fitness);
  const experience = typeof fitness?.experience === "string"
    ? fitness.experience
    : "experience_beginner";
  const useRecovery = experience === "experience_beginner";

  return {
    ...session,
    type: useRecovery ? "recoveryRun" : "easyRun",
    distanceKm: null,
    durationMinutes: useRecovery ? 25 : Math.min(40, Math.max(30, session.durationMinutes ?? 35)),
    coachNote: trainingDayCue("firstSessionEasyStart", locale),
    targetZone: useRecovery ? "recovery" : "easy",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}
```

- [ ] **Step 4: Add cue key**

Extend `TrainingDayCueKey`:

```ts
  | "firstSessionEasyStart"
```

Add cue:

```ts
    firstSessionEasyStart: {
      en: "Start the plan with a controlled easy run before adding harder workouts.",
      es:
        "Empieza el plan con una carrera suave y controlada antes de añadir entrenamientos más duros.",
    },
```

- [ ] **Step 5: Run tests and commit**

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
git add supabase/functions/generate-plan/plan-rules.ts supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "feat: prevent generated plans from starting hard"
```

Expected:

```text
ok normalizeFirstPlannedSession downgrades first hard workout
```

## Task 4: Normalize Session IDs After Date and Type Changes

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Add failing test**

```ts
Deno.test("normalizeSessionIds regenerates ids from final date and type", () => {
  const sessions = normalizeSessionIds([
    session({
      id: "w1-2026-04-30-intervals",
      date: "2026-04-27",
      weekNumber: 1,
      type: "easyRun",
    }),
    session({
      id: "custom-rest",
      date: "2026-04-28",
      weekNumber: 1,
      type: "restDay",
    }),
  ]);

  assert.equal(sessions[0].id, "w1-2026-04-27-easyRun");
  assert.equal(sessions[1].id, "w1-2026-04-28-restDay");
});
```

Run:

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
FAIL normalizeSessionIds regenerates ids from final date and type
```

- [ ] **Step 2: Add exported function**

```ts
export function normalizeSessionIds(
  sessions: GeneratedSession[],
): GeneratedSession[] {
  const usedIds = new Set<string>();

  return sessions
    .map((session) => {
      const baseId = `w${session.weekNumber}-${session.date.slice(0, 10)}-${session.type}`;
      const id = uniqueSessionId(baseId, usedIds);
      usedIds.add(id);
      return { ...session, id };
    })
    .sort(compareSessionsByDate);
}
```

- [ ] **Step 3: Add uniqueness helper**

```ts
function uniqueSessionId(baseId: string, usedIds: Set<string>): string {
  if (!usedIds.has(baseId)) return baseId;

  let suffix = 2;
  while (usedIds.has(`${baseId}-${suffix}`)) {
    suffix += 1;
  }
  return `${baseId}-${suffix}`;
}
```

- [ ] **Step 4: Run tests and commit**

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
git add supabase/functions/generate-plan/plan-rules.ts supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "feat: normalize generated session ids"
```

Expected:

```text
ok normalizeSessionIds regenerates ids from final date and type
```

## Task 5: Add Final Schedule Validation

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Add failing validation test**

```ts
Deno.test("validateGeneratedSchedule reports hard-day and id-date violations", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-04-30-intervals",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-2026-04-29-easyRun",
        date: "2026-04-29",
        type: "easyRun",
      }),
    ],
    profile({
      trainingDays: 4,
      hardDays: ["day_tue"],
    }),
  );

  assert.ok(
    violations.some((item) => item.rule === "stressful_session_on_hard_day"),
  );
  assert.ok(
    violations.some((item) => item.rule === "session_id_date_mismatch"),
  );
});
```

Run:

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
FAIL validateGeneratedSchedule reports hard-day and id-date violations
```

- [ ] **Step 2: Add type and exported function**

Add near exported functions:

```ts
export type ScheduleValidationViolation = {
  rule:
    | "stressful_session_on_hard_day"
    | "avoidable_training_on_hard_day"
    | "first_session_is_stressful"
    | "session_id_date_mismatch"
    | "long_run_not_on_preferred_day";
  sessionId: string;
  date: string;
  message: string;
};
```

Add function:

```ts
export function validateGeneratedSchedule(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): ScheduleValidationViolation[] {
  const hardDays = hardDaySetFor(profileData);
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  const preferredLongRunDay = preferredLongRunDayFor(profileData);
  const violations: ScheduleValidationViolation[] = [];
  const sorted = [...sessions].sort(compareSessionsByDate);

  const nonHardDateCount = new Set(
    sorted
      .filter((session) => !hardDays.has(dayKeyForDate(session.date)))
      .map((session) => session.date.slice(0, 10)),
  ).size;
  const hardDaysAreAvoidable =
    targetTrainingDays != null && nonHardDateCount >= targetTrainingDays;

  for (const session of sorted) {
    const dayKey = dayKeyForDate(session.date);
    if (
      hardDays.has(dayKey) &&
      isStressfulSession(session) &&
      !isGoalRaceSession(session, profileData)
    ) {
      violations.push({
        rule: "stressful_session_on_hard_day",
        sessionId: session.id,
        date: session.date,
        message: `${session.type} is scheduled on ${dayKey}, which is marked hard to train.`,
      });
    }

    if (
      hardDaysAreAvoidable &&
      hardDays.has(dayKey) &&
      isTrainingDay(session) &&
      !isGoalRaceSession(session, profileData)
    ) {
      violations.push({
        rule: "avoidable_training_on_hard_day",
        sessionId: session.id,
        date: session.date,
        message: `${session.type} is scheduled on avoidable hard day ${dayKey}.`,
      });
    }

    if (!session.id.includes(session.date.slice(0, 10))) {
      violations.push({
        rule: "session_id_date_mismatch",
        sessionId: session.id,
        date: session.date,
        message: `Session id does not include final date ${session.date.slice(0, 10)}.`,
      });
    }
  }

  const firstTraining = sorted.find((session) =>
    isTrainingDay(session) && !isGoalRaceSession(session, profileData)
  );
  if (firstTraining != null && isStressfulSession(firstTraining)) {
    violations.push({
      rule: "first_session_is_stressful",
      sessionId: firstTraining.id,
      date: firstTraining.date,
      message: `${firstTraining.type} is the first planned training session.`,
    });
  }

  if (preferredLongRunDay != null && !hardDays.has(preferredLongRunDay)) {
    for (const weekNumber of new Set(sorted.map((session) => session.weekNumber))) {
      const weekSessions = sorted.filter((session) => session.weekNumber === weekNumber);
      const longRun = weekSessions.find((session) => session.type === "longRun");
      if (
        longRun != null &&
        !isGoalRaceSession(longRun, profileData) &&
        dayKeyForDate(longRun.date) !== preferredLongRunDay &&
        weekSessions.some((session) =>
          dayKeyForDate(session.date) === preferredLongRunDay &&
          isLowStressSession(session)
        )
      ) {
        violations.push({
          rule: "long_run_not_on_preferred_day",
          sessionId: longRun.id,
          date: longRun.date,
          message: `Long run is not on preferred day ${preferredLongRunDay}.`,
        });
      }
    }
  }

  return violations;
}
```

- [ ] **Step 3: Run tests and commit**

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
git add supabase/functions/generate-plan/plan-rules.ts supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "feat: validate generated schedule before save"
```

Expected:

```text
ok validateGeneratedSchedule reports hard-day and id-date violations
```

## Task 6: Wire New Rules Into the Edge Function Pipeline

**Files:**
- Modify: `supabase/functions/generate-plan/index.ts`
- Test: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Update imports**

In `index.ts`, add:

```ts
  normalizeFirstPlannedSession,
  normalizeSessionIds,
  preferRestOnHardDays,
  validateGeneratedSchedule,
```

- [ ] **Step 2: Replace pipeline block**

Replace the current normalization block from `scheduleNormalizedSessions` through `sessionsWithSteps` with the pipeline shown in the "Pipeline Order" section of this plan.

- [ ] **Step 3: Run function tests**

```bash
deno test supabase/functions/generate-plan
```

Expected:

```text
ok
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/generate-plan/index.ts
git commit -m "feat: enforce schedule validation in plan generation"
```

## Task 7: Update OpenAI Prompt Contract

**Files:**
- Modify: `supabase/functions/generate-plan/openai.ts`

- [ ] **Step 1: Replace hard-day prompt paragraph**

Replace:

```text
Treat schedule.hardDays as days the runner prefers not to train. Avoid placing
long runs, intervals, hills, tempo, threshold, race-pace, fartlek, progression,
or other high-stress sessions on those days. If the schedule is constrained, use
hardDays only for rest, recovery, short easy running, or optional cross-training.
Do not move a fixed goal race date just because it falls on a hardDay.
```

With:

```text
Treat schedule.hardDays as days the runner finds hard to train. These are
unavailable or prefer-rest days, not hard-workout days. If schedule.trainingDays
can be satisfied using non-hard days, schedule restDay on every hardDay. If the
selected schedule is too constrained and a hardDay must be used, use only
easyRun or recoveryRun there. Never place longRun, intervals, hills, tempo,
threshold, race-pace, fartlek, progression, or other high-stress sessions on a
hardDay. Do not move a fixed goal race date just because it falls on a hardDay.
The app supports run and rest sessions in this flow; do not suggest unsupported
mobility, strength, or cross-training activities in coachNote text.
```

- [ ] **Step 2: Add first-session prompt rule**

After phase descriptions, add:

```text
The first planned training session should be easyRun or recoveryRun unless it is
a fixed goal race date. Introduce quality sessions only after the runner has at
least one controlled easy/base session in the plan.
```

- [ ] **Step 3: Run tests**

```bash
deno test supabase/functions/generate-plan
```

Expected:

```text
ok
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/generate-plan/openai.ts
git commit -m "chore: clarify generated plan schedule prompt"
```

## Task 8: Add End-to-End Rule Test for the Observed Profile

**Files:**
- Modify: `supabase/functions/generate-plan/plan-rules_test.ts`

- [ ] **Step 1: Add pipeline-style test**

Add a test that runs the same sequence used by `index.ts` without calling OpenAI:

```ts
Deno.test("schedule rule pipeline fixes observed Tue Thu Sun hard-day profile", () => {
  const profileData = profile({
    race: "race_10k",
    experience: "experience_experienced",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu", "day_sun"],
    longRunDay: "day_sat",
  });
  const totalWeeks = 8;
  const input = [
    session({ id: "w1-2026-04-30-intervals", date: "2026-04-27", type: "intervals" }),
    session({ id: "w1-2026-04-28-easy", date: "2026-04-28", type: "easyRun" }),
    session({ id: "w1-2026-04-29-rest", date: "2026-04-29", type: "restDay" }),
    session({ id: "w1-2026-04-30-rest", date: "2026-04-30", type: "restDay" }),
    session({ id: "w1-2026-05-01-rest", date: "2026-05-01", type: "restDay" }),
    session({ id: "w1-2026-05-03-longRun", date: "2026-05-02", type: "longRun" }),
    session({ id: "w1-2026-05-02-easyRun", date: "2026-05-03", type: "easyRun" }),
  ];

  const result = normalizeSessionIds(
    normalizeFirstPlannedSession(
      preferRestOnHardDays(
        placeLongRunsOnPreferredDay(
          normalizeTrainingDayCount(input, profileData),
          profileData,
        ),
        profileData,
      ),
      profileData,
    ),
  );

  assert.equal(findByDate(result, "2026-04-27").type, "easyRun");
  assert.equal(findByDate(result, "2026-04-28").type, "restDay");
  assert.equal(findByDate(result, "2026-04-30").type, "restDay");
  assert.equal(findByDate(result, "2026-05-02").type, "longRun");
  assert.equal(findByDate(result, "2026-05-03").type, "restDay");
  assert.equal(trainingCountForTest(result), 4);
  assert.deepEqual(validateGeneratedSchedule(result, profileData), []);
  assert.ok(result.every((item) => item.id.includes(item.date.slice(0, 10))));
});
```

- [ ] **Step 2: Run tests**

```bash
deno test supabase/functions/generate-plan/plan-rules_test.ts
```

Expected:

```text
ok schedule rule pipeline fixes observed Tue Thu Sun hard-day profile
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/generate-plan/plan-rules_test.ts
git commit -m "test: cover observed generated plan schedule regression"
```

## Task 9: Verification and Deployment Prep

**Files:**
- No code changes unless tests reveal an issue.

- [ ] **Step 1: Run all Edge Function tests**

```bash
deno test supabase/functions/generate-plan
```

Expected:

```text
ok
```

- [ ] **Step 2: Run Flutter static analysis**

```bash
cd apps/mobile
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 3: Run focused Flutter tests**

```bash
cd apps/mobile
flutter test test/features/training_plan/domain/models test/features/training_plan/data test/features/training_plan/presentation
```

Expected:

```text
All tests passed!
```

- [ ] **Step 4: Optional local function smoke test**

Use this only when local Supabase is configured:

```bash
supabase start
supabase functions serve generate-plan
```

Then invoke from the app or a valid authenticated client. Verify the response plan for the observed profile has:

```text
Tue restDay
Thu restDay
Sun restDay when avoidable
Sat longRun
first training session easyRun or recoveryRun
no id/date mismatch
```

- [ ] **Step 5: Deploy when tests pass**

```bash
supabase functions deploy generate-plan
```

Expected:

```text
Deployed Function generate-plan
```

Commit deployment-related code before deploying:

```bash
git status --short
git log --oneline -5
```

## Acceptance Criteria

The implementation is complete only when all criteria are true:

- A 4-day training plan with hard Tue/Thu/Sun and long-run Saturday keeps Tue/Thu/Sun as `restDay`.
- A constrained plan that must use hard days uses only `easyRun` or `recoveryRun` on those days.
- No stressful session lands on hard days unless it is the fixed goal race date.
- The first chronological training session is not stressful unless it is the fixed goal race date.
- Long runs land on the selected long-run day when that day is not hard and a low-stress swap candidate exists.
- Every final session ID includes the final `date`.
- Final validation runs before saving to `plan_versions`.
- Prompt no longer mentions unsupported mobility or cross-training suggestions.
- `deno test supabase/functions/generate-plan` passes.
- `flutter analyze` passes from `apps/mobile/`.

## Risks and Mitigations

- Risk: `preferRestOnHardDays` may reduce training count if no non-hard rest day exists.
  - Mitigation: Only force hard days to rest when non-hard dates can satisfy `trainingDays`; otherwise downgrade hard-day sessions to recovery.

- Risk: session ID changes could affect completed activity linking later.
  - Mitigation: This plan normalizes IDs only before persistence for newly generated plans. Existing saved plans are not migrated.

- Risk: fixed race date could violate hard-day rules.
  - Mitigation: Keep the explicit exception for fixed goal race date. The user selected the race date directly.

- Risk: long-run placement and hard-day rest rules could fight each other.
  - Mitigation: If preferred long-run day is hard, do not force long run there. If preferred day is not hard, validation expects long run there only when a low-stress swap candidate exists.

- Risk: OpenAI may still produce poor schedules despite prompt changes.
  - Mitigation: Deterministic normalization and final validation remain authoritative.

## Rollback Plan

If deployment causes bad generated plans or function failures:

1. Revert the commits touching:
   - `supabase/functions/generate-plan/plan-rules.ts`
   - `supabase/functions/generate-plan/plan-rules_test.ts`
   - `supabase/functions/generate-plan/index.ts`
   - `supabase/functions/generate-plan/openai.ts`
2. Redeploy the previous `generate-plan` function:

```bash
supabase functions deploy generate-plan
```

3. Existing active plans in `plan_versions` are not migrated by this plan. If a bad plan was generated after deployment, regenerate a plan after rollback or manually deactivate the bad `plan_versions` row.

## Self-Review Checklist

- Spec coverage: hard days as rest, constrained fallback, first-session rule, date/id consistency, validation, prompt update, and no unsupported activity suggestions are each covered by a task.
- Placeholder scan: this plan does not use placeholder tasks; every task has files, steps, commands, expected results, and acceptance criteria.
- Type consistency: helper names are consistent across tests, implementation, imports, and pipeline wiring.
- Scope control: no Flutter UI changes, no profile schema migration, no historical plan migration.
