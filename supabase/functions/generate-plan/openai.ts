import OpenAI from "openai";
import {
  type GeneratedPlan,
  GeneratedPlanSchema,
  StravaCoachingProfileInputSchema,
  trainingPlanResponseJsonSchema,
} from "./schema.ts";
import type { CoachingBrief } from "./coaching-brief.ts";

const DEFAULT_OPENAI_MODEL = "gpt-5.4-mini";

type SupportedLocale = "en" | "es";

type ProfileForPlan = Record<string, unknown>;
type CoachingBriefForPrompt = CoachingBrief | Record<string, unknown>;

export type StravaActivitySummaryForEvidence = {
  recorded_at?: string | null;
  activity_type?: string | null;
  sport_type?: string | null;
  distance_meters?: number | null;
  moving_time_seconds?: number | null;
  elapsed_time_seconds?: number | null;
  average_speed_mps?: number | null;
  elevation_gain_meters?: number | null;
};

export type BackendEvidenceDerivation = {
  backendEvidence: Array<{
    metric: string;
    date: string;
    value: number;
    unit: string;
  }>;
  dataConfidence: "high" | "medium" | "limited";
  activityCount: number;
  runActivityCount: number;
  dataFromDate: string | null;
  dataThroughDate: string | null;
};

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

const SAFE_GOAL_KEYS = [
  "race",
  "hasRaceDate",
  "raceDate",
] as const;

const SAFE_ACCEPTED_RACE_TARGET_KEYS = [
  "distanceKm",
  "primaryTimeMs",
  "stretchTimeMs",
  "confidence",
  "evidence",
] as const;

const SAFE_SCHEDULE_KEYS = [
  "trainingDays",
  "longRunDay",
  "weekdayTime",
  "weekendTime",
  "hardDays",
  "preferredTimeOfDay",
  "planStartDate",
] as const;

const SAFE_COACHING_BRIEF_KEYS = [
  "raceType",
  "readinessLevel",
  "confidence",
  "source",
  "currentVolumeKmPerWeek",
  "currentRunsPerWeek",
  "recentLongRunKm",
  "planLengthWeeks",
  "phaseStrategy",
  "maxWeeklyVolumeKm",
  "longRunCeilingKm",
  "weeklyRunDays",
  "taper",
  "workoutEmphasis",
  "evidenceTarget",
  "ambitiousTarget",
  "constraints",
  "rationale",
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

function sanitizeTopLevelProfileForOpenAi(
  profileData: ProfileForPlan,
): ProfileForPlan {
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

function sanitizeScheduleForOpenAi(value: unknown): ProfileForPlan | undefined {
  if (!isRecord(value)) return undefined;

  const sanitizedSchedule: ProfileForPlan = {};
  for (const key of SAFE_SCHEDULE_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedSchedule[key] = value[key];
    }
  }

  const parsedPlanStartDate = parsePlanStartDate(
    sanitizedSchedule.planStartDate,
  );
  if (parsedPlanStartDate == null) {
    delete sanitizedSchedule.planStartDate;
  } else {
    sanitizedSchedule.planStartDate = parsedPlanStartDate;
  }

  return sanitizedSchedule;
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

function sanitizeManualFitnessForOpenAi(
  value: unknown,
): ProfileForPlan | undefined {
  if (!isRecord(value)) return undefined;

  const sanitizedManualFitness: ProfileForPlan = {};
  for (const key of SAFE_MANUAL_FITNESS_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedManualFitness[key] = value[key];
    }
  }

  return sanitizedManualFitness;
}

function sanitizeGoalForOpenAi(value: unknown): ProfileForPlan | undefined {
  if (!isRecord(value)) return undefined;

  const sanitizedGoal: ProfileForPlan = {};
  for (const key of SAFE_GOAL_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedGoal[key] = value[key];
    }
  }

  return sanitizedGoal;
}

function sanitizeAcceptedRaceTargetForOpenAi(
  value: unknown,
): ProfileForPlan | undefined {
  if (!isRecord(value)) return undefined;

  const sanitizedTarget: ProfileForPlan = {};
  for (const key of SAFE_ACCEPTED_RACE_TARGET_KEYS) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      sanitizedTarget[key] = value[key];
    }
  }

  return sanitizedTarget;
}

export function sanitizeProfileForOpenAi(
  profileData: ProfileForPlan,
): ProfileForPlan {
  const sanitized = sanitizeTopLevelProfileForOpenAi(profileData);

  const sanitizedGoal = sanitizeGoalForOpenAi(sanitized.goal);
  if (sanitizedGoal == null) {
    delete sanitized.goal;
  } else {
    sanitized.goal = sanitizedGoal;
  }

  const sanitizedAcceptedTarget = sanitizeAcceptedRaceTargetForOpenAi(
    sanitized.acceptedRaceTarget,
  );
  if (sanitizedAcceptedTarget == null) {
    delete sanitized.acceptedRaceTarget;
  } else {
    sanitized.acceptedRaceTarget = sanitizedAcceptedTarget;
  }

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

  if (isRecord(sanitized.schedule)) {
    const sanitizedSchedule = sanitizeScheduleForOpenAi(sanitized.schedule);
    if (sanitizedSchedule == null) {
      delete sanitized.schedule;
    } else {
      sanitized.schedule = sanitizedSchedule;
    }
  }

  const sanitizedManual = sanitizeManualFitnessForOpenAi(
    profileData.manualFitness,
  );
  if (sanitizedManual == null) {
    delete sanitized.manualFitness;
  } else {
    sanitized.manualFitness = sanitizedManual;
  }

  return sanitized;
}

export function sanitizeCoachingBriefForOpenAi(
  coachingBrief: CoachingBriefForPrompt | null | undefined,
): ProfileForPlan | undefined {
  if (!isRecord(coachingBrief)) return undefined;

  const sanitized: ProfileForPlan = {};
  for (const key of SAFE_COACHING_BRIEF_KEYS) {
    if (Object.prototype.hasOwnProperty.call(coachingBrief, key)) {
      sanitized[key] = coachingBrief[key];
    }
  }
  return sanitized;
}

export function deriveBackendEvidenceFromStravaSummaries(
  rows: readonly StravaActivitySummaryForEvidence[],
): BackendEvidenceDerivation | null {
  const parsedRows = rows
    .map((row) => {
      const recordedAt = parseIsoDateMs(row.recorded_at);
      const distanceMeters = finiteNonNegativeNumber(row.distance_meters);
      if (recordedAt == null || distanceMeters == null) return null;
      return {
        recordedAt,
        date: new Date(recordedAt).toISOString().slice(0, 10),
        activityType: row.activity_type,
        sportType: row.sport_type,
        distanceKm: distanceMeters / 1000,
      };
    })
    .filter((row): row is NonNullable<typeof row> => row != null)
    .sort((a, b) => b.recordedAt - a.recordedAt);

  if (parsedRows.length === 0) return null;

  const runRows = parsedRows.filter((row) =>
    isRunActivityType(row.sportType) || isRunActivityType(row.activityType)
  );
  if (runRows.length === 0) return null;

  const dataThroughMs = runRows[0].recordedAt;
  const dataFromMs = runRows[runRows.length - 1].recordedAt;
  const recentVolumeWindowStart = dataThroughMs - 28 * 24 * 60 * 60 * 1000;
  const recentLongRunWindowStart = dataThroughMs - 56 * 24 * 60 * 60 * 1000;
  const volumeRows = runRows.filter((row) =>
    row.recordedAt >= recentVolumeWindowStart
  );
  const longRunRows = runRows.filter((row) =>
    row.recordedAt >= recentLongRunWindowStart
  );
  const volumeDistanceKm = volumeRows.reduce(
    (sum, row) => sum + row.distanceKm,
    0,
  );
  const longestRecentRunKm = Math.max(
    ...longRunRows.map((row) => row.distanceKm),
  );
  const weeklyVolumeKm = round1(volumeDistanceKm / 4);
  const runsPerWeek = round1(volumeRows.length / 4);
  const recentLongRunKm = round1(longestRecentRunKm);
  const dataThroughDate = new Date(dataThroughMs).toISOString().slice(0, 10);
  const dataFromDate = new Date(dataFromMs).toISOString().slice(0, 10);
  const dataConfidence = volumeRows.length >= 8 && weeklyVolumeKm > 0 &&
      recentLongRunKm > 0
    ? "high"
    : volumeRows.length >= 3
    ? "medium"
    : "limited";

  return {
    backendEvidence: [
      {
        metric: "training_base_weekly_km",
        date: dataThroughDate,
        value: weeklyVolumeKm,
        unit: "km/week",
      },
      {
        metric: "training_base_runs_per_week",
        date: dataThroughDate,
        value: runsPerWeek,
        unit: "runs/week",
      },
      {
        metric: "endurance_long_run_km",
        date: dataThroughDate,
        value: recentLongRunKm,
        unit: "km",
      },
    ],
    dataConfidence,
    activityCount: parsedRows.length,
    runActivityCount: runRows.length,
    dataFromDate,
    dataThroughDate,
  };
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
    ? "AI-written coaching text in Spanish, including coachNote and race guidance fields."
    : "AI-written coaching text in English, including coachNote and race guidance fields.";
}

const DATE_ONLY_REGEX = /^\d{4}-\d{2}-\d{2}$/;

function parsePlanStartDate(value: unknown): string | undefined {
  if (typeof value !== "string" || !DATE_ONLY_REGEX.test(value)) {
    return undefined;
  }

  const [year, month, day] = value
    .split("-")
    .map((part) => Number.parseInt(part, 10));
  const parsed = new Date(Date.UTC(year, month - 1, day));

  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return undefined;
  }

  return value;
}

function parseIsoDateMs(value: unknown): number | null {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

function finiteNonNegativeNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : null;
}

function isRunActivityType(value: unknown): boolean {
  return typeof value === "string" && /run/i.test(value);
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function weekStartMondayForDateOnly(dateOnly: string): string | undefined {
  if (typeof dateOnly !== "string" || !DATE_ONLY_REGEX.test(dateOnly)) {
    return undefined;
  }

  const [year, month, day] = dateOnly
    .split("-")
    .map((part) => Number.parseInt(part, 10));
  const date = new Date(Date.UTC(year, month - 1, day));
  const weekday = date.getUTCDay();
  const daysSinceMonday = (weekday + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday);

  const isoMonth = String(date.getUTCMonth() + 1).padStart(2, "0");
  const isoDay = String(date.getUTCDate()).padStart(2, "0");
  return `${date.getUTCFullYear()}-${isoMonth}-${isoDay}`;
}

function planStartDateFromProfile(
  profileData: ProfileForPlan,
): string | undefined {
  const schedule =
    typeof profileData.schedule === "object" && profileData.schedule != null
      ? profileData.schedule as Record<string, unknown>
      : undefined;
  return parsePlanStartDate(schedule?.planStartDate);
}

function planStartDateGuidance(profileData: ProfileForPlan): string {
  const planStartDate = planStartDateFromProfile(profileData);
  if (planStartDate == null) {
    return "";
  }

  const weekOneMonday = weekStartMondayForDateOnly(planStartDate) ??
    planStartDate;

  return `If provided, use planStartDate (${planStartDate}) as the first allowed session date. No sessions may be scheduled before ${planStartDate}. Week 1 starts on Monday ${weekOneMonday} (the Monday-Sunday containing planStartDate), and week numbering should use that Monday as the fixed week-1 anchor.`;
}

function buildPrompt(
  profileData: ProfileForPlan,
  locale: SupportedLocale,
  coachingBrief?: CoachingBriefForPrompt | null,
): string {
  const goal = typeof profileData.goal === "object" && profileData.goal != null
    ? profileData.goal as Record<string, unknown>
    : {};
  const hasRaceDate = typeof goal.raceDate === "string" &&
    goal.raceDate.length > 0;

  const raceDateGuidance = hasRaceDate
    ? "The provided goal race date is a planning anchor only: keep all sessions on or before that date, and do not generate a dedicated race-day session."
    : "This runner has no fixed race date; build toward a final goal-oriented week without adding a fake goal-day session.";

  const briefInstruction = coachingBrief == null
    ? "No backend coaching brief was supplied; use the sanitized runner profile conservatively."
    : "The backend coaching brief is the source of truth. Fill a plan within that brief rather than creating generic plan constraints. Use the brief for readiness, plan length, current volume anchor, max weekly volume, long-run ceiling, taper shape, target handling, phase strategy, and workout emphasis.";

  return `You are an expert running coach. Generate a personalized training plan by filling the backend coaching brief provided.

This app is phone-first. Use effort-based guidance, duration, distance, and mobile-readable coaching cues. Avoid heart-rate zones, power, and watch-only metrics.

${briefInstruction}

Apply profile constraints directly from the input object fields only when they do not conflict with the backend coaching brief. If fitness has stravaCoachingProfile, prioritize its calibrated inputs over self-reported fields, but do not override the backend coaching brief.
If stravaCoachingProfile is present, use its structured signal (pace zones, training indicators, and race target estimates) as supporting evidence. If no Strava profile exists, use self-reported fields as supporting evidence.

Critical brief requirements:
- Return totalWeeks exactly equal to coachingBrief.planLengthWeeks when a coaching brief is provided.
- Week 1 should stay near the brief's currentVolumeKmPerWeek when confidence is high; do not drop a trained runner to a beginner week.
- Never exceed coachingBrief.maxWeeklyVolumeKm in any week.
- Never exceed coachingBrief.longRunCeilingKm for a longRun.
- Follow coachingBrief.phaseStrategy and taper; final taper weeks should use taperRace phase.
- If coachingBrief.ambitiousTarget.supported is false, do not let that ambitious target drive workoutTarget, racePace sessions, or race-pace language. Use evidenceTarget or effort guidance instead.

IMPORTANT: Do not create strength, mobility, support, raceDay, or dedicated goal-race sessions. The goal race is guidance-only in raceGuidance; the backend will add one info-only Race Day item after validation.
${raceDateGuidance}

${planStartDateGuidance(profileData)}

All session workoutTarget and zone pace values must be numeric seconds-per-kilometre integers (e.g., 360, not strings like "6:00/km").

${coachLanguageInstruction(locale)}

Return one complete training plan object matching the JSON schema exactly. Include:
- sessions (run and rest sessions only).
- paceZones with all required zone keys.
- raceGuidance with race day execution guidance.
- stravaCoachingProfileSnapshot as a curated Strava coaching summary.
- coachingBriefSnapshot copied from the backend coaching brief when provided.
- planRationale, evidenceTarget, ambitiousTarget, confidence, and phaseStrategy aligned to the backend coaching brief.
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
  coachingBrief: CoachingBriefForPrompt | null = null,
): Array<{ role: "system" | "user" | "assistant"; content: string }> {
  const sanitizedProfile = sanitizeProfileForOpenAi(profileData);
  const sanitizedBrief = sanitizeCoachingBriefForOpenAi(coachingBrief);
  const systemPrompt = `${
    buildPrompt(sanitizedProfile, locale, sanitizedBrief)
  } ${expectedWeeksInstruction(expectedTotalWeeks)}`.trim();
  const briefPayload = sanitizedBrief == null
    ? "Backend coaching brief: null"
    : `Backend coaching brief:\n${JSON.stringify(sanitizedBrief, null, 2)}`;
  const userPrompt = `${briefPayload}\n\nRunner profile:\n${
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
  coachingBrief: CoachingBriefForPrompt | null = null,
): Promise<GeneratedPlan> {
  const client = new OpenAI({ apiKey: requireEnv("OPENAI_API_KEY") });
  const model = resolveOpenAiModel(Deno.env.get("OPENAI_MODEL") ?? undefined);
  const messages = buildGeneratePlanMessages(
    profileData,
    locale,
    expectedTotalWeeks,
    coachingBrief,
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
