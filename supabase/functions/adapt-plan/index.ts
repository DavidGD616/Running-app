import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import OpenAI from "openai";
import { z } from "zod";

import { buildWorkoutSteps } from "../generate-plan/workout-steps.ts";

type JsonObject = Record<string, unknown>;
type SupportedLocale = "en" | "es";
type SessionType =
  | "easyRun"
  | "longRun"
  | "progressionRun"
  | "intervals"
  | "hillRepeats"
  | "fartlek"
  | "tempoRun"
  | "thresholdRun"
  | "racePaceRun"
  | "recoveryRun"
  | "crossTraining"
  | "restDay"
  | "raceDay";
type AdaptationClassification =
  | "on_track"
  | "too_aggressive"
  | "too_easy"
  | "recovery_needed"
  | "schedule_mismatch"
  | "insufficient_data";
type AdaptationSeverity = "info" | "caution" | "high";
type AdaptationReviewStatus = "pending" | "accepted" | "dismissed" | "failed";
type PatchType =
  | "noChange"
  | "reduceSession"
  | "replaceSession"
  | "moveSession"
  | "shortenLongRun"
  | "repeatWeek"
  | "progressSlightly";

const DEFAULT_OPENAI_MODEL = "gpt-5.5";
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const ONE_MINUTE_MS = 60 * 1000;
const MIN_TIMEZONE_OFFSET_MINUTES = -12 * 60;
const MAX_TIMEZONE_OFFSET_MINUTES = 14 * 60;
const HARD_SESSION_TYPES = new Set<SessionType>([
  "intervals",
  "hillRepeats",
  "fartlek",
  "tempoRun",
  "thresholdRun",
  "racePaceRun",
]);
const RUN_SESSION_TYPES = new Set<SessionType>([
  "easyRun",
  "longRun",
  "progressionRun",
  "intervals",
  "hillRepeats",
  "fartlek",
  "tempoRun",
  "thresholdRun",
  "racePaceRun",
  "recoveryRun",
]);

const AdaptationPatchSchema = z.object({
  type: z.enum([
    "noChange",
    "reduceSession",
    "replaceSession",
    "moveSession",
    "shortenLongRun",
    "repeatWeek",
    "progressSlightly",
  ]),
  sessionId: z.string().nullish(),
  targetDate: z.string().nullish(),
  targetType: z.enum([
    "easyRun",
    "longRun",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "tempoRun",
    "thresholdRun",
    "racePaceRun",
    "recoveryRun",
    "crossTraining",
    "restDay",
    "raceDay",
  ]).nullish(),
  targetDistanceKm: z.number().positive().nullish(),
  targetDurationMinutes: z.number().int().positive().nullish(),
  reasonKey: z.string().min(1),
}).strict();

const AdaptationReviewSchema = z.object({
  classification: z.enum([
    "on_track",
    "too_aggressive",
    "too_easy",
    "recovery_needed",
    "schedule_mismatch",
    "insufficient_data",
  ]),
  severity: z.enum(["info", "caution", "high"]),
  summaryKey: z.string().min(1),
  reasonKeys: z.array(z.string().min(1)).default([]),
  patches: z.array(AdaptationPatchSchema).default([]),
}).strict();

type AdaptationPatch = z.infer<typeof AdaptationPatchSchema>;
type AdaptationReviewProposal = z.infer<typeof AdaptationReviewSchema>;

type PlannedSession = {
  id: string;
  date: string;
  weekNumber?: number;
  type: SessionType;
  status?: string;
  distanceKm?: number | null;
  durationMinutes?: number | null;
  targetZone?: string | null;
  workoutTarget?: JsonObject | null;
  workoutSteps?: unknown[];
  description?: string | null;
  coachNote?: string | null;
  warmUpMinutes?: number | null;
  coolDownMinutes?: number | null;
  intervalReps?: number | null;
  intervalRepDistanceMeters?: number | null;
  intervalRecoverySeconds?: number | null;
  strideReps?: number | null;
  strideSeconds?: number | null;
  strideRecoverySeconds?: number | null;
  [key: string]: unknown;
};

type ActivitySummary = {
  id: string;
  linkedSessionId: string | null;
  completionStatus: string | null;
  actualDistanceKm: number | null;
  actualDurationMinutes: number | null;
  perceivedEffort: string | null;
  recordedAt: string | null;
};

type FeedbackSummary = {
  plannedSessionId: string | null;
  difficulty: string | null;
  recoveryStatus: string | null;
  sleep: string | null;
  legs: string | null;
  pain: string | null;
  motivation: string | null;
  recordedAt: string | null;
};

export type WeeklyTrainingSummary = {
  weekStart: string;
  weekEnd: string;
  plannedSessions: number;
  completedSessions: number;
  skippedSessions: number;
  plannedDistanceKm: number;
  completedDistanceKm: number;
  plannedDurationMinutes: number;
  completedDurationMinutes: number;
  plannedHardSessions: number;
  completedHardSessions: number;
  veryHardFeedbackCount: number;
  poorRecoveryCount: number;
  painFeedbackCount: number;
  completionRatio: number;
  distanceRatio: number;
  classification: AdaptationClassification;
  severity: AdaptationSeverity;
  reasonKeys: string[];
};

type ActivePlanVersionRow = {
  id: string;
  generated_at: string;
  requested_by: string;
  is_active: boolean;
  data: JsonObject;
};

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function parseMinutesFromMs(value: unknown): number | null {
  const ms = numberOrNull(value);
  return ms == null ? null : Math.max(0, Math.round(ms / 60_000));
}

function normalizeDateOnly(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function minDateOnly(a: string, b: string): string {
  return a <= b ? a : b;
}

function nextDateOnly(value: string): string {
  const parsed = parseDateOnly(value);
  if (parsed == null) return value;
  return normalizeDateOnly(new Date(parsed.getTime() + ONE_DAY_MS));
}

function parseDateOnly(value: string | null | undefined): Date | null {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || normalizeDateOnly(parsed) !== value) {
    return null;
  }
  return parsed;
}

export function parseTimezoneOffsetMinutes(value: unknown): number | null {
  if (value === undefined) return 0;
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < MIN_TIMEZONE_OFFSET_MINUTES ||
    value > MAX_TIMEZONE_OFFSET_MINUTES
  ) {
    return null;
  }
  return value;
}

export function currentDateAtTimezoneOffset(
  instant: Date,
  timezoneOffsetMinutes: number,
): string {
  return normalizeDateOnly(
    new Date(instant.getTime() + timezoneOffsetMinutes * ONE_MINUTE_MS),
  );
}

function defaultWeekBounds(
  now = new Date(),
  timezoneOffsetMinutes = 0,
): { weekStart: string; weekEnd: string } {
  const currentDate = currentDateAtTimezoneOffset(
    now,
    timezoneOffsetMinutes,
  );
  const utc = parseDateOnly(currentDate)!;
  const weekday = utc.getUTCDay() === 0 ? 7 : utc.getUTCDay();
  const weekStart = new Date(utc.getTime() - (weekday - 1) * ONE_DAY_MS);
  const weekEnd = new Date(weekStart.getTime() + 6 * ONE_DAY_MS);
  return {
    weekStart: normalizeDateOnly(weekStart),
    weekEnd: normalizeDateOnly(weekEnd),
  };
}

function isWithinDateRange(
  dateValue: string,
  weekStart: string,
  weekEnd: string,
): boolean {
  const date = dateValue.slice(0, 10);
  return date >= weekStart && date <= weekEnd;
}

function rowsFromResponse(response: unknown): JsonObject[] {
  if (!Array.isArray(response)) return [];
  return response.filter(isRecord);
}

function sessionsFromPlan(plan: JsonObject): PlannedSession[] {
  const rawSessions = plan.sessions;
  if (!Array.isArray(rawSessions)) return [];
  return rawSessions
    .filter(isRecord)
    .map((session) => {
      const type = stringOrNull(session.type) as SessionType | null;
      return {
        ...session,
        id: stringOrNull(session.id) ?? "",
        date: stringOrNull(session.date) ?? "",
        type: type ?? "easyRun",
        distanceKm: numberOrNull(session.distanceKm),
        durationMinutes: numberOrNull(session.durationMinutes),
      };
    })
    .filter((session) => session.id.length > 0 && session.date.length > 0);
}

function activityFromRow(row: JsonObject): ActivitySummary | null {
  const data = isRecord(row.normalized_data)
    ? row.normalized_data
    : isRecord(row.data)
    ? row.data
    : row;
  const id = stringOrNull(row.id) ?? stringOrNull(data.id);
  if (id == null) return null;
  return {
    id,
    linkedSessionId: stringOrNull(row.linked_session_id) ??
      stringOrNull(data.linkedSessionId),
    completionStatus: stringOrNull(row.completion_status) ??
      stringOrNull(data.completionStatus),
    actualDistanceKm: numberOrNull(row.actual_distance_km) ??
      numberOrNull(data.actualDistanceKm),
    actualDurationMinutes: parseMinutesFromMs(data.actualDurationMs) ??
      numberOrNull(row.actual_duration_minutes),
    perceivedEffort: stringOrNull(data.perceivedEffort) ??
      stringOrNull(row.perceived_effort),
    recordedAt: stringOrNull(row.recorded_at) ?? stringOrNull(data.recordedAt),
  };
}

function feedbackFromRow(row: JsonObject): FeedbackSummary | null {
  const data = isRecord(row.data) ? row.data : row;
  return {
    plannedSessionId: stringOrNull(row.linked_session_id) ??
      stringOrNull(data.plannedSessionId),
    difficulty: stringOrNull(data.difficulty),
    recoveryStatus: stringOrNull(data.recoveryStatus),
    sleep: stringOrNull(data.sleep),
    legs: stringOrNull(data.legs),
    pain: stringOrNull(data.pain),
    motivation: stringOrNull(data.motivation),
    recordedAt: stringOrNull(row.recorded_at) ?? stringOrNull(data.recordedAt),
  };
}

function isHardSession(session: PlannedSession): boolean {
  return HARD_SESSION_TYPES.has(session.type);
}

function countsAsRun(session: PlannedSession): boolean {
  return RUN_SESSION_TYPES.has(session.type);
}

export function buildWeeklyTrainingSummary({
  plan,
  activities,
  feedback,
  weekStart,
  weekEnd,
  asOfDate,
}: {
  plan: JsonObject;
  activities: ActivitySummary[];
  feedback: FeedbackSummary[];
  weekStart: string;
  weekEnd: string;
  asOfDate?: string;
}): WeeklyTrainingSummary {
  const weekSessions = sessionsFromPlan(plan)
    .filter((session) => isWithinDateRange(session.date, weekStart, weekEnd));
  const weekSessionIds = new Set(weekSessions.map((session) => session.id));
  const weekCompletedActivities = activities.filter((activity) =>
    activity.linkedSessionId != null &&
    weekSessionIds.has(activity.linkedSessionId) &&
    activity.completionStatus === "completed"
  );
  const completedSessionIds = new Set(
    weekCompletedActivities.map((activity) => activity.linkedSessionId),
  );
  const dueCutoff = asOfDate == null
    ? nextDateOnly(weekEnd)
    : normalizeDateOnly(new Date(asOfDate));
  const dueSessions = weekSessions.filter((session) =>
    session.date.slice(0, 10) < dueCutoff ||
    completedSessionIds.has(session.id) ||
    session.status === "completed" ||
    session.status === "skipped"
  );
  const dueSessionIds = new Set(dueSessions.map((session) => session.id));
  const completedActivities = weekCompletedActivities.filter((activity) =>
    activity.linkedSessionId != null &&
    dueSessionIds.has(activity.linkedSessionId)
  );
  const weekFeedback = feedback.filter((item) =>
    item.plannedSessionId != null && dueSessionIds.has(item.plannedSessionId)
  );

  const plannedRunSessions = dueSessions.filter(countsAsRun);
  const completedSessions = completedSessionIds.size;
  const plannedSessions = plannedRunSessions.length;
  const plannedDistanceKm = sum(
    plannedRunSessions.map((session) => session.distanceKm ?? 0),
  );
  const completedDistanceKm = sum(
    completedActivities.map((activity) => activity.actualDistanceKm ?? 0),
  );
  const plannedDurationMinutes = sum(
    plannedRunSessions.map((session) => session.durationMinutes ?? 0),
  );
  const completedDurationMinutes = sum(
    completedActivities.map((activity) => activity.actualDurationMinutes ?? 0),
  );
  const plannedHardSessions = plannedRunSessions.filter(isHardSession).length;
  const completedHardSessions =
    plannedRunSessions.filter((session) =>
      isHardSession(session) && completedSessionIds.has(session.id)
    ).length;
  const skippedSessions = Math.max(0, plannedSessions - completedSessions);
  const veryHardFeedbackCount =
    weekFeedback.filter((item) =>
      item.difficulty === "feedback_very_hard" ||
      item.difficulty === "veryHard" ||
      item.difficulty === "effort_very_hard"
    ).length;
  const poorRecoveryCount =
    weekFeedback.filter((item) =>
      item.recoveryStatus === "recovery_fatigued" ||
      item.sleep === "sleep_poor" ||
      item.legs === "legs_heavy"
    ).length;
  const painFeedbackCount =
    weekFeedback.filter((item) =>
      item.pain === "pain_mild" ||
      item.pain === "pain_moderate" ||
      item.pain === "pain_severe"
    ).length;
  const completionRatio = plannedSessions === 0
    ? 0
    : completedSessions / plannedSessions;
  const distanceRatio = plannedDistanceKm <= 0
    ? 0
    : completedDistanceKm / plannedDistanceKm;
  const { classification, severity, reasonKeys } = classifySummary({
    plannedSessions,
    skippedSessions,
    veryHardFeedbackCount,
    poorRecoveryCount,
    painFeedbackCount,
    completionRatio,
    distanceRatio,
  });

  return {
    weekStart,
    weekEnd,
    plannedSessions,
    completedSessions,
    skippedSessions,
    plannedDistanceKm: roundOne(plannedDistanceKm),
    completedDistanceKm: roundOne(completedDistanceKm),
    plannedDurationMinutes,
    completedDurationMinutes,
    plannedHardSessions,
    completedHardSessions,
    veryHardFeedbackCount,
    poorRecoveryCount,
    painFeedbackCount,
    completionRatio: roundTwo(completionRatio),
    distanceRatio: roundTwo(distanceRatio),
    classification,
    severity,
    reasonKeys,
  };
}

function classifySummary(input: {
  plannedSessions: number;
  skippedSessions: number;
  veryHardFeedbackCount: number;
  poorRecoveryCount: number;
  painFeedbackCount: number;
  completionRatio: number;
  distanceRatio: number;
}): {
  classification: AdaptationClassification;
  severity: AdaptationSeverity;
  reasonKeys: string[];
} {
  if (input.plannedSessions === 0) {
    return {
      classification: "insufficient_data",
      severity: "info",
      reasonKeys: ["adapt_reason_insufficient_data"],
    };
  }
  if (input.painFeedbackCount > 0) {
    return {
      classification: "recovery_needed",
      severity: "high",
      reasonKeys: ["adapt_reason_pain_reported"],
    };
  }
  if (input.veryHardFeedbackCount >= 2 || input.poorRecoveryCount >= 2) {
    return {
      classification: "too_aggressive",
      severity: "caution",
      reasonKeys: ["adapt_reason_high_effort_recovery"],
    };
  }
  if (input.skippedSessions >= 2 || input.completionRatio < 0.65) {
    return {
      classification: "schedule_mismatch",
      severity: "caution",
      reasonKeys: ["adapt_reason_missed_sessions"],
    };
  }
  if (input.completionRatio >= 0.95 && input.distanceRatio >= 0.95) {
    return {
      classification: "on_track",
      severity: "info",
      reasonKeys: ["adapt_reason_on_track"],
    };
  }
  return {
    classification: "insufficient_data",
    severity: "info",
    reasonKeys: ["adapt_reason_insufficient_data"],
  };
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
}

function roundTwo(value: number): number {
  return Math.round(value * 100) / 100;
}

function resolveOpenAiModel(): string {
  const value = Deno.env.get("OPENAI_MODEL")?.trim();
  return value && !/\s/.test(value) ? value : DEFAULT_OPENAI_MODEL;
}

export function adaptationJsonSchema(): JsonObject {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "classification",
      "severity",
      "summaryKey",
      "reasonKeys",
      "patches",
    ],
    properties: {
      classification: {
        type: "string",
        enum: [
          "on_track",
          "too_aggressive",
          "too_easy",
          "recovery_needed",
          "schedule_mismatch",
          "insufficient_data",
        ],
      },
      severity: { type: "string", enum: ["info", "caution", "high"] },
      summaryKey: { type: "string" },
      reasonKeys: { type: "array", items: { type: "string" } },
      patches: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "type",
            "sessionId",
            "targetDate",
            "targetType",
            "targetDistanceKm",
            "targetDurationMinutes",
            "reasonKey",
          ],
          properties: {
            type: {
              type: "string",
              enum: [
                "noChange",
                "reduceSession",
                "replaceSession",
                "moveSession",
                "shortenLongRun",
                "progressSlightly",
              ],
            },
            sessionId: { type: ["string", "null"] },
            targetDate: { type: ["string", "null"] },
            targetType: {
              type: ["string", "null"],
              enum: [
                "easyRun",
                "longRun",
                "progressionRun",
                "intervals",
                "hillRepeats",
                "fartlek",
                "tempoRun",
                "thresholdRun",
                "racePaceRun",
                "recoveryRun",
                "crossTraining",
                "restDay",
                "raceDay",
                null,
              ],
            },
            targetDistanceKm: { type: ["number", "null"] },
            targetDurationMinutes: { type: ["integer", "null"] },
            reasonKey: { type: "string" },
          },
        },
      },
    },
  };
}

function buildAdaptationMessages(input: {
  locale: SupportedLocale;
  summary: WeeklyTrainingSummary;
  futureSessions: PlannedSession[];
}): Array<{ role: "system" | "user"; content: string }> {
  return [
    {
      role: "system",
      content:
        "You are a conservative running coach. Return only safe plan adaptation patches. Never modify past sessions. Pain or severe fatigue must reduce intensity. Prefer noChange when evidence is thin. Use canonical keys only.",
    },
    {
      role: "user",
      content: JSON.stringify({
        locale: input.locale,
        weeklySummary: input.summary,
        futureSessions: input.futureSessions.map((session) => ({
          id: session.id,
          date: session.date,
          type: session.type,
          distanceKm: session.distanceKm,
          durationMinutes: session.durationMinutes,
        })),
      }),
    },
  ];
}

async function proposeAdaptationWithOpenAi(input: {
  locale: SupportedLocale;
  summary: WeeklyTrainingSummary;
  futureSessions: PlannedSession[];
}): Promise<AdaptationReviewProposal> {
  if (
    input.summary.classification === "on_track" ||
    input.summary.classification === "insufficient_data"
  ) {
    return defaultProposal(input.summary);
  }

  const client = new OpenAI({ apiKey: requireEnv("OPENAI_API_KEY") });
  const completion = await client.chat.completions.create({
    model: resolveOpenAiModel(),
    messages: buildAdaptationMessages(input),
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "plan_adaptation_review",
        strict: true,
        schema: adaptationJsonSchema(),
      },
    },
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) throw new Error("OpenAI returned no content");
  return AdaptationReviewSchema.parse(JSON.parse(content));
}

function defaultProposal(
  summary: WeeklyTrainingSummary,
): AdaptationReviewProposal {
  return {
    classification: summary.classification,
    severity: summary.severity,
    summaryKey: summary.classification === "on_track"
      ? "adapt_summary_on_track"
      : "adapt_summary_insufficient_data",
    reasonKeys: summary.reasonKeys,
    patches: [{ type: "noChange", reasonKey: "adapt_reason_no_change" }],
  };
}

export function validateAdaptationPatches(
  patches: AdaptationPatch[],
  futureSessions: PlannedSession[],
  summary: WeeklyTrainingSummary,
  options: { asOfDate?: string } = {},
): { ok: true; patches: AdaptationPatch[] } | { ok: false; reason: string } {
  if (patches.length === 0) {
    return { ok: false, reason: "missing_patches" };
  }
  const noChangePatches = patches.filter((patch) => patch.type === "noChange");
  if (noChangePatches.length > 0 && patches.length > 1) {
    return { ok: false, reason: "no_change_must_be_exclusive" };
  }

  const asOfDate = options.asOfDate ?? normalizeDateOnly(new Date());
  if (parseDateOnly(asOfDate) == null) {
    return { ok: false, reason: "invalid_as_of_date" };
  }
  const sessionById = new Map(
    futureSessions.map((session) => [session.id, session]),
  );
  const remainingPlanDates = futureSessions
    .map((session) => session.date.slice(0, 10))
    .filter((date) => parseDateOnly(date) != null)
    .sort();
  const planStart = remainingPlanDates.at(0) ?? null;
  const planEnd = remainingPlanDates.at(-1) ?? null;
  const patchedSessionIds = new Set<string>();
  const sanitized: AdaptationPatch[] = [];

  for (const patch of patches) {
    if (patch.type === "noChange") {
      if (hasTargetFields(patch)) {
        return { ok: false, reason: "no_change_has_target_fields" };
      }
      sanitized.push({
        type: "noChange",
        reasonKey: patch.reasonKey,
      });
      continue;
    }
    if (patch.type === "repeatWeek") {
      return { ok: false, reason: "unsupported_patch_type" };
    }
    if (patch.sessionId == null || !sessionById.has(patch.sessionId)) {
      return { ok: false, reason: "unknown_session" };
    }
    if (patchedSessionIds.has(patch.sessionId)) {
      return { ok: false, reason: "duplicate_session_patch" };
    }
    patchedSessionIds.add(patch.sessionId);
    const session = sessionById.get(patch.sessionId)!;
    if (summary.severity === "high" && patch.type === "progressSlightly") {
      return { ok: false, reason: "progression_blocked_by_high_severity" };
    }

    const validation = validatePatchForSession({
      patch,
      session,
      summary,
      asOfDate,
      planStart,
      planEnd,
    });
    if (!validation.ok) return validation;
    sanitized.push(validation.patch);
  }

  return { ok: true, patches: sanitized };
}

function hasTargetFields(patch: AdaptationPatch): boolean {
  return patch.sessionId != null ||
    patch.targetDate != null ||
    patch.targetType != null ||
    patch.targetDistanceKm != null ||
    patch.targetDurationMinutes != null;
}

function hasMetricTargets(patch: AdaptationPatch): boolean {
  return patch.targetDistanceKm != null || patch.targetDurationMinutes != null;
}

function validateMetricShape(
  patch: AdaptationPatch,
): { ok: true } | { ok: false; reason: string } {
  if (
    patch.targetDistanceKm != null &&
    (!Number.isFinite(patch.targetDistanceKm) || patch.targetDistanceKm <= 0)
  ) {
    return { ok: false, reason: "invalid_target_distance" };
  }
  if (
    patch.targetDurationMinutes != null &&
    (!Number.isInteger(patch.targetDurationMinutes) ||
      patch.targetDurationMinutes <= 0)
  ) {
    return { ok: false, reason: "invalid_target_duration" };
  }
  return { ok: true };
}

function validateComparableMetrics(
  patch: AdaptationPatch,
  session: PlannedSession,
): { ok: true } | { ok: false; reason: string } {
  const shape = validateMetricShape(patch);
  if (!shape.ok) return shape;
  if (patch.targetDistanceKm != null && session.distanceKm == null) {
    return { ok: false, reason: "target_distance_not_available" };
  }
  if (patch.targetDurationMinutes != null && session.durationMinutes == null) {
    return { ok: false, reason: "target_duration_not_available" };
  }
  return { ok: true };
}

function exceedsIncreaseCap(
  patch: AdaptationPatch,
  session: PlannedSession,
): { ok: true } | { ok: false; reason: string } {
  if (
    patch.targetDistanceKm != null &&
    session.distanceKm != null &&
    patch.targetDistanceKm > session.distanceKm * 1.08
  ) {
    return { ok: false, reason: "distance_increase_too_large" };
  }
  if (
    patch.targetDurationMinutes != null &&
    session.durationMinutes != null &&
    patch.targetDurationMinutes > session.durationMinutes * 1.08
  ) {
    return { ok: false, reason: "duration_increase_too_large" };
  }
  return { ok: true };
}

function metricPatch(
  patch: AdaptationPatch,
): Pick<
  AdaptationPatch,
  "targetDistanceKm" | "targetDurationMinutes"
> {
  return {
    ...(patch.targetDistanceKm == null
      ? {}
      : { targetDistanceKm: patch.targetDistanceKm }),
    ...(patch.targetDurationMinutes == null
      ? {}
      : { targetDurationMinutes: patch.targetDurationMinutes }),
  };
}

function validateReductionPatch(
  patch: AdaptationPatch,
  session: PlannedSession,
): { ok: true; patch: AdaptationPatch } | { ok: false; reason: string } {
  if (patch.targetDate != null || patch.targetType != null) {
    return { ok: false, reason: "reduction_has_unexpected_fields" };
  }
  if (!hasMetricTargets(patch)) {
    return { ok: false, reason: "reduction_requires_target_metric" };
  }
  const comparable = validateComparableMetrics(patch, session);
  if (!comparable.ok) return comparable;
  if (
    (patch.targetDistanceKm != null &&
      patch.targetDistanceKm > session.distanceKm!) ||
    (patch.targetDurationMinutes != null &&
      patch.targetDurationMinutes > session.durationMinutes!)
  ) {
    return { ok: false, reason: "reduction_cannot_increase_metric" };
  }
  const reducesDistance = patch.targetDistanceKm != null &&
    patch.targetDistanceKm < session.distanceKm!;
  const reducesDuration = patch.targetDurationMinutes != null &&
    patch.targetDurationMinutes < session.durationMinutes!;
  if (!reducesDistance && !reducesDuration) {
    return { ok: false, reason: "reduction_must_reduce_metric" };
  }
  return {
    ok: true,
    patch: {
      type: patch.type,
      sessionId: patch.sessionId,
      ...metricPatch(patch),
      reasonKey: patch.reasonKey,
    },
  };
}

function validateProgressionPatch(
  patch: AdaptationPatch,
  session: PlannedSession,
): { ok: true; patch: AdaptationPatch } | { ok: false; reason: string } {
  if (patch.targetDate != null || patch.targetType != null) {
    return { ok: false, reason: "progression_has_unexpected_fields" };
  }
  if (!hasMetricTargets(patch)) {
    return { ok: false, reason: "progression_requires_target_metric" };
  }
  const comparable = validateComparableMetrics(patch, session);
  if (!comparable.ok) return comparable;
  if (
    (patch.targetDistanceKm != null &&
      patch.targetDistanceKm < session.distanceKm!) ||
    (patch.targetDurationMinutes != null &&
      patch.targetDurationMinutes < session.durationMinutes!)
  ) {
    return { ok: false, reason: "progression_cannot_reduce_metric" };
  }
  const increasesDistance = patch.targetDistanceKm != null &&
    patch.targetDistanceKm > session.distanceKm!;
  const increasesDuration = patch.targetDurationMinutes != null &&
    patch.targetDurationMinutes > session.durationMinutes!;
  if (!increasesDistance && !increasesDuration) {
    return { ok: false, reason: "progression_must_increase_metric" };
  }
  const cap = exceedsIncreaseCap(patch, session);
  if (!cap.ok) return cap;
  return {
    ok: true,
    patch: {
      type: "progressSlightly",
      sessionId: patch.sessionId,
      ...metricPatch(patch),
      reasonKey: patch.reasonKey,
    },
  };
}

function validatePatchForSession({
  patch,
  session,
  summary,
  asOfDate,
  planStart,
  planEnd,
}: {
  patch: AdaptationPatch;
  session: PlannedSession;
  summary: WeeklyTrainingSummary;
  asOfDate: string;
  planStart: string | null;
  planEnd: string | null;
}): { ok: true; patch: AdaptationPatch } | { ok: false; reason: string } {
  if (patch.type === "reduceSession") {
    return validateReductionPatch(patch, session);
  }
  if (patch.type === "shortenLongRun") {
    if (session.type !== "longRun") {
      return { ok: false, reason: "shorten_requires_long_run" };
    }
    return validateReductionPatch(patch, session);
  }
  if (patch.type === "progressSlightly") {
    return validateProgressionPatch(patch, session);
  }
  if (patch.type === "replaceSession") {
    if (patch.targetDate != null) {
      return { ok: false, reason: "replacement_has_unexpected_fields" };
    }
    if (patch.targetType == null) {
      return { ok: false, reason: "replacement_requires_target_type" };
    }
    if (patch.targetType === session.type) {
      return { ok: false, reason: "replacement_must_change_type" };
    }
    if (
      summary.painFeedbackCount > 0 &&
      HARD_SESSION_TYPES.has(patch.targetType)
    ) {
      return { ok: false, reason: "pain_cannot_add_intensity" };
    }
    const comparable = validateComparableMetrics(patch, session);
    if (!comparable.ok) return comparable;
    const cap = exceedsIncreaseCap(patch, session);
    if (!cap.ok) return cap;
    return {
      ok: true,
      patch: {
        type: "replaceSession",
        sessionId: patch.sessionId,
        targetType: patch.targetType,
        ...metricPatch(patch),
        reasonKey: patch.reasonKey,
      },
    };
  }
  if (patch.type === "moveSession") {
    if (
      patch.targetType != null ||
      patch.targetDistanceKm != null ||
      patch.targetDurationMinutes != null
    ) {
      return { ok: false, reason: "move_has_unexpected_fields" };
    }
    if (patch.targetDate == null || parseDateOnly(patch.targetDate) == null) {
      return { ok: false, reason: "invalid_target_date" };
    }
    if (patch.targetDate <= asOfDate) {
      return { ok: false, reason: "target_date_must_be_future" };
    }
    if (patch.targetDate === session.date.slice(0, 10)) {
      return { ok: false, reason: "move_must_change_date" };
    }
    if (
      planStart == null ||
      planEnd == null ||
      patch.targetDate < planStart ||
      patch.targetDate > planEnd
    ) {
      return { ok: false, reason: "target_date_outside_plan" };
    }
    return {
      ok: true,
      patch: {
        type: "moveSession",
        sessionId: patch.sessionId,
        targetDate: patch.targetDate,
        reasonKey: patch.reasonKey,
      },
    };
  }
  return { ok: false, reason: "unsupported_patch_type" };
}

export function revalidateAdaptationForAcceptance({
  plan,
  patches,
  activities,
  feedback,
  weekStart,
  weekEnd,
  asOfDate,
}: {
  plan: JsonObject;
  patches: AdaptationPatch[];
  activities: ActivitySummary[];
  feedback: FeedbackSummary[];
  weekStart: string;
  weekEnd: string;
  asOfDate: string;
}):
  | {
    ok: true;
    patches: AdaptationPatch[];
    summary: WeeklyTrainingSummary;
  }
  | { ok: false; reason: string } {
  if (
    parseDateOnly(weekStart) == null ||
    parseDateOnly(weekEnd) == null ||
    weekStart > weekEnd
  ) {
    return { ok: false, reason: "invalid_review_week" };
  }
  if (parseDateOnly(asOfDate) == null) {
    return { ok: false, reason: "invalid_as_of_date" };
  }
  const summary = buildWeeklyTrainingSummary({
    plan,
    activities,
    feedback,
    weekStart,
    weekEnd,
    asOfDate: minDateOnly(asOfDate, nextDateOnly(weekEnd)),
  });
  const futureSessions = sessionsFromPlan(plan)
    .filter((session) => session.date.slice(0, 10) >= asOfDate);
  const validation = validateAdaptationPatches(
    patches,
    futureSessions,
    summary,
    { asOfDate },
  );
  if (!validation.ok) return validation;
  return { ok: true, patches: validation.patches, summary };
}

export function revalidateAdaptationForAcceptanceAtInstant({
  instant,
  timezoneOffsetMinutes,
  ...input
}: {
  plan: JsonObject;
  patches: AdaptationPatch[];
  activities: ActivitySummary[];
  feedback: FeedbackSummary[];
  weekStart: string;
  weekEnd: string;
  instant: Date;
  timezoneOffsetMinutes: number;
}):
  | {
    ok: true;
    patches: AdaptationPatch[];
    summary: WeeklyTrainingSummary;
  }
  | { ok: false; reason: string } {
  const parsedOffset = parseTimezoneOffsetMinutes(timezoneOffsetMinutes);
  if (parsedOffset == null) {
    return { ok: false, reason: "invalid_review_timezone" };
  }
  return revalidateAdaptationForAcceptance({
    ...input,
    asOfDate: currentDateAtTimezoneOffset(instant, parsedOffset),
  });
}

function targetZoneFor(type: SessionType): string | null {
  switch (type) {
    case "recoveryRun":
      return "recovery";
    case "longRun":
      return "longRun";
    case "tempoRun":
      return "tempo";
    case "thresholdRun":
      return "threshold";
    case "racePaceRun":
      return "racePace";
    case "intervals":
    case "hillRepeats":
    case "fartlek":
      return "interval";
    case "easyRun":
    case "progressionRun":
      return "easy";
    default:
      return null;
  }
}

function paceZoneKeyFor(targetZone: string | null): string | null {
  if (targetZone === "interval") return "intervals";
  return targetZone;
}

function workoutTargetFor(
  type: SessionType,
  paceZones: unknown,
): JsonObject | null {
  const zone = targetZoneFor(type);
  const paceKey = paceZoneKeyFor(zone);
  if (zone == null || paceKey == null || !isRecord(paceZones)) return null;
  const paceZone = paceZones[paceKey];
  if (!isRecord(paceZone)) return null;
  const min = numberOrNull(paceZone.paceMinSecPerKm);
  const max = numberOrNull(paceZone.paceMaxSecPerKm);
  if (min == null || max == null) return null;
  return {
    schemaVersion: 1,
    type: "pace",
    zone,
    paceMinSecPerKm: min,
    paceMaxSecPerKm: max,
  };
}

export function applyPatchesToPlan(
  plan: JsonObject,
  patches: AdaptationPatch[],
): JsonObject {
  const sessions = sessionsFromPlan(plan);
  const patchBySession = new Map(
    patches
      .filter((patch) => patch.sessionId != null && patch.type !== "noChange")
      .map((patch) => [patch.sessionId!, patch]),
  );
  const paceZones = plan.paceZones;
  const updatedSessions = sessions.map((session) => {
    const patch = patchBySession.get(session.id);
    if (patch == null) return session;
    const targetType = patch.targetType ?? session.type;
    const updated: PlannedSession = {
      ...session,
      type: targetType,
      date: patch.targetDate ?? session.date,
      distanceKm: patch.targetDistanceKm ?? session.distanceKm,
      durationMinutes: patch.targetDurationMinutes ?? session.durationMinutes,
      targetZone: targetZoneFor(targetType),
      workoutTarget: workoutTargetFor(targetType, paceZones),
    };
    updated.workoutSteps = buildWorkoutSteps(
      {
        ...updated,
        distanceKm: updated.distanceKm ?? null,
        durationMinutes: updated.durationMinutes ?? null,
        targetZone: updated.targetZone ?? null,
        warmUpMinutes: numberOrNull(updated.warmUpMinutes),
        coolDownMinutes: numberOrNull(updated.coolDownMinutes),
        intervalReps: numberOrNull(updated.intervalReps),
        intervalRepDistanceMeters: numberOrNull(
          updated.intervalRepDistanceMeters,
        ),
        intervalRecoverySeconds: numberOrNull(
          updated.intervalRecoverySeconds,
        ),
        strideReps: numberOrNull(updated.strideReps),
        strideSeconds: numberOrNull(updated.strideSeconds),
        strideRecoverySeconds: numberOrNull(updated.strideRecoverySeconds),
      } as Parameters<typeof buildWorkoutSteps>[0],
      isRecord(paceZones)
        ? paceZones as Parameters<typeof buildWorkoutSteps>[1]
        : null,
    );
    updated.description = null;
    updated.coachNote = null;
    return updated;
  });
  return { ...plan, sessions: updatedSessions };
}

function normalizeAdaptationPatch(value: unknown): AdaptationPatch {
  if (!isRecord(value)) return AdaptationPatchSchema.parse(value);
  return AdaptationPatchSchema.parse({
    type: value.type,
    sessionId: value.sessionId,
    targetDate: value.targetDate ?? value.date,
    targetType: value.targetType ?? value.afterSessionType,
    targetDistanceKm: value.targetDistanceKm ?? value.afterDistanceKm,
    targetDurationMinutes: value.targetDurationMinutes ??
      value.afterDurationMinutes,
    reasonKey: value.reasonKey,
  });
}

async function activePlanVersion(
  admin: SupabaseClient,
  userId: string,
): Promise<ActivePlanVersionRow | null> {
  const { data, error } = await admin
    .from("plan_versions")
    .select("id, generated_at, requested_by, is_active, data")
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  if (!isRecord(data) || !isRecord(data.data)) return null;
  return data as ActivePlanVersionRow;
}

async function loadActivities(
  admin: SupabaseClient,
  userId: string,
): Promise<ActivitySummary[]> {
  const { data, error } = await admin
    .from("activity_records")
    .select()
    .eq("user_id", userId);
  if (error) throw error;
  return rowsFromResponse(data).map(activityFromRow).filter((
    item,
  ): item is ActivitySummary => item != null);
}

async function loadFeedback(
  admin: SupabaseClient,
  userId: string,
): Promise<FeedbackSummary[]> {
  const { data, error } = await admin
    .from("session_feedback")
    .select()
    .eq("user_id", userId);
  if (error) throw error;
  return rowsFromResponse(data).map(feedbackFromRow).filter((
    item,
  ): item is FeedbackSummary => item != null);
}

async function pendingReviewForScope(
  admin: SupabaseClient,
  userId: string,
  sourcePlanVersionId: string,
  weekStart: string,
  weekEnd: string,
): Promise<JsonObject | null> {
  const { data, error } = await admin
    .from("adaptation_reviews")
    .select()
    .eq("user_id", userId)
    .eq("source_plan_version_id", sourcePlanVersionId)
    .eq("week_start", weekStart)
    .eq("week_end", weekEnd)
    .eq("status", "pending")
    .maybeSingle();
  if (error) throw error;
  return isRecord(data) ? data : null;
}

function pendingReviewResponse(reviewRow: JsonObject): Response {
  if (!isRecord(reviewRow.data)) {
    throw new Error("Pending adaptation review has invalid data");
  }
  const reviewId = stringOrNull(reviewRow.id) ??
    stringOrNull(reviewRow.data.id);
  if (reviewId == null) {
    throw new Error("Pending adaptation review is missing its id");
  }
  return jsonResponse({ reviewId, review: reviewRow.data, reused: true });
}

async function createReview(
  admin: SupabaseClient,
  userId: string,
  body: JsonObject,
): Promise<Response> {
  const timezoneOffsetMinutes = parseTimezoneOffsetMinutes(
    body.timezoneOffsetMinutes,
  );
  if (timezoneOffsetMinutes == null) {
    return jsonResponse({ error: "Invalid timezone offset" }, 400);
  }
  const planVersion = await activePlanVersion(admin, userId);
  if (planVersion == null) {
    return jsonResponse({ error: "Active plan not found" }, 404);
  }
  const creationInstant = new Date();
  const bounds = defaultWeekBounds(creationInstant, timezoneOffsetMinutes);
  const weekStart = stringOrNull(body.weekStart) ?? bounds.weekStart;
  const weekEnd = stringOrNull(body.weekEnd) ?? bounds.weekEnd;
  if (
    parseDateOnly(weekStart) == null ||
    parseDateOnly(weekEnd) == null ||
    weekStart > weekEnd
  ) {
    return jsonResponse({ error: "Invalid review week" }, 400);
  }
  const pendingReview = await pendingReviewForScope(
    admin,
    userId,
    planVersion.id,
    weekStart,
    weekEnd,
  );
  if (pendingReview != null) return pendingReviewResponse(pendingReview);

  const today = currentDateAtTimezoneOffset(
    creationInstant,
    timezoneOffsetMinutes,
  );
  const asOfDate = minDateOnly(today, nextDateOnly(weekEnd));
  const locale = (body.locale === "es" ? "es" : "en") as SupportedLocale;
  const activities = await loadActivities(admin, userId);
  const feedback = await loadFeedback(admin, userId);
  const summary = buildWeeklyTrainingSummary({
    plan: planVersion.data,
    activities,
    feedback,
    weekStart,
    weekEnd,
    asOfDate,
  });
  const futureSessions = sessionsFromPlan(planVersion.data)
    .filter((session) => session.date.slice(0, 10) >= today);
  let proposal: AdaptationReviewProposal;
  try {
    proposal = await proposeAdaptationWithOpenAi({
      locale,
      summary,
      futureSessions,
    });
  } catch (error) {
    console.error("adapt-plan OpenAI proposal failed", String(error));
    proposal = {
      classification: "insufficient_data",
      severity: "info",
      summaryKey: "adapt_summary_failed",
      reasonKeys: ["adapt_reason_generation_failed"],
      patches: [{ type: "noChange", reasonKey: "adapt_reason_no_change" }],
    };
  }
  const validation = validateAdaptationPatches(
    proposal.patches,
    futureSessions,
    summary,
    { asOfDate: today },
  );
  const status: AdaptationReviewStatus = validation.ok ? "pending" : "failed";
  const patches = validation.ok ? validation.patches : [{
    type: "noChange",
    reasonKey: validation.reason,
  }] satisfies AdaptationPatch[];
  const now = creationInstant.toISOString();
  const reviewId = crypto.randomUUID();
  const review = {
    schemaVersion: 1,
    id: reviewId,
    status,
    classification: proposal.classification,
    severity: proposal.severity,
    summaryKey: proposal.summaryKey,
    reasonKeys: proposal.reasonKeys,
    patches,
    weeklySummary: summary,
    weekStart,
    weekEnd,
    timezoneOffsetMinutes,
    sourcePlanVersionId: planVersion.id,
    proposedPlanVersionId: null,
    createdAt: now,
    updatedAt: now,
  };

  const { error } = await admin.from("adaptation_reviews").insert({
    id: reviewId,
    user_id: userId,
    status,
    classification: proposal.classification,
    severity: proposal.severity,
    week_start: weekStart,
    week_end: weekEnd,
    source_plan_version_id: planVersion.id,
    proposed_plan_version_id: null,
    created_at: now,
    updated_at: now,
    data: review,
  });
  if (error) {
    if (error.code === "23505" && status === "pending") {
      const concurrentReview = await pendingReviewForScope(
        admin,
        userId,
        planVersion.id,
        weekStart,
        weekEnd,
      );
      if (concurrentReview != null) {
        return pendingReviewResponse(concurrentReview);
      }
    }
    console.error("Failed to save adaptation review", error);
    return jsonResponse({ error: "Failed to save adaptation review" }, 500);
  }
  return jsonResponse({ reviewId, review });
}

async function acceptReview(
  admin: SupabaseClient,
  userId: string,
  body: JsonObject,
): Promise<Response> {
  const reviewId = stringOrNull(body.reviewId);
  if (reviewId == null) return jsonResponse({ error: "Missing reviewId" }, 400);
  const { data: reviewRow, error: reviewError } = await admin
    .from("adaptation_reviews")
    .select()
    .eq("user_id", userId)
    .eq("id", reviewId)
    .maybeSingle();
  if (reviewError) throw reviewError;
  if (!isRecord(reviewRow) || !isRecord(reviewRow.data)) {
    return jsonResponse({ error: "Adaptation review not found" }, 404);
  }
  if (reviewRow.status !== "pending") {
    return jsonResponse({ error: "Adaptation review is not pending" }, 409);
  }
  const timezoneOffsetMinutes = parseTimezoneOffsetMinutes(
    reviewRow.data.timezoneOffsetMinutes,
  );
  if (timezoneOffsetMinutes == null) {
    return jsonResponse({ error: "invalid_review_timezone" }, 409);
  }
  const planVersion = await activePlanVersion(admin, userId);
  if (planVersion == null) {
    return jsonResponse({ error: "Active plan not found" }, 404);
  }
  const sourcePlanVersionId = stringOrNull(reviewRow.source_plan_version_id);
  if (sourcePlanVersionId !== planVersion.id) {
    return jsonResponse({ error: "Adaptation review is stale" }, 409);
  }
  const patchesRaw = reviewRow.data.patches;
  let patches: AdaptationPatch[];
  try {
    if (!Array.isArray(patchesRaw)) {
      return jsonResponse({ error: "invalid_stored_patches" }, 409);
    }
    patches = patchesRaw.map((item) => normalizeAdaptationPatch(item));
  } catch {
    return jsonResponse({ error: "invalid_stored_patches" }, 409);
  }
  const weekStart = stringOrNull(reviewRow.week_start);
  const weekEnd = stringOrNull(reviewRow.week_end);
  if (weekStart == null || weekEnd == null) {
    return jsonResponse({ error: "invalid_review_week" }, 409);
  }
  const activities = await loadActivities(admin, userId);
  const feedback = await loadFeedback(admin, userId);
  const acceptanceInstant = new Date();
  const validation = revalidateAdaptationForAcceptanceAtInstant({
    plan: planVersion.data,
    patches,
    activities,
    feedback,
    weekStart,
    weekEnd,
    instant: acceptanceInstant,
    timezoneOffsetMinutes,
  });
  if (!validation.ok) {
    return jsonResponse({ error: validation.reason }, 409);
  }
  const nextPlan = applyPatchesToPlan(planVersion.data, validation.patches);
  const versionId = crypto.randomUUID();
  const now = acceptanceInstant.toISOString();
  const updatedReview = {
    ...reviewRow.data,
    status: "accepted",
    patches: validation.patches,
    weeklySummary: validation.summary,
    timezoneOffsetMinutes,
    proposedPlanVersionId: versionId,
    updatedAt: now,
  };
  const { error: acceptError } = await admin.rpc(
    "accept_adaptation_plan_version",
    {
      p_user_id: userId,
      p_review_id: reviewId,
      p_source_plan_version_id: planVersion.id,
      p_new_plan_version_id: versionId,
      p_generated_at: now,
      p_plan_data: { ...nextPlan, id: versionId },
      p_review_data: updatedReview,
    },
  );
  if (acceptError) {
    console.error("Failed to accept adaptation review", acceptError);
    const message = String(acceptError.message ?? "");
    if (
      message.includes("source_plan_version_not_active") ||
      message.includes("adaptation_review_not_pending")
    ) {
      return jsonResponse({ error: "Adaptation review is stale" }, 409);
    }
    return jsonResponse({ error: "Failed to save adapted plan" }, 500);
  }
  return jsonResponse({
    versionId,
    plan: { ...nextPlan, id: versionId },
    review: updatedReview,
  });
}

async function dismissReview(
  admin: SupabaseClient,
  userId: string,
  body: JsonObject,
): Promise<Response> {
  const reviewId = stringOrNull(body.reviewId);
  if (reviewId == null) return jsonResponse({ error: "Missing reviewId" }, 400);

  const { data: reviewRow, error: reviewError } = await admin
    .from("adaptation_reviews")
    .select()
    .eq("user_id", userId)
    .eq("id", reviewId)
    .maybeSingle();
  if (reviewError) throw reviewError;
  if (!isRecord(reviewRow) || !isRecord(reviewRow.data)) {
    return jsonResponse({ error: "Adaptation review not found" }, 404);
  }
  if (reviewRow.status !== "pending") {
    return jsonResponse({ error: "Adaptation review is not pending" }, 409);
  }

  const now = new Date().toISOString();
  const updatedReview = {
    ...reviewRow.data,
    status: "dismissed",
    updatedAt: now,
  };
  const { data: updatedRow, error: updateError } = await admin
    .from("adaptation_reviews")
    .update({
      status: "dismissed",
      updated_at: now,
      data: updatedReview,
    })
    .eq("user_id", userId)
    .eq("id", reviewId)
    .eq("status", "pending")
    .select()
    .maybeSingle();
  if (updateError) throw updateError;
  if (!isRecord(updatedRow)) {
    return jsonResponse({ error: "Adaptation review is stale" }, 409);
  }
  return jsonResponse({ review: updatedReview });
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization" }, 401);
    }

    const supabasePublic = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SB_PUBLISHABLE_KEY"),
    );
    const jwt = authHeader.replace("Bearer ", "");
    const { data: claimsData, error: claimsError } = await supabasePublic.auth
      .getClaims(jwt);
    const userId = claimsData?.claims?.sub;
    if (!userId || claimsError) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const admin = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );
    const body = await req.json().catch(() => ({} as JsonObject));
    const action = stringOrNull(body.action) ?? "review";
    if (action === "accept") return await acceptReview(admin, userId, body);
    if (action === "dismiss") return await dismissReview(admin, userId, body);
    if (action === "review") return await createReview(admin, userId, body);
    return jsonResponse({ error: "Unsupported action" }, 400);
  } catch (error) {
    console.error("adapt-plan failed", String(error));
    return jsonResponse(
      { error: "Adaptation failed", detail: String(error) },
      500,
    );
  }
});
