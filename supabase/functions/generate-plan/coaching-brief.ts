export type StandardRaceType =
  | "fiveK"
  | "tenK"
  | "halfMarathon"
  | "marathon";

export type CoachingRaceType = StandardRaceType | "other";

export type ReadinessLevel =
  | "raceReady"
  | "prepared"
  | "developing"
  | "underprepared"
  | "unsupported";

export type CoachingConfidence = "high" | "medium" | "limited";

export type CoachingSource = "strava" | "manual" | "mixed" | "unknown";

export type CoachingPhase =
  | "base"
  | "build"
  | "specific"
  | "peak"
  | "taperRace"
  | "safeBuild"
  | "unsupportedFallback";

export type PhaseStrategy = {
  phase: CoachingPhase;
  weeks: number;
  focus: string;
};

export type CoachingTarget = {
  distanceKm: number | null;
  timeSec: number | null;
  paceSecPerKm: number | null;
  confidence: CoachingConfidence;
  source: CoachingSource;
  supported: boolean;
  reason: string;
};

export type CoachingTaper = {
  weeks: number;
  volumeReductionPercent: number;
  finalWeekFocus: string;
};

export type CoachingBrief = {
  raceType: CoachingRaceType;
  readinessLevel: ReadinessLevel;
  confidence: CoachingConfidence;
  source: CoachingSource;
  currentVolumeKmPerWeek: number;
  currentRunsPerWeek: number;
  recentLongRunKm: number;
  planLengthWeeks: number;
  phaseStrategy: PhaseStrategy[];
  maxWeeklyVolumeKm: number;
  longRunCeilingKm: number;
  weeklyRunDays: number;
  taper: CoachingTaper;
  workoutEmphasis: string[];
  evidenceTarget: CoachingTarget;
  ambitiousTarget: CoachingTarget;
  constraints: string[];
  rationale: string[];
};

export type BuildCoachingBriefInput = {
  profileData: Record<string, unknown>;
  startDate: Date;
  raceDate: Date | null;
  requestedRaceType?: string | null;
};

type EvidencePoint = {
  metric: string;
  value: number;
  unit?: string;
  date?: string;
};

type ExtractedEvidence = {
  source: CoachingSource;
  confidence: CoachingConfidence;
  volumeKmPerWeek: number | null;
  runsPerWeek: number | null;
  longRunKm: number | null;
  target: CoachingTarget | null;
  rationale: string[];
};

const RACE_DISTANCE_KM: Record<StandardRaceType, number> = {
  fiveK: 5,
  tenK: 10,
  halfMarathon: 21.097,
  marathon: 42.195,
};

const DEFAULT_PLAN_WEEKS: Record<StandardRaceType, number> = {
  fiveK: 8,
  tenK: 10,
  halfMarathon: 14,
  marathon: 18,
};

const READINESS_BASELINES: Record<
  StandardRaceType,
  {
    readyVolume: number;
    preparedVolume: number;
    readyRuns: number;
    preparedRuns: number;
    readyLongRun: number;
    preparedLongRun: number;
    maxVolume: number;
    longRunCeiling: number;
  }
> = {
  fiveK: {
    readyVolume: 18,
    preparedVolume: 10,
    readyRuns: 3,
    preparedRuns: 2,
    readyLongRun: 6,
    preparedLongRun: 4,
    maxVolume: 42,
    longRunCeiling: 12,
  },
  tenK: {
    readyVolume: 28,
    preparedVolume: 18,
    readyRuns: 3,
    preparedRuns: 3,
    readyLongRun: 10,
    preparedLongRun: 7,
    maxVolume: 58,
    longRunCeiling: 18,
  },
  halfMarathon: {
    readyVolume: 38,
    preparedVolume: 26,
    readyRuns: 4,
    preparedRuns: 3,
    readyLongRun: 16,
    preparedLongRun: 12,
    maxVolume: 76,
    longRunCeiling: 24,
  },
  marathon: {
    readyVolume: 58,
    preparedVolume: 38,
    readyRuns: 4,
    preparedRuns: 4,
    readyLongRun: 26,
    preparedLongRun: 20,
    maxVolume: 96,
    longRunCeiling: 34,
  },
};

const WEEKLY_VOLUME_FALLBACK_KM: Record<string, number> = {
  weekly_volume_0: 0,
  weekly_volume_1: 7,
  weekly_volume_2: 13,
  weekly_volume_3: 20.5,
  weekly_volume_4: 28.5,
  weekly_volume_5: 40.5,
  weekly_volume_6: 55,
};

const LONG_RUN_FALLBACK_KM: Record<string, number> = {
  longest_run_0: 0,
  longest_run_1: 3,
  longest_run_2: 6.5,
  longest_run_3: 11,
  longest_run_4: 15,
  longest_run_5: 19,
  longest_run_6: 23,
};

const MIN_PROGRESSION_VOLUME_KM: Record<
  StandardRaceType,
  Partial<Record<ReadinessLevel, number>>
> = {
  fiveK: { underprepared: 8 },
  tenK: { underprepared: 10 },
  halfMarathon: { underprepared: 12 },
  marathon: { underprepared: 14 },
};

export function buildCoachingBrief(
  input: BuildCoachingBriefInput,
): CoachingBrief {
  const raceType = normalizeRaceType(
    input.requestedRaceType ?? raceFromProfile(input.profileData),
  );
  const weeksUntilRace = weeksBetween(input.startDate, input.raceDate);

  const extracted = extractEvidence(input.profileData, raceType);
  const manual = extractManualSnapshot(input.profileData, raceType);
  const source = resolveSource(extracted.source, manual.source);
  const confidence = resolveConfidence(extracted, manual);

  const currentVolumeKmPerWeek = round1(
    extracted.volumeKmPerWeek ?? manual.volumeKmPerWeek ?? 0,
  );
  const currentRunsPerWeek = clampInt(
    Math.round(extracted.runsPerWeek ?? manual.runsPerWeek ?? 3),
    1,
    7,
  );
  const recentLongRunKm = round1(extracted.longRunKm ?? manual.longRunKm ?? 0);
  const weeklyRunDays = clampInt(
    numberFromPath(input.profileData, ["schedule", "trainingDays"]) ??
      currentRunsPerWeek,
    1,
    7,
  );

  if (raceType === "other") {
    return unsupportedBrief({
      source,
      confidence,
      currentVolumeKmPerWeek,
      currentRunsPerWeek,
      recentLongRunKm,
      weeklyRunDays,
      planLengthWeeks: planLengthFor("fiveK", weeksUntilRace),
      rationale: [
        ...extracted.rationale,
        ...manual.rationale,
        "Race type is not one of the standard supported distances.",
      ],
    });
  }

  const planLengthWeeks = planLengthFor(raceType, weeksUntilRace);
  const readinessLevel = readinessFor({
    raceType,
    currentVolumeKmPerWeek,
    currentRunsPerWeek,
    recentLongRunKm,
    weeksUntilRace,
  });
  const taper = taperFor(raceType, planLengthWeeks);
  const phaseStrategy = phaseStrategyFor({
    raceType,
    readinessLevel,
    planLengthWeeks,
    taperWeeks: taper.weeks,
  });
  const constraints = constraintsFor({
    raceType,
    readinessLevel,
    currentVolumeKmPerWeek,
    currentRunsPerWeek,
    recentLongRunKm,
    weeksUntilRace,
  });
  const maxWeeklyVolumeKm = maxWeeklyVolumeFor({
    raceType,
    planLengthWeeks,
    currentVolumeKmPerWeek,
    readinessLevel,
  });
  const longRunCeilingKm = longRunCeilingFor({
    raceType,
    planLengthWeeks,
    recentLongRunKm,
    readinessLevel,
  });
  const evidenceTarget = extracted.target ?? manual.target ??
    noTarget(raceType, confidence, source);
  const ambitiousTarget = ambitiousTargetFor(
    input.profileData,
    raceType,
    evidenceTarget,
    source,
    confidence,
    readinessLevel,
  );

  const rationale = [
    ...extracted.rationale,
    ...manual.rationale,
    `Readiness is ${readinessLevel} from ${currentVolumeKmPerWeek} km/week, ${currentRunsPerWeek} runs/week, and a ${recentLongRunKm} km recent long run.`,
    raceDateRationale(planLengthWeeks, weeksUntilRace, readinessLevel),
  ].filter((value, index, values) =>
    value.length > 0 && values.indexOf(value) === index
  );

  return {
    raceType,
    readinessLevel,
    confidence,
    source,
    currentVolumeKmPerWeek,
    currentRunsPerWeek,
    recentLongRunKm,
    planLengthWeeks,
    phaseStrategy,
    maxWeeklyVolumeKm,
    longRunCeilingKm,
    weeklyRunDays,
    taper,
    workoutEmphasis: workoutEmphasisFor(raceType, readinessLevel),
    evidenceTarget,
    ambitiousTarget,
    constraints,
    rationale,
  };
}

function unsupportedBrief(options: {
  source: CoachingSource;
  confidence: CoachingConfidence;
  currentVolumeKmPerWeek: number;
  currentRunsPerWeek: number;
  recentLongRunKm: number;
  weeklyRunDays: number;
  planLengthWeeks: number;
  rationale: string[];
}): CoachingBrief {
  const evidenceTarget: CoachingTarget = {
    distanceKm: null,
    timeSec: null,
    paceSecPerKm: null,
    confidence: "limited",
    source: options.source,
    supported: false,
    reason: "Custom race distances are not supported by this brief engine.",
  };

  return {
    raceType: "other",
    readinessLevel: "unsupported",
    confidence: options.confidence,
    source: options.source,
    currentVolumeKmPerWeek: options.currentVolumeKmPerWeek,
    currentRunsPerWeek: options.currentRunsPerWeek,
    recentLongRunKm: options.recentLongRunKm,
    planLengthWeeks: options.planLengthWeeks,
    phaseStrategy: [{
      phase: "unsupportedFallback",
      weeks: options.planLengthWeeks,
      focus:
        "Keep training conservative until a standard race distance is selected.",
    }],
    maxWeeklyVolumeKm: round1(Math.max(options.currentVolumeKmPerWeek, 20)),
    longRunCeilingKm: round1(Math.max(options.recentLongRunKm, 8)),
    weeklyRunDays: options.weeklyRunDays,
    taper: {
      weeks: 1,
      volumeReductionPercent: 25,
      finalWeekFocus: "Reduce volume and keep all running comfortable.",
    },
    workoutEmphasis: [
      "easy aerobic running",
      "strides only if already tolerated",
    ],
    evidenceTarget,
    ambitiousTarget: evidenceTarget,
    constraints: [
      "Unsupported race type: use a standard 5K, 10K, half marathon, or marathon brief before prescribing race-specific workouts.",
    ],
    rationale: options.rationale,
  };
}

function normalizeRaceType(value: unknown): CoachingRaceType {
  if (typeof value !== "string") return "other";
  const normalized = value.trim().toLowerCase().replace(/[\s-]+/g, "_");

  if (
    normalized === "5k" ||
    normalized === "fivek" ||
    normalized === "five_k" ||
    normalized === "race_5k"
  ) return "fiveK";
  if (
    normalized === "10k" ||
    normalized === "tenk" ||
    normalized === "ten_k" ||
    normalized === "race_10k"
  ) return "tenK";
  if (
    normalized === "halfmarathon" ||
    normalized === "half_marathon" ||
    normalized === "half" ||
    normalized === "race_half_marathon"
  ) return "halfMarathon";
  if (normalized === "marathon" || normalized === "race_marathon") {
    return "marathon";
  }

  return "other";
}

function raceFromProfile(profileData: Record<string, unknown>): unknown {
  return valueFromPath(profileData, ["goal", "race"]) ??
    valueFromPath(profileData, ["raceType"]) ??
    valueFromPath(profileData, ["race"]);
}

function extractEvidence(
  profileData: Record<string, unknown>,
  raceType: CoachingRaceType,
): ExtractedEvidence {
  const profile = stravaProfile(profileData);
  const evidencePoints = [
    ...evidenceFromProfile(profile),
    ...evidenceFromFutureFields(profileData),
  ];
  const confidence = normalizeConfidence(
    stringFromRecord(profile, "dataConfidence") ??
      stringFromPath(profileData, ["fitness", "dataConfidence"]) ??
      stringFromPath(profileData, ["evidence", "dataConfidence"]),
  );
  const hasStravaProfile = profile != null || evidencePoints.length > 0;

  const volumeKmPerWeek = pickEvidenceValue(evidencePoints, [
    "training_base_weekly_km",
    "weekly_volume_km",
    "weekly_volume",
    "current_volume_km_per_week",
    "currentvolumekmperweek",
  ], ["km_per_week", "km/week"]);
  const runsPerWeek = pickEvidenceValue(evidencePoints, [
    "training_base_runs_per_week",
    "runs_per_week",
    "current_runs_per_week",
    "currentrunsperweek",
  ], ["runs_per_week", "runs/week"]);
  const longRunKm = pickEvidenceValue(evidencePoints, [
    "endurance_long_run_km",
    "longest_recent_run_km",
    "recent_long_run_km",
    "recentlongrunkm",
  ], ["km"]);

  const directVolume = firstNumber([
    numberFromPath(profileData, ["currentVolumeKmPerWeek"]),
    numberFromPath(profileData, ["fitness", "currentVolumeKmPerWeek"]),
    numberFromPath(profileData, [
      "fitness",
      "athleteSummary",
      "weeklyVolumeKm",
    ]),
  ]);
  const directRuns = firstNumber([
    numberFromPath(profileData, ["currentRunsPerWeek"]),
    numberFromPath(profileData, ["fitness", "currentRunsPerWeek"]),
    numberFromPath(profileData, ["fitness", "athleteSummary", "runsPerWeek"]),
  ]);
  const directLongRun = firstNumber([
    numberFromPath(profileData, ["recentLongRunKm"]),
    numberFromPath(profileData, ["fitness", "recentLongRunKm"]),
    numberFromPath(profileData, [
      "fitness",
      "athleteSummary",
      "longestRecentRunKm",
    ]),
  ]);

  const target = raceType === "other" ? null : stravaTarget(profile, raceType);
  const measuredCount = [
    volumeKmPerWeek ?? directVolume,
    runsPerWeek ?? directRuns,
    longRunKm ?? directLongRun,
  ]
    .filter((value) => value != null && value > 0).length;
  const hasMeasuredEvidence = measuredCount > 0;
  const hasStravaTarget = target != null;
  const source: CoachingSource = hasMeasuredEvidence || hasStravaTarget
    ? "strava"
    : "unknown";
  const resolvedConfidence: CoachingConfidence = measuredCount >= 2 &&
      confidence !== "limited"
    ? confidence
    : measuredCount >= 2
    ? "medium"
    : "limited";

  return {
    source,
    confidence: resolvedConfidence,
    volumeKmPerWeek: volumeKmPerWeek ?? directVolume,
    runsPerWeek: runsPerWeek ?? directRuns,
    longRunKm: longRunKm ?? directLongRun,
    target,
    rationale: source === "strava"
      ? [
        `Used measured training evidence from ${measuredCount} available Strava-style metric${
          measuredCount === 1 ? "" : "s"
        }.`,
      ]
      : hasStravaProfile
      ? [
        "Ignored Strava coaching profile confidence because no measured training metrics were available.",
      ]
      : [],
  };
}

function extractManualSnapshot(
  profileData: Record<string, unknown>,
  raceType: CoachingRaceType,
): ExtractedEvidence {
  const manual = objectFromPath(profileData, ["manualFitness"]) ??
    objectFromPath(profileData, ["fitness"]);
  const weeklyVolumeKey = stringFromRecord(manual, "weeklyVolume");
  const longestRunKey = stringFromRecord(manual, "longestRun");
  const volumeKmPerWeek = weeklyVolumeKey == null
    ? null
    : WEEKLY_VOLUME_FALLBACK_KM[weeklyVolumeKey] ?? null;
  const longRunKm = longestRunKey == null
    ? null
    : LONG_RUN_FALLBACK_KM[longestRunKey] ?? null;
  const runsPerWeek = numberFromPath(profileData, ["schedule", "trainingDays"]);
  const target = raceType === "other" ? null : manualTarget(manual, raceType);
  const hasManual = manual != null &&
    (volumeKmPerWeek != null || longRunKm != null || target != null);
  const confidence: CoachingConfidence = target?.confidence === "medium"
    ? "medium"
    : hasManual
    ? "limited"
    : "limited";

  return {
    source: hasManual ? "manual" : "unknown",
    confidence,
    volumeKmPerWeek,
    runsPerWeek,
    longRunKm,
    target,
    rationale: hasManual
      ? [
        target == null
          ? "Used manual training snapshot; no corroborated benchmark was available."
          : "Used manual training snapshot with benchmark-derived target.",
      ]
      : [],
  };
}

function stravaProfile(
  profileData: Record<string, unknown>,
): Record<string, unknown> | null {
  return objectFromPath(profileData, ["stravaCoachingProfile"]) ??
    objectFromPath(profileData, ["fitness", "stravaCoachingProfile"]);
}

function evidenceFromProfile(
  profile: Record<string, unknown> | null,
): EvidencePoint[] {
  if (profile == null) return [];
  return [
    ...evidenceArray(profile.trainingBase),
    ...evidenceArray(profile.endurance),
    ...evidenceArray(profile.speedMarkers),
  ];
}

function evidenceFromFutureFields(
  profileData: Record<string, unknown>,
): EvidencePoint[] {
  return [
    ...evidenceArray(profileData.trainingEvidence),
    ...evidenceArray(profileData.coachingEvidence),
    ...evidenceArray(profileData.backendEvidence),
    ...evidenceArray(profileData.evidence),
    ...evidenceArray(valueFromPath(profileData, ["fitness", "evidence"])),
  ];
}

function evidenceArray(value: unknown): EvidencePoint[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const metric = stringFromRecord(entry, "metric") ??
      stringFromRecord(entry, "name") ??
      stringFromRecord(entry, "key");
    const value = numberFromRecord(entry, "value");
    if (metric == null || value == null) return [];
    return [{
      metric,
      value,
      unit: stringFromRecord(entry, "unit") ?? undefined,
      date: stringFromRecord(entry, "date") ?? undefined,
    }];
  });
}

function pickEvidenceValue(
  points: EvidencePoint[],
  metricNames: string[],
  units: string[],
): number | null {
  const metricSet = new Set(metricNames.map(normalizeMetricName));
  const unitSet = new Set(units.map((unit) => unit.toLowerCase()));
  const candidates = points.filter((point) => {
    const metricMatches = metricSet.has(normalizeMetricName(point.metric));
    const unitMatches = point.unit == null ||
      unitSet.has(point.unit.toLowerCase());
    return metricMatches && unitMatches && point.value >= 0;
  });
  candidates.sort((a, b) => dateMs(b.date) - dateMs(a.date));
  return candidates[0]?.value ?? null;
}

function stravaTarget(
  profile: Record<string, unknown> | null,
  raceType: StandardRaceType,
): CoachingTarget | null {
  if (profile == null || !Array.isArray(profile.raceTargets)) return null;
  const distanceKm = RACE_DISTANCE_KM[raceType];
  const candidates = profile.raceTargets.filter((entry) => {
    if (!isRecord(entry)) return false;
    const candidateDistance = numberFromRecord(entry, "distanceKm");
    return candidateDistance != null &&
      Math.abs(candidateDistance - distanceKm) <= distanceTolerance(distanceKm);
  });
  if (candidates.length === 0) return null;
  const target = candidates[0] as Record<string, unknown>;
  const timeSec = numberFromRecord(target, "primaryTimeSec");
  if (timeSec == null || timeSec <= 0) return null;
  const confidence = normalizeConfidence(
    stringFromRecord(target, "confidence"),
  );
  return {
    distanceKm,
    timeSec,
    paceSecPerKm: Math.round(timeSec / distanceKm),
    confidence,
    source: "strava",
    supported: confidence !== "limited",
    reason: "Race target is backed by Strava-style race-target evidence.",
  };
}

function manualTarget(
  manual: Record<string, unknown> | null,
  raceType: StandardRaceType,
): CoachingTarget | null {
  if (manual == null) return null;
  const benchmark = stringFromRecord(manual, "benchmark");
  const benchmarkTimeMs = numberFromRecord(manual, "benchmarkTimeMs");
  if (
    benchmark == null ||
    benchmark === "benchmark_skip" ||
    benchmarkTimeMs == null ||
    benchmarkTimeMs <= 0
  ) return null;

  const benchmarkDistanceKm = benchmarkDistance(benchmark);
  if (benchmarkDistanceKm == null) return null;
  const raceDistanceKm = RACE_DISTANCE_KM[raceType];
  const timeSec = Math.round(
    riegelSeconds(benchmarkTimeMs / 1000, benchmarkDistanceKm, raceDistanceKm),
  );

  return {
    distanceKm: raceDistanceKm,
    timeSec,
    paceSecPerKm: Math.round(timeSec / raceDistanceKm),
    confidence: "medium",
    source: "manual",
    supported: true,
    reason: benchmarkDistanceKm === raceDistanceKm
      ? "Manual benchmark matches the race distance."
      : "Manual benchmark was converted conservatively to the race distance.",
  };
}

function ambitiousTargetFor(
  profileData: Record<string, unknown>,
  raceType: StandardRaceType,
  evidenceTarget: CoachingTarget,
  source: CoachingSource,
  confidence: CoachingConfidence,
  readinessLevel: ReadinessLevel,
): CoachingTarget {
  const distanceKm = RACE_DISTANCE_KM[raceType];
  const accepted = objectFromPath(profileData, ["acceptedRaceTarget"]);
  const acceptedDistanceKm = numberFromRecord(accepted, "distanceKm");
  const acceptedDistanceMismatched = acceptedDistanceKm != null &&
    Math.abs(acceptedDistanceKm - distanceKm) > distanceTolerance(distanceKm);
  const stretchTimeSec = msOrSecToSec(
    numberFromRecord(accepted, "stretchTimeMs") ??
      numberFromRecord(accepted, "stretchTimeSec"),
  );
  const primaryTimeSec = msOrSecToSec(
    numberFromRecord(accepted, "primaryTimeMs") ??
      numberFromRecord(accepted, "primaryTimeSec"),
  );
  const acceptedTimeSec = acceptedDistanceMismatched
    ? null
    : stretchTimeSec ?? primaryTimeSec;
  const requestedTimeSec = acceptedTimeSec ??
    evidenceTarget.timeSec;

  if (requestedTimeSec == null || requestedTimeSec <= 0) {
    return {
      distanceKm,
      timeSec: null,
      paceSecPerKm: null,
      confidence,
      source,
      supported: false,
      reason: acceptedDistanceMismatched
        ? "Accepted race target distance does not match the requested race distance."
        : "No ambitious race target was provided.",
    };
  }

  const hasEvidence = evidenceTarget.supported &&
    evidenceTarget.timeSec != null;
  const supportedByEvidence = hasEvidence &&
    requestedTimeSec >= evidenceTarget.timeSec! * 0.97 &&
    readinessLevel !== "underprepared";

  return {
    distanceKm,
    timeSec: requestedTimeSec,
    paceSecPerKm: Math.round(requestedTimeSec / distanceKm),
    confidence: supportedByEvidence ? evidenceTarget.confidence : "limited",
    source,
    supported: supportedByEvidence,
    reason: acceptedDistanceMismatched
      ? "Accepted race target distance does not match the requested race; using the evidence target instead."
      : supportedByEvidence
      ? "Ambitious target is within the evidence-supported range."
      : "Ambitious target is not supported by current readiness evidence and should not drive workouts.",
  };
}

function noTarget(
  raceType: StandardRaceType,
  confidence: CoachingConfidence,
  source: CoachingSource,
): CoachingTarget {
  return {
    distanceKm: RACE_DISTANCE_KM[raceType],
    timeSec: null,
    paceSecPerKm: null,
    confidence,
    source,
    supported: false,
    reason: "No corroborated race target evidence was available.",
  };
}

function readinessFor(input: {
  raceType: StandardRaceType;
  currentVolumeKmPerWeek: number;
  currentRunsPerWeek: number;
  recentLongRunKm: number;
  weeksUntilRace: number | null;
}): ReadinessLevel {
  const baseline = READINESS_BASELINES[input.raceType];
  const raceIsNear = input.weeksUntilRace != null && input.weeksUntilRace <= 4;
  const raceIsVeryNear = input.weeksUntilRace != null &&
    input.weeksUntilRace <= 2;

  const ready = input.currentVolumeKmPerWeek >= baseline.readyVolume &&
    input.currentRunsPerWeek >= baseline.readyRuns &&
    input.recentLongRunKm >= baseline.readyLongRun;
  if (ready) return "raceReady";

  const prepared = input.currentVolumeKmPerWeek >= baseline.preparedVolume &&
    input.currentRunsPerWeek >= baseline.preparedRuns &&
    input.recentLongRunKm >= baseline.preparedLongRun;
  if (prepared) return raceIsVeryNear ? "developing" : "prepared";

  const hasSomeBase =
    input.currentVolumeKmPerWeek >= baseline.preparedVolume * 0.5 &&
    input.currentRunsPerWeek >= 2 &&
    input.recentLongRunKm >= baseline.preparedLongRun * 0.5;
  if (hasSomeBase && !raceIsNear) return "developing";

  return "underprepared";
}

function constraintsFor(input: {
  raceType: StandardRaceType;
  readinessLevel: ReadinessLevel;
  currentVolumeKmPerWeek: number;
  currentRunsPerWeek: number;
  recentLongRunKm: number;
  weeksUntilRace: number | null;
}): string[] {
  const constraints: string[] = [];
  const raceDistance = RACE_DISTANCE_KM[input.raceType];
  const nearRace = input.weeksUntilRace != null && input.weeksUntilRace <= 4;

  if (input.readinessLevel === "underprepared") {
    constraints.push(
      "Prioritize completion and safe consistency over the ambitious finish target.",
    );
    constraints.push(
      "Do not prescribe workouts from an unsupported ambitious target.",
    );
  }
  if (nearRace && input.readinessLevel !== "raceReady") {
    constraints.push(
      "Race is too soon for a full build; avoid aggressive volume or long-run jumps.",
    );
  }
  if (input.recentLongRunKm < raceDistance * 0.45) {
    constraints.push(
      "Long-run history is low for the race distance; use run-walk or completion guidance if needed.",
    );
  }
  if (input.currentRunsPerWeek < 3) {
    constraints.push(
      "Keep weekly run frequency conservative until durability improves.",
    );
  }

  return constraints;
}

function planLengthFor(
  raceType: StandardRaceType,
  weeksUntilRace: number | null,
): number {
  if (weeksUntilRace == null) return DEFAULT_PLAN_WEEKS[raceType];
  if (weeksUntilRace <= 0) return 1;
  return clampInt(Math.ceil(weeksUntilRace), 1, DEFAULT_PLAN_WEEKS[raceType]);
}

function phaseStrategyFor(input: {
  raceType: StandardRaceType;
  readinessLevel: ReadinessLevel;
  planLengthWeeks: number;
  taperWeeks: number;
}): PhaseStrategy[] {
  const workingWeeks = Math.max(0, input.planLengthWeeks - input.taperWeeks);
  if (input.readinessLevel === "underprepared") {
    return compactPhases([
      {
        phase: "safeBuild",
        weeks: workingWeeks,
        focus:
          "Build consistency with easy running and conservative long-run progression.",
      },
      taperPhase(input.taperWeeks),
    ]);
  }

  if (input.planLengthWeeks <= 3) {
    return compactPhases([
      {
        phase: "specific",
        weeks: workingWeeks,
        focus: shortSpecificFocus(input.raceType),
      },
      taperPhase(input.taperWeeks),
    ]);
  }

  if (input.planLengthWeeks <= 6) {
    return compactPhases([
      {
        phase: "build",
        weeks: Math.max(1, Math.floor(workingWeeks / 2)),
        focus:
          "Maintain current base while adding one controlled quality stimulus.",
      },
      {
        phase: "specific",
        weeks: Math.max(1, workingWeeks - Math.floor(workingWeeks / 2)),
        focus: specificFocus(input.raceType),
      },
      taperPhase(input.taperWeeks),
    ]);
  }

  const baseWeeks = Math.max(1, Math.floor(input.planLengthWeeks * 0.25));
  const buildWeeks = Math.max(1, Math.floor(input.planLengthWeeks * 0.25));
  const peakWeeks = input.planLengthWeeks >= 10 ? 1 : 0;
  const specificWeeks = Math.max(
    1,
    input.planLengthWeeks - baseWeeks - buildWeeks - peakWeeks -
      input.taperWeeks,
  );

  return compactPhases([
    {
      phase: "base",
      weeks: baseWeeks,
      focus: "Establish durable aerobic volume and relaxed running frequency.",
    },
    {
      phase: "build",
      weeks: buildWeeks,
      focus:
        "Progress volume gradually and introduce controlled threshold work.",
    },
    {
      phase: "specific",
      weeks: specificWeeks,
      focus: specificFocus(input.raceType),
    },
    {
      phase: "peak",
      weeks: peakWeeks,
      focus: "Practice race-specific rhythm while keeping recovery protected.",
    },
    taperPhase(input.taperWeeks),
  ]);
}

function compactPhases(phases: PhaseStrategy[]): PhaseStrategy[] {
  return phases.filter((phase) => phase.weeks > 0);
}

function taperPhase(weeks: number): PhaseStrategy {
  return {
    phase: "taperRace",
    weeks,
    focus: "Reduce volume while keeping light race-specific rhythm.",
  };
}

function taperFor(
  raceType: StandardRaceType,
  planLengthWeeks: number,
): CoachingTaper {
  if (planLengthWeeks <= 1) {
    return {
      weeks: 1,
      volumeReductionPercent: 35,
      finalWeekFocus: "Freshen up; no fitness-building workouts remain.",
    };
  }

  switch (raceType) {
    case "fiveK":
      return {
        weeks: 1,
        volumeReductionPercent: 25,
        finalWeekFocus: "Keep strides sharp and reduce total volume.",
      };
    case "tenK":
      return {
        weeks: 1,
        volumeReductionPercent: 30,
        finalWeekFocus: "Keep one light 10K-rhythm touch and arrive fresh.",
      };
    case "halfMarathon":
      return {
        weeks: planLengthWeeks >= 8 ? 2 : 1,
        volumeReductionPercent: 35,
        finalWeekFocus: "Reduce long-run load and preserve threshold feel.",
      };
    case "marathon":
      return {
        weeks: planLengthWeeks >= 12 ? 3 : planLengthWeeks >= 6 ? 2 : 1,
        volumeReductionPercent: 45,
        finalWeekFocus: "Protect freshness, fueling, sleep, and easy movement.",
      };
  }
}

function maxWeeklyVolumeFor(input: {
  raceType: StandardRaceType;
  planLengthWeeks: number;
  currentVolumeKmPerWeek: number;
  readinessLevel: ReadinessLevel;
}): number {
  const baseline = READINESS_BASELINES[input.raceType];
  const growthFactor = input.readinessLevel === "underprepared"
    ? 1 + Math.min(0.25, input.planLengthWeeks * 0.06)
    : input.planLengthWeeks <= 3
    ? 1.1
    : 1 + Math.min(0.45, input.planLengthWeeks * 0.05);
  const cap = input.readinessLevel === "underprepared"
    ? Math.min(baseline.maxVolume, baseline.preparedVolume * 1.05)
    : baseline.maxVolume;
  const floor = MIN_PROGRESSION_VOLUME_KM[input.raceType][
    input.readinessLevel
  ] ?? 0;

  return round1(
    Math.max(
      input.currentVolumeKmPerWeek,
      Math.min(cap, floor),
      Math.min(cap, input.currentVolumeKmPerWeek * growthFactor),
    ),
  );
}

function longRunCeilingFor(input: {
  raceType: StandardRaceType;
  planLengthWeeks: number;
  recentLongRunKm: number;
  readinessLevel: ReadinessLevel;
}): number {
  const baseline = READINESS_BASELINES[input.raceType];
  const growth = input.readinessLevel === "underprepared"
    ? Math.min(6, input.planLengthWeeks * 1.5)
    : Math.min(8, input.planLengthWeeks * 2);
  const raceCap = input.readinessLevel === "underprepared"
    ? Math.min(baseline.longRunCeiling, baseline.preparedLongRun * 0.9)
    : baseline.longRunCeiling;
  const ceiling = Math.max(
    input.recentLongRunKm,
    Math.min(raceCap, input.recentLongRunKm + growth),
  );
  if (input.readinessLevel === "underprepared") {
    return round1(ceiling);
  }

  const currentBaseAllowance = Math.min(
    Math.max(input.recentLongRunKm, baseline.longRunCeiling),
    baseline.longRunCeiling * 1.25,
  );
  return round1(Math.max(ceiling, currentBaseAllowance));
}

function workoutEmphasisFor(
  raceType: StandardRaceType,
  readinessLevel: ReadinessLevel,
): string[] {
  if (readinessLevel === "underprepared") {
    return [
      "easy aerobic running",
      "safe long-run progression",
      "completion-oriented race preparation",
    ];
  }

  switch (raceType) {
    case "fiveK":
      return ["easy volume", "strides", "VO2 max intervals", "short tempo"];
    case "tenK":
      return [
        "threshold",
        "10K pace intervals",
        "strides",
        "controlled long run",
      ];
    case "halfMarathon":
      return [
        "aerobic volume",
        "tempo",
        "threshold",
        "long-run progression",
      ];
    case "marathon":
      return [
        "aerobic volume",
        "long-run endurance",
        "marathon-pace blocks",
        "fueling practice",
      ];
  }
}

function shortSpecificFocus(raceType: StandardRaceType): string {
  switch (raceType) {
    case "fiveK":
      return "Sharpen with strides and short fast repetitions already supported by current fitness.";
    case "tenK":
      return "Sharpen threshold and 10K rhythm without adding new volume.";
    case "halfMarathon":
      return "Rehearse threshold rhythm and protect the existing long-run base.";
    case "marathon":
      return "Rehearse marathon effort, fueling, and freshness without chasing new endurance.";
  }
}

function specificFocus(raceType: StandardRaceType): string {
  switch (raceType) {
    case "fiveK":
      return "Blend short intervals, strides, and controlled aerobic support.";
    case "tenK":
      return "Progress threshold work and 10K-rhythm intervals.";
    case "halfMarathon":
      return "Extend tempo durability and long-run stamina.";
    case "marathon":
      return "Build long-run endurance, fueling practice, and marathon-pace control.";
  }
}

function raceDateRationale(
  planLengthWeeks: number,
  weeksUntilRace: number | null,
  readinessLevel: ReadinessLevel,
): string {
  if (weeksUntilRace == null) {
    return `No race date was provided, so the brief uses a ${planLengthWeeks}-week standard preparation window.`;
  }
  if (weeksUntilRace <= 4 && readinessLevel === "raceReady") {
    return `Race is in ${weeksUntilRace} week${
      weeksUntilRace === 1 ? "" : "s"
    }, so the plan is sharpening plus taper rather than a generic build.`;
  }
  if (weeksUntilRace <= 4) {
    return `Race is in ${weeksUntilRace} week${
      weeksUntilRace === 1 ? "" : "s"
    }, so the plan protects safety instead of trying to create missing fitness.`;
  }
  return `Race date allows ${planLengthWeeks} week${
    planLengthWeeks === 1 ? "" : "s"
  } of preparation.`;
}

function resolveSource(
  stravaSource: CoachingSource,
  manualSource: CoachingSource,
): CoachingSource {
  if (stravaSource === "strava" && manualSource === "manual") return "mixed";
  if (stravaSource === "strava") return "strava";
  if (manualSource === "manual") return "manual";
  return "unknown";
}

function resolveConfidence(
  extracted: ExtractedEvidence,
  manual: ExtractedEvidence,
): CoachingConfidence {
  if (extracted.source === "strava") return extracted.confidence;
  if (manual.source === "manual") return manual.confidence;
  return "limited";
}

function weeksBetween(startDate: Date, raceDate: Date | null): number | null {
  if (raceDate == null) return null;
  const start = Date.UTC(
    startDate.getUTCFullYear(),
    startDate.getUTCMonth(),
    startDate.getUTCDate(),
  );
  const race = Date.UTC(
    raceDate.getUTCFullYear(),
    raceDate.getUTCMonth(),
    raceDate.getUTCDate(),
  );
  return Math.ceil((race - start) / (7 * 24 * 60 * 60 * 1000));
}

function normalizeConfidence(
  value: string | null | undefined,
): CoachingConfidence {
  if (value === "high" || value === "medium") return value;
  return "limited";
}

function benchmarkDistance(value: string): number | null {
  switch (value) {
    case "benchmark_1km_run":
    case "benchmark_1km_walk":
      return 1;
    case "benchmark_1mi_run":
    case "benchmark_1mi_walk":
      return 1.609;
    case "benchmark_5k":
      return 5;
    case "benchmark_10k":
      return 10;
    case "benchmark_half_marathon":
      return 21.097;
    default:
      return null;
  }
}

function riegelSeconds(
  knownTimeSec: number,
  knownDistanceKm: number,
  targetDistanceKm: number,
): number {
  return knownTimeSec * Math.pow(targetDistanceKm / knownDistanceKm, 1.06);
}

function distanceTolerance(distanceKm: number): number {
  return distanceKm < 15 ? 0.25 : 0.75;
}

function msOrSecToSec(value: number | null): number | null {
  if (value == null) return null;
  return value > 100000 ? Math.round(value / 1000) : Math.round(value);
}

function normalizeMetricName(value: string): string {
  return value.trim().toLowerCase().replace(/[\s-]+/g, "_");
}

function dateMs(value: string | undefined): number {
  if (value == null) return 0;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function firstNumber(values: Array<number | null>): number | null {
  return values.find((value) => value != null && Number.isFinite(value)) ??
    null;
}

function valueFromPath(
  source: Record<string, unknown>,
  path: string[],
): unknown {
  let current: unknown = source;
  for (const segment of path) {
    if (!isRecord(current)) return undefined;
    current = current[segment];
  }
  return current;
}

function objectFromPath(
  source: Record<string, unknown>,
  path: string[],
): Record<string, unknown> | null {
  const value = valueFromPath(source, path);
  return isRecord(value) ? value : null;
}

function stringFromPath(
  source: Record<string, unknown>,
  path: string[],
): string | null {
  const value = valueFromPath(source, path);
  return typeof value === "string" ? value : null;
}

function numberFromPath(
  source: Record<string, unknown>,
  path: string[],
): number | null {
  const value = valueFromPath(source, path);
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringFromRecord(
  source: Record<string, unknown> | null,
  key: string,
): string | null {
  const value = source?.[key];
  return typeof value === "string" ? value : null;
}

function numberFromRecord(
  source: Record<string, unknown> | null,
  key: string,
): number | null {
  const value = source?.[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function clampInt(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}
