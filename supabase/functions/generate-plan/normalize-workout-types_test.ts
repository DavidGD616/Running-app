import { strict as assert } from "node:assert";
import { normalizeWorkoutTypesByPhase } from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("normalizeWorkoutTypesByPhase downgrades early base-phase intervals for beginner to easyRun", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w1-mon",
      date: "2026-04-27",
      weekNumber: 1,
      type: "intervals",
    }),
    session({
      id: "w1-wed",
      date: "2026-04-29",
      weekNumber: 1,
      type: "tempoRun",
    }),
    session({
      id: "w1-sat",
      date: "2026-05-02",
      weekNumber: 1,
      type: "longRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_beginner", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w1-mon").type, "easyRun");
  assert.equal(findSession(result, "w1-wed").type, "easyRun");
  assert.equal(findSession(result, "w1-sat").type, "longRun");
});

Deno.test("normalizeWorkoutTypesByPhase downgrades early base-phase intervals for intermediate to fartlek", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w1-mon",
      date: "2026-04-27",
      weekNumber: 1,
      type: "intervals",
    }),
    session({
      id: "w2-mon",
      date: "2026-05-04",
      weekNumber: 2,
      type: "thresholdRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w1-mon").type, "fartlek");
  assert.equal(findSession(result, "w2-mon").type, "fartlek");
});

Deno.test("normalizeWorkoutTypesByPhase keeps race-specific work only in specific/peak phases", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w2-thu",
      date: "2026-05-07",
      weekNumber: 2,
      type: "intervals",
    }),
    session({
      id: "w3-thu",
      date: "2026-05-14",
      weekNumber: 3,
      type: "racePaceRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w2-thu").type, "fartlek");
  assert.equal(findSession(result, "w3-thu").type, "fartlek");
});

Deno.test("normalizeWorkoutTypesByPhase allows race-specific work in specific phase", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w7-thu",
      date: "2026-06-11",
      weekNumber: 7,
      type: "intervals",
    }),
    session({
      id: "w7-sat",
      date: "2026-06-13",
      weekNumber: 7,
      type: "racePaceRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w7-thu").type, "intervals");
  assert.equal(findSession(result, "w7-sat").type, "racePaceRun");
});

Deno.test("normalizeWorkoutTypesByPhase allows race-specific work in peak phase", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w10-thu",
      date: "2026-07-02",
      weekNumber: 10,
      type: "intervals",
    }),
    session({
      id: "w10-sat",
      date: "2026-07-04",
      weekNumber: 10,
      type: "racePaceRun",
    }),
    session({
      id: "w10-fri",
      date: "2026-07-03",
      weekNumber: 10,
      type: "thresholdRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_experienced", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w10-thu").type, "intervals");
  assert.equal(findSession(result, "w10-sat").type, "racePaceRun");
  assert.equal(findSession(result, "w10-fri").type, "thresholdRun");
});

Deno.test("normalizeWorkoutTypesByPhase downgrades heavy workouts in taper phase", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w11-wed",
      date: "2026-07-08",
      weekNumber: 11,
      type: "intervals",
    }),
    session({
      id: "w11-fri",
      date: "2026-07-10",
      weekNumber: 11,
      type: "tempoRun",
    }),
    session({
      id: "w11-sat",
      date: "2026-07-11",
      weekNumber: 11,
      type: "longRun",
    }),
    session({
      id: "w12-sat",
      date: "2026-07-18",
      weekNumber: 12,
      type: "racePaceRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w11-wed").type, "fartlek");
  assert.equal(findSession(result, "w11-fri").type, "fartlek");
  assert.equal(findSession(result, "w11-sat").type, "longRun");
  assert.equal(findSession(result, "w12-sat").type, "racePaceRun");
});

Deno.test("normalizeWorkoutTypesByPhase taper phase keeps easy runs and recovery", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w11-mon",
      date: "2026-07-06",
      weekNumber: 11,
      type: "easyRun",
    }),
    session({
      id: "w11-tue",
      date: "2026-07-07",
      weekNumber: 11,
      type: "recoveryRun",
    }),
    session({
      id: "w12-fri",
      date: "2026-07-17",
      weekNumber: 12,
      type: "fartlek",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w11-mon").type, "easyRun");
  assert.equal(findSession(result, "w11-tue").type, "recoveryRun");
  assert.equal(findSession(result, "w12-fri").type, "fartlek");
});

Deno.test("normalizeWorkoutTypesByPhase taper phase downgrades hillRepeats near race", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w11-thu",
      date: "2026-07-09",
      weekNumber: 11,
      type: "hillRepeats",
    }),
    session({
      id: "w12-sat",
      date: "2026-07-18",
      weekNumber: 12,
      type: "racePaceRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_experienced", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w11-thu").type, "fartlek");
  assert.equal(findSession(result, "w12-sat").type, "racePaceRun");
});

Deno.test("normalizeWorkoutTypesByPhase does not change sessions already matching policy", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w4-mon",
      date: "2026-05-18",
      weekNumber: 4,
      type: "easyRun",
    }),
    session({
      id: "w4-sat",
      date: "2026-05-23",
      weekNumber: 4,
      type: "longRun",
    }),
    session({
      id: "w4-thu",
      date: "2026-05-21",
      weekNumber: 4,
      type: "fartlek",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w4-mon").type, "easyRun");
  assert.equal(findSession(result, "w4-sat").type, "longRun");
  assert.equal(findSession(result, "w4-thu").type, "fartlek");
});

Deno.test("normalizeWorkoutTypesByPhase preserves goal race session", () => {
  const sessions: GeneratedSession[] = [
    session({
      id: "w12-sat",
      date: "2026-07-18",
      weekNumber: 12,
      type: "racePaceRun",
      distanceKm: 10,
    }),
    session({
      id: "w11-thu",
      date: "2026-07-09",
      weekNumber: 11,
      type: "thresholdRun",
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    profile({
      experience: "experience_experienced",
      race: "race_10k",
      raceDate: "2026-07-18T00:00:00.000",
    }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w12-sat").type, "racePaceRun");
  assert.equal(findSession(result, "w11-thu").type, "fartlek");
});

function profile({
  experience = "experience_beginner",
  hardDays = [],
  longRunDay = null,
  race = "race_5k",
  raceDate = null,
  trainingDays = null,
}: {
  experience?: string;
  hardDays?: string[];
  longRunDay?: string | null;
  race?: string;
  raceDate?: string | null;
  trainingDays?: number | null;
} = {}): Record<string, unknown> {
  return {
    goal: { race, raceDate },
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
