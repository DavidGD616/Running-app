import type { GeneratedSession } from "./schema.ts";

export function addStrideDefaults(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
): GeneratedSession[] {
  const config = strideConfigFor(profileData);
  if (config == null) return sessions;
  const hardDays = hardDaySetFor(profileData);

  const weeksWithStrides = new Set<number>();
  for (const session of sessions) {
    if (hasStrides(session)) weeksWithStrides.add(session.weekNumber);
  }

  return sessions.map((session) => {
    if (
      !isStrideEligible(session, config, totalWeeks, weeksWithStrides, hardDays)
    ) {
      return session;
    }

    weeksWithStrides.add(session.weekNumber);
    return {
      ...session,
      strideReps: config.reps,
      strideSeconds: config.seconds,
      strideRecoverySeconds: config.recoverySeconds,
      coachNote: appendStrideCue(session.coachNote),
    };
  });
}

export function avoidHardDayTraining(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
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
    adjusted[i] = withScheduleNote({ ...session, date: swapSession.date });
    adjusted[swapIndex] = { ...swapSession, date: session.date };
  }

  return adjusted;
}

type StrideConfig = {
  startWeek: number;
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
      return { startWeek: 1, reps: 6, seconds: 20, recoverySeconds: 80 };
    case "experience_intermediate":
      return { startWeek: 1, reps: 4, seconds: 20, recoverySeconds: 90 };
    default:
      return null;
  }
}

function isStrideEligible(
  session: GeneratedSession,
  config: StrideConfig,
  totalWeeks: number,
  weeksWithStrides: Set<number>,
  hardDays: Set<string>,
): boolean {
  if (weeksWithStrides.has(session.weekNumber)) return false;
  if (session.weekNumber < config.startWeek) return false;
  if (session.weekNumber > Math.max(1, totalWeeks - 2)) return false;
  if (session.type !== "easyRun") return false;
  if (hardDays.has(dayKeyForDate(session.date))) return false;
  if (hasStrides(session)) return false;
  if ((session.durationMinutes ?? 0) < 25) return false;
  return true;
}

function hasStrides(session: GeneratedSession): boolean {
  return (session.strideReps ?? 0) > 0 && (session.strideSeconds ?? 0) > 0;
}

function appendStrideCue(coachNote: string | null): string {
  const strideCue =
    "Finish with relaxed strides: fast but smooth, not a sprint.";
  if (!coachNote) return strideCue;
  if (coachNote.toLowerCase().includes("stride")) return coachNote;
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
  return new Set(
    hardDays.filter((day): day is string =>
      typeof day === "string" && day.startsWith("day_")
    ),
  );
}

function dayKeyForDate(date: string): string {
  const [year, month, day] = date.slice(0, 10).split("-").map(Number);
  if (!year || !month || !day) return "";

  const dayIndex = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
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
  return ["restDay", "recoveryRun", "easyRun", "crossTraining"].includes(
    session.type,
  );
}

function sessionSwapScore(session: GeneratedSession): number {
  switch (session.type) {
    case "restDay":
      return 0;
    case "recoveryRun":
      return 1;
    case "easyRun":
      return 2;
    case "crossTraining":
      return 3;
    default:
      return 4;
  }
}

function withScheduleNote(session: GeneratedSession): GeneratedSession {
  const scheduleCue = "Moved away from a day you marked hard to train.";
  const coachNote = session.coachNote;
  if (!coachNote) return { ...session, coachNote: scheduleCue };
  if (coachNote.toLowerCase().includes("hard to train")) return session;
  return { ...session, coachNote: `${coachNote} ${scheduleCue}` };
}

function objectOrNull(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
