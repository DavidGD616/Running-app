import OpenAI from "openai";
import {
  type GeneratedPlan,
  GeneratedPlanSchema,
  StravaCoachingProfileInputSchema,
  trainingPlanResponseJsonSchema,
} from "./schema.ts";

const DEFAULT_OPENAI_MODEL = "gpt-5.4-mini";

type SupportedLocale = "en" | "es";

type ProfileForPlan = Record<string, unknown>;

const SAFE_TOP_LEVEL_PROFILE_KEYS = [
  "goal",
  "schedule",
  "health",
  "strengthPreferences",
  "acceptedRaceTarget",
  "planIntensity",
  "unitPreference",
  "locale",
  "raceCourseTerrain",
  "fitnessSource",
  "fitness",
  "manualFitness",
  "stravaCoachingProfile",
  "currentWeekNumber",
] as const;

const UNSAFE_PROFILE_KEYS = [
  "activities",
  "tokens",
  "activityStreams",
  "activityNames",
  "upstreamErrorBodies",
  "upstreamError",
  "stravaError",
  "athleteSummary",
  "stravaProfile",
  "rawActivities",
  "rawActivityStreams",
] as const;

const UNSAFE_STRAVA_PROFILE_KEYS = [
  "activityNames",
  "activityStreams",
  "upstreamError",
  "upstreamErrorBodies",
  "stravaError",
  "stravaProfile",
  "tokens",
  "rawActivities",
  "rawActivityStreams",
] as const;

const SAFE_FITNESS_KEYS = [
  "fitnessSource",
  "experience",
  "weeklyVolume",
  "longestRun",
  "canCompleteGoalDistance",
  "raceDistanceBefore",
  "benchmark",
  "benchmarkTimeMs",
  "stravaCoachingProfile",
] as const;

const SAFE_MANUAL_FITNESS_KEYS = [
  "experience",
  "weeklyVolume",
  "longestRun",
  "canCompleteGoalDistance",
  "raceDistanceBefore",
  "benchmark",
  "benchmarkTimeMs",
] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

export function sanitizeStravaCoachingProfileForPrompt(
  raw: unknown,
): Record<string, unknown> | undefined {
  if (!isRecord(raw)) return undefined;

  const sanitizedRaw: Record<string, unknown> = { ...raw };
  for (const key of UNSAFE_STRAVA_PROFILE_KEYS) {
    delete sanitizedRaw[key];
  }

  const sanitized = StravaCoachingProfileInputSchema.safeParse(sanitizedRaw);
  return sanitized.success ? sanitized.data : undefined;
}

function sanitizeTopLevelProfileForOpenAi(profileData: ProfileForPlan): ProfileForPlan {
  const sanitized: ProfileForPlan = {};
  for (const key of SAFE_TOP_LEVEL_PROFILE_KEYS) {
    if (key in profileData) {
      sanitized[key] = profileData[key];
    }
  }

  for (const key of UNSAFE_PROFILE_KEYS) {
    delete sanitized[key];
  }

  return sanitized;
}

function sanitizeFitnessForOpenAi(value: unknown): ProfileForPlan {
  if (!isRecord(value)) return {};

  const sanitizedFitness: ProfileForPlan = {};
  for (const key of SAFE_FITNESS_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedFitness[key] = value[key];
    }
  }

  const nestedProfile = sanitizeStravaCoachingProfileForPrompt(
    sanitizedFitness.stravaCoachingProfile,
  );
  if (nestedProfile == null) {
    delete sanitizedFitness.stravaCoachingProfile;
  } else {
    sanitizedFitness.stravaCoachingProfile = nestedProfile;
  }

  return sanitizedFitness;
}

function sanitizeManualFitnessForOpenAi(value: unknown): ProfileForPlan | undefined {
  if (!isRecord(value)) return undefined;

  const sanitizedManualFitness: ProfileForPlan = {};
  for (const key of SAFE_MANUAL_FITNESS_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedManualFitness[key] = value[key];
    }
  }

  return sanitizedManualFitness;
}

export function sanitizeProfileForOpenAi(
  profileData: ProfileForPlan,
): ProfileForPlan {
  const sanitized = sanitizeTopLevelProfileForOpenAi(profileData);

  const directProfile = sanitizeStravaCoachingProfileForPrompt(
    sanitized.stravaCoachingProfile,
  );
  if (directProfile == null) {
    delete sanitized.stravaCoachingProfile;
  } else {
    sanitized.stravaCoachingProfile = directProfile;
  }

  if (isRecord(sanitized.fitness)) {
    const sanitizedFitness = sanitizeFitnessForOpenAi(sanitized.fitness);
    sanitized.fitness = sanitizedFitness;
  }

  const sanitizedManual = sanitizeManualFitnessForOpenAi(profileData.manualFitness);
  if (sanitizedManual == null) {
    delete sanitized.manualFitness;
  } else {
    sanitized.manualFitness = sanitizedManual;
  }

  return sanitized;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function resolveOpenAiModel(modelFromEnv: string | undefined): string {
  if (modelFromEnv == null) {
    return DEFAULT_OPENAI_MODEL;
  }

  const normalizedModel = modelFromEnv.trim();
  if (normalizedModel.length === 0) {
    throw new Error(
      "OPENAI_MODEL is set but empty. Provide a valid model name or unset OPENAI_MODEL to use the default model.",
    );
  }
  if (/\s/u.test(normalizedModel)) {
    throw new Error(
      `OPENAI_MODEL is invalid: "${normalizedModel}". Model names must not contain whitespace.`,
    );
  }

  return normalizedModel;
}

function coachLanguageInstruction(locale: SupportedLocale): string {
  return locale === "es"
    ? "AI-written coaching text in Spanish, including coachNote, race guidance fields, and support session notes."
    : "AI-written coaching text in English, including coachNote, race guidance fields, and support session notes.";
}

function buildPrompt(
  profileData: ProfileForPlan,
  locale: SupportedLocale,
): string {
  const goal = typeof profileData.goal === "object" && profileData.goal != null
    ? profileData.goal as Record<string, unknown>
    : {};
  const hasRaceDate = typeof goal.raceDate === "string" &&
    goal.raceDate.length > 0;

  const raceDateGuidance = hasRaceDate
    ? "The provided goal race date is a planning anchor only: keep all sessions on or before that date, and do not generate a dedicated race-day session."
    : "This runner has no fixed race date; build toward a final goal-oriented week without adding a fake goal-day session.";

  return `You are an expert running coach. Generate a personalized training plan based on the runner profile provided.

This app is phone-first. Use effort-based guidance, duration, distance, and mobile-readable coaching cues. Avoid heart-rate zones, power, and watch-only metrics.

Apply profile constraints directly from the input object fields. If fitness has stravaCoachingProfile, prioritize its calibrated inputs over self-reported fields.
If stravaCoachingProfile is present, use its structured signal (pace zones, training indicators, and race target estimates) as the stronger source. If no Strava profile exists, use self-reported fields.

IMPORTANT: Do not create raceDay or dedicated goal-race sessions. The goal race is guidance-only, represented in raceGuidance and race guidance notes.
${raceDateGuidance}

All session workoutTarget and zone pace values must be numeric seconds-per-kilometre integers (e.g., 360, not strings like "6:00/km").

${coachLanguageInstruction(locale)}

Return one complete training plan object matching the JSON schema exactly. Include:
- sessions (run and rest sessions only).
- supportSessions for strength/mobility support work.
- paceZones with all required zone keys.
- raceGuidance with race day execution guidance.
- stravaCoachingProfileSnapshot as a curated Strava coaching summary.
- generatedLocale exactly in ${locale}.
- schemaVersion and currentWeekNumber fields.

Use existing session fields to stay deterministic with legacy pipeline transforms.
`;
}

function expectedWeeksInstruction(expectedTotalWeeks: number | null): string {
  if (expectedTotalWeeks == null) return "";
  return `Return totalWeeks=${expectedTotalWeeks}, and cover weekNumber values from 1 through ${expectedTotalWeeks}.`;
}

export function buildGeneratePlanMessages(
  profileData: ProfileForPlan,
  locale: SupportedLocale,
  expectedTotalWeeks: number | null = null,
): Array<{ role: "system" | "user" | "assistant"; content: string }> {
  const sanitizedProfile = sanitizeProfileForOpenAi(profileData);
  const systemPrompt = `${buildPrompt(sanitizedProfile, locale)} ${
    expectedWeeksInstruction(expectedTotalWeeks)
  }`.trim();
  const userPrompt = `Runner profile:\n${
    JSON.stringify(sanitizedProfile, null, 2)
  }`;

  return [
    { role: "system", content: systemPrompt },
    { role: "user", content: userPrompt },
  ];
}

export function parseGeneratedPlanContent(
  content: string | null | undefined,
): GeneratedPlan {
  if (!content) {
    throw new Error("OpenAI returned no content");
  }

  let raw: unknown;
  try {
    raw = JSON.parse(content);
  } catch (error) {
    throw new Error(`Failed to parse OpenAI response JSON: ${String(error)}`);
  }

  return GeneratedPlanSchema.parse(raw);
}

export async function generatePlanFromProfile(
  profileData: ProfileForPlan,
  locale: SupportedLocale = "en",
  expectedTotalWeeks: number | null = null,
): Promise<GeneratedPlan> {
  const client = new OpenAI({ apiKey: requireEnv("OPENAI_API_KEY") });
  const model = resolveOpenAiModel(Deno.env.get("OPENAI_MODEL") ?? undefined);
  const messages = buildGeneratePlanMessages(
    profileData,
    locale,
    expectedTotalWeeks,
  );

  const completion = await client.chat.completions.create({
    model,
    messages,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "training_plan",
        strict: true,
        schema: trainingPlanResponseJsonSchema,
      },
    },
  });

  const content = completion.choices[0]?.message?.content;
  return parseGeneratedPlanContent(content);
}

export { trainingPlanResponseJsonSchema };
