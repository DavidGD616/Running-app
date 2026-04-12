import type { GeneratedSession } from './schema.ts';

type StepKind = 'warmUp' | 'work' | 'recovery' | 'coolDown' | 'repeat';

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
  guidanceType: 'effort' | 'pace' | 'heartRate',
): WorkoutStepJson[] {
  const zone = session.targetZone;
  if (!zone) return [];
  const target = zone ? { type: guidanceType, zone } : null;

  const steps: WorkoutStepJson[] = [];

  if (session.warmUpMinutes) {
    steps.push({
      kind: 'warmUp',
      target: { type: guidanceType, zone: 'easy' },
      durationMs: session.warmUpMinutes * 60_000,
    });
  }

  if (session.intervalReps && session.intervalRepDistanceMeters) {
    steps.push({
      kind: 'repeat',
      repetitions: session.intervalReps,
      steps: [
        {
          kind: 'work',
          target,
          distanceMeters: session.intervalRepDistanceMeters,
        },
        {
          kind: 'recovery',
          target: { type: guidanceType, zone: 'recovery' },
          durationMs: (session.intervalRecoverySeconds ?? 90) * 1000,
        },
      ],
    });
  } else if (zone) {
    steps.push({
      kind: 'work',
      target,
      durationMs: (session.durationMinutes ?? 30) * 60_000,
    });
  }

  if (session.coolDownMinutes) {
    steps.push({
      kind: 'coolDown',
      target: { type: guidanceType, zone: 'easy' },
      durationMs: session.coolDownMinutes * 60_000,
    });
  }

  return steps;
}
