import type { GeneratedSession } from "./schema.ts";

type StepKind =
  | "warmUp"
  | "work"
  | "recovery"
  | "coolDown"
  | "repeat"
  | "stride";

interface WorkoutStepJson {
  kind: StepKind;
  target?: { type: string; zone: string } | null;
  durationMs?: number | null;
  distanceMeters?: number | null;
  repetitions?: number | null;
  steps?: WorkoutStepJson[];
}

type TargetZone =
  | "recovery"
  | "easy"
  | "steady"
  | "tempo"
  | "threshold"
  | "interval"
  | "racePace"
  | "longRun";

const ONE_SECOND_MS = 1_000;
const ONE_MINUTE_MS = 60_000;
const MIN_WORKOUT_MINUTES = 1;
const DEFAULT_RECOVERY_SECONDS = 90;
const DEFAULT_STRIDE_RECOVERY_SECONDS = 75;
const PROGRESSION_ZONES: readonly TargetZone[] = ["easy", "steady", "tempo"];

export function buildWorkoutSteps(
  session: GeneratedSession,
): WorkoutStepJson[] {
  if (session.type === "restDay" || session.type === "raceDay") {
    return [];
  }

  const steps: WorkoutStepJson[] = [];
  const strideReps = positiveInt(session.strideReps);
  const strideSeconds = positiveInt(session.strideSeconds);
  const strideRecoverySeconds = positiveInt(session.strideRecoverySeconds) ??
    DEFAULT_STRIDE_RECOVERY_SECONDS;
  const hasStrides = strideReps != null && strideSeconds != null;
  const strideBlockSeconds = hasStrides
    ? strideReps * (strideSeconds + strideRecoverySeconds)
    : 0;
  const mainDistanceMeters = distanceMetersFromKm(session.distanceKm);
  const warmUpMinutes = positiveInt(session.warmUpMinutes);
  const coolDownMinutes = positiveInt(session.coolDownMinutes);

  if (warmUpMinutes != null) {
    steps.push({
      kind: "warmUp",
      target: makeTarget("easy"),
      durationMs: warmUpMinutes * ONE_MINUTE_MS,
    });
  }

  if (
    session.type === "intervals" ||
    session.type === "hillRepeats" ||
    session.type === "fartlek"
  ) {
    appendIntervalOrQualityBlock(
      steps,
      session,
      strideBlockSeconds,
      session.type === "intervals"
        ? "interval"
        : session.type === "hillRepeats"
        ? "threshold"
        : "tempo",
      mainDistanceMeters,
    );
  } else if (
    session.type === "easyRun" ||
    session.type === "recoveryRun" ||
    session.type === "longRun"
  ) {
    appendSingleWorkBlock(
      steps,
      session.type === "recoveryRun"
        ? resolveTargetZone(session, "recovery")
        : session.type === "longRun"
        ? resolveTargetZone(session, "longRun")
        : resolveTargetZone(session, "easy"),
      mainWorkMinutes(session, strideBlockSeconds),
      mainDistanceMeters,
    );
  } else if (session.type === "progressionRun") {
    const rawMainMinutes = mainWorkMinutes(session, strideBlockSeconds);
    const mainMinutes = rawMainMinutes == null
      ? null
      : Math.max(PROGRESSION_ZONES.length, rawMainMinutes);
    const durationBuckets = mainMinutes == null
      ? null
      : splitIntoThreeParts(mainMinutes);
    const distanceBuckets = mainMinutes == null && mainDistanceMeters != null
      ? splitIntoThreeParts(mainDistanceMeters)
      : null;

    for (let index = 0; index < PROGRESSION_ZONES.length; index++) {
      appendSingleWorkBlock(
        steps,
        PROGRESSION_ZONES[index],
        durationBuckets?.[index] ?? null,
        distanceBuckets?.[index] ?? null,
      );
    }
  } else if (
    session.type === "tempoRun" ||
    session.type === "thresholdRun" ||
    session.type === "racePaceRun"
  ) {
    appendSingleWorkBlock(
      steps,
      session.type === "tempoRun"
        ? resolveTargetZone(session, "tempo")
        : session.type === "thresholdRun"
        ? resolveTargetZone(session, "threshold")
        : resolveTargetZone(session, "racePace"),
      mainWorkMinutes(session, strideBlockSeconds),
      mainDistanceMeters,
    );
  }

  if (hasStrides) {
    steps.push({
      kind: "repeat",
      repetitions: strideReps,
      steps: [
        {
          kind: "stride",
          target: makeTarget("interval"),
          durationMs: strideSeconds * ONE_SECOND_MS,
        },
        {
          kind: "recovery",
          target: makeTarget("recovery"),
          durationMs: strideRecoverySeconds * ONE_SECOND_MS,
        },
      ],
    });
  }

  if (coolDownMinutes != null) {
    steps.push({
      kind: "coolDown",
      target: makeTarget("easy"),
      durationMs: coolDownMinutes * ONE_MINUTE_MS,
    });
  }

  return steps;
}

function appendIntervalOrQualityBlock(
  steps: WorkoutStepJson[],
  session: GeneratedSession,
  strideBlockSeconds: number,
  fallbackZone: TargetZone,
  distanceMeters: number | null,
): void {
  const intervalReps = positiveInt(session.intervalReps);
  const intervalRepDistanceMeters = positiveInt(
    session.intervalRepDistanceMeters,
  );

  if (intervalReps != null && intervalRepDistanceMeters != null) {
    steps.push({
      kind: "repeat",
      repetitions: intervalReps,
      steps: [
        {
          kind: "work",
          target: makeTarget(resolveTargetZone(session, fallbackZone)),
          distanceMeters: intervalRepDistanceMeters,
        },
        {
          kind: "recovery",
          target: makeTarget("recovery"),
          durationMs: (positiveInt(session.intervalRecoverySeconds) ??
            DEFAULT_RECOVERY_SECONDS) * ONE_SECOND_MS,
        },
      ],
    });
    return;
  }

  appendSingleWorkBlock(
    steps,
    resolveTargetZone(session, fallbackZone),
    mainWorkMinutes(session, strideBlockSeconds),
    distanceMeters,
  );
}

function appendSingleWorkBlock(
  steps: WorkoutStepJson[],
  zone: TargetZone,
  durationMinutes: number | null,
  distanceMeters: number | null,
): void {
  steps.push({
    kind: "work",
    target: makeTarget(zone),
    durationMs: durationMinutes != null
      ? durationMinutes * ONE_MINUTE_MS
      : null,
    distanceMeters: durationMinutes == null ? distanceMeters ?? null : null,
  });
}

function makeTarget(zone: TargetZone): { type: string; zone: TargetZone } {
  return { type: "effort", zone };
}

function resolveTargetZone(
  session: GeneratedSession,
  fallbackZone: TargetZone,
): TargetZone {
  return session.targetZone == null ? fallbackZone : session.targetZone;
}

function mainWorkMinutes(
  session: GeneratedSession,
  extraStructuredSeconds: number,
): number | null {
  if (session.durationMinutes == null) return null;
  const warmUp = positiveInt(session.warmUpMinutes) ?? 0;
  const coolDown = positiveInt(session.coolDownMinutes) ?? 0;
  const extraMinutes = Math.ceil(extraStructuredSeconds / 60);
  return Math.max(
    MIN_WORKOUT_MINUTES,
    session.durationMinutes - warmUp - coolDown - extraMinutes,
  );
}

function distanceMetersFromKm(distanceKm: number | null): number | null {
  if (distanceKm == null) return null;
  return Math.round(distanceKm * 1000);
}

function splitIntoThreeParts(total: number): [number, number, number] {
  const base = Math.floor(total / 3);
  const remainder = total % 3;
  const first = base + (remainder > 0 ? 1 : 0);
  const second = base + (remainder > 1 ? 1 : 0);
  const third = total - first - second;
  return [first, second, third];
}

function positiveInt(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value) || value <= 0) return null;
  return Math.floor(value);
}
