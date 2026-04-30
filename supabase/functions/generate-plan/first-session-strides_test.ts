import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  normalizeFirstPlannedSession,
} from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("first normalized easy session does not receive default strides", () => {
  const profileData = profile({ experience: "experience_intermediate" });
  const normalized = normalizeFirstPlannedSession(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
    ],
    profileData,
  );

  const sessions = addStrideDefaults(normalized, profileData, 6);

  const first = findSession(sessions, "w1-mon-intervals");
  assert.equal(first.type, "easyRun");
  assert.equal(first.strideReps, null);
  assert.equal(first.strideSeconds, null);
  assert.equal(first.strideRecoverySeconds, null);
  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-wed-easy").strideReps, 4);
  assert.equal(findSession(sessions, "w1-fri-easy").strideReps, 4);
});

Deno.test("first recovery session with existing strides is stripped while later strides remain", () => {
  const profileData = profile({ experience: "experience_experienced" });

  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon-recovery",
        date: "2026-04-27",
        type: "recoveryRun",
        targetZone: "recovery",
        strideReps: 6,
        strideSeconds: 20,
        strideRecoverySeconds: 80,
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
    ],
    profileData,
    6,
  );

  const first = findSession(sessions, "w1-mon-recovery");
  assert.equal(first.strideReps, null);
  assert.equal(first.strideSeconds, null);
  assert.equal(first.strideRecoverySeconds, null);
  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-wed-easy").strideReps, 6);
  assert.equal(findSession(sessions, "w1-fri-easy").strideReps, 6);
});

Deno.test("fixed goal race date remains locked while first planned training is protected", () => {
  const profileData = profile({
    experience: "experience_intermediate",
    raceDate: "2026-04-27T00:00:00.000",
  });

  const normalized = normalizeFirstPlannedSession(
    [
      session({
        id: "race",
        date: "2026-04-27",
        type: "racePaceRun",
        targetZone: "racePace",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
    ],
    profileData,
  );
  const sessions = addStrideDefaults(normalized, profileData, 6);

  const race = findSession(sessions, "race");
  assert.equal(race.date, "2026-04-27");
  assert.equal(race.type, "racePaceRun");
  assert.equal(findSession(sessions, "w1-wed-easy").strideReps, null);
});

function profile({
  experience,
  raceDate = null,
}: {
  experience: string;
  raceDate?: string | null;
}): Record<string, unknown> {
  return {
    goal: { race: "race_5k", raceDate },
    fitness: { experience },
    schedule: { hardDays: [], longRunDay: null, trainingDays: null },
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
