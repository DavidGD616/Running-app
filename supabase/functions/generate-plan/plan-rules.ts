import type { GeneratedSession } from "./schema.ts";

type RacePrepPhase = "base" | "build" | "specific" | "peak" | "taperRace";

type PeakLongRunRange = {
  minKm: number;
  targetKm: number;
  maxKm: number;
};

export function peakLongRunRangeKm(
  profileData: Record<string, unknown>,
): PeakLongRunRange {
  const race = raceFromProfile(profileData);
  const experience = experienceFromProfile(profileData);

  switch (race) {
    case "race_5k":
      switch (experience) {
        case "experience_beginner":
          return { minKm: 3, targetKm: 5, maxKm: 7 };
        case "experience_intermediate":
          return { minKm: 6, targetKm: 9, maxKm: 12 };
        case "experience_experienced":
          return { minKm: 8, targetKm: 11, maxKm: 14 };
      }
      break;
    case "race_10k":
      switch (experience) {
        case "experience_beginner":
          return { minKm: 6, targetKm: 9, maxKm: 12 };
        case "experience_intermediate":
          return { minKm: 10, targetKm: 12.5, maxKm: 15 };
        case "experience_experienced":
          return { minKm: 11, targetKm: 14.5, maxKm: 18 };
      }
      break;
    case "race_half_marathon":
      switch (experience) {
        case "experience_beginner":
          return { minKm: 11, targetKm: 14.5, maxKm: 18 };
        case "experience_intermediate":
          return { minKm: 14, targetKm: 17, maxKm: 20 };
        case "experience_experienced":
          return { minKm: 16, targetKm: 19.5, maxKm: 23 };
      }
      break;
    case "race_marathon":
      switch (experience) {
        case "experience_beginner":
          return { minKm: 24, targetKm: 27, maxKm: 30 };
        case "experience_intermediate":
          return { minKm: 28, targetKm: 31, maxKm: 34 };
        case "experience_experienced":
          return { minKm: 30, targetKm: 33, maxKm: 36 };
      }
      break;
  }

  return { minKm: 5, targetKm: 10, maxKm: 15 };
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
): GeneratedSession[] {
  const race = raceFromProfile(profileData);
  const experience = experienceFromProfile(profileData);
  const raceDate = goalRaceDate(profileData);

  return sessions.map((session) => {
    if (session.type === "restDay") return session;
    if (isGoalRaceSession(session, profileData)) return session;

    const phase = phaseForWeek(session.weekNumber, totalWeeks, profileData);
    const policy = workoutPolicyForPhase(phase, race, experience);

    if (policy.allowedTypes.includes(session.type)) return session;

    const replacement = nearestAllowedType(session.type, policy.allowedTypes);
    return withDowngradedType(session, replacement, locale);
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
  if (experience === "experience_beginner") {
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
  raceType: string,
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

export function normalizeTrainingDayCount(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
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
        locale,
      )
    )
    .sort(compareSessionsByDate);
}

export function ensureFullCalendarWeeks(
  sessions: GeneratedSession[],
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const sessionsByWeek = new Map<number, GeneratedSession[]>();
  for (const session of sessions) {
    const weekSessions = sessionsByWeek.get(session.weekNumber) ?? [];
    weekSessions.push({ ...session });
    sessionsByWeek.set(session.weekNumber, weekSessions);
  }

  return Array.from(sessionsByWeek.keys())
    .sort((a, b) => a - b)
    .flatMap((weekNumber) =>
      fillWeekRestDays(sessionsByWeek.get(weekNumber) ?? [], locale)
    )
    .sort(compareSessionsByDate);
}

export function ensureGoalRaceSession(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const distanceKm = goalRaceDistanceKm(profileData);
  if (distanceKm == null) return sessions;

  const adjusted = sessions.map((session) => ({ ...session })).sort(
    compareSessionsByDate,
  );
  const raceDate = goalRaceDate(profileData);
  if (raceDate != null) {
    const raceIndex = adjusted.findIndex((session) =>
      session.date.slice(0, 10) === raceDate
    );
    if (raceIndex < 0) return adjusted;
    adjusted[raceIndex] = toGoalRaceSession(
      adjusted[raceIndex],
      distanceKm,
      locale,
    );
    return adjusted.sort(compareSessionsByDate);
  }

  const finalWeek = Math.max(...adjusted.map((session) => session.weekNumber));
  if (!Number.isFinite(finalWeek)) return adjusted;

  const finalWeekSessions = adjusted.filter((session) =>
    session.weekNumber === finalWeek
  );
  if (finalWeekSessions.length === 0) return adjusted;

  const targetDate = preferredGoalRaceDate(finalWeekSessions, profileData);
  const targetIndex = adjusted.findIndex((session) =>
    session.weekNumber === finalWeek &&
    session.date.slice(0, 10) === targetDate
  );
  if (targetIndex < 0) return adjusted;

  adjusted[targetIndex] = toGoalRaceSession(
    adjusted[targetIndex],
    distanceKm,
    locale,
  );

  return adjusted.sort(compareSessionsByDate);
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
        locale,
      )
    )
    .sort(compareSessionsByDate);
}

function fillWeekRestDays(
  sessions: GeneratedSession[],
  locale: CoachNoteLocale,
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
  const template = adjusted[0];

  for (let dayOffset = 0; dayOffset < 7; dayOffset += 1) {
    const date = new Date(weekStart);
    date.setUTCDate(weekStart.getUTCDate() + dayOffset);
    const dateKey = date.toISOString().slice(0, 10);
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

    const date = findMissingWeekDate(adjusted, hardDays);
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

function goalRaceDistanceKm(
  profileData: Record<string, unknown>,
): number | null {
  const goal = objectOrNull(profileData.goal);
  const race = typeof goal?.race === "string" ? goal.race : null;

  switch (race) {
    case "race_5k":
      return 5;
    case "race_10k":
      return 10;
    case "race_half_marathon":
      return 21.1;
    case "race_marathon":
      return 42.2;
    default:
      return null;
  }
}

function preferredGoalRaceDate(
  finalWeekSessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): string {
  const preferredDay = preferredLongRunDayFor(profileData);
  const hardDays = hardDaySetFor(profileData);
  const sorted = [...finalWeekSessions].sort(compareSessionsByDate);

  if (preferredDay != null && !hardDays.has(preferredDay)) {
    const preferredSession = sorted.find((session) =>
      dayKeyForDate(session.date) === preferredDay
    );
    if (preferredSession != null) return preferredSession.date.slice(0, 10);
  }

  const racePaceSession = sorted.findLast((session) =>
    session.type === "racePaceRun" && !hardDays.has(dayKeyForDate(session.date))
  );
  if (racePaceSession != null) return racePaceSession.date.slice(0, 10);

  const longRunSession = sorted.findLast((session) =>
    session.type === "longRun" && !hardDays.has(dayKeyForDate(session.date))
  );
  if (longRunSession != null) return longRunSession.date.slice(0, 10);

  const trainingSession = sorted.findLast((session) =>
    isTrainingDay(session) && !hardDays.has(dayKeyForDate(session.date))
  );
  if (trainingSession != null) return trainingSession.date.slice(0, 10);

  const nonHardDay = sorted.findLast((session) =>
    !hardDays.has(dayKeyForDate(session.date))
  );
  return (nonHardDay ?? sorted[sorted.length - 1]).date.slice(0, 10);
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

function toGoalRaceSession(
  session: GeneratedSession,
  distanceKm: number,
  locale: CoachNoteLocale,
): GeneratedSession {
  return {
    ...session,
    type: "racePaceRun",
    distanceKm,
    durationMinutes: null,
    coachNote: trainingDayCue("goalRace", locale),
    targetZone: "racePace",
    warmUpMinutes: goalRaceWarmUpMinutes(distanceKm),
    coolDownMinutes: goalRaceCoolDownMinutes(distanceKm),
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    strideReps: null,
    strideSeconds: null,
    strideRecoverySeconds: null,
  };
}

function goalRaceWarmUpMinutes(distanceKm: number): number | null {
  if (distanceKm <= 10) return 10;
  return null;
}

function goalRaceCoolDownMinutes(distanceKm: number): number | null {
  if (distanceKm <= 10) return 5;
  return null;
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
  locale: CoachNoteLocale,
): GeneratedSession[] {
  const adjusted = sessions.map((session) => {
    const sanitized = sanitizeStrideValues(session);
    if (isRaceWeek || !isStridePlacementEligible(sanitized, hardDays)) {
      return withoutStrides(sanitized);
    }
    return sanitized;
  }).sort(compareSessionsByDate);

  if (isRaceWeek) return adjusted;

  trimExtraStrideSessions(adjusted, config, hardDays);
  if (config.addDefaults) {
    addMissingStrideSessions(adjusted, config, hardDays, locale);
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
  locale: CoachNoteLocale,
): void {
  while (
    sessions.filter((session) => hasStrides(session)).length <
      config.maxPerWeek
  ) {
    const existing = sessions.filter((session) => hasStrides(session));
    const candidate = sessions
      .filter((session) =>
        !hasStrides(session) && isStridePlacementEligible(session, hardDays)
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
  | "goalRace"
  | "preferredLongRunDay"
  | "movedForSpacing"
  | "restDayAdded"
  | "shortRecoveryAdded"
  | "easyRunAdded"
  | "adjustedForSpacing"
  | "adjustedForPhase"
  | "peakLongRunNormalized"
  | "strideAdded"
  | "movedAwayFromHardDay";

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
    goalRace: {
      en:
        "Goal race day. Run the full target distance by effort: controlled early, steady through the middle, strong at the finish.",
      es:
        "Día de carrera objetivo. Corre la distancia completa por esfuerzo: controlado al inicio, constante en la parte media y fuerte al final.",
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

export function normalizePeakLongRun(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
  locale: CoachNoteLocale = "en",
): GeneratedSession[] {
  const range = peakLongRunRangeKm(profileData);
  const peakWeeks = new Set(
    Array.from({ length: totalWeeks }, (_, i) => i + 1)
      .filter((w) => phaseForWeek(w, totalWeeks, profileData) === "peak"),
  );

  const adjusted = sessions.map((session) => ({ ...session }));
  let bestPeakLongRun: { index: number; distanceKm: number } | null = null;

  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (session.type !== "longRun") continue;
    if (!peakWeeks.has(session.weekNumber)) continue;
    if (isGoalRaceSession(session, profileData)) continue;

    const currentDistance = session.distanceKm ?? 0;
    if (bestPeakLongRun == null || currentDistance > bestPeakLongRun.distanceKm) {
      bestPeakLongRun = { index: i, distanceKm: currentDistance };
    }
  }

  if (bestPeakLongRun == null) return sessions;

  const targetDistance = range.targetKm;
  const currentDistance = bestPeakLongRun.distanceKm;
  const finalDistance = Math.max(range.minKm, Math.min(range.maxKm, targetDistance));

  const wasRaised = currentDistance < targetDistance;
  const cue = wasRaised
    ? locale === "en"
      ? "Peak long run raised to target."
      : "Tirada larga máxima aumentada al objetivo."
    : "Peak long run capped to safe maximum.";

  adjusted[bestPeakLongRun.index] = {
    ...adjusted[bestPeakLongRun.index],
    distanceKm: finalDistance,
    coachNote: appendTrainingDayCue(
      adjusted[bestPeakLongRun.index].coachNote,
      cue,
    ),
  };

  return adjusted;
}
