import { strict as assert } from "node:assert";
import { buildWorkoutSteps } from "./workout-steps.ts";
import type { GeneratedSession } from "./schema.ts";

const VALID_ZONES = new Set([
  "recovery",
  "easy",
  "steady",
  "tempo",
  "threshold",
  "interval",
  "racePace",
  "longRun",
]);

const PAZE_ZONE_FIXTURE = {
  recovery: { paceMinSecPerKm: 460, paceMaxSecPerKm: 520 },
  easy: { paceMinSecPerKm: 380, paceMaxSecPerKm: 420 },
  longRun: { paceMinSecPerKm: 360, paceMaxSecPerKm: 430 },
  steady: { paceMinSecPerKm: 340, paceMaxSecPerKm: 390 },
  tempo: { paceMinSecPerKm: 300, paceMaxSecPerKm: 340 },
  threshold: { paceMinSecPerKm: 280, paceMaxSecPerKm: 310 },
  racePace: { paceMinSecPerKm: 270, paceMaxSecPerKm: 300 },
  intervals: { paceMinSecPerKm: 260, paceMaxSecPerKm: 290 },
  strides: { paceMinSecPerKm: 240, paceMaxSecPerKm: 260 },
};

Deno.test("buildWorkoutSteps returns no workout steps for rest day", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "rest",
    date: "2026-06-20",
    type: "restDay",
    durationMinutes: 40,
  }));

  assert.equal(steps.length, 0);
});

Deno.test("buildWorkoutSteps returns no workout steps for race day", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "race",
    date: "2026-06-20",
    type: "raceDay",
    durationMinutes: 40,
    targetZone: "racePace",
  }));

  assert.equal(steps.length, 0);
});

Deno.test("buildWorkoutSteps builds easy run as warm-up, work, and cool-down", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "easy",
    date: "2026-06-20",
    type: "easyRun",
    durationMinutes: 50,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    targetZone: "easy",
    distanceKm: 8,
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[0].kind, "warmUp");
  assert.equal(steps[0].durationMs, 600_000);
  assert.equal(steps[0].target?.zone, "easy");
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "easy");
  assert.equal(steps[1].durationMs, 35 * 60_000);
  assert.equal(steps[2].kind, "coolDown");
  assert.equal(steps[2].durationMs, 300_000);
});

Deno.test("buildWorkoutSteps builds recovery run as warm-up, work, and cool-down", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "recovery",
    date: "2026-06-20",
    type: "recoveryRun",
    durationMinutes: 40,
    warmUpMinutes: 5,
    coolDownMinutes: 5,
    targetZone: "recovery",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[0].kind, "warmUp");
  assert.equal(steps[0].durationMs, 300_000);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "recovery");
  assert.equal(steps[2].kind, "coolDown");
  assert.equal(steps[2].durationMs, 300_000);
});

Deno.test("buildWorkoutSteps builds long run as warm-up, work, and cool-down", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "long",
    date: "2026-06-20",
    type: "longRun",
    durationMinutes: 80,
    warmUpMinutes: 10,
    coolDownMinutes: 10,
    targetZone: "longRun",
    distanceKm: 16,
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[0].kind, "warmUp");
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "longRun");
  assert.equal(steps[1].durationMs, 60 * 60_000);
  assert.equal(steps[2].kind, "coolDown");
});

Deno.test("buildWorkoutSteps builds progressionRun blocks in easy, steady, tempo order", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "progression",
    date: "2026-06-20",
    type: "progressionRun",
    durationMinutes: 45,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    distanceKm: 12,
    targetZone: "steady",
  }));

  assert.equal(steps.length, 5);
  assert.equal(steps[1].target?.zone, "easy");
  assert.equal(steps[2].target?.zone, "steady");
  assert.equal(steps[3].target?.zone, "tempo");
  assert.equal(steps[1].durationMs, 10 * 60_000);
  assert.equal(steps[2].durationMs, 10 * 60_000);
  assert.equal(steps[3].durationMs, 10 * 60_000);
});

Deno.test("buildWorkoutSteps preserves progression distance split when duration is missing", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "progression-distance",
    date: "2026-06-20",
    type: "progressionRun",
    durationMinutes: null,
    distanceKm: 9,
    targetZone: "steady",
    warmUpMinutes: null,
    coolDownMinutes: null,
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[0].durationMs, null);
  assert.equal(steps[1].durationMs, null);
  assert.equal(steps[2].durationMs, null);
  assert.equal(steps[0].distanceMeters, 3000);
  assert.equal(steps[1].distanceMeters, 3000);
  assert.equal(steps[2].distanceMeters, 3000);
  assert.equal(steps[0].target?.zone, "easy");
  assert.equal(steps[1].target?.zone, "steady");
  assert.equal(steps[2].target?.zone, "tempo");
});

Deno.test("buildWorkoutSteps keeps short duration progression blocks runnable", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "progression-short",
    date: "2026-06-20",
    type: "progressionRun",
    durationMinutes: 2,
    warmUpMinutes: null,
    coolDownMinutes: null,
    targetZone: "steady",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[0].durationMs, 60_000);
  assert.equal(steps[1].durationMs, 60_000);
  assert.equal(steps[2].durationMs, 60_000);
});

Deno.test("buildWorkoutSteps builds tempo run with focused quality block", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "tempo",
    date: "2026-06-20",
    type: "tempoRun",
    durationMinutes: 45,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    targetZone: "tempo",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "tempo");
  assert.equal(steps[1].durationMs, 30 * 60_000);
});

Deno.test("buildWorkoutSteps builds threshold run with focused quality block", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "threshold",
    date: "2026-06-20",
    type: "thresholdRun",
    durationMinutes: 45,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    targetZone: "threshold",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "threshold");
  assert.equal(steps[1].durationMs, 30 * 60_000);
});

Deno.test("buildWorkoutSteps builds race-pace run with focused quality block", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "race-pace",
    date: "2026-06-20",
    type: "racePaceRun",
    durationMinutes: null,
    distanceKm: 5,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    targetZone: "racePace",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "racePace");
  assert.equal(steps[1].durationMs, null);
  assert.equal(steps[1].distanceMeters, 5000);
});

Deno.test("buildWorkoutSteps preserves interval repeat behavior", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "intervals",
    date: "2026-06-20",
    type: "intervals",
    durationMinutes: 60,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    intervalReps: 4,
    intervalRepDistanceMeters: 400,
    intervalRecoverySeconds: 75,
    targetZone: "threshold",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "repeat");
  assert.equal(steps[1].repetitions, 4);
  assert.equal(steps[1].steps?.[0].kind, "work");
  assert.equal(steps[1].steps?.[0].distanceMeters, 400);
  assert.equal(steps[1].steps?.[0].target?.zone, "threshold");
  assert.equal(steps[1].steps?.[1].kind, "recovery");
  assert.equal(steps[1].steps?.[1].durationMs, 75_000);
});

Deno.test(
  "buildWorkoutSteps maps interval target zone to pace zone intervals when available",
  () => {
    const steps = buildWorkoutSteps(
      baseSession({
        id: "intervals-default-zone",
        date: "2026-06-20",
        type: "intervals",
        durationMinutes: 60,
        warmUpMinutes: 10,
        coolDownMinutes: 5,
        intervalReps: 4,
        intervalRepDistanceMeters: 400,
        intervalRecoverySeconds: 75,
      }),
      PAZE_ZONE_FIXTURE,
    );

    const intervalBlock = steps[1];
    const workStep = intervalBlock.steps?.[0];

    assert.equal(intervalBlock.kind, "repeat");
    assert.equal(workStep?.kind, "work");
    assert.equal(workStep?.target?.zone, "interval");
    assert.equal(workStep?.target?.paceMinSecPerKm, 260);
    assert.equal(workStep?.target?.paceMaxSecPerKm, 290);
  },
);

Deno.test("buildWorkoutSteps builds hill repeats as structured block when interval metadata is missing", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "hills",
    date: "2026-06-20",
    type: "hillRepeats",
    durationMinutes: 45,
    warmUpMinutes: 10,
    coolDownMinutes: 5,
    targetZone: "threshold",
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "threshold");
  assert.equal(steps[1].durationMs, 30 * 60_000);
});

Deno.test("buildWorkoutSteps preserves hill repeats repeat/recovery structure with interval metadata", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "hills-intervals",
    date: "2026-06-20",
    type: "hillRepeats",
    durationMinutes: 45,
    intervalReps: 6,
    intervalRepDistanceMeters: 120,
    intervalRecoverySeconds: 60,
    targetZone: "threshold",
  }));

  assert.equal(steps.length, 1);
  assert.equal(steps[0].kind, "repeat");
  assert.equal(steps[0].repetitions, 6);
  assert.equal(steps[0].steps?.[0].distanceMeters, 120);
});

Deno.test("buildWorkoutSteps builds fartlek as structured block when interval metadata is missing", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "fartlek",
    date: "2026-06-20",
    type: "fartlek",
    durationMinutes: 50,
    targetZone: "tempo",
    warmUpMinutes: 8,
    coolDownMinutes: 8,
  }));

  assert.equal(steps.length, 3);
  assert.equal(steps[1].kind, "work");
  assert.equal(steps[1].target?.zone, "tempo");
  assert.equal(steps[1].durationMs, 34 * 60_000);
});

Deno.test("buildWorkoutSteps preserves fartlek repeat/recovery structure with interval metadata", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "fartlek-intervals",
    date: "2026-06-20",
    type: "fartlek",
    durationMinutes: 50,
    intervalReps: 5,
    intervalRepDistanceMeters: 200,
    intervalRecoverySeconds: 90,
    targetZone: "tempo",
  }));

  assert.equal(steps.length, 1);
  assert.equal(steps[0].kind, "repeat");
  assert.equal(steps[0].repetitions, 5);
  assert.equal(steps[0].steps?.[1].durationMs, 90_000);
});

Deno.test("buildWorkoutSteps appends stride blocks when stride metadata exists", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "strides",
    date: "2026-06-20",
    type: "easyRun",
    strideReps: 6,
    strideSeconds: 20,
    strideRecoverySeconds: 80,
  }));

  assert.equal(steps[1].kind, "repeat");
  assert.equal(steps[1].steps?.[0].kind, "stride");
  assert.equal(steps[1].steps?.[0].durationMs, 20_000);
  assert.equal(steps[1].steps?.[1].kind, "recovery");
  assert.equal(steps[1].steps?.[1].durationMs, 80_000);
});

Deno.test("buildWorkoutSteps includes effort target metadata on generated steps", () => {
  const steps = buildWorkoutSteps(baseSession({
    id: "metadata",
    date: "2026-06-20",
    type: "tempoRun",
    targetZone: "tempo",
    strideReps: 6,
    strideSeconds: 20,
    strideRecoverySeconds: 80,
    durationMinutes: 45,
    warmUpMinutes: 5,
    coolDownMinutes: 5,
  }));

  assertTargetsHaveMetadata(steps);
});

Deno.test("buildWorkoutSteps hydrates target paces from generated pace zones", () => {
  const steps = buildWorkoutSteps(
    baseSession({
      id: "hydrated",
      date: "2026-06-20",
      type: "easyRun",
      warmUpMinutes: 10,
      coolDownMinutes: 5,
      targetZone: "easy",
      durationMinutes: 50,
      distanceKm: 8,
    }),
    PAZE_ZONE_FIXTURE,
  );

  assert.equal(steps[0].target?.zone, "easy");
  assert.equal(steps[0].target?.paceMinSecPerKm, 380);
  assert.equal(steps[0].target?.paceMaxSecPerKm, 420);
  assert.equal(steps[1].target?.zone, "easy");
  assert.equal(steps[1].target?.paceMinSecPerKm, 380);
  assert.equal(steps[1].target?.paceMaxSecPerKm, 420);
  assert.equal(steps[2].target?.zone, "easy");
  assert.equal(steps[2].target?.paceMinSecPerKm, 380);
  assert.equal(steps[2].target?.paceMaxSecPerKm, 420);
});

Deno.test(
  "buildWorkoutSteps applies stride-specific pace ranges when pace zones are provided",
  () => {
    const steps = buildWorkoutSteps(
      baseSession({
        id: "strides-zones",
        date: "2026-06-20",
        type: "easyRun",
        strideReps: 6,
        strideSeconds: 20,
        strideRecoverySeconds: 80,
        targetZone: "easy",
      }),
      PAZE_ZONE_FIXTURE,
    );

    const strideBlock = steps[1];
    const strideStep = strideBlock.steps?.[0];
    const strideRecovery = strideBlock.steps?.[1];

    assert.equal(strideBlock.kind, "repeat");
    assert.equal(strideStep?.kind, "stride");
    assert.equal(strideStep?.target?.zone, "interval");
    assert.equal(strideStep?.target?.paceMinSecPerKm, 240);
    assert.equal(strideStep?.target?.paceMaxSecPerKm, 260);
    assert.equal(strideRecovery?.target?.zone, "recovery");
    assert.equal(strideRecovery?.target?.paceMinSecPerKm, 460);
  },
);

Deno.test(
  "buildWorkoutSteps does not add pace ranges when no pace zones are provided",
  () => {
    const steps = buildWorkoutSteps(
      baseSession({
        id: "no-hydration",
        date: "2026-06-20",
        type: "tempoRun",
        targetZone: "tempo",
        warmUpMinutes: 5,
        coolDownMinutes: 5,
      }),
    );

    assert.equal(steps[0].target?.paceMinSecPerKm, undefined);
    assert.equal(steps[0].target?.paceMaxSecPerKm, undefined);
    assert.equal(steps[1].target?.paceMinSecPerKm, undefined);
    assert.equal(steps[1].target?.paceMaxSecPerKm, undefined);
    assert.equal(steps[2].target?.paceMinSecPerKm, undefined);
    assert.equal(steps[2].target?.paceMaxSecPerKm, undefined);
  },
);

type TestStep = {
  kind: string;
  target?: { type: string; zone: string } | null;
  steps?: TestStep[];
};

function assertTargetsHaveMetadata(steps: TestStep[]): void {
  for (const step of steps) {
    if (step.target != null) {
      assert.equal(step.target.type, "effort");
      assert.ok(VALID_ZONES.has(step.target.zone));
    }
    if (step.kind === "repeat" && step.steps != null) {
      assertTargetsHaveMetadata(step.steps);
    }
  }
}

function baseSession(
  overrides:
    & Partial<GeneratedSession>
    & Pick<GeneratedSession, "id" | "date" | "type">,
): GeneratedSession {
  return {
    id: overrides.id,
    date: overrides.date,
    weekNumber: overrides.weekNumber ?? 1,
    type: overrides.type,
    distanceKm: overrides.distanceKm ?? null,
    durationMinutes: "durationMinutes" in overrides
      ? overrides.durationMinutes ?? null
      : 35,
    coachNote: overrides.coachNote ?? null,
    targetZone: overrides.targetZone ?? null,
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
