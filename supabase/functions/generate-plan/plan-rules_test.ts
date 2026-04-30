import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  ensureFullCalendarWeeks,
  ensureGoalRaceSession,
  normalizeFirstPlannedSession,
  normalizePeakLongRun,
  normalizeSessionIds,
  normalizeTaper,
  normalizeTrainingDayCount,
  normalizeWorkoutTypesByPhase,
  peakLongRunRangeKm,
  phaseForWeek,
  phasePlanFor,
  placeLongRunsOnPreferredDay,
  preferRestOnHardDays,
  smoothLongRunProgression,
  spaceStressfulSessions,
  validateGeneratedSchedule,
  workoutPolicyForPhase,
} from "./plan-rules.ts";
import type { GeneratedSession } from "./schema.ts";

Deno.test("phaseForWeek 12-week plan week 1 is base", () => {
  assert.equal(phaseForWeek(1, 12, {}), "base");
});

Deno.test("phaseForWeek 12-week plan week 4 is build", () => {
  assert.equal(phaseForWeek(4, 12, {}), "build");
});

Deno.test("phaseForWeek 12-week plan week 7 is specific", () => {
  assert.equal(phaseForWeek(7, 12, {}), "specific");
});

Deno.test("phaseForWeek 12-week plan week 10 is peak", () => {
  assert.equal(phaseForWeek(10, 12, {}), "peak");
});

Deno.test("phaseForWeek 12-week plan week 12 is taperRace", () => {
  assert.equal(phaseForWeek(12, 12, {}), "taperRace");
});

Deno.test("phaseForWeek 8-week plan final week is taperRace", () => {
  assert.equal(phaseForWeek(8, 8, {}), "taperRace");
});

Deno.test("phaseForWeek 16-week plan week 13 is peak", () => {
  assert.equal(phaseForWeek(13, 16, {}), "peak");
});

Deno.test("phaseForWeek 16-week plan final week is taperRace", () => {
  assert.equal(phaseForWeek(16, 16, {}), "taperRace");
});

Deno.test("phaseForWeek 20-week plan week 18 is peak", () => {
  assert.equal(phaseForWeek(18, 20, {}), "peak");
});

Deno.test("phaseForWeek 20-week plan final week is taperRace", () => {
  assert.equal(phaseForWeek(20, 20, {}), "taperRace");
});

Deno.test("phasePlanFor 12 weeks returns correct phases", () => {
  const phases = phasePlanFor(12, {});
  assert.equal(phases.length, 12);
  assert.equal(phases.filter((p) => p === "base").length, 3);
  assert.equal(phases.filter((p) => p === "build").length, 3);
  assert.equal(phases.filter((p) => p === "specific").length, 3);
  assert.equal(phases.filter((p) => p === "peak").length, 1);
  assert.equal(phases.filter((p) => p === "taperRace").length, 2);
  assert.equal(phases[11], "taperRace");
});

Deno.test("phasePlanFor 8 weeks returns correct phases", () => {
  const phases = phasePlanFor(8, {});
  assert.equal(phases.length, 8);
  assert.equal(phases.filter((p) => p === "base").length, 2);
  assert.equal(phases.filter((p) => p === "build").length, 2);
  assert.equal(phases.filter((p) => p === "specific").length, 2);
  assert.equal(phases.filter((p) => p === "peak").length, 1);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
  assert.equal(phases[7], "taperRace");
});

Deno.test("phasePlanFor 16 weeks returns correct phases", () => {
  const phases = phasePlanFor(16, {});
  assert.equal(phases.length, 16);
  assert.equal(phases.filter((p) => p === "base").length, 4);
  assert.equal(phases.filter((p) => p === "build").length, 4);
  assert.equal(phases.filter((p) => p === "specific").length, 4);
  assert.equal(phases.filter((p) => p === "peak").length, 2);
  assert.equal(phases.filter((p) => p === "taperRace").length, 2);
  assert.equal(phases[15], "taperRace");
});

Deno.test("phasePlanFor 20 weeks returns correct phases", () => {
  const phases = phasePlanFor(20, {});
  assert.equal(phases.length, 20);
  assert.equal(phases.filter((p) => p === "base").length, 5);
  assert.equal(phases.filter((p) => p === "build").length, 5);
  assert.equal(phases.filter((p) => p === "specific").length, 5);
  assert.equal(phases.filter((p) => p === "peak").length, 3);
  assert.equal(phases.filter((p) => p === "taperRace").length, 2);
  assert.equal(phases[19], "taperRace");
});

Deno.test("phasePlanFor 10 weeks scales proportionally with no gaps", () => {
  const phases = phasePlanFor(10, {});
  assert.equal(phases.length, 10);
  const baseCount = phases.filter((p) => p === "base").length;
  const buildCount = phases.filter((p) => p === "build").length;
  const specificCount = phases.filter((p) => p === "specific").length;
  const peakCount = phases.filter((p) => p === "peak").length;
  const taperCount = phases.filter((p) => p === "taperRace").length;
  assert.equal(
    baseCount + buildCount + specificCount + peakCount + taperCount,
    10,
  );
  assert.ok(
    baseCount >= 1 && buildCount >= 1 && specificCount >= 1 && peakCount >= 1 &&
      taperCount >= 1,
  );
  assert.equal(phases[9], "taperRace");
});

Deno.test("phasePlanFor 14 weeks scales proportionally with no gaps", () => {
  const phases = phasePlanFor(14, {});
  assert.equal(phases.length, 14);
  const baseCount = phases.filter((p) => p === "base").length;
  const buildCount = phases.filter((p) => p === "build").length;
  const specificCount = phases.filter((p) => p === "specific").length;
  const peakCount = phases.filter((p) => p === "peak").length;
  const taperCount = phases.filter((p) => p === "taperRace").length;
  assert.equal(
    baseCount + buildCount + specificCount + peakCount + taperCount,
    14,
  );
  assert.ok(
    baseCount >= 1 && buildCount >= 1 && specificCount >= 1 && peakCount >= 1 &&
      taperCount >= 1,
  );
  assert.equal(phases[13], "taperRace");
});

Deno.test("phasePlanFor 9 weeks produces no gaps", () => {
  const phases = phasePlanFor(9, {});
  assert.equal(phases.length, 9);
  for (let i = 0; i < 9; i++) {
    assert.ok(
      ["base", "build", "specific", "peak", "taperRace"].includes(phases[i]),
    );
  }
});

Deno.test("phasePlanFor 15 weeks produces no gaps", () => {
  const phases = phasePlanFor(15, {});
  assert.equal(phases.length, 15);
  for (let i = 0; i < 15; i++) {
    assert.ok(
      ["base", "build", "specific", "peak", "taperRace"].includes(phases[i]),
    );
  }
});

Deno.test("addStrideDefaults adds intermediate stride defaults", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-wed",
        date: "2026-04-29",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(findSession(sessions, "w1-mon").strideReps, null);
  const laterEasyRun = findSession(sessions, "w1-wed");
  assert.equal(laterEasyRun.strideReps, 4);
  assert.equal(laterEasyRun.strideSeconds, 20);
  assert.equal(laterEasyRun.strideRecoverySeconds, 90);
  assert.match(laterEasyRun.coachNote ?? "", /fast but smooth/i);
});

Deno.test("addStrideDefaults adds larger experienced stride defaults", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-wed",
        date: "2026-04-29",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({ experience: "experience_experienced" }),
    6,
  );

  assert.equal(findSession(sessions, "w1-mon").strideReps, null);
  const laterEasyRun = findSession(sessions, "w1-wed");
  assert.equal(laterEasyRun.strideReps, 6);
  assert.equal(laterEasyRun.strideSeconds, 20);
  assert.equal(laterEasyRun.strideRecoverySeconds, 80);
});

Deno.test("addStrideDefaults can add two weekly stride sessions when safe", () => {
  const sessions = addStrideDefaults(
    [
      session({ id: "w1-mon", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed", date: "2026-04-29", type: "recoveryRun" }),
      session({ id: "w1-thu", date: "2026-04-30", type: "easyRun" }),
      session({ id: "w1-sat", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-mon").strideReps, null);
  assert.equal(findSession(sessions, "w1-wed").strideReps, 4);
  assert.equal(findSession(sessions, "w1-thu").strideReps, 4);
  assert.equal(findSession(sessions, "w1-sat").strideReps, null);
});

Deno.test("addStrideDefaults does not auto-add beginner strides", () => {
  const sessions = addStrideDefaults(
    [
      session({ id: "w1-mon", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed", date: "2026-04-29", type: "easyRun" }),
    ],
    profile({ experience: "experience_beginner" }),
    6,
  );

  assert.equal(strideCount(sessions), 0);
});

Deno.test("addStrideDefaults skips hard days and uses another easy day in the week", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-tue",
        date: "2026-04-28",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({
      experience: "experience_intermediate",
      hardDays: ["day_mon"],
    }),
    6,
  );

  assert.equal(sessions[0].strideReps, null);
  assert.equal(sessions[1].strideReps, 4);
});

Deno.test("addStrideDefaults removes all strides in race week", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w8-mon",
        date: "2026-06-15",
        weekNumber: 8,
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        weekNumber: 8,
        type: "racePaceRun",
      }),
    ],
    profile({
      experience: "experience_intermediate",
      raceDate: "2026-06-21T00:00:00.000",
    }),
    8,
  );

  assert.equal(strideCount(sessions), 0);
});

Deno.test("addStrideDefaults clamps OpenAI stride values to safe ranges", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon-start",
        date: "2026-04-27",
        type: "easyRun",
      }),
      session({
        id: "w1-wed",
        date: "2026-04-29",
        type: "easyRun",
        strideReps: 12,
        strideSeconds: 45,
        strideRecoverySeconds: 30,
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(findSession(sessions, "w1-mon-start").strideReps, null);
  const laterEasyRun = findSession(sessions, "w1-wed");
  assert.equal(laterEasyRun.strideReps, 8);
  assert.equal(laterEasyRun.strideSeconds, 30);
  assert.equal(laterEasyRun.strideRecoverySeconds, 60);
});

Deno.test("addStrideDefaults removes extra or badly placed stride sessions", () => {
  const sessions = addStrideDefaults(
    [
      session({
        id: "w1-mon-easy",
        date: "2026-04-27",
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-wed-recovery",
        date: "2026-04-29",
        type: "recoveryRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
      session({
        id: "w1-thu-easy",
        date: "2026-04-30",
        type: "easyRun",
        strideReps: 4,
        strideSeconds: 20,
        strideRecoverySeconds: 90,
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-tue-tempo").strideReps, null);
});

Deno.test("avoidHardDayTraining swaps stressful sessions off hard days", () => {
  const sessions = avoidHardDayTraining(
    [
      session({
        id: "w1-tue-quality",
        date: "2026-04-28",
        weekNumber: 1,
        type: "intervals",
      }),
      session({
        id: "w1-wed-rest",
        date: "2026-04-29",
        weekNumber: 1,
        type: "restDay",
      }),
    ],
    profile({ hardDays: ["day_tue"] }),
  );

  assert.equal(sessions[0].date, "2026-04-29");
  assert.equal(sessions[1].date, "2026-04-28");
  assert.match(sessions[0].coachNote ?? "", /hard to train/i);
});

Deno.test("avoidHardDayTraining does not move a fixed goal race date", () => {
  const sessions = avoidHardDayTraining(
    [
      session({
        id: "race",
        date: "2026-04-28",
        weekNumber: 1,
        type: "racePaceRun",
      }),
      session({
        id: "w1-wed-rest",
        date: "2026-04-29",
        weekNumber: 1,
        type: "restDay",
      }),
    ],
    profile({
      hardDays: ["day_tue"],
      raceDate: "2026-04-28T00:00:00.000",
    }),
  );

  assert.equal(sessions[0].date, "2026-04-28");
  assert.equal(sessions[1].date, "2026-04-29");
});

Deno.test("preferRestOnHardDays keeps hard days as rest when non-hard days can satisfy 4 training days", () => {
  const sessions = preferRestOnHardDays(
    [
      session({ id: "w1-mon-quality", date: "2026-04-27", type: "intervals" }),
      session({ id: "w1-tue-easy", date: "2026-04-28", type: "easyRun" }),
      session({ id: "w1-wed-rest", date: "2026-04-29", type: "restDay" }),
      session({ id: "w1-thu-easy", date: "2026-04-30", type: "easyRun" }),
      session({ id: "w1-fri-rest", date: "2026-05-01", type: "restDay" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
      session({ id: "w1-sun-easy", date: "2026-05-03", type: "easyRun" }),
    ],
    profile({
      trainingDays: 4,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
    }),
  );

  assert.equal(findByDate(sessions, "2026-04-28").type, "restDay");
  assert.equal(findByDate(sessions, "2026-04-30").type, "restDay");
  assert.equal(findByDate(sessions, "2026-05-03").type, "restDay");
  assert.equal(findByDate(sessions, "2026-05-02").type, "longRun");
  assert.equal(trainingCountForTest(sessions), 4);
  assert.ok(
    sessions.every((item) =>
      !["2026-04-28", "2026-04-30", "2026-05-03"].includes(item.date) ||
      item.type === "restDay"
    ),
  );
});

Deno.test("preferRestOnHardDays uses only easy or recovery runs on hard days when schedule is over-constrained", () => {
  const sessions = preferRestOnHardDays(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-tue-tempo", date: "2026-04-28", type: "tempoRun" }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({
        id: "w1-thu-intervals",
        date: "2026-04-30",
        type: "intervals",
      }),
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
      session({ id: "w1-sun-fartlek", date: "2026-05-03", type: "fartlek" }),
    ],
    profile({
      trainingDays: 6,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
    }),
  );

  const hardDaySessions = [
    findByDate(sessions, "2026-04-28"),
    findByDate(sessions, "2026-04-30"),
    findByDate(sessions, "2026-05-03"),
  ];
  assert.ok(
    hardDaySessions.every((item) =>
      ["restDay", "easyRun", "recoveryRun"].includes(item.type)
    ),
  );
  assert.equal(trainingCountForTest(sessions), 6);
});

Deno.test("normalizeTrainingDayCount converts lowest priority sessions to rest days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({
        id: "w1-tue-quality",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-wed-recovery",
        date: "2026-04-29",
        type: "recoveryRun",
      }),
      session({
        id: "w1-thu-fartlek",
        date: "2026-04-30",
        type: "fartlek",
      }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 3 }),
  );

  assert.equal(trainingDayCount(sessions), 3);
  assert.equal(findSession(sessions, "w1-mon-easy").type, "restDay");
  assert.equal(findSession(sessions, "w1-wed-recovery").type, "restDay");
  assert.equal(findSession(sessions, "w1-tue-quality").type, "intervals");
  assert.equal(findSession(sessions, "w1-thu-fartlek").type, "fartlek");
  assert.equal(findSession(sessions, "w1-sat-long").type, "longRun");
});

Deno.test("normalizeTrainingDayCount converts rest days into easy training days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({
        id: "w1-tue-rest",
        date: "2026-04-28",
        type: "restDay",
        coachNote: "Día libre. Mantén las piernas frescas.",
      }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 3 }),
    "es",
  );

  assert.equal(trainingDayCount(sessions), 3);
  const converted = findSession(sessions, "w1-tue-rest");
  assert.equal(converted.type, "easyRun");
  assert.equal(converted.durationMinutes, 35);
  assert.equal(
    converted.coachNote,
    "Carrera suave añadida para respetar tus días de entrenamiento seleccionados.",
  );
  assert.doesNotMatch(converted.coachNote ?? "", /día libre|descanso/i);
});

Deno.test("normalizeTrainingDayCount adds missing easy days when week has no rest days", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ trainingDays: 4, hardDays: ["day_tue"] }),
  );

  assert.equal(trainingDayCount(sessions), 4);
  assert.equal(new Set(sessions.map((item) => item.date)).size, 4);
  assert.ok(sessions.some((item) => item.id.includes("2026-04-29-added")));
  assert.ok(sessions.some((item) => item.id.includes("2026-04-30-added")));
});

Deno.test("ensureFullCalendarWeeks fills missing dates with rest days", () => {
  const sessions = ensureFullCalendarWeeks(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-fri-long", date: "2026-05-01", type: "longRun" }),
      session({ id: "w1-sat-rest", date: "2026-05-02", type: "restDay" }),
      session({ id: "w1-sun-rest", date: "2026-05-03", type: "restDay" }),
    ],
    "es",
  );

  assert.equal(sessions.length, 7);
  assert.equal(new Set(sessions.map((item) => item.date)).size, 7);
  assert.equal(findSession(sessions, "w1-mon-easy").type, "easyRun");

  const tuesday = findSession(sessions, "w1-2026-04-28-rest");
  const thursday = findSession(sessions, "w1-2026-04-30-rest");
  assert.equal(tuesday.type, "restDay");
  assert.equal(thursday.type, "restDay");
  assert.match(tuesday.coachNote ?? "", /Día de descanso/i);
});

Deno.test("ensureGoalRaceSession makes no-date 5K plan finish with full 5K race", () => {
  const sessions = ensureGoalRaceSession(
    [
      session({
        id: "w8-mon",
        date: "2026-06-15",
        weekNumber: 8,
        type: "easyRun",
      }),
      session({
        id: "w8-fri",
        date: "2026-06-19",
        weekNumber: 8,
        type: "racePaceRun",
        distanceKm: 3,
        durationMinutes: 20,
        warmUpMinutes: 8,
        coolDownMinutes: 6,
      }),
      session({
        id: "w8-sat",
        date: "2026-06-20",
        weekNumber: 8,
        type: "restDay",
      }),
    ],
    profile({
      race: "race_5k",
      raceDate: null,
      longRunDay: "day_sat",
    }),
    "en",
  );

  const race = findSession(sessions, "w8-sat");
  assert.equal(race.type, "racePaceRun");
  assert.equal(race.distanceKm, 5);
  assert.equal(race.durationMinutes, null);
  assert.equal(race.targetZone, "racePace");
  assert.equal(race.warmUpMinutes, 10);
  assert.equal(race.coolDownMinutes, 5);
  assert.match(race.coachNote ?? "", /Goal race day/i);
});

Deno.test("ensureGoalRaceSession preserves fixed race date and sets goal distance", () => {
  const sessions = ensureGoalRaceSession(
    [
      session({
        id: "w9-fri",
        date: "2026-06-19",
        weekNumber: 9,
        type: "easyRun",
      }),
      session({
        id: "race",
        date: "2026-06-21",
        weekNumber: 9,
        type: "racePaceRun",
        distanceKm: 6,
      }),
    ],
    profile({
      race: "race_10k",
      raceDate: "2026-06-21T00:00:00.000",
    }),
  );

  const race = findSession(sessions, "race");
  assert.equal(race.date, "2026-06-21");
  assert.equal(race.distanceKm, 10);
  assert.equal(race.type, "racePaceRun");
});

Deno.test("spaceStressfulSessions swaps adjacent hard sessions apart", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
  );

  assert.equal(findSession(sessions, "w1-mon-intervals").date, "2026-04-27");
  assert.equal(findSession(sessions, "w1-tue-tempo").date, "2026-04-29");
  assert.equal(findSession(sessions, "w1-wed-easy").date, "2026-04-28");
  assert.match(
    findSession(sessions, "w1-tue-tempo").coachNote ?? "",
    /spaced safely/i,
  );
});

Deno.test("spaceStressfulSessions downgrades extra weekly stress", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-fartlek",
        date: "2026-04-27",
        type: "fartlek",
        coachNote: "Push hard today.",
      }),
      session({
        id: "w1-tue-intervals",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-thu-tempo",
        date: "2026-04-30",
        type: "tempoRun",
      }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
  );

  assert.equal(stressDayCount(sessions), 3);
  const downgraded = findSession(sessions, "w1-mon-fartlek");
  assert.equal(downgraded.type, "recoveryRun");
  assert.equal(
    downgraded.coachNote,
    "Adjusted to keep hard training days spaced safely.",
  );
  assert.doesNotMatch(downgraded.coachNote ?? "", /push hard/i);
  assert.equal(findSession(sessions, "w1-sat-long").type, "longRun");
});

Deno.test("spaceStressfulSessions preserves fixed goal race date", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-tempo",
        date: "2026-04-27",
        type: "tempoRun",
      }),
      session({
        id: "race",
        date: "2026-04-28",
        type: "racePaceRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
    ],
    profile({
      experience: "experience_intermediate",
      raceDate: "2026-04-28T00:00:00.000",
    }),
  );

  assert.equal(findSession(sessions, "race").date, "2026-04-28");
  assert.notEqual(findSession(sessions, "w1-mon-tempo").type, "tempoRun");
});

Deno.test("spaceStressfulSessions does not swap hard sessions onto hard days", () => {
  const sessions = spaceStressfulSessions(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({
        id: "w1-tue-tempo",
        date: "2026-04-28",
        type: "tempoRun",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-thu-easy", date: "2026-04-30", type: "easyRun" }),
    ],
    profile({
      experience: "experience_intermediate",
      hardDays: ["day_wed"],
    }),
  );

  assert.equal(findSession(sessions, "w1-tue-tempo").date, "2026-04-30");
  assert.equal(findSession(sessions, "w1-wed-easy").date, "2026-04-29");
});

Deno.test("placeLongRunsOnPreferredDay swaps long run onto preferred day", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-01");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-03");
  assert.match(
    findSession(sessions, "w1-sun-long").coachNote ?? "",
    /preferred long run day/i,
  );
});

Deno.test("placeLongRunsOnPreferredDay skips preferred day when it is hard", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ hardDays: ["day_fri"], longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-01");
});

Deno.test("placeLongRunsOnPreferredDay does not swap with hard workout", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({
        id: "w1-fri-tempo",
        date: "2026-05-01",
        type: "tempoRun",
      }),
      session({ id: "w1-sun-long", date: "2026-05-03", type: "longRun" }),
    ],
    profile({ longRunDay: "day_fri" }),
  );

  assert.equal(findSession(sessions, "w1-sun-long").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-tempo").date, "2026-05-01");
});

Deno.test("placeLongRunsOnPreferredDay preserves fixed race date", () => {
  const sessions = placeLongRunsOnPreferredDay(
    [
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "race", date: "2026-05-03", type: "racePaceRun" }),
    ],
    profile({
      longRunDay: "day_fri",
      raceDate: "2026-05-03T00:00:00.000",
    }),
  );

  assert.equal(findSession(sessions, "race").date, "2026-05-03");
  assert.equal(findSession(sessions, "w1-fri-easy").date, "2026-05-01");
});

Deno.test("peakLongRunRangeKm 5K beginner returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_5k", experience: "experience_beginner" }),
  );
  assert.equal(range.minKm, 3);
  assert.equal(range.targetKm, 5);
  assert.equal(range.maxKm, 7);
});

Deno.test("peakLongRunRangeKm 5K intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_5k", experience: "experience_intermediate" }),
  );
  assert.equal(range.minKm, 6);
  assert.equal(range.targetKm, 8);
  assert.equal(range.maxKm, 10);
});

Deno.test("peakLongRunRangeKm 5K experienced returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_5k", experience: "experience_experienced" }),
  );
  assert.equal(range.minKm, 8);
  assert.equal(range.targetKm, 10);
  assert.equal(range.maxKm, 12);
});

Deno.test("peakLongRunRangeKm 10K beginner returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_10k", experience: "experience_beginner" }),
  );
  assert.equal(range.minKm, 6);
  assert.equal(range.targetKm, 8);
  assert.equal(range.maxKm, 10);
});

Deno.test("peakLongRunRangeKm 10K intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_10k", experience: "experience_intermediate" }),
  );
  assert.equal(range.minKm, 10);
  assert.equal(range.targetKm, 12);
  assert.equal(range.maxKm, 13);
});

Deno.test("peakLongRunRangeKm 10K experienced returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_10k", experience: "experience_experienced" }),
  );
  assert.equal(range.minKm, 11);
  assert.equal(range.targetKm, 13);
  assert.equal(range.maxKm, 16);
});

Deno.test("peakLongRunRangeKm half marathon beginner returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_half_marathon", experience: "experience_beginner" }),
  );
  assert.equal(range.minKm, 11);
  assert.equal(range.targetKm, 13);
  assert.equal(range.maxKm, 16);
});

Deno.test("peakLongRunRangeKm half marathon intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({
      race: "race_half_marathon",
      experience: "experience_intermediate",
    }),
  );
  assert.equal(range.minKm, 14);
  assert.equal(range.targetKm, 16);
  assert.equal(range.maxKm, 18);
});

Deno.test("peakLongRunRangeKm half marathon experienced returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({
      race: "race_half_marathon",
      experience: "experience_experienced",
    }),
  );
  assert.equal(range.minKm, 16);
  assert.equal(range.targetKm, 18);
  assert.equal(range.maxKm, 21);
});

Deno.test("peakLongRunRangeKm marathon beginner returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_marathon", experience: "experience_beginner" }),
  );
  assert.equal(range.minKm, 24);
  assert.equal(range.targetKm, 26);
  assert.equal(range.maxKm, 30);
});

Deno.test("peakLongRunRangeKm marathon intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_marathon", experience: "experience_intermediate" }),
  );
  assert.equal(range.minKm, 28);
  assert.equal(range.targetKm, 30);
  assert.equal(range.maxKm, 32);
});

Deno.test("peakLongRunRangeKm marathon experienced returns correct range", () => {
  const range = peakLongRunRangeKm(
    profile({ race: "race_marathon", experience: "experience_experienced" }),
  );
  assert.equal(range.minKm, 30);
  assert.equal(range.targetKm, 32);
  assert.equal(range.maxKm, 34);
});

Deno.test("workoutPolicyForPhase base phase allows easy, recovery, long run", () => {
  const policy = workoutPolicyForPhase("base", "fiveK", "experience_beginner");
  assert.ok(
    policy.allowedTypes.includes("easyRun"),
    "base should allow easyRun",
  );
  assert.ok(
    policy.allowedTypes.includes("recoveryRun"),
    "base should allow recoveryRun",
  );
  assert.ok(
    policy.allowedTypes.includes("longRun"),
    "base should allow longRun",
  );
});

Deno.test("workoutPolicyForPhase base phase does not allow advanced workouts for beginner", () => {
  const policy = workoutPolicyForPhase("base", "fiveK", "experience_beginner");
  assert.ok(
    !policy.allowedTypes.includes("intervals"),
    "base should not allow intervals for beginner",
  );
  assert.ok(
    !policy.allowedTypes.includes("tempoRun"),
    "base should not allow tempoRun for beginner",
  );
  assert.ok(
    !policy.allowedTypes.includes("thresholdRun"),
    "base should not allow thresholdRun for beginner",
  );
});

Deno.test("workoutPolicyForPhase build phase adds tempo, hills, fartlek for intermediate", () => {
  const policy = workoutPolicyForPhase(
    "build",
    "fiveK",
    "experience_intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("tempoRun"),
    "build should allow tempoRun for intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("hillRepeats"),
    "build should allow hillRepeats for intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("fartlek"),
    "build should allow fartlek for intermediate",
  );
});

Deno.test("workoutPolicyForPhase build phase allows progressionRun for experienced", () => {
  const policy = workoutPolicyForPhase(
    "build",
    "tenK",
    "experience_experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("progressionRun"),
    "build should allow progressionRun for experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("tempoRun"),
    "build should allow tempoRun for experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("hillRepeats"),
    "build should allow hillRepeats for experienced",
  );
});

Deno.test("workoutPolicyForPhase specific phase adds race-relevant workouts", () => {
  const policy = workoutPolicyForPhase(
    "specific",
    "fiveK",
    "experience_intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("intervals"),
    "specific should allow intervals",
  );
  assert.ok(
    policy.allowedTypes.includes("racePaceRun"),
    "specific should allow racePaceRun",
  );
});

Deno.test("workoutPolicyForPhase peak phase includes strongest workouts", () => {
  const policy = workoutPolicyForPhase(
    "peak",
    "marathon",
    "experience_experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("intervals"),
    "peak should allow intervals",
  );
  assert.ok(
    policy.allowedTypes.includes("thresholdRun"),
    "peak should allow thresholdRun",
  );
  assert.ok(
    policy.allowedTypes.includes("longRun"),
    "peak should allow longRun",
  );
});

Deno.test("workoutPolicyForPhase peak phase does not exceed weekly stress limits", () => {
  const policy = workoutPolicyForPhase(
    "peak",
    "fiveK",
    "experience_intermediate",
  );
  const hardTypes =
    policy.allowedTypes.filter((t) =>
      ["intervals", "tempoRun", "thresholdRun", "hillRepeats"].includes(t)
    ).length;
  assert.ok(hardTypes <= 4, "peak should limit hard workout types");
  assert.equal(policy.maxStressDays, 3, "peak maxStressDays should be 3");
});

Deno.test("workoutPolicyForPhase taperRace phase is reduced volume with light sharpness", () => {
  const policy = workoutPolicyForPhase(
    "taperRace",
    "halfMarathon",
    "experience_intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("easyRun"),
    "taperRace should allow easyRun",
  );
  assert.ok(
    policy.allowedTypes.includes("recoveryRun"),
    "taperRace should allow recoveryRun",
  );
  assert.ok(
    !policy.allowedTypes.includes("intervals"),
    "taperRace should not allow intervals",
  );
  assert.ok(
    !policy.allowedTypes.includes("thresholdRun"),
    "taperRace should not allow thresholdRun",
  );
  assert.ok(
    !policy.allowedTypes.includes("hillRepeats"),
    "taperRace should not allow hillRepeats",
  );
});

Deno.test("workoutPolicyForPhase taperRace allows racePaceRun for race day", () => {
  const policy = workoutPolicyForPhase(
    "taperRace",
    "marathon",
    "experience_experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("racePaceRun"),
    "taperRace should allow racePaceRun",
  );
});

Deno.test("workoutPolicyForPhase build phase for marathon adds marathon-specific workouts", () => {
  const policy = workoutPolicyForPhase(
    "build",
    "marathon",
    "experience_intermediate",
  );
  assert.ok(
    policy.allowedTypes.includes("longRun"),
    "marathon build should allow longRun",
  );
  assert.ok(
    policy.allowedTypes.includes("tempoRun"),
    "marathon build should allow tempoRun",
  );
});

Deno.test("workoutPolicyForPhase beginner never gets thresholdRun", () => {
  for (
    const phase of ["base", "build", "specific", "peak", "taperRace"] as const
  ) {
    const policy = workoutPolicyForPhase(phase, "fiveK", "experience_beginner");
    assert.ok(
      !policy.allowedTypes.includes("thresholdRun"),
      `beginner ${phase} should not allow thresholdRun`,
    );
  }
});

Deno.test("workoutPolicyForPhase experienced gets full range", () => {
  const policy = workoutPolicyForPhase(
    "specific",
    "fiveK",
    "experience_experienced",
  );
  assert.ok(
    policy.allowedTypes.includes("intervals"),
    "experienced specific should allow intervals",
  );
  assert.ok(
    policy.allowedTypes.includes("thresholdRun"),
    "experienced specific should allow thresholdRun",
  );
  assert.ok(
    policy.allowedTypes.includes("racePaceRun"),
    "experienced specific should allow racePaceRun",
  );
});

Deno.test("workoutPolicyForPhase longRun appears in all phases", () => {
  for (
    const phase of ["base", "build", "specific", "peak", "taperRace"] as const
  ) {
    const policy = workoutPolicyForPhase(
      phase,
      "fiveK",
      "experience_intermediate",
    );
    assert.ok(
      policy.allowedTypes.includes("longRun"),
      `${phase} should allow longRun`,
    );
  }
});

Deno.test("workoutPolicyForPhase base phase sets maxStressDays low", () => {
  const policy = workoutPolicyForPhase(
    "base",
    "fiveK",
    "experience_intermediate",
  );
  assert.ok(
    policy.maxStressDays <= 2,
    "base phase should have low maxStressDays",
  );
});

Deno.test("workoutPolicyForPhase taperRace phase sets maxStressDays to minimum", () => {
  const policy = workoutPolicyForPhase(
    "taperRace",
    "fiveK",
    "experience_intermediate",
  );
  assert.ok(
    policy.maxStressDays <= 1,
    "taperRace should have minimal maxStressDays",
  );
});

Deno.test("normalizePeakLongRun raises beginner marathon 20km peak to ~28km", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 10,
      weekNumber: 1,
    }),
    session({
      id: "w5-sat",
      date: "2026-05-23",
      type: "longRun",
      distanceKm: 15,
      weekNumber: 5,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 20,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 20,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(
    peakLongRun!.distanceKm != null,
    "peak longRun should have a distance",
  );
  assert.ok(
    peakLongRun!.distanceKm! >= 24,
    `peak should be at least 24km, got ${peakLongRun!.distanceKm}`,
  );
  assert.ok(
    peakLongRun!.distanceKm! <= 30,
    `peak should be capped at 30km, got ${peakLongRun!.distanceKm}`,
  );
});

Deno.test("normalizePeakLongRun raises intermediate 10K 8km peak to ~13km", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 5,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 8,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 8,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 10,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({ race: "race_10k", experience: "experience_intermediate" }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(
    peakLongRun!.distanceKm != null,
    "peak longRun should have a distance",
  );
  assert.ok(
    peakLongRun!.distanceKm! >= 10,
    `peak should be at least 10km, got ${peakLongRun!.distanceKm}`,
  );
  assert.ok(
    peakLongRun!.distanceKm! <= 15,
    `peak should be capped at 15km, got ${peakLongRun!.distanceKm}`,
  );
});

Deno.test("normalizePeakLongRun caps experienced half marathon 25km peak at ~21km", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 12,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 20,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 25,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 21.1,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({
      race: "race_half_marathon",
      experience: "experience_experienced",
    }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(
    peakLongRun!.distanceKm != null,
    "peak longRun should have a distance",
  );
  assert.ok(
    peakLongRun!.distanceKm! >= 16,
    `peak should be at least 16km, got ${peakLongRun!.distanceKm}`,
  );
  assert.ok(
    peakLongRun!.distanceKm! <= 23,
    `peak should be capped at 23km, got ${peakLongRun!.distanceKm}`,
  );
});

Deno.test("normalizePeakLongRun updates duration when raising distance", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 10,
      durationMinutes: 60,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 15,
      durationMinutes: 90,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 20,
      durationMinutes: 100,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.equal(
    peakLongRun!.distanceKm,
    26,
    "distance should be raised to target",
  );
  assert.ok(peakLongRun!.durationMinutes != null, "duration should be updated");
  assert.ok(
    peakLongRun!.durationMinutes! > 100,
    "duration should reflect larger distance",
  );
  assert.ok(
    peakLongRun!.durationMinutes! < 200,
    "duration should be realistic",
  );
});

Deno.test("normalizePeakLongRun does not update duration when distance unchanged", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 10,
      durationMinutes: 60,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 15,
      durationMinutes: 90,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 26,
      durationMinutes: 130,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.equal(peakLongRun!.distanceKm, 26, "distance should stay at 26");
  assert.equal(
    peakLongRun!.durationMinutes,
    130,
    "duration should not change when distance unchanged",
  );
});

Deno.test("normalizePeakLongRun updates duration when capping distance", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 12,
      durationMinutes: 72,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 20,
      durationMinutes: 120,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 25,
      durationMinutes: 150,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 21.1,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({
      race: "race_half_marathon",
      experience: "experience_experienced",
    }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(peakLongRun!.distanceKm! <= 23, "distance should be capped at max");
  assert.ok(peakLongRun!.durationMinutes != null, "duration should be updated");
  assert.ok(
    peakLongRun!.durationMinutes! < 150,
    "duration should reflect smaller distance",
  );
});

Deno.test("normalizePeakLongRun does not update duration when distance unchanged", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 10,
      durationMinutes: 60,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 15,
      durationMinutes: 90,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 26,
      durationMinutes: 130,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = normalizePeakLongRun(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.equal(peakLongRun!.distanceKm, 26, "distance should stay at 26");
  assert.equal(
    peakLongRun!.durationMinutes,
    130,
    "duration should not change when distance unchanged",
  );
});

Deno.test("smoothLongRunProgression reduces 5K 4km jump to 2km max", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 5,
      weekNumber: 1,
    }),
    session({
      id: "w2-sat",
      date: "2026-05-02",
      type: "longRun",
      distanceKm: 9,
      weekNumber: 2,
    }),
    session({
      id: "w3-sat",
      date: "2026-05-09",
      type: "longRun",
      distanceKm: 11,
      weekNumber: 3,
    }),
  ];
  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_5k", experience: "experience_beginner" }),
    12,
    "en",
  );
  const longRuns = result.filter((s: GeneratedSession) => s.type === "longRun")
    .sort((a: GeneratedSession, b: GeneratedSession) =>
      a.weekNumber - b.weekNumber
    );
  assert.ok(longRuns.length >= 3, "should have at least 3 long runs");
  const jump2to3 = Math.abs(
    (longRuns[2].distanceKm ?? 0) - (longRuns[1].distanceKm ?? 0),
  );
  assert.ok(
    jump2to3 <= 2 + 0.01,
    `w2→w3 jump ${jump2to3.toFixed(2)}km exceeds 2km max for 5K`,
  );
});

Deno.test("smoothLongRunProgression reduces marathon 5km jump to 3-4km max", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 15,
      durationMinutes: 90,
      weekNumber: 1,
    }),
    session({
      id: "w2-sat",
      date: "2026-05-02",
      type: "longRun",
      distanceKm: 20,
      durationMinutes: 120,
      weekNumber: 2,
    }),
    session({
      id: "w3-sat",
      date: "2026-05-09",
      type: "longRun",
      distanceKm: 28,
      durationMinutes: 168,
      weekNumber: 3,
    }),
  ];
  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_marathon", experience: "experience_intermediate" }),
    12,
    "en",
  );
  const longRuns = result.filter((s: GeneratedSession) => s.type === "longRun")
    .sort((a: GeneratedSession, b: GeneratedSession) =>
      a.weekNumber - b.weekNumber
    );
  const jump2to3 = Math.abs(
    (longRuns[2].distanceKm ?? 0) - (longRuns[1].distanceKm ?? 0),
  );
  assert.ok(
    jump2to3 <= 4 + 0.01,
    `w2→w3 jump ${jump2to3.toFixed(2)}km exceeds 4km max for marathon`,
  );
  assert.ok(
    jump2to3 >= 3,
    `w2→w3 jump ${jump2to3.toFixed(2)}km should be at least 3km`,
  );
  assert.ok(
    longRuns[2].durationMinutes! < 168,
    "duration should be recalculated when smoothing lowers distance",
  );
});

Deno.test("smoothLongRunProgression preserves normalized peak long run target", () => {
  const sessions = [
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 20,
      durationMinutes: 120,
      weekNumber: 8,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 26,
      durationMinutes: 156,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );

  assert.equal(findSession(result, "w10-sat").distanceKm, 26);
  assert.equal(findSession(result, "w10-sat").durationMinutes, 156);
});

Deno.test("smoothLongRunProgression preserves down week lower than previous", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 15,
      weekNumber: 1,
    }),
    session({
      id: "w2-sat",
      date: "2026-05-02",
      type: "longRun",
      distanceKm: 10,
      weekNumber: 2,
    }),
    session({
      id: "w3-sat",
      date: "2026-05-09",
      type: "longRun",
      distanceKm: 12,
      weekNumber: 3,
    }),
  ];
  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_5k", experience: "experience_intermediate" }),
    12,
    "en",
  );
  const longRuns = result.filter((s: GeneratedSession) => s.type === "longRun")
    .sort((a: GeneratedSession, b: GeneratedSession) =>
      a.weekNumber - b.weekNumber
    );
  assert.ok(longRuns[1].distanceKm != null, "w2 longRun should have distance");
  assert.ok(
    longRuns[1].distanceKm! <= 10 + 0.01,
    "down week w2 should stay at 10km or lower",
  );
});

Deno.test("normalizeTaper marathon final 2 long runs reduced vs peak", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 18,
      durationMinutes: 108,
      weekNumber: 1,
    }),
    session({
      id: "w5-sat",
      date: "2026-05-23",
      type: "longRun",
      distanceKm: 24,
      durationMinutes: 144,
      weekNumber: 5,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 27,
      durationMinutes: 162,
      weekNumber: 8,
    }),
    session({
      id: "w9-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 28,
      durationMinutes: 168,
      weekNumber: 9,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 27,
      durationMinutes: 162,
      weekNumber: 10,
    }),
    session({
      id: "w11-sat",
      date: "2026-07-04",
      type: "longRun",
      distanceKm: 20,
      durationMinutes: 120,
      weekNumber: 11,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 12,
    }),
  ];
  const result = normalizeTaper(
    sessions,
    profile({ race: "race_marathon", experience: "experience_beginner" }),
    12,
    "en",
  );
  const w11LongRun = result.find((s: GeneratedSession) =>
    s.weekNumber === 11 && s.type === "longRun"
  );
  assert.ok(w11LongRun, "week 11 longRun should exist");
  assert.ok(
    w11LongRun!.distanceKm != null,
    "week 11 longRun should have distance",
  );
  assert.ok(
    w11LongRun!.distanceKm! < 27,
    `week 11 long run should be reduced vs peak (~27km), got ${
      w11LongRun!.distanceKm
    }`,
  );
  assert.ok(
    w11LongRun!.durationMinutes! < 120,
    "duration should be recalculated when taper lowers distance",
  );
});

Deno.test("normalizeTaper marathon taperRace week just before race has reduced long run", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 18,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 28,
      weekNumber: 8,
    }),
    session({
      id: "w9-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 32,
      weekNumber: 9,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 18,
      weekNumber: 10,
    }),
    session({
      id: "w11-sat",
      date: "2026-07-04",
      type: "racePaceRun",
      distanceKm: 42.2,
      weekNumber: 11,
    }),
  ];
  const result = normalizeTaper(
    sessions,
    profile({ race: "race_marathon", experience: "experience_intermediate" }),
    11,
    "en",
  );
  const w10LongRun = result.find((s: GeneratedSession) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(w10LongRun, "week 10 longRun in taperRace should exist");
  assert.ok(
    w10LongRun!.distanceKm! < 32,
    `taperRace long run should be reduced from peak 32km, got ${
      w10LongRun!.distanceKm
    }`,
  );
  const raceSession = result.find((s: GeneratedSession) =>
    s.type === "racePaceRun"
  );
  assert.equal(
    raceSession!.distanceKm,
    42.2,
    "race day distance must stay exact",
  );
});

Deno.test("normalizeTaper half marathon taper is lighter than marathon taper", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 10,
      weekNumber: 1,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 16,
      weekNumber: 8,
    }),
    session({
      id: "w9-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 18,
      weekNumber: 9,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 12,
      weekNumber: 10,
    }),
    session({
      id: "w11-sat",
      date: "2026-07-04",
      type: "racePaceRun",
      distanceKm: 21.1,
      weekNumber: 11,
    }),
  ];
  const result = normalizeTaper(
    sessions,
    profile({
      race: "race_half_marathon",
      experience: "experience_intermediate",
    }),
    11,
    "en",
  );
  const w10LongRun = result.find((s: GeneratedSession) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(
    w10LongRun,
    "taperRace week longRun should exist for half marathon",
  );
  assert.ok(
    w10LongRun!.distanceKm! < 18,
    `half marathon taper should reduce from peak 18km`,
  );
  const raceSession = result.find((s: GeneratedSession) =>
    s.type === "racePaceRun"
  );
  assert.equal(
    raceSession!.distanceKm,
    21.1,
    "race day distance must stay exact for half",
  );
});

Deno.test("normalizeTaper 5K taper keeps light sharpening but reduces volume", () => {
  const sessions = [
    session({
      id: "w1-mon",
      date: "2026-04-27",
      type: "easyRun",
      distanceKm: 5,
      weekNumber: 1,
    }),
    session({
      id: "w1-sat",
      date: "2026-05-02",
      type: "longRun",
      distanceKm: 8,
      weekNumber: 1,
    }),
    session({
      id: "w7-mon",
      date: "2026-06-08",
      type: "fartlek",
      distanceKm: 6,
      weekNumber: 7,
    }),
    session({
      id: "w8-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 9,
      weekNumber: 8,
    }),
    session({
      id: "w9-mon",
      date: "2026-06-15",
      type: "fartlek",
      distanceKm: 5,
      weekNumber: 9,
    }),
    session({
      id: "w9-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 7,
      weekNumber: 9,
    }),
    session({
      id: "w10-mon",
      date: "2026-06-22",
      type: "easyRun",
      distanceKm: 4,
      weekNumber: 10,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 6,
      weekNumber: 10,
    }),
    session({
      id: "w10-fri",
      date: "2026-06-26",
      type: "racePaceRun",
      distanceKm: 5,
      weekNumber: 10,
    }),
  ];
  const result = normalizeTaper(
    sessions,
    profile({ race: "race_5k", experience: "experience_intermediate" }),
    10,
    "en",
  );
  const w10LongRun = result.find((s: GeneratedSession) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(w10LongRun, "week 10 longRun should exist in taperRace phase");
  assert.ok(
    w10LongRun!.distanceKm! < 7,
    `5K taper long run should be reduced from peak 7km, got ${
      w10LongRun!.distanceKm
    }`,
  );
  const raceSession = result.find((s: GeneratedSession) =>
    s.type === "racePaceRun"
  );
  assert.equal(
    raceSession!.distanceKm,
    5,
    "5K race day distance must stay exact 5km",
  );
  const w9Fartlek = result.find((s: GeneratedSession) =>
    s.weekNumber === 9 && s.type === "fartlek"
  );
  assert.ok(w9Fartlek, "light sharpening fartlek should be preserved in taper");
});

Deno.test("normalizeTaper does not touch final race session distance", () => {
  const sessions = [
    session({
      id: "w9-mon",
      date: "2026-06-15",
      type: "easyRun",
      distanceKm: 6,
      weekNumber: 9,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 15,
      weekNumber: 10,
    }),
    session({
      id: "w11-sat",
      date: "2026-06-27",
      type: "racePaceRun",
      distanceKm: 21.1,
      weekNumber: 11,
    }),
  ];
  const result = normalizeTaper(
    sessions,
    profile({ race: "race_half_marathon", experience: "experience_beginner" }),
    11,
    "en",
  );
  const raceSession = result.find((s: GeneratedSession) =>
    s.type === "racePaceRun"
  );
  assert.equal(
    raceSession!.distanceKm,
    21.1,
    "race day distance must remain exact 21.1km",
  );
});

Deno.test("normalizeFirstPlannedSession downgrades first hard workout", () => {
  const sessions = normalizeFirstPlannedSession(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        type: "intervals",
      }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_experienced" }),
  );

  const first = findByDate(sessions, "2026-04-27");
  assert.equal(first.type, "easyRun");
  assert.equal(first.targetZone, "easy");
  assert.equal(first.intervalReps, null);
  assert.equal(first.intervalRepDistanceMeters, null);
  assert.equal(first.intervalRecoverySeconds, null);
});

Deno.test("normalizeSessionIds regenerates ids from final date and type", () => {
  const sessions = normalizeSessionIds([
    session({
      id: "w1-2026-04-30-intervals",
      date: "2026-04-27",
      weekNumber: 1,
      type: "easyRun",
    }),
    session({
      id: "custom-rest",
      date: "2026-04-28",
      weekNumber: 1,
      type: "restDay",
    }),
  ]);

  assert.equal(sessions[0].id, "w1-2026-04-27-easyRun");
  assert.equal(sessions[1].id, "w1-2026-04-28-restDay");
});

Deno.test("validateGeneratedSchedule reports hard-day and id-date violations", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-04-30-intervals",
        date: "2026-04-28",
        type: "intervals",
      }),
      session({
        id: "w1-2026-04-29-easyRun",
        date: "2026-04-29",
        type: "easyRun",
      }),
    ],
    profile({
      trainingDays: 4,
      hardDays: ["day_tue"],
    }),
  );

  assert.ok(
    violations.some((item) => item.rule === "stressful_session_on_hard_day"),
  );
  assert.ok(
    violations.some((item) => item.rule === "session_id_date_mismatch"),
  );
});

Deno.test("validateGeneratedSchedule allows over-constrained hard-day easy runs per week", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-04-27-easyRun",
        date: "2026-04-27",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-2026-04-28-recoveryRun",
        date: "2026-04-28",
        weekNumber: 1,
        type: "recoveryRun",
        targetZone: "recovery",
      }),
      session({
        id: "w1-2026-04-29-easyRun",
        date: "2026-04-29",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-2026-04-30-restDay",
        date: "2026-04-30",
        weekNumber: 1,
        type: "restDay",
        targetZone: null,
      }),
      session({
        id: "w1-2026-05-01-easyRun",
        date: "2026-05-01",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-2026-05-02-longRun",
        date: "2026-05-02",
        weekNumber: 1,
        type: "longRun",
        targetZone: "longRun",
      }),
      session({
        id: "w1-2026-05-03-easyRun",
        date: "2026-05-03",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w2-2026-05-04-easyRun",
        date: "2026-05-04",
        weekNumber: 2,
        type: "easyRun",
      }),
      session({
        id: "w2-2026-05-05-recoveryRun",
        date: "2026-05-05",
        weekNumber: 2,
        type: "recoveryRun",
        targetZone: "recovery",
      }),
      session({
        id: "w2-2026-05-06-easyRun",
        date: "2026-05-06",
        weekNumber: 2,
        type: "easyRun",
      }),
      session({
        id: "w2-2026-05-07-restDay",
        date: "2026-05-07",
        weekNumber: 2,
        type: "restDay",
        targetZone: null,
      }),
      session({
        id: "w2-2026-05-08-easyRun",
        date: "2026-05-08",
        weekNumber: 2,
        type: "easyRun",
      }),
      session({
        id: "w2-2026-05-09-longRun",
        date: "2026-05-09",
        weekNumber: 2,
        type: "longRun",
        targetZone: "longRun",
      }),
      session({
        id: "w2-2026-05-10-easyRun",
        date: "2026-05-10",
        weekNumber: 2,
        type: "easyRun",
      }),
    ],
    profile({
      trainingDays: 6,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
    }),
  );

  assert.deepEqual(
    violations.filter((item) => item.rule === "avoidable_training_on_hard_day"),
    [],
  );
  assert.deepEqual(
    violations.filter((item) => item.rule === "stressful_session_on_hard_day"),
    [],
  );
});

Deno.test("schedule rule pipeline fixes observed Tue Thu Sun hard-day profile", () => {
  const profileData = profile({
    race: "race_10k",
    raceDate: "2026-06-21T00:00:00.000",
    experience: "experience_experienced",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu", "day_sun"],
    longRunDay: "day_sat",
  });
  const input = [
    session({
      id: "w1-2026-04-30-intervals",
      date: "2026-04-27",
      type: "intervals",
    }),
    session({ id: "w1-2026-04-28-easy", date: "2026-04-28", type: "easyRun" }),
    session({ id: "w1-2026-04-29-rest", date: "2026-04-29", type: "restDay" }),
    session({ id: "w1-2026-04-30-rest", date: "2026-04-30", type: "restDay" }),
    session({ id: "w1-2026-05-01-rest", date: "2026-05-01", type: "restDay" }),
    session({
      id: "w1-2026-05-03-longRun",
      date: "2026-05-02",
      type: "longRun",
    }),
    session({
      id: "w1-2026-05-02-easyRun",
      date: "2026-05-03",
      type: "easyRun",
    }),
  ];

  const result = normalizeSessionIds(
    normalizeFirstPlannedSession(
      preferRestOnHardDays(
        placeLongRunsOnPreferredDay(
          normalizeTrainingDayCount(input, profileData),
          profileData,
        ),
        profileData,
      ),
      profileData,
    ),
  );

  assert.equal(findByDate(result, "2026-04-27").type, "easyRun");
  assert.equal(findByDate(result, "2026-04-28").type, "restDay");
  assert.equal(findByDate(result, "2026-04-30").type, "restDay");
  assert.equal(findByDate(result, "2026-05-02").type, "longRun");
  assert.equal(findByDate(result, "2026-05-03").type, "restDay");
  assert.equal(trainingCountForTest(result), 4);
  assert.deepEqual(validateGeneratedSchedule(result, profileData), []);
  assert.ok(result.every((item) => item.id.includes(item.date.slice(0, 10))));
});

Deno.test("production rule pipeline repairs partial-week hard-day training after calendar fill", () => {
  const profileData = profile({
    race: "race_10k",
    raceDate: "2026-06-21T00:00:00.000",
    experience: "experience_experienced",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu", "day_sun"],
    longRunDay: "day_sat",
  });
  const totalWeeks = 8;
  const input = [
    session({
      id: "w1-2026-04-28-intervals",
      date: "2026-04-28",
      type: "intervals",
    }),
    session({
      id: "w1-2026-04-29-easyRun",
      date: "2026-04-29",
      type: "easyRun",
    }),
    session({
      id: "w1-2026-04-30-easyRun",
      date: "2026-04-30",
      type: "easyRun",
    }),
    session({
      id: "w1-2026-05-03-longRun",
      date: "2026-05-03",
      type: "longRun",
    }),
  ];

  const result = runProductionRulePipeline(input, profileData, totalWeeks);

  assert.equal(result.length, 7);
  assert.equal(findByDate(result, "2026-04-28").type, "restDay");
  assert.equal(findByDate(result, "2026-04-30").type, "restDay");
  assert.equal(findByDate(result, "2026-05-02").type, "longRun");
  assert.equal(findByDate(result, "2026-05-03").type, "restDay");
  assert.equal(trainingCountForTest(result), 4);
  assert.deepEqual(validateGeneratedSchedule(result, profileData), []);
  assert.ok(result.every((item) => item.id.includes(item.date.slice(0, 10))));
});

Deno.test("production rule pipeline moves partial-week long run onto preferred day after calendar fill", () => {
  const profileData = profile({
    race: "race_10k",
    raceDate: "2026-06-21T00:00:00.000",
    experience: "experience_experienced",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu", "day_sun"],
    longRunDay: "day_sat",
  });
  const totalWeeks = 8;
  const input = [
    session({
      id: "w1-2026-04-27-easyRun",
      date: "2026-04-27",
      type: "easyRun",
    }),
    session({
      id: "w1-2026-04-29-easyRun",
      date: "2026-04-29",
      type: "easyRun",
    }),
    session({
      id: "w1-2026-05-01-longRun",
      date: "2026-05-01",
      type: "longRun",
    }),
    session({
      id: "w1-2026-05-03-easyRun",
      date: "2026-05-03",
      type: "easyRun",
    }),
  ];

  const result = runProductionRulePipeline(input, profileData, totalWeeks);

  assert.equal(findByDate(result, "2026-05-02").type, "longRun");
  assert.notEqual(findByDate(result, "2026-05-01").type, "longRun");
  assert.equal(findByDate(result, "2026-05-03").type, "restDay");
  assert.equal(trainingCountForTest(result), 4);
  assert.deepEqual(validateGeneratedSchedule(result, profileData), []);
});

function profile({
  experience = "experience_beginner",
  hardDays = [],
  longRunDay = null,
  race = "race_5k",
  raceDate = null,
  trainingDays = null,
}: {
  experience?: string;
  hardDays?: string[];
  longRunDay?: string | null;
  race?: string;
  raceDate?: string | null;
  trainingDays?: number | null;
} = {}): Record<string, unknown> {
  return {
    goal: { race, raceDate },
    fitness: { experience },
    schedule: { hardDays, longRunDay, trainingDays },
  };
}

function findSession(
  sessions: GeneratedSession[],
  id: string,
): GeneratedSession {
  const found = sessions.find((item) => item.id === id);
  assert.ok(found, `Expected session ${id} to exist`);
  return found;
}

function trainingDayCount(sessions: GeneratedSession[]): number {
  return sessions.filter((item) => item.type !== "restDay").length;
}

function stressDayCount(sessions: GeneratedSession[]): number {
  const stressfulTypes = new Set([
    "longRun",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "tempoRun",
    "thresholdRun",
    "racePaceRun",
  ]);
  return sessions.filter((item) => stressfulTypes.has(item.type)).length;
}

function strideCount(sessions: GeneratedSession[]): number {
  return sessions.filter((item) =>
    (item.strideReps ?? 0) > 0 && (item.strideSeconds ?? 0) > 0
  ).length;
}

function findByDate(
  sessions: GeneratedSession[],
  date: string,
): GeneratedSession {
  const found = sessions.find((item) => item.date === date);
  assert.ok(found, `Expected session on ${date} to exist`);
  return found;
}

function trainingCountForTest(sessions: GeneratedSession[]): number {
  return sessions.filter((item) => item.type !== "restDay").length;
}

function runProductionRulePipeline(
  input: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
): GeneratedSession[] {
  const scheduleNormalizedSessions = normalizeTrainingDayCount(
    input,
    profileData,
  );
  const longRunPlacedSessions = placeLongRunsOnPreferredDay(
    scheduleNormalizedSessions,
    profileData,
  );
  const stressSpacedSessions = spaceStressfulSessions(
    longRunPlacedSessions,
    profileData,
  );
  const fullCalendarSessions = ensureFullCalendarWeeks(stressSpacedSessions);
  const fullCalendarLongRunPlacedSessions = placeLongRunsOnPreferredDay(
    fullCalendarSessions,
    profileData,
  );
  const hardDayRestedSessions = preferRestOnHardDays(
    fullCalendarLongRunPlacedSessions,
    profileData,
  );
  const scheduleAdjustedSessions = avoidHardDayTraining(
    hardDayRestedSessions,
    profileData,
  );
  const peakNormalizedSessions = normalizePeakLongRun(
    scheduleAdjustedSessions,
    profileData,
    totalWeeks,
  );
  const progressionSmoothedSessions = smoothLongRunProgression(
    peakNormalizedSessions,
    profileData,
    totalWeeks,
  );
  const taperNormalizedSessions = normalizeTaper(
    progressionSmoothedSessions,
    profileData,
    totalWeeks,
  );
  const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
    taperNormalizedSessions,
    profileData,
    totalWeeks,
  );
  const firstSessionNormalizedSessions = normalizeFirstPlannedSession(
    phaseNormalizedSessions,
    profileData,
  );
  const phaseStampedSessions = firstSessionNormalizedSessions.map((
    session,
  ) => ({
    ...session,
    phase: phaseForWeek(session.weekNumber, totalWeeks, profileData),
  }));
  const raceFinalizedSessions = ensureGoalRaceSession(
    phaseStampedSessions,
    profileData,
  );
  return normalizeSessionIds(raceFinalizedSessions);
}

function session(
  overrides: Partial<GeneratedSession> & Pick<GeneratedSession, "id" | "date">,
): GeneratedSession {
  return {
    id: overrides.id,
    date: overrides.date,
    weekNumber: overrides.weekNumber ?? 1,
    type: overrides.type ?? "easyRun",
    distanceKm: overrides.distanceKm ?? 5,
    durationMinutes: overrides.durationMinutes ?? 35,
    coachNote: overrides.coachNote ?? null,
    targetZone: overrides.targetZone ?? "easy",
    warmUpMinutes: overrides.warmUpMinutes ?? null,
    coolDownMinutes: overrides.coolDownMinutes ?? null,
    intervalReps: overrides.intervalReps ?? null,
    intervalRepDistanceMeters: overrides.intervalRepDistanceMeters ?? null,
    intervalRecoverySeconds: overrides.intervalRecoverySeconds ?? null,
    strideReps: overrides.strideReps ?? null,
    strideSeconds: overrides.strideSeconds ?? null,
    strideRecoverySeconds: overrides.strideRecoverySeconds ?? null,
  };
}
