import { strict as assert } from "node:assert";
import { normalizeWeeklyVolumeRamp } from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

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

// Two training sessions per week: one easy + one long. Distances chosen so the
// per-week total is easy to reason about.
function week(
  weekNumber: number,
  easyKm: number,
  longKm: number,
): GeneratedSession[] {
  const baseDate = new Date(Date.UTC(2026, 0, 5)); // Monday 2026-01-05.
  baseDate.setUTCDate(baseDate.getUTCDate() + (weekNumber - 1) * 7);
  const monday = baseDate.toISOString().slice(0, 10);
  const saturdayDate = new Date(baseDate);
  saturdayDate.setUTCDate(baseDate.getUTCDate() + 5);
  const saturday = saturdayDate.toISOString().slice(0, 10);
  return [
    session({
      id: `w${weekNumber}-easy`,
      date: monday,
      weekNumber,
      type: "easyRun",
      distanceKm: easyKm,
    }),
    session({
      id: `w${weekNumber}-long`,
      date: saturday,
      weekNumber,
      type: "longRun",
      distanceKm: longKm,
      targetZone: "longRun",
    }),
  ];
}

function weekVolume(
  sessions: GeneratedSession[],
  weekNumber: number,
): number {
  return sessions
    .filter((s) => s.weekNumber === weekNumber && s.type !== "restDay")
    .reduce((sum, s) => sum + (s.distanceKm ?? 0), 0);
}

function profileWithSummary(weeklyVolumeKm: number): Record<string, unknown> {
  return {
    goal: { race: "race_half_marathon", raceDate: null },
    fitness: {
      experience: "experience_intermediate",
      athleteSummary: {
        weeklyVolumeKm,
        acuteChronicRatio: 1.0,
        longestRecentRunKm: 12,
      },
    },
    schedule: { hardDays: [], longRunDay: null, trainingDays: 2 },
  };
}

function profileWithStravaWeeklyVolume(
  weeklyVolumeKm: number,
  options: {
    confidence?: "high" | "medium" | "limited";
    guardrails?: Array<{ category: string }>;
    fallbackSummaryKm?: number | null;
  } = {},
): Record<string, unknown> {
  const confidence = options.confidence ?? "high";
  const fallbackSummaryKm = options.fallbackSummaryKm;

  return {
    goal: { race: "race_half_marathon", raceDate: null },
    fitness: {
      experience: "experience_intermediate",
      ...(fallbackSummaryKm == null ? {} : {
        athleteSummary: {
          weeklyVolumeKm: fallbackSummaryKm,
        },
      }),
    },
    stravaCoachingProfile: {
      dataConfidence: confidence,
      trainingBase: [
        {
          metric: "training_base_weekly_km",
          value: weeklyVolumeKm,
          unit: "km_per_week",
          date: "2026-05-01T00:00:00Z",
        },
      ],
      recoveryGuardrails: options.guardrails,
    },
    schedule: { hardDays: [], longRunDay: null, trainingDays: 2 },
  };
}

Deno.test("normalizeWeeklyVolumeRamp clamps a too-aggressive week-over-week ramp", () => {
  // Anchor history ~20 km/week. Week 1 = 20 km (within ~10% of anchor).
  // Week 2 jumps to 40 km (a 100% ramp) which must be clamped to ~22 km.
  const sessions = [
    ...week(1, 8, 12), // 20 km
    ...week(2, 16, 24), // 40 km — far above the ~10% ceiling
  ];

  const result = normalizeWeeklyVolumeRamp(
    sessions,
    profileWithSummary(20),
    8,
    "en",
  );

  const w1 = weekVolume(result, 1);
  const w2 = weekVolume(result, 2);

  // Week 1 left at its already-within-budget volume.
  assert.equal(Math.round(w1), 20);

  // Week 2 clamped to ~10% over week 1.
  assert.ok(
    w2 <= w1 * 1.1 + 0.5,
    `week 2 should be clamped to ~10% over week 1 (<= ${w1 * 1.1}), got ${w2}`,
  );
  assert.ok(
    w2 > w1,
    `week 2 should still progress above week 1, got ${w2} vs ${w1}`,
  );

  // Distances were scaled proportionally and durations recomputed.
  const w2Long = result.find((s) => s.id === "w2-long");
  assert.ok(w2Long, "week 2 long run should exist");
  assert.ok(
    (w2Long!.distanceKm ?? 0) < 24,
    "week 2 long run distance should be reduced",
  );
  assert.ok(
    (w2Long!.durationMinutes ?? 0) > 0,
    "week 2 long run duration should be recomputed",
  );
});

Deno.test("normalizeWeeklyVolumeRamp clamps using strong Strava weekly-volume evidence", () => {
  const sessions = [
    ...week(1, 8, 12),
    ...week(2, 16, 24),
  ];

  const result = normalizeWeeklyVolumeRamp(
    sessions,
    profileWithStravaWeeklyVolume(20, { confidence: "high" }),
    8,
    "en",
  );

  const w1 = weekVolume(result, 1);
  const w2 = weekVolume(result, 2);

  assert.ok(
    w1 <= 20 + 0.5,
    `anchor week should stay close to Strava weekly volume, got ${w1}`,
  );
  assert.ok(
    w2 <= w1 * 1.1 + 0.5,
    `week 2 should be clamped by Strava safety, got ${w2}`,
  );
});

Deno.test("normalizeWeeklyVolumeRamp ignores acceptedRaceTarget for volume baseline", () => {
  const sessions = [
    ...week(1, 8, 12),
    ...week(2, 25, 45),
  ];

  const result = normalizeWeeklyVolumeRamp(
    sessions,
    {
      goal: { race: "race_half_marathon", raceDate: null },
      acceptedRaceTarget: {
        distanceKm: 42.2,
        primaryTimeMs: 1200000,
        stretchTimeMs: 1180000,
      },
      fitness: {
        experience: "experience_intermediate",
        athleteSummary: {
          weeklyVolumeKm: 20,
          longestRecentRunKm: 14,
          acuteChronicRatio: 1.0,
        },
      },
      schedule: { hardDays: [], longRunDay: null, trainingDays: 2 },
    },
    8,
    "en",
  );

  const w1 = weekVolume(result, 1);
  const w2 = weekVolume(result, 2);

  assert.ok(
    w1 >= 20,
    `week 1 should remain around athleteSummary, got ${w1}`,
  );
  assert.ok(
    w2 <= 22 + 0.5,
    `acceptedRaceTarget must not raise weekly volume above safety cap, got ${w2}`,
  );
});

Deno.test("normalizeWeeklyVolumeRamp falls back when Strava weekly-volume has high-risk guardrails", () => {
  const sessions = [
    ...week(1, 8, 12),
    ...week(2, 16, 24),
  ];

  const result = normalizeWeeklyVolumeRamp(
    sessions,
    profileWithStravaWeeklyVolume(20, {
      confidence: "high",
      guardrails: [{ category: "recovery_sparse_data" }],
      fallbackSummaryKm: 20,
    }),
    8,
    "en",
  );

  assert.ok(
    weekVolume(result, 2) <= 22 + 0.01,
    `guardrailed inputs must still cap near athlete summary, got ${
      weekVolume(result, 2)
    }`,
  );
});

Deno.test("normalizeWeeklyVolumeRamp leaves down/taper weeks untouched", () => {
  // Week 3 deliberately drops volume (down week) — it is already under budget
  // and must not be raised.
  const sessions = [
    ...week(1, 8, 12), // 20 km
    ...week(2, 9, 13), // 22 km (~10% ramp, within budget)
    ...week(3, 5, 8), // 13 km down week
  ];

  const result = normalizeWeeklyVolumeRamp(
    sessions,
    profileWithSummary(20),
    8,
    "en",
  );

  assert.equal(weekVolume(result, 3), 13, "down week must be left unchanged");
  assert.equal(weekVolume(result, 2), 22, "in-budget week must be unchanged");
});

Deno.test("normalizeWeeklyVolumeRamp is a no-op when athleteSummary is absent", () => {
  const sessions = [
    ...week(1, 8, 12),
    ...week(2, 16, 24), // huge ramp, but no Strava history => untouched
  ];
  const manualProfile: Record<string, unknown> = {
    goal: { race: "race_half_marathon", raceDate: null },
    fitness: { experience: "experience_intermediate" },
    schedule: { hardDays: [], longRunDay: null, trainingDays: 2 },
  };

  const result = normalizeWeeklyVolumeRamp(sessions, manualProfile, 8, "en");

  assert.deepEqual(
    result.map((s) => ({ id: s.id, distanceKm: s.distanceKm })),
    sessions.map((s) => ({ id: s.id, distanceKm: s.distanceKm })),
    "manual-profile plans must be returned unchanged",
  );
});

Deno.test("normalizeWeeklyVolumeRamp ignores summary flagged insufficientData", () => {
  const sessions = [
    ...week(1, 8, 12),
    ...week(2, 16, 24),
  ];
  const profile: Record<string, unknown> = {
    goal: { race: "race_half_marathon", raceDate: null },
    fitness: {
      experience: "experience_intermediate",
      athleteSummary: {
        weeklyVolumeKm: 20,
        insufficientData: true,
      },
    },
    schedule: { hardDays: [], longRunDay: null, trainingDays: 2 },
  };

  const result = normalizeWeeklyVolumeRamp(sessions, profile, 8, "en");

  assert.equal(
    weekVolume(result, 2),
    40,
    "weak/insufficient summary must not clamp the ramp",
  );
});
