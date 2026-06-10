import type { CoachingBrief } from "./coaching-brief.ts";
import {
  type GeneratedSession,
  type TargetedSessionRepairPatchResponse,
} from "./schema.ts";
import {
  repairTargetedSessionPatchesWithOpenAi,
  type TargetedSessionRepairPatchPriorFailurePayload,
} from "./openai.ts";
import {
  detectSessionTypePolicyViolations,
  mergeTargetedSessionRepairPatches,
  type SessionRepairPatchFailure,
  type SessionTypePolicyViolation,
} from "./plan-rules.ts";

type SupportedLocale = "en" | "es";

type RepairPatchResponseFn = (
  profileData: Record<string, unknown>,
  totalWeeks: number,
  sessionsNeedingRepair: readonly GeneratedSession[],
  violations: readonly SessionTypePolicyViolation[],
  locale: SupportedLocale,
  coachingBrief: CoachingBrief | null,
  priorFailureReasons: TargetedSessionRepairPatchPriorFailurePayload,
) => Promise<TargetedSessionRepairPatchResponse>;

export type RepairPolicyViolationsResultSuccess = {
  ok: true;
  sessions: GeneratedSession[];
  acceptedSessionIds: string[];
  attempts: number;
};

export type RepairPolicyViolationsResultFailure = {
  ok: false;
  sessions: GeneratedSession[];
  remainingViolations: SessionTypePolicyViolation[];
  repairFailures: SessionRepairPatchFailure[];
  attempts: number;
};

export type RepairPolicyViolationsResult =
  | RepairPolicyViolationsResultSuccess
  | RepairPolicyViolationsResultFailure;

function dedupeSessionIds(sessionIds: readonly string[]): string[] {
  const seen = new Set<string>();
  const deduped: string[] = [];
  for (const sessionId of sessionIds) {
    if (seen.has(sessionId)) continue;
    seen.add(sessionId);
    deduped.push(sessionId);
  }
  return deduped;
}

function failurePayloadFromReasonMap(
  failureReasons: Map<string, string>,
  sessionIds: readonly string[],
): TargetedSessionRepairPatchPriorFailurePayload {
  const payload: TargetedSessionRepairPatchPriorFailurePayload = {};
  for (const sessionId of sessionIds) {
    const reason = failureReasons.get(sessionId);
    if (reason != null) {
      payload[sessionId] = reason;
    }
  }
  return payload;
}

function errorFailure(
  sessionId: string,
  error: unknown,
  attempt: number,
): SessionRepairPatchFailure {
  return {
    sessionId,
    reason: `OpenAI repair failed on attempt ${attempt}: ${String(error)}`,
  };
}

function missingPatchFailure(sessionId: string): SessionRepairPatchFailure {
  return {
    sessionId,
    reason: "Missing patch response for this session.",
  };
}

export async function repairPolicyViolationsWithOpenAiPatches(
  sessions: readonly GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  locale: SupportedLocale,
  coachingBrief: CoachingBrief | null,
  maxAttempts = 3,
  repairFn: RepairPatchResponseFn = repairTargetedSessionPatchesWithOpenAi,
): Promise<RepairPolicyViolationsResult> {
  let currentSessions = [...sessions];
  let remainingViolations = detectSessionTypePolicyViolations(
    currentSessions,
    profileData,
    totalWeeks,
    coachingBrief,
  );

  if (remainingViolations.length === 0) {
    return {
      ok: true,
      sessions: currentSessions,
      acceptedSessionIds: [],
      attempts: 0,
    };
  }

  let attempts = 0;
  const acceptedSessionIds: string[] = [];
  const acceptedSessionIdSet = new Set<string>();
  const persistedFailures = new Map<string, string>();
  let latestRepairFailures: SessionRepairPatchFailure[] = [];

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    attempts = attempt;
    remainingViolations = detectSessionTypePolicyViolations(
      currentSessions,
      profileData,
      totalWeeks,
      coachingBrief,
    );
    if (remainingViolations.length === 0) {
      return {
        ok: true,
        sessions: currentSessions,
        acceptedSessionIds,
        attempts: attempts - 1,
      };
    }

    const requestedSessionIds = dedupeSessionIds(
      remainingViolations.map((violation) => violation.sessionId),
    );
    const sessionsNeedingRepair = currentSessions.filter((session) =>
      requestedSessionIds.includes(session.id)
    );
    const priorFailureReasons = failurePayloadFromReasonMap(
      persistedFailures,
      requestedSessionIds,
    );
    latestRepairFailures = [];
    let repairResponse: TargetedSessionRepairPatchResponse | null = null;

    try {
      repairResponse = await repairFn(
        profileData,
        totalWeeks,
        sessionsNeedingRepair,
        remainingViolations,
        locale,
        coachingBrief,
        priorFailureReasons,
      );
    } catch (error) {
      latestRepairFailures = requestedSessionIds.map((sessionId) =>
        errorFailure(sessionId, error, attempt)
      );
      for (const failure of latestRepairFailures) {
        persistedFailures.set(failure.sessionId, failure.reason);
      }
    }

    if (repairResponse == null) {
      continue;
    }

    const responseRepairs = repairResponse.repairs;
    const missingSessionIds = requestedSessionIds.filter((sessionId) => {
      const hasMatchingResponse = responseRepairs.some((repair) =>
        repair.sessionId === sessionId
      );
      return !hasMatchingResponse;
    });

    const mergedResult = mergeTargetedSessionRepairPatches(
      currentSessions,
      requestedSessionIds,
      responseRepairs,
      profileData,
      totalWeeks,
      coachingBrief,
    );
    currentSessions = mergedResult.sessions;

    for (const sessionId of mergedResult.acceptedSessionIds) {
      if (!acceptedSessionIdSet.has(sessionId)) {
        acceptedSessionIdSet.add(sessionId);
        acceptedSessionIds.push(sessionId);
      }
      persistedFailures.delete(sessionId);
    }

    latestRepairFailures = [
      ...mergedResult.rejectedRepairs,
      ...missingSessionIds.map((sessionId) => missingPatchFailure(sessionId)),
    ];

    for (const failure of latestRepairFailures) {
      persistedFailures.set(failure.sessionId, failure.reason);
    }

    remainingViolations = detectSessionTypePolicyViolations(
      currentSessions,
      profileData,
      totalWeeks,
      coachingBrief,
    );
    if (remainingViolations.length === 0) {
      return {
        ok: true,
        sessions: currentSessions,
        acceptedSessionIds,
        attempts,
      };
    }

    if (attempt === maxAttempts) {
      remainingViolations = detectSessionTypePolicyViolations(
        currentSessions,
        profileData,
        totalWeeks,
        coachingBrief,
      );
      return {
        ok: false,
        sessions: currentSessions,
        remainingViolations,
        repairFailures: latestRepairFailures,
        attempts,
      };
    }
  }

  remainingViolations = detectSessionTypePolicyViolations(
    currentSessions,
    profileData,
    totalWeeks,
    coachingBrief,
  );
  return {
    ok: false,
    sessions: currentSessions,
    remainingViolations,
    repairFailures: latestRepairFailures,
    attempts,
  };
}
