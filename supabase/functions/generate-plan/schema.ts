import { z } from 'zod';

export const GeneratedSessionSchema = z.object({
  id: z.string(),
  date: z.string(),               // ISO 8601 date
  weekNumber: z.number().int().min(1),
  type: z.enum([
    'easyRun', 'longRun', 'progressionRun',
    'intervals', 'hillRepeats', 'fartlek',
    'tempoRun', 'thresholdRun', 'racePaceRun',
    'recoveryRun', 'crossTraining', 'restDay',
  ]),
  distanceKm: z.number().nullable(),
  durationMinutes: z.number().int().nullable(),
  coachNote: z.string().nullable(),
  targetZone: z.enum([
    'recovery', 'easy', 'steady', 'tempo',
    'threshold', 'interval', 'racePace', 'longRun',
  ]).nullable(),
  warmUpMinutes: z.number().int().nullable(),
  coolDownMinutes: z.number().int().nullable(),
  intervalReps: z.number().int().nullable(),
  intervalRepDistanceMeters: z.number().int().nullable(),
  intervalRecoverySeconds: z.number().int().nullable(),
  strideReps: z.number().int().nullable(),
  strideSeconds: z.number().int().nullable(),
  strideRecoverySeconds: z.number().int().nullable(),
});

export const GeneratedPlanSchema = z.object({
  totalWeeks: z.number().int().min(4).max(26),
  raceType: z.enum(['fiveK', 'tenK', 'halfMarathon', 'marathon', 'other']),
  sessions: z.array(GeneratedSessionSchema),
});

export type GeneratedSession = z.infer<typeof GeneratedSessionSchema>;
export type GeneratedPlan = z.infer<typeof GeneratedPlanSchema>;
