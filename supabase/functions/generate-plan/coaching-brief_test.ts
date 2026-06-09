import { strict as assert } from "node:assert";
import { buildCoachingBrief } from "./coaching-brief.ts";

Deno.test("race-ready 10K with close Strava evidence uses sharpening and taper", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-06-22T00:00:00Z"),
    requestedRaceType: "10K",
    profileData: {
      goal: { race: "race_10k" },
      schedule: { trainingDays: 4 },
      stravaCoachingProfile: {
        dataConfidence: "high",
        trainingBase: [
          {
            metric: "training_base_weekly_km",
            value: 45,
            unit: "km_per_week",
            date: "2026-05-24T00:00:00Z",
          },
          {
            metric: "training_base_runs_per_week",
            value: 4,
            unit: "runs_per_week",
            date: "2026-05-24T00:00:00Z",
          },
        ],
        endurance: [
          {
            metric: "endurance_long_run_km",
            value: 22,
            unit: "km",
            date: "2026-05-31T00:00:00Z",
          },
        ],
        raceTargets: [
          {
            distanceKm: 10,
            primaryTimeSec: 2400,
            confidence: "high",
            evidence: [],
          },
        ],
      },
      acceptedRaceTarget: {
        distanceKm: 10,
        primaryTimeMs: 2400000,
        stretchTimeMs: 2340000,
        confidence: "medium",
        evidence: [],
      },
    },
  });

  assert.equal(brief.raceType, "tenK");
  assert.equal(brief.readinessLevel, "raceReady");
  assert.equal(brief.confidence, "high");
  assert.equal(brief.source, "strava");
  assert.equal(brief.currentVolumeKmPerWeek, 45);
  assert.equal(brief.currentRunsPerWeek, 4);
  assert.equal(brief.recentLongRunKm, 22);
  assert.equal(brief.planLengthWeeks, 3);
  assert.deepEqual(
    brief.phaseStrategy.map((phase) => phase.phase),
    ["specific", "taperRace"],
  );
  assert.equal(brief.phaseStrategy[0].weeks, 2);
  assert.ok(
    !brief.phaseStrategy.some((phase) => phase.phase === "base"),
    "near race-ready 10K should not receive a generic base phase",
  );
  assert.ok(
    brief.maxWeeklyVolumeKm >= 45,
    `max volume should not be below current base, got ${brief.maxWeeklyVolumeKm}`,
  );
  assert.ok(
    brief.longRunCeilingKm >= 22,
    `long-run ceiling should respect current long-run base, got ${brief.longRunCeilingKm}`,
  );
  assert.equal(brief.taper.weeks, 1);
  assert.ok(brief.workoutEmphasis.includes("threshold"));
  assert.equal(brief.evidenceTarget.supported, true);
  assert.equal(brief.ambitiousTarget.supported, true);
});

Deno.test("underprepared near marathon downgrades ambitious target and caps load", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-06-29T00:00:00Z"),
    requestedRaceType: "marathon",
    profileData: {
      goal: { race: "race_marathon" },
      schedule: { trainingDays: 2 },
      stravaCoachingProfile: {
        dataConfidence: "medium",
        trainingBase: [
          {
            metric: "training_base_weekly_km",
            value: 16,
            unit: "km_per_week",
            date: "2026-05-24T00:00:00Z",
          },
          {
            metric: "training_base_runs_per_week",
            value: 2,
            unit: "runs_per_week",
            date: "2026-05-24T00:00:00Z",
          },
        ],
        endurance: [
          {
            metric: "endurance_long_run_km",
            value: 8,
            unit: "km",
            date: "2026-05-31T00:00:00Z",
          },
        ],
        raceTargets: [
          {
            distanceKm: 42.195,
            primaryTimeSec: 18000,
            confidence: "medium",
            evidence: [],
          },
        ],
      },
      acceptedRaceTarget: {
        distanceKm: 42.195,
        primaryTimeMs: 14400000,
        stretchTimeMs: 13500000,
        confidence: "medium",
        evidence: [],
      },
    },
  });

  assert.equal(brief.raceType, "marathon");
  assert.equal(brief.readinessLevel, "underprepared");
  assert.deepEqual(
    brief.phaseStrategy.map((phase) => phase.phase),
    ["safeBuild", "taperRace"],
  );
  assert.ok(
    brief.constraints.some((constraint) =>
      constraint.includes("completion and safe consistency")
    ),
  );
  assert.ok(
    brief.constraints.some((constraint) =>
      constraint.includes("unsupported ambitious target")
    ),
  );
  assert.equal(brief.ambitiousTarget.supported, false);
  assert.ok(
    brief.maxWeeklyVolumeKm <= 20,
    `near underprepared marathon should keep volume conservative, got ${brief.maxWeeklyVolumeKm}`,
  );
  assert.ok(
    brief.longRunCeilingKm <= 14,
    `near underprepared marathon should not chase marathon long-run norms, got ${brief.longRunCeilingKm}`,
  );
  assert.ok(
    brief.workoutEmphasis.includes("completion-oriented race preparation"),
  );
});

Deno.test("manual non-Strava snapshot produces usable medium confidence brief", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-08-10T00:00:00Z"),
    requestedRaceType: "half_marathon",
    profileData: {
      goal: { race: "race_half_marathon" },
      schedule: { trainingDays: 3 },
      manualFitness: {
        experience: "experience_intermediate",
        weeklyVolume: "weekly_volume_4",
        longestRun: "longest_run_4",
        benchmark: "benchmark_10k",
        benchmarkTimeMs: 3000000,
      },
      acceptedRaceTarget: {
        distanceKm: 21.097,
        primaryTimeMs: 6900000,
        confidence: "medium",
        evidence: [],
      },
    },
  });

  assert.equal(brief.raceType, "halfMarathon");
  assert.equal(brief.source, "manual");
  assert.equal(brief.confidence, "medium");
  assert.equal(brief.currentVolumeKmPerWeek, 28.5);
  assert.equal(brief.currentRunsPerWeek, 3);
  assert.equal(brief.recentLongRunKm, 15);
  assert.notEqual(brief.readinessLevel, "unsupported");
  assert.equal(brief.evidenceTarget.supported, true);
  assert.equal(brief.evidenceTarget.source, "manual");
  assert.ok((brief.evidenceTarget.timeSec ?? 0) > 0);
});

Deno.test("mismatched accepted race target distance is not supported for requested race", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-08-10T00:00:00Z"),
    requestedRaceType: "10K",
    profileData: {
      goal: { race: "race_10k" },
      schedule: { trainingDays: 4 },
      stravaCoachingProfile: {
        dataConfidence: "high",
        trainingBase: [
          {
            metric: "training_base_weekly_km",
            value: 32,
            unit: "km_per_week",
          },
          {
            metric: "training_base_runs_per_week",
            value: 4,
            unit: "runs_per_week",
          },
        ],
        endurance: [
          {
            metric: "endurance_long_run_km",
            value: 11,
            unit: "km",
          },
        ],
      },
      acceptedRaceTarget: {
        distanceKm: 21.097,
        primaryTimeMs: 7200000,
        stretchTimeMs: 6900000,
        confidence: "medium",
        evidence: [],
      },
    },
  });

  assert.equal(brief.raceType, "tenK");
  assert.equal(brief.evidenceTarget.supported, false);
  assert.equal(brief.ambitiousTarget.supported, false);
  assert.equal(brief.ambitiousTarget.timeSec, null);
  assert.match(brief.ambitiousTarget.reason, /distance does not match/);
});

Deno.test("zero-volume manual beginner 5K gets safe nonzero max weekly volume", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-07-27T00:00:00Z"),
    requestedRaceType: "5K",
    profileData: {
      goal: { race: "race_5k" },
      schedule: { trainingDays: 3 },
      manualFitness: {
        experience: "experience_beginner",
        weeklyVolume: "weekly_volume_0",
        longestRun: "longest_run_0",
        benchmark: "benchmark_skip",
      },
    },
  });

  assert.equal(brief.raceType, "fiveK");
  assert.equal(brief.readinessLevel, "underprepared");
  assert.equal(brief.currentVolumeKmPerWeek, 0);
  assert.ok(
    brief.maxWeeklyVolumeKm > 0,
    `zero-volume 5K should still get a usable progression cap, got ${brief.maxWeeklyVolumeKm}`,
  );
  assert.ok(
    brief.maxWeeklyVolumeKm <= 10.5,
    `zero-volume 5K floor should remain conservative, got ${brief.maxWeeklyVolumeKm}`,
  );
});

Deno.test("empty high-confidence Strava profile falls back to manual confidence", () => {
  const brief = buildCoachingBrief({
    startDate: new Date("2026-06-01T00:00:00Z"),
    raceDate: new Date("2026-08-10T00:00:00Z"),
    requestedRaceType: "10K",
    profileData: {
      goal: { race: "race_10k" },
      schedule: { trainingDays: 3 },
      stravaCoachingProfile: {
        dataConfidence: "high",
        trainingBase: [],
        endurance: [],
        speedMarkers: [],
      },
      manualFitness: {
        weeklyVolume: "weekly_volume_2",
        longestRun: "longest_run_2",
        benchmark: "benchmark_skip",
      },
    },
  });

  assert.equal(brief.source, "manual");
  assert.equal(brief.confidence, "limited");
  assert.notEqual(brief.source, "strava");
  assert.notEqual(brief.confidence, "high");
});

Deno.test("normalizes standard races and marks custom races unsupported", () => {
  const startDate = new Date("2026-06-01T00:00:00Z");
  const raceDate = new Date("2026-08-01T00:00:00Z");
  const baseProfile = {
    schedule: { trainingDays: 3 },
    manualFitness: {
      weeklyVolume: "weekly_volume_3",
      longestRun: "longest_run_3",
    },
  };

  assert.equal(
    buildCoachingBrief({
      profileData: baseProfile,
      startDate,
      raceDate,
      requestedRaceType: "race_5k",
    }).raceType,
    "fiveK",
  );
  assert.equal(
    buildCoachingBrief({
      profileData: baseProfile,
      startDate,
      raceDate,
      requestedRaceType: "10k",
    }).raceType,
    "tenK",
  );
  assert.equal(
    buildCoachingBrief({
      profileData: baseProfile,
      startDate,
      raceDate,
      requestedRaceType: "halfMarathon",
    }).raceType,
    "halfMarathon",
  );
  assert.equal(
    buildCoachingBrief({
      profileData: baseProfile,
      startDate,
      raceDate,
      requestedRaceType: "race_marathon",
    }).raceType,
    "marathon",
  );

  const custom = buildCoachingBrief({
    profileData: baseProfile,
    startDate,
    raceDate,
    requestedRaceType: "50K trail",
  });
  assert.equal(custom.raceType, "other");
  assert.equal(custom.readinessLevel, "unsupported");
  assert.equal(custom.evidenceTarget.supported, false);
  assert.ok(
    custom.constraints.some((constraint) =>
      constraint.includes("Unsupported race type")
    ),
  );
});

Deno.test("phase strategy differs for 5K, 10K, half marathon, and marathon", () => {
  const startDate = new Date("2026-06-01T00:00:00Z");
  const profileData = {
    schedule: { trainingDays: 4 },
    stravaCoachingProfile: {
      dataConfidence: "high",
      trainingBase: [
        {
          metric: "training_base_weekly_km",
          value: 45,
          unit: "km_per_week",
        },
        {
          metric: "training_base_runs_per_week",
          value: 4,
          unit: "runs_per_week",
        },
      ],
      endurance: [
        {
          metric: "endurance_long_run_km",
          value: 22,
          unit: "km",
        },
      ],
    },
  };

  const fiveK = buildCoachingBrief({
    profileData,
    startDate,
    raceDate: null,
    requestedRaceType: "5K",
  });
  const tenK = buildCoachingBrief({
    profileData,
    startDate,
    raceDate: null,
    requestedRaceType: "10K",
  });
  const half = buildCoachingBrief({
    profileData,
    startDate,
    raceDate: null,
    requestedRaceType: "half_marathon",
  });
  const marathon = buildCoachingBrief({
    profileData,
    startDate,
    raceDate: null,
    requestedRaceType: "marathon",
  });

  assert.equal(fiveK.planLengthWeeks, 8);
  assert.equal(tenK.planLengthWeeks, 10);
  assert.equal(half.planLengthWeeks, 14);
  assert.equal(marathon.planLengthWeeks, 18);
  assert.ok(fiveK.workoutEmphasis.includes("VO2 max intervals"));
  assert.ok(tenK.workoutEmphasis.includes("10K pace intervals"));
  assert.ok(half.workoutEmphasis.includes("long-run progression"));
  assert.ok(marathon.workoutEmphasis.includes("fueling practice"));
  assert.notDeepEqual(fiveK.phaseStrategy, tenK.phaseStrategy);
  assert.notDeepEqual(half.phaseStrategy, marathon.phaseStrategy);
});
