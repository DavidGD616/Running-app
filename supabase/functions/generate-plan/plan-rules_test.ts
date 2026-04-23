import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  normalizeTrainingDayCount,
  placeLongRunsOnPreferredDay,
  spaceStressfulSessions,
} from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("addStrideDefaults adds intermediate stride defaults", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 4);
  assert.equal(sessions[0].strideSeconds, 20);
  assert.equal(sessions[0].strideRecoverySeconds, 90);
  assert.match(sessions[0].coachNote ?? "", /fast but smooth/i);
});

Deno.test("addStrideDefaults adds larger experienced stride defaults", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({ experience: "experience_experienced" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 6);
  assert.equal(sessions[0].strideSeconds, 20);
  assert.equal(sessions[0].strideRecoverySeconds, 80);
});

Deno.test("addStrideDefaults can add two weekly stride sessions when safe", () => {
  const sessions = addStrideDefaults(
    [
      session({ id: "w1-mon", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed", date: "2026-04-29", type: "recoveryRun" }),
      session({ id: "w1-sat", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-mon").strideReps, 4);
  assert.equal(findSession(sessions, "w1-wed").strideReps, 4);
  assert.equal(findSession(sessions, "w1-sat").strideReps, null);
});

Deno.test("addStrideDefaults does not auto-add beginner strides", () => {
  const sessions = addStrideDefaults(
    [
      session({ id: "w1-mon", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed", date: "2026-04-29", type: "easyRun" }),
    ],
    profile({ experience: "experience_beginner" }),
    6,
  );

  assert.equal(strideCount(sessions), 0);
});

Deno.test("addStrideDefaults skips hard days and uses another easy day in the week", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-tue",
        date: "2026-04-28",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({
      experience: "experience_intermediate",
      hardDays: ["day_mon"],
    }),
    6,
  );

  assert.equal(sessions[0].strideReps, null);
  assert.equal(sessions[1].strideReps, 4);
});

Deno.test("addStrideDefaults removes all strides in race week", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w8-mon",
        date: "2026-06-15",
        weekNumber: 8,
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        weekNumber: 8,
        type: "racePaceRun",
      }),
    ],
    profile({
      experience: "experience_intermediate",
      raceDate: "2026-06-21T00:00:00.000",
    }),
    8,
  );

  assert.equal(strideCount(sessions), 0);
});

Deno.test("addStrideDefaults clamps OpenAI stride values to safe ranges", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        type: "easyRun",
        strideReps: 12,
        strideSeconds: 45,
        strideRecoverySeconds: 30,
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 8);
  assert.equal(sessions[0].strideSeconds, 30);
  assert.equal(sessions[0].strideRecoverySeconds, 60);
});

Deno.test("addStrideDefaults removes extra or badly placed stride sessions", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon-easy",
        date: "2026-04-27",
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-wed-recovery",
        date: "2026-04-29",
        type: "recoveryRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-thu-easy",
        date: "2026-04-30",
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-tue-tempo").strideReps, null);
});

Deno.test("avoidHardDayTraining swaps stressful sessions off hard days", () => {
  const sessions = avoidHardDayTraining(
    [
      session({
        id: "w1-tue-quality",
        date: "2026-04-28",
        weekNumber: 1,
        type: "intervals",
      }),
      session({
        id: "w1-wed-rest",
        date: "2026-04-29",
        weekNumber: 1,
        type: "restDay",
      }),
    ],
    profile({ hardDays: ["day_tue"] }),
  );

  assert.equal(sessions[0].date, "2026-04-29");
  assert.equal(sessions[1].date, "2026-04-28");
  assert.match(sessions[0].coachNote ?? "", /hard to train/i);
});

Deno.test("avoidHardDayTraining does not move a fixed goal race date", () => {
  const sessions = avoidHardDayTraining(
    [
      session({
        id: "race",
        date: "2026-04-28",
        weekNumber: 1,
        type: "racePaceRun",
      }),
      session({
        id: "w1-wed-rest",
        date: "2026-04-29",
        weekNumber: 1,
        type: "restDay",
      }),
    ],
    profile({
      hardDays: ["day_tue"],
      raceDate: "2026-04-28T00:00:00.000",
    }),
  );

  assert.equal(sessions[0].date, "2026-04-28");
  assert.equal(sessions[1].date, "2026-04-29");
});

Deno.test("normalizeTrainingDayCount converts lowest priority sessions to rest days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({
        id: "w1-tue-quality",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-wed-recovery",
        date: "2026-04-29",
        type: "recoveryRun",
      }),
      session({
        id: "w1-thu-cross",
        date: "2026-04-30",
        type: "crossTraining",
      }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 3 }),
  );

  assert.equal(trainingDayCount(sessions), 3);
  assert.equal(findSession(sessions, "w1-thu-cross").type, "restDay");
  assert.equal(findSession(sessions, "w1-wed-recovery").type, "restDay");
  assert.equal(findSession(sessions, "w1-tue-quality").type, "intervals");
  assert.equal(findSession(sessions, "w1-sat-long").type, "longRun");
});

Deno.test("normalizeTrainingDayCount converts rest days into easy training days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-tue-rest", date: "2026-04-28", type: "restDay" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 3 }),
  );

  assert.equal(trainingDayCount(sessions), 3);
  assert.equal(findSession(sessions, "w1-tue-rest").type, "easyRun");
  assert.equal(findSession(sessions, "w1-tue-rest").durationMinutes, 35);
});

Deno.test("normalizeTrainingDayCount adds missing easy days when week has no rest days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 4, hardDays: ["day_tue"] }),
  );

  assert.equal(trainingDayCount(sessions), 4);
  assert.equal(new Set(sessions.map((item) => item.date)).size, 4);
  assert.ok(sessions.some((item) => item.id.includes("2026-04-29-added")));
  assert.ok(sessions.some((item) => item.id.includes("2026-04-30-added")));
});

Deno.test("spaceStressfulSessions swaps adjacent hard sessions apart", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
  );

  assert.equal(findSession(sessions, "w1-mon-intervals").date, "2026-04-27");
  assert.equal(findSession(sessions, "w1-tue-tempo").date, "2026-04-29");
  assert.equal(findSession(sessions, "w1-wed-easy").date, "2026-04-28");
  assert.match(
    findSession(sessions, "w1-tue-tempo").coachNote ?? "",
    /spaced safely/i,
  );
});

Deno.test("spaceStressfulSessions downgrades extra weekly stress", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-fartlek",
        date: "2026-04-27",
        type: "fartlek",
      }),
      session({
        id: "w1-tue-intervals",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-thu-tempo",
        date: "2026-04-30",
        type: "tempoRun",
      }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
  );

  assert.equal(stressDayCount(sessions), 3);
  assert.equal(findSession(sessions, "w1-mon-fartlek").type, "recoveryRun");
  assert.equal(findSession(sessions, "w1-sat-long").type, "longRun");
});

Deno.test("spaceStressfulSessions preserves fixed goal race date", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-tempo",
        date: "2026-04-27",
        type: "tempoRun",
      }),
      session({
        id: "race",
        date: "2026-04-28",
        type: "racePaceRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
    ],
    profile({
      experience: "experience_intermediate",
      raceDate: "2026-04-28T00:00:00.000",
    }),
  );

  assert.equal(findSession(sessions, "race").date, "2026-04-28");
  assert.notEqual(findSession(sessions, "w1-mon-tempo").type, "tempoRun");
});

Deno.test("spaceStressfulSessions does not swap hard sessions onto hard days", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-thu-easy", date: "2026-04-30", type: "easyRun" }),
    ],
    profile({
      experience: "experience_intermediate",
      hardDays: ["day_wed"],
    }),
  );

  assert.equal(findSession(sessions, "w1-tue-tempo").date, "2026-04-30");
  assert.equal(findSession(sessions, "w1-wed-easy").date, "2026-04-29");
});

Deno.test("placeLongRunsOnPreferredDay swaps long run onto preferred day", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-01");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-03");
  assert.match(
    findSession(sessions, "w1-sun-long").coachNote ?? "",
    /preferred long run day/i,
  );
});

Deno.test("placeLongRunsOnPreferredDay skips preferred day when it is hard", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ hardDays: ["day_fri"], longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-01");
});

Deno.test("placeLongRunsOnPreferredDay does not swap with hard workout", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({
        id: "w1-fri-tempo",
        date: "2026-05-01",
        type: "tempoRun",
      }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-tempo").date, "2026-05-01");
});

Deno.test("placeLongRunsOnPreferredDay preserves fixed race date", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "race", date: "2026-05-03", type: "racePaceRun" }),
    ],
    profile({
      longRunDay: "day_fri",
      raceDate: "2026-05-03T00:00:00.000",
    }),
  );

  assert.equal(findSession(sessions, "race").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-01");
});

function profile({
  experience = "experience_beginner",
  hardDays = [],
  longRunDay = null,
  raceDate = null,
  trainingDays = null,
}: {
  experience?: string;
  hardDays?: string[];
  longRunDay?: string | null;
  raceDate?: string | null;
  trainingDays?: number | null;
} = {}): Record<string, unknown> {
  return {
    goal: { raceDate },
    fitness: { experience },
    schedule: { hardDays, longRunDay, trainingDays },
  };
}

function findSession(
  sessions: GeneratedSession[],
  id: string,
): GeneratedSession {
  const found = sessions.find((item) => item.id === id);
  assert.ok(found, `Expected session ${id} to exist`);
  return found;
}

function trainingDayCount(sessions: GeneratedSession[]): number {
  return sessions.filter((item) => item.type !== "restDay").length;
}

function stressDayCount(sessions: GeneratedSession[]): number {
  const stressfulTypes = new Set([
    "longRun",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "tempoRun",
    "thresholdRun",
    "racePaceRun",
  ]);
  return sessions.filter((item) => stressfulTypes.has(item.type)).length;
}

function strideCount(sessions: GeneratedSession[]): number {
  return sessions.filter((item) =>
    (item.strideReps ?? 0) > 0 && (item.strideSeconds ?? 0) > 0
  ).length;
}

function session(
  overrides: Partial<GeneratedSession> & Pick<GeneratedSession, "id" | "date">,
): GeneratedSession {
  return {
    id: overrides.id,
    date: overrides.date,
    weekNumber: overrides.weekNumber ?? 1,
    type: overrides.type ?? "easyRun",
    distanceKm: overrides.distanceKm ?? 5,
    durationMinutes: overrides.durationMinutes ?? 35,
    coachNote: overrides.coachNote ?? null,
    targetZone: overrides.targetZone ?? "easy",
    warmUpMinutes: overrides.warmUpMinutes ?? null,
    coolDownMinutes: overrides.coolDownMinutes ?? null,
    intervalReps: overrides.intervalReps ?? null,
    intervalRepDistanceMeters: overrides.intervalRepDistanceMeters ?? null,
    intervalRecoverySeconds: overrides.intervalRecoverySeconds ?? null,
    strideReps: overrides.strideReps ?? null,
    strideSeconds: overrides.strideSeconds ?? null,
    strideRecoverySeconds: overrides.strideRecoverySeconds ?? null,
  };
}
