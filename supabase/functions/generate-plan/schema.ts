import { z } from "zod";

export const LocaleSchema = z.enum(["en", "es"]);

const WeekdaySchema = z.enum([
  "day_sun",
  "day_mon",
  "day_tue",
  "day_wed",
  "day_thu",
  "day_fri",
  "day_sat",
]);

const TimeSlotSchema = z.enum([
  "time_20_min",
  "time_30_min",
  "time_45_min",
  "time_60_min",
  "time_75_plus_min",
  "time_90_min",
  "time_2_plus_hours",
]);

const PreferredTimeOfDaySchema = z.enum([
  "time_of_day_early_morning",
  "time_of_day_morning",
  "time_of_day_afternoon",
  "time_of_day_evening",
  "time_of_day_no_preference",
]);

const GoalRaceSchema = z.enum([
  "race_5k",
  "race_10k",
  "race_half_marathon",
  "race_marathon",
  "race_other",
]);

const ExperienceSchema = z.enum([
  "experience_brand_new",
  "experience_beginner",
  "experience_intermediate",
  "experience_experienced",
]);

const WeeklyVolumeSchema = z.enum([
  "weekly_volume_0",
  "weekly_volume_1",
  "weekly_volume_2",
  "weekly_volume_3",
  "weekly_volume_4",
  "weekly_volume_5",
  "weekly_volume_6",
]);

const LongestRunSchema = z.enum([
  "longest_run_0",
  "longest_run_1",
  "longest_run_2",
  "longest_run_3",
  "longest_run_4",
  "longest_run_5",
  "longest_run_6",
]);

const TernarySchema = z.enum(["yes", "no", "not_sure"]);

const BenchmarkSchema = z.enum([
  "benchmark_1km_run",
  "benchmark_1km_walk",
  "benchmark_1mi_run",
  "benchmark_1mi_walk",
  "benchmark_5k",
  "benchmark_10k",
  "benchmark_half_marathon",
  "benchmark_skip",
]);

const RaceDistanceBeforeSchema = z.enum([
  "race_distance_never",
  "race_distance_once",
  "race_distance_2_to_3",
  "race_distance_4_plus",
]);

const PainLevelSchema = z.enum([
  "pain_no",
  "pain_mild",
  "pain_moderate",
  "pain_severe",
]);

const InjuryHistorySchema = z.enum([
  "injury_no",
  "injury_once",
  "injury_multiple",
]);

const BinarySchema = z.enum(["yes", "no"]);

const FitnessSourceSchema = z.enum(["strava", "manual"]);

const AcceptedConfidenceSchema = z.enum(["high", "medium", "limited"]);

const PlanIntensitySchema = z.enum(["conservative", "balanced", "ambitious"]);

const StrengthCategorySchema = z.enum([
  "lower_body",
  "upper_body",
  "core_mobility",
  "full_body",
]);

const SameDayOrderSchema = z.enum([
  "run_first",
  "lift_first",
  "separate_sessions",
  "it_depends",
]);

const RaceCourseTerrainSchema = z.enum([
  "flat",
  "rolling",
  "hilly",
  "not_sure",
]);

const StravaTerrainSchema = z.enum(["flat", "rolling", "hilly", "notSure"]);

const DATE_ONLY_REGEX = /^\d{4}-\d{2}-\d{2}$/;

const isCalendarDateOnly = (value: string): boolean => {
  if (!DATE_ONLY_REGEX.test(value)) {
    return false;
  }

  const [year, month, day] = value
    .split("-")
    .map((part) => Number.parseInt(part, 10));
  const parsed = new Date(Date.UTC(year, month - 1, day));

  return (
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day
  );
};

const EvidencePointSchema = z.object({
  metric: z.string(),
  date: z.string(),
  value: z.number(),
  unit: z.string(),
}).strict();

const EvidenceListSchema = z.array(EvidencePointSchema);

const StravaProvenanceSchema = z.object({
  source: z.string(),
  syncedAt: z.string(),
  dataWindow: z.string(),
  dataFromDate: z.string(),
  dataThroughDate: z.string(),
  activityCount: z.number().int().nonnegative(),
  runActivityCount: z.number().int().nonnegative(),
  confidence: AcceptedConfidenceSchema,
}).strict();

const StravaGuardrailSchema = z.object({
  priority: z.number().int().min(0).max(3),
  category: z.string(),
  message: z.string(),
}).strict();

const StravaRaceTargetSchema = z.object({
  distanceKm: z.number().positive(),
  primaryTimeSec: z.number().int().positive(),
  stretchTimeSec: z.number().int().positive().optional(),
  confidence: AcceptedConfidenceSchema,
  evidence: EvidenceListSchema.default([]),
}).strict().superRefine((value, ctx) => {
  if (value.stretchTimeSec != null && value.stretchTimeSec <= 0) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "stravaCoachingProfile.raceTargets.stretchTimeSec must be > 0 when present.",
      path: ["stretchTimeSec"],
    });
  }
});

const StravaPlanFocusSchema = z.object({
  category: z.string(),
  summary: z.string(),
}).strict();

const StravaPaceZoneInputSchema = z.object({
  paceMinSecPerKm: z.number().int().positive().optional(),
  paceMaxSecPerKm: z.number().int().positive().optional(),
}).strict().superRefine((zone, ctx) => {
  if (
    zone.paceMinSecPerKm != null &&
    zone.paceMaxSecPerKm != null &&
    zone.paceMinSecPerKm > zone.paceMaxSecPerKm
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "paceMinSecPerKm must be <= paceMaxSecPerKm.",
      path: ["paceMinSecPerKm"],
    });
  }
});

const StravaPaceZoneSchema = z.object({
  paceMinSecPerKm: z.number().int().positive(),
  paceMaxSecPerKm: z.number().int().positive(),
}).strict().refine(
  (zone) => zone.paceMinSecPerKm <= zone.paceMaxSecPerKm,
  {
    message: "paceMinSecPerKm must be <= paceMaxSecPerKm.",
    path: ["paceMinSecPerKm"],
  },
);

const StravaPaceZonesInputSchema = z.object({
  recovery: StravaPaceZoneInputSchema.optional(),
  easy: StravaPaceZoneInputSchema.optional(),
  longRun: StravaPaceZoneInputSchema.optional(),
  steady: StravaPaceZoneInputSchema.optional(),
  tempo: StravaPaceZoneInputSchema.optional(),
  threshold: StravaPaceZoneInputSchema.optional(),
  racePace: StravaPaceZoneInputSchema.optional(),
  intervals: StravaPaceZoneInputSchema.optional(),
  strides: StravaPaceZoneInputSchema.optional(),
}).strict().default({});

export const StravaCoachingProfileInputSchema = z.object({
  dataConfidence: AcceptedConfidenceSchema,
  terrain: StravaTerrainSchema.optional(),
  provenance: StravaProvenanceSchema.optional(),
  trainingBase: EvidenceListSchema.default([]),
  endurance: EvidenceListSchema.default([]),
  speedMarkers: EvidenceListSchema.default([]),
  recoveryGuardrails: z.array(StravaGuardrailSchema).default([]),
  raceTargets: z.array(StravaRaceTargetSchema).default([]),
  planFocus: StravaPlanFocusSchema.optional(),
  paceZones: StravaPaceZonesInputSchema.default({}),
}).strict();

const AcceptedRaceTargetSchema = z.object({
  distanceKm: z.number().positive(),
  primaryTimeMs: z.number().int().positive(),
  stretchTimeMs: z.number().int().positive().optional(),
  confidence: AcceptedConfidenceSchema.optional(),
  evidence: EvidenceListSchema.default([]),
}).strict().superRefine((value, ctx) => {
  if (value.stretchTimeMs != null && value.stretchTimeMs <= 0) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "acceptedRaceTarget.stretchTimeMs must be > 0 when present.",
      path: ["stretchTimeMs"],
    });
  }
});

const GoalProfileSchema = z.object({
  race: GoalRaceSchema,
  hasRaceDate: z.boolean(),
  raceDate: z.string().optional(),
}).strict().superRefine((value, ctx) => {
  if (value.hasRaceDate && !value.raceDate) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "goal.raceDate is required when goal.hasRaceDate is true.",
      path: ["raceDate"],
    });
  }
});

const ScheduleProfileSchema = z.object({
  trainingDays: z.number().int().min(1).max(7),
  longRunDay: WeekdaySchema,
  weekdayTime: TimeSlotSchema,
  weekendTime: TimeSlotSchema,
  hardDays: z.array(WeekdaySchema),
  preferredTimeOfDay: PreferredTimeOfDaySchema.optional(),
  planStartDate: z.string().refine(isCalendarDateOnly, {
    message: "schedule.planStartDate must be a valid YYYY-MM-DD date.",
  }).optional(),
});

const HealthProfileSchema = z.object({
  painLevel: PainLevelSchema,
  injuryHistory: InjuryHistorySchema,
  hasHealthConditions: BinarySchema,
});

const ManualFitnessInputSchema = z.object({
  experience: ExperienceSchema,
  weeklyVolume: WeeklyVolumeSchema.optional(),
  longestRun: LongestRunSchema.optional(),
  canCompleteGoalDistance: TernarySchema.optional(),
  raceDistanceBefore: RaceDistanceBeforeSchema.optional(),
  benchmark: BenchmarkSchema.optional(),
  benchmarkTimeMs: z.number().int().positive().optional(),
}).superRefine((value, ctx) => {
  if (
    value.benchmark != null &&
    value.benchmark !== "benchmark_skip" &&
    value.benchmarkTimeMs == null
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "manualFitness.benchmarkTimeMs is required when benchmark is not benchmark_skip.",
      path: ["benchmarkTimeMs"],
    });
  }

  if (value.benchmark === "benchmark_skip" && value.benchmarkTimeMs != null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "manualFitness.benchmarkTimeMs must be omitted when benchmark is benchmark_skip.",
      path: ["benchmarkTimeMs"],
    });
  }
});

const StrengthPreferencesSchema = z.object({
  lifts: z.boolean(),
  weeklyFrequency: z.number().int().nonnegative().optional(),
  categories: z.array(StrengthCategorySchema),
  preferredDays: z.array(WeekdaySchema),
  sameDayOrder: SameDayOrderSchema.optional(),
});

export const ProfessionalPlanInputSchema = z.object({
  goal: GoalProfileSchema,
  fitnessSource: FitnessSourceSchema,
  stravaCoachingProfile: StravaCoachingProfileInputSchema.optional(),
  manualFitness: ManualFitnessInputSchema.optional(),
  acceptedRaceTarget: AcceptedRaceTargetSchema,
  schedule: ScheduleProfileSchema,
  health: HealthProfileSchema,
  strengthPreferences: StrengthPreferencesSchema,
  planIntensity: PlanIntensitySchema,
  unitPreference: z.string().optional(),
  locale: LocaleSchema,
  raceCourseTerrain: RaceCourseTerrainSchema.optional(),
}).strict().superRefine((input, ctx) => {
  if (input.fitnessSource === "manual") {
    if (input.manualFitness == null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "manual source requires manualFitness.",
        path: ["manualFitness"],
      });
    }
    if (input.stravaCoachingProfile != null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "manual source cannot include stravaCoachingProfile.",
        path: ["stravaCoachingProfile"],
      });
    }
    return;
  }

  if (input.stravaCoachingProfile == null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "strava source requires stravaCoachingProfile.",
      path: ["stravaCoachingProfile"],
    });
  }

  if (
    input.manualFitness != null &&
    input.stravaCoachingProfile != null &&
    (input.stravaCoachingProfile as Record<string, unknown>).dataConfidence ===
      "high"
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "high-confidence Strava data cannot include manualFitness.",
      path: ["manualFitness"],
    });
  }
});

export const GeneratePlanRequestSchema = z.object({
  requestedBy: z.string().default("onboarding"),
  locale: LocaleSchema.default("en"),
  professionalPlanInput: ProfessionalPlanInputSchema.optional(),
}).strict();

export function removeSessionsOnRaceDate<T extends { date: string }>(
  sessions: readonly T[],
  raceDate: string | null | undefined,
): T[] {
  if (typeof raceDate !== "string" || raceDate.length === 0) {
    return [...sessions];
  }

  const targetDate = raceDate.slice(0, 10);
  if (!targetDate) return [...sessions];

  return sessions.filter((session) => session.date.slice(0, 10) !== targetDate);
}

export const SessionTypeSchema = z.enum([
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
]);

export const TargetZoneSchema = z.enum([
  "recovery",
  "easy",
  "steady",
  "tempo",
  "threshold",
  "interval",
  "racePace",
  "longRun",
]);

const PaceValueSchema = z.number().int().positive();

const PaceZoneSchema = z.object({
  paceMinSecPerKm: PaceValueSchema,
  paceMaxSecPerKm: PaceValueSchema,
}).strict().superRefine((zone, ctx) => {
  if (zone.paceMinSecPerKm > zone.paceMaxSecPerKm) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "paceMinSecPerKm must be <= paceMaxSecPerKm.",
      path: ["paceMinSecPerKm"],
    });
  }
});

export const WorkoutTargetSchema = z.object({
  schemaVersion: z.number().int().positive(),
  type: z.enum(["pace", "effort", "heartRate"]),
  zone: TargetZoneSchema,
  paceMinSecPerKm: PaceValueSchema,
  paceMaxSecPerKm: PaceValueSchema,
  effortCue: z.string().optional(),
}).superRefine((target, ctx) => {
  if (
    target.paceMinSecPerKm != null &&
    target.paceMaxSecPerKm != null &&
    target.paceMinSecPerKm > target.paceMaxSecPerKm
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "paceMinSecPerKm must be <= paceMaxSecPerKm.",
      path: ["paceMinSecPerKm"],
    });
  }
});

const requireWorkoutTargetForRunSessions = (
  session: { [key: string]: unknown },
  ctx: z.RefinementCtx,
) => {
  const type = typeof session.type === "string" ? session.type : "";
  if (type === "crossTraining" || type === "restDay" || type === "raceDay") {
    return;
  }
  if (session.workoutTarget == null) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "workoutTarget is required for run sessions (easy, long, quality, threshold, and recovery sessions).",
      path: ["workoutTarget"],
    });
  }
};

export const GeneratedSessionSchema = z.object({
  id: z.string(),
  date: z.string(),
  weekNumber: z.number().int().min(1),
  type: SessionTypeSchema,
  phase: z.enum(["base", "build", "specific", "peak", "taperRace"]).nullable()
    .optional(),
  distanceKm: z.number().nullable(),
  durationMinutes: z.number().int().nullable(),
  coachNote: z.string().nullable(),
  targetZone: TargetZoneSchema.nullable(),
  warmUpMinutes: z.number().int().nullable(),
  coolDownMinutes: z.number().int().nullable(),
  intervalReps: z.number().int().nullable(),
  intervalRepDistanceMeters: z.number().int().nullable(),
  intervalRecoverySeconds: z.number().int().nullable(),
  strideReps: z.number().int().nullable(),
  strideSeconds: z.number().int().nullable(),
  strideRecoverySeconds: z.number().int().nullable(),
  workoutTarget: WorkoutTargetSchema.nullable().optional(),
}).superRefine(requireWorkoutTargetForRunSessions);

const RepairedGeneratedSessionSchema = z.object({
  id: z.string(),
  date: z.string(),
  weekNumber: z.number().int().min(1),
  type: SessionTypeSchema,
  phase: z.enum(["base", "build", "specific", "peak", "taperRace"]).nullable()
    .optional(),
  distanceKm: z.number().nullable(),
  durationMinutes: z.number().int().nullable(),
  coachNote: z.string().nullable(),
  targetZone: TargetZoneSchema.nullable(),
  warmUpMinutes: z.number().int().nullable(),
  coolDownMinutes: z.number().int().nullable(),
  intervalReps: z.number().int().nullable(),
  intervalRepDistanceMeters: z.number().int().nullable(),
  intervalRecoverySeconds: z.number().int().nullable(),
  strideReps: z.number().int().nullable(),
  strideSeconds: z.number().int().nullable(),
  strideRecoverySeconds: z.number().int().nullable(),
  workoutTarget: WorkoutTargetSchema,
}).strict().superRefine(requireWorkoutTargetForRunSessions);

const TargetedSessionRepairItemSchema = z.object({
  sessionId: z.string(),
  repairedSession: RepairedGeneratedSessionSchema,
}).strict();

export const TargetedSessionRepairResponseSchema = z.object({
  schemaVersion: z.number().int().positive(),
  sessions: z.array(TargetedSessionRepairItemSchema).min(1),
}).strict();

export type TargetedSessionRepairItem = z.infer<
  typeof TargetedSessionRepairItemSchema
>;
export type TargetedSessionRepairResponse = z.infer<
  typeof TargetedSessionRepairResponseSchema
>;

export const StravaPaceZonesSchema = z.object({
  recovery: PaceZoneSchema,
  easy: PaceZoneSchema,
  longRun: PaceZoneSchema,
  steady: PaceZoneSchema,
  tempo: PaceZoneSchema,
  threshold: PaceZoneSchema,
  racePace: PaceZoneSchema,
  intervals: PaceZoneSchema,
  strides: PaceZoneSchema,
}).strict();

export const RaceGuidanceSchema = z.object({
  schemaVersion: z.number().int().positive(),
  raceDayExecution: z.string(),
  warmup: z.string().nullable().optional(),
  primaryTargetSec: z.number().int().positive().nullable().optional(),
  stretchTargetSec: z.number().int().positive().nullable().optional(),
  splitPlan: z.string().nullable().optional(),
  whenToPress: z.string().nullable().optional(),
  whatToAvoid: z.string().nullable().optional(),
  coachingNotes: z.string().nullable().optional(),
  sleepNotes: z.string().nullable().optional(),
  fuelingNotes: z.string().nullable().optional(),
  hydrationNotes: z.string().nullable().optional(),
  taperReminders: z.string().nullable().optional(),
  weatherCourseNotes: z.string().nullable().optional(),
});

export const StravaCoachingProfileSnapshotSchema = z.object({
  dataConfidence: AcceptedConfidenceSchema,
  terrain: StravaTerrainSchema.optional(),
  provenance: StravaProvenanceSchema.optional(),
  trainingBase: EvidenceListSchema.optional(),
  endurance: EvidenceListSchema.optional(),
  speedMarkers: EvidenceListSchema.optional(),
  recoveryGuardrails: z.array(StravaGuardrailSchema).optional(),
  raceTargets: z.array(StravaRaceTargetSchema).optional(),
  planFocus: StravaPlanFocusSchema.optional(),
  paceZones: StravaPaceZonesSchema.partial().optional(),
}).strict();

const CoachingPhaseSchema = z.enum([
  "base",
  "build",
  "specific",
  "peak",
  "taperRace",
  "safeBuild",
  "unsupportedFallback",
]);

const ReadinessLevelSchema = z.enum([
  "raceReady",
  "prepared",
  "developing",
  "underprepared",
  "unsupported",
]);

const CoachingSourceSchema = z.enum(["strava", "manual", "mixed", "unknown"]);

const PhaseStrategySchema = z.object({
  phase: CoachingPhaseSchema,
  weeks: z.number().int().nonnegative(),
  focus: z.string(),
}).strict();

const CoachingTargetSchema = z.object({
  distanceKm: z.number().positive().nullable(),
  timeSec: z.number().int().positive().nullable(),
  paceSecPerKm: z.number().int().positive().nullable(),
  confidence: AcceptedConfidenceSchema,
  source: CoachingSourceSchema,
  supported: z.boolean(),
  reason: z.string(),
}).strict();

const CoachingTaperSchema = z.object({
  weeks: z.number().int().min(1),
  volumeReductionPercent: z.number().nonnegative(),
  finalWeekFocus: z.string(),
}).strict();

export const CoachingBriefSnapshotSchema = z.object({
  raceType: z.enum([
    "fiveK",
    "tenK",
    "halfMarathon",
    "marathon",
    "other",
  ]),
  readinessLevel: ReadinessLevelSchema,
  confidence: AcceptedConfidenceSchema,
  source: CoachingSourceSchema,
  currentVolumeKmPerWeek: z.number().nonnegative(),
  currentRunsPerWeek: z.number().int().min(1).max(7),
  recentLongRunKm: z.number().nonnegative(),
  planLengthWeeks: z.number().int().min(1).max(26),
  phaseStrategy: z.array(PhaseStrategySchema),
  maxWeeklyVolumeKm: z.number().nonnegative(),
  longRunCeilingKm: z.number().nonnegative(),
  weeklyRunDays: z.number().int().min(1).max(7),
  taper: CoachingTaperSchema,
  workoutEmphasis: z.array(z.string()),
  evidenceTarget: CoachingTargetSchema,
  ambitiousTarget: CoachingTargetSchema,
  constraints: z.array(z.string()),
  rationale: z.array(z.string()),
}).strict();

export const GeneratedPlanSchema = z.object({
  schemaVersion: z.number().int().positive(),
  id: z.string(),
  totalWeeks: z.number().int().min(1).max(26),
  currentWeekNumber: z.number().int().min(1),
  raceType: z.enum([
    "fiveK",
    "tenK",
    "halfMarathon",
    "marathon",
    "other",
  ]),
  generatedLocale: LocaleSchema,
  sessions: z.array(GeneratedSessionSchema),
  paceZones: StravaPaceZonesSchema,
  raceGuidance: RaceGuidanceSchema,
  stravaCoachingProfileSnapshot: StravaCoachingProfileSnapshotSchema,
  coachingBriefSnapshot: CoachingBriefSnapshotSchema.optional(),
  planRationale: z.array(z.string()).optional(),
  evidenceTarget: CoachingTargetSchema.optional(),
  ambitiousTarget: CoachingTargetSchema.optional(),
  confidence: AcceptedConfidenceSchema.optional(),
  phaseStrategy: z.array(PhaseStrategySchema).optional(),
}).strict();

const coachingTargetJsonSchema = {
  type: "object",
  properties: {
    distanceKm: { type: ["number", "null"], minimum: 0 },
    timeSec: { type: ["integer", "null"], minimum: 1 },
    paceSecPerKm: { type: ["integer", "null"], minimum: 1 },
    confidence: { type: "string", enum: ["high", "medium", "limited"] },
    source: { type: "string", enum: ["strava", "manual", "mixed", "unknown"] },
    supported: { type: "boolean" },
    reason: { type: "string" },
  },
  required: [
    "distanceKm",
    "timeSec",
    "paceSecPerKm",
    "confidence",
    "source",
    "supported",
    "reason",
  ],
  additionalProperties: false,
};

const phaseStrategyJsonSchema = {
  type: "object",
  properties: {
    phase: {
      type: "string",
      enum: [
        "base",
        "build",
        "specific",
        "peak",
        "taperRace",
        "safeBuild",
        "unsupportedFallback",
      ],
    },
    weeks: { type: "integer", minimum: 0 },
    focus: { type: "string" },
  },
  required: ["phase", "weeks", "focus"],
  additionalProperties: false,
};

const coachingBriefSnapshotJsonSchema = {
  type: "object",
  properties: {
    raceType: {
      type: "string",
      enum: ["fiveK", "tenK", "halfMarathon", "marathon", "other"],
    },
    readinessLevel: {
      type: "string",
      enum: [
        "raceReady",
        "prepared",
        "developing",
        "underprepared",
        "unsupported",
      ],
    },
    confidence: { type: "string", enum: ["high", "medium", "limited"] },
    source: { type: "string", enum: ["strava", "manual", "mixed", "unknown"] },
    currentVolumeKmPerWeek: { type: "number", minimum: 0 },
    currentRunsPerWeek: { type: "integer", minimum: 1, maximum: 7 },
    recentLongRunKm: { type: "number", minimum: 0 },
    planLengthWeeks: { type: "integer", minimum: 1, maximum: 26 },
    phaseStrategy: {
      type: "array",
      items: phaseStrategyJsonSchema,
    },
    maxWeeklyVolumeKm: { type: "number", minimum: 0 },
    longRunCeilingKm: { type: "number", minimum: 0 },
    weeklyRunDays: { type: "integer", minimum: 1, maximum: 7 },
    taper: {
      type: "object",
      properties: {
        weeks: { type: "integer", minimum: 1 },
        volumeReductionPercent: { type: "number", minimum: 0 },
        finalWeekFocus: { type: "string" },
      },
      required: ["weeks", "volumeReductionPercent", "finalWeekFocus"],
      additionalProperties: false,
    },
    workoutEmphasis: {
      type: "array",
      items: { type: "string" },
    },
    evidenceTarget: coachingTargetJsonSchema,
    ambitiousTarget: coachingTargetJsonSchema,
    constraints: {
      type: "array",
      items: { type: "string" },
    },
    rationale: {
      type: "array",
      items: { type: "string" },
    },
  },
  required: [
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
  ],
  additionalProperties: false,
};

export const trainingPlanResponseJsonSchema = {
  type: "object",
  properties: {
    schemaVersion: { type: "integer", minimum: 1 },
    id: { type: "string" },
    totalWeeks: { type: "integer", minimum: 1, maximum: 26 },
    currentWeekNumber: { type: "integer", minimum: 1 },
    raceType: {
      type: "string",
      enum: ["fiveK", "tenK", "halfMarathon", "marathon", "other"],
    },
    generatedLocale: { type: "string", enum: ["en", "es"] },
    sessions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: { type: "string" },
          date: { type: "string" },
          weekNumber: { type: "integer", minimum: 1 },
          type: {
            type: "string",
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
            ],
          },
          phase: {
            type: ["string", "null"],
            enum: ["base", "build", "specific", "peak", "taperRace", null],
          },
          distanceKm: { type: ["number", "null"] },
          durationMinutes: { type: ["integer", "null"] },
          coachNote: { type: ["string", "null"] },
          targetZone: {
            type: ["string", "null"],
            enum: [
              "recovery",
              "easy",
              "steady",
              "tempo",
              "threshold",
              "interval",
              "racePace",
              "longRun",
              null,
            ],
          },
          warmUpMinutes: { type: ["integer", "null"], minimum: 0 },
          coolDownMinutes: { type: ["integer", "null"], minimum: 0 },
          intervalReps: { type: ["integer", "null"], minimum: 0 },
          intervalRepDistanceMeters: { type: ["integer", "null"], minimum: 0 },
          intervalRecoverySeconds: { type: ["integer", "null"], minimum: 0 },
          strideReps: { type: ["integer", "null"], minimum: 0 },
          strideSeconds: { type: ["integer", "null"], minimum: 1 },
          strideRecoverySeconds: { type: ["integer", "null"], minimum: 1 },
          workoutTarget: {
            type: ["object", "null"],
            properties: {
              schemaVersion: { type: "integer", minimum: 1 },
              type: {
                type: "string",
                enum: ["pace", "effort", "heartRate"],
              },
              zone: {
                type: "string",
                enum: [
                  "recovery",
                  "easy",
                  "steady",
                  "tempo",
                  "threshold",
                  "interval",
                  "racePace",
                  "longRun",
                ],
              },
              paceMinSecPerKm: { type: "integer", minimum: 1 },
              paceMaxSecPerKm: { type: "integer", minimum: 1 },
              effortCue: { type: "string" },
            },
            required: [
              "schemaVersion",
              "type",
              "zone",
              "paceMinSecPerKm",
              "paceMaxSecPerKm",
              "effortCue",
            ],
            additionalProperties: false,
          },
        },
        required: [
          "id",
          "date",
          "weekNumber",
          "type",
          "distanceKm",
          "durationMinutes",
          "coachNote",
          "targetZone",
          "phase",
          "warmUpMinutes",
          "coolDownMinutes",
          "intervalReps",
          "intervalRepDistanceMeters",
          "intervalRecoverySeconds",
          "strideReps",
          "strideSeconds",
          "strideRecoverySeconds",
          "workoutTarget",
        ],
        additionalProperties: false,
      },
    },
    paceZones: {
      type: "object",
      properties: {
        recovery: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        easy: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        longRun: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        steady: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        tempo: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        threshold: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        racePace: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        intervals: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
        strides: {
          type: "object",
          properties: {
            paceMinSecPerKm: { type: "integer", minimum: 1 },
            paceMaxSecPerKm: { type: "integer", minimum: 1 },
          },
          required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
          additionalProperties: false,
        },
      },
      required: [
        "recovery",
        "easy",
        "longRun",
        "steady",
        "tempo",
        "threshold",
        "racePace",
        "intervals",
        "strides",
      ],
      additionalProperties: false,
    },
    raceGuidance: {
      type: "object",
      properties: {
        schemaVersion: { type: "integer", minimum: 1 },
        raceDayExecution: { type: "string" },
        warmup: { type: ["string", "null"] },
        primaryTargetSec: { type: ["integer", "null"], minimum: 1 },
        stretchTargetSec: { type: ["integer", "null"], minimum: 1 },
        splitPlan: { type: ["string", "null"] },
        whenToPress: { type: ["string", "null"] },
        whatToAvoid: { type: ["string", "null"] },
        coachingNotes: { type: ["string", "null"] },
        sleepNotes: { type: ["string", "null"] },
        fuelingNotes: { type: ["string", "null"] },
        hydrationNotes: { type: ["string", "null"] },
        taperReminders: { type: ["string", "null"] },
        weatherCourseNotes: { type: ["string", "null"] },
      },
      required: [
        "schemaVersion",
        "raceDayExecution",
        "warmup",
        "primaryTargetSec",
        "stretchTargetSec",
        "splitPlan",
        "whenToPress",
        "whatToAvoid",
        "coachingNotes",
        "sleepNotes",
        "fuelingNotes",
        "hydrationNotes",
        "taperReminders",
        "weatherCourseNotes",
      ],
      additionalProperties: false,
    },
    coachingBriefSnapshot: coachingBriefSnapshotJsonSchema,
    planRationale: {
      type: "array",
      items: { type: "string" },
    },
    evidenceTarget: coachingTargetJsonSchema,
    ambitiousTarget: coachingTargetJsonSchema,
    confidence: { type: "string", enum: ["high", "medium", "limited"] },
    phaseStrategy: {
      type: "array",
      items: phaseStrategyJsonSchema,
    },
    stravaCoachingProfileSnapshot: {
      type: "object",
      required: [
        "dataConfidence",
        "terrain",
        "provenance",
        "trainingBase",
        "endurance",
        "speedMarkers",
        "recoveryGuardrails",
        "raceTargets",
        "planFocus",
        "paceZones",
      ],
      properties: {
        dataConfidence: { type: "string", enum: ["high", "medium", "limited"] },
        terrain: {
          type: "string",
          enum: ["flat", "rolling", "hilly", "notSure"],
        },
        provenance: {
          type: "object",
          properties: {
            source: { type: "string" },
            syncedAt: { type: "string" },
            dataWindow: { type: "string" },
            dataFromDate: { type: "string" },
            dataThroughDate: { type: "string" },
            activityCount: { type: "integer", minimum: 0 },
            runActivityCount: { type: "integer", minimum: 0 },
            confidence: {
              type: "string",
              enum: ["high", "medium", "limited"],
            },
          },
          required: [
            "source",
            "syncedAt",
            "dataWindow",
            "dataFromDate",
            "dataThroughDate",
            "activityCount",
            "runActivityCount",
            "confidence",
          ],
          additionalProperties: false,
        },
        trainingBase: {
          type: "array",
          items: {
            type: "object",
            properties: {
              metric: { type: "string" },
              date: { type: "string" },
              value: { type: "number" },
              unit: { type: "string" },
            },
            required: ["metric", "date", "value", "unit"],
            additionalProperties: false,
          },
        },
        endurance: {
          type: "array",
          items: {
            type: "object",
            properties: {
              metric: { type: "string" },
              date: { type: "string" },
              value: { type: "number" },
              unit: { type: "string" },
            },
            required: ["metric", "date", "value", "unit"],
            additionalProperties: false,
          },
        },
        speedMarkers: {
          type: "array",
          items: {
            type: "object",
            properties: {
              metric: { type: "string" },
              date: { type: "string" },
              value: { type: "number" },
              unit: { type: "string" },
            },
            required: ["metric", "date", "value", "unit"],
            additionalProperties: false,
          },
        },
        recoveryGuardrails: {
          type: "array",
          items: {
            type: "object",
            properties: {
              priority: { type: "integer", minimum: 0, maximum: 3 },
              category: { type: "string" },
              message: { type: "string" },
            },
            required: ["priority", "category", "message"],
            additionalProperties: false,
          },
        },
        raceTargets: {
          type: "array",
          items: {
            type: "object",
            properties: {
              distanceKm: { type: "number", minimum: 0 },
              primaryTimeSec: { type: "integer", minimum: 1 },
              stretchTimeSec: { type: "integer", minimum: 1 },
              confidence: {
                type: "string",
                enum: ["high", "medium", "limited"],
              },
              evidence: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    metric: { type: "string" },
                    date: { type: "string" },
                    value: { type: "number" },
                    unit: { type: "string" },
                  },
                  required: ["metric", "date", "value", "unit"],
                  additionalProperties: false,
                },
              },
            },
            required: [
              "distanceKm",
              "primaryTimeSec",
              "stretchTimeSec",
              "confidence",
              "evidence",
            ],
            additionalProperties: false,
          },
        },
        planFocus: {
          type: "object",
          properties: {
            category: { type: "string" },
            summary: { type: "string" },
          },
          required: ["category", "summary"],
          additionalProperties: false,
        },
        paceZones: {
          type: "object",
          required: [
            "recovery",
            "easy",
            "longRun",
            "steady",
            "tempo",
            "threshold",
            "racePace",
            "intervals",
            "strides",
          ],
          properties: {
            recovery: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            easy: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            longRun: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            steady: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            tempo: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            threshold: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            racePace: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            intervals: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
            strides: {
              type: "object",
              properties: {
                paceMinSecPerKm: { type: "integer", minimum: 1 },
                paceMaxSecPerKm: { type: "integer", minimum: 1 },
              },
              required: ["paceMinSecPerKm", "paceMaxSecPerKm"],
              additionalProperties: false,
            },
          },
          additionalProperties: false,
        },
      },
      additionalProperties: false,
    },
  },
  required: [
    "schemaVersion",
    "id",
    "totalWeeks",
    "currentWeekNumber",
    "raceType",
    "generatedLocale",
    "sessions",
    "paceZones",
    "raceGuidance",
    "coachingBriefSnapshot",
    "planRationale",
    "evidenceTarget",
    "ambitiousTarget",
    "confidence",
    "phaseStrategy",
    "stravaCoachingProfileSnapshot",
  ],
  additionalProperties: false,
};

export const targetedSessionRepairResponseJsonSchema = {
  type: "object",
  properties: {
    schemaVersion: { type: "integer", minimum: 1 },
    sessions: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        properties: {
          sessionId: { type: "string" },
          repairedSession: {
            ...(trainingPlanResponseJsonSchema
              .properties as {
                sessions: { items: Record<string, unknown> };
              }).sessions.items,
            properties: {
              ...(trainingPlanResponseJsonSchema
                .properties as {
                  sessions: { items: { properties: Record<string, unknown> } };
                }).sessions.items.properties,
              workoutTarget: {
                ...(trainingPlanResponseJsonSchema
                  .properties as {
                    sessions: {
                      items: {
                        properties: { workoutTarget: Record<string, unknown> };
                      };
                    };
                  }).sessions.items.properties.workoutTarget,
                type: "object",
              },
            },
          },
        },
        required: ["sessionId", "repairedSession"],
        additionalProperties: false,
      },
    },
  },
  required: ["schemaVersion", "sessions"],
  additionalProperties: false,
};

export type GeneratePlanRequest = z.infer<typeof GeneratePlanRequestSchema>;
export type ProfessionalPlanInput = z.infer<typeof ProfessionalPlanInputSchema>;
export type GeneratedSession = z.infer<typeof GeneratedSessionSchema>;
export type GeneratedPlan = z.infer<typeof GeneratedPlanSchema>;
