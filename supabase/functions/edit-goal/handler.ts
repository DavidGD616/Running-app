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
type Session = JsonObject & { id: string; date: string };
type Goal = {
  race: SupportedRace;
  hasRaceDate: boolean;
  raceDate?: string;
};
type SupportedRace = z.infer<typeof SupportedRaceSchema>;
type EstimateConfidence = "high" | "medium" | "limited";
type FitnessResult = z.infer<typeof FitnessResultSchema>;

const DAY_MS = 86_400_000;
const SHORT_NOTICE_DAYS = 28;
const RACE_WEEK_DAYS = 6;
const EVIDENCE_WINDOW_DAYS = 84;
const SupportedRaceSchema = z.enum([
  "race_5k",
  "race_10k",
  "race_half_marathon",
  "race_marathon",
]);
const DateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(
  (value) => parseDateOnly(value) != null,
  "Invalid calendar date",
);
const FitnessResultSchema = z.object({
  source: z.enum(["manual", "assessment"]),
  distanceKm: z.number().positive().finite(),
  elapsedSeconds: z.number().int().positive(),
  recordedOn: DateOnlySchema,
  hardEffort: z.boolean(),
}).strict();

export const PreviewRequestSchema = z.object({
  action: z.literal("preview"),
  sourcePlanVersionId: z.string().min(1),
  race: SupportedRaceSchema,
  hasRaceDate: z.boolean(),
  raceDate: DateOnlySchema.nullish(),
  fitnessResult: FitnessResultSchema.optional(),
  localDate: DateOnlySchema,
  locale: z.enum(["en", "es"]),
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
    const local = parseDateOnly(value.localDate)!;
    const race = parseDateOnly(value.raceDate)!;
    if ((race.getTime() - local.getTime()) / DAY_MS < 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["raceDate"],
        message: "raceDate must not be before localDate",
      });
    }
  }
});

export const AcceptRequestSchema = z.object({
  action: z.literal("accept"),
  proposalId: z.string().min(1),
}).strict();

const EditGoalRequestSchema = z.union([
  PreviewRequestSchema,
  AcceptRequestSchema,
]);

export type PreviewRequest = z.infer<typeof PreviewRequestSchema>;
export type AcceptRequest = z.infer<typeof AcceptRequestSchema>;

export type LoadedPreviewContext = {
  profile: JsonObject;
  sourcePlan: JsonObject;
  activityLinkedSessionIds: string[];
  skipAdjustmentSessionIds: string[];
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

export type EditGoalDependencies = {
  authenticate(authHeader: string): Promise<string | null>;
  loadPreviewContext(
    userId: string,
    sourcePlanVersionId: string,
  ): Promise<LoadedPreviewContext | null>;
  buildCandidate(input: {
    profile: JsonObject;
    localDate: string;
    locale: "en" | "es";
  }): Promise<Response | CandidatePlan>;
  storeProposal(input: {
    userId: string;
    proposalId: string;
    sourcePlanVersionId: string;
    candidatePlan: JsonObject;
    proposedGoal: JsonObject;
    proposedProfileFragment: JsonObject;
    summary: GoalEditSummary;
    warnings: GoalEditWarning[];
    suggestedTargetTimeSeconds: number | null;
    createdAt: string;
    expiresAt: string;
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

export type GoalEditWarning =
  | "short_notice"
  | "race_week"
  | "readiness_gap"
  | "limited_evidence"
  | "no_fixed_date";
export type GoalEditRaceEstimate = {
  centerTimeSeconds: number;
  fasterTimeSeconds: number;
  slowerTimeSeconds: number;
  confidence: EstimateConfidence;
  evidence: Array<{
    source: "strava" | "manual" | "assessment";
    recordedOn: string | null;
    description: string;
  }>;
};

export type GoalEditFitnessCheck = {
  suggestedActivities: Array<{
    recordedOn: string;
    distanceKm: number;
    elapsedSeconds: number;
  }>;
  benchmark: {
    kind: "one_km_run" | "five_k_run";
    safeDates: string[];
  };
};
export type GoalEditSessionChange = {
  localDate: string;
  beforeSessionType: string | null;
  afterSessionType: string | null;
  beforeDurationMinutes: number | null;
  afterDurationMinutes: number | null;
  beforeDistanceKm: number | null;
  afterDistanceKm: number | null;
};
export type GoalEditSummary = {
  preservedCount: number;
  addedUpcomingCount: number;
  removedUpcomingCount: number;
  materiallyChangedUpcomingCount: number;
  addedUpcomingSessions: GoalEditSessionChange[];
  removedUpcomingSessions: GoalEditSessionChange[];
  materiallyChangedUpcomingSessions: GoalEditSessionChange[];
  totalWeeks: number;
  endDate: string | null;
};

export function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function createEditGoalHandler(
  dependencies: EditGoalDependencies,
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
    const parsed = EditGoalRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return jsonResponse({
        error: "invalid_request",
        detail: parsed.error.format(),
      }, 400);
    }

    try {
      return parsed.data.action === "preview"
        ? await previewGoal(dependencies, userId, parsed.data)
        : await acceptGoal(dependencies, userId, parsed.data);
    } catch (error) {
      const mapped = mapRpcError(error);
      if (mapped != null) {
        return jsonResponse({ error: mapped.key }, mapped.status);
      }
      console.error("edit-goal failed", String(error));
      return jsonResponse({ error: "edit_goal_failed" }, 500);
    }
  };
}

async function previewGoal(
  dependencies: EditGoalDependencies,
  userId: string,
  request: PreviewRequest,
): Promise<Response> {
  const context = await dependencies.loadPreviewContext(
    userId,
    request.sourcePlanVersionId,
  );
  if (context == null) {
    return jsonResponse({ error: "source_plan_stale" }, 409);
  }

  const proposedGoal = {
    race: request.race,
    hasRaceDate: request.hasRaceDate,
    ...(request.raceDate == null ? {} : { raceDate: request.raceDate }),
  };
  let proposedProfile: JsonObject = {
    ...context.profile,
    goal: proposedGoal,
  };
  proposedProfile = addBackendEvidence(
    proposedProfile,
    context.stravaSummaries,
  );

  const brief = buildCoachingBrief({
    profileData: proposedProfile,
    startDate: parseDateOnly(request.localDate)!,
    raceDate: request.raceDate == null ? null : parseDateOnly(request.raceDate),
    requestedRaceType: request.race,
  });
  const estimate = estimateFor({
    request,
    localDate: request.localDate,
  });
  if (estimate == null) {
    return jsonResponse({
      state: "fitness_check_required",
      sourcePlanVersionId: request.sourcePlanVersionId,
      fitnessCheck: buildFitnessCheck({
        summaries: context.stravaSummaries,
        sourcePlan: context.sourcePlan,
        brief,
        localDate: request.localDate,
      }),
    });
  }

  // The legacy field remains a generator compatibility seam. It is now the
  // evidence-supported centre of an app-owned estimate, never user input.
  const acceptedRaceTarget = {
    distanceKm: raceDistanceKm(request.race),
    primaryTimeMs: estimate.centerTimeSeconds * 1000,
    confidence: estimate.confidence,
    evidence: estimate.evidence,
    estimate: {
      centerTimeMs: estimate.centerTimeSeconds * 1000,
      fasterTimeMs: estimate.fasterTimeSeconds * 1000,
      slowerTimeMs: estimate.slowerTimeSeconds * 1000,
      confidence: estimate.confidence,
      generatedAt: dependencies.now().toISOString(),
      estimatorVersion: 1,
    },
  };
  proposedProfile = {
    ...proposedProfile,
    acceptedRaceTarget,
  };

  const candidateResult = await dependencies.buildCandidate({
    profile: proposedProfile,
    localDate: request.localDate,
    locale: request.locale,
  });
  if (candidateResult instanceof Response) return candidateResult;

  const safeCandidate = applyRaceWeekSafety(
    candidateResult as unknown as JsonObject,
    request,
  );
  const merged = mergeImmutableHistory({
    sourcePlan: context.sourcePlan,
    candidatePlan: safeCandidate,
    localDate: request.localDate,
    activityLinkedSessionIds: context.activityLinkedSessionIds,
    skipAdjustmentSessionIds: context.skipAdjustmentSessionIds,
  });
  const summary = summarizePlanChanges(
    context.sourcePlan,
    merged.plan,
    request.localDate,
    merged.preservedIds,
  );
  const warnings = buildWarnings(request, estimate, brief.readinessLevel);
  const now = dependencies.now();
  const proposalId = dependencies.randomId();
  const expiresAt = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  const stored = await dependencies.storeProposal({
    userId,
    proposalId,
    sourcePlanVersionId: request.sourcePlanVersionId,
    candidatePlan: merged.plan,
    proposedGoal,
    proposedProfileFragment: { acceptedRaceTarget },
    summary,
    warnings,
    suggestedTargetTimeSeconds: estimate.centerTimeSeconds,
    createdAt: now.toISOString(),
    expiresAt,
  });

  return jsonResponse({
    proposalId: stored.id,
    sourcePlanVersionId: request.sourcePlanVersionId,
    expiresAt: stored.expires_at,
    currentGoal: goalForResponse(context.profile),
    proposedGoal,
    candidatePlan: merged.plan,
    summary,
    warnings,
    raceEstimate: estimate,
  });
}

async function acceptGoal(
  dependencies: EditGoalDependencies,
  userId: string,
  request: AcceptRequest,
): Promise<Response> {
  const accepted = await dependencies.acceptProposal(
    userId,
    request.proposalId,
    dependencies.randomId(),
    dependencies.now().toISOString(),
  );
  return jsonResponse({
    versionId: accepted.new_plan_version_id,
    plan: accepted.plan_data,
    profile: accepted.profile_data,
  });
}

export function buildWarnings(
  request: Pick<PreviewRequest, "hasRaceDate" | "raceDate" | "localDate">,
  estimate: GoalEditRaceEstimate,
  readinessLevel: string,
): GoalEditWarning[] {
  const warnings: GoalEditWarning[] = [];
  if (!request.hasRaceDate) {
    warnings.push("no_fixed_date");
  } else if (request.raceDate != null) {
    const days = (parseDateOnly(request.raceDate)!.getTime() -
      parseDateOnly(request.localDate)!.getTime()) / DAY_MS;
    if (days <= RACE_WEEK_DAYS) {
      warnings.push("race_week");
    } else if (days <= SHORT_NOTICE_DAYS) {
      warnings.push("short_notice");
    }
  }
  if (readinessLevel === "underprepared") warnings.push("readiness_gap");
  if (estimate.confidence === "limited") warnings.push("limited_evidence");
  return warnings;
}

function estimateFor(input: {
  request: PreviewRequest;
  localDate: string;
}): GoalEditRaceEstimate | null {
  const targetDistanceKm = raceDistanceKm(input.request.race);
  const manual = input.request.fitnessResult;
  if (manual == null) return null;

  let centerTimeSeconds: number | null;
  let confidence: EstimateConfidence;
  let evidence: GoalEditRaceEstimate["evidence"];
  let manualWasCrossDistance = false;

  const recordedAt = parseDateOnly(manual.recordedOn)!;
  const localDate = parseDateOnly(input.localDate)!;
  const ageDays = (localDate.getTime() - recordedAt.getTime()) / DAY_MS;
  if (!manual.hardEffort || ageDays < 0 || ageDays > EVIDENCE_WINDOW_DAYS) {
    return null;
  }
  centerTimeSeconds = Math.round(
    riegelSeconds(manual.elapsedSeconds, manual.distanceKm, targetDistanceKm),
  );
  manualWasCrossDistance = !sameDistance(manual.distanceKm, targetDistanceKm);
  confidence = manualWasCrossDistance ? "medium" : "high";
  evidence = [{
    source: manual.source,
    recordedOn: manual.recordedOn,
    description: manual.source === "assessment"
      ? "Completed Edit Goal assessment"
      : "Recent hard running result",
  }];

  if (centerTimeSeconds == null || centerTimeSeconds <= 0) return null;
  if (input.request.race === "race_marathon" && manualWasCrossDistance) {
    confidence = downgradeConfidence(confidence);
  }
  const band = confidence === "high"
    ? { fast: 0.03, slow: 0.03 }
    : confidence === "medium"
    ? { fast: 0.06, slow: 0.06 }
    : { fast: 0.08, slow: 0.12 };
  const fasterTimeSeconds = Math.max(
    1,
    Math.round(centerTimeSeconds * (1 - band.fast)),
  );
  let slowerTimeSeconds = Math.max(
    fasterTimeSeconds + 1,
    Math.round(centerTimeSeconds * (1 + band.slow)),
  );
  if (input.request.race === "race_marathon" && manualWasCrossDistance) {
    slowerTimeSeconds = Math.max(slowerTimeSeconds, centerTimeSeconds + 600);
  }
  return {
    centerTimeSeconds,
    fasterTimeSeconds,
    slowerTimeSeconds,
    confidence,
    evidence,
  };
}

function buildFitnessCheck(input: {
  summaries: StravaActivitySummaryForEvidence[];
  sourcePlan: JsonObject;
  brief: ReturnType<typeof buildCoachingBrief>;
  localDate: string;
}): GoalEditFitnessCheck {
  const local = parseDateOnly(input.localDate)!;
  const suggestedActivities = input.summaries.flatMap((summary) => {
    const row = summary as unknown as JsonObject;
    const recordedAt = typeof row.recorded_at === "string"
      ? row.recorded_at.slice(0, 10)
      : null;
    const distanceMeters = numberOrNull(row.distance_meters);
    const elapsedSeconds = numberOrNull(row.moving_time_seconds) ??
      numberOrNull(row.elapsed_time_seconds);
    const activity = `${row.activity_type ?? ""} ${row.sport_type ?? ""}`
      .toLowerCase();
    if (
      recordedAt == null || distanceMeters == null || elapsedSeconds == null ||
      !activity.includes("run") || distanceMeters < 3000 ||
      elapsedSeconds < 1200
    ) return [];
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

  const kind = input.brief.recentLongRunKm >= 8 &&
      input.brief.currentRunsPerWeek >= 2 &&
      input.brief.readinessLevel !== "underprepared"
    ? "five_k_run"
    : "one_km_run";
  return {
    suggestedActivities,
    benchmark: {
      kind,
      safeDates: safeAssessmentDates(input.sourcePlan, input.localDate),
    },
  };
}

function safeAssessmentDates(
  sourcePlan: JsonObject,
  localDate: string,
): string[] {
  const hardDates = sessionsFromPlan(sourcePlan)
    .filter((session) => isHardOrLongSession(session))
    .map((session) => session.date.slice(0, 10))
    .map(parseDateOnly)
    .filter((date): date is Date => date != null);
  const start = parseDateOnly(localDate)!;
  const safe: string[] = [];
  for (let offset = 2; offset <= 14 && safe.length < 4; offset++) {
    const candidate = new Date(start.getTime() + offset * DAY_MS);
    const hasBuffer = hardDates.every((hardDate) =>
      Math.abs(candidate.getTime() - hardDate.getTime()) / DAY_MS >= 2
    );
    if (hasBuffer) safe.push(dateOnly(candidate));
  }
  return safe;
}

function applyRaceWeekSafety(
  candidatePlan: JsonObject,
  request: Pick<PreviewRequest, "hasRaceDate" | "raceDate" | "localDate">,
): JsonObject {
  if (!request.hasRaceDate || request.raceDate == null) return candidatePlan;
  const daysToRace = (parseDateOnly(request.raceDate)!.getTime() -
    parseDateOnly(request.localDate)!.getTime()) / DAY_MS;
  if (daysToRace > RACE_WEEK_DAYS) return candidatePlan;
  const allowed = new Set(["restDay", "recoveryRun", "easyRun", "raceDay"]);
  return {
    ...candidatePlan,
    sessions: sessionsFromPlan(candidatePlan).filter((session) =>
      session.date.slice(0, 10) <= request.raceDate! &&
      allowed.has(sessionType(session))
    ),
  };
}

function isHardOrLongSession(session: Session): boolean {
  return new Set([
    "longRun",
    "tempoRun",
    "thresholdRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "progressionRun",
  ]).has(sessionType(session));
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

function downgradeConfidence(value: EstimateConfidence): EstimateConfidence {
  return value === "high" ? "medium" : "limited";
}

export function mergeImmutableHistory(input: {
  sourcePlan: JsonObject;
  candidatePlan: JsonObject;
  localDate: string;
  activityLinkedSessionIds: string[];
  skipAdjustmentSessionIds: string[];
}): { plan: JsonObject; preservedIds: Set<string> } {
  const sourceSessions = sessionsFromPlan(input.sourcePlan);
  const candidateSessions = sessionsFromPlan(input.candidatePlan);
  const linked = new Set(input.activityLinkedSessionIds);
  const skipped = new Set(input.skipAdjustmentSessionIds);
  const preserved = sourceSessions.filter((session) =>
    session.date.slice(0, 10) < input.localDate ||
    linked.has(session.id) || skipped.has(session.id) ||
    session.status === "completed" || session.status === "skipped" ||
    session.status === "active"
  );
  const preservedIds = new Set(preserved.map((session) => session.id));
  const preservedDates = new Set(
    preserved.map((session) => session.date.slice(0, 10)),
  );
  const hasPreservedRaceInfo = preserved.some((session) =>
    session.type === "raceDay"
  );
  const generated = candidateSessions.filter((session) => {
    const date = session.date.slice(0, 10);
    if (date < input.localDate || preservedIds.has(session.id)) return false;
    if (preservedDates.has(date)) return false;
    if (session.type === "raceDay" && hasPreservedRaceInfo) return false;
    return true;
  });
  const currentWeek = currentWeekAtDate(
    sourceSessions,
    input.sourcePlan,
    input.localDate,
  );
  const rebasedGenerated = generated.map((session) => ({
    ...session,
    weekNumber: currentWeek + Math.max(
      0,
      Math.floor(
        (parseDateOnly(session.date.slice(0, 10))!.getTime() -
          parseDateOnly(input.localDate)!.getTime()) / (7 * DAY_MS),
      ),
    ),
  }));
  const sessions = [...preserved, ...rebasedGenerated].sort((a, b) =>
    a.date.localeCompare(b.date) || a.id.localeCompare(b.id)
  );
  const totalWeeks = sessions.reduce(
    (max, session) => Math.max(max, numberOr(session.weekNumber, 1)),
    currentWeek,
  );
  return {
    plan: {
      ...input.candidatePlan,
      currentWeekNumber: currentWeek,
      totalWeeks,
      sessions,
    },
    preservedIds,
  };
}

export function summarizePlanChanges(
  sourcePlan: JsonObject,
  proposedPlan: JsonObject,
  localDate: string,
  preservedIds: Set<string>,
): GoalEditSummary {
  const current = sessionsFromPlan(sourcePlan).filter((session) =>
    session.date.slice(0, 10) >= localDate && !preservedIds.has(session.id)
  );
  const proposed = sessionsFromPlan(proposedPlan).filter((session) =>
    session.date.slice(0, 10) >= localDate && !preservedIds.has(session.id)
  );
  const currentByDate = groupSessionsByDate(current);
  const proposedByDate = groupSessionsByDate(proposed);
  const addedUpcomingSessions: GoalEditSessionChange[] = [];
  const removedUpcomingSessions: GoalEditSessionChange[] = [];
  const materiallyChangedUpcomingSessions: GoalEditSessionChange[] = [];
  const dates = [
    ...new Set([
      ...currentByDate.keys(),
      ...proposedByDate.keys(),
    ]),
  ].sort();
  for (const date of dates) {
    const matched = matchSessionsOnDate(
      currentByDate.get(date) ?? [],
      proposedByDate.get(date) ?? [],
    );
    for (const [before, after] of matched.pairs) {
      if (
        materialSessionSignature(before) !== materialSessionSignature(after)
      ) {
        materiallyChangedUpcomingSessions.push(
          sessionChange(date, before, after),
        );
      }
    }
    for (const after of matched.added) {
      addedUpcomingSessions.push(sessionChange(date, null, after));
    }
    for (const before of matched.removed) {
      removedUpcomingSessions.push(sessionChange(date, before, null));
    }
  }
  const all = sessionsFromPlan(proposedPlan);
  const endDate = all.length === 0
    ? null
    : all.map((session) => session.date.slice(0, 10)).sort().at(-1)!;
  return {
    preservedCount: preservedIds.size,
    addedUpcomingCount: addedUpcomingSessions.length,
    removedUpcomingCount: removedUpcomingSessions.length,
    materiallyChangedUpcomingCount: materiallyChangedUpcomingSessions.length,
    addedUpcomingSessions,
    removedUpcomingSessions,
    materiallyChangedUpcomingSessions,
    totalWeeks: numberOr(proposedPlan.totalWeeks, 1),
    endDate,
  };
}

export function mapRpcError(
  error: unknown,
): { key: string; status: number } | null {
  const message = errorMessage(error);
  const mappings: Array<[string, string, number]> = [
    ["goal_edit_proposal_inconsistent", "proposal_inconsistent", 500],
    ["goal_edit_proposal_not_found", "proposal_not_found", 404],
    ["goal_edit_proposal_expired", "proposal_expired", 409],
    ["goal_edit_source_plan_stale", "source_plan_stale", 409],
    ["goal_edit_source_plan_not_active", "source_plan_stale", 409],
    ["goal_edit_proposal_not_pending", "proposal_not_pending", 409],
  ];
  for (const [needle, key, status] of mappings) {
    if (message.includes(needle)) return { key, status };
  }
  return null;
}

export function createProductionDependencies(
  publicClient: SupabaseClient,
  admin: SupabaseClient,
): EditGoalDependencies {
  return {
    async authenticate(authHeader) {
      const jwt = authHeader.slice("Bearer ".length);
      const { data, error } = await publicClient.auth.getClaims(jwt);
      return error == null && typeof data?.claims?.sub === "string"
        ? data.claims.sub
        : null;
    },
    async loadPreviewContext(userId, sourcePlanVersionId) {
      const [
        profileResult,
        planResult,
        activityResult,
        adjustmentResult,
        stravaResult,
      ] = await Promise.all([
        admin.from("runner_profiles").select("data").eq("user_id", userId)
          .maybeSingle(),
        admin.from("plan_versions").select("id,data,is_active").eq(
          "user_id",
          userId,
        ).eq("id", sourcePlanVersionId).eq("is_active", true).maybeSingle(),
        admin.from("activity_records").select("linked_session_id").eq(
          "user_id",
          userId,
        ).not("linked_session_id", "is", null),
        admin.from("plan_adjustments").select(
          "linked_session_id,status,data",
        ).eq("user_id", userId),
        admin.from("strava_activity_summaries").select(
          "recorded_at,activity_type,sport_type,distance_meters,moving_time_seconds,elapsed_time_seconds,average_speed_mps,elevation_gain_meters",
        ).eq("user_id", userId).order("recorded_at", { ascending: false })
          .limit(120),
      ]);
      for (
        const result of [
          profileResult,
          planResult,
          activityResult,
          adjustmentResult,
          stravaResult,
        ]
      ) {
        if (result.error != null) throw result.error;
      }
      if (
        !isRecord(profileResult.data?.data) ||
        !isRecord(planResult.data?.data)
      ) return null;
      return {
        profile: profileResult.data.data,
        sourcePlan: planResult.data.data,
        activityLinkedSessionIds: stringValues(
          activityResult.data,
          "linked_session_id",
        ),
        skipAdjustmentSessionIds: (adjustmentResult.data ?? [])
          .filter((row) => {
            const data = isRecord(row.data) ? row.data : {};
            return row.status !== "dismissed" &&
              data.trigger === "trigger_skipped_session";
          })
          .map((row) => row.linked_session_id)
          .filter((value): value is string => typeof value === "string"),
        stravaSummaries:
          (stravaResult.data ?? []) as StravaActivitySummaryForEvidence[],
      };
    },
    async buildCandidate({ profile, localDate, locale }) {
      const generationStartedAt = parseDateOnly(localDate)!;
      const profileWithStart = {
        ...profile,
        schedule: isRecord(profile.schedule)
          ? { ...profile.schedule, planStartDate: localDate }
          : { planStartDate: localDate },
      } as CandidateProfile;
      const goal = isRecord(profileWithStart.goal) ? profileWithStart.goal : {};
      const brief = buildCoachingBrief({
        profileData: profileWithStart,
        startDate: generationStartedAt,
        raceDate: typeof goal.raceDate === "string"
          ? parseDateOnly(goal.raceDate)
          : null,
        requestedRaceType: typeof goal.race === "string" ? goal.race : null,
      });
      const sanitized = sanitizeProfileForOpenAi(
        profileWithStart,
      ) as CandidateProfile;
      const fitness = isRecord(sanitized.fitness) ? sanitized.fitness : {};
      return await buildCandidatePlan({
        generationProfileWithPlanStartDate: profileWithStart,
        sanitizedGenerationProfile: sanitized,
        generationStartedAt,
        resolvedPlanStartDate: localDate,
        locale,
        coachingBrief: brief,
        expectedWeeks: brief.planLengthWeeks,
        stravaSnapshotSource: fitness.stravaCoachingProfile,
      });
    },
    async storeProposal(input) {
      const { data, error } = await admin.rpc("store_goal_edit_proposal", {
        p_user_id: input.userId,
        p_proposal_id: input.proposalId,
        p_source_plan_version_id: input.sourcePlanVersionId,
        p_candidate_plan: input.candidatePlan,
        p_proposed_goal: input.proposedGoal,
        p_proposed_profile_fragment: input.proposedProfileFragment,
        p_change_summary: input.summary,
        p_warnings: input.warnings,
        p_suggested_target_seconds: input.suggestedTargetTimeSeconds,
        p_created_at: input.createdAt,
        p_expires_at: input.expiresAt,
      });
      if (error != null) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (
        !isRecord(row) || typeof row.id !== "string" ||
        typeof row.expires_at !== "string"
      ) {
        throw new Error("Invalid store_goal_edit_proposal response");
      }
      return row as StoredProposal;
    },
    async acceptProposal(userId, proposalId, versionId, generatedAt) {
      const { data, error } = await admin.rpc("accept_goal_edit_proposal", {
        p_user_id: userId,
        p_proposal_id: proposalId,
        p_new_plan_version_id: versionId,
        p_generated_at: generatedAt,
      });
      if (error != null) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (
        !isRecord(row) || typeof row.new_plan_version_id !== "string" ||
        !isRecord(row.plan_data) || !isRecord(row.profile_data)
      ) {
        throw new Error("Invalid accept_goal_edit_proposal response");
      }
      return row as AcceptedProposal;
    },
    now: () => new Date(),
    randomId: () => crypto.randomUUID(),
  };
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

function evidenceValue(
  evidence: readonly { metric: string; value: number }[],
  metric: string,
): number | undefined {
  return evidence.find((point) => point.metric === metric)?.value;
}

function sessionsFromPlan(plan: JsonObject): Session[] {
  if (!Array.isArray(plan.sessions)) return [];
  return plan.sessions.filter((session): session is Session =>
    isRecord(session) && typeof session.id === "string" &&
    typeof session.date === "string" &&
    parseDateOnly(session.date.slice(0, 10)) != null
  );
}

function currentWeekAtDate(
  sessions: Session[],
  sourcePlan: JsonObject,
  localDate: string,
): number {
  const throughToday = sessions.filter((session) =>
    session.date.slice(0, 10) <= localDate
  );
  return throughToday.reduce(
    (max, session) => Math.max(max, numberOr(session.weekNumber, 1)),
    numberOr(sourcePlan.currentWeekNumber, 1),
  );
}

function materialSessionSignature(session: Session): string {
  return JSON.stringify({
    type: session.type ?? null,
    distanceKm: session.distanceKm ?? null,
    durationMinutes: session.durationMinutes ?? null,
    targetZone: session.targetZone ?? null,
    workoutTarget: session.workoutTarget ?? null,
    workoutSteps: session.workoutSteps ?? null,
  });
}

function groupSessionsByDate(sessions: Session[]): Map<string, Session[]> {
  const grouped = new Map<string, Session[]>();
  for (const session of sessions) {
    const date = session.date.slice(0, 10);
    const group = grouped.get(date) ?? [];
    group.push(session);
    grouped.set(date, group);
  }
  for (const group of grouped.values()) group.sort(compareSessions);
  return grouped;
}

function matchSessionsOnDate(
  current: Session[],
  proposed: Session[],
): {
  pairs: Array<[Session, Session]>;
  added: Session[];
  removed: Session[];
} {
  const remainingCurrent = [...current].sort(compareSessions);
  const remainingProposed = [...proposed].sort(compareSessions);
  const pairs: Array<[Session, Session]> = [];
  const types = [
    ...new Set([
      ...remainingCurrent.map(sessionType),
      ...remainingProposed.map(sessionType),
    ]),
  ].sort();

  // Match equal canonical session types first. IDs can change when a plan is
  // regenerated, so they are only a deterministic tie-breaker within a type.
  for (const type of types) {
    const before = remainingCurrent.filter((item) =>
      sessionType(item) === type
    );
    const after = remainingProposed.filter((item) =>
      sessionType(item) === type
    );
    const pairCount = Math.min(before.length, after.length);
    for (let index = 0; index < pairCount; index++) {
      pairs.push([before[index], after[index]]);
      removeSession(remainingCurrent, before[index]);
      removeSession(remainingProposed, after[index]);
    }
  }

  // Remaining sessions still match by local date, with type/id ordering as a
  // stable secondary key for multi-session days.
  const pairCount = Math.min(
    remainingCurrent.length,
    remainingProposed.length,
  );
  for (let index = 0; index < pairCount; index++) {
    pairs.push([remainingCurrent[index], remainingProposed[index]]);
  }
  return {
    pairs,
    removed: remainingCurrent.slice(pairCount),
    added: remainingProposed.slice(pairCount),
  };
}

function sessionChange(
  localDate: string,
  before: Session | null,
  after: Session | null,
): GoalEditSessionChange {
  return {
    localDate,
    beforeSessionType: before == null ? null : sessionType(before),
    afterSessionType: after == null ? null : sessionType(after),
    beforeDurationMinutes: nullableNumber(before?.durationMinutes),
    afterDurationMinutes: nullableNumber(after?.durationMinutes),
    beforeDistanceKm: nullableNumber(before?.distanceKm),
    afterDistanceKm: nullableNumber(after?.distanceKm),
  };
}

function compareSessions(a: Session, b: Session): number {
  return sessionType(a).localeCompare(sessionType(b)) ||
    a.id.localeCompare(b.id);
}

function sessionType(session: Session): string {
  return typeof session.type === "string" ? session.type : "";
}

function removeSession(sessions: Session[], target: Session): void {
  const index = sessions.indexOf(target);
  if (index >= 0) sessions.splice(index, 1);
}

function nullableNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function goalForResponse(profile: JsonObject): Goal | JsonObject {
  const goal = isRecord(profile.goal) ? profile.goal : {};
  return goal;
}

function raceDistanceKm(race: SupportedRace): number {
  return {
    race_5k: 5,
    race_10k: 10,
    race_half_marathon: 21.0975,
    race_marathon: 42.195,
  }[race];
}

function parseDateOnly(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) &&
      date.toISOString().slice(0, 10) === value
    ? date
    : null;
}

function dateOnly(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function isRecord(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function numberOr(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringValues(rows: unknown, key: string): string[] {
  if (!Array.isArray(rows)) return [];
  return rows.map((row) => isRecord(row) ? row[key] : null).filter(
    (value): value is string => typeof value === "string",
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (isRecord(error) && typeof error.message === "string") {
    return error.message;
  }
  return String(error);
}
