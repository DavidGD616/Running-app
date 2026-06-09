import type { GeneratedPlan, GeneratedSession } from "./schema.ts";
import type {
  CoachingBrief,
  CoachingRaceType,
  ReadinessLevel,
} from "./coaching-brief.ts";

type RacePrepPhase = "base" | "build" | "specific" | "peak" | "taperRace";
type PlanRaceKey =
  | "race_5k"
  | "race_10k"
  | "race_half_marathon"
  | "race_marathon";
type ExperienceKey =
  | "experience_brand_new"
  | "experience_beginner"
  | "experience_intermediate"
  | "experience_experienced";
type RuleContext = {
  race: PlanRaceKey | string;
  experience: ExperienceKey | string;
};

type PeakLongRunRange = {
  minKm: number;
  targetKm: number;
  maxKm: number;
};

export function peakLongRunRangeKm(
  profileData: Record<string, unknown>,
): PeakLongRunRange {
  return peakLongRunRangeFor(ruleContextFor(profileData));
}

function peakLongRunRangeFor(context: RuleContext): PeakLongRunRange {
  switch (context.race) {
    case "race_5k":
      switch (context.experience) {
        case "experience_brand_new":
        case "experience_beginner":
          return { minKm: 3, targetKm: 5, maxKm: 7 };
        case "experience_intermediate":
          return { minKm: 6, targetKm: 8, maxKm: 10 };
        case "experience_experienced":
          return { minKm: 8, targetKm: 10, maxKm: 12 };
      }
      break;
    case "race_10k":
      switch (context.experience) {
        case "experience_brand_new":
        case "experience_beginner":
          return { minKm: 6, targetKm: 8, maxKm: 10 };
        case "experience_intermediate":
          return { minKm: 10, targetKm: 12, maxKm: 13 };
        case "experience_experienced":
          return { minKm: 11, targetKm: 13, maxKm: 16 };
      }
      break;
    case "race_half_marathon":
      switch (context.experience) {
        case "experience_brand_new":
        case "experience_beginner":
          return { minKm: 11, targetKm: 13, maxKm: 16 };
        case "experience_intermediate":
          return { minKm: 14, targetKm: 16, maxKm: 18 };
        case "experience_experienced":
          return { minKm: 16, targetKm: 18, maxKm: 21 };
      }
      break;
    case "race_marathon":
      switch (context.experience) {
        case "experience_brand_new":
        case "experience_beginner":
          return { minKm: 24, targetKm: 26, maxKm: 30 };
        case "experience_intermediate":
          return { minKm: 28, targetKm: 30, maxKm: 32 };
        case "experience_experienced":
          return { minKm: 30, targetKm: 32, maxKm: 34 };
      }
      break;
  }

  return { minKm: 5, targetKm: 10, maxKm: 15 };
}

function ruleContextFor(
  profileData: Record<string, unknown>,
  coachingBrief: CoachingBrief | null | undefined = null,
): RuleContext {
  return {
    race: raceKeyFromCoachingBrief(coachingBrief) ??
      raceFromProfile(profileData),
    experience: experienceKeyFromCoachingBrief(coachingBrief) ??
      experienceFromProfile(profileData),
  };
}

function raceKeyFromCoachingBrief(
  coachingBrief: CoachingBrief | null | undefined,
): PlanRaceKey | null {
  if (coachingBrief == null) return null;
  return raceKeyFromCoachingRaceType(coachingBrief.raceType);
}

function raceKeyFromCoachingRaceType(
  raceType: CoachingRaceType,
): PlanRaceKey | null {
  switch (raceType) {
    case "fiveK":
      return "race_5k";
    case "tenK":
      return "race_10k";
    case "halfMarathon":
      return "race_half_marathon";
    case "marathon":
      return "race_marathon";
    case "other":
      return null;
  }
}

function experienceKeyFromCoachingBrief(
  coachingBrief: CoachingBrief | null | undefined,
): ExperienceKey | null {
  if (coachingBrief == null) return null;
  return experienceKeyFromReadinessLevel(coachingBrief.readinessLevel);
}

function experienceKeyFromReadinessLevel(
  readinessLevel: ReadinessLevel,
): ExperienceKey {
  switch (readinessLevel) {
    case "raceReady":
      return "experience_experienced";
    case "prepared":
      return "experience_intermediate";
    case "developing":
      return "experience_beginner";
    case "underprepared":
    case "unsupported":
      return "experience_brand_new";
  }
}

function raceFromProfile(profileData: Record<string, unknown>): string {
  const goal = objectOrNull(profileData.goal);
  return typeof goal?.race === "string" ? goal.race : "race_5k";
}

function experienceFromProfile(profileData: Record<string, unknown>): string {
  const fitness = objectOrNull(profileData.fitness);
  return typeof fitness?.experience === "string"
    ? fitness.experience
    : "experience_beginner";
}

function athleteSummaryLongestRecentRunKm(
  profileData: Record<string, unknown>,
): number | null {
  const fitness = objectOrNull(profileData.fitness);
  const athleteSummary = objectOrNull(fitness?.athleteSummary);
  if (athleteSummary == null) return null;

  const value = athleteSummary.longestRecentRunKm;
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    return null;
  }

  return value;
}

function athleteSummaryWeeklyVolumeKm(
  profileData: Record<string, unknown>,
): number | null {
  const fitness = objectOrNull(profileData.fitness);
  const athleteSummary = objectOrNull(fitness?.athleteSummary);
  if (athleteSummary == null) return null;

  // When Strava history is too thin, athleteSummary is only a weak signal and
  // must not override self-reported fitness (mirrors the prompt guidance), so
  // skip the volume anchor entirely.
  if (athleteSummary.insufficientData === true) return null;

  const value = athleteSummary.weeklyVolumeKm;
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    return null;
  }

  return value;
}

export function phaseForWeek(
  weekNumber: number,
  totalWeeks: number,
  _profileData: Record<string, unknown>,
): RacePrepPhase {
  if (weekNumber < 1 || !Number.isFinite(weekNumber)) return "base";
  if (!Number.isFinite(totalWeeks) || totalWeeks < 1) return "base";

  const allocation = phaseAllocationFor(totalWeeks);
  const phasesInOrder: RacePrepPhase[] = [
    "base",
    "build",
    "specific",
    "peak",
    "taperRace",
  ];

  let cumulativeWeeks = 0;
  for (let i = 0; i < phasesInOrder.length; i += 1) {
    const phase = phasesInOrder[i];
    const phaseWeeks = allocation[phase] ?? 0;
    if (weekNumber <= cumulativeWeeks + phaseWeeks) {
      return phase;
    }
    cumulativeWeeks += phaseWeeks;
  }

  return "taperRace";
}

export function phaseForWeekFromCoachingBrief(
  weekNumber: number,
  totalWeeks: number,
  profileData: Record<string, unknown>,
  coachingBrief: CoachingBrief | null | undefined,
): RacePrepPhase {
  if (coachingBrief == null) {
    return phaseForWeek(weekNumber, totalWeeks, profileData);
  }
  if (weekNumber < 1 || !Number.isFinite(weekNumber)) {
    return phaseForWeek(weekNumber, totalWeeks, profileData);
  }

  const taperStartWeek = Math.max(
    1,
    coachingBrief.planLengthWeeks - coachingBrief.taper.weeks + 1,
  );
  if (weekNumber >= taperStartWeek) return "taperRace";

  let cumulativeWeeks = 0;
  for (const phase of coachingBrief.phaseStrategy) {
    cumulativeWeeks += phase.weeks;
    if (weekNumber > cumulativeWeeks) continue;

    switch (phase.phase) {
      case "base":
      case "build":
      case "specific":
      case "peak":
      case "taperRace":
        return phase.phase;
      case "safeBuild":
        return "build";
      case "unsupportedFallback":
        return "base";
    }
  }

  return phaseForWeek(weekNumber, totalWeeks, profileData);
}

export function phasePlanFor(
  totalWeeks: number,
  profileData: Record<string, unknown>,
): RacePrepPhase[] {
  return Array.from(
    { length: totalWeeks },
    (_, i) => phaseForWeek(i + 1, totalWeeks, profileData),
  );
}

type PhaseAllocation = Record<RacePrepPhase, number>;

function phaseAllocationFor(totalWeeks: number): PhaseAllocation {
  if (totalWeeks <= 3) {
    return {
      base: 0,
      build: 0,
      specific: Math.max(0, totalWeeks - 1),
      peak: 0,
      taperRace: 1,
    };
  }
  if (totalWeeks <= 5) {
    return {
      base: 0,
      build: 1,
      specific: totalWeeks - 2,
      peak: 0,
      taperRace: 1,
    };
  }
  if (totalWeeks <= 7) {
    return {
      base: 1,
      build: totalWeeks - 5,
      specific: 3,
      peak: 0,
      taperRace: 1,
    };
  }

  switch (totalWeeks) {
    case 8:
      return { base: 2, build: 2, specific: 2, peak: 1, taperRace: 1 };
    case 12:
      return { base: 3, build: 3, specific: 3, peak: 1, taperRace: 2 };
    case 16:
      return { base: 4, build: 4, specific: 4, peak: 2, taperRace: 2 };
    case 20:
      return { base: 5, build: 5, specific: 5, peak: 3, taperRace: 2 };
    default:
      return proportionalPhaseAllocation(totalWeeks);
  }
}

function proportionalPhaseAllocation(totalWeeks: number): PhaseAllocation {
  const baseWeeks = Math.floor(totalWeeks * 0.25);
  const buildWeeks = Math.floor(totalWeeks * 0.25);
  const specificWeeks = Math.floor(totalWeeks * 0.25);
  const peakWeeks = Math.floor(totalWeeks * 0.10);
  const allocatedSoFar = baseWeeks + buildWeeks + specificWeeks + peakWeeks;
  const taperRaceWeeks = Math.max(1, totalWeeks - allocatedSoFar);

  return {
    base: Math.max(1, baseWeeks),
    build: Math.max(1, buildWeeks),
    specific: Math.max(1, specificWeeks),
    peak: Math.max(1, peakWeeks),
    taperRace: taperRaceWeeks,
  };
}

type WorkoutPolicy = {
  allowedTypes: string[];
  maxStressDays: number;
};

export function workoutPolicyForPhase(
  phase: RacePrepPhase,
  raceType: string,
  experience: string,
): WorkoutPolicy {
  switch (phase) {
    case "base":
      return basePhasePolicy(experience);
    case "build":
      return buildPhasePolicy(experience);
    case "specific":
      return specificPhasePolicy(experience, raceType);
    case "peak":
      return peakPhasePolicy(experience);
    case "taperRace":
      return taperRacePhasePolicy(experience);
  }
}

export function normalizeWorkoutTypesByPhase(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  locale: CoachNoteLocale = "en",
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const context = ruleContextFor(profileData, coachingBrief);
  const _raceDate = goalRaceDate(profileData);

  return sessions.map((session) => {
    if (session.type === "restDay") return session;
    if (isGoalRaceSession(session, profileData)) return session;

    const phase = phaseForWeekFromCoachingBrief(
      session.weekNumber,
      totalWeeks,
      profileData,
      coachingBrief,
    );
    const policy = workoutPolicyForPhase(
      phase,
      context.race,
      context.experience,
    );

    if (policy.allowedTypes.includes(session.type)) return session;

    const replacement = nearestAllowedType(session.type, policy.allowedTypes);
    return withDowngradedType(session, replacement, locale);
  });
}

export type SessionTypePolicyViolation = {
  code: "session_type_not_allowed_for_phase";
  sessionId: string;
  weekNumber: number;
  date: string;
  currentType: GeneratedSession["type"];
  phase: "base" | "build" | "specific" | "peak" | "taperRace";
  allowedTypes: string[];
  recommendedType: GeneratedSession["type"];
  reason: string;
};

export function detectSessionTypePolicyViolations(
  sessions: readonly GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  coachingBrief: CoachingBrief | null = null,
): SessionTypePolicyViolation[] {
  const context = ruleContextFor(profileData, coachingBrief);

  return sessions.flatMap((session) => {
    if (session.type === "restDay") return [];
    if (isGoalRaceSession(session, profileData)) return [];

    const phase = phaseForWeekFromCoachingBrief(
      session.weekNumber,
      totalWeeks,
      profileData,
      coachingBrief,
    );
    const policy = workoutPolicyForPhase(
      phase,
      context.race,
      context.experience,
    );

    if (policy.allowedTypes.includes(session.type)) return [];

    const recommendedType = nearestAllowedType(
      session.type,
      policy.allowedTypes,
    );

    return [{
      code: "session_type_not_allowed_for_phase",
      sessionId: session.id,
      weekNumber: session.weekNumber,
      date: session.date,
      currentType: session.type,
      phase,
      allowedTypes: [...policy.allowedTypes],
      recommendedType: recommendedType as GeneratedSession["type"],
      reason:
        `${session.type} is not allowed in ${phase}; suggest ${recommendedType}.`,
    }];
  });
}

function nearestAllowedType(
  currentType: string,
  allowedTypes: string[],
): string {
  const downgradeMap: Record<string, string[]> = {
    thresholdRun: ["tempoRun", "fartlek", "progressionRun", "easyRun"],
    intervals: ["fartlek", "progressionRun", "easyRun"],
    hillRepeats: ["fartlek", "progressionRun", "easyRun"],
    tempoRun: ["fartlek", "progressionRun", "easyRun"],
    racePaceRun: ["fartlek", "progressionRun", "easyRun"],
    progressionRun: ["fartlek", "easyRun"],
    fartlek: ["easyRun"],
  };

  const candidates = downgradeMap[currentType] ?? [];
  for (const candidate of candidates) {
    if (allowedTypes.includes(candidate)) return candidate;
  }

  return "easyRun";
}

function withDowngradedType(
  session: GeneratedSession,
  newType: string,
  locale: CoachNoteLocale,
): GeneratedSession {
  const isLongRun = session.type === "longRun";
  return {
    ...session,
    type: newType as GeneratedSession["type"],
    distanceKm: newType === "easyRun" || newType === "recoveryRun"
      ? null
      : session.distanceKm,
    durationMinutes: newType === "easyRun" || newType === "recoveryRun"
      ? (isLongRun
        ? Math.max(35, session.durationMinutes ?? 45)
        : Math.min(35, Math.max(25, session.durationMinutes ?? 30)))
      : session.durationMinutes,
    coachNote: trainingDayCue("adjustedForPhase", locale),
    targetZone: newType === "easyRun"
      ? "easy"
      : newType === "recoveryRun"
      ? "recovery"
      : session.targetZone,
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
  };
}

function basePhasePolicy(experience: string): WorkoutPolicy {
  const base: WorkoutPolicy = {
    allowedTypes: ["easyRun", "recoveryRun", "longRun", "restDay"],
    maxStressDays: 2,
  };

  if (
    experience === "experience_intermediate" ||
    experience === "experience_experienced"
  ) {
    base.allowedTypes.push("fartlek", "progressionRun");
    base.maxStressDays = 2;
  }

  return base;
}

function buildPhasePolicy(experience: string): WorkoutPolicy {
  if (
    experience === "experience_brand_new" ||
    experience === "experience_beginner"
  ) {
    return {
      allowedTypes: ["easyRun", "recoveryRun", "longRun", "restDay", "fartlek"],
      maxStressDays: 2,
    };
  }

  if (experience === "experience_intermediate") {
    return {
      allowedTypes: [
        "easyRun",
        "recoveryRun",
        "longRun",
        "restDay",
        "tempoRun",
        "hillRepeats",
        "fartlek",
        "progressionRun",
      ],
      maxStressDays: 3,
    };
  }

  return {
    allowedTypes: [
      "easyRun",
      "recoveryRun",
      "longRun",
      "restDay",
      "tempoRun",
      "hillRepeats",
      "fartlek",
      "progressionRun",
      "intervals",
      "racePaceRun",
    ],
    maxStressDays: 3,
  };
}

function specificPhasePolicy(
  experience: string,
  _raceType: string,
): WorkoutPolicy {
  const allowed: string[] = [
    "easyRun",
    "recoveryRun",
    "longRun",
    "restDay",
    "tempoRun",
    "fartlek",
    "progressionRun",
  ];

  if (
    experience === "experience_intermediate" ||
    experience === "experience_experienced"
  ) {
    allowed.push("intervals", "hillRepeats", "racePaceRun");
  }

  if (experience === "experience_experienced") {
    allowed.push("thresholdRun");
  }

  return {
    allowedTypes: allowed,
    maxStressDays: experience === "experience_experienced" ? 3 : 3,
  };
}

function peakPhasePolicy(experience: string): WorkoutPolicy {
  if (experience === "experience_brand_new") {
    return {
      allowedTypes: [
        "easyRun",
        "recoveryRun",
        "longRun",
        "restDay",
        "fartlek",
        "progressionRun",
      ],
      maxStressDays: 2,
    };
  }

  const allowed: string[] = [
    "easyRun",
    "recoveryRun",
    "longRun",
    "restDay",
    "tempoRun",
    "fartlek",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "racePaceRun",
  ];

  if (experience === "experience_experienced") {
    allowed.push("thresholdRun");
  }

  return {
    allowedTypes: allowed,
    maxStressDays: 3,
  };
}

function taperRacePhasePolicy(experience: string): WorkoutPolicy {
  const allowed: string[] = [
    "easyRun",
    "recoveryRun",
    "restDay",
    "fartlek",
  ];

  if (
    experience === "experience_intermediate" ||
    experience === "experience_experienced"
  ) {
    allowed.push("longRun");
    allowed.push("racePaceRun");
  }

  if (experience === "experience_experienced") {
    allowed.push("progressionRun");
  }

  return {
    allowedTypes: allowed,
    maxStressDays: 1,
  };
}

type CoachNoteLocale = "en" | "es";

const STRAVA_RUNS_PER_WEEK_METRIC = "training_base_runs_per_week";
const STRAVA_WEEKLY_VOLUME_METRIC = "training_base_weekly_km";
const STRAVA_LONG_RUN_METRIC = "endurance_long_run_km";
const STRAVA_WEEKLY_VOLUME_UNIT = "km_per_week";
const STRAVA_RUNS_PER_WEEK_UNIT = "runs_per_week";
const STRAVA_LONG_RUN_UNIT = "km";
const STRAVA_EVIDENCE_GROUPS = ["trainingBase", "endurance"] as const;

const GUARDRAIL_BLOCKING_VOLUME_RAMP = new Set([
  "recovery_detraining",
  "recovery_long_layoff",
  "recovery_sparse_data",
  "recovery_data_collection",
]);
const GUARDRAIL_BLOCKING_PEAK_LONG_RUN = new Set([
  ...GUARDRAIL_BLOCKING_VOLUME_RAMP,
  "recovery_load_spike",
  "recovery_pace_uncertainty",
]);
const WEEKLY_VOLUME_RAMP_HIGH_RISK_FACTOR = 1.0;
const WEEKLY_VOLUME_RAMP_DEFAULT_FACTOR = 1.1;
const LEG_STRENGTH_CATEGORIES = new Set([
  "lower_body",
  "full_body",
]);

type StravaEvidence = {
  metric: string;
  value: number;
  unit: string;
  date?: string;
};

type StrengthPreferences = {
  weeklyFrequency: number;
  categories: string[];
  preferredDays: string[];
};

function stravaCoachingProfile(profileData: Record<string, unknown>):
  | Record<
    string,
    unknown
  >
  | null {
  const fitness = objectOrNull(profileData.fitness);
  const direct = objectOrNull(profileData.stravaCoachingProfile);
  const nested = objectOrNull(fitness?.stravaCoachingProfile);
  return direct ?? nested ?? null;
}

function dataConfidence(profileData: Record<string, unknown>): string | null {
  const profile = stravaCoachingProfile(profileData);
  if (profile == null) return null;
  const confidence = profile.dataConfidence;
  return typeof confidence === "string" ? confidence : null;
}

function hasHighConfidence(profileData: Record<string, unknown>): boolean {
  const confidence = dataConfidence(profileData);
  return confidence === "high" || confidence === "medium";
}

function recoveryGuardrails(profileData: Record<string, unknown>): string[] {
  const profile = stravaCoachingProfile(profileData);
  const list = profile?.recoveryGuardrails;
  if (!Array.isArray(list)) return [];
  return list.map((entry) => {
    if (!entry || typeof entry !== "object") return "";
    const record = entry as Record<string, unknown>;
    return typeof record.category === "string" ? record.category : "";
  }).filter((category): category is string => category.length > 0);
}

function evidenceCategoryBlocked(
  category: string,
  blocked: Set<string>,
): boolean {
  const normalized = category.toLowerCase();
  if (blocked.has(normalized)) return true;
  for (const block of blocked) {
    if (
      normalized === block ||
      normalized.includes(block.replace("recovery_", "")) ||
      normalized.includes(block.replace(/_/g, " "))
    ) {
      return true;
    }
  }
  return false;
}

function hasBlockingGuardrail(
  profileData: Record<string, unknown>,
  bucket: Set<string>,
): boolean {
  return recoveryGuardrails(profileData).some((category) =>
    evidenceCategoryBlocked(category, bucket)
  );
}

function evidencePoints(
  profileData: Record<string, unknown>,
): StravaEvidence[] {
  const profile = stravaCoachingProfile(profileData);
  if (profile == null) return [];

  return STRAVA_EVIDENCE_GROUPS
    .flatMap((key) => {
      const raw = profile[key];
      if (!Array.isArray(raw)) return [];

      return raw
        .flatMap((item) => {
          if (item == null || typeof item !== "object") return [];
          const record = item as Record<string, unknown>;
          const metric = typeof record.metric === "string"
            ? record.metric
            : null;
          const unit = typeof record.unit === "string" ? record.unit : null;
          const value =
            typeof record.value === "number" && Number.isFinite(record.value)
              ? record.value
              : null;
          if (metric == null || unit == null || value == null) return [];

          const base = {
            metric,
            unit,
            value,
          };
          const dated = typeof record.date === "string"
            ? { ...base, date: record.date }
            : base;
          return [dated as StravaEvidence];
        });
    });
}

function evidenceDateSort(a: StravaEvidence, b: StravaEvidence): number {
  const aDate = a.date == null ? 0 : Date.parse(a.date);
  const bDate = b.date == null ? 0 : Date.parse(b.date);
  return (Number.isFinite(bDate) ? bDate : 0) -
    (Number.isFinite(aDate) ? aDate : 0);
}

function latestEvidenceValue(
  profileData: Record<string, unknown>,
  metric: string,
  unit: string,
): number | null {
  const points = evidencePoints(profileData)
    .filter((point) => point.metric === metric && point.unit === unit)
    .sort(evidenceDateSort);
  return points.length > 0 ? points[0].value : null;
}

function stravaRunsPerWeek(
  profileData: Record<string, unknown>,
): number | null {
  return latestEvidenceValue(
    profileData,
    STRAVA_RUNS_PER_WEEK_METRIC,
    STRAVA_RUNS_PER_WEEK_UNIT,
  );
}

function stravaWeeklyVolume(
  profileData: Record<string, unknown>,
): number | null {
  return latestEvidenceValue(
    profileData,
    STRAVA_WEEKLY_VOLUME_METRIC,
    STRAVA_WEEKLY_VOLUME_UNIT,
  );
}

function stravaLongRun(profileData: Record<string, unknown>): number | null {
  return latestEvidenceValue(
    profileData,
    STRAVA_LONG_RUN_METRIC,
    STRAVA_LONG_RUN_UNIT,
  );
}

function acceptedRaceTargetDistance(
  profileData: Record<string, unknown>,
): number | null {
  const target = objectOrNull(profileData.acceptedRaceTarget);
  const distance = target?.distanceKm;
  return typeof distance === "number" && Number.isFinite(distance) &&
      distance > 0
    ? distance
    : null;
}

function baselineWeeklyVolumeProfile(
  profileData: Record<string, unknown>,
): {
  anchor: number;
  rampFactor: number;
  maxWeeklyVolumeKm: null;
  weekOneMinimumRatio: number;
  longRunCeilingKm: null;
} | null {
  if (
    hasStrongEvidenceConfidence(profileData) &&
    !hasBlockingGuardrail(profileData, GUARDRAIL_BLOCKING_VOLUME_RAMP)
  ) {
    const byStrava = stravaWeeklyVolume(profileData);
    if (byStrava != null) {
      return {
        anchor: byStrava,
        rampFactor: weeklyVolumeRampFactor(profileData),
        maxWeeklyVolumeKm: null,
        weekOneMinimumRatio: 0,
        longRunCeilingKm: null,
      };
    }
  }

  const athleteSummary = athleteSummaryWeeklyVolumeKm(profileData);
  if (athleteSummary == null) return null;

  return {
    anchor: athleteSummary,
    rampFactor: WEEKLY_VOLUME_RAMP_FACTOR,
    maxWeeklyVolumeKm: null,
    weekOneMinimumRatio: 0,
    longRunCeilingKm: null,
  };
}

function hasStrongEvidenceConfidence(
  profileData: Record<string, unknown>,
): boolean {
  const confidence = dataConfidence(profileData);
  return confidence === "high" || confidence === "medium";
}

function weeklyVolumeRampFactor(profileData: Record<string, unknown>): number {
  if (
    hasStrongEvidenceConfidence(profileData) &&
    !hasBlockingGuardrail(profileData, GUARDRAIL_BLOCKING_VOLUME_RAMP)
  ) {
    return WEEKLY_VOLUME_RAMP_DEFAULT_FACTOR;
  }
  return WEEKLY_VOLUME_RAMP_FACTOR;
}

function longRunHistoryFloor(
  profileData: Record<string, unknown>,
): number | null {
  if (hasBlockingGuardrail(profileData, GUARDRAIL_BLOCKING_PEAK_LONG_RUN)) {
    return null;
  }

  const acceptedConfidence = dataConfidence(profileData);
  if (
    acceptedConfidence != null &&
    acceptedConfidence !== "high" &&
    acceptedConfidence !== "medium"
  ) {
    return null;
  }

  const stravaEvidence = stravaLongRun(profileData);
  if (stravaEvidence != null) return stravaEvidence * 0.9;

  return athleteSummaryLongestRecentRunKm(profileData);
}

function strengthPreferences(
  profileData: Record<string, unknown>,
): StrengthPreferences {
  const fallback: StrengthPreferences = {
    weeklyFrequency: 0,
    categories: [],
    preferredDays: [],
  };
  const profile = objectOrNull(profileData.strengthPreferences);
  if (profile == null) return fallback;

  const rawFrequency = typeof profile.weeklyFrequency === "number"
    ? Math.floor(profile.weeklyFrequency)
    : typeof profile.weeklyFrequency === "string"
    ? Number.parseInt(profile.weeklyFrequency, 10)
    : null;
  const weeklyFrequency = rawFrequency == null || Number.isNaN(rawFrequency)
    ? 0
    : Math.max(0, rawFrequency);

  const rawCategories = Array.isArray(profile.categories)
    ? profile.categories
    : [];
  const categories = rawCategories
    .filter((category): category is string =>
      typeof category === "string" &&
      category.length > 0
    );

  const rawPreferredDays = Array.isArray(profile.preferredDays)
    ? profile.preferredDays
    : [];
  const preferredDays = rawPreferredDays.filter((day): day is string =>
    typeof day === "string" && day.startsWith("day_")
  );

  return {
    weeklyFrequency,
    categories: Array.from(new Set(categories)),
    preferredDays,
  };
}

function hasLegStrengthPreference(prefs: StrengthPreferences): boolean {
  return prefs.weeklyFrequency > 0 &&
    prefs.categories.some((category) => LEG_STRENGTH_CATEGORIES.has(category));
}

export function normalizeTrainingDayCount(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
  planStartDate?: string | null,
): GeneratedSession[] {
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  if (targetTrainingDays == null) return sessions;

  const hardDays = hardDaySetFor(profileData);
  const minimumDate = planStartDate != null
    ? parsePlanStartDateValue(planStartDate)
    : parsePlanStartDateValue(
      objectOrNull(profileData.schedule)?.planStartDate,
    );
  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      normalizeWeekTrainingDays(
        sessionsByWeek.get(weekNumber) ?? [],
        targetTrainingDays,
        hardDays,
        profileData,
        locale,
        minimumDate,
      )
    )
    .sort(compareSessionsByDate);
}

export function normalizeWeekNumbersFromDates(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  today: Date = new Date(),
  planStartDate?: string | null,
): GeneratedSession[] {
  const resolvedPlanStartDate = resolvePlanStartDate(
    profileData,
    today,
    planStartDate,
  );
  const anchorMonday = planStartAnchorMonday(resolvedPlanStartDate);
  if (anchorMonday == null) {
    return sessions.map((session) => ({ ...session }))
      .sort(compareSessionsByDate);
  }

  return sessions
    .map((session) => {
      const expectedWeekNumber = weekNumberFromAnchor(
        session.date,
        anchorMonday,
      );
      if (expectedWeekNumber == null || expectedWeekNumber < 1) {
        return { ...session };
      }

      return {
        ...session,
        weekNumber: expectedWeekNumber,
      };
    })
    .sort(compareSessionsByDate);
}

export function ensureFullCalendarWeeks(
  sessions: GeneratedSession[],
  locale: CoachNoteLocale = "en",
  planStartDate?: string | null,
): GeneratedSession[] {
  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }
  const resolvedPlanStartDate = parsePlanStartDateValue(planStartDate);

  const hasLaterWeek = [...sessionsByWeek.keys()].some((weekNumber) =>
    weekNumber > 1
  );
  if (
    resolvedPlanStartDate != null &&
    hasLaterWeek &&
    !sessionsByWeek.has(1)
  ) {
    const syntheticWeekOneTemplate: GeneratedSession = {
      id: `w1-${resolvedPlanStartDate}-restDay`,
      date: resolvedPlanStartDate,
      weekNumber: 1,
      type: "restDay",
      distanceKm: null,
      durationMinutes: null,
      coachNote: null,
      targetZone: null,
      warmUpMinutes: null,
      coolDownMinutes: null,
      intervalReps: null,
      intervalRepDistanceMeters: null,
      intervalRecoverySeconds: null,
      strideReps: null,
      strideSeconds: null,
      strideRecoverySeconds: null,
    };

    sessionsByWeek.set(
      1,
      fillWeekRestDays(
        [syntheticWeekOneTemplate],
        locale,
        resolvedPlanStartDate,
      ),
    );
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      fillWeekRestDays(
        sessionsByWeek.get(weekNumber) ?? [],
        locale,
        resolvedPlanStartDate,
      )
    )
    .sort(compareSessionsByDate);
}

export function expectedTotalWeeks(
  profileData: Record<string, unknown>,
  today: Date = new Date(),
  planStartDate?: string | null,
): number | null {
  const raceDate = goalRaceDate(profileData);
  if (raceDate == null) return null;

  const raceDateParsed = parseDateOnly(raceDate);
  if (raceDateParsed == null) return null;

  const resolvedPlanStartDate = resolvePlanStartDate(
    profileData,
    today,
    planStartDate,
  );
  const anchorMonday = planStartAnchorMonday(resolvedPlanStartDate) ??
    anchorMondayFor(today);

  const raceDayIndex = raceDateParsed.getUTCDay();
  const raceMondayOffset = raceDayIndex === 0 ? -6 : 1 - raceDayIndex;
  const raceMonday = new Date(raceDateParsed);
  raceMonday.setUTCDate(raceDateParsed.getUTCDate() + raceMondayOffset);

  if (raceMonday.getTime() < anchorMonday.getTime()) return 0;

  const weeks = Math.ceil(
    (raceMonday.getTime() - anchorMonday.getTime()) /
      (7 * 24 * 60 * 60 * 1000),
  ) + 1;

  return weeks;
}

function anchorMondayFor(date: Date): Date {
  const dayIndex = date.getUTCDay();
  const mondayOffset = dayIndex === 0 ? -6 : 1 - dayIndex;
  const monday = new Date(date);
  monday.setUTCDate(date.getUTCDate() + mondayOffset);
  monday.setUTCHours(0, 0, 0, 0);
  return monday;
}

function weekNumberFromAnchor(date: string, anchorMonday: Date): number | null {
  const parsed = parseDateOnly(date);
  if (parsed == null) return null;
  return Math.floor(
    (parsed.getTime() - anchorMonday.getTime()) / (7 * 24 * 60 * 60 * 1000),
  ) + 1;
}

export function truncateAfterRaceDate(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): GeneratedSession[] {
  const raceDate = goalRaceDate(profileData);
  if (raceDate == null) return sessions;

  return sessions
    .filter((session) => session.date.slice(0, 10) <= raceDate);
}

export function addStrideDefaults(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const config = strideConfigFor(profileData) ?? beginnerStrideConfig();
  const hardDays = hardDaySetFor(profileData);
  const raceWeeks = raceWeekNumbersFor(sessions, profileData, totalWeeks);
  const protectedFirstTrainingId = firstStrideProtectedSessionId(
    sessions,
    profileData,
  );
  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      enforceWeekStrides(
        sessionsByWeek.get(weekNumber) ?? [],
        config,
        hardDays,
        raceWeeks.has(weekNumber),
        protectedFirstTrainingId,
        locale,
      )
    )
    .sort(compareSessionsByDate);
}

function firstStrideProtectedSessionId(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): string | null {
  const firstTraining = [...sessions].sort(compareSessionsByDate).find((
    session,
  ) => isTrainingDay(session) && !isGoalRaceSession(session, profileData));
  return firstTraining?.id ?? null;
}

function fillWeekRestDays(
  sessions: GeneratedSession[],
  locale: CoachNoteLocale,
  planStartDate?: string | null,
): GeneratedSession[] {
  if (sessions.length === 0) return sessions;

  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );
  const weekStart = weekStartDateFor(adjusted);
  if (weekStart == null) return adjusted;

  const existingDates = new Set(
    adjusted.map((session) => session.date.slice(0, 10)),
  );
  const normalizedPlanStartDate = parsePlanStartDateValue(planStartDate);
  const template = adjusted[0];

  for (let dayOffset = 0; dayOffset < 7; dayOffset += 1) {
    const date = new Date(weekStart);
    date.setUTCDate(weekStart.getUTCDate() + dayOffset);
    const dateKey = date.toISOString().slice(0, 10);
    if (
      normalizedPlanStartDate != null &&
      dateKey < normalizedPlanStartDate
    ) {
      continue;
    }
    if (existingDates.has(dateKey)) continue;

    adjusted.push(createRestDay(template, dateKey, locale));
    existingDates.add(dateKey);
  }

  return adjusted.sort(compareSessionsByDate);
}

export function avoidHardDayTraining(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const hardDays = hardDaySetFor(profileData);
  if (hardDays.size === 0) return sessions;

  const adjusted = sessions.map((session) => ({ ...session }));
  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (!isStressfulSession(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;
    if (!hardDays.has(dayKeyForDate(session.date))) continue;

    const swapIndex = findHardDaySwapIndex(adjusted, i, hardDays);
    if (swapIndex == null) continue;

    const swapSession = adjusted[swapIndex];
    adjusted[i] = withScheduleNote(
      { ...session, date: swapSession.date },
      locale,
    );
    adjusted[swapIndex] = { ...swapSession, date: session.date };
  }

  return adjusted;
}

export function spaceStressfulSessions(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const hardDays = hardDaySetFor(profileData);
  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) => {
      const weekSessions = (sessionsByWeek.get(weekNumber) ?? []).sort(
        compareSessionsByDate,
      );
      const limited = limitWeeklyStressDays(weekSessions, profileData, locale);
      return separateAdjacentStressDays(limited, hardDays, profileData, locale);
    })
    .sort(compareSessionsByDate);
}

export function placeLongRunsOnPreferredDay(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const preferredDay = preferredLongRunDayFor(profileData);
  if (preferredDay == null) return sessions;

  const hardDays = hardDaySetFor(profileData);
  if (hardDays.has(preferredDay)) return sessions;

  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      placeWeekLongRun(
        sessionsByWeek.get(weekNumber) ?? [],
        preferredDay,
        hardDays,
        profileData,
        locale,
      )
    )
    .sort(compareSessionsByDate);
}

function normalizeWeekTrainingDays(
  sessions: GeneratedSession[],
  targetTrainingDays: number,
  hardDays: Set<string>,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
  minimumDate?: string | null,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );

  while (trainingDayCount(adjusted) > targetTrainingDays) {
    const index = findSessionToRest(adjusted, profileData);
    if (index == null) break;
    adjusted[index] = toRestDay(adjusted[index], locale);
  }

  while (trainingDayCount(adjusted) < targetTrainingDays) {
    const restIndex = findRestDayToTrain(adjusted, hardDays);
    if (restIndex != null) {
      adjusted[restIndex] = toEasyTrainingDay(
        adjusted[restIndex],
        hardDays,
        locale,
      );
      continue;
    }

    const date = findMissingWeekDate(adjusted, hardDays, minimumDate);
    if (date == null) break;
    adjusted.push(createEasyTrainingDay(adjusted[0], date, hardDays, locale));
    adjusted.sort(compareSessionsByDate);
  }

  return adjusted;
}

function placeWeekLongRun(
  sessions: GeneratedSession[],
  preferredDay: string,
  hardDays: Set<string>,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );
  const longRunIndex = adjusted.findIndex((session) =>
    session.type === "longRun" && !isGoalRaceSession(session, profileData)
  );
  if (longRunIndex < 0) return adjusted;

  const longRun = adjusted[longRunIndex];
  if (dayKeyForDate(longRun.date) === preferredDay) return adjusted;

  const swapIndex = adjusted.findIndex((session, index) =>
    index !== longRunIndex &&
    dayKeyForDate(session.date) === preferredDay &&
    isLowStressSession(session) &&
    !hardDays.has(dayKeyForDate(session.date)) &&
    !wouldCreateAdjacentStress(adjusted, longRunIndex, session.date)
  );
  if (swapIndex < 0) return adjusted;

  const swapSession = adjusted[swapIndex];
  adjusted[longRunIndex] = {
    ...longRun,
    date: swapSession.date,
    coachNote: appendTrainingDayCue(
      longRun.coachNote,
      trainingDayCue("preferredLongRunDay", locale),
    ),
  };
  adjusted[swapIndex] = { ...swapSession, date: longRun.date };
  return adjusted.sort(compareSessionsByDate);
}

function limitWeeklyStressDays(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session }));
  const maxStressDays = maxStressDaysFor(profileData);

  while (stressDayCount(adjusted) > maxStressDays) {
    const index = findStressSessionToDowngrade(adjusted, profileData);
    if (index == null) break;
    adjusted[index] = toEasyStressFallback(adjusted[index], locale);
  }

  return adjusted;
}

function separateAdjacentStressDays(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );

  let changed = true;
  let passes = 0;
  while (changed && passes < 7) {
    changed = false;
    passes += 1;

    for (let i = 1; i < adjusted.length; i += 1) {
      const previous = adjusted[i - 1];
      const current = adjusted[i];
      if (!isAdjacentStressPair(previous, current)) continue;

      const stressIndex = stressIndexToMove(adjusted, i - 1, i, profileData);
      if (stressIndex == null) continue;

      const swapIndex = findSpacingSwapIndex(adjusted, stressIndex, hardDays);
      if (swapIndex != null) {
        const stressSession = adjusted[stressIndex];
        const swapSession = adjusted[swapIndex];
        adjusted[stressIndex] = {
          ...stressSession,
          date: swapSession.date,
          coachNote: appendTrainingDayCue(
            stressSession.coachNote,
            trainingDayCue("movedForSpacing", locale),
          ),
        };
        adjusted[swapIndex] = { ...swapSession, date: stressSession.date };
        adjusted.sort(compareSessionsByDate);
        changed = true;
        break;
      }

      adjusted[stressIndex] = toEasyStressFallback(
        adjusted[stressIndex],
        locale,
      );
      changed = true;
      break;
    }
  }

  return adjusted;
}

function targetTrainingDaysFor(
  profileData: Record<string, unknown>,
): number | null {
  const schedule = objectOrNull(profileData.schedule);
  const rawTrainingDays = schedule?.trainingDays;
  const trainingDays = typeof rawTrainingDays === "number"
    ? rawTrainingDays
    : typeof rawTrainingDays === "string"
    ? Number.parseInt(rawTrainingDays, 10)
    : null;

  if (trainingDays == null || !Number.isFinite(trainingDays)) return null;
  return Math.min(7, Math.max(1, Math.floor(trainingDays)));
}

function preferredLongRunDayFor(
  profileData: Record<string, unknown>,
): string | null {
  const schedule = objectOrNull(profileData.schedule);
  const longRunDay = schedule?.longRunDay;
  return typeof longRunDay === "string" && longRunDay.startsWith("day_")
    ? longRunDay
    : null;
}

function goalRaceDate(profileData: Record<string, unknown>): string | null {
  const goal = objectOrNull(profileData.goal);
  const raceDate = typeof goal?.raceDate === "string" ? goal.raceDate : null;
  return raceDate == null ? null : raceDate.slice(0, 10);
}

function trainingDayCount(sessions: GeneratedSession[]): number {
  return sessions.filter((session) => isTrainingDay(session)).length;
}

function isTrainingDay(session: GeneratedSession): boolean {
  return session.type !== "restDay";
}

function stressDayCount(sessions: GeneratedSession[]): number {
  return sessions.filter((session) => isStressfulSession(session)).length;
}

function maxStressDaysFor(profileData: Record<string, unknown>): number {
  const fitness = objectOrNull(profileData.fitness);
  const experience = typeof fitness?.experience === "string"
    ? fitness.experience
    : null;

  switch (experience) {
    case "experience_experienced":
      return 3;
    case "experience_intermediate":
      return 3;
    default:
      return 2;
  }
}

function findSessionToRest(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): number | null {
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    const session = sessions[i];
    if (!isTrainingDay(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;

    const score = restConversionScore(session);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function restConversionScore(session: GeneratedSession): number {
  switch (session.type) {
    case "recoveryRun":
      return 1;
    case "easyRun":
      return 2;
    case "fartlek":
    case "progressionRun":
      return 4;
    case "tempoRun":
    case "thresholdRun":
    case "intervals":
    case "hillRepeats":
    case "racePaceRun":
      return 6;
    case "longRun":
      return 10;
    default:
      return 20;
  }
}

function findStressSessionToDowngrade(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): number | null {
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    const session = sessions[i];
    if (!isStressfulSession(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;

    const score = stressDowngradeScore(session);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function stressDowngradeScore(session: GeneratedSession): number {
  switch (session.type) {
    case "fartlek":
    case "progressionRun":
      return 0;
    case "racePaceRun":
      return 1;
    case "tempoRun":
    case "thresholdRun":
      return 2;
    case "intervals":
    case "hillRepeats":
      return 3;
    case "longRun":
      return 10;
    default:
      return 20;
  }
}

function isAdjacentStressPair(
  previous: GeneratedSession,
  current: GeneratedSession,
): boolean {
  if (!isStressfulSession(previous) || !isStressfulSession(current)) {
    return false;
  }

  const previousDate = parseDateOnly(previous.date);
  const currentDate = parseDateOnly(current.date);
  if (previousDate == null || currentDate == null) return false;

  const dayDifference = Math.round(
    (currentDate.getTime() - previousDate.getTime()) / 86_400_000,
  );
  return dayDifference === 1;
}

function stressIndexToMove(
  sessions: GeneratedSession[],
  firstIndex: number,
  secondIndex: number,
  profileData: Record<string, unknown>,
): number | null {
  const first = sessions[firstIndex];
  const second = sessions[secondIndex];

  const firstLocked = isGoalRaceSession(first, profileData);
  const secondLocked = isGoalRaceSession(second, profileData);
  if (firstLocked && secondLocked) return null;
  if (firstLocked) return secondIndex;
  if (secondLocked) return firstIndex;

  return stressMoveScore(first) <= stressMoveScore(second)
    ? firstIndex
    : secondIndex;
}

function stressMoveScore(session: GeneratedSession): number {
  switch (session.type) {
    case "fartlek":
    case "progressionRun":
      return 0;
    case "racePaceRun":
      return 1;
    case "tempoRun":
    case "thresholdRun":
      return 2;
    case "intervals":
    case "hillRepeats":
      return 3;
    case "longRun":
      return 10;
    default:
      return 20;
  }
}

function findSpacingSwapIndex(
  sessions: GeneratedSession[],
  stressIndex: number,
  hardDays: Set<string>,
): number | null {
  const stressSession = sessions[stressIndex];
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    if (i === stressIndex) continue;

    const candidate = sessions[i];
    if (!isLowStressSession(candidate)) continue;
    if (hardDays.has(dayKeyForDate(candidate.date))) continue;
    if (wouldCreateAdjacentStress(sessions, stressIndex, candidate.date)) {
      continue;
    }

    const score = spacingSwapScore(stressSession, candidate);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function wouldCreateAdjacentStress(
  sessions: GeneratedSession[],
  stressIndex: number,
  candidateDate: string,
): boolean {
  const stressSession = sessions[stressIndex];
  const movedSession = { ...stressSession, date: candidateDate };

  return sessions.some((session, index) => {
    if (index === stressIndex) return false;
    if (!isStressfulSession(session)) return false;
    return areDatesAdjacent(movedSession.date, session.date);
  });
}

function areDatesAdjacent(firstDate: string, secondDate: string): boolean {
  return Math.abs(dateDifferenceDays(firstDate, secondDate)) === 1;
}

function dateDifferenceDays(firstDate: string, secondDate: string): number {
  const first = parseDateOnly(firstDate);
  const second = parseDateOnly(secondDate);
  if (first == null || second == null) return Number.NaN;

  return Math.round((second.getTime() - first.getTime()) / 86_400_000);
}

function spacingSwapScore(
  stressSession: GeneratedSession,
  candidate: GeneratedSession,
): number {
  return Math.abs(
    dayOffsetInWeek(stressSession.date) - dayOffsetInWeek(candidate.date),
  ) +
    sessionSwapScore(candidate);
}

function findRestDayToTrain(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
): number | null {
  let hardDayFallback: number | null = null;

  for (let i = 0; i < sessions.length; i += 1) {
    const session = sessions[i];
    if (session.type !== "restDay") continue;
    if (!hardDays.has(dayKeyForDate(session.date))) return i;
    hardDayFallback ??= i;
  }

  return hardDayFallback;
}

function toRestDay(
  session: GeneratedSession,
  locale: CoachNoteLocale,
): GeneratedSession {
  return {
    ...session,
    type: "restDay",
    distanceKm: null,
    durationMinutes: null,
    coachNote: trainingDayCue("restDayAdded", locale),
    targetZone: null,
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function toEasyTrainingDay(
  session: GeneratedSession,
  hardDays: Set<string>,
  locale: CoachNoteLocale,
): GeneratedSession {
  const isHardDay = hardDays.has(dayKeyForDate(session.date));
  return {
    ...session,
    type: isHardDay ? "recoveryRun" : "easyRun",
    distanceKm: null,
    durationMinutes: isHardDay ? 25 : 35,
    coachNote: isHardDay
      ? trainingDayCue("shortRecoveryAdded", locale)
      : trainingDayCue("easyRunAdded", locale),
    targetZone: isHardDay ? "recovery" : "easy",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function toEasyStressFallback(
  session: GeneratedSession,
  locale: CoachNoteLocale,
): GeneratedSession {
  const isLongRun = session.type === "longRun";
  return {
    ...session,
    type: isLongRun ? "easyRun" : "recoveryRun",
    distanceKm: null,
    durationMinutes: isLongRun
      ? Math.max(35, session.durationMinutes ?? 45)
      : Math.min(35, Math.max(25, session.durationMinutes ?? 30)),
    coachNote: trainingDayCue("adjustedForSpacing", locale),
    targetZone: isLongRun ? "easy" : "recovery",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function createEasyTrainingDay(
  template: GeneratedSession,
  date: string,
  hardDays: Set<string>,
  locale: CoachNoteLocale,
): GeneratedSession {
  return toEasyTrainingDay(
    {
      id: `w${template.weekNumber}-${date}-added`,
      date,
      weekNumber: template.weekNumber,
      type: "restDay",
      distanceKm: null,
      durationMinutes: null,
      coachNote: null,
      targetZone: null,
      warmUpMinutes: null,
      coolDownMinutes: null,
      intervalReps: null,
      intervalRepDistanceMeters: null,
      intervalRecoverySeconds: null,
      strideReps: null,
      strideSeconds: null,
      strideRecoverySeconds: null,
    },
    hardDays,
    locale,
  );
}

function createRestDay(
  template: GeneratedSession,
  date: string,
  locale: CoachNoteLocale,
): GeneratedSession {
  return {
    id: `w${template.weekNumber}-${date}-rest`,
    date,
    weekNumber: template.weekNumber,
    type: "restDay",
    distanceKm: null,
    durationMinutes: null,
    coachNote: trainingDayCue("restDay", locale),
    targetZone: null,
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function findMissingWeekDate(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
  minimumDate?: string | null,
): string | null {
  const weekStart = weekStartDateFor(sessions);
  if (weekStart == null) return null;

  const existingDates = new Set(
    sessions.map((session) => session.date.slice(0, 10)),
  );
  const candidates = Array.from({ length: 7 }, (_, dayOffset) => {
    const date = new Date(weekStart);
    date.setUTCDate(weekStart.getUTCDate() + dayOffset);
    return date.toISOString().slice(0, 10);
  })
    .filter((date) => !existingDates.has(date))
    .filter((date) => minimumDate == null || date >= minimumDate);

  return candidates.find((date) => !hardDays.has(dayKeyForDate(date))) ??
    candidates[0] ??
    null;
}

function weekStartDateFor(sessions: GeneratedSession[]): Date | null {
  const firstDate = sessions
    .map((session) => parseDateOnly(session.date))
    .filter((date): date is Date => date != null)
    .sort((a, b) => a.getTime() - b.getTime())[0];
  if (firstDate == null) return null;

  const dayIndex = firstDate.getUTCDay();
  const mondayOffset = dayIndex === 0 ? -6 : 1 - dayIndex;
  const weekStart = new Date(firstDate);
  weekStart.setUTCDate(firstDate.getUTCDate() + mondayOffset);
  return weekStart;
}

function dayOffsetInWeek(date: string): number {
  const parsedDate = parseDateOnly(date);
  if (parsedDate == null) return 0;
  const dayIndex = parsedDate.getUTCDay();
  return dayIndex === 0 ? 6 : dayIndex - 1;
}

type StrideConfig = {
  addDefaults: boolean;
  maxPerWeek: number;
  reps: number;
  seconds: number;
  recoverySeconds: number;
};

function strideConfigFor(
  profileData: Record<string, unknown>,
): StrideConfig | null {
  const fitness = objectOrNull(profileData.fitness);
  const experience = typeof fitness?.experience === "string"
    ? fitness.experience
    : null;

  switch (experience) {
    case "experience_experienced":
      return {
        addDefaults: true,
        maxPerWeek: 2,
        reps: 6,
        seconds: 20,
        recoverySeconds: 80,
      };
    case "experience_intermediate":
      return {
        addDefaults: true,
        maxPerWeek: 2,
        reps: 4,
        seconds: 20,
        recoverySeconds: 90,
      };
    default:
      return beginnerStrideConfig();
  }
}

function beginnerStrideConfig(): StrideConfig {
  return {
    addDefaults: false,
    maxPerWeek: 1,
    reps: 4,
    seconds: 15,
    recoverySeconds: 90,
  };
}

function enforceWeekStrides(
  sessions: GeneratedSession[],
  config: StrideConfig,
  hardDays: Set<string>,
  isRaceWeek: boolean,
  protectedFirstTrainingId: string | null,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => {
    const sanitized = sanitizeStrideValues(session);
    if (
      isRaceWeek ||
      sanitized.id === protectedFirstTrainingId ||
      !isStridePlacementEligible(sanitized, hardDays)
    ) {
      return withoutStrides(sanitized);
    }
    return sanitized;
  }).sort(compareSessionsByDate);

  if (isRaceWeek) return adjusted;

  trimExtraStrideSessions(adjusted, config, hardDays);
  if (config.addDefaults) {
    addMissingStrideSessions(
      adjusted,
      config,
      hardDays,
      protectedFirstTrainingId,
      locale,
    );
  }

  return adjusted;
}

function sanitizeStrideValues(session: GeneratedSession): GeneratedSession {
  if (!hasStrides(session)) return session;

  return {
    ...session,
    strideReps: clampInt(session.strideReps, 4, 8),
    strideSeconds: clampInt(session.strideSeconds, 15, 30),
    strideRecoverySeconds: clampInt(session.strideRecoverySeconds, 60, 90),
  };
}

function trimExtraStrideSessions(
  sessions: GeneratedSession[],
  config: StrideConfig,
  hardDays: Set<string>,
): void {
  const existing = sessions.filter((session) => hasStrides(session));
  if (existing.length <= config.maxPerWeek) return;

  const kept = selectBestStrideSessions(
    existing,
    sessions,
    config.maxPerWeek,
    hardDays,
  );

  for (let i = 0; i < sessions.length; i += 1) {
    if (hasStrides(sessions[i]) && !kept.has(sessions[i].id)) {
      sessions[i] = withoutStrides(sessions[i]);
    }
  }
}

function addMissingStrideSessions(
  sessions: GeneratedSession[],
  config: StrideConfig,
  hardDays: Set<string>,
  protectedFirstTrainingId: string | null,
  locale: CoachNoteLocale,
): void {
  while (
    sessions.filter((session) => hasStrides(session)).length <
      config.maxPerWeek
  ) {
    const existing = sessions.filter((session) => hasStrides(session));
    const candidate = sessions
      .filter((session) =>
        session.id !== protectedFirstTrainingId &&
        !hasStrides(session) &&
        isStridePlacementEligible(session, hardDays)
      )
      .sort((a, b) =>
        stridePlacementScore(a, sessions, existing, hardDays) -
        stridePlacementScore(b, sessions, existing, hardDays)
      )[0];

    if (candidate == null) return;

    const index = sessions.findIndex((session) => session.id === candidate.id);
    sessions[index] = {
      ...candidate,
      strideReps: config.reps,
      strideSeconds: config.seconds,
      strideRecoverySeconds: config.recoverySeconds,
      coachNote: appendStrideCue(candidate.coachNote, locale),
    };
  }
}

function selectBestStrideSessions(
  candidates: GeneratedSession[],
  weekSessions: GeneratedSession[],
  maxCount: number,
  hardDays: Set<string>,
): Set<string> {
  const remaining = [...candidates];
  const selected: GeneratedSession[] = [];

  while (selected.length < maxCount && remaining.length > 0) {
    remaining.sort((a, b) =>
      stridePlacementScore(a, weekSessions, selected, hardDays) -
      stridePlacementScore(b, weekSessions, selected, hardDays)
    );
    selected.push(remaining.shift()!);
  }

  return new Set(selected.map((session) => session.id));
}

function isStridePlacementEligible(
  session: GeneratedSession,
  hardDays: Set<string>,
): boolean {
  if (!["easyRun", "recoveryRun"].includes(session.type)) return false;
  if (hardDays.has(dayKeyForDate(session.date))) return false;
  if (isStressfulSession(session)) return false;
  return true;
}

function hasStrides(session: GeneratedSession): boolean {
  return (session.strideReps ?? 0) > 0 && (session.strideSeconds ?? 0) > 0;
}

function withoutStrides(session: GeneratedSession): GeneratedSession {
  return {
    ...session,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function clampInt(
  value: number | null,
  min: number,
  max: number,
): number {
  const numericValue = typeof value === "number" && Number.isFinite(value)
    ? Math.floor(value)
    : min;
  return Math.min(max, Math.max(min, numericValue));
}

function stridePlacementScore(
  session: GeneratedSession,
  weekSessions: GeneratedSession[],
  selectedStrideSessions: GeneratedSession[],
  hardDays: Set<string>,
): number {
  let score = session.type === "easyRun" ? 0 : 4;

  const dayOffset = dayOffsetInWeek(session.date);
  score += dayOffset <= 3 ? dayOffset : 10 + dayOffset;

  if (isDayBeforeLongRun(session, weekSessions)) score += 20;
  if (
    selectedStrideSessions.some((selected) =>
      areDatesAdjacent(selected.date, session.date)
    )
  ) {
    score += 15;
  }
  if (hardDays.has(dayKeyForDate(session.date))) score += 100;

  return score;
}

function isDayBeforeLongRun(
  session: GeneratedSession,
  weekSessions: GeneratedSession[],
): boolean {
  return weekSessions.some((candidate) =>
    candidate.type === "longRun" &&
    dateDifferenceDays(session.date, candidate.date) === 1
  );
}

function raceWeekNumbersFor(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
): Set<number> {
  const goal = objectOrNull(profileData.goal);
  const raceDate = typeof goal?.raceDate === "string"
    ? goal.raceDate.slice(0, 10)
    : null;
  const raceWeeks = new Set<number>();

  if (raceDate != null) {
    for (const session of sessions) {
      if (session.date.slice(0, 10) === raceDate) {
        raceWeeks.add(session.weekNumber);
      }
    }
  }

  if (raceWeeks.size === 0 && totalWeeks > 0) raceWeeks.add(totalWeeks);
  return raceWeeks;
}

function appendStrideCue(
  coachNote: string | null,
  locale: CoachNoteLocale,
): string {
  const strideCue = trainingDayCue("strideAdded", locale);
  if (!coachNote) return strideCue;
  const lowerNote = coachNote.toLowerCase();
  if (lowerNote.includes("stride") || lowerNote.includes("progresivo")) {
    return coachNote;
  }
  return `${coachNote} ${strideCue}`;
}

function findHardDaySwapIndex(
  sessions: GeneratedSession[],
  sourceIndex: number,
  hardDays: Set<string>,
): number | null {
  const source = sessions[sourceIndex];
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    if (i === sourceIndex) continue;

    const candidate = sessions[i];
    if (candidate.weekNumber !== source.weekNumber) continue;
    if (hardDays.has(dayKeyForDate(candidate.date))) continue;
    if (!isLowStressSession(candidate)) continue;

    const score = sessionSwapScore(candidate);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function hardDaySetFor(profileData: Record<string, unknown>): Set<string> {
  const schedule = objectOrNull(profileData.schedule);
  const hardDays = Array.isArray(schedule?.hardDays) ? schedule.hardDays : [];
  const strength = strengthPreferences(profileData);
  const legDays = hasLegStrengthPreference(strength)
    ? strength.preferredDays
    : [];
  return new Set(
    [...hardDays, ...legDays].filter((day): day is string =>
      typeof day === "string" && day.startsWith("day_")
    ),
  );
}

function dayKeyForDate(date: string): string {
  const parsedDate = parseDateOnly(date);
  if (parsedDate == null) return "";

  const dayIndex = parsedDate.getUTCDay();
  return [
    "day_sun",
    "day_mon",
    "day_tue",
    "day_wed",
    "day_thu",
    "day_fri",
    "day_sat",
  ][dayIndex] ?? "";
}

function parseDateOnly(date: string): Date | null {
  const [year, month, day] = date.slice(0, 10).split("-").map(Number);
  if (!year || !month || !day) return null;
  return new Date(Date.UTC(year, month - 1, day));
}

function compareSessionsByDate(
  a: GeneratedSession,
  b: GeneratedSession,
): number {
  const dateComparison = a.date.localeCompare(b.date);
  if (dateComparison !== 0) return dateComparison;
  return a.id.localeCompare(b.id);
}

function isStressfulSession(session: GeneratedSession): boolean {
  return [
    "longRun",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "tempoRun",
    "thresholdRun",
    "racePaceRun",
  ].includes(session.type);
}

function isGoalRaceSession(
  session: GeneratedSession,
  profileData: Record<string, unknown>,
): boolean {
  const goal = objectOrNull(profileData.goal);
  const raceDate = typeof goal?.raceDate === "string" ? goal.raceDate : null;
  return session.type === "racePaceRun" &&
    raceDate != null &&
    session.date.slice(0, 10) === raceDate.slice(0, 10);
}

function isLowStressSession(session: GeneratedSession): boolean {
  return ["restDay", "recoveryRun", "easyRun"].includes(session.type);
}

function sessionSwapScore(session: GeneratedSession): number {
  switch (session.type) {
    case "restDay":
      return 0;
    case "recoveryRun":
      return 1;
    case "easyRun":
      return 2;
    default:
      return 4;
  }
}

function withScheduleNote(
  session: GeneratedSession,
  locale: CoachNoteLocale,
): GeneratedSession {
  const scheduleCue = trainingDayCue("movedAwayFromHardDay", locale);
  const coachNote = session.coachNote;
  if (!coachNote) return { ...session, coachNote: scheduleCue };
  if (coachNote.toLowerCase().includes(scheduleCue.toLowerCase())) {
    return session;
  }
  return { ...session, coachNote: `${coachNote} ${scheduleCue}` };
}

type TrainingDayCueKey =
  | "restDay"
  | "preferredLongRunDay"
  | "movedForSpacing"
  | "restDayAdded"
  | "shortRecoveryAdded"
  | "easyRunAdded"
  | "adjustedForSpacing"
  | "adjustedForPhase"
  | "peakLongRunNormalized"
  | "strideAdded"
  | "movedAwayFromHardDay"
  | "hardDayRecoveryFallback"
  | "firstSessionEasyStart"
  | "peakLongRunGuardrailCapped";

function trainingDayCue(
  key: TrainingDayCueKey,
  locale: CoachNoteLocale,
): string {
  const cues: Record<TrainingDayCueKey, Record<CoachNoteLocale, string>> = {
    restDay: {
      en: "Rest day. Keep it easy and let your body absorb the training.",
      es:
        "Día de descanso. Mantén el día suave y deja que tu cuerpo asimile el entrenamiento.",
    },
    preferredLongRunDay: {
      en: "Moved to your preferred long run day.",
      es: "Movido a tu día preferido para la tirada larga.",
    },
    movedForSpacing: {
      en: "Moved to keep hard training days spaced safely.",
      es: "Movido para separar mejor los días duros de entrenamiento.",
    },
    restDayAdded: {
      en: "Rest day added to match your selected training days.",
      es:
        "Día de descanso añadido para respetar tus días de entrenamiento seleccionados.",
    },
    shortRecoveryAdded: {
      en: "Short recovery run added because your selected schedule is tight.",
      es:
        "Carrera corta de recuperación añadida porque tu horario seleccionado es ajustado.",
    },
    easyRunAdded: {
      en: "Easy run added to match your selected training days.",
      es:
        "Carrera suave añadida para respetar tus días de entrenamiento seleccionados.",
    },
    adjustedForSpacing: {
      en: "Adjusted to keep hard training days spaced safely.",
      es: "Ajustado para separar mejor los días duros de entrenamiento.",
    },
    adjustedForPhase: {
      en: "Adjusted to match phase-appropriate training.",
      es: "Ajustado para coincidir con el entrenamiento apropiado de la fase.",
    },
    peakLongRunNormalized: {
      en: "Adjusted to match peak long run target.",
      es: "Ajustado para coincidir con el objetivo de tirada larga máxima.",
    },
    strideAdded: {
      en: "Finish with relaxed strides: fast but smooth, not a sprint.",
      es:
        "Termina con progresivos relajados: rápidos pero controlados, no un sprint.",
    },
    movedAwayFromHardDay: {
      en: "Moved away from a day you marked hard to train.",
      es: "Movido fuera de un día que marcaste como difícil para entrenar.",
    },
    hardDayRecoveryFallback: {
      en:
        "Short recovery run kept because your selected training schedule is tight.",
      es:
        "Carrera corta de recuperación mantenida porque tu horario seleccionado es ajustado.",
    },
    firstSessionEasyStart: {
      en:
        "Start the plan with a controlled easy run before adding harder workouts.",
      es:
        "Empieza el plan con una carrera suave y controlada antes de añadir entrenamientos más duros.",
    },
    peakLongRunGuardrailCapped: {
      en:
        "Peak long run was kept at the safety limit; evidence-based increase is currently blocked by guardrails.",
      es:
        "La tirada larga máxima se mantuvo por límites de seguridad; la evidencia adicional está bloqueada por guardas de riesgo.",
    },
  };
  return cues[key][locale];
}

function appendTrainingDayCue(
  coachNote: string | null,
  cue: string,
): string {
  if (!coachNote) return cue;
  if (coachNote.toLowerCase().includes(cue.toLowerCase())) return coachNote;
  return `${coachNote} ${cue}`;
}

function objectOrNull(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

const PEAK_LONG_RUN_EVIDENCE_FRACTION = 0.7;
const PEAK_LONG_RUN_VOLUME_SAFETY_RATIO = 0.33;

function canRaisePeakLongRunFromBriefEvidence(
  profileData: Record<string, unknown>,
  coachingBrief: CoachingBrief | null,
): boolean {
  if (coachingBrief == null) return false;
  if (
    coachingBrief.source !== "strava" &&
    coachingBrief.source !== "mixed"
  ) {
    return false;
  }

  if (
    coachingBrief.confidence !== "high" &&
    coachingBrief.confidence !== "medium"
  ) {
    return false;
  }

  if (
    !hasStrongEvidenceConfidence(profileData)
  ) {
    return false;
  }

  const currentVolumeKmPerWeek = normalizePositiveNumber(
    coachingBrief.currentVolumeKmPerWeek,
    0,
  );
  if (currentVolumeKmPerWeek == null || currentVolumeKmPerWeek <= 0) {
    return false;
  }

  const recentLongRunKm = normalizePositiveNumber(
    coachingBrief.recentLongRunKm,
    0,
  );
  return recentLongRunKm != null && recentLongRunKm > 0;
}

function resolvePeakLongRunRange(
  range: PeakLongRunRange,
  profileData: Record<string, unknown>,
  coachingBrief: CoachingBrief | null,
): PeakLongRunRange {
  if (!canRaisePeakLongRunFromBriefEvidence(profileData, coachingBrief)) {
    return range;
  }
  if (coachingBrief == null) return range;

  const recentLongRunKm = normalizePositiveNumber(
    coachingBrief.recentLongRunKm,
    0,
  );
  if (recentLongRunKm == null) return range;

  const currentVolumeKmPerWeek = normalizePositiveNumber(
    coachingBrief.currentVolumeKmPerWeek,
    0,
  );
  if (currentVolumeKmPerWeek == null || currentVolumeKmPerWeek <= 0) {
    return range;
  }
  const evidenceTargetKm = recentLongRunKm * PEAK_LONG_RUN_EVIDENCE_FRACTION;
  const evidenceCapKm = currentVolumeKmPerWeek == null
    ? evidenceTargetKm
    : Math.min(
      evidenceTargetKm,
      currentVolumeKmPerWeek * PEAK_LONG_RUN_VOLUME_SAFETY_RATIO,
    );

  if (evidenceCapKm <= range.maxKm) return range;

  return {
    minKm: range.minKm,
    targetKm: Math.max(range.targetKm, evidenceCapKm),
    maxKm: Math.max(range.maxKm, evidenceCapKm),
  };
}

export function normalizePeakLongRun(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  locale: CoachNoteLocale = "en",
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const context = ruleContextFor(profileData, coachingBrief);
  const range = peakLongRunRangeFor(context);
  const briefLongRunCeilingKm = normalizePositiveNumber(
    coachingBrief?.longRunCeilingKm,
    MIN_COACHING_BRIEF_LONG_RUN_CEILING_KM,
  );
  const measuredLongestRecentRunKm = longRunHistoryFloor(profileData);
  const historyFloorKm = measuredLongestRecentRunKm == null
    ? null
    : Math.min(measuredLongestRecentRunKm, range.maxKm);
  const normalizedRange = {
    minKm: Math.max(range.minKm, historyFloorKm ?? range.minKm),
    targetKm: Math.max(range.targetKm, historyFloorKm ?? range.targetKm),
    maxKm: Math.max(range.maxKm, historyFloorKm ?? range.maxKm),
  };
  const evidenceAwareRange = resolvePeakLongRunRange(
    normalizedRange,
    profileData,
    coachingBrief,
  );
  const hadEvidenceAwarePotential =
    evidenceAwareRange.targetKm > normalizedRange.targetKm ||
    evidenceAwareRange.maxKm > normalizedRange.maxKm;
  const cappedRange = {
    maxKm: briefLongRunCeilingKm == null
      ? evidenceAwareRange.maxKm
      : Math.min(evidenceAwareRange.maxKm, briefLongRunCeilingKm),
    targetKm: briefLongRunCeilingKm == null
      ? evidenceAwareRange.targetKm
      : Math.min(evidenceAwareRange.targetKm, briefLongRunCeilingKm),
    minKm: briefLongRunCeilingKm == null
      ? evidenceAwareRange.minKm
      : Math.min(evidenceAwareRange.minKm, briefLongRunCeilingKm),
  };
  const peakWeeks = new Set(
    Array.from({ length: totalWeeks }, (_, i) => i + 1)
      .filter((w) =>
        phaseForWeekFromCoachingBrief(
          w,
          totalWeeks,
          profileData,
          coachingBrief,
        ) === "peak"
      ),
  );

  const adjusted = sessions.map((session) => ({ ...session }));
  let bestPeakLongRun: { index: number; distanceKm: number } | null = null;

  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (session.type !== "longRun") continue;
    if (!peakWeeks.has(session.weekNumber)) continue;
    if (isGoalRaceSession(session, profileData)) continue;

    const currentDistance = session.distanceKm ?? 0;
    if (
      bestPeakLongRun == null || currentDistance > bestPeakLongRun.distanceKm
    ) {
      bestPeakLongRun = { index: i, distanceKm: currentDistance };
    }
  }

  if (bestPeakLongRun == null) return sessions;

  const targetDistance = cappedRange.targetKm;
  const currentDistance = bestPeakLongRun.distanceKm;
  const hasPeakLongRunGuardrail = hasBlockingGuardrail(
    profileData,
    GUARDRAIL_BLOCKING_PEAK_LONG_RUN,
  );
  const normalizedTargetDistance = hasPeakLongRunGuardrail
    ? range.targetKm
    : targetDistance;
  const guardrailSuppressedEvidenceLift = hasPeakLongRunGuardrail &&
    hadEvidenceAwarePotential;
  const finalDistance = Math.max(
    cappedRange.minKm,
    Math.min(cappedRange.maxKm, normalizedTargetDistance),
  );

  if (Math.abs(finalDistance - currentDistance) > 0.01) {
    const newDuration = recalculateDurationForDistance(
      adjusted,
      bestPeakLongRun.index,
      finalDistance,
      profileData,
    );

    const wasRaised = currentDistance < finalDistance;
    const cue = guardrailSuppressedEvidenceLift
      ? trainingDayCue("peakLongRunGuardrailCapped", locale)
      : wasRaised
      ? locale === "en"
        ? "Peak long run raised to target."
        : "Tirada larga máxima aumentada al objetivo."
      : "Peak long run capped to safe maximum.";

    adjusted[bestPeakLongRun.index] = {
      ...adjusted[bestPeakLongRun.index],
      distanceKm: finalDistance,
      durationMinutes: newDuration,
      coachNote: appendTrainingDayCue(
        adjusted[bestPeakLongRun.index].coachNote,
        cue,
      ),
    };
  }

  return adjusted;
}

function recalculateDurationForDistance(
  sessions: GeneratedSession[],
  targetIndex: number,
  newDistanceKm: number,
  profileData: Record<string, unknown>,
): number | null {
  const targetSession = sessions[targetIndex];
  const targetWeek = targetSession.weekNumber;

  const nearbyLongRunData: {
    index: number;
    distanceKm: number;
    durationMinutes: number;
  }[] = [];

  for (let i = 0; i < sessions.length; i += 1) {
    const s = sessions[i];
    if (s.type !== "longRun") continue;
    if (i === targetIndex) continue;
    if (s.distanceKm == null || s.durationMinutes == null) continue;
    const weekDiff = Math.abs(s.weekNumber - targetWeek);
    if (weekDiff >= 1 && weekDiff <= 2) {
      nearbyLongRunData.push({
        index: i,
        distanceKm: s.distanceKm,
        durationMinutes: s.durationMinutes,
      });
    }
  }

  if (nearbyLongRunData.length > 0) {
    const avgPaceMinPerKm = nearbyLongRunData.reduce((sum, lr) => {
      return sum + (lr.durationMinutes / (lr.distanceKm ?? 1));
    }, 0) / nearbyLongRunData.length;

    return Math.round(avgPaceMinPerKm * newDistanceKm);
  }

  const experience = experienceFromProfile(profileData);
  const fallbackPaceMinPerKm = fallbackEasyPaceMinPerKm(experience);
  return Math.round(fallbackPaceMinPerKm * newDistanceKm);
}

function fallbackEasyPaceMinPerKm(experience: string): number {
  switch (experience) {
    case "experience_experienced":
      return 5.75;
    case "experience_intermediate":
      return 6.5;
    default:
      return 7.5;
  }
}

export function smoothLongRunProgression(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  _locale: CoachNoteLocale = "en",
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const context = ruleContextFor(profileData, coachingBrief);
  const race = context.race;
  const maxJump = maxLongRunJumpKm(race);
  const longRunCeilingKm = normalizePositiveNumber(
    coachingBrief?.longRunCeilingKm,
    MIN_COACHING_BRIEF_LONG_RUN_CEILING_KM,
  );

  const adjusted = sessions.map((s) => ({ ...s }));
  const protectedPeakIndex = protectedPeakLongRunIndex(
    adjusted,
    profileData,
    totalWeeks,
    coachingBrief,
  );

  const longRunIndices: number[] = [];
  for (let i = 0; i < adjusted.length; i += 1) {
    if (
      adjusted[i].type === "longRun" &&
      !isGoalRaceSession(adjusted[i], profileData)
    ) {
      longRunIndices.push(i);
    }
  }

  if (longRunIndices.length === 0) return sessions;

  longRunIndices.sort((a, b) =>
    adjusted[a].weekNumber - adjusted[b].weekNumber
  );

  for (let i = 0; i < longRunIndices.length; i += 1) {
    const currIdx = longRunIndices[i];
    if (currIdx === protectedPeakIndex) continue;

    const currDist = adjusted[currIdx].distanceKm ?? 0;
    let newDistance = currDist;

    if (
      longRunCeilingKm != null &&
      currDist > longRunCeilingKm
    ) {
      newDistance = longRunCeilingKm;
    }

    if (i > 0) {
      const prevIdx = longRunIndices[i - 1];
      const prevDist = adjusted[prevIdx].distanceKm ?? 0;
      if (currDist > prevDist) {
        const maxAllowedFromJump = prevDist + maxJump;
        const maxAllowed = longRunCeilingKm == null
          ? maxAllowedFromJump
          : Math.min(maxAllowedFromJump, longRunCeilingKm);

        if (newDistance > maxAllowed) {
          newDistance = maxAllowed;
        }
      }
    }

    if (Math.abs(newDistance - currDist) < 0.01) continue;

    const newDuration = recalculateDurationForDistance(
      adjusted,
      currIdx,
      newDistance,
      profileData,
    );
    adjusted[currIdx] = {
      ...adjusted[currIdx],
      distanceKm: newDistance,
      durationMinutes: newDuration,
    };
  }

  return adjusted;
}

const WEEKLY_VOLUME_RAMP_FACTOR = 1.1; // ~10% week-over-week ceiling.
const WEEKLY_VOLUME_TOLERANCE = 0.05; // small slack before clamping kicks in.
const WEEKLY_VOLUME_RAMP_LOW_CONFIDENCE_FACTOR = 1.05;
const WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_STRONG_EVIDENCE = 0.85;
const WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_LOW_CONFIDENCE = 0.55;
const WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_BY_READINESS: Record<
  ReadinessLevel,
  number
> = {
  raceReady: 0.95,
  prepared: 0.9,
  developing: 0.85,
  underprepared: 0.8,
  unsupported: 0.75,
};

type WeeklyVolumeProfile = {
  anchor: number;
  rampFactor: number;
  maxWeeklyVolumeKm: number | null;
  weekOneMinimumRatio: number;
  longRunCeilingKm: number | null;
};

const MIN_COACHING_BRIEF_LONG_RUN_CEILING_KM = 0.01;

function normalizePositiveNumber(
  value: unknown,
  minimum = 0,
): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= minimum
    ? value
    : null;
}

function weeklyVolumeProfileForBrief(
  coachingBrief: CoachingBrief | null,
): WeeklyVolumeProfile | null {
  if (coachingBrief == null) return null;

  const anchor = normalizePositiveNumber(
    coachingBrief.currentVolumeKmPerWeek,
    0,
  );
  const hasAnchor = anchor != null && anchor > 0;

  const maxWeeklyVolumeKm = normalizePositiveNumber(
    coachingBrief.maxWeeklyVolumeKm,
    0,
  );
  if (!hasAnchor && maxWeeklyVolumeKm == null) return null;

  const longRunCeilingKm = normalizePositiveNumber(
    coachingBrief.longRunCeilingKm,
    MIN_COACHING_BRIEF_LONG_RUN_CEILING_KM,
  );
  const hasEvidenceSource = coachingBrief.source === "strava" ||
    coachingBrief.source === "mixed";

  let minimumRatio = WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_LOW_CONFIDENCE;
  let rampFactor = WEEKLY_VOLUME_RAMP_LOW_CONFIDENCE_FACTOR;
  if (!hasAnchor) {
    minimumRatio = 0;
  }

  if (hasEvidenceSource && coachingBrief.confidence === "high") {
    rampFactor = WEEKLY_VOLUME_RAMP_FACTOR;
    minimumRatio = hasAnchor && coachingBrief.currentVolumeKmPerWeek >= 20
      ? WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_STRONG_EVIDENCE
      : Math.max(
        WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_LOW_CONFIDENCE,
        WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_BY_READINESS[
          coachingBrief.readinessLevel
        ],
      );
  } else if (coachingBrief.confidence === "medium") {
    rampFactor = WEEKLY_VOLUME_RAMP_FACTOR;
    minimumRatio = hasAnchor
      ? WEEKLY_VOLUME_WEEK_ONE_MIN_RATIO_BY_READINESS[
        coachingBrief.readinessLevel
      ]
      : 0;
  }

  return {
    anchor: hasAnchor ? anchor : 0,
    rampFactor,
    maxWeeklyVolumeKm,
    weekOneMinimumRatio: Math.min(1, minimumRatio),
    longRunCeilingKm,
  };
}

function weeklyVolumeProfile(
  profileData: Record<string, unknown>,
  coachingBrief: CoachingBrief | null = null,
): WeeklyVolumeProfile | null {
  return weeklyVolumeProfileForBrief(coachingBrief) ??
    baselineWeeklyVolumeProfile(profileData);
}

// FIX B: deterministic acute:chronic ramp guard. The prompt asks the model to
// cap weekly growth (~<=10%) using athleteSummary.acuteChronicRatio, but that is
// advisory only. When source profile is available, anchor week-1 total volume
// near the current evidence and hard-clamp each week's increase to ~10% over the
// prior week's (post-clamp) volume. Taper/down weeks plan less than the prior
// week, so they fall under their cap and are left untouched.
export function normalizeWeeklyVolumeRamp(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  _locale: CoachNoteLocale = "en",
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const baseline = weeklyVolumeProfile(profileData, coachingBrief);
  if (baseline == null) return sessions;

  const anchorVolumeKm = baseline.anchor;
  const rampFactor = baseline.rampFactor;
  const maxWeeklyVolumeKm = baseline.maxWeeklyVolumeKm;
  const weekOneMinimumRatio = baseline.weekOneMinimumRatio;

  const adjusted = sessions.map((s) => ({ ...s }));

  const weekNumbers = Array.from(
    new Set(adjusted.map((s) => s.weekNumber)),
  ).sort((a, b) => a - b);

  let previousCappedVolumeKm: number | null = null;
  let encounteredActiveWeek = false;

  for (const weekNumber of weekNumbers) {
    const phase = phaseForWeekFromCoachingBrief(
      weekNumber,
      totalWeeks,
      profileData,
      coachingBrief,
    );
    const indices = adjusted
      .map((s, i) => ({ s, i }))
      .filter(({ s }) =>
        s.weekNumber === weekNumber &&
        s.type !== "restDay" &&
        !isGoalRaceSession(s, profileData)
      )
      .map(({ i }) => i);

    const weekVolumeKm = indices.reduce(
      (sum, i) => sum + estimateSessionVolumeKm(adjusted[i], profileData),
      0,
    );

    // Taper weeks are intentionally reduced; never let the ramp guard touch
    // them and don't let their low volume become the base for later weeks.
    if (phase === "taperRace") {
      continue;
    }
    const isFirstActiveWeek = !encounteredActiveWeek;
    encounteredActiveWeek = true;

    const uncappedCap = previousCappedVolumeKm == null
      ? (
        anchorVolumeKm <= 0
          ? Number.POSITIVE_INFINITY
          : anchorVolumeKm * rampFactor
      )
      : previousCappedVolumeKm * rampFactor;
    const cap = maxWeeklyVolumeKm == null
      ? uncappedCap
      : Math.min(uncappedCap, maxWeeklyVolumeKm);

    if (
      isFirstActiveWeek &&
      weekOneMinimumRatio > 0 &&
      weekVolumeKm > 0
    ) {
      const minimumWeekOneVolumeKm = Math.min(
        anchorVolumeKm * weekOneMinimumRatio,
        cap,
      );

      if (weekVolumeKm < minimumWeekOneVolumeKm) {
        const scale = minimumWeekOneVolumeKm / weekVolumeKm;
        for (const i of indices) {
          const session = adjusted[i];
          const currentDistance = session.distanceKm;
          if (currentDistance == null || currentDistance <= 0) continue;
          const scaledDistance = Math.round(currentDistance * scale * 100) /
            100;
          const constrainedDistance = constrainedSessionDistanceKm(
            session,
            scaledDistance,
            baseline,
          );
          const newDuration = recalculateDurationForDistance(
            adjusted,
            i,
            constrainedDistance,
            profileData,
          );
          adjusted[i] = {
            ...session,
            distanceKm: constrainedDistance,
            durationMinutes: newDuration,
          };
        }

        previousCappedVolumeKm = indices.reduce(
          (sum, i) => sum + estimateSessionVolumeKm(adjusted[i], profileData),
          0,
        );
        continue;
      }
    }

    const effectiveTolerance = maxWeeklyVolumeKm == null
      ? WEEKLY_VOLUME_TOLERANCE
      : 0;
    if (
      weekVolumeKm <= cap * (1 + effectiveTolerance) || weekVolumeKm <= 0
    ) {
      // Within budget (covers down weeks that plan less than the prior week).
      previousCappedVolumeKm = weekVolumeKm;
      continue;
    }

    const scale = cap / weekVolumeKm;
    for (const i of indices) {
      const session = adjusted[i];
      const currentDistance = session.distanceKm;
      if (currentDistance == null || currentDistance <= 0) continue;
      const scaledDistance = Math.round(currentDistance * scale * 100) / 100;
      const constrainedDistance = constrainedSessionDistanceKm(
        session,
        scaledDistance,
        baseline,
      );
      const newDuration = recalculateDurationForDistance(
        adjusted,
        i,
        constrainedDistance,
        profileData,
      );
      adjusted[i] = {
        ...session,
        distanceKm: constrainedDistance,
        durationMinutes: newDuration,
      };
    }

    previousCappedVolumeKm = indices.reduce(
      (sum, i) => sum + estimateSessionVolumeKm(adjusted[i], profileData),
      0,
    );
  }

  return adjusted;
}

// Best-effort weekly-volume signal: prefer explicit distance, else convert
// duration to km using the experience-based fallback easy pace.
function estimateSessionVolumeKm(
  session: GeneratedSession,
  profileData: Record<string, unknown>,
): number {
  if (typeof session.distanceKm === "number" && session.distanceKm > 0) {
    return session.distanceKm;
  }
  if (
    typeof session.durationMinutes === "number" && session.durationMinutes > 0
  ) {
    const paceMinPerKm = fallbackEasyPaceMinPerKm(
      experienceFromProfile(profileData),
    );
    if (paceMinPerKm > 0) return session.durationMinutes / paceMinPerKm;
  }
  return 0;
}

function constrainedSessionDistanceKm(
  session: GeneratedSession,
  distanceKm: number,
  profile: WeeklyVolumeProfile,
): number {
  if (
    !Number.isFinite(distanceKm) ||
    profile.longRunCeilingKm == null ||
    session.type !== "longRun"
  ) {
    return distanceKm;
  }

  return Math.min(distanceKm, profile.longRunCeilingKm);
}

function protectedPeakLongRunIndex(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  coachingBrief: CoachingBrief | null = null,
): number | null {
  const peakWeeks = new Set(
    Array.from({ length: totalWeeks }, (_, i) => i + 1)
      .filter((w) =>
        phaseForWeekFromCoachingBrief(
          w,
          totalWeeks,
          profileData,
          coachingBrief,
        ) === "peak"
      ),
  );

  let bestPeakLongRun: { index: number; distanceKm: number } | null = null;

  for (let i = 0; i < sessions.length; i += 1) {
    const session = sessions[i];
    if (session.type !== "longRun") continue;
    if (!peakWeeks.has(session.weekNumber)) continue;
    if (isGoalRaceSession(session, profileData)) continue;

    const currentDistance = session.distanceKm ?? 0;
    if (
      bestPeakLongRun == null || currentDistance > bestPeakLongRun.distanceKm
    ) {
      bestPeakLongRun = { index: i, distanceKm: currentDistance };
    }
  }

  return bestPeakLongRun?.index ?? null;
}

function maxLongRunJumpKm(race: string): number {
  switch (race) {
    case "race_5k":
      return 2;
    case "race_10k":
      return 2;
    case "race_half_marathon":
      return 3;
    case "race_marathon":
      return 4;
    default:
      return 2;
  }
}

function quietWindowDaysFor(race: string): number {
  switch (race) {
    case "race_5k":
    case "race_10k":
      return 2;
    case "race_half_marathon":
    case "race_marathon":
      return 3;
    default:
      return 2;
  }
}

export function normalizeTaper(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  _locale: CoachNoteLocale = "en",
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const race = raceFromProfile(profileData);
  const taperRaceWeeks = new Set(
    Array.from({ length: totalWeeks }, (_, i) => i + 1)
      .filter((w) =>
        phaseForWeekFromCoachingBrief(
          w,
          totalWeeks,
          profileData,
          coachingBrief,
        ) === "taperRace"
      ),
  );

  if (taperRaceWeeks.size === 0) return sessions;

  const adjusted = sessions.map((session) => ({ ...session }));

  const longRunSessionsInTaper = adjusted
    .filter((s) =>
      s.type === "longRun" &&
      !isGoalRaceSession(s, profileData) &&
      taperRaceWeeks.has(s.weekNumber)
    )
    .sort((a, b) => a.weekNumber - b.weekNumber);

  if (longRunSessionsInTaper.length === 0) return sessions;

  const peakWeeks = new Set(
    Array.from({ length: totalWeeks }, (_, i) => i + 1)
      .filter((w) =>
        phaseForWeekFromCoachingBrief(
          w,
          totalWeeks,
          profileData,
          coachingBrief,
        ) === "peak"
      ),
  );

  const peakLongRuns = adjusted
    .filter((s) =>
      s.type === "longRun" &&
      !isGoalRaceSession(s, profileData) &&
      peakWeeks.has(s.weekNumber)
    );
  const peakMaxDistance = peakLongRuns.length > 0
    ? Math.max(...peakLongRuns.map((s) => s.distanceKm ?? 0))
    : null;

  const reductionFactor = marathonReductionFactor(race);
  const targetMinDistance = peakMaxDistance != null
    ? peakMaxDistance * reductionFactor
    : null;

  for (const session of longRunSessionsInTaper) {
    const idx = adjusted.findIndex((s) => s.id === session.id);
    if (idx < 0) continue;

    const currentDist = adjusted[idx].distanceKm ?? 0;
    if (targetMinDistance != null && currentDist > targetMinDistance) {
      const newDuration = recalculateDurationForDistance(
        adjusted,
        idx,
        targetMinDistance,
        profileData,
      );
      adjusted[idx] = {
        ...adjusted[idx],
        distanceKm: targetMinDistance,
        durationMinutes: newDuration,
      };
    } else if (peakMaxDistance != null) {
      const reduced = Math.max(
        0.6 * peakMaxDistance,
        currentDist * reductionFactor,
      );
      if (reduced < currentDist) {
        const newDuration = recalculateDurationForDistance(
          adjusted,
          idx,
          reduced,
          profileData,
        );
        adjusted[idx] = {
          ...adjusted[idx],
          distanceKm: reduced,
          durationMinutes: newDuration,
        };
      }
    }
  }

  return adjusted;
}

export function enforcePreRaceTaper(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const goalRace = sessions.find((s) => isGoalRaceSession(s, profileData));
  const raceDate = goalRaceDate(profileData) ?? goalRace?.date ?? null;
  if (raceDate == null) return sessions;

  const race = raceFromProfile(profileData);
  const quietWindowDays = quietWindowDaysFor(race);

  const adjusted = sessions.map((session) => {
    const daysBeforeRace = dateDifferenceDays(session.date, raceDate);
    if (
      daysBeforeRace > 0 &&
      daysBeforeRace <= quietWindowDays &&
      isStressfulSession(session) &&
      !isGoalRaceSession(session, profileData)
    ) {
      return toEasyStressFallback(session, locale);
    }
    return { ...session };
  });

  return adjusted.sort(compareSessionsByDate);
}

function marathonReductionFactor(race: string): number {
  switch (race) {
    case "race_marathon":
      return 0.6;
    case "race_half_marathon":
      return 0.7;
    case "race_5k":
    case "race_10k":
      return 0.75;
    default:
      return 0.7;
  }
}

export function preferRestOnHardDays(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const hardDays = hardDaySetFor(profileData);
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  if (hardDays.size === 0 || targetTrainingDays == null) return sessions;

  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      preferRestOnHardDaysForWeek(
        sessionsByWeek.get(weekNumber) ?? [],
        hardDays,
        targetTrainingDays,
        profileData,
        locale,
      )
    )
    .sort(compareSessionsByDate);
}

function preferRestOnHardDaysForWeek(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
  targetTrainingDays: number,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );

  const nonHardDates = new Set(
    adjusted
      .filter((session) => !hardDays.has(dayKeyForDate(session.date)))
      .map((session) => session.date.slice(0, 10)),
  );
  const canSatisfyWithoutHardDays = nonHardDates.size >= targetTrainingDays;

  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (!isTrainingDay(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;
    if (!hardDays.has(dayKeyForDate(session.date))) continue;

    if (canSatisfyWithoutHardDays) {
      const swapIndex = findNonHardRestSwapIndex(adjusted, i, hardDays);
      if (swapIndex != null) {
        const swapSession = adjusted[swapIndex];
        adjusted[swapIndex] = withScheduleNote(
          { ...session, date: swapSession.date },
          locale,
        );
        adjusted[i] = toRestDay({ ...swapSession, date: session.date }, locale);
        continue;
      }
      adjusted[i] = toRestDay(session, locale);
      continue;
    }

    if (isStressfulSession(session)) {
      adjusted[i] = toHardDayLowStressFallback(session, locale);
    }
  }

  while (trainingDayCount(adjusted) > targetTrainingDays) {
    const index = findHardDaySessionToRest(adjusted, hardDays, profileData);
    if (index == null) break;
    adjusted[index] = toRestDay(adjusted[index], locale);
  }

  return adjusted.sort(compareSessionsByDate);
}

function findHardDaySessionToRest(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
  profileData: Record<string, unknown>,
): number | null {
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    const session = sessions[i];
    if (!isTrainingDay(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;
    if (!hardDays.has(dayKeyForDate(session.date))) continue;

    const score = restConversionScore(session);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function findNonHardRestSwapIndex(
  sessions: GeneratedSession[],
  sourceIndex: number,
  hardDays: Set<string>,
): number | null {
  const source = sessions[sourceIndex];
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    if (i === sourceIndex) continue;
    const candidate = sessions[i];
    if (candidate.weekNumber !== source.weekNumber) continue;
    if (candidate.type !== "restDay") continue;
    if (hardDays.has(dayKeyForDate(candidate.date))) continue;

    const score = Math.abs(
      dayOffsetInWeek(source.date) - dayOffsetInWeek(candidate.date),
    );
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function toHardDayLowStressFallback(
  session: GeneratedSession,
  locale: CoachNoteLocale,
): GeneratedSession {
  return {
    ...session,
    type: "recoveryRun",
    distanceKm: null,
    durationMinutes: Math.min(30, Math.max(20, session.durationMinutes ?? 25)),
    coachNote: trainingDayCue("hardDayRecoveryFallback", locale),
    targetZone: "recovery",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

export function normalizeFirstPlannedSession(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );
  const firstTrainingIndex = adjusted.findIndex((session) =>
    isTrainingDay(session) && !isGoalRaceSession(session, profileData)
  );
  if (firstTrainingIndex < 0) return adjusted;

  const firstSession = adjusted[firstTrainingIndex];
  if (!isStressfulSession(firstSession)) return adjusted;

  adjusted[firstTrainingIndex] = toFirstSessionEasyRun(
    firstSession,
    profileData,
    locale,
  );
  return adjusted;
}

function toFirstSessionEasyRun(
  session: GeneratedSession,
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale,
): GeneratedSession {
  const fitness = objectOrNull(profileData.fitness);
  const experience = typeof fitness?.experience === "string"
    ? fitness.experience
    : "experience_beginner";
  const useRecovery = experience === "experience_beginner";

  return {
    ...session,
    type: useRecovery ? "recoveryRun" : "easyRun",
    distanceKm: null,
    durationMinutes: useRecovery
      ? 25
      : Math.min(40, Math.max(30, session.durationMinutes ?? 35)),
    coachNote: trainingDayCue("firstSessionEasyStart", locale),
    targetZone: useRecovery ? "recovery" : "easy",
    warmUpMinutes: null,
    coolDownMinutes: null,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

export function normalizeSessionIds(
  sessions: GeneratedSession[],
): GeneratedSession[] {
  const usedIds = new Set<string>();

  return sessions
    .map((session) => {
      const baseId = `w${session.weekNumber}-${
        session.date.slice(0, 10)
      }-${session.type}`;
      const id = uniqueSessionId(baseId, usedIds);
      usedIds.add(id);
      return { ...session, id };
    })
    .sort(compareSessionsByDate);
}

function uniqueSessionId(baseId: string, usedIds: Set<string>): string {
  if (!usedIds.has(baseId)) return baseId;

  let suffix = 2;
  while (usedIds.has(`${baseId}-${suffix}`)) {
    suffix += 1;
  }
  return `${baseId}-${suffix}`;
}

export type ScheduleValidationViolation = {
  rule:
    | "stressful_session_on_hard_day"
    | "avoidable_training_on_hard_day"
    | "first_session_is_stressful"
    | "session_before_plan_start"
    | "session_id_date_mismatch"
    | "long_run_not_on_preferred_day"
    | "session_after_race_date"
    | "stressful_session_before_race"
    | "missing_plan_week"
    | "session_week_after_total_weeks"
    | "session_date_week_mismatch"
    | "coaching_brief_plan_length_mismatch"
    | "coaching_brief_week_one_below_anchor"
    | "coaching_brief_weekly_volume_above_max"
    | "coaching_brief_long_run_above_ceiling"
    | "coaching_brief_taper_phase_mismatch"
    | "coaching_brief_unsupported_ambitious_target";
  sessionId: string;
  date: string;
  message: string;
};

export function unsupportedCoachingBriefReason(
  coachingBrief: CoachingBrief,
): string | null {
  if (
    coachingBrief.raceType === "other" ||
    coachingBrief.readinessLevel === "unsupported"
  ) {
    return "Custom race distances are not supported. Choose 5K, 10K, half marathon, or marathon.";
  }

  return null;
}

export function validateGeneratedPlanAgainstCoachingBrief(
  plan: Pick<GeneratedPlan, "totalWeeks" | "sessions" | "raceGuidance">,
  coachingBrief: CoachingBrief,
): ScheduleValidationViolation[] {
  const violations: ScheduleValidationViolation[] = [];
  const sessions = plan.sessions;

  if (plan.totalWeeks !== coachingBrief.planLengthWeeks) {
    violations.push({
      rule: "coaching_brief_plan_length_mismatch",
      sessionId: "plan",
      date: "",
      message:
        `Generated totalWeeks ${plan.totalWeeks} does not match coaching brief planLengthWeeks ${coachingBrief.planLengthWeeks}.`,
    });
  }

  const weeklyVolumes = weeklyRunVolumeKm(sessions);
  for (const [weekNumber, weeklyVolumeKm] of weeklyVolumes) {
    if (weeklyVolumeKm <= coachingBrief.maxWeeklyVolumeKm + 0.1) continue;
    violations.push({
      rule: "coaching_brief_weekly_volume_above_max",
      sessionId: `week-${weekNumber}`,
      date: "",
      message: `Week ${weekNumber} volume ${
        round1(weeklyVolumeKm)
      } km exceeds coaching brief maxWeeklyVolumeKm ${coachingBrief.maxWeeklyVolumeKm}.`,
    });
  }

  const weekOneVolumeKm = weeklyVolumes.get(1) ?? 0;
  if (
    (coachingBrief.source === "strava" || coachingBrief.source === "mixed") &&
    coachingBrief.confidence === "high" &&
    coachingBrief.currentVolumeKmPerWeek >= 20 &&
    weekOneVolumeKm < coachingBrief.currentVolumeKmPerWeek * 0.55 &&
    coachingBrief.currentVolumeKmPerWeek - weekOneVolumeKm >= 10
  ) {
    violations.push({
      rule: "coaching_brief_week_one_below_anchor",
      sessionId: "week-1",
      date: "",
      message: `Week 1 volume ${
        round1(weekOneVolumeKm)
      } km is far below high-confidence Strava currentVolumeKmPerWeek ${coachingBrief.currentVolumeKmPerWeek}.`,
    });
  }

  for (const session of sessions) {
    if (
      session.type !== "longRun" ||
      session.distanceKm == null ||
      session.distanceKm <= coachingBrief.longRunCeilingKm + 0.1
    ) continue;
    violations.push({
      rule: "coaching_brief_long_run_above_ceiling",
      sessionId: session.id,
      date: session.date,
      message:
        `Long run distance ${session.distanceKm} km exceeds coaching brief longRunCeilingKm ${coachingBrief.longRunCeilingKm}.`,
    });
  }

  const taperStartWeek = Math.max(
    1,
    coachingBrief.planLengthWeeks - coachingBrief.taper.weeks + 1,
  );
  for (const session of sessions) {
    if (session.weekNumber < taperStartWeek || session.phase == null) continue;
    if (session.phase === "taperRace") continue;
    violations.push({
      rule: "coaching_brief_taper_phase_mismatch",
      sessionId: session.id,
      date: session.date,
      message:
        `Session in brief taper window has phase ${session.phase}, expected taperRace.`,
    });
  }

  if (!coachingBrief.ambitiousTarget.supported) {
    const unsupportedAmbitiousTargetText = unsupportedAmbitiousTargetPattern(
      coachingBrief,
    );
    for (const session of sessions) {
      const usesRacePaceTarget = session.type === "racePaceRun" ||
        session.targetZone === "racePace" ||
        session.workoutTarget?.zone === "racePace";
      const drivesFromUnsupportedTarget = usesRacePaceTarget &&
        !coachingBrief.evidenceTarget.supported;
      const mentionsUnsupportedTarget =
        unsupportedAmbitiousTargetText != null &&
        textMatchesTarget(
          [session.coachNote, session.workoutTarget?.effortCue],
          unsupportedAmbitiousTargetText,
        );
      if (!drivesFromUnsupportedTarget && !mentionsUnsupportedTarget) {
        continue;
      }
      violations.push({
        rule: "coaching_brief_unsupported_ambitious_target",
        sessionId: session.id,
        date: session.date,
        message:
          "Session appears to use an unsupported ambitious target despite coaching brief constraints.",
      });
    }

    const raceGuidanceText = Object.values(plan.raceGuidance).filter((
      value,
    ): value is string => typeof value === "string");
    if (
      unsupportedAmbitiousTargetText != null &&
      textMatchesTarget(raceGuidanceText, unsupportedAmbitiousTargetText)
    ) {
      violations.push({
        rule: "coaching_brief_unsupported_ambitious_target",
        sessionId: "raceGuidance",
        date: "",
        message:
          "Race guidance appears to use an unsupported ambitious target despite coaching brief constraints.",
      });
    }
  }

  return violations;
}

function weeklyRunVolumeKm(
  sessions: readonly GeneratedSession[],
): Map<number, number> {
  const volumes = new Map<number, number>();
  for (const session of sessions) {
    if (
      session.type === "restDay" ||
      session.type === "crossTraining" ||
      session.type === "raceDay" ||
      session.distanceKm == null ||
      session.distanceKm <= 0
    ) continue;
    volumes.set(
      session.weekNumber,
      (volumes.get(session.weekNumber) ?? 0) + session.distanceKm,
    );
  }
  return volumes;
}

function unsupportedAmbitiousTargetPattern(
  coachingBrief: CoachingBrief,
): RegExp | null {
  const target = coachingBrief.ambitiousTarget;
  const candidates = [
    target.timeSec == null ? null : formatTimeTarget(target.timeSec),
    target.timeSec == null ? null : formatShortTimeTarget(target.timeSec),
    target.paceSecPerKm == null
      ? null
      : `${formatPaceTarget(target.paceSecPerKm)}/km`,
    target.paceSecPerKm == null
      ? null
      : `${formatPaceTarget(target.paceSecPerKm)} per km`,
  ].filter((value): value is string => value != null && value.length > 0);

  if (candidates.length === 0) return null;
  return new RegExp(
    candidates.map((value) => escapeRegExp(value)).join("|"),
    "i",
  );
}

function textMatchesTarget(
  values: readonly (string | null | undefined)[],
  targetPattern: RegExp,
): boolean {
  return values.some((value) =>
    typeof value === "string" && targetPattern.test(value)
  );
}

function formatTimeTarget(totalSeconds: number): string {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, "0")}:${
      String(seconds).padStart(2, "0")
    }`
    : `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function formatShortTimeTarget(totalSeconds: number): string {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.round((totalSeconds % 3600) / 60);
  return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}` : "";
}

function formatPaceTarget(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export function validateGeneratedPlanShape(
  sessions: GeneratedSession[],
  totalWeeks: number,
  profileData: Record<string, unknown>,
  today: Date = new Date(),
  planStartDate?: string | null,
): ScheduleValidationViolation[] {
  const violations: ScheduleValidationViolation[] = [];
  const sorted = [...sessions].sort(compareSessionsByDate);
  const resolvedPlanStartDate = resolvePlanStartDate(
    profileData,
    today,
    planStartDate,
  );
  const anchorMonday = planStartAnchorMonday(resolvedPlanStartDate) ??
    anchorMondayFor(today);
  const resolvedPlanStartDateValue = parseDateOnly(resolvedPlanStartDate);

  if (Number.isFinite(totalWeeks) && totalWeeks >= 1) {
    const weekNumbers = new Set(sorted.map((session) => session.weekNumber));
    for (let weekNumber = 1; weekNumber <= totalWeeks; weekNumber += 1) {
      if (weekNumbers.has(weekNumber)) continue;
      violations.push({
        rule: "missing_plan_week",
        sessionId: `week-${weekNumber}`,
        date: "",
        message: `Plan has no sessions for week ${weekNumber}.`,
      });
    }

    for (const session of sorted) {
      if (session.weekNumber <= totalWeeks) continue;
      violations.push({
        rule: "session_week_after_total_weeks",
        sessionId: session.id,
        date: session.date,
        message:
          `Session week ${session.weekNumber} is after totalWeeks ${totalWeeks}.`,
      });
    }

    for (const session of sorted) {
      const sessionDate = parseDateOnly(session.date);
      if (
        sessionDate != null &&
        resolvedPlanStartDateValue != null &&
        sessionDate.getTime() < resolvedPlanStartDateValue.getTime()
      ) {
        violations.push({
          rule: "session_before_plan_start",
          sessionId: session.id,
          date: session.date,
          message:
            `Session is before resolved plan start date ${resolvedPlanStartDate}.`,
        });
      }

      const expectedWeekNumber = weekNumberFromAnchor(
        session.date,
        anchorMonday,
      );
      if (
        expectedWeekNumber == null ||
        expectedWeekNumber === session.weekNumber
      ) {
        continue;
      }

      violations.push({
        rule: "session_date_week_mismatch",
        sessionId: session.id,
        date: session.date,
        message:
          `Session date maps to week ${expectedWeekNumber}, got week ${session.weekNumber}.`,
      });
    }
  }

  return violations;
}

export function resolvePlanStartDate(
  profileData: Record<string, unknown> | null | undefined,
  generationDate: Date = new Date(),
  planStartDate?: string | null,
): string {
  const rawPlanStartDate = planStartDate != null
    ? parsePlanStartDateValue(planStartDate)
    : null;
  if (rawPlanStartDate != null) return rawPlanStartDate;

  const schedule = objectOrNull(profileData?.schedule);
  const planStartFromProfile = parsePlanStartDateValue(schedule?.planStartDate);
  if (planStartFromProfile != null) return planStartFromProfile;

  return nextFutureMonday(generationDate);
}

export function planStartAnchorMonday(planStartDate: string): Date | null {
  const parsedPlanStartDate = parseDateOnly(planStartDate);
  if (parsedPlanStartDate == null) return null;
  return anchorMondayFor(parsedPlanStartDate);
}

function nextFutureMonday(date: Date): string {
  const normalizedDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const dayIndex = normalizedDate.getUTCDay();
  const daysUntilNextMonday = dayIndex === 0 ? 1 : 8 - dayIndex;
  normalizedDate.setUTCDate(normalizedDate.getUTCDate() + daysUntilNextMonday);
  return normalizedDate.toISOString().slice(0, 10);
}

function parsePlanStartDateValue(value: unknown): string | null {
  if (typeof value !== "string") return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const candidate = value;
  const parsedDate = parseDateOnly(candidate);
  if (parsedDate == null) return null;
  const normalized = parsedDate.toISOString().slice(0, 10);
  if (normalized !== candidate) return null;
  return candidate;
}

export function validateGeneratedSchedule(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): ScheduleValidationViolation[] {
  const hardDays = hardDaySetFor(profileData);
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  const preferredLongRunDay = preferredLongRunDayFor(profileData);
  const violations: ScheduleValidationViolation[] = [];
  const sorted = [...sessions].sort(compareSessionsByDate);

  const nonHardDateCountByWeek = new Map<number, number>();
  for (
    const weekNumber of new Set(sorted.map((session) => session.weekNumber))
  ) {
    const weekNonHardDateCount = new Set(
      sorted
        .filter((session) =>
          session.weekNumber === weekNumber &&
          !hardDays.has(dayKeyForDate(session.date))
        )
        .map((session) => session.date.slice(0, 10)),
    ).size;
    nonHardDateCountByWeek.set(weekNumber, weekNonHardDateCount);
  }

  for (const session of sorted) {
    const dayKey = dayKeyForDate(session.date);
    if (
      hardDays.has(dayKey) &&
      isStressfulSession(session) &&
      !isGoalRaceSession(session, profileData)
    ) {
      violations.push({
        rule: "stressful_session_on_hard_day",
        sessionId: session.id,
        date: session.date,
        message:
          `${session.type} is scheduled on ${dayKey}, which is marked hard to train.`,
      });
    }

    if (
      targetTrainingDays != null &&
      (nonHardDateCountByWeek.get(session.weekNumber) ?? 0) >=
        targetTrainingDays &&
      hardDays.has(dayKey) &&
      isTrainingDay(session) &&
      !isGoalRaceSession(session, profileData)
    ) {
      violations.push({
        rule: "avoidable_training_on_hard_day",
        sessionId: session.id,
        date: session.date,
        message:
          `${session.type} is scheduled on avoidable hard day ${dayKey}.`,
      });
    }

    if (!session.id.includes(session.date.slice(0, 10))) {
      violations.push({
        rule: "session_id_date_mismatch",
        sessionId: session.id,
        date: session.date,
        message: `Session id does not include final date ${
          session.date.slice(0, 10)
        }.`,
      });
    }
  }

  const firstTraining = sorted.find((session) =>
    isTrainingDay(session) && !isGoalRaceSession(session, profileData)
  );
  if (firstTraining != null && isStressfulSession(firstTraining)) {
    violations.push({
      rule: "first_session_is_stressful",
      sessionId: firstTraining.id,
      date: firstTraining.date,
      message: `${firstTraining.type} is the first planned training session.`,
    });
  }

  if (preferredLongRunDay != null && !hardDays.has(preferredLongRunDay)) {
    for (
      const weekNumber of new Set(sorted.map((session) => session.weekNumber))
    ) {
      const weekSessions = sorted.filter((session) =>
        session.weekNumber === weekNumber
      );
      const longRun = weekSessions.find((session) =>
        session.type === "longRun"
      );
      if (
        longRun != null &&
        !isGoalRaceSession(longRun, profileData) &&
        dayKeyForDate(longRun.date) !== preferredLongRunDay &&
        weekSessions.some((session) =>
          dayKeyForDate(session.date) === preferredLongRunDay &&
          isLowStressSession(session)
        )
      ) {
        violations.push({
          rule: "long_run_not_on_preferred_day",
          sessionId: longRun.id,
          date: longRun.date,
          message: `Long run is not on preferred day ${preferredLongRunDay}.`,
        });
      }
    }
  }

  const raceDate = goalRaceDate(profileData);
  if (raceDate != null) {
    for (const session of sorted) {
      if (dateDifferenceDays(raceDate, session.date) > 0) {
        violations.push({
          rule: "session_after_race_date",
          sessionId: session.id,
          date: session.date,
          message: `Session is scheduled after the goal race date ${raceDate}.`,
        });
      }
    }
  }

  const goalRace = sorted.find((s) => isGoalRaceSession(s, profileData));
  const raceAnchorDate = goalRaceDate(profileData) ?? goalRace?.date ?? null;
  if (raceAnchorDate != null) {
    const race = raceFromProfile(profileData);
    const quietWindowDays = quietWindowDaysFor(race);

    for (const session of sorted) {
      const daysBeforeRace = dateDifferenceDays(session.date, raceAnchorDate);
      if (
        daysBeforeRace > 0 &&
        daysBeforeRace <= quietWindowDays &&
        isStressfulSession(session) &&
        !isGoalRaceSession(session, profileData)
      ) {
        violations.push({
          rule: "stressful_session_before_race",
          sessionId: session.id,
          date: session.date,
          message:
            `${session.type} is within ${quietWindowDays} days before the goal race.`,
        });
      }
    }
  }

  return violations;
}
