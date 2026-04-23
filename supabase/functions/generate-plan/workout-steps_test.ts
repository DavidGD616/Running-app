import { strict as assert } from "node:assert";
import { buildWorkoutSteps } from "./workout-steps.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("buildWorkoutSteps uses full race distance for goal race session", () => {
  const steps = buildWorkoutSteps(
    {
      id: "w8-sat",
      date: "2026-06-20",
      weekNumber: 8,
      type: "racePaceRun",
      distanceKm: 5,
      durationMinutes: null,
      coachNote: "Goal race day.",
      targetZone: "racePace",
      warmUpMinutes: 10,
      coolDownMinutes: 5,
      intervalReps: null,
      intervalRepDistanceMeters: null,
      intervalRecoverySeconds: null,
      strideReps: null,
      strideSeconds: null,
      strideRecoverySeconds: null,
    } satisfies GeneratedSession,
  );

  assert.equal(steps[0].kind, "warmUp");
  assert.equal(steps[0].durationMs, 600_000);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].distanceMeters, 5000);
  assert.equal(steps[1].durationMs, null);
  assert.equal(steps[2].kind, "coolDown");
  assert.equal(steps[2].durationMs, 300_000);
});
