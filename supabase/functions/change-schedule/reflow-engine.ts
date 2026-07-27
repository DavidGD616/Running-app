export type JsonObject = Record<string, unknown>;

export type ReflowSameDayPreference =
  | "separate_sessions"
  | "avoid_same_day";

type WeekdayKey = `${1 | 2 | 3 | 4 | 5 | 6 | 7}`;

export type ReflowPlan = JsonObject & {
  sessions: ReflowSession[];
};

export type ReflowCandidatePlan = ReflowPlan;

export type AvailabilityDayConfig = {
  available: boolean;
  maxDurationMinutes: number;
};

export type AvailabilityV2 = Record<WeekdayKey, AvailabilityDayConfig>;

export type ReflowPlanInput = {
  sourcePlan: ReflowPlan;
  availability: AvailabilityV2;
  targetRunningDays: number;
  primaryLongRunDay?: number;
  backupLongRunDay?: number;
  sameDayPreference: ReflowSameDayPreference;
  strengthWeekdays?: number[];
  immutableSessionIds?: string[];
  effectiveFrom: string;
  asOfDate: string;
};

export type ReflowSession = JsonObject & {
  id: string;
  date: string;
  weekNumber: number;
  type: string;
  status?: string;
  phase?: string | null;
  distanceKm?: number | null;
  durationMinutes?: number | null;
  workoutTarget?: JsonObject | null;
};

type ReflowWorkingSession = ReflowSession & {
  _date: Date;
  _weekday: number;
  _weekStart: string;
  _locked: boolean;
};

export type ReflowImpactKey =
  | "move"
  | "long_run_backup"
  | "shortened_for_time_cap"
  | "removed_for_constraints"
  | "split_for_frequency";

export type ReflowWarningKey =
  | "long_run_backup"
  | "shortened_for_time_cap"
  | "removed_for_constraints"
  | "immutable_preserved"
  | "one_run_warning"
  | "constraints_not_fully_supported";

export type ReflowImpact = {
  key: ReflowImpactKey;
  sessionId: string;
  fromDate?: string;
  toDate?: string;
  fromType?: string;
  toType?: string;
  detail?: JsonObject;
};

export type ReflowWeekSummary = {
  weekStart: string;
  beforeRunningDays: number;
  afterRunningDays: number;
  addedRunningDays: number;
  removedRunningDays: number;
};

export type ReflowGoalImpact = {
  targetRunningDays: number;
  totalRunningDaysBefore: number;
  totalRunningDaysAfter: number;
  movedSessions: number;
  shortenedSessions: number;
  removedSessions: number;
  splitSessions: number;
  immutablePreservedSessions: number;
  weekly: ReflowWeekSummary[];
};

export type ReflowResult =
  | {
    ok: true;
    candidatePlan: ReflowCandidatePlan;
    impacts: ReflowImpact[];
    warnings: ReflowWarningKey[];
    goalImpact: ReflowGoalImpact;
  }
  | {
    ok: false;
    reason: string;
  };

const DAY_MS = 24 * 60 * 60 * 1000;
const RUN_TYPES = new Set([
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
]);
// These are the persisted Flutter SessionType names. Non-running entries are
// intentionally accepted and then left immutable by the reflow loop.
const SESSION_TYPES = new Set([
  ...RUN_TYPES,
  "crossTraining",
  "restDay",
  "raceDay",
]);
const QUALITY_TYPES = new Set([
  "progressionRun",
  "intervals",
  "hillRepeats",
  "fartlek",
  "tempoRun",
  "thresholdRun",
  "racePaceRun",
]);
const SESSION_STATUSES = new Set([
  "upcoming",
  "today",
  "completed",
  "skipped",
  "started",
  "active",
]);
const IMMUTABLE_STATUS = new Set(["completed", "skipped", "started", "active"]);

function parseDateOnly(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) return null;

  return parsed.toISOString().slice(0, 10) === value ? parsed : null;
}

function formatDateOnly(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function isoWeekday(value: Date): number {
  const utcDay = value.getUTCDay();
  return utcDay === 0 ? 7 : utcDay;
}

function mondayOf(value: Date): Date {
  const weekday = isoWeekday(value);
  return new Date(value.getTime() - (weekday - 1) * DAY_MS);
}

function addDays(value: Date, days: number): Date {
  return new Date(value.getTime() + days * DAY_MS);
}

function dateOnly(value: string): string {
  return value.slice(0, 10);
}

function round2(value: number): number {
  return Number(value.toFixed(2));
}

function parseWeekday(value: unknown): number | undefined {
  if (typeof value === "number") {
    return Number.isInteger(value) && value >= 1 && value <= 7
      ? value
      : undefined;
  }

  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isInteger(parsed) && parsed >= 1 && parsed <= 7
      ? parsed
      : undefined;
  }

  return undefined;
}

function parseAvailability(
  value: unknown,
): Record<WeekdayKey, AvailabilityDayConfig> | null {
  if (value == null || typeof value !== "object") return null;

  const raw = value as Record<string, unknown>;
  const days: Partial<Record<WeekdayKey, AvailabilityDayConfig>> = {};

  for (const key of ["1", "2", "3", "4", "5", "6", "7"] as const) {
    if (!(key in raw)) return null;
    const entry = raw[key];
    if (entry == null || typeof entry !== "object") return null;

    const entryRecord = entry as Record<string, unknown>;
    const available = entryRecord.available;
    const maxDurationMinutes = entryRecord.maxDurationMinutes;

    if (
      typeof available !== "boolean" ||
      typeof maxDurationMinutes !== "number" ||
      !Number.isInteger(maxDurationMinutes) ||
      maxDurationMinutes < 0
    ) {
      return null;
    }

    days[key as WeekdayKey] = {
      available,
      maxDurationMinutes,
    };
  }

  return days as Record<WeekdayKey, AvailabilityDayConfig>;
}

function isRunType(type: string): boolean {
  return RUN_TYPES.has(type);
}

function isQualityType(type: string): boolean {
  return QUALITY_TYPES.has(type);
}

function runPriority(session: ReflowSession): number {
  if (session.type === "longRun") return 120;
  if (isQualityType(session.type)) {
    return session.phase === "taperRace" ? 105 : 110;
  }
  if (session.type === "easyRun") return 70;
  if (session.type === "recoveryRun") return 60;
  return 50;
}

function removalRank(session: ReflowSession): number {
  if (session.type === "easyRun") return 0;
  if (session.type === "recoveryRun") return 1;
  if (isQualityType(session.type)) {
    return session.phase === "taperRace" ? 500 : 300;
  }
  if (session.type === "longRun") return 1_000;
  return 200;
}

function splitSourceRank(session: ReflowSession): number {
  if (session.type === "easyRun") return 0;
  if (session.type === "recoveryRun") return 1;
  return 100;
}

function getConfig(input: ReflowPlanInput, day: number): AvailabilityDayConfig {
  return input.availability[String(day) as WeekdayKey];
}

function isDayAllowedForRun(input: ReflowPlanInput, day: number): boolean {
  const cfg = getConfig(input, day);
  if (!cfg.available || cfg.maxDurationMinutes <= 0) return false;

  if (
    input.sameDayPreference === "avoid_same_day" &&
    (input.strengthWeekdays ?? []).includes(day)
  ) {
    return false;
  }

  return true;
}

function dayOrderForSession(
  session: ReflowWorkingSession,
  input: ReflowPlanInput,
): number[] {
  const ordered: number[] = [];

  const pushDay = (day: number) => {
    if (!ordered.includes(day)) ordered.push(day);
  };

  if (session.type === "longRun" && input.primaryLongRunDay != null) {
    pushDay(input.primaryLongRunDay);
  }

  if (
    session.type === "longRun" &&
    input.backupLongRunDay != null &&
    input.backupLongRunDay !== input.primaryLongRunDay
  ) {
    pushDay(input.backupLongRunDay);
  }

  pushDay(session._weekday);

  for (let day = 1; day <= 7; day += 1) {
    pushDay(day);
  }

  return ordered;
}

function buildInputErrors(input: unknown): ReflowPlanInput | null {
  if (input == null || typeof input !== "object") return null;

  const body = input as Record<string, unknown>;

  const sourcePlanRecord = body.sourcePlan;
  if (sourcePlanRecord == null || typeof sourcePlanRecord !== "object") {
    return null;
  }
  if (!("sessions" in sourcePlanRecord)) return null;
  const rawSessions = (sourcePlanRecord as { sessions?: unknown }).sessions;
  if (!Array.isArray(rawSessions)) return null;

  const sessions: ReflowSession[] = [];
  for (const raw of rawSessions) {
    if (raw == null || typeof raw !== "object") return null;
    const sessionRecord = raw as Record<string, unknown>;
    const id = sessionRecord.id;
    const date = sessionRecord.date;
    const weekNumber = sessionRecord.weekNumber;
    const type = sessionRecord.type;
    const status = sessionRecord.status;
    if (typeof id !== "string" || id.length === 0) return null;
    if (typeof date !== "string") return null;
    if (parseDateOnly(dateOnly(date)) == null) return null;
    if (
      typeof weekNumber !== "number" || !Number.isInteger(weekNumber) ||
      weekNumber < 1
    ) return null;
    if (typeof type !== "string" || !SESSION_TYPES.has(type)) return null;
    if (
      status != null &&
      (typeof status !== "string" || !SESSION_STATUSES.has(status))
    ) return null;
    if (
      sessionRecord.phase != null && typeof sessionRecord.phase !== "string"
    ) return null;
    if (
      sessionRecord.distanceKm != null &&
      typeof sessionRecord.distanceKm !== "number"
    ) return null;
    if (
      sessionRecord.durationMinutes != null &&
      (typeof sessionRecord.durationMinutes !== "number" ||
        !Number.isInteger(sessionRecord.durationMinutes) ||
        sessionRecord.durationMinutes < 0)
    ) {
      return null;
    }
    sessions.push({
      id,
      date,
      weekNumber,
      type,
      ...(status == null ? {} : { status }),
      ...(sessionRecord.phase == null ? {} : { phase: sessionRecord.phase }),
      ...(sessionRecord.distanceKm == null
        ? {}
        : { distanceKm: sessionRecord.distanceKm }),
      ...(sessionRecord.durationMinutes == null
        ? {}
        : { durationMinutes: sessionRecord.durationMinutes }),
      ...(sessionRecord.workoutTarget == null ? {} : {
        workoutTarget: sessionRecord.workoutTarget as JsonObject,
      }),
      ...(sessionRecord.targetZone == null ? {} : {
        targetZone: sessionRecord.targetZone as JsonObject,
      }),
    });
  }

  const availability = parseAvailability(body.availability);
  if (availability == null) return null;

  const targetRunningDays = Number(body.targetRunningDays);
  if (
    !Number.isInteger(targetRunningDays) ||
    targetRunningDays < 1 ||
    targetRunningDays > 7
  ) {
    return null;
  }

  let primaryLongRunDay: number | undefined;
  if (body.primaryLongRunDay !== undefined) {
    const parsedPrimary = parseWeekday(body.primaryLongRunDay);
    if (parsedPrimary == null) return null;
    primaryLongRunDay = parsedPrimary;
  }

  let backupLongRunDay: number | undefined;
  if (body.backupLongRunDay !== undefined) {
    const parsedBackup = parseWeekday(body.backupLongRunDay);
    if (parsedBackup == null) return null;
    backupLongRunDay = parsedBackup;
  }

  const sameDayPreference = body.sameDayPreference;
  if (
    sameDayPreference !== "separate_sessions" &&
    sameDayPreference !== "avoid_same_day"
  ) {
    return null;
  }

  const effectiveFrom = typeof body.effectiveFrom === "string"
    ? parseDateOnly(dateOnly(body.effectiveFrom))
    : null;
  const asOfDate = typeof body.asOfDate === "string"
    ? parseDateOnly(dateOnly(body.asOfDate))
    : null;
  if (effectiveFrom == null || asOfDate == null) return null;

  let strengthWeekdays: number[] = [];
  if (body.strengthWeekdays != null) {
    if (!Array.isArray(body.strengthWeekdays)) return null;
    for (const raw of body.strengthWeekdays) {
      const day = parseWeekday(raw);
      if (day == null) return null;
      if (!strengthWeekdays.includes(day)) strengthWeekdays.push(day);
    }
  }

  let immutableSessionIds: string[] = [];
  if (body.immutableSessionIds != null) {
    if (!Array.isArray(body.immutableSessionIds)) return null;
    for (const raw of body.immutableSessionIds) {
      if (typeof raw !== "string" || raw.length === 0) return null;
      if (!immutableSessionIds.includes(raw)) immutableSessionIds.push(raw);
    }
  }

  const sourcePlan: ReflowPlan = {
    ...(sourcePlanRecord as ReflowPlan),
    sessions,
  };

  return {
    sourcePlan,
    availability,
    targetRunningDays,
    primaryLongRunDay,
    backupLongRunDay,
    sameDayPreference: sameDayPreference as ReflowSameDayPreference,
    strengthWeekdays,
    immutableSessionIds,
    effectiveFrom: dateOnly(effectiveFrom.toISOString()),
    asOfDate: dateOnly(asOfDate.toISOString()),
  };
}

export function validateReflowInput(
  input: unknown,
): { ok: true; request: ReflowPlanInput } | { ok: false; reason: string } {
  const parsed = buildInputErrors(input);
  if (parsed == null) {
    return { ok: false, reason: "invalid_request" };
  }
  return { ok: true, request: parsed };
}

function toWorkingSessions(plan: ReflowPlan): ReflowWorkingSession[] {
  return plan.sessions.map((session) => {
    const parsedDate = parseDateOnly(dateOnly(session.date))!;

    return {
      ...session,
      _date: parsedDate,
      _weekday: isoWeekday(parsedDate),
      _weekStart: formatDateOnly(mondayOf(parsedDate)),
      _locked: false,
    };
  });
}

function isImmutableSession(
  session: ReflowWorkingSession,
  cutoff: Date,
  immutableIds: Set<string>,
): boolean {
  if (session._date < cutoff) return true;
  if (immutableIds.has(session.id)) return true;
  if (
    typeof session.status === "string" && IMMUTABLE_STATUS.has(session.status)
  ) {
    return true;
  }
  return false;
}

function stripWorkingFields(session: ReflowWorkingSession): ReflowSession {
  const {
    _date: _ignoredDate,
    _weekday: _ignoredWeekday,
    _weekStart: _ignoredWeekStart,
    _locked: _ignoredLocked,
    ...candidate
  } = session;

  void _ignoredDate;
  void _ignoredWeekday;
  void _ignoredWeekStart;
  void _ignoredLocked;
  return candidate;
}

function dateForWeekday(weekStart: string, weekday: number): string {
  const start = parseDateOnly(weekStart)!;
  return formatDateOnly(addDays(start, weekday - 1));
}

function convertToRest(session: ReflowWorkingSession): ReflowImpact {
  const fromType = session.type;

  session.type = "restDay";
  session.workoutTarget = null;
  session.distanceKm = null;
  session.durationMinutes = null;
  session.targetZone = null;

  return {
    key: "removed_for_constraints",
    sessionId: session.id,
    fromType,
    toType: "restDay",
  };
}

function applyDayCap(
  session: ReflowWorkingSession,
  maxDurationMinutes: number,
): boolean {
  const current = session.durationMinutes;
  if (typeof current !== "number" || current <= 0 || maxDurationMinutes <= 0) {
    return false;
  }

  if (current <= maxDurationMinutes) return false;

  const ratio = maxDurationMinutes / current;
  session.durationMinutes = maxDurationMinutes;

  if (typeof session.distanceKm === "number") {
    session.distanceKm = round2(session.distanceKm * ratio);
  }

  return true;
}

function chooseSplitSource(
  candidates: ReflowWorkingSession[],
): ReflowWorkingSession | null {
  const splits = candidates
    .filter((candidate) =>
      !candidate._locked &&
      (candidate.type === "easyRun" || candidate.type === "recoveryRun") &&
      candidate.durationMinutes != null &&
      candidate.durationMinutes >= 2 &&
      candidate.durationMinutes % 1 === 0
    )
    .sort((left, right) => {
      const rank = splitSourceRank(left) - splitSourceRank(right);
      if (rank !== 0) return rank;

      const durationDelta = (left.durationMinutes ?? 0) -
        (right.durationMinutes ?? 0);
      if (durationDelta !== 0) return durationDelta;

      return left._date.getTime() - right._date.getTime() ||
        left.id.localeCompare(right.id);
    });

  return splits[0] ?? null;
}

function splitSession(session: ReflowWorkingSession): {
  splitDuration: number;
  remainingDuration: number;
  splitDistance: number | null;
  remainingDistance: number | null;
} {
  const sourceDuration = session.durationMinutes ?? 0;
  const splitDuration = Math.floor(sourceDuration / 2);
  const remainingDuration = sourceDuration - splitDuration;

  let splitDistance: number | null = null;
  let remainingDistance: number | null = null;
  if (typeof session.distanceKm === "number" && sourceDuration > 0) {
    splitDistance = round2(
      session.distanceKm * (splitDuration / sourceDuration),
    );
    remainingDistance = round2(session.distanceKm - splitDistance);
  }

  return {
    splitDuration,
    remainingDuration,
    splitDistance,
    remainingDistance,
  };
}

function findTargetDay(
  session: ReflowWorkingSession,
  input: ReflowPlanInput,
  occupancy: Map<number, ReflowWorkingSession[]>,
  cutoff: Date,
): number | null {
  const dayOrder = dayOrderForSession(session, input);
  for (const day of dayOrder) {
    if (!isDayAllowedForRun(input, day)) continue;
    const candidateDate = parseDateOnly(
      dateForWeekday(session._weekStart, day),
    );
    if (candidateDate == null || candidateDate < cutoff) continue;
    const occupant = occupancy.get(day);
    if (day !== session._weekday && occupant != null && occupant.length > 0) {
      continue;
    }
    return day;
  }
  return null;
}

function isValidSplitDistance(session: ReflowWorkingSession): boolean {
  if (!isRunType(session.type)) return false;
  if (session.durationMinutes == null) return false;
  return session.durationMinutes >= 2;
}

function splitDurationsForCaps(
  sourceDuration: number,
  sourceCap: number,
  destinationCap: number,
): { splitDuration: number; remainingDuration: number } | null {
  if (sourceDuration < 2) return null;

  const minSplitForSource = Math.max(1, sourceDuration - sourceCap);
  const maxSplitForDestination = Math.min(sourceDuration - 1, destinationCap);

  if (minSplitForSource > maxSplitForDestination) return null;

  const idealSplit = Math.floor(sourceDuration / 2);
  const splitDuration = Math.max(
    minSplitForSource,
    Math.min(idealSplit, maxSplitForDestination),
  );
  const remainingDuration = sourceDuration - splitDuration;

  if (splitDuration > destinationCap || remainingDuration > sourceCap) {
    return null;
  }

  return {
    splitDuration,
    remainingDuration,
  };
}

function splitSessionForDurations(
  session: ReflowWorkingSession,
  splitDuration: number,
) {
  const sourceDuration = session.durationMinutes ?? 0;
  const remainingDuration = sourceDuration - splitDuration;

  let splitDistance: number | null = null;
  let remainingDistance: number | null = null;
  if (typeof session.distanceKm === "number" && sourceDuration > 0) {
    splitDistance = round2(
      session.distanceKm * (splitDuration / sourceDuration),
    );
    remainingDistance = round2(session.distanceKm - splitDistance);
  }

  return {
    splitDuration,
    remainingDuration,
    splitDistance,
    remainingDistance,
  };
}

function buildSplitSessionId(
  baseId: string,
  usedSessionIds: Set<string>,
): string {
  let splitCounter = 1;
  while (usedSessionIds.has(`${baseId}-split-${splitCounter}`)) {
    splitCounter += 1;
  }

  const generatedId = `${baseId}-split-${splitCounter}`;
  usedSessionIds.add(generatedId);
  return generatedId;
}

function addRunToDay(
  runDays: Map<number, ReflowWorkingSession[]>,
  session: ReflowWorkingSession,
): void {
  const bucket = runDays.get(session._weekday);
  if (bucket == null) {
    runDays.set(session._weekday, [session]);
    return;
  }

  if (!bucket.includes(session)) {
    bucket.push(session);
  }
}

function removeRunFromDay(
  runDays: Map<number, ReflowWorkingSession[]>,
  session: ReflowWorkingSession,
): void {
  const bucket = runDays.get(session._weekday);
  if (bucket == null) return;

  const index = bucket.findIndex((item) => item.id === session.id);
  if (index < 0) return;

  if (bucket.length === 1) {
    runDays.delete(session._weekday);
    return;
  }

  bucket.splice(index, 1);
}

function distinctRunningDays(
  sessions: { date: string; type: string }[],
): number {
  const dates = new Set<string>();

  for (const session of sessions) {
    if (!isRunType(session.type)) continue;
    dates.add(dateOnly(session.date));
  }

  return dates.size;
}

export function reflowPlan(input: unknown): ReflowResult {
  const parsedResult = validateReflowInput(input);
  if (!parsedResult.ok) return parsedResult;

  const inputData = parsedResult.request;
  const sessions = toWorkingSessions(inputData.sourcePlan);
  const usedSessionIds = new Set(sessions.map((session) => session.id));

  const cutoff = new Date(Math.max(
    parseDateOnly(inputData.effectiveFrom)!.getTime(),
    parseDateOnly(inputData.asOfDate)!.getTime(),
  ));
  const immutableIds = new Set(inputData.immutableSessionIds ?? []);

  const sessionsByWeek = new Map<string, ReflowWorkingSession[]>();
  let totalRunningDaysBefore = 0;
  let immutablePreservedSessions = 0;

  for (const session of sessions) {
    if (isRunType(session.type)) {
      const immutable = isImmutableSession(session, cutoff, immutableIds);
      session._locked = immutable;
      if (immutable) immutablePreservedSessions += 1;
    } else {
      session._locked = true;
    }

    const bucket = sessionsByWeek.get(session._weekStart);
    if (bucket == null) {
      sessionsByWeek.set(session._weekStart, [session]);
    } else {
      bucket.push(session);
    }
  }

  const impactRows: ReflowImpact[] = [];
  const warnings = new Set<ReflowWarningKey>();
  const weekSummaries: ReflowWeekSummary[] = [];

  let movedSessions = 0;
  let shortenedSessions = 0;
  let removedSessions = 0;
  let splitSessions = 0;

  if (immutablePreservedSessions > 0) {
    warnings.add("immutable_preserved");
  }

  const weekKeys = [...sessionsByWeek.keys()].sort();
  for (const weekStart of weekKeys) {
    const weekSessions = sessionsByWeek.get(weekStart)!;
    const beforeRunningDays = distinctRunningDays(weekSessions);
    totalRunningDaysBefore += beforeRunningDays;

    const occupancy = new Map<number, ReflowWorkingSession[]>();
    for (const session of weekSessions) {
      if (isRunType(session.type)) {
        addRunToDay(occupancy, session);
      }
    }

    const mutableRuns = weekSessions
      .filter((session) => isRunType(session.type) && !session._locked)
      .sort((left, right) => {
        const priority = runPriority(right) - runPriority(left);
        if (priority !== 0) return priority;
        return left._date.getTime() - right._date.getTime() ||
          left.id.localeCompare(right.id);
      });

    for (const session of mutableRuns) {
      const candidateDay = findTargetDay(
        session,
        inputData,
        occupancy,
        cutoff,
      );
      if (candidateDay == null) {
        impactRows.push(convertToRest(session));
        removedSessions += 1;
        warnings.add("removed_for_constraints");
        warnings.add("constraints_not_fully_supported");
        session._locked = true;
        removeRunFromDay(occupancy, session);
        continue;
      }

      const previousDate = session.date;
      const targetDate = dateForWeekday(weekStart, candidateDay);
      const config = getConfig(inputData, candidateDay);

      const moved = session.date !== targetDate;
      if (moved) {
        removeRunFromDay(occupancy, session);
        session._weekday = candidateDay;
        session._date = parseDateOnly(targetDate)!;
        session.date = targetDate;
        addRunToDay(occupancy, session);

        impactRows.push({
          key: "move",
          sessionId: session.id,
          fromDate: previousDate,
          toDate: targetDate,
        });
        movedSessions += 1;
      }

      const shortened = applyDayCap(session, config.maxDurationMinutes);
      if (shortened) {
        impactRows.push({
          key: "shortened_for_time_cap",
          sessionId: session.id,
          fromDate: previousDate,
          toDate: targetDate,
          detail: {
            maxDurationMinutes: config.maxDurationMinutes,
          },
        });
        shortenedSessions += 1;
        warnings.add("shortened_for_time_cap");
      }

      if (
        session.type === "longRun" &&
        inputData.backupLongRunDay != null &&
        session.type === "longRun" &&
        candidateDay === inputData.backupLongRunDay &&
        inputData.primaryLongRunDay !== inputData.backupLongRunDay
      ) {
        impactRows.push({
          key: "long_run_backup",
          sessionId: session.id,
          toDate: targetDate,
          detail: {
            weekday: candidateDay,
            weekStart,
          },
        });
        warnings.add("long_run_backup");
      }
    }

    while (occupancy.size > inputData.targetRunningDays) {
      const removableDateBuckets = [...occupancy.entries()]
        .filter(([, sessions]) => sessions.every((session) => !session._locked))
        .map(([weekday, sessions]) => ({ weekday, sessions }))
        .sort((left, right) => {
          const leftRemovalWeight = left.sessions
            .reduce((sum, session) => sum + removalRank(session), 0);
          const rightRemovalWeight = right.sessions
            .reduce((sum, session) => sum + removalRank(session), 0);
          if (leftRemovalWeight !== rightRemovalWeight) {
            return leftRemovalWeight - rightRemovalWeight;
          }

          if (left.sessions.length !== right.sessions.length) {
            return left.sessions.length - right.sessions.length;
          }

          return left.weekday - right.weekday;
        });

      const removalBucket = removableDateBuckets[0];
      if (removalBucket == null) {
        warnings.add("constraints_not_fully_supported");
        break;
      }

      for (const removeSession of [...removalBucket.sessions]) {
        impactRows.push(convertToRest(removeSession));
        removedSessions += 1;
        warnings.add("removed_for_constraints");
        removeSession._locked = true;
        removeRunFromDay(occupancy, removeSession);
      }
    }

    while (occupancy.size < inputData.targetRunningDays) {
      const splitSource = chooseSplitSource(weekSessions);
      if (splitSource == null || !isValidSplitDistance(splitSource)) {
        warnings.add("constraints_not_fully_supported");
        break;
      }

      let splitDay = -1;
      let splitPlan:
        | {
          splitDay: number;
          splitDate: string;
          sourceCap: number;
          destinationCap: number;
          splitDuration: number;
          remainingDuration: number;
        }
        | null = null;
      for (let day = 1; day <= 7; day += 1) {
        const splitDate = dateForWeekday(weekStart, day);
        const splitDateValue = parseDateOnly(splitDate);
        if (splitDateValue == null || splitDateValue < cutoff) continue;
        if (!isDayAllowedForRun(inputData, day)) continue;
        if (occupancy.has(day)) continue;

        const splitCaps = splitDurationsForCaps(
          splitSource.durationMinutes!,
          getConfig(inputData, splitSource._weekday).maxDurationMinutes,
          getConfig(inputData, day).maxDurationMinutes,
        );
        if (splitCaps == null) continue;

        splitDay = day;
        splitPlan = {
          splitDay: day,
          splitDate,
          sourceCap:
            getConfig(inputData, splitSource._weekday).maxDurationMinutes,
          destinationCap: getConfig(inputData, day).maxDurationMinutes,
          splitDuration: splitCaps.splitDuration,
          remainingDuration: splitCaps.remainingDuration,
        };
        break;
      }

      if (splitDay === -1) {
        warnings.add("constraints_not_fully_supported");
        break;
      }

      if (splitPlan == null) {
        warnings.add("constraints_not_fully_supported");
        break;
      }

      const splitData = splitSessionForDurations(
        splitSource,
        splitPlan.splitDuration,
      );
      if (splitData.splitDuration <= 0 || splitData.remainingDuration <= 0) {
        warnings.add("constraints_not_fully_supported");
        break;
      }

      splitSource.durationMinutes = splitData.remainingDuration;
      if (splitData.remainingDistance != null) {
        splitSource.distanceKm = splitData.remainingDistance;
      }

      const splitDate = splitPlan.splitDate;
      const splitSessionId = buildSplitSessionId(
        splitSource.id,
        usedSessionIds,
      );
      const splitSessionRow: ReflowWorkingSession = {
        ...splitSource,
        id: splitSessionId,
        date: splitDate,
        _date: parseDateOnly(splitDate)!,
        _weekday: splitDay,
        _weekStart: weekStart,
        _locked: true,
        durationMinutes: splitData.splitDuration,
      };

      if (splitData.splitDistance != null) {
        splitSessionRow.distanceKm = splitData.splitDistance;
      }

      splitSessionRow.workoutTarget = splitSource.workoutTarget;
      splitSessionRow.phase = splitSource.phase;

      weekSessions.push(splitSessionRow);
      sessions.push(splitSessionRow);
      addRunToDay(occupancy, splitSessionRow);

      impactRows.push({
        key: "split_for_frequency",
        sessionId: splitSessionId,
        fromType: splitSource.type,
        toType: splitSource.type,
        fromDate: splitSource.date,
        toDate: splitDate,
      });
      splitSessions += 1;
    }

    const afterRunningDays = occupancy.size;
    if (afterRunningDays === 1 && inputData.targetRunningDays > 1) {
      warnings.add("one_run_warning");
    }

    weekSummaries.push({
      weekStart,
      beforeRunningDays,
      afterRunningDays,
      addedRunningDays: Math.max(0, afterRunningDays - beforeRunningDays),
      removedRunningDays: Math.max(0, beforeRunningDays - afterRunningDays),
    });
  }

  const candidatePlanSessions = sessions
    .slice()
    .sort((left, right) => {
      const byDate = dateOnly(left.date).localeCompare(dateOnly(right.date));
      if (byDate !== 0) return byDate;
      return left.id.localeCompare(right.id);
    })
    .map((session) => stripWorkingFields(session));

  const totalAfter = distinctRunningDays(candidatePlanSessions);

  return {
    ok: true,
    candidatePlan: {
      ...(inputData.sourcePlan as JsonObject),
      sessions: candidatePlanSessions,
    },
    impacts: impactRows,
    warnings: [...warnings].sort(),
    goalImpact: {
      targetRunningDays: inputData.targetRunningDays,
      totalRunningDaysBefore,
      totalRunningDaysAfter: totalAfter,
      movedSessions,
      shortenedSessions,
      removedSessions,
      splitSessions,
      immutablePreservedSessions,
      weekly: weekSummaries,
    },
  };
}
