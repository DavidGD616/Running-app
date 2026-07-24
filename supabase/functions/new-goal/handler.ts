import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

import { buildCoachingBrief } from "../generate-plan/coaching-brief.ts";
import {
  buildCandidatePlan,
  type CandidatePlan,
  type CandidateProfile,
} from "../generate-plan/candidate-builder.ts";
import {
  deriveBackendEvidenceFromStravaSummaries,
  sanitizeProfileForOpenAi,
  type StravaActivitySummaryForEvidence,
} from "../generate-plan/openai.ts";

type JsonObject = Record<string, unknown>;
type Goal = {
  race: SupportedRace;
  hasRaceDate: boolean;
  raceDate?: string;
};
type SupportedRace = z.infer<typeof SupportedRaceSchema>;
type EstimateConfidence = "high" | "medium" | "limited";
type NewGoalPlanMode =
  | "standard"
  | "short_fixed_date"
  | "race_support"
  | "no_fixed_date";
type SourceEvidence =
  | "manual"
  | "assessment"
  | "strava";

const DAY_MS = 86_400_000;
const SHORT_NOTICE_DAYS = 28;
const RACE_SUPPORT_DAYS = 6;
const EVIDENCE_WINDOW_DAYS = 84;

const SupportedRaceSchema = z.enum([
  "race_5k",
  "race_10k",
  "race_half_marathon",
  "race_marathon",
]);
const LocaleSchema = z.enum(["en", "es"]);
const DateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(
  (value) => parseDateOnly(value) != null,
  "Invalid calendar date",
);
const BaseRequestSchema = z.object({
  sourcePlanVersionId: z.string().min(1),
  race: SupportedRaceSchema,
  hasRaceDate: z.boolean(),
  raceDate: DateOnlySchema.nullish(),
  planStartDate: DateOnlySchema,
  locale: LocaleSchema,
  fitnessResult: z.object({
    source: z.enum(["manual", "assessment"]),
    distanceKm: z.number().positive().finite(),
    elapsedSeconds: z.number().int().positive(),
    recordedOn: DateOnlySchema,
    hardEffort: z.boolean(),
  }).strict().nullable().optional(),
}).strict().superRefine((value, ctx) => {
  if (value.hasRaceDate && value.raceDate == null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["raceDate"],
      message: "raceDate is required when hasRaceDate is true",
    });
  }
  if (!value.hasRaceDate && value.raceDate != null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["raceDate"],
      message: "raceDate must be omitted when hasRaceDate is false",
    });
  }
  if (value.hasRaceDate && value.raceDate != null) {
    const start = parseDateOnly(value.planStartDate)!;
    const race = parseDateOnly(value.raceDate)!;
    if (race.getTime() < start.getTime()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["raceDate"],
        message: "raceDate must not be before planStartDate",
      });
    }
  }
});

export const RecommendRequestSchema = z.object({
  action: z.literal("recommend"),
  ...BaseRequestSchema.shape,
});

export const PreviewRequestSchema = z.object({
  action: z.literal("preview"),
  ...BaseRequestSchema.shape,
});

export const AcceptRequestSchema = z.object({
  action: z.literal("accept"),
  proposalId: z.string().min(1),
}).strict();

const NewGoalRequestSchema = z.union([
  RecommendRequestSchema,
  PreviewRequestSchema,
  AcceptRequestSchema,
]);

type NewGoalRequest = z.infer<typeof NewGoalRequestSchema>;
export type RecommendRequest = z.infer<typeof RecommendRequestSchema>;
type PreviewRequest = z.infer<typeof PreviewRequestSchema>;
type AcceptRequest = z.infer<typeof AcceptRequestSchema>;
export type NewGoalRecommendationTimeline = {
  mode: NewGoalPlanMode;
  startDate: string;
  endDate: string;
  weeks: number;
  hasRaceDate: boolean;
  raceDate?: string;
  daysToRace?: number;
};
export type NewGoalRaceEstimate = {
  centerTimeSeconds: number;
  fasterTimeSeconds: number;
  slowerTimeSeconds: number;
  confidence: EstimateConfidence;
  evidence: Array<{
    source: SourceEvidence;
    recordedOn: string | null;
    reason: "manual_recent_hard_result" | "completed_assessment" | "strava_run";
  }>;
};

export type LoadedPreviewContext = {
  profile: JsonObject;
  sourcePlan: JsonObject;
  profileSchemaVersion: number;
  profileUpdatedAt: string;
  stravaSummaries: StravaActivitySummaryForEvidence[];
};

export type StoredProposal = {
  id: string;
  expires_at: string;
  [key: string]: unknown;
};

export type AcceptedProposal = {
  new_plan_version_id: string;
  plan_data: JsonObject;
  profile_data: JsonObject;
};

export type NewGoalDependencies = {
  authenticate(authHeader: string): Promise<string | null>;
  loadPreviewContext(
    userId: string,
    sourcePlanVersionId: string,
  ): Promise<LoadedPreviewContext | null>;
  buildCandidate(input: {
    profile: JsonObject;
    planStartDate: string;
    locale: "en" | "es";
  }): Promise<Response | CandidatePlan>;
  storeProposal(input: {
    userId: string;
    proposalId: string;
    sourcePlanVersionId: string;
    candidatePlan: JsonObject;
    proposedGoal: JsonObject;
    proposedProfileFragment: JsonObject;
    changeSummary: JsonObject;
    warnings: string[];
    suggestedTargetTimeSeconds: number | null;
    createdAt: string;
    expiresAt: string;
    sourceProfileSchemaVersion: number;
    sourceProfileUpdatedAt: string;
  }): Promise<StoredProposal>;
  acceptProposal(
    userId: string,
    proposalId: string,
    versionId: string,
    generatedAt: string,
  ): Promise<AcceptedProposal>;
  now(): Date;
  randomId(): string;
};

export function jsonResponse(
  body: JsonObject,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function createNewGoalHandler(
  dependencies: NewGoalDependencies,
): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method !== "POST") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const authHeader = request.headers.get("Authorization");
    if (authHeader == null || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "missing_authorization" }, 401);
    }

    const userId = await dependencies.authenticate(authHeader);
    if (userId == null) return jsonResponse({ error: "unauthorized" }, 401);

    const rawBody = await request.json().catch(() => null);
    const parsed = NewGoalRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return jsonResponse({ error: "invalid_request", detail: parsed.error.format() }, 400);
    }

    try {
      const typed = parsed.data;
      if (typed.action === "recommend") {
        return await recommendGoal(dependencies, userId, typed);
      }
      if (typed.action === "preview") {
        return await previewGoal(dependencies, userId, typed);
      }
      return await acceptGoal(dependencies, userId, typed);
    } catch (error) {
      const mapped = mapRpcError(error);
      if (mapped != null) {
        return jsonResponse({ error: mapped.key }, mapped.status);
      }
      console.error("new-goal failed", String(error));
      return jsonResponse({ error: "new_goal_failed" }, 500);
    }
  };
}

async function recommendGoal(
  dependencies: NewGoalDependencies,
  userId: string,
  request: RecommendRequest,
): Promise<Response> {
  const context = await dependencies.loadPreviewContext(
    userId,
    request.sourcePlanVersionId,
  );
  if (context == null) {
    return jsonResponse({ error: "source_plan_not_found" }, 409);
  }

  const proposedGoal: Goal = {
    race: request.race,
    hasRaceDate: request.hasRaceDate,
    ...(request.raceDate == null ? {} : { raceDate: request.raceDate }),
  };

  const recommendation = buildRecommendation(
    request,
    context.sourcePlan,
    context.profile,
    request.planStartDate,
  );
  const estimate = estimateRaceTarget({
    request,
    localDate: request.planStartDate,
    stravaSummaries: context.stravaSummaries,
  });
  const currentGoal = context.profile.goal;

  if (estimate == null) {
    const brief = buildCoachingBrief({
      profileData: {
        ...context.profile,
        goal: proposedGoal,
      },
      startDate: parseDateOnly(request.planStartDate)!,
      raceDate: recommendation.raceDate,
      requestedRaceType: request.race,
    });
    return jsonResponse({
      state: "fitness_check_required",
      sourceGoal: goalForResponse(context.profile),
      proposedGoal,
      recommendation,
      fitnessCheck: buildFitnessCheck({
        summaries: context.stravaSummaries,
        sourcePlan: context.sourcePlan,
        brief,
        planStartDate: request.planStartDate,
      }),
    });
  }

  return jsonResponse({
    sourceGoal: goalForResponse(context.profile),
    proposedGoal,
    recommendation,
    raceEstimate: estimate,
  });
}

async function previewGoal(
  dependencies: NewGoalDependencies,
  userId: string,
  request: PreviewRequest,
): Promise<Response> {
  const context = await dependencies.loadPreviewContext(
    userId,
    request.sourcePlanVersionId,
  );
  if (context == null) {
    return jsonResponse({ error: "source_plan_not_found" }, 409);
  }

  const proposedGoal: Goal = {
    race: request.race,
    hasRaceDate: request.hasRaceDate,
    ...(request.raceDate == null ? {} : { raceDate: request.raceDate }),
  };

  const recommendation = buildRecommendation(
    request,
    context.sourcePlan,
    context.profile,
    request.planStartDate,
  );
  const estimate = estimateRaceTarget({
    request,
    localDate: request.planStartDate,
    stravaSummaries: context.stravaSummaries,
  });

  if (estimate == null) {
    const brief = buildCoachingBrief({
      profileData: {
        ...context.profile,
        goal: proposedGoal,
      },
      startDate: parseDateOnly(request.planStartDate)!,
      raceDate: recommendation.raceDate,
      requestedRaceType: request.race,
    });
    return jsonResponse({
      state: "fitness_check_required",
      sourceGoal: goalForResponse(context.profile),
      proposedGoal,
      recommendation,
      fitnessCheck: buildFitnessCheck({
        summaries: context.stravaSummaries,
        sourcePlan: context.sourcePlan,
        brief,
        planStartDate: request.planStartDate,
      }),
    });
  }

  const proposedProfile = addBackendEvidence({
    ...context.profile,
    goal: proposedGoal,
  }, context.stravaSummaries);
  const acceptedRaceTarget = buildAcceptedRaceTarget({
    request,
    estimate,
    generatedAt: dependencies.now(),
    localDate: request.planStartDate,
  });

  const generationProfile = {
    ...proposedProfile,
    schedule: mergePlanStartDate(proposedProfile, request.planStartDate),
  } as CandidateProfile;

  const candidateResult = await dependencies.buildCandidate({
    profile: generationProfile,
    planStartDate: request.planStartDate,
    locale: request.locale,
  });
  if (candidateResult instanceof Response) {
    return candidateResult;
  }

  const now = dependencies.now();
  const proposalId = dependencies.randomId();
  const expiresAt = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  const stored = await dependencies.storeProposal({
    userId,
    proposalId,
    sourcePlanVersionId: request.sourcePlanVersionId,
    candidatePlan: candidateResult as JsonObject,
    proposedGoal,
    proposedProfileFragment: buildAllowedProfileFragment({
      profile: context.profile,
      proposalProfile: acceptedRaceTarget == null ? {} : { acceptedRaceTarget },
      requestedPlanStartDate: request.planStartDate,
      includeSchedule: true,
      includeTrainingPreferences: true,
      includeHealth: true,
  }),
    changeSummary: {
      sourceGoal: goalForResponse(context.profile),
      proposedGoal,
      recommendationMode: recommendation.mode,
    },
    warnings: [recommendation.mode],
    suggestedTargetTimeSeconds: estimate.centerTimeSeconds,
    createdAt: now.toISOString(),
    expiresAt,
    sourceProfileSchemaVersion: context.profileSchemaVersion,
    sourceProfileUpdatedAt: context.profileUpdatedAt,
  });

  return jsonResponse({
    sourceGoal: goalForResponse(context.profile),
    proposedGoal,
    recommendation,
    raceEstimate: estimate,
    proposalId: stored.id,
    sourcePlanVersionId: request.sourcePlanVersionId,
    expiresAt: stored.expires_at,
    candidatePlan: candidateResult,
  });
}

async function acceptGoal(
  dependencies: NewGoalDependencies,
  userId: string,
  request: AcceptRequest,
): Promise<Response> {
  const acceptedAt = dependencies.now().toISOString();
  const versionId = dependencies.randomId();
  const accepted = await dependencies.acceptProposal(
    userId,
    request.proposalId,
    versionId,
    acceptedAt,
  );
  return jsonResponse({
    versionId: accepted.new_plan_version_id,
    plan: accepted.plan_data,
    profile: accepted.profile_data,
  });
}

function raceDistanceKm(race: SupportedRace): number {
  return {
    race_5k: 5,
    race_10k: 10,
    race_half_marathon: 21.0975,
    race_marathon: 42.195,
  }[race];
}

function buildRecommendation(
  request: RecommendRequest | PreviewRequest,
  sourcePlan: JsonObject,
  profile: JsonObject,
  localDate: string,
): NewGoalRecommendationTimeline {
  const startDate = parseDateOnly(localDate)!;
  const hasRaceDate = request.hasRaceDate;
  const brief = buildCoachingBrief({
    profileData: {
      ...profile,
      goal: {
        race: request.race,
        hasRaceDate: request.hasRaceDate,
        ...(request.raceDate == null ? {} : { raceDate: request.raceDate }),
      },
    },
    startDate,
    raceDate: parseDateOnly(request.raceDate ?? "") ?? null,
    requestedRaceType: request.race,
  });
  const baseWeeks = brief.planLengthWeeks;
  if (!hasRaceDate) {
    return {
      mode: "no_fixed_date",
      startDate: request.planStartDate,
      endDate: addDays(startDate, baseWeeks * 7 - 1),
      weeks: baseWeeks,
      hasRaceDate: false,
    };
  }

  const raceDate = parseDateOnly(request.raceDate!)!;
  const daysToRace = Math.max(0, Math.round((raceDate.getTime() - startDate.getTime()) /
    DAY_MS));
  if (daysToRace <= RACE_SUPPORT_DAYS) {
    return {
      mode: "race_support",
      startDate: request.planStartDate,
      endDate: request.raceDate!,
      weeks: sourcePlanDurationWeeks(sourcePlan, daysToRace),
      hasRaceDate: true,
      raceDate: request.raceDate,
      daysToRace,
    };
  }
  if (daysToRace <= SHORT_NOTICE_DAYS) {
    return {
      mode: "short_fixed_date",
      startDate: request.planStartDate,
      endDate: request.raceDate!,
      weeks: sourcePlanDurationWeeks(sourcePlan, daysToRace),
      hasRaceDate: true,
      raceDate: request.raceDate,
      daysToRace,
    };
  }
  return {
    mode: "standard",
    startDate: request.planStartDate,
    endDate: request.raceDate!,
    weeks: sourcePlanDurationWeeks(sourcePlan, daysToRace),
    hasRaceDate: true,
    raceDate: request.raceDate,
    daysToRace,
  };
}

function sourcePlanDurationWeeks(sourcePlan: JsonObject, daysToRace: number): number {
  const rawCurrentWeek = numberOrNull((sourcePlan.currentWeekNumber as unknown)) ?? 1;
  return Math.max(
    1,
    Math.min(
      18,
      daysToRace > 0 ? Math.ceil(daysToRace / 7) : Math.max(1, rawCurrentWeek),
    numberOr(sourcePlan.totalWeeks, 1),
  ));
}

export function estimateRaceTarget(input: {
  request: RecommendRequest | PreviewRequest;
  localDate: string;
  stravaSummaries: StravaActivitySummaryForEvidence[];
}): NewGoalRaceEstimate | null {
  const manual = estimateFromManual({
    source: input.request.fitnessResult ?? null,
    race: input.request.race,
    localDate: input.localDate,
  });
  if (manual != null) return manual;
  return estimateFromStrava({
    summaries: input.stravaSummaries,
    race: input.request.race,
    localDate: input.localDate,
  });
}

function estimateFromManual(input: {
  source: RecommendRequest["fitnessResult"] | null;
  race: SupportedRace;
  localDate: string;
}): NewGoalRaceEstimate | null {
  if (input.source == null) return null;
  const source = input.source;
  if (!source.hardEffort) return null;
  const targetDistanceKm = raceDistanceKm(input.race);
  const recordedAt = parseDateOnly(source.recordedOn);
  if (recordedAt == null) return null;
  const localDate = parseDateOnly(input.localDate);
  if (localDate == null) return null;
  const ageDays = (localDate.getTime() - recordedAt.getTime()) / DAY_MS;
  if (ageDays < 0 || ageDays > EVIDENCE_WINDOW_DAYS) return null;
  const targetSeconds = Math.round(
    riegelSeconds(source.elapsedSeconds, source.distanceKm, targetDistanceKm),
  );
  if (!targetSeconds || targetSeconds <= 0) return null;

  const band = source.source === "assessment" ? 0.05 : 0.03;
  let confidence: EstimateConfidence = source.source === "assessment" ? "medium" : "high";
  if (input.race === "race_marathon" && !sameDistance(source.distanceKm, targetDistanceKm)) {
    confidence = "medium";
  }
  const faster = Math.max(1, Math.round(targetSeconds * (1 - band)));
  const slower = Math.max(faster + 1, Math.round(targetSeconds * (1 + band)));
  return {
    centerTimeSeconds: targetSeconds,
    fasterTimeSeconds: faster,
    slowerTimeSeconds: slower,
    confidence,
    evidence: [{
      source: source.source,
      recordedOn: source.recordedOn,
      reason: source.source === "assessment"
        ? "completed_assessment"
        : "manual_recent_hard_result",
    }],
  };
}

function estimateFromStrava(input: {
  summaries: StravaActivitySummaryForEvidence[];
  race: SupportedRace;
  localDate: string;
}): NewGoalRaceEstimate | null {
  const targetDistanceKm = raceDistanceKm(input.race);
  const localDate = parseDateOnly(input.localDate);
  if (localDate == null) return null;
  const parsed = input.summaries
    .map((summary) => {
      const recordedAt = parseDateOnly(trimDate(summary.recorded_at));
      const distance = finiteNumber(summary.distance_meters);
      const moving = finiteNumber(summary.moving_time_seconds);
      const elapsed = finiteNumber(summary.elapsed_time_seconds);
      const timeSeconds = moving ?? elapsed;
      const type = summary.activity_type ?? summary.sport_type;
      return {
        recordedAt,
        distanceKm: distance == null ? null : distance / 1000,
        timeSeconds,
        type,
      };
    })
    .filter((row): row is {
      recordedAt: Date;
      distanceKm: number;
      timeSeconds: number;
      type: unknown;
    } =>
      row.recordedAt != null &&
      row.distanceKm != null &&
      row.distanceKm >= 1 &&
      row.timeSeconds > 0 &&
      isRunType(row.type) &&
      row.recordedAt.getTime() <= localDate.getTime())
    .filter((row) =>
      (localDate.getTime() - row.recordedAt.getTime()) / DAY_MS <= EVIDENCE_WINDOW_DAYS
    )
    .map((row) => ({
      recordedOn: toDateOnly(row.recordedAt),
      estimatedSeconds: riegelSeconds(row.timeSeconds, row.distanceKm, targetDistanceKm),
      isSameDistance: sameDistance(row.distanceKm, targetDistanceKm),
      recordedAt: row.recordedAt.getTime(),
    }))
    .filter((row) => Number.isFinite(row.estimatedSeconds) && row.estimatedSeconds > 0)
    .sort((a, b) => b.recordedAt - a.recordedAt);

  if (parsed.length === 0) return null;

  const estimates = parsed
    .map((entry) => entry.estimatedSeconds);
  const centerTimeSeconds = Math.round(
    estimates.sort((a, b) => a - b)[Math.floor(estimates.length / 2)],
  );
  const hasSameDistance = parsed.some((entry) => entry.isSameDistance);
  let confidence: EstimateConfidence = hasSameDistance
    ? "medium"
    : parsed.length >= 3 ? "medium" : "limited";
  const band = confidence === "medium" ? 0.06 : 0.1;
  const faster = Math.max(1, Math.round(centerTimeSeconds * (1 - band)));
  const slower = Math.max(faster + 1, Math.round(centerTimeSeconds * (1 + band)));
  return {
    centerTimeSeconds,
    fasterTimeSeconds: faster,
    slowerTimeSeconds: slower,
    confidence,
    evidence: parsed.slice(0, 3).map((entry) => ({
      source: "strava",
      recordedOn: entry.recordedOn,
      reason: "strava_run",
    })),
  };
}

function buildAllowedProfileFragment(input: {
  profile: JsonObject;
  proposalProfile: JsonObject;
  requestedPlanStartDate: string;
  includeSchedule: boolean;
  includeTrainingPreferences: boolean;
  includeHealth: boolean;
}): JsonObject {
  const fragment: JsonObject = {};

  const accepted = input.proposalProfile.acceptedRaceTarget;
  if (accepted != null) {
    fragment.acceptedRaceTarget = accepted;
  }
  if (input.includeSchedule && isRecord(input.profile.schedule)) {
    fragment.schedule = {
      ...(input.profile.schedule as JsonObject),
      planStartDate: input.requestedPlanStartDate,
    };
  }
  if (input.includeTrainingPreferences && isRecord(input.profile.trainingPreferences)) {
    fragment.trainingPreferences = input.profile.trainingPreferences;
  }
  if (input.includeHealth && isRecord(input.profile.health)) {
    fragment.health = input.profile.health;
  }
  return fragment;
}

function buildAcceptedRaceTarget(input: {
  request: RecommendRequest | PreviewRequest;
  estimate: NewGoalRaceEstimate;
  generatedAt: Date;
  localDate: string;
}): JsonObject {
  return {
    distanceKm: raceDistanceKm(input.request.race),
    primaryTimeMs: input.estimate.centerTimeSeconds * 1000,
    confidence: input.estimate.confidence,
    estimate: {
      centerTimeMs: input.estimate.centerTimeSeconds * 1000,
      fasterTimeMs: input.estimate.fasterTimeSeconds * 1000,
      slowerTimeMs: input.estimate.slowerTimeSeconds * 1000,
      confidence: input.estimate.confidence,
      generatedAt: input.generatedAt.toISOString(),
      estimatorVersion: 1,
    },
    evidence: input.estimate.evidence,
    planStartDate: input.localDate,
  };
}

export function buildFitnessCheck(input: {
  summaries: StravaActivitySummaryForEvidence[];
  sourcePlan: JsonObject;
  brief: ReturnType<typeof buildCoachingBrief>;
  planStartDate: string;
}): {
  suggestedActivities: Array<{
    recordedOn: string;
    distanceKm: number;
    elapsedSeconds: number;
  }>;
  benchmark: {
    kind: "one_km_run" | "five_k_run";
    safeDates: string[];
  };
} {
  const local = parseDateOnly(input.planStartDate)!;
  const suggestedActivities = input.summaries.flatMap((summary) => {
    const row = summary as JsonObject;
    const recordedAt = typeof row.recorded_at === "string"
      ? row.recorded_at.slice(0, 10)
      : null;
    const distanceMeters = numberOrNull(row.distance_meters);
    const elapsedSeconds = numberOrNull(row.elapsed_time_seconds) ??
      numberOrNull(row.moving_time_seconds);
    const activity = `${row.activity_type ?? ""} ${row.sport_type ?? ""}`.toLowerCase();
    if (
      recordedAt == null ||
      distanceMeters == null ||
      elapsedSeconds == null ||
      !activity.includes("run") ||
      distanceMeters < 3000 ||
      elapsedSeconds < 1200
    ) {
      return [];
    }
    const date = parseDateOnly(recordedAt);
    if (date == null) return [];
    const ageDays = (local.getTime() - date.getTime()) / DAY_MS;
    if (ageDays < 0 || ageDays > EVIDENCE_WINDOW_DAYS) return [];
    return [{
      recordedOn: recordedAt,
      distanceKm: Math.round((distanceMeters / 1000) * 100) / 100,
      elapsedSeconds: Math.round(elapsedSeconds),
    }];
  }).slice(0, 3);

  const benchmarkKind: "one_km_run" | "five_k_run" = input.brief.recentLongRunKm >= 8 &&
      input.brief.currentRunsPerWeek >= 2
    ? "five_k_run"
    : "one_km_run";

  return {
    suggestedActivities,
    benchmark: {
      kind: benchmarkKind,
      safeDates: safeAssessmentDates(input.sourcePlan, input.planStartDate),
    },
  };
}

function safeAssessmentDates(sourcePlan: JsonObject, localDate: string): string[] {
  const hardDates = sessionsFromPlan(sourcePlan).filter((session) =>
    isHardOrLongSession(session)
  ).map((session) => session.date.slice(0, 10)).map(parseDateOnly).filter(
    (value): value is Date => value != null,
  );
  const start = parseDateOnly(localDate)!;
  const safe: string[] = [];
  for (let offset = 2; offset <= 14 && safe.length < 4; offset++) {
    const candidate = new Date(start.getTime() + offset * DAY_MS);
    const hasBuffer = hardDates.every((hardDate) =>
      Math.abs(candidate.getTime() - hardDate.getTime()) / DAY_MS >= 2
    );
    if (hasBuffer) safe.push(toDateOnly(candidate));
  }
  return safe;
}

function toDateOnly(from: Date): string {
  return from.toISOString().slice(0, 10);
}

function addDays(from: Date, days: number): string {
  return toDateOnly(new Date(from.getTime() + days * DAY_MS));
}

function dateOnlyFromMaybe(value: string): string {
  return parseDateOnly(value)?.toISOString().slice(0, 10) ?? value;
}

function dateOnlyFromDateOnly(value: string, offsetDays: number): string {
  return addDays(parseDateOnly(value) ?? new Date(), offsetDays);
}

function mergePlanStartDate(profile: JsonObject, planStartDate: string): JsonObject {
  const schedule = isRecord(profile.schedule) ? profile.schedule : {};
  return {
    ...schedule,
    planStartDate,
  };
}

function goalForResponse(profile: JsonObject): Goal {
  const goal = isRecord(profile.goal) ? profile.goal : {};
  const race = isSupportedRace(goal.race) ? goal.race : "race_10k";
  const hasRaceDate = typeof goal.hasRaceDate === "boolean"
    ? goal.hasRaceDate
    : false;
  const raceDate = hasRaceDate ? typeof goal.raceDate === "string"
    ? goal.raceDate
    : undefined
    : undefined;
  return {
    race,
    hasRaceDate,
    ...(raceDate == null ? {} : { raceDate }),
  };
}

export function mapRpcError(
  error: unknown,
): { key: string; status: number } | null {
  const message = errorMessage(error);
  const mappings: Array<[string, string, number]> = [
    ["new_goal_proposal_inconsistent", "proposal_inconsistent", 500],
    ["new_goal_proposal_not_found", "proposal_not_found", 404],
    ["new_goal_proposal_expired", "proposal_expired", 409],
    ["new_goal_proposal_not_pending", "proposal_not_pending", 409],
    ["new_goal_source_profile_stale", "source_profile_stale", 409],
    ["new_goal_source_plan_stale", "source_plan_stale", 409],
    ["new_goal_source_plan_not_active", "source_plan_stale", 409],
    ["new_goal_profile_fragment_restricted", "proposal_fragment_restricted", 400],
    ["new_goal_runner_profile_not_found", "profile_not_found", 404],
    ["new_goal_invalid_expiry", "invalid_expiry", 400],
  ];
  for (const [needle, key, status] of mappings) {
    if (message.includes(needle)) return { key, status };
  }
  return null;
}

export function createProductionDependencies(
  publicClient: SupabaseClient,
  admin: SupabaseClient,
): NewGoalDependencies {
  return {
    async authenticate(authHeader) {
      const jwt = authHeader.slice("Bearer ".length);
      const { data, error } = await publicClient.auth.getClaims(jwt);
      return error == null && typeof data?.claims?.sub === "string"
        ? data.claims.sub
        : null;
    },
    async loadPreviewContext(userId, sourcePlanVersionId) {
      const [profileResult, planResult, summaryResult] = await Promise.all([
        admin.from("runner_profiles").select("data,schema_version,updated_at").eq("user_id", userId).maybeSingle(),
        admin.from("plan_versions").select("id,data").eq("user_id", userId)
          .eq("id", sourcePlanVersionId)
          .eq("is_active", true).maybeSingle(),
        admin.from("strava_activity_summaries").select(
          "recorded_at,activity_type,sport_type,distance_meters,moving_time_seconds,elapsed_time_seconds,average_speed_mps,elevation_gain_meters",
        ).eq("user_id", userId).order("recorded_at", { ascending: false })
          .limit(120),
      ]);
      for (const result of [profileResult, planResult, summaryResult]) {
        if (result.error != null) throw result.error;
      }

      const profileRow = profileResult.data;
      const profileUpdatedAt = typeof profileRow?.updated_at === "string"
        ? profileRow.updated_at
        : profileRow?.updated_at instanceof Date
          ? profileRow.updated_at.toISOString()
          : null;
      const profileSchemaVersion = isInteger(profileRow?.schema_version)
        ? profileRow.schema_version
        : null;
      if (!isRecord(profileRow?.data) ||
          !isRecord(profileUpdatedAt) ||
          !isInteger(profileSchemaVersion) ||
          !isRecord(planResult.data?.data) ||
          !isString(planResult.data?.id)
      ) {
        return null;
      }

      return {
        profile: profileRow.data,
        sourcePlan: planResult.data.data,
        profileSchemaVersion,
        profileUpdatedAt,
        stravaSummaries: (summaryResult.data ?? []) as StravaActivitySummaryForEvidence[],
      };
    },
    async buildCandidate({ profile, planStartDate, locale }) {
      const generationStartedAt = parseDateOnly(planStartDate)!;
      const generatedStart = planStartDate;
      const generatedProfile = {
        ...profile,
        schedule: isRecord(profile.schedule)
          ? { ...(profile.schedule as JsonObject), planStartDate }
          : { planStartDate },
      };
      const goal = isRecord(generatedProfile.goal) ? generatedProfile.goal : {};
      const brief = buildCoachingBrief({
        profileData: generatedProfile,
        startDate: generationStartedAt,
        raceDate: parseDateOnly(
          isRecord(goal) && typeof goal.raceDate === "string"
            ? goal.raceDate
            : "",
        ),
        requestedRaceType: typeof goal.race === "string" ? goal.race : null,
      });
      const sanitized = sanitizeProfileForOpenAi(generatedProfile as unknown as JsonObject);
      return await buildCandidatePlan({
        generationProfileWithPlanStartDate: generatedProfile as CandidateProfile,
        sanitizedGenerationProfile: sanitized as CandidateProfile,
        generationStartedAt,
        resolvedPlanStartDate: generatedStart,
        locale,
        coachingBrief: brief,
        expectedWeeks: brief.planLengthWeeks,
        stravaSnapshotSource: isRecord((sanitized as JsonObject).fitness)
          ? isRecord((sanitized as JsonObject).fitness!.stravaCoachingProfile)
            ? sanitized.fitness.stravaCoachingProfile
            : undefined
          : undefined,
      });
    },
    async storeProposal(input) {
      const { data, error } = await admin.rpc("store_new_goal_proposal", {
        p_user_id: input.userId,
        p_proposal_id: input.proposalId,
        p_source_plan_version_id: input.sourcePlanVersionId,
        p_candidate_plan: input.candidatePlan,
        p_proposed_goal: input.proposedGoal,
        p_proposed_profile_fragment: input.proposedProfileFragment,
        p_change_summary: input.changeSummary,
        p_warnings: input.warnings,
        p_suggested_target_seconds: input.suggestedTargetTimeSeconds,
        p_created_at: input.createdAt,
        p_expires_at: input.expiresAt,
        p_source_profile_schema_version: input.sourceProfileSchemaVersion,
        p_source_profile_updated_at: input.sourceProfileUpdatedAt,
      });
      if (error != null) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (!isRecord(row) || typeof row.id !== "string" || typeof row.expires_at !== "string") {
        throw new Error("Invalid store_new_goal_proposal response");
      }
      return row as StoredProposal;
    },
    async acceptProposal(userId, proposalId, versionId, generatedAt) {
      const { data, error } = await admin.rpc("accept_new_goal_proposal", {
        p_user_id: userId,
        p_proposal_id: proposalId,
        p_new_plan_version_id: versionId,
        p_generated_at: generatedAt,
      });
      if (error != null) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (
        !isRecord(row) ||
        typeof row.new_plan_version_id !== "string" ||
        !isRecord(row.plan_data) ||
        !isRecord(row.profile_data)
      ) {
        throw new Error("Invalid accept_new_goal_proposal response");
      }
      return row as AcceptedProposal;
    },
    now: () => new Date(),
    randomId: () => crypto.randomUUID(),
  };
}

function trimDate(value: unknown): string {
  return typeof value === "string" ? value.slice(0, 10) : "";
}

function addBackendEvidence(
  profile: JsonObject,
  summaries: StravaActivitySummaryForEvidence[],
): JsonObject {
  const derived = deriveBackendEvidenceFromStravaSummaries(summaries);
  if (derived == null) return profile;
  const fitness = isRecord(profile.fitness) ? profile.fitness : {};
  return {
    ...profile,
    backendEvidence: derived.backendEvidence,
    evidence: {
      ...(isRecord(profile.evidence) ? profile.evidence : {}),
      dataConfidence: derived.dataConfidence,
    },
    fitness: {
      ...fitness,
      dataConfidence: derived.dataConfidence,
      currentVolumeKmPerWeek: evidenceValue(
        derived.backendEvidence,
        "training_base_weekly_km",
      ),
      currentRunsPerWeek: evidenceValue(
        derived.backendEvidence,
        "training_base_runs_per_week",
      ),
      recentLongRunKm: evidenceValue(
        derived.backendEvidence,
        "endurance_long_run_km",
      ),
    },
  };
}

function sessionsFromPlan(plan: JsonObject): { id: string; date: string; type: string }[] {
  if (!Array.isArray(plan.sessions)) return [];
  return plan.sessions.filter((session) => isRecord(session) &&
    typeof session.id === "string" &&
    typeof session.date === "string" &&
    parseDateOnly(session.date.slice(0, 10)) != null
  ).map((session) => ({
    id: String((session as JsonObject).id),
    date: String((session as JsonObject).date),
    type: String((session as JsonObject).type ?? ""),
  }));
}

function isHardOrLongSession(session: { type: string }): boolean {
  return new Set([
    "longRun",
    "tempoRun",
    "thresholdRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "progressionRun",
  ]).has(session.type);
}

function buildCoachingSummary(profile: JsonObject, request: NewGoalRequest): ReturnType<
  typeof buildCoachingBrief
> | null {
  const goal = {
    race: request.race,
    hasRaceDate: request.hasRaceDate,
    ...(request.raceDate == null ? {} : { raceDate: request.raceDate }),
  };
  try {
    return buildCoachingBrief({
      profileData: { ...profile, goal },
      startDate: parseDateOnly(request.planStartDate) ?? new Date(),
      raceDate: request.raceDate == null
        ? null
        : parseDateOnly(request.raceDate),
      requestedRaceType: request.race,
    });
  } catch (_) {
    return null;
  }
}

function parseDateOnly(value: string): Date | null {
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) &&
      date.toISOString().slice(0, 10) === value
    ? date
    : null;
}

function riegelSeconds(
  knownSeconds: number,
  knownDistanceKm: number,
  targetDistanceKm: number,
): number {
  return knownSeconds * Math.pow(targetDistanceKm / knownDistanceKm, 1.06);
}

function sameDistance(left: number, right: number): boolean {
  return Math.abs(left - right) <= Math.max(0.1, right * 0.02);
}

function isRunType(value: unknown): boolean {
  return typeof value === "string" && /run/i.test(value);
}

function isRecord(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function isString(value: unknown): value is string {
  return typeof value === "string";
}

function isInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value);
}

function numberOr(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function finiteNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (isRecord(error) && typeof error.message === "string") return error.message;
  return String(error);
}

function isSupportedRace(value: unknown): value is SupportedRace {
  return typeof value === "string" && SupportedRaceSchema.safeParse(value).success;
}
