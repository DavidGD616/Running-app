import { strict as assert } from "node:assert";
import type {
  GeneratedSession,
  TargetedSessionRepairPatchResponse,
} from "./schema.ts";
import {
  type RepairPolicyViolationsResultFailure,
  type RepairPolicyViolationsResultSuccess,
  repairPolicyViolationsWithOpenAiPatches,
} from "./repair-loop.ts";

const EASY_RUN_TARGET = {
  schemaVersion: 1,
  type: "pace" as const,
  zone: "easy" as const,
  paceMinSecPerKm: 420,
  paceMaxSecPerKm: 480,
  effortCue: "easy effort",
};

const LONG_RUN_TARGET = {
  schemaVersion: 1,
  type: "pace" as const,
  zone: "longRun" as const,
  paceMinSecPerKm: 480,
  paceMaxSecPerKm: 560,
  effortCue: "long slow",
};

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
    coachNote: overrides.coachNote ?? "Base plan note",
    targetZone: overrides.targetZone ?? "easy",
    phase: overrides.phase,
    warmUpMinutes: overrides.warmUpMinutes ?? null,
    coolDownMinutes: overrides.coolDownMinutes ?? null,
    intervalReps: overrides.intervalReps ?? null,
    intervalRepDistanceMeters: overrides.intervalRepDistanceMeters ?? null,
    intervalRecoverySeconds: overrides.intervalRecoverySeconds ?? null,
    strideReps: overrides.strideReps ?? null,
    strideSeconds: overrides.strideSeconds ?? null,
    strideRecoverySeconds: overrides.strideRecoverySeconds ?? null,
    workoutTarget: overrides.workoutTarget ?? EASY_RUN_TARGET,
  };
}

const baseProfile: Record<string, unknown> = {
  goal: { race: "race_half_marathon", hasRaceDate: false, raceDate: null },
  fitness: { experience: "experience_intermediate" },
};

Deno.test(
  "repair loop preserves accepted repairs and retries only remaining violations",
  async () => {
    const calls: Array<{
      attempt: number;
      requestIds: string[];
    }> = [];
    const repairFn = (
      _profileData: Record<string, unknown>,
      _totalWeeks: number,
      sessionsNeedingRepair: readonly GeneratedSession[],
      _violations: readonly unknown[],
      _locale: "en" | "es",
      _coachingBrief: unknown,
      _priorFailureReasons: Record<string, string>,
    ): Promise<TargetedSessionRepairPatchResponse> => {
      const call = calls.length + 1;
      calls.push({
        attempt: call,
        requestIds: sessionsNeedingRepair.map((session) => session.id),
      });

      if (call === 1) {
        return Promise.resolve({
          schemaVersion: 1,
          repairs: [
            {
              sessionId: "s1",
              type: "fartlek",
              coachNote: "Set this first run as a relaxed fartlek session.",
              workoutTarget: EASY_RUN_TARGET,
              distanceKm: 6,
            },
            {
              sessionId: "s2",
              type: "easyRun",
              coachNote: "Make this an easy recovery run.",
              workoutTarget: EASY_RUN_TARGET,
              distanceKm: 5,
            },
          ],
        });
      }

      return Promise.resolve({
        schemaVersion: 1,
        repairs: [{
          sessionId: "s3",
          type: "longRun",
          coachNote: "Keep this run long and easy.",
          workoutTarget: LONG_RUN_TARGET,
          distanceKm: 10,
        }],
      });
    };

    const initialSessions = [
      session({
        id: "s1",
        date: "2026-01-01",
        type: "intervals",
        weekNumber: 1,
      }),
      session({
        id: "s2",
        date: "2026-01-02",
        type: "thresholdRun",
        weekNumber: 2,
      }),
      session({
        id: "s3",
        date: "2026-01-03",
        type: "tempoRun",
        weekNumber: 2,
      }),
      session({
        id: "ok-1",
        date: "2026-01-04",
        type: "easyRun",
        weekNumber: 1,
      }),
      session({
        id: "ok-2",
        date: "2026-01-05",
        type: "recoveryRun",
        weekNumber: 1,
      }),
      session({
        id: "ok-3",
        date: "2026-01-06",
        type: "longRun",
        weekNumber: 1,
      }),
      session({
        id: "ok-4",
        date: "2026-01-07",
        type: "easyRun",
        weekNumber: 1,
      }),
      session({
        id: "ok-5",
        date: "2026-01-08",
        type: "recoveryRun",
        weekNumber: 2,
      }),
      session({
        id: "ok-6",
        date: "2026-01-04",
        type: "easyRun",
        coachNote: "Already compliant",
      }),
    ];

    const result = await repairPolicyViolationsWithOpenAiPatches(
      initialSessions,
      baseProfile,
      8,
      "en",
      null,
      3,
      repairFn,
    ) as RepairPolicyViolationsResultSuccess;

    assert.equal(result.ok, true);
    assert.equal(result.attempts, 2);
    assert.deepEqual(result.acceptedSessionIds, ["s1", "s2", "s3"]);
    assert.deepEqual(
      calls[0].requestIds,
      ["s1", "s2", "s3"],
    );
    assert.deepEqual(calls[1].requestIds, ["s3"]);
    const finalById = new Map(
      result.sessions.map((item) => [item.id, item]),
    );
    assert.equal(finalById.get("s1")?.type, "fartlek");
    assert.equal(finalById.get("s2")?.type, "easyRun");
    assert.equal(finalById.get("s3")?.type, "longRun");
  },
);

Deno.test(
  "repair loop succeeds when final attempt fixes remaining violation despite extra patch rejection",
  async () => {
    const repairFn = (
      _profileData: Record<string, unknown>,
      _totalWeeks: number,
      _sessionsNeedingRepair: readonly GeneratedSession[],
      _violations: readonly unknown[],
      _locale: "en" | "es",
      _coachingBrief: unknown,
      _priorFailureReasons: Record<string, string>,
    ): Promise<TargetedSessionRepairPatchResponse> => {
      assert.equal(_priorFailureReasons.bad, undefined);
      return Promise.resolve({
        schemaVersion: 1,
        repairs: [
          {
            sessionId: "bad",
            type: "fartlek",
            coachNote: "Final-pass fix with compliant details.",
            workoutTarget: EASY_RUN_TARGET,
            distanceKm: 7,
          },
          {
            sessionId: "extra",
            type: "fartlek",
            coachNote: "This session was never requested.",
            workoutTarget: EASY_RUN_TARGET,
            distanceKm: 6,
          },
        ],
      });
    };

    const result = await repairPolicyViolationsWithOpenAiPatches(
      [
        session({
          id: "bad",
          date: "2026-01-01",
          type: "thresholdRun",
          weekNumber: 1,
        }),
      ],
      baseProfile,
      8,
      "en",
      null,
      1,
      repairFn,
    ) as RepairPolicyViolationsResultSuccess;

    assert.equal(result.ok, true);
    assert.equal(result.attempts, 1);
    assert.deepEqual(result.acceptedSessionIds, ["bad"]);
    const repaired = result.sessions.find((item) => item.id === "bad");
    assert.equal(repaired?.type, "fartlek");
  },
);

Deno.test(
  "repair loop returns failure after max attempts when patches stay invalid",
  async () => {
    const repairFn = (
      _profileData: Record<string, unknown>,
      _totalWeeks: number,
      _sessionsNeedingRepair: readonly GeneratedSession[],
      _violations: readonly unknown[],
      _locale: "en" | "es",
      _coachingBrief: unknown,
      _priorFailureReasons: Record<string, string>,
    ): Promise<TargetedSessionRepairPatchResponse> => {
      return Promise.resolve({
        schemaVersion: 1,
        repairs: [{
          sessionId: "bad",
          type: "intervals",
          coachNote: "Adjusting interval work for this slot.",
          workoutTarget: EASY_RUN_TARGET,
          distanceKm: 5,
        }],
      });
    };

    const failureResult = await repairPolicyViolationsWithOpenAiPatches(
      [
        session({
          id: "bad",
          date: "2026-01-01",
          type: "thresholdRun",
          weekNumber: 1,
          coachNote: "Original coaching note",
        }),
      ],
      baseProfile,
      8,
      "en",
      null,
      2,
      repairFn,
    ) as RepairPolicyViolationsResultFailure;

    assert.equal(failureResult.ok, false);
    assert.equal(failureResult.attempts, 2);
    assert.equal(failureResult.remainingViolations.length, 1);
    assert.equal(failureResult.remainingViolations[0].sessionId, "bad");
    assert.equal(failureResult.repairFailures[0].sessionId, "bad");
    assert.equal(
      failureResult.repairFailures[0].reason.includes("not allowed"),
      true,
    );
    const badSession = failureResult.sessions.find((item) => item.id === "bad");
    assert.equal(badSession?.coachNote, "Original coaching note");
    assert.equal(badSession?.type, "thresholdRun");
  },
);

Deno.test(
  "repair loop retries after error and uses prior failure reasons",
  async () => {
    const calls: Array<{ priorFailureReasons: Record<string, string> }> = [];
    const repairFn = (
      _profileData: Record<string, unknown>,
      _totalWeeks: number,
      _sessionsNeedingRepair: readonly GeneratedSession[],
      _violations: readonly unknown[],
      _locale: "en" | "es",
      _coachingBrief: unknown,
      priorFailureReasons: Record<string, string>,
    ): Promise<TargetedSessionRepairPatchResponse> => {
      calls.push({ priorFailureReasons: { ...priorFailureReasons } });
      if (calls.length === 1) {
        throw new Error("Transient API failure");
      }

      return Promise.resolve({
        schemaVersion: 1,
        repairs: [{
          sessionId: "retry",
          type: "fartlek",
          coachNote: "Recovered from API error and fixed this run.",
          workoutTarget: EASY_RUN_TARGET,
          distanceKm: 6,
        }],
      });
    };

    const result = await repairPolicyViolationsWithOpenAiPatches(
      [
        session({
          id: "retry",
          date: "2026-01-01",
          type: "tempoRun",
          weekNumber: 1,
        }),
      ],
      baseProfile,
      8,
      "en",
      null,
      3,
      repairFn,
    ) as RepairPolicyViolationsResultSuccess;

    assert.equal(result.ok, true);
    assert.equal(result.attempts, 2);
    assert.equal(calls.length, 2);
    assert.equal(
      calls[1].priorFailureReasons.retry?.includes("Transient API failure"),
      true,
    );
    const repaired = result.sessions.find((item) => item.id === "retry");
    assert.equal(repaired?.type, "fartlek");
  },
);
