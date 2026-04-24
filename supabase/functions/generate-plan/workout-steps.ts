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

export function buildWorkoutSteps(
  session: GeneratedSession,
): WorkoutStepJson[] {
  if (session.type === "restDay") return [];

  const zone = session.targetZone;
  const target = zone ? { type: "effort", zone } : null;

  const steps: WorkoutStepJson[] = [];
  const strideReps = positiveInt(session.strideReps);
  const strideSeconds = positiveInt(session.strideSeconds);
  const strideRecoverySeconds = positiveInt(session.strideRecoverySeconds) ??
    75;
  const hasStrides = strideReps != null && strideSeconds != null;
  const strideBlockSeconds = hasStrides
    ? strideReps * (strideSeconds + strideRecoverySeconds)
    : 0;

  if (session.warmUpMinutes) {
    steps.push({
      kind: "warmUp",
      target: { type: "effort", zone: "easy" },
      durationMs: session.warmUpMinutes * 60_000,
    });
  }

  if (session.intervalReps && session.intervalRepDistanceMeters) {
    steps.push({
      kind: "repeat",
      repetitions: session.intervalReps,
      steps: [
        {
          kind: "work",
          target,
          distanceMeters: session.intervalRepDistanceMeters,
        },
        {
          kind: "recovery",
          target: { type: "effort", zone: "recovery" },
          durationMs: (session.intervalRecoverySeconds ?? 90) * 1000,
        },
      ],
    });
  } else if (target) {
    const mainDurationMinutes = mainWorkMinutes(session, strideBlockSeconds);
    steps.push({
      kind: "work",
      target,
      durationMs: mainDurationMinutes != null
        ? mainDurationMinutes * 60_000
        : null,
      distanceMeters: mainDurationMinutes == null && session.distanceKm != null
        ? Math.round(session.distanceKm * 1000)
        : null,
    });
  }

  if (hasStrides) {
    steps.push({
      kind: "repeat",
      repetitions: strideReps,
      steps: [
        {
          kind: "stride",
          target: { type: "effort", zone: "interval" },
          durationMs: strideSeconds * 1000,
        },
        {
          kind: "recovery",
          target: { type: "effort", zone: "recovery" },
          durationMs: strideRecoverySeconds * 1000,
        },
      ],
    });
  }

  if (session.coolDownMinutes) {
    steps.push({
      kind: "coolDown",
      target: { type: "effort", zone: "easy" },
      durationMs: session.coolDownMinutes * 60_000,
    });
  }

  return steps;
}

function mainWorkMinutes(
  session: GeneratedSession,
  extraStructuredSeconds: number,
): number | null {
  if (session.durationMinutes == null) return null;
  const warmUp = session.warmUpMinutes ?? 0;
  const coolDown = session.coolDownMinutes ?? 0;
  const extraMinutes = Math.ceil(extraStructuredSeconds / 60);
  return Math.max(
    1,
    session.durationMinutes - warmUp - coolDown - extraMinutes,
  );
}

function positiveInt(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value) || value <= 0) return null;
  return Math.floor(value);
}
