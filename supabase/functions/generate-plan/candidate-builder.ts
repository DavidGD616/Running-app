import type { CoachingBrief } from "./coaching-brief.ts";
import { generatePlanFromProfile } from "./openai.ts";
import {
  type GeneratedPlan,
  removeSessionsOnRaceDate,
  StravaCoachingProfileSnapshotSchema,
} from "./schema.ts";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  detectGenericCoachCopyViolations,
  detectSessionTypePolicyViolations,
  dropSessionsBeforePlanStartDate,
  enforcePreRaceTaper,
  ensureFullCalendarWeeks,
  normalizeFirstPlannedSession,
  normalizePeakLongRun,
  normalizeSessionIds,
  normalizeTaper,
  normalizeTrainingDayCount,
  normalizeWeeklyVolumeRamp,
  normalizeWeekNumbersFromDates,
  normalizeWorkoutTypesByPhase,
  phaseForWeekFromCoachingBrief,
  placeLongRunsOnPreferredDay,
  preferRestOnHardDays,
  restoreSessionCoachNotes,
  smoothLongRunProgression,
  snapshotSessionCoachNotesByIds,
  spaceStressfulSessions,
  truncateAfterRaceDate,
  validateGeneratedPlanAgainstCoachingBrief,
  validateGeneratedPlanShape,
  validateGeneratedSchedule,
} from "./plan-rules.ts";
import {
  type RepairPolicyViolationsResult,
  repairPolicyViolationsWithOpenAiPatches,
} from "./repair-loop.ts";
import { buildWorkoutSteps } from "./workout-steps.ts";

export type CoachLocale = "en" | "es";
export type CandidateProfile = Record<string, unknown> & {
  fitness?: Record<string, unknown>;
};
type ProfileShape = CandidateProfile;

export type CandidatePlan = Omit<GeneratedPlan, "sessions"> & {
  id?: string;
  generatedLocale: CoachLocale;
  sessions: Array<Record<string, unknown>>;
};

export type BuildCandidatePlanInput = {
  generationProfileWithPlanStartDate: CandidateProfile;
  sanitizedGenerationProfile: CandidateProfile;
  generationStartedAt: Date;
  resolvedPlanStartDate: string;
  locale: CoachLocale;
  coachingBrief: CoachingBrief;
  expectedWeeks: number | null;
  stravaSnapshotSource: unknown;
};

export async function buildCandidatePlan({
  generationProfileWithPlanStartDate,
  sanitizedGenerationProfile,
  generationStartedAt,
  resolvedPlanStartDate,
  locale,
  coachingBrief,
  expectedWeeks,
  stravaSnapshotSource,
}: BuildCandidatePlanInput): Promise<Response | CandidatePlan> {
  let generatedPlan;
  try {
    generatedPlan = await generatePlanFromProfile(
      sanitizedGenerationProfile,
      locale,
      expectedWeeks,
      coachingBrief,
    );
  } catch (err) {
    console.error("OpenAI generation failed:", err);
    return new Response(
      JSON.stringify({ error: "Plan generation failed", detail: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const briefViolations = validateGeneratedPlanAgainstCoachingBrief(
    generatedPlan,
    coachingBrief,
  );
  if (briefViolations.length > 0) {
    console.error(
      "Generated plan failed coaching brief validation:",
      briefViolations,
    );
    return new Response(
      JSON.stringify({
        error: "Generated plan failed coaching brief validation",
        violations: briefViolations,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const plannedWeeksCandidate = expectedWeeks ?? generatedPlan.totalWeeks;
  const supportedSnapshot = pickStravaSnapshot(stravaSnapshotSource);
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

  const dateNormalizedSessions = normalizeWeekNumbersFromDates(
    generatedPlan.sessions,
    generationProfileWithPlanStartDate,
    generationStartedAt,
    resolvedPlanStartDate,
  );
  const planStartFilteredGeneratedSessions = dropSessionsBeforePlanStartDate(
    dateNormalizedSessions,
    resolvedPlanStartDate,
  );
  const normalizedMaxWeek = planStartFilteredGeneratedSessions.reduce(
    (maximum, session) => Math.max(maximum, session.weekNumber),
    0,
  );

  const plannedWeeks = expectedWeeks == null
    ? Math.max(plannedWeeksCandidate, normalizedMaxWeek)
    : expectedWeeks;
  const safeGeneratedPlan = {
    ...generatedPlan,
    totalWeeks: plannedWeeks,
    sessions: planStartFilteredGeneratedSessions,
    currentWeekNumber: generatedPlan.currentWeekNumber ?? 1,
    generatedLocale: locale,
    coachingBriefSnapshot: coachingBrief,
    planRationale: coachingBrief.rationale,
    evidenceTarget: coachingBrief.evidenceTarget,
    ambitiousTarget: coachingBrief.ambitiousTarget,
    confidence: coachingBrief.confidence,
    phaseStrategy: coachingBrief.phaseStrategy,
    stravaCoachingProfileSnapshot: parsedSnapshot ??
      generatedPlan.stravaCoachingProfileSnapshot,
  };

  const scheduleNormalizedSessions = normalizeTrainingDayCount(
    safeGeneratedPlan.sessions,
    generationProfileWithPlanStartDate,
    locale,
    resolvedPlanStartDate,
  );
  const longRunPlacedSessions = placeLongRunsOnPreferredDay(
    scheduleNormalizedSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const stressSpacedSessions = spaceStressfulSessions(
    longRunPlacedSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const fullCalendarSessions = ensureFullCalendarWeeks(
    stressSpacedSessions,
    locale,
    resolvedPlanStartDate,
  );
  const fullCalendarLongRunPlacedSessions = placeLongRunsOnPreferredDay(
    fullCalendarSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const hardDayRestedSessions = preferRestOnHardDays(
    fullCalendarLongRunPlacedSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const scheduleAdjustedSessions = avoidHardDayTraining(
    hardDayRestedSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const volumeRampedSessions = normalizeWeeklyVolumeRamp(
    scheduleAdjustedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
  );
  const peakNormalizedSessions = normalizePeakLongRun(
    volumeRampedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
  );
  const progressionSmoothedSessions = smoothLongRunProgression(
    peakNormalizedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
  );
  const volumeStabilizedSessions = normalizeWeeklyVolumeRamp(
    progressionSmoothedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
  );
  const taperNormalizedSessions = normalizeTaper(
    volumeStabilizedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
  );
  const policyViolations = detectSessionTypePolicyViolations(
    taperNormalizedSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    coachingBrief,
  );
  let policyRepairResult: RepairPolicyViolationsResult = {
    ok: true,
    sessions: taperNormalizedSessions,
    acceptedSessionIds: [],
    attempts: 0,
  };

  if (policyViolations.length > 0) {
    try {
      policyRepairResult = await repairPolicyViolationsWithOpenAiPatches(
        taperNormalizedSessions,
        generationProfileWithPlanStartDate,
        safeGeneratedPlan.totalWeeks,
        locale,
        coachingBrief,
      );
    } catch (error) {
      console.error("Generated plan failed OpenAI repair validation", {
        attempts: 0,
        requestedRepairs: policyViolations.length,
        error: String(error),
      });
      return new Response(
        JSON.stringify({
          error: "Generated plan failed OpenAI repair validation",
          detail: String(error),
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }
  }

  if (!policyRepairResult.ok) {
    console.error("Generated plan failed OpenAI repair validation", {
      attempts: policyRepairResult.attempts,
      remainingViolations: policyRepairResult.remainingViolations.length,
      repairFailures: policyRepairResult.repairFailures.length,
      requestedRepairs: policyViolations.length,
    });
    return new Response(
      JSON.stringify({
        error: "Generated plan failed OpenAI repair validation",
        remainingViolations: policyRepairResult.remainingViolations,
        repairFailures: policyRepairResult.repairFailures,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const preservedRepairCoachNotes = snapshotSessionCoachNotesByIds(
    policyRepairResult.sessions,
    policyRepairResult.acceptedSessionIds,
  );
  const policyRepairedPlanStartFilteredSessions =
    dropSessionsBeforePlanStartDate(
      policyRepairResult.sessions,
      resolvedPlanStartDate,
    );

  if (policyViolations.length > 0) {
    console.info("OpenAI repair loop completed", {
      attempts: policyRepairResult.attempts,
      repairedSessions: policyRepairResult.acceptedSessionIds.length,
      requestedRepairs: policyViolations.length,
    });
  }

  const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
    policyRepairedPlanStartFilteredSessions,
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
    coachingBrief,
    policyRepairResult.acceptedSessionIds,
  );
  const firstSessionNormalizedSessions = normalizeFirstPlannedSession(
    phaseNormalizedSessions,
    generationProfileWithPlanStartDate,
    locale,
  );
  const firstSessionNormalizedWithPreservedCoachNotes =
    restoreSessionCoachNotes(
      firstSessionNormalizedSessions,
      preservedRepairCoachNotes,
    );
  const phaseStampedSessions = firstSessionNormalizedWithPreservedCoachNotes
    .map((
      session,
    ) => ({
      ...session,
      phase: phaseForWeekFromCoachingBrief(
        session.weekNumber,
        safeGeneratedPlan.totalWeeks,
        generationProfileWithPlanStartDate,
        coachingBrief,
      ),
    }));
  const phaseStampedSessionsWithPreservedCoachNotes = restoreSessionCoachNotes(
    phaseStampedSessions,
    preservedRepairCoachNotes,
  );
  const truncatedSessions = truncateAfterRaceDate(
    phaseStampedSessionsWithPreservedCoachNotes,
    generationProfileWithPlanStartDate,
  );
  const goal = isRecord(generationProfileWithPlanStartDate.goal)
    ? generationProfileWithPlanStartDate.goal
    : {};
  const raceDate = typeof goal.raceDate === "string"
    ? goal.raceDate
    : undefined;
  const sessionsWithoutRaceDate = removeSessionsOnRaceDate(
    truncatedSessions,
    raceDate,
  );
  const preRaceTaperedSessions = enforcePreRaceTaper(
    sessionsWithoutRaceDate,
    generationProfileWithPlanStartDate,
    locale,
  );
  const preRaceTaperedWithPreservedCoachNotes = restoreSessionCoachNotes(
    preRaceTaperedSessions,
    preservedRepairCoachNotes,
  );
  const raceDayDate = raceDate ?? lastSessionDate(
    preRaceTaperedWithPreservedCoachNotes,
  );
  const sessionsBeforeRaceDayInfo = raceDayDate == null
    ? preRaceTaperedWithPreservedCoachNotes
    : removeSessionsOnRaceDate(
      preRaceTaperedWithPreservedCoachNotes,
      raceDayDate,
    );
  const planStartFilteredSessions = dropSessionsBeforePlanStartDate(
    sessionsBeforeRaceDayInfo,
    resolvedPlanStartDate,
  );
  const idNormalizedSessions = normalizeSessionIds(planStartFilteredSessions);
  const genericCoachCopyViolations = detectGenericCoachCopyViolations(
    idNormalizedSessions,
  );
  if (genericCoachCopyViolations.length > 0) {
    console.error("Generated plan failed generic coach note validation", {
      attempts: policyRepairResult.attempts,
      genericCoachCopyViolationCount: genericCoachCopyViolations.length,
      sessionIds: genericCoachCopyViolations.map((violation) =>
        violation.sessionId
      ),
      repairViolations: policyViolations.length,
    });
    return new Response(
      JSON.stringify({
        error: "Generated plan failed generic coach note validation",
        violations: genericCoachCopyViolations,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const sanitizedForValidation = withoutGoalDate(
    generationProfileWithPlanStartDate,
  );
  const finalViolations = [
    ...validateGeneratedPlanShape(
      idNormalizedSessions,
      safeGeneratedPlan.totalWeeks,
      sanitizedForValidation,
      generationStartedAt,
      resolvedPlanStartDate,
    ),
    ...validateGeneratedSchedule(idNormalizedSessions, sanitizedForValidation),
    ...validateGeneratedPlanAgainstCoachingBrief(
      {
        totalWeeks: safeGeneratedPlan.totalWeeks,
        raceGuidance: safeGeneratedPlan.raceGuidance,
        sessions: idNormalizedSessions,
      },
      coachingBrief,
    ),
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
    generationProfileWithPlanStartDate,
    safeGeneratedPlan.totalWeeks,
    locale,
  ).map((session) => ({
    ...session,
    description: session.coachNote,
    status: "upcoming",
    workoutSteps: buildWorkoutSteps(session, safeGeneratedPlan.paceZones),
  }));
  const sessionsWithRaceDayInfo = raceDayDate == null ? sessionsWithSteps : [
    ...sessionsWithSteps,
    buildRaceDayInfoSession(
      raceDayDate,
      safeGeneratedPlan.totalWeeks,
      locale,
    ),
  ];

  return {
    ...safeGeneratedPlan,
    sessions: sessionsWithRaceDayInfo,
  } as CandidatePlan;
}

function lastSessionDate(sessions: { date: string }[]): string | null {
  const sorted = sessions
    .map((session) => session.date?.slice(0, 10))
    .filter((date): date is string =>
      typeof date === "string" && date.length > 0
    )
    .sort();
  return sorted.length === 0 ? null : sorted[sorted.length - 1];
}

function buildRaceDayInfoSession(
  date: string,
  totalWeeks: number,
  locale: CoachLocale,
) {
  return {
    id: "race-day-info",
    date: date.slice(0, 10),
    weekNumber: Math.max(1, totalWeeks),
    type: "raceDay",
    phase: "taperRace",
    distanceKm: null,
    durationMinutes: null,
    coachNote: locale === "es"
      ? "Revisa tu estrategia de carrera. Esta es una guía, no una sesión para iniciar."
      : "Review your race strategy. This is guidance, not a workout to start.",
    targetZone: null,
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
    workoutTarget: null,
    description: locale === "es"
      ? "Estrategia de carrera y recordatorios finales."
      : "Race strategy and final reminders.",
    status: "upcoming",
    workoutSteps: [],
  };
}

function isRecord(value: unknown): value is CandidateProfile {
  return value != null && typeof value === "object" && !Array.isArray(value);
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
