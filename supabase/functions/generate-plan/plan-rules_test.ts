import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  normalizeTrainingDayCount,
} from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("addStrideDefaults adds week 1 strides for intermediate runners", () => {
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

Deno.test("addStrideDefaults adds larger week 1 strides for experienced runners", () => {
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

function profile({
  experience = "experience_beginner",
  hardDays = [],
  raceDate = null,
  trainingDays = null,
}: {
  experience?: string;
  hardDays?: string[];
  raceDate?: string | null;
  trainingDays?: number | null;
} = {}): Record<string, unknown> {
  return {
    goal: { raceDate },
    fitness: { experience },
    schedule: { hardDays, trainingDays },
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
