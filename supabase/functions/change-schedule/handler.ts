import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

import { reflowPlan } from "./reflow-engine.ts";

type JsonObject = Record<string, unknown>;
type ScheduleSession = JsonObject & {
  id: string;
  date: string;
  weekNumber: number;
  type: string;
  status?: string;
};
type StoredProposal = {
  id: string;
  expires_at: string;
  [key: string]: unknown;
};
type AcceptedProposal = {
  accepted_plan_version_id: string;
  plan_data: JsonObject;
  prior_active_plan_version_id: string | null;
  prior_active_availability_version_id: string | null;
  accepted_availability_version_id: string;
};
type ScheduledProposal = {
  proposal_id: string;
  activation_id: string;
  scheduled_plan_version_id: string;
  scheduled_availability_version_id: string;
  activation_status: string;
};
type CancelledProposal = {
  proposal_id: string;
  proposal_status: string;
  activation_id: string | null;
  scheduled_plan_version_id: string | null;
};
type ActivatedProposal = {
  proposal_id: string | null;
  activation_id: string;
  proposal_status: string | null;
  accepted_plan_version_id: string | null;
  prior_active_plan_version_id: string | null;
  prior_active_availability_version_id: string | null;
  accepted_availability_version_id: string | null;
  activation_status: string;
};
type UndoneProposal = {
  proposal_id: string;
  prior_plan_version_id: string | null;
  prior_availability_version_id: string | null;
  restored_plan_version_id: string | null;
  restored_availability_version_id: string | null;
};
type LoadedPreviewContext = {
  profile: JsonObject;
  sourcePlan: JsonObject;
  sourcePlanVersionId: string;
  profileSchemaVersion: number;
  profileUpdatedAt: string;
  immutableSessionIds: string[];
};

export type ChangeScheduleDependencies = {
  authenticate(authHeader: string): Promise<string | null>;
  loadPreviewContext(
    userId: string,
  ): Promise<LoadedPreviewContext | null>;
  storeProposal(input: {
    userId: string;
    proposalId: string;
    sourcePlanVersionId: string;
    candidatePlan: JsonObject;
    impact: JsonObject;
    proposedAvailability: JsonObject;
    effectiveFrom: string;
    createdAt: string;
    expiresAt: string;
    sourceProfileSchemaVersion: number;
    sourceProfileUpdatedAt: string;
    localDate: string;
  }): Promise<StoredProposal>;
  acceptProposalNow(
    userId: string,
    proposalId: string,
    planVersionId: string,
    availabilityVersionId: string,
    generatedAt: string,
    acceptedAt: string,
    localDate?: string,
  ): Promise<AcceptedProposal>;
  scheduleProposal(
    userId: string,
    proposalId: string,
    planVersionId: string,
    availabilityVersionId: string,
    scheduledAt: string,
    localDate?: string,
  ): Promise<ScheduledProposal>;
  cancelScheduledProposal(
    userId: string,
    proposalId: string,
    cancelledAt: string,
  ): Promise<CancelledProposal>;
  activateDueProposal(
    userId: string,
    activationId: string,
    activatedAt: string,
    localDate?: string,
  ): Promise<ActivatedProposal>;
  undoAcceptedProposal(
    userId: string,
    proposalId: string,
    undoneAt: string,
  ): Promise<UndoneProposal>;
  now(): Date;
  randomId(): string;
};

const DAY_MS = 86_400_000;
const DAY_NAMES: Record<string, number> = {
  day_mon: 1,
  day_tue: 2,
  day_wed: 3,
  day_thu: 4,
  day_fri: 5,
  day_sat: 6,
  day_sun: 7,
};
const SCHEDULED_PLAN_VERSION_PREFIX = "schedule-plan:";
const SCHEDULED_AVAILABILITY_VERSION_PREFIX = "schedule-availability:";
const UNLIMITED_DAY_CAP_MINUTES = 10_000;
const ProposalTtlMs = 30 * 60 * 1000;

const StoredProposalResponseSchema = z.object({
  id: z.string(),
  expires_at: z.string(),
});
const AcceptProposalResponseSchema = z.object({
  accepted_plan_version_id: z.string(),
  plan_data: z.record(z.unknown()),
  prior_active_plan_version_id: z.string().nullable(),
  prior_active_availability_version_id: z.string().nullable(),
  accepted_availability_version_id: z.string(),
});
const ScheduleProposalResponseSchema = z.object({
  proposal_id: z.string(),
  activation_id: z.string(),
  scheduled_plan_version_id: z.string(),
  scheduled_availability_version_id: z.string(),
  activation_status: z.string(),
});
const CancelProposalResponseSchema = z.object({
  proposal_id: z.string(),
  proposal_status: z.string(),
  activation_id: z.union([z.string(), z.null()]),
  scheduled_plan_version_id: z.union([z.string(), z.null()]),
});
const ActivateProposalResponseSchema = z.object({
  proposal_id: z.union([z.string(), z.null()]),
  activation_id: z.string(),
  proposal_status: z.union([z.string(), z.null()]),
  accepted_plan_version_id: z.union([z.string(), z.null()]),
  prior_active_plan_version_id: z.union([z.string(), z.null()]),
  prior_active_availability_version_id: z.union([z.string(), z.null()]),
  accepted_availability_version_id: z.union([z.string(), z.null()]),
  activation_status: z.string(),
});
const UndoProposalResponseSchema = z.object({
  proposal_id: z.string(),
  prior_plan_version_id: z.union([z.string(), z.null()]),
  prior_availability_version_id: z.union([z.string(), z.null()]),
  restored_plan_version_id: z.union([z.string(), z.null()]),
  restored_availability_version_id: z.union([z.string(), z.null()]),
});

function parseRpcResponse<T>(name: string, schema: z.ZodType<T>, data: unknown): T {
  const row = Array.isArray(data) ? data.length === 1 ? data[0] : undefined : data;
  if (Array.isArray(data) && (data.length !== 1 || row == null)) {
    throw new Error(`Invalid ${name} response`);
  }
  const candidate = row;
  const parsed = schema.safeParse(candidate);
  if (!parsed.success) {
    throw new Error(`Invalid ${name} response`);
  }
  return parsed.data;
}

const DateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(
  (value) => parseDateOnly(value) != null,
  "Invalid calendar date",
);
const SameDayPreferenceRawSchema = z.enum([
  "separate_sessions",
  "avoid_same_day",
]);
const DayAvailabilityInputSchema = z.object({
  day: z.number().int().min(1).max(7),
  available: z.boolean(),
  max_duration_minutes: z.number().int().positive().nullable().optional(),
}).strict();
const AvailabilityInputSchema = z.object({
  days: z.array(DayAvailabilityInputSchema).length(7),
  target_running_days: z.number().int().min(1).max(7),
  primary_long_run_weekday: z.number().int().min(1).max(7),
  backup_long_run_weekday: z.number().int().min(1).max(7).nullable().optional(),
  same_day_run_strength_preference: SameDayPreferenceRawSchema,
}).strict();

export const PreviewRequestSchema = z.object({
  action: z.literal("preview"),
  availability: AvailabilityInputSchema,
  localDate: DateOnlySchema,
  effectiveFrom: DateOnlySchema.optional(),
}).strict();

export const AcceptRequestSchema = z.object({
  action: z.literal("accept_now"),
  proposalId: z.string().min(1),
  localDate: DateOnlySchema.optional(),
}).strict();

export const ScheduleRequestSchema = z.object({
  action: z.literal("schedule"),
  proposalId: z.string().min(1),
  localDate: DateOnlySchema.optional(),
}).strict();

export const CancelRequestSchema = z.object({
  action: z.literal("cancel_scheduled"),
  proposalId: z.string().min(1),
}).strict();

export const ActivateRequestSchema = z.object({
  action: z.literal("activate_due"),
  activationId: z.string().min(1),
  localDate: DateOnlySchema.optional(),
}).strict();

export const UndoRequestSchema = z.object({
  action: z.literal("undo"),
  proposalId: z.string().min(1),
}).strict();

const ChangeScheduleRequestSchema = z.union([
  PreviewRequestSchema,
  AcceptRequestSchema,
  ScheduleRequestSchema,
  CancelRequestSchema,
  ActivateRequestSchema,
  UndoRequestSchema,
]);

export type PreviewRequest = z.infer<typeof PreviewRequestSchema>;
export type AcceptRequest = z.infer<typeof AcceptRequestSchema>;
export type ScheduleRequest = z.infer<typeof ScheduleRequestSchema>;
export type CancelRequest = z.infer<typeof CancelRequestSchema>;
export type ActivateRequest = z.infer<typeof ActivateRequestSchema>;
export type UndoRequest = z.infer<typeof UndoRequestSchema>;

export function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function createChangeScheduleHandler(
  dependencies: ChangeScheduleDependencies,
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
    const parsed = ChangeScheduleRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return jsonResponse({
        error: "invalid_request",
        detail: parsed.error.format(),
      }, 400);
    }

    try {
      const action = parsed.data.action;
      if (action === "preview") {
        const now = dependencies.now();
        if (!isLocalDateWithinServerWindow(parsed.data.localDate, now)) {
          return jsonResponse({ error: "invalid_request" }, 400);
        }
        return await previewSchedule(dependencies, userId, parsed.data, now);
      }
      if (action === "accept_now") {
        const now = dependencies.now();
        if (!isLocalDateWithinServerWindow(parsed.data.localDate, now)) {
          return jsonResponse({ error: "invalid_request" }, 400);
        }
        return await acceptScheduleNow(dependencies, userId, parsed.data, now);
      }
      if (action === "schedule") {
        const now = dependencies.now();
        if (!isLocalDateWithinServerWindow(parsed.data.localDate, now)) {
          return jsonResponse({ error: "invalid_request" }, 400);
        }
        return await scheduleProposal(dependencies, userId, parsed.data, now);
      }
      if (action === "cancel_scheduled") {
        return await cancelScheduledProposal(dependencies, userId, parsed.data);
      }
      if (action === "activate_due") {
        const now = dependencies.now();
        if (!isLocalDateWithinServerWindow(parsed.data.localDate, now)) {
          return jsonResponse({ error: "invalid_request" }, 400);
        }
        return await activateDueProposal(dependencies, userId, parsed.data, now);
      }
      return await undoAcceptedProposal(dependencies, userId, parsed.data);
    } catch (error) {
      const mapped = mapRpcError(error);
      if (mapped != null) {
        return jsonResponse({ error: mapped.key }, mapped.status);
      }
      console.error("change-schedule failed", errorForLog(error));
      return jsonResponse({ error: "change_schedule_failed" }, 500);
    }
  };
}

async function previewSchedule(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: PreviewRequest,
  now: Date,
): Promise<Response> {
  const context = await dependencies.loadPreviewContext(userId);
  if (context == null) {
    return jsonResponse({ error: "source_plan_stale" }, 409);
  }

  const availability = normalizeAvailability(request.availability);
  const sourceSessions = sessionsFromPlan(context.sourcePlan).filter(
    (session) => isValidDateOnly(session.date),
  );
  const sourcePlan = {
    ...(context.sourcePlan as JsonObject),
    sessions: sourceSessions,
  };

  const effectiveFrom = determineEffectiveFrom(
    request.effectiveFrom,
    request.localDate,
  );
  if (effectiveFrom == null) {
    return jsonResponse({ error: "invalid_request" }, 400);
  }
  const asOfDate = request.localDate;

  const reflowInput = {
    sourcePlan,
    availability: availability.engineAvailability,
    targetRunningDays: availability.targetRunningDays,
    primaryLongRunDay: availability.primaryLongRunWeekday,
    backupLongRunDay: availability.backupLongRunWeekday ?? undefined,
    sameDayPreference: availability.sameDayPreference,
    strengthWeekdays: strengthWeekdaysFromProfile(context.profile),
    immutableSessionIds: context.immutableSessionIds,
    effectiveFrom,
    asOfDate,
  } as const;

  const result = reflowPlan(reflowInput);
  if (!result.ok) {
    return jsonResponse({ error: "invalid_request", detail: result.reason }, 400);
  }

  const proposalId = dependencies.randomId();
  const expiresAt = new Date(now.getTime() + ProposalTtlMs).toISOString();
  const stored = await dependencies.storeProposal({
    userId,
    proposalId,
    sourcePlanVersionId: context.sourcePlanVersionId,
    candidatePlan: result.candidatePlan as JsonObject,
    impact: {
      impact: result.impacts,
      warnings: result.warnings,
      goalImpact: result.goalImpact,
    },
    proposedAvailability: availability.dbAvailability,
    effectiveFrom,
    createdAt: now.toISOString(),
    expiresAt,
    sourceProfileSchemaVersion: context.profileSchemaVersion,
    sourceProfileUpdatedAt: context.profileUpdatedAt,
    localDate: request.localDate,
  });

  return jsonResponse({
    state: "preview",
    proposalId: stored.id,
    sourcePlanVersionId: context.sourcePlanVersionId,
    effectiveFrom,
    asOfDate,
    expiresAt: stored.expires_at,
    candidatePlan: result.candidatePlan,
    impacts: result.impacts,
    warnings: result.warnings,
    goalImpact: result.goalImpact,
    proposedAvailability: availability.dbAvailability,
  });
}

async function acceptScheduleNow(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: AcceptRequest,
  now: Date,
): Promise<Response> {
  const acceptedAt = now.toISOString();
  const planVersionId = dependencies.randomId();
  const availabilityVersionId = dependencies.randomId();
  const generatedAt = acceptedAt;
  const accepted = await dependencies.acceptProposalNow(
    userId,
    request.proposalId,
    planVersionId,
    availabilityVersionId,
    generatedAt,
    acceptedAt,
    request.localDate,
  );
  return jsonResponse({
    versionId: accepted.accepted_plan_version_id,
    plan: accepted.plan_data,
    priorActivePlanVersionId: accepted.prior_active_plan_version_id,
    priorActiveAvailabilityVersionId:
      accepted.prior_active_availability_version_id,
    acceptedAvailabilityVersionId: accepted.accepted_availability_version_id,
  });
}

async function scheduleProposal(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: ScheduleRequest,
  now: Date,
): Promise<Response> {
  const scheduledAt = now.toISOString();
  const planVersionId = buildScheduledPlanVersionId(request.proposalId);
  const availabilityVersionId = buildScheduledAvailabilityVersionId(request.proposalId);
  const scheduled = await dependencies.scheduleProposal(
    userId,
    request.proposalId,
    planVersionId,
    availabilityVersionId,
    scheduledAt,
    request.localDate,
  );
  return jsonResponse({
    proposalId: scheduled.proposal_id,
    activationId: scheduled.activation_id,
    scheduledPlanVersionId: scheduled.scheduled_plan_version_id,
    scheduledAvailabilityVersionId: scheduled.scheduled_availability_version_id,
    activationStatus: scheduled.activation_status,
  });
}

function buildScheduledPlanVersionId(proposalId: string): string {
  return `${SCHEDULED_PLAN_VERSION_PREFIX}${proposalId}`;
}

function buildScheduledAvailabilityVersionId(proposalId: string): string {
  return `${SCHEDULED_AVAILABILITY_VERSION_PREFIX}${proposalId}`;
}

async function cancelScheduledProposal(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: CancelRequest,
): Promise<Response> {
  const cancelledAt = dependencies.now().toISOString();
  const cancelled = await dependencies.cancelScheduledProposal(
    userId,
    request.proposalId,
    cancelledAt,
  );
  return jsonResponse({
    proposalId: cancelled.proposal_id,
    proposalStatus: cancelled.proposal_status,
    activationId: cancelled.activation_id,
    scheduledPlanVersionId: cancelled.scheduled_plan_version_id,
  });
}

async function activateDueProposal(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: ActivateRequest,
  now: Date,
): Promise<Response> {
  const activatedAt = now.toISOString();
  const activated = await dependencies.activateDueProposal(
    userId,
    request.activationId,
    activatedAt,
    request.localDate,
  );
  return jsonResponse({
    proposalId: activated.proposal_id,
    activationId: activated.activation_id,
    proposalStatus: activated.proposal_status,
    acceptedPlanVersionId: activated.accepted_plan_version_id,
    priorActivePlanVersionId: activated.prior_active_plan_version_id,
    priorActiveAvailabilityVersionId: activated.prior_active_availability_version_id,
    acceptedAvailabilityVersionId: activated.accepted_availability_version_id,
    activationStatus: activated.activation_status,
  });
}

async function undoAcceptedProposal(
  dependencies: ChangeScheduleDependencies,
  userId: string,
  request: UndoRequest,
): Promise<Response> {
  const undoneAt = dependencies.now().toISOString();
  const undone = await dependencies.undoAcceptedProposal(
    userId,
    request.proposalId,
    undoneAt,
  );
  return jsonResponse({
    proposalId: undone.proposal_id,
    priorPlanVersionId: undone.prior_plan_version_id,
    priorAvailabilityVersionId: undone.prior_availability_version_id,
    restoredPlanVersionId: undone.restored_plan_version_id,
    restoredAvailabilityVersionId: undone.restored_availability_version_id,
  });
}

function determineEffectiveFrom(
  requested: string | undefined,
  localDate: string,
): string | null {
  const localCalendarDate = parseDateOnly(localDate);
  if (localCalendarDate == null) return null;
  const currentMonday = toMonday(localCalendarDate);
  const requestedDate = requested == null ? currentMonday : parseDateOnly(requested);
  if (requestedDate == null) return null;
  if (requestedDate.getTime() !== toMonday(requestedDate).getTime()) return null;
  const nextMonday = new Date(currentMonday.getTime() + 7 * DAY_MS);
  if (
    requestedDate.getTime() !== currentMonday.getTime() &&
    requestedDate.getTime() !== nextMonday.getTime()
  ) {
    return null;
  }
  return requestedDate.toISOString().slice(0, 10);
}

function isLocalDateWithinServerWindow(
  localDate: string | undefined,
  serverNow: Date,
): boolean {
  if (localDate == null) return true;
  const parsedLocalDate = parseDateOnly(localDate);
  if (parsedLocalDate == null) return false;
  const serverUtcDate = new Date(Date.UTC(
    serverNow.getUTCFullYear(),
    serverNow.getUTCMonth(),
    serverNow.getUTCDate(),
  ));
  return Math.abs(parsedLocalDate.getTime() - serverUtcDate.getTime()) <= DAY_MS;
}

function normalizeAvailability(input: unknown): {
  engineAvailability: Record<string, { available: boolean; maxDurationMinutes: number }>;
  dbAvailability: JsonObject;
  targetRunningDays: number;
  primaryLongRunWeekday: number;
  backupLongRunWeekday: number | null;
  sameDayPreference: "separate_sessions" | "avoid_same_day";
} {
  const parsed = AvailabilityInputSchema.safeParse(input);
  if (!parsed.success) throw new Error("invalid_request");

  const targetRunningDays = parsed.data.target_running_days;
  const primaryLongRunWeekday = parsed.data.primary_long_run_weekday;
  const backupLongRunWeekday = parsed.data.backup_long_run_weekday ?? null;
  const rawPreference = parsed.data.same_day_run_strength_preference;

  const sameDayPreference = rawPreference;

  const dayRecords = parsed.data.days;
  const seenDays = new Set<number>();
  const engineAvailability: Record<string, { available: boolean; maxDurationMinutes: number
  }> = {};
  const canonicalDays: Array<{ day: number; available: boolean; max_duration_minutes: number | null }> = [];

  for (const row of dayRecords) {
    if (seenDays.has(row.day)) {
      throw new Error("change_schedule_availability_payload_day_duplicate");
    }
    seenDays.add(row.day);

    const maxDurationMinutes = row.max_duration_minutes ?? null;
    if (maxDurationMinutes != null) {
      if (maxDurationMinutes <= 0 || !Number.isInteger(maxDurationMinutes)) {
        throw new Error("change_schedule_availability_payload_duration_invalid");
      }
    }
    canonicalDays.push({
      day: row.day,
      available: row.available,
      max_duration_minutes: maxDurationMinutes,
    });
    engineAvailability[String(row.day)] = {
      available: row.available,
      maxDurationMinutes: row.available
        ? (maxDurationMinutes == null
          ? UNLIMITED_DAY_CAP_MINUTES
          : maxDurationMinutes)
        : 0,
    };
  }

  for (let day = 1; day <= 7; day += 1) {
    if (!seenDays.has(day)) {
      throw new Error("change_schedule_availability_payload_day_missing");
    }
  }

  const availableCount = canonicalDays.filter((entry) => entry.available).length;
  if (availableCount !== targetRunningDays) {
    throw new Error("change_schedule_availability_payload_target_running_days_mismatch");
  }

  return {
    engineAvailability,
    dbAvailability: {
      days: canonicalDays,
      target_running_days: targetRunningDays,
      primary_long_run_weekday: primaryLongRunWeekday,
      ...(backupLongRunWeekday == null ? {} : {
        backup_long_run_weekday: backupLongRunWeekday,
      }),
      same_day_run_strength_preference: sameDayPreference,
    },
    targetRunningDays,
    primaryLongRunWeekday,
    backupLongRunWeekday,
    sameDayPreference,
  };
}

function sessionsFromPlan(plan: JsonObject): ScheduleSession[] {
  if (!Array.isArray(plan.sessions)) return [];
  return plan.sessions.filter((session): session is ScheduleSession =>
    isRecord(session) &&
    typeof session.id === "string" &&
    typeof session.date === "string" &&
    typeof session.weekNumber === "number" &&
    typeof session.type === "string"
  );
}

function isValidDateOnly(value: string): boolean {
  return parseDateOnly(value.slice(0, 10)) != null;
}

function toMonday(value: Date): Date {
  const weekday = value.getUTCDay();
  const mondayShift = weekday === 0 ? 6 : weekday - 1;
  const monday = new Date(value.getTime() - mondayShift * DAY_MS);
  monday.setUTCHours(0, 0, 0, 0);
  return monday;
}

function strengthWeekdaysFromProfile(profile: JsonObject): number[] {
  const strength = isRecord(profile.strength) ? profile.strength : null;
  if (strength == null || !isRecord(strength) || !Array.isArray(strength.preferredDays)) {
    return [];
  }
  const out: number[] = [];
  for (const raw of strength.preferredDays) {
    const day = toDayNumber(raw);
    if (day != null && !out.includes(day)) out.push(day);
  }
  return out;
}

function toDayNumber(value: unknown): number | null {
  if (typeof value === "string") {
    const normalized = DAY_NAMES[value];
    return normalized == null ? null : normalized;
  }
  return null;
}

export function mapRpcError(error: unknown): { key: string; status: number } | null {
  const message = errorMessage(error);
  const mappings: Array<[string, string, number]> = [
    ["change_schedule_proposal_not_found", "proposal_not_found", 404],
    ["change_schedule_proposal_not_accepted", "proposal_not_accepted", 409],
    ["change_schedule_proposal_not_pending", "proposal_not_pending", 409],
    ["change_schedule_proposal_not_current_week", "proposal_not_current_week", 409],
    ["change_schedule_proposal_not_scheduled", "proposal_not_scheduled", 409],
    ["change_schedule_proposal_expired", "proposal_expired", 409],
    ["change_schedule_plan_version_id_missing", "proposal_plan_id_missing", 400],
    ["change_schedule_availability_id_missing", "proposal_availability_id_missing", 400],
    ["change_schedule_proposal_source_profile_stale", "source_profile_stale", 409],
    ["change_schedule_proposal_source_plan_not_active", "source_plan_stale", 409],
    ["change_schedule_source_plan_stale", "source_plan_stale", 409],
    ["change_schedule_proposal_profile_snapshot_mismatch", "profile_snapshot_mismatch", 409],
    ["change_schedule_proposal_profile_snapshot_missing", "profile_snapshot_missing", 409],
    ["change_schedule_accept_prior_availability_not_found", "proposal_inconsistent", 500],
    ["change_schedule_proposal_profile_not_found", "profile_not_found", 404],
    ["change_schedule_accept_profile_not_found", "profile_not_found", 404],
    ["change_schedule_accept_availability_id_conflict", "proposal_availability_id_conflict", 409],
    ["change_schedule_availability_id_conflict", "proposal_availability_id_conflict", 409],
    ["change_schedule_proposal_invalid_created_at", "invalid_request", 400],
    ["change_schedule_proposal_invalid_expiry", "invalid_request", 400],
    ["change_schedule_activation_timestamp_missing", "invalid_request", 400],
    ["change_schedule_proposal_inconsistent", "proposal_inconsistent", 500],
    ["change_schedule_activation_proposal_source_mismatch", "proposal_inconsistent", 500],
    ["change_schedule_activation_proposal_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_activation_proposal_inconsistent", "proposal_inconsistent", 500],
    ["change_schedule_activation_terminal_status_rejects_proposal", "proposal_inconsistent", 500],
    ["change_schedule_activation_source_plan_not_active", "source_plan_stale", 409],
    ["change_schedule_activation_snapshot_plan_missing", "proposal_inconsistent", 500],
    ["change_schedule_activation_snapshot_availability_missing", "proposal_inconsistent", 500],
    ["change_schedule_activation_snapshot_immutable", "proposal_inconsistent", 500],
    ["change_schedule_activation_candidate_plan_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_activation_availability_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_activation_availability_schedule_mismatch", "proposal_inconsistent", 500],
    ["change_schedule_activation_availability_state_mismatch", "proposal_inconsistent", 500],
    ["change_schedule_activate_prior_plan_missing", "proposal_inconsistent", 500],
    ["change_schedule_proposal_acceptance_requires_activated_activation", "proposal_inconsistent", 500],
    ["change_schedule_proposal_accepted_activation_context_mismatch", "proposal_inconsistent", 500],
    ["change_schedule_proposal_terminalization_activation_not_found", "proposal_inconsistent", 500],
    ["change_schedule_proposal_prior_plan_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_proposal_prior_availability_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_proposal_scheduled_plan_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_proposal_accepted_plan_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_proposal_accepted_availability_not_owned", "proposal_inconsistent", 500],
    ["change_schedule_proposal_terminalization_requires_schedule_clear", "proposal_inconsistent", 500],
    ["change_schedule_proposal_terminalization_lineage_rewrite", "proposal_inconsistent", 500],
    ["change_schedule_accept_prior_plan_not_found", "proposal_inconsistent", 500],
    ["change_schedule_proposal_effective_from_not_monday", "proposal_effective_from_not_monday", 400],
    ["change_schedule_proposal_effective_from_not_future", "proposal_effective_from_not_future", 409],
    ["change_schedule_proposal_effective_from_in_past", "proposal_effective_from_in_past", 409],
    ["change_schedule_proposal_effective_from_missing", "proposal_effective_from_missing", 400],
    ["change_schedule_plan_version_id_conflict", "proposal_plan_version_conflict", 409],
    ["change_schedule_accept_plan_id_missing", "plan_id_missing", 400],
    ["change_schedule_accept_availability_id_missing", "availability_id_missing", 400],
    ["change_schedule_undo_not_available", "undo_not_available", 409],
    ["change_schedule_undo_plan_not_active", "undo_plan_not_active", 409],
    ["change_schedule_undo_prior_plan_missing", "undo_prior_plan_missing", 409],
    ["change_schedule_undo_timestamp_missing", "invalid_request", 400],
    ["change_schedule_undo_blocked_by_activity", "undo_blocked_by_activity", 409],
    ["change_schedule_activation_not_found", "activation_not_found", 404],
    ["change_schedule_activation_not_due", "activation_not_due", 409],
    ["change_schedule_activation_proposal_not_found", "activation_proposal_not_found", 404],
    ["change_schedule_activation_proposal_not_available", "activation_not_available", 409],
    ["change_schedule_activation_proposal_ambiguous", "activation_ambiguous", 500],
    ["change_schedule_proposal_cancelled_timestamp_missing", "invalid_request", 400],
    ["change_schedule_proposal_not_scheduled", "proposal_not_scheduled", 409],
    ["change_schedule_proposal_inactive_source_plan", "source_plan_stale", 409],
    ["change_schedule_proposal_user_missing", "unauthorized", 401],
    ["change_schedule_user_missing", "unauthorized", 401],
  ];
  for (const [needle, key, status] of mappings) {
    if (message.includes(needle)) return { key, status };
  }
  // Keep explicit user-actionable response mapping first, then collapse remaining
  // proposal/activation/accept integrity/lineage/domain errors to a stable 500 class.
  for (const prefix of [
    "change_schedule_availability_payload_",
  ]) {
    if (message.includes(prefix)) {
      return { key: "invalid_request", status: 400 };
    }
  }
  for (const prefix of [
    "change_schedule_proposal_",
    "change_schedule_activation_",
    "change_schedule_accept_",
  ]) {
    if (message.includes(prefix)) {
      return { key: "proposal_inconsistent", status: 500 };
    }
  }
  return null;
}

export function createProductionDependencies(
  publicClient: SupabaseClient,
  admin: SupabaseClient,
): ChangeScheduleDependencies {
  return {
    async authenticate(authHeader) {
      const jwt = authHeader.slice("Bearer ".length);
      const { data, error } = await publicClient.auth.getClaims(jwt);
      return error == null && typeof data?.claims?.sub === "string"
        ? data.claims.sub
        : null;
    },
    async loadPreviewContext(userId) {
      const [profileResult, planResult] = await Promise.all([
        admin.from("runner_profiles").select("data,schema_version,updated_at")
          .eq("user_id", userId).maybeSingle(),
        admin.from("plan_versions").select("id,data")
          .eq("user_id", userId)
          .eq("is_active", true).maybeSingle(),
      ]);

      for (const result of [profileResult, planResult]) {
        if (result.error != null) throw result.error;
      }

      const profileRow = profileResult.data;
      const profileSchemaVersion = profileRow?.schema_version;
      const profileUpdatedAt = typeof profileRow?.updated_at === "string"
        ? profileRow.updated_at
        : profileRow?.updated_at instanceof Date
        ? profileRow.updated_at.toISOString()
        : null;
      const planRow = planResult.data;

      if (
        !isRecord(profileRow?.data) ||
        typeof planRow?.id !== "string" ||
        !isInteger(profileSchemaVersion) ||
        !isString(profileUpdatedAt) ||
        !isRecord(planRow?.data)
      ) {
        return null;
      }

      const activityResult = await admin.from("activity_records")
        .select("linked_session_id")
        .eq("user_id", userId)
        .eq("plan_version_id", planRow.id);
      if (activityResult.error != null) throw activityResult.error;

      const immutableSessionIds = new Set<string>();
      for (const row of (activityResult.data ?? [])) {
        if (typeof row.linked_session_id === "string") {
          immutableSessionIds.add(row.linked_session_id);
        }
      }
      for (const session of sessionsFromPlan(planRow.data).filter((session) =>
        isCompletedSessionStatus(session.status)
      )) {
        immutableSessionIds.add(session.id);
      }

      return {
        profile: profileRow.data,
        sourcePlanVersionId: planRow.id,
        sourcePlan: planRow.data,
        profileSchemaVersion,
        profileUpdatedAt,
        immutableSessionIds: Array.from(immutableSessionIds),
      };
    },
    async storeProposal(input) {
      const { data, error } = await admin.rpc("store_change_schedule_proposal", {
        p_user_id: input.userId,
        p_proposal_id: input.proposalId,
        p_source_plan_version_id: input.sourcePlanVersionId,
        p_candidate_plan: input.candidatePlan,
        p_impact: input.impact,
        p_proposed_availability: input.proposedAvailability,
        p_effective_from: input.effectiveFrom,
        p_created_at: input.createdAt,
        p_expires_at: input.expiresAt,
        p_source_profile_schema_version: input.sourceProfileSchemaVersion,
        p_source_profile_updated_at: input.sourceProfileUpdatedAt,
        p_local_date: input.localDate,
      });
      if (error != null) throw error;
      return parseRpcResponse("store_change_schedule_proposal", StoredProposalResponseSchema, data);
    },
    async acceptProposalNow(
      userId,
      proposalId,
      planVersionId,
      availabilityVersionId,
      generatedAt,
      acceptedAt,
      localDate,
    ) {
      const { data, error } = await admin.rpc("accept_change_schedule_proposal_now", {
        p_user_id: userId,
        p_proposal_id: proposalId,
        p_plan_version_id: planVersionId,
        p_availability_version_id: availabilityVersionId,
        p_generated_at: generatedAt,
        p_accepted_at: acceptedAt,
        ...(localDate == null ? {} : { p_local_date: localDate }),
      });
      if (error != null) throw error;
      return parseRpcResponse(
        "accept_change_schedule_proposal_now",
        AcceptProposalResponseSchema,
        data,
      );
    },
    async scheduleProposal(
      userId,
      proposalId,
      planVersionId,
      availabilityVersionId,
      scheduledAt,
      localDate,
    ) {
      const { data, error } = await admin.rpc("schedule_change_schedule_proposal", {
        p_user_id: userId,
        p_proposal_id: proposalId,
        p_plan_version_id: planVersionId,
        p_availability_version_id: availabilityVersionId,
        p_scheduled_at: scheduledAt,
        ...(localDate == null ? {} : { p_local_date: localDate }),
      });
      if (error != null) throw error;
      return parseRpcResponse(
        "schedule_change_schedule_proposal",
        ScheduleProposalResponseSchema,
        data,
      );
    },
    async cancelScheduledProposal(userId, proposalId, cancelledAt) {
      const { data, error } = await admin.rpc(
        "cancel_scheduled_change_schedule_proposal",
        {
          p_user_id: userId,
          p_proposal_id: proposalId,
          p_cancelled_at: cancelledAt,
        },
      );
      if (error != null) throw error;
      return parseRpcResponse(
        "cancel_scheduled_change_schedule_proposal",
        CancelProposalResponseSchema,
        data,
      );
    },
    async activateDueProposal(userId, activationId, activatedAt, localDate) {
      const { data, error } = await admin.rpc("activate_due_change_schedule", {
        p_user_id: userId,
        p_activation_id: activationId,
        p_activated_at: activatedAt,
        ...(localDate == null ? {} : { p_local_date: localDate }),
      });
      if (error != null) throw error;
      return parseRpcResponse(
        "activate_due_change_schedule",
        ActivateProposalResponseSchema,
        data,
      );
    },
    async undoAcceptedProposal(userId, proposalId, undoneAt) {
      const { data, error } = await admin.rpc("undo_accepted_change_schedule_proposal", {
        p_user_id: userId,
        p_proposal_id: proposalId,
        p_undone_at: undoneAt,
      });
      if (error != null) throw error;
      return parseRpcResponse(
        "undo_accepted_change_schedule_proposal",
        UndoProposalResponseSchema,
        data,
      );
    },
    now: () => new Date(),
    randomId: () => crypto.randomUUID(),
  };
}

function parseDateOnly(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value
    ? date
    : null;
}

function isRecord(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function isInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && Number.isInteger(value);
}

function isString(value: unknown): value is string {
  return typeof value === "string";
}

function isCompletedSessionStatus(status: unknown): boolean {
  return status === "completed" || status === "skipped" || status === "started" ||
    status === "active";
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (isRecord(error) && typeof error.message === "string") {
    return error.message;
  }
  return String(error);
}

function errorForLog(error: unknown): JsonObject {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      ...(typeof error.stack === "string" ? { stack: error.stack } : {}),
    };
  }

  if (isRecord(error)) {
    return {
      ...(typeof error.code === "string" ? { code: error.code } : {}),
      ...(typeof error.message === "string" ? { message: error.message } : {}),
      ...(typeof error.details === "string" ? { details: error.details } : {}),
      ...(typeof error.hint === "string" ? { hint: error.hint } : {}),
    };
  }

  return { message: String(error) };
}
