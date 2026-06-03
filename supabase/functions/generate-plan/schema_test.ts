import { strict as assert } from "node:assert";
import {
  GeneratedPlanSchema,
  GeneratePlanRequestSchema,
  removeSessionsOnRaceDate,
} from "./schema.ts";

const professionalPlanInputStrava = {
  goal: {
    race: "race_half_marathon",
    hasRaceDate: true,
    raceDate: "2026-10-18T00:00:00.000Z",
    priority: "priority_improve_time",
    currentTimeMs: 7260000,
    targetTimeMs: 6900000,
  },
  fitnessSource: "strava",
  stravaCoachingProfile: {
    dataConfidence: "high",
    terrain: "rolling",
    paceZones: {
      recovery: {},
      easy: {},
      longRun: {},
      steady: {},
      tempo: {},
      threshold: {},
      racePace: {},
      intervals: {},
      strides: {},
    },
  },
  acceptedRaceTarget: {
    distanceKm: 21.097,
    primaryTimeMs: 6900000,
    stretchTimeMs: 6720000,
    confidence: "medium",
    evidence: [],
  },
  schedule: {
    trainingDays: 4,
    longRunDay: "day_sun",
    weekdayTime: "time_45_min",
    weekendTime: "time_90_min",
    hardDays: ["day_tue", "day_thu"],
    preferredTimeOfDay: "time_of_day_morning",
  },
  health: {
    painLevel: "pain_no",
    injuryHistory: "injury_no",
    hasHealthConditions: "no",
  },
  strengthPreferences: {
    lifts: true,
    weeklyFrequency: 2,
    categories: ["core_mobility", "lower_body"],
    preferredDays: ["day_mon", "day_wed"],
    sameDayOrder: "run_first",
  },
  planIntensity: "balanced",
  unitPreference: "metric",
  locale: "es",
  raceCourseTerrain: "rolling",
};

const manualProfessionalPlanInput = {
  ...professionalPlanInputStrava,
  fitnessSource: "manual",
  stravaCoachingProfile: undefined,
  manualFitness: {
    experience: "experience_intermediate",
    weeklyVolume: "weekly_volume_3",
    longestRun: "longest_run_3",
    canCompleteGoalDistance: "not_sure",
    raceDistanceBefore: "race_distance_2_to_3",
    benchmark: "benchmark_half_marathon",
    benchmarkTimeMs: 6900000,
  },
};

const generatedPlan = {
  schemaVersion: 1,
  id: "plan-id",
  totalWeeks: 8,
  currentWeekNumber: 1,
  raceType: "halfMarathon",
  generatedLocale: "en",
  sessions: [
    {
      id: "w1-mon-easy",
      date: "2026-10-01",
      weekNumber: 1,
      type: "easyRun",
      phase: "base",
      distanceKm: 10,
      durationMinutes: 60,
      coachNote: "Easy effort.",
      targetZone: "easy",
      warmUpMinutes: 10,
      coolDownMinutes: 10,
      intervalReps: null,
      intervalRepDistanceMeters: null,
      intervalRecoverySeconds: null,
      strideReps: 4,
      strideSeconds: 20,
      strideRecoverySeconds: 60,
      workoutTarget: {
        schemaVersion: 1,
        type: "pace",
        zone: "easy",
        paceMinSecPerKm: 360,
        paceMaxSecPerKm: 390,
        effortCue: "Easy effort",
      },
    },
  ],
  supportSessions: [
    {
      schemaVersion: 1,
      id: "s1",
      date: "2026-10-02",
      weekNumber: 1,
      category: "lower_body",
      durationMinutes: 40,
      load: "moderate",
      timingGuidance: "before long run",
      interferenceRule: "keep low intensity",
      taperAdjustment: null,
      notes: "Tempo work",
    },
  ],
  paceZones: {
    recovery: { paceMinSecPerKm: 360, paceMaxSecPerKm: 460 },
    easy: { paceMinSecPerKm: 360, paceMaxSecPerKm: 460 },
    longRun: { paceMinSecPerKm: 380, paceMaxSecPerKm: 470 },
    steady: { paceMinSecPerKm: 350, paceMaxSecPerKm: 430 },
    tempo: { paceMinSecPerKm: 330, paceMaxSecPerKm: 350 },
    threshold: { paceMinSecPerKm: 320, paceMaxSecPerKm: 340 },
    racePace: { paceMinSecPerKm: 300, paceMaxSecPerKm: 325 },
    intervals: { paceMinSecPerKm: 280, paceMaxSecPerKm: 320 },
    strides: { paceMinSecPerKm: 250, paceMaxSecPerKm: 290 },
  },
  raceGuidance: {
    schemaVersion: 1,
    raceDayExecution: "Evening race plan.",
    primaryTargetSec: 6900,
  },
  stravaCoachingProfileSnapshot: {
    dataConfidence: "high",
    terrain: "rolling",
  },
};

Deno.test("GeneratePlanRequestSchema accepts strong Strava input", () => {
  const parsed = GeneratePlanRequestSchema.parse({
    requestedBy: "onboarding",
    locale: "en",
    professionalPlanInput: {
      ...professionalPlanInputStrava,
      locale: "es",
    },
  });
  assert.equal(parsed.requestedBy, "onboarding");
  assert.equal(parsed.professionalPlanInput?.fitnessSource, "strava");
});

Deno.test("GeneratePlanRequestSchema accepts manual source with manualFitness", () => {
  const parsed = GeneratePlanRequestSchema.parse({
    professionalPlanInput: manualProfessionalPlanInput,
  });
  assert.equal(parsed.professionalPlanInput?.fitnessSource, "manual");
  assert.ok(parsed.professionalPlanInput?.manualFitness != null);
});

Deno.test("GeneratePlanRequestSchema rejects manual source with strava profile", () => {
  assert.throws(() => {
    GeneratePlanRequestSchema.parse({
      professionalPlanInput: {
        ...manualProfessionalPlanInput,
        stravaCoachingProfile: { dataConfidence: "medium" },
      },
    });
  }, /manual source cannot include stravaCoachingProfile/);
});

Deno.test("GeneratePlanRequestSchema rejects strava source without strava profile", () => {
  assert.throws(() => {
    GeneratePlanRequestSchema.parse({
      professionalPlanInput: {
        ...professionalPlanInputStrava,
        stravaCoachingProfile: undefined,
      },
    });
  }, /strava source requires stravaCoachingProfile/);
});

Deno.test("GeneratePlanRequestSchema rejects high-confidence strava plus manualFitness", () => {
  assert.throws(() => {
    GeneratePlanRequestSchema.parse({
      professionalPlanInput: {
        ...professionalPlanInputStrava,
        manualFitness: {
          experience: "experience_intermediate",
          weeklyVolume: "weekly_volume_3",
          longestRun: "longest_run_3",
          canCompleteGoalDistance: "not_sure",
          raceDistanceBefore: "race_distance_2_to_3",
          benchmark: "benchmark_half_marathon",
          benchmarkTimeMs: 6900000,
        },
      },
    });
  }, /high-confidence Strava data cannot include manualFitness/);
});

Deno.test("GeneratedPlanSchema accepts new required fields and support sessions", () => {
  const parsed = GeneratedPlanSchema.parse({
    ...generatedPlan,
    generatedLocale: "en",
  });
  assert.equal(parsed.generatedLocale, "en");
  assert.equal(parsed.raceGuidance.raceDayExecution, "Evening race plan.");
  assert.equal(parsed.supportSessions.length, 1);
  assert.equal(parsed.paceZones.recovery.paceMinSecPerKm, 360);
});

Deno.test("GeneratedPlanSchema rejects pace zones with prose-only pace values", () => {
  const invalid = JSON.parse(JSON.stringify(generatedPlan));
  invalid.paceZones.easy.paceMinSecPerKm = "5:20/km";
  assert.throws(() => {
    GeneratedPlanSchema.parse(invalid);
  }, /invalid_type/);
});

Deno.test("GeneratedPlanSchema rejects workoutTarget prose-only pace values", () => {
  const invalid = JSON.parse(JSON.stringify(generatedPlan));
  invalid.sessions[0].workoutTarget.paceMinSecPerKm = "easy pace";
  assert.throws(() => {
    GeneratedPlanSchema.parse(invalid);
  }, /invalid_type/);
});

Deno.test("GeneratedPlanSchema rejects pace minima above maxima", () => {
  const invalid = JSON.parse(JSON.stringify(generatedPlan));
  invalid.sessions[0].workoutTarget.paceMinSecPerKm = 500;
  invalid.sessions[0].workoutTarget.paceMaxSecPerKm = 300;
  assert.throws(() => {
    GeneratedPlanSchema.parse(invalid);
  }, /paceMinSecPerKm must be <=/);
});

Deno.test("GeneratedPlanSchema rejects race guidance-only session types", () => {
  const invalid = JSON.parse(JSON.stringify(generatedPlan));
  invalid.sessions[0].type = "goalRace";
  assert.throws(() => {
    GeneratedPlanSchema.parse(invalid);
  }, /invalid_union|invalid_value|invalid_enum_value/);
});

Deno.test(
  "removeSessionsOnRaceDate removes easyRun/longRun/racePaceRun sessions on the race date",
  () => {
    const raceDate = "2026-10-18T00:00:00.000Z";
    const sessions = [
      { id: "a", date: raceDate, type: "easyRun", weekNumber: 1 },
      { id: "b", date: raceDate, type: "longRun", weekNumber: 1 },
      { id: "c", date: "2026-10-10", type: "easyRun", weekNumber: 1 },
      { id: "d", date: raceDate, type: "racePaceRun", weekNumber: 1 },
    ] as const;

    const filtered = removeSessionsOnRaceDate(sessions, raceDate);
    assert.equal(filtered.length, 1);
    assert.equal(filtered[0].id, "c");
    assert.ok(
      !filtered.some((session) => session.date.startsWith("2026-10-18")),
    );
  },
);
