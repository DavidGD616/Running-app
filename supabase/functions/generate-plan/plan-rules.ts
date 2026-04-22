import type { GeneratedSession } from "./schema.ts";

export function normalizeTrainingDayCount(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): GeneratedSession[] {
  const targetTrainingDays = targetTrainingDaysFor(profileData);
  if (targetTrainingDays == null) return sessions;

  const hardDays = hardDaySetFor(profileData);
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
      )
    )
    .sort(compareSessionsByDate);
}

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

function normalizeWeekTrainingDays(
  sessions: GeneratedSession[],
  targetTrainingDays: number,
  hardDays: Set<string>,
  profileData: Record<string, unknown>,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );

  while (trainingDayCount(adjusted) > targetTrainingDays) {
    const index = findSessionToRest(adjusted, profileData);
    if (index == null) break;
    adjusted[index] = toRestDay(adjusted[index]);
  }

  while (trainingDayCount(adjusted) < targetTrainingDays) {
    const restIndex = findRestDayToTrain(adjusted, hardDays);
    if (restIndex != null) {
      adjusted[restIndex] = toEasyTrainingDay(adjusted[restIndex], hardDays);
      continue;
    }

    const date = findMissingWeekDate(adjusted, hardDays);
    if (date == null) break;
    adjusted.push(createEasyTrainingDay(adjusted[0], date, hardDays));
    adjusted.sort(compareSessionsByDate);
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

function trainingDayCount(sessions: GeneratedSession[]): number {
  return sessions.filter((session) => isTrainingDay(session)).length;
}

function isTrainingDay(session: GeneratedSession): boolean {
  return session.type !== "restDay";
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
    case "crossTraining":
      return 0;
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

function toRestDay(session: GeneratedSession): GeneratedSession {
  return {
    ...session,
    type: "restDay",
    distanceKm: null,
    durationMinutes: null,
    coachNote: appendTrainingDayCue(
      session.coachNote,
      "Rest day added to match your selected training days.",
    ),
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
): GeneratedSession {
  const isHardDay = hardDays.has(dayKeyForDate(session.date));
  return {
    ...session,
    type: isHardDay ? "recoveryRun" : "easyRun",
    distanceKm: null,
    durationMinutes: isHardDay ? 25 : 35,
    coachNote: appendTrainingDayCue(
      session.coachNote,
      isHardDay
        ? "Short recovery run added because your selected schedule is tight."
        : "Easy run added to match your selected training days.",
    ),
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

function createEasyTrainingDay(
  template: GeneratedSession,
  date: string,
  hardDays: Set<string>,
): GeneratedSession {
  return toEasyTrainingDay({
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
  }, hardDays);
}

function findMissingWeekDate(
  sessions: GeneratedSession[],
  hardDays: Set<string>,
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
  }).filter((date) => !existingDates.has(date));

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
