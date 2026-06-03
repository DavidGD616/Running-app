import { createClient } from "@supabase/supabase-js";
import {
  type GeneratePlanRequest,
  GeneratePlanRequestSchema,
  removeSessionsOnRaceDate,
  StravaCoachingProfileSnapshotSchema,
} from "./schema.ts";
import { generatePlanFromProfile, sanitizeProfileForOpenAi } from "./openai.ts";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  enforcePreRaceTaper,
  ensureFullCalendarWeeks,
  expectedTotalWeeks,
  normalizeFirstPlannedSession,
  normalizePeakLongRun,
  normalizeSessionIds,
  normalizeSupportSessions,
  normalizeTaper,
  normalizeTrainingDayCount,
  normalizeWeeklyVolumeRamp,
  normalizeWorkoutTypesByPhase,
  phaseForWeek,
  placeLongRunsOnPreferredDay,
  preferRestOnHardDays,
  smoothLongRunProgression,
  spaceStressfulSessions,
  truncateAfterRaceDate,
  validateGeneratedPlanShape,
  validateGeneratedSchedule,
} from "./plan-rules.ts";
import { buildWorkoutSteps } from "./workout-steps.ts";

type CoachLocale = "en" | "es";
type JsonObject = Record<string, unknown>;
type ProfileShape = JsonObject & {
  fitness?: JsonObject;
  manualFitness?: JsonObject;
  stravaCoachingProfile?: JsonObject;
};

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabasePublic = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SB_PUBLISHABLE_KEY")!,
  );

  const jwt = authHeader.replace("Bearer ", "");
  const { data: claimsData, error: claimsError } = await supabasePublic.auth
    .getClaims(jwt);
  const userId = claimsData?.claims?.sub;
  if (!userId || claimsError) {
    console.error("getClaims failed:", claimsError);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const body = await req.json().catch(() => ({} as Record<string, unknown>));
  const parsedBody = GeneratePlanRequestSchema.safeParse(body);
  if (!parsedBody.success) {
    return new Response(
      JSON.stringify({
        error: "Invalid request",
        detail: parsedBody.error.format(),
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const requestedBy = parsedBody.data.requestedBy;
  const storedLocale = normalizeLocale(parsedBody.data.locale);
  const professionalInput = parsedBody.data.professionalPlanInput;
  const locale = normalizeLocale(
    professionalInput?.locale ?? storedLocale,
  );

  let storedProfile: ProfileShape | null = null;
  if (professionalInput == null) {
    const { data: profileRow, error: profileError } = await supabase
      .from("runner_profiles")
      .select("data")
      .eq("user_id", userId)
      .maybeSingle();

    if (profileError || !profileRow) {
      return new Response(
        JSON.stringify({ error: "Runner profile not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    if (isRecord(profileRow.data)) {
      storedProfile = profileRow.data;
    }
  } else {
    const { data: profileRow, error: profileError } = await supabase
      .from("runner_profiles")
      .select("data")
      .eq("user_id", userId)
      .maybeSingle();

    if (
      !profileError && profileRow?.data != null && isRecord(profileRow.data)
    ) {
      storedProfile = profileRow.data;
    }
  }

  const generationProfile = buildGenerationProfile(
    storedProfile,
    professionalInput,
  );
  const sanitizedGenerationProfile = sanitizeProfileForOpenAi(
    generationProfile,
  ) as ProfileShape;
  if (Object.keys(generationProfile).length === 0) {
    return new Response(
      JSON.stringify({
        error: "Runner profile not found",
        detail:
          "No profile data available. Send professionalPlanInput or create a runner profile first.",
      }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const generationStartedAt = new Date();
  const expectedWeeks = expectedTotalWeeks(
    generationProfile,
    generationStartedAt,
  );
  if (expectedWeeks != null && expectedWeeks < 3) {
    return new Response(
      JSON.stringify({
        error: "Race date is too soon for plan generation",
        detail: "Fixed race-date plans require at least 3 calendar weeks.",
      }),
      { status: 422, headers: { "Content-Type": "application/json" } },
    );
  }

  let generatedPlan;
  try {
    generatedPlan = await generatePlanFromProfile(
      sanitizedGenerationProfile,
      locale,
      expectedWeeks,
    );
  } catch (err) {
    console.error("OpenAI generation failed:", err);
    return new Response(
      JSON.stringify({ error: "Plan generation failed", detail: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const plannedWeeks = expectedWeeks ?? generatedPlan.totalWeeks;
  const supportedSnapshot = pickStravaSnapshot(
    professionalInput?.stravaCoachingProfile ??
      (isRecord(sanitizedGenerationProfile.fitness?.stravaCoachingProfile)
        ? sanitizedGenerationProfile.fitness.stravaCoachingProfile
        : undefined),
  );
  const parsedSnapshot = supportedSnapshot
    ? sanitizeStravaSnapshot(supportedSnapshot)
    : null;
  if (
    parsedSnapshot == null &&
    generatedPlan.stravaCoachingProfileSnapshot == null
  ) {
    return new Response(
      JSON.stringify({
        error: "Plan generation failed",
        detail: "Invalid stravaCoachingProfile snapshot payload.",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const safeGeneratedPlan = {
    ...generatedPlan,
    totalWeeks: plannedWeeks,
    currentWeekNumber: generatedPlan.currentWeekNumber ?? 1,
    generatedLocale: locale,
    stravaCoachingProfileSnapshot: parsedSnapshot ??
      generatedPlan.stravaCoachingProfileSnapshot,
  };

  const scheduleNormalizedSessions = normalizeTrainingDayCount(
    safeGeneratedPlan.sessions,
    generationProfile,
    locale,
  );
  const longRunPlacedSessions = placeLongRunsOnPreferredDay(
    scheduleNormalizedSessions,
    generationProfile,
    locale,
  );
  const stressSpacedSessions = spaceStressfulSessions(
    longRunPlacedSessions,
    generationProfile,
    locale,
  );
  const fullCalendarSessions = ensureFullCalendarWeeks(
    stressSpacedSessions,
    locale,
  );
  const fullCalendarLongRunPlacedSessions = placeLongRunsOnPreferredDay(
    fullCalendarSessions,
    generationProfile,
    locale,
  );
  const hardDayRestedSessions = preferRestOnHardDays(
    fullCalendarLongRunPlacedSessions,
    generationProfile,
    locale,
  );
  const scheduleAdjustedSessions = avoidHardDayTraining(
    hardDayRestedSessions,
    generationProfile,
    locale,
  );
  const volumeRampedSessions = normalizeWeeklyVolumeRamp(
    scheduleAdjustedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const peakNormalizedSessions = normalizePeakLongRun(
    volumeRampedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const progressionSmoothedSessions = smoothLongRunProgression(
    peakNormalizedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const volumeStabilizedSessions = normalizeWeeklyVolumeRamp(
    progressionSmoothedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const taperNormalizedSessions = normalizeTaper(
    volumeStabilizedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
    taperNormalizedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const firstSessionNormalizedSessions = normalizeFirstPlannedSession(
    phaseNormalizedSessions,
    generationProfile,
    locale,
  );
  const phaseStampedSessions = firstSessionNormalizedSessions.map((
    session,
  ) => ({
    ...session,
    phase: phaseForWeek(
      session.weekNumber,
      safeGeneratedPlan.totalWeeks,
      generationProfile,
    ),
  }));
  const truncatedSessions = truncateAfterRaceDate(
    phaseStampedSessions,
    generationProfile,
  );
  const goal = isRecord(generationProfile.goal) ? generationProfile.goal : {};
  const raceDate = typeof goal.raceDate === "string"
    ? goal.raceDate
    : undefined;
  const sessionsWithoutRaceDate = removeSessionsOnRaceDate(
    truncatedSessions,
    raceDate,
  );
  const preRaceTaperedSessions = enforcePreRaceTaper(
    sessionsWithoutRaceDate,
    generationProfile,
    locale,
  );
  const normalizedSupportSessions = normalizeSupportSessions(
    safeGeneratedPlan.supportSessions,
    preRaceTaperedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  );
  const filteredSupportSessions = removeSessionsOnRaceDate(
    normalizedSupportSessions,
    raceDate,
  );
  const idNormalizedSessions = normalizeSessionIds(preRaceTaperedSessions);

  const sanitizedForValidation = withoutGoalDate(generationProfile);
  const finalViolations = [
    ...validateGeneratedPlanShape(
      idNormalizedSessions,
      safeGeneratedPlan.totalWeeks,
      sanitizedForValidation,
      generationStartedAt,
    ),
    ...validateGeneratedSchedule(idNormalizedSessions, sanitizedForValidation),
  ];
  if (finalViolations.length > 0) {
    console.error(
      "Generated plan failed schedule validation:",
      finalViolations,
    );
    return new Response(
      JSON.stringify({
        error: "Generated plan failed schedule validation",
        violations: finalViolations,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const sessionsWithSteps = addStrideDefaults(
    idNormalizedSessions,
    generationProfile,
    safeGeneratedPlan.totalWeeks,
    locale,
  ).map((session) => ({
    ...session,
    description: session.coachNote,
    status: "upcoming",
    workoutSteps: buildWorkoutSteps(session),
  }));

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  await adminClient
    .from("plan_versions")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  const versionId = crypto.randomUUID();
  const planJson = {
    ...safeGeneratedPlan,
    id: versionId,
    currentWeekNumber: safeGeneratedPlan.currentWeekNumber ?? 1,
    supportSessions: filteredSupportSessions,
    sessions: sessionsWithSteps,
  };

  const { error: insertError } = await adminClient.from("plan_versions").insert(
    {
      id: versionId,
      user_id: userId,
      generated_at: new Date().toISOString(),
      requested_by: requestedBy,
      is_active: true,
      schema_version: 1,
      data: planJson,
    },
  );

  if (insertError) {
    console.error("Failed to save plan version:", insertError);
    return new Response(
      JSON.stringify({
        error: "Failed to save plan",
        detail: insertError.message,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ versionId, plan: planJson }), {
    headers: { "Content-Type": "application/json" },
  });
});

function normalizeLocale(value: unknown): CoachLocale {
  if (typeof value === "string") {
    return value.toLowerCase() === "es" ? "es" : "en";
  }
  return "en";
}

function isRecord(value: unknown): value is ProfileShape {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function buildGenerationProfile(
  storedProfile: ProfileShape | null,
  input: GeneratePlanRequest["professionalPlanInput"],
): ProfileShape {
  const baseProfile: ProfileShape = storedProfile ? { ...storedProfile } : {};
  if (input == null) {
    return baseProfile;
  }

  const profile: ProfileShape = {
    ...baseProfile,
    goal: input.goal,
    schedule: input.schedule,
    health: input.health,
    strengthPreferences: input.strengthPreferences,
    planIntensity: input.planIntensity,
    acceptedRaceTarget: input.acceptedRaceTarget,
    unitPreference: input.unitPreference,
    locale: input.locale,
    raceCourseTerrain: input.raceCourseTerrain,
    fitnessSource: input.fitnessSource,
    currentWeekNumber: 1,
  };

  const priorFitness = isRecord(profile.fitness) ? { ...profile.fitness } : {};
  const sanitizeFitnessSource = (value: unknown): JsonObject => {
    if (!isRecord(value)) return {};

    const cleaned = { ...value };
    delete cleaned.stravaCoachingProfile;
    delete cleaned.athleteSummary;
    delete cleaned.activities;
    delete cleaned.activityNames;
    delete cleaned.activityStreams;
    delete cleaned.tokens;
    delete cleaned.stravaError;
    delete cleaned.upstreamError;
    delete cleaned.upstreamErrorBodies;
    return cleaned;
  };

  const priorFitnessClean = sanitizeFitnessSource(priorFitness);
  const stravaPayload = sanitizeFitnessSource(input.stravaCoachingProfile);

  if (input.fitnessSource === "manual") {
    const manualFitness: JsonObject = {
      ...priorFitnessClean,
      fitnessSource: "manual",
      experience: input.manualFitness?.experience,
      weeklyVolume: input.manualFitness?.weeklyVolume,
      longestRun: input.manualFitness?.longestRun,
      canCompleteGoalDistance: input.manualFitness?.canCompleteGoalDistance,
      raceDistanceBefore: input.manualFitness?.raceDistanceBefore,
      benchmark: input.manualFitness?.benchmark,
      benchmarkTimeMs: input.manualFitness?.benchmarkTimeMs,
    };
    delete manualFitness.stravaCoachingProfile;

    profile.fitness = manualFitness;
    profile.manualFitness = input.manualFitness;
    delete profile.stravaCoachingProfile;
    return profile;
  }

  const stravaFitness: JsonObject = {
    ...priorFitnessClean,
    fitnessSource: "strava",
    stravaCoachingProfile: stravaPayload,
  };
  profile.fitness = stravaFitness;
  if (input.stravaCoachingProfile != null) {
    profile.stravaCoachingProfile = stravaPayload;
  } else {
    delete profile.stravaCoachingProfile;
  }
  if (input.manualFitness != null) {
    profile.manualFitness = input.manualFitness;
  } else {
    delete profile.manualFitness;
  }

  return profile;
}

function pickStravaSnapshot(
  source: unknown,
): ProfileShape | undefined {
  if (!isRecord(source)) {
    return undefined;
  }

  const allowedKeys = [
    "dataConfidence",
    "terrain",
    "provenance",
    "trainingBase",
    "endurance",
    "speedMarkers",
    "paceZones",
    "recoveryGuardrails",
    "raceTargets",
    "planFocus",
  ];

  const snapshot: ProfileShape = {};
  for (const key of allowedKeys) {
    if (key in source) {
      snapshot[key] = source[key];
    }
  }

  return snapshot;
}

function withoutGoalDate(profile: ProfileShape): ProfileShape {
  const goal = isRecord(profile.goal) ? { ...profile.goal } : {};
  delete goal.raceDate;

  return {
    ...profile,
    goal,
  };
}

function sanitizeStravaSnapshot(source: unknown): ProfileShape | null {
  const snapshot = pickStravaSnapshot(source);
  const parsed = StravaCoachingProfileSnapshotSchema.safeParse(snapshot);
  return parsed.success ? parsed.data : null;
}
