import { strict as assert } from "node:assert";
import {
  buildGeneratePlanMessages,
  parseGeneratedPlanContent,
  resolveOpenAiModel,
  sanitizeProfileForOpenAi,
  trainingPlanResponseJsonSchema,
} from "./openai.ts";

const messageProfile = {
  goal: {
    race: "race_half_marathon",
    hasRaceDate: true,
    raceDate: "2026-10-18T00:00:00.000Z",
    priority: "priority_improve_time",
    currentTimeMs: 7260000,
    targetTimeMs: 6900000,
  },
  acceptedRaceTarget: {
    distanceKm: 21.097,
    primaryTimeMs: 6900000,
    stretchTimeMs: 6720000,
    confidence: "medium",
    evidence: [],
  },
  fitnessSource: "strava",
  stravaCoachingProfile: {
    dataConfidence: "high",
    terrain: "rolling",
    paceZones: {},
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
  locale: "es",
  unitPreference: "metric",
  raceCourseTerrain: "rolling",
};

const parseProfile = {
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
      coachNote: "Easy effort",
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
        effortCue: "easy effort",
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
      notes: "Mobility + strength",
    },
  ],
  paceZones: {
    recovery: {
      paceMinSecPerKm: 420,
      paceMaxSecPerKm: 520,
    },
    easy: {
      paceMinSecPerKm: 360,
      paceMaxSecPerKm: 460,
    },
    longRun: {
      paceMinSecPerKm: 380,
      paceMaxSecPerKm: 470,
    },
    steady: {
      paceMinSecPerKm: 350,
      paceMaxSecPerKm: 430,
    },
    tempo: {
      paceMinSecPerKm: 330,
      paceMaxSecPerKm: 350,
    },
    threshold: {
      paceMinSecPerKm: 320,
      paceMaxSecPerKm: 340,
    },
    racePace: {
      paceMinSecPerKm: 300,
      paceMaxSecPerKm: 325,
    },
    intervals: {
      paceMinSecPerKm: 280,
      paceMaxSecPerKm: 320,
    },
    strides: {
      paceMinSecPerKm: 240,
      paceMaxSecPerKm: 290,
    },
  },
  raceGuidance: {
    schemaVersion: 1,
    raceDayExecution: "Warm up with easy jog.",
    primaryTargetSec: 6900,
  },
  stravaCoachingProfileSnapshot: {
    dataConfidence: "high",
    terrain: "rolling",
  },
};

Deno.test("buildGeneratePlanMessages builds locale-specific Spanish copy", () => {
  const [systemMessage] = buildGeneratePlanMessages(messageProfile, "es", 8);
  assert.equal(systemMessage.role, "system");
  assert.ok(systemMessage.content.includes("Spanish"));
  assert.ok(
    systemMessage.content.includes("AI-written coaching text in Spanish"),
  );
});

Deno.test("buildGeneratePlanMessages builds locale-specific English copy", () => {
  const [systemMessage] = buildGeneratePlanMessages(messageProfile, "en", 8);
  assert.equal(systemMessage.role, "system");
  assert.ok(systemMessage.content.includes("English"));
  assert.ok(systemMessage.content.includes("coachNote"));
});

Deno.test("resolveOpenAiModel uses default when OPENAI_MODEL is unset", () => {
  const model = resolveOpenAiModel(undefined);
  assert.equal(model, "gpt-5.4-mini");
});

Deno.test("resolveOpenAiModel accepts trimmed configured model", () => {
  const model = resolveOpenAiModel("  gpt-5.4  ");
  assert.equal(model, "gpt-5.4");
});

Deno.test("resolveOpenAiModel fails fast for empty configured model", () => {
  assert.throws(
    () => resolveOpenAiModel("   "),
    Error,
    "OPENAI_MODEL is set but empty",
  );
});

Deno.test("resolveOpenAiModel fails fast for whitespace in configured model", () => {
  assert.throws(
    () => resolveOpenAiModel("gpt 5.4"),
    Error,
    "OPENAI_MODEL is invalid",
  );
});

Deno.test("buildGeneratePlanMessages guides race-day as guidance-only", () => {
  const [systemMessage] = buildGeneratePlanMessages(messageProfile, "es", 8);
  assert.ok(systemMessage.content.includes("guidance-only"));
  assert.ok(!systemMessage.content.includes("goal race is the final session"));
});

Deno.test("trainingPlanResponseJsonSchema requires new generated output fields", () => {
  const requiredFields = trainingPlanResponseJsonSchema.required as string[];
  assert.ok(requiredFields.includes("generatedLocale"));
  assert.ok(requiredFields.includes("supportSessions"));
  assert.ok(requiredFields.includes("paceZones"));
  assert.ok(requiredFields.includes("raceGuidance"));
  assert.ok(requiredFields.includes("stravaCoachingProfileSnapshot"));
});

Deno.test("trainingPlanResponseJsonSchema requires numeric pace fields", () => {
  const sessionsSchema = (
    trainingPlanResponseJsonSchema.properties as {
      sessions: { items: { properties: Record<string, unknown> } };
    }
  ).sessions.items;
  const workoutTarget = sessionsSchema.properties.workoutTarget as {
    required?: string[];
    properties: {
      paceMinSecPerKm: { type: string | string[] };
      paceMaxSecPerKm: { type: string | string[] };
    };
  };
  assert.equal(workoutTarget.properties.paceMinSecPerKm.type, "integer");
  assert.equal(workoutTarget.properties.paceMaxSecPerKm.type, "integer");
  assert.ok(
    workoutTarget.required?.includes("paceMinSecPerKm"),
    "workoutTarget.required should include paceMinSecPerKm",
  );
  assert.ok(
    workoutTarget.required?.includes("paceMaxSecPerKm"),
    "workoutTarget.required should include paceMaxSecPerKm",
  );
});

Deno.test("trainingPlanResponseJsonSchema requires all object properties", () => {
  const schema = trainingPlanResponseJsonSchema as unknown as Record<
    string,
    unknown
  >;
  const violations: string[] = [];

  const walk = (node: unknown, path = "root") => {
    if (node == null || typeof node !== "object") return;

    if (Array.isArray(node)) {
      node.forEach((child, index) => walk(child, `${path}[${index}]`));
      return;
    }

    const objectNode = node as Record<string, unknown>;
    const properties = objectNode.properties;
    if (properties != null && typeof properties === "object") {
      const propertyNames = Object.keys(properties);
      const required = Array.isArray(objectNode.required)
        ? objectNode.required.map(String)
        : [];
      for (const propName of propertyNames) {
        if (!required.includes(propName)) {
          violations.push(`${path} object missing required property "${propName}"`);
        }
      }
    }

    for (const [key, child] of Object.entries(objectNode)) {
      if (key === "required") continue;
      if (child == null || typeof child !== "object") continue;
      walk(child, `${path}.${key}`);
    }
  };

  walk(schema);
  assert.equal(violations.length, 0, violations.join("\n"));
});

Deno.test("trainingPlanResponseJsonSchema has no additionalProperties:true flags", () => {
  const schema = trainingPlanResponseJsonSchema as unknown as Record<
    string,
    unknown
  >;
  let violation = "";
  const walk = (node: unknown, path = "root") => {
    if (node == null || typeof node !== "object") return;
    if (Array.isArray(node)) {
      node.forEach((child, index) => walk(child, `${path}[${index}]`));
      return;
    }

    const objectNode = node as Record<string, unknown>;
    if (objectNode.additionalProperties === true) {
      violation = `${path}.additionalProperties=true`;
      return;
    }

    for (const [key, child] of Object.entries(objectNode)) {
      walk(child, `${path}.${key}`);
      if (violation) return;
    }
  };
  walk(schema);
  assert.equal(violation, "");
});

Deno.test("buildGeneratePlanMessages sends sanitized payload fields", () => {
  const unsafeProfile = {
    activities: [{ id: "run-1" }],
    tokens: "secret-token",
    activityStreams: [{ stream: "bad" }],
    upstreamErrorBodies: [{ body: "bad" }],
    ...messageProfile,
    manualFitness: {
      experience: "experience_intermediate",
      weeklyVolume: "weekly_volume_3",
      longestRun: "longest_run_3",
      canCompleteGoalDistance: "not_sure",
      raceDistanceBefore: "race_distance_2_to_3",
      benchmark: "benchmark_half_marathon",
      benchmarkTimeMs: 6900000,
      tokens: "manual-secret-token",
      privateData: { secret: "manual-private" },
    },
    fitness: {
      fitnessSource: "strava",
      accessToken: "fitness-secret-token",
      privateData: { secret: "fitness-private" },
      stravaCoachingProfile: {
        dataConfidence: "high",
        terrain: "rolling",
        trainingBase: [
          {
            metric: "longest-run",
            date: "2026-01-01",
            value: 15,
            unit: "km",
            source: "strava-app",
          },
        ],
      },
    },
    stravaCoachingProfile: {
      dataConfidence: "high",
      terrain: "rolling",
      upstreamError: "bad",
      tokens: "secret-token",
      activityNames: ["bad"],
      activityStreams: [{ id: "x" }],
      stravaError: { code: "x" },
      upstreamErrorBodies: [{ body: "x" }],
      paceZones: {
        recovery: { paceMinSecPerKm: 420, paceMaxSecPerKm: 520 },
        easy: { paceMinSecPerKm: 360, paceMaxSecPerKm: 460 },
        longRun: { paceMinSecPerKm: 380, paceMaxSecPerKm: 470 },
        steady: { paceMinSecPerKm: 350, paceMaxSecPerKm: 430 },
        tempo: { paceMinSecPerKm: 330, paceMaxSecPerKm: 350 },
        threshold: { paceMinSecPerKm: 320, paceMaxSecPerKm: 340 },
        racePace: { paceMinSecPerKm: 300, paceMaxSecPerKm: 325 },
        intervals: { paceMinSecPerKm: 280, paceMaxSecPerKm: 320 },
        strides: { paceMinSecPerKm: 240, paceMaxSecPerKm: 290 },
      },
    },
  } as const;

  const messages = buildGeneratePlanMessages(unsafeProfile, "en", 8);
  const userPrompt = JSON.parse(
    messages[1].content.replace("Runner profile:\n", ""),
  );
  assert.equal(userPrompt.activities, undefined);
  assert.equal(userPrompt.tokens, undefined);
  assert.equal(userPrompt.activityStreams, undefined);
  assert.equal(userPrompt.upstreamErrorBodies, undefined);
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.activityNames,
    undefined,
  );
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.activityStreams,
    undefined,
  );
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.upstreamError,
    undefined,
  );
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.tokens,
    undefined,
  );
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.stravaError,
    undefined,
  );
  assert.equal(
    userPrompt.fitness.stravaCoachingProfile?.upstreamErrorBodies,
    undefined,
  );
  assert.equal(userPrompt.fitness.accessToken, undefined);
  assert.equal(userPrompt.fitness.privateData, undefined);
  assert.equal(userPrompt.manualFitness.tokens, undefined);
  assert.equal(userPrompt.manualFitness.privateData, undefined);
  assert.equal(userPrompt.stravaCoachingProfile.dataConfidence, "high");
  assert.equal(userPrompt.stravaCoachingProfile.terrain, "rolling");
  assert.equal(Array.isArray(userPrompt.stravaCoachingProfile.trainingBase), true);
  assert.equal(
    JSON.stringify(userPrompt).includes("tokens"),
    false,
  );
  assert.equal(
    JSON.stringify(userPrompt).includes("accessToken"),
    false,
  );
  assert.equal(
    JSON.stringify(userPrompt).includes("privateData"),
    false,
  );
  assert.equal(
    JSON.stringify(userPrompt).includes("activityNames"),
    false,
  );
  assert.equal(
    JSON.stringify(userPrompt).includes("activityStreams"),
    false,
  );
  assert.equal(
    JSON.stringify(userPrompt).includes("upstreamError"),
    false,
  );

  const sanitized = sanitizeProfileForOpenAi(unsafeProfile as Record<string, unknown>);
  assert.equal(sanitized.activities, undefined);
  assert.equal(
    (sanitized.fitness as Record<string, unknown> | undefined)
      ?.stravaCoachingProfile,
    undefined,
  );
  const sanitizedFitnessStrava = sanitized.fitness as
    | Record<string, unknown>
    | undefined;
  if (sanitizedFitnessStrava != null) {
    const sanitizedFitnessSnapshot = sanitizedFitnessStrava.stravaCoachingProfile;
    if (sanitizedFitnessSnapshot != null) {
      const inner = sanitizedFitnessSnapshot as Record<string, unknown>;
      assert.equal(inner.activityNames, undefined);
      assert.equal(inner.activityStreams, undefined);
      assert.equal(inner.upstreamError, undefined);
      assert.equal(inner.upstreamErrorBodies, undefined);
      assert.equal(inner.stravaError, undefined);
    }
  }
  const sanitizedTopStrava = sanitized.stravaCoachingProfile as
    | Record<string, unknown>
    | undefined;
  if (sanitizedTopStrava != null) {
    assert.equal(sanitizedTopStrava.upstreamError, undefined);
    assert.equal(sanitizedTopStrava.upstreamErrorBodies, undefined);
    assert.equal(sanitizedTopStrava.activityNames, undefined);
    assert.equal(sanitizedTopStrava.activityStreams, undefined);
    assert.equal(sanitizedTopStrava.stravaError, undefined);
    assert.equal(sanitizedTopStrava.tokens, undefined);
  }
  const sanitizedFitness = sanitized.fitness as Record<string, unknown> | undefined;
  if (sanitizedFitness != null) {
    assert.equal(sanitizedFitness.accessToken, undefined);
    assert.equal(sanitizedFitness.privateData, undefined);
  }
  const sanitizedManual = sanitized.manualFitness as
    | Record<string, unknown>
    | undefined;
  if (sanitizedManual != null) {
    assert.equal(sanitizedManual.tokens, undefined);
    assert.equal(sanitizedManual.privateData, undefined);
  }
});

Deno.test("parseGeneratedPlanContent throws on prose-only pace values", () => {
  const invalid = {
    ...parseProfile,
    sessions: [
      {
        ...parseProfile.sessions[0],
        workoutTarget: {
          ...parseProfile.sessions[0].workoutTarget,
          paceMinSecPerKm: "easy pace",
        },
      },
    ],
  };
  assert.throws(() => {
    parseGeneratedPlanContent(JSON.stringify(invalid));
  }, /Expected number, received string|invalid_type|Expected number/);
});
