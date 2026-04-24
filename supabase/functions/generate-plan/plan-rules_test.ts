import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  ensureFullCalendarWeeks,
  ensureGoalRaceSession,
  normalizeTrainingDayCount,
  peakLongRunRangeKm,
  phaseForWeek,
  phasePlanFor,
  placeLongRunsOnPreferredDay,
  spaceStressfulSessions,
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
  assert.equal(baseCount + buildCount + specificCount + peakCount + taperCount, 10);
  assert.ok(baseCount >= 1 && buildCount >= 1 && specificCount >= 1 && peakCount >= 1 && taperCount >= 1);
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
  assert.equal(baseCount + buildCount + specificCount + peakCount + taperCount, 14);
  assert.ok(baseCount >= 1 && buildCount >= 1 && specificCount >= 1 && peakCount >= 1 && taperCount >= 1);
  assert.equal(phases[13], "taperRace");
});

Deno.test("phasePlanFor 9 weeks produces no gaps", () => {
  const phases = phasePlanFor(9, {});
  assert.equal(phases.length, 9);
  for (let i = 0; i < 9; i++) {
    assert.ok(["base", "build", "specific", "peak", "taperRace"].includes(phases[i]));
  }
});

Deno.test("phasePlanFor 15 weeks produces no gaps", () => {
  const phases = phasePlanFor(15, {});
  assert.equal(phases.length, 15);
  for (let i = 0; i < 15; i++) {
    assert.ok(["base", "build", "specific", "peak", "taperRace"].includes(phases[i]));
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
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 4);
  assert.equal(sessions[0].strideSeconds, 20);
  assert.equal(sessions[0].strideRecoverySeconds, 90);
  assert.match(sessions[0].coachNote ?? "", /fast but smooth/i);
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
    ],
    profile({ experience: "experience_experienced" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 6);
  assert.equal(sessions[0].strideSeconds, 20);
  assert.equal(sessions[0].strideRecoverySeconds, 80);
});

Deno.test("addStrideDefaults can add two weekly stride sessions when safe", () => {
  const sessions = addStrideDefaults(
    [
      session({ id: "w1-mon", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-wed", date: "2026-04-29", type: "recoveryRun" }),
      session({ id: "w1-sat", date: "2026-05-02", type: "longRun" }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(strideCount(sessions), 2);
  assert.equal(findSession(sessions, "w1-mon").strideReps, 4);
  assert.equal(findSession(sessions, "w1-wed").strideReps, 4);
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
        id: "w1-mon",
        date: "2026-04-27",
        type: "easyRun",
        strideReps: 12,
        strideSeconds: 45,
        strideRecoverySeconds: 30,
      }),
    ],
    profile({ experience: "experience_intermediate" }),
    6,
  );

  assert.equal(sessions[0].strideReps, 8);
  assert.equal(sessions[0].strideSeconds, 30);
  assert.equal(sessions[0].strideRecoverySeconds, 60);
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
  const range = peakLongRunRangeKm(profile({ race: "race_5k", experience: "experience_beginner" }));
  assert.equal(range.minKm, 3);
  assert.equal(range.targetKm, 5);
  assert.equal(range.maxKm, 7);
});

Deno.test("peakLongRunRangeKm 5K intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_5k", experience: "experience_intermediate" }));
  assert.equal(range.minKm, 6);
  assert.equal(range.targetKm, 9);
  assert.equal(range.maxKm, 12);
});

Deno.test("peakLongRunRangeKm 5K experienced returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_5k", experience: "experience_experienced" }));
  assert.equal(range.minKm, 8);
  assert.equal(range.targetKm, 11);
  assert.equal(range.maxKm, 14);
});

Deno.test("peakLongRunRangeKm 10K beginner returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_10k", experience: "experience_beginner" }));
  assert.equal(range.minKm, 6);
  assert.equal(range.targetKm, 9);
  assert.equal(range.maxKm, 12);
});

Deno.test("peakLongRunRangeKm 10K intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_10k", experience: "experience_intermediate" }));
  assert.equal(range.minKm, 10);
  assert.equal(range.targetKm, 12.5);
  assert.equal(range.maxKm, 15);
});

Deno.test("peakLongRunRangeKm 10K experienced returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_10k", experience: "experience_experienced" }));
  assert.equal(range.minKm, 11);
  assert.equal(range.targetKm, 14.5);
  assert.equal(range.maxKm, 18);
});

Deno.test("peakLongRunRangeKm half marathon beginner returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_half_marathon", experience: "experience_beginner" }));
  assert.equal(range.minKm, 11);
  assert.equal(range.targetKm, 14.5);
  assert.equal(range.maxKm, 18);
});

Deno.test("peakLongRunRangeKm half marathon intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_half_marathon", experience: "experience_intermediate" }));
  assert.equal(range.minKm, 14);
  assert.equal(range.targetKm, 17);
  assert.equal(range.maxKm, 20);
});

Deno.test("peakLongRunRangeKm half marathon experienced returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_half_marathon", experience: "experience_experienced" }));
  assert.equal(range.minKm, 16);
  assert.equal(range.targetKm, 19.5);
  assert.equal(range.maxKm, 23);
});

Deno.test("peakLongRunRangeKm marathon beginner returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_marathon", experience: "experience_beginner" }));
  assert.equal(range.minKm, 24);
  assert.equal(range.targetKm, 27);
  assert.equal(range.maxKm, 30);
});

Deno.test("peakLongRunRangeKm marathon intermediate returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_marathon", experience: "experience_intermediate" }));
  assert.equal(range.minKm, 28);
  assert.equal(range.targetKm, 31);
  assert.equal(range.maxKm, 34);
});

Deno.test("peakLongRunRangeKm marathon experienced returns correct range", () => {
  const range = peakLongRunRangeKm(profile({ race: "race_marathon", experience: "experience_experienced" }));
  assert.equal(range.minKm, 30);
  assert.equal(range.targetKm, 33);
  assert.equal(range.maxKm, 36);
});

Deno.test("workoutPolicyForPhase base phase allows easy, recovery, long run", () => {
  const policy = workoutPolicyForPhase("base", "fiveK", "experience_beginner");
  assert.ok(policy.allowedTypes.includes("easyRun"), "base should allow easyRun");
  assert.ok(policy.allowedTypes.includes("recoveryRun"), "base should allow recoveryRun");
  assert.ok(policy.allowedTypes.includes("longRun"), "base should allow longRun");
});

Deno.test("workoutPolicyForPhase base phase does not allow advanced workouts for beginner", () => {
  const policy = workoutPolicyForPhase("base", "fiveK", "experience_beginner");
  assert.ok(!policy.allowedTypes.includes("intervals"), "base should not allow intervals for beginner");
  assert.ok(!policy.allowedTypes.includes("tempoRun"), "base should not allow tempoRun for beginner");
  assert.ok(!policy.allowedTypes.includes("thresholdRun"), "base should not allow thresholdRun for beginner");
});

Deno.test("workoutPolicyForPhase build phase adds tempo, hills, fartlek for intermediate", () => {
  const policy = workoutPolicyForPhase("build", "fiveK", "experience_intermediate");
  assert.ok(policy.allowedTypes.includes("tempoRun"), "build should allow tempoRun for intermediate");
  assert.ok(policy.allowedTypes.includes("hillRepeats"), "build should allow hillRepeats for intermediate");
  assert.ok(policy.allowedTypes.includes("fartlek"), "build should allow fartlek for intermediate");
});

Deno.test("workoutPolicyForPhase build phase allows progressionRun for experienced", () => {
  const policy = workoutPolicyForPhase("build", "tenK", "experience_experienced");
  assert.ok(policy.allowedTypes.includes("progressionRun"), "build should allow progressionRun for experienced");
  assert.ok(policy.allowedTypes.includes("tempoRun"), "build should allow tempoRun for experienced");
  assert.ok(policy.allowedTypes.includes("hillRepeats"), "build should allow hillRepeats for experienced");
});

Deno.test("workoutPolicyForPhase specific phase adds race-relevant workouts", () => {
  const policy = workoutPolicyForPhase("specific", "fiveK", "experience_intermediate");
  assert.ok(policy.allowedTypes.includes("intervals"), "specific should allow intervals");
  assert.ok(policy.allowedTypes.includes("racePaceRun"), "specific should allow racePaceRun");
});

Deno.test("workoutPolicyForPhase peak phase includes strongest workouts", () => {
  const policy = workoutPolicyForPhase("peak", "marathon", "experience_experienced");
  assert.ok(policy.allowedTypes.includes("intervals"), "peak should allow intervals");
  assert.ok(policy.allowedTypes.includes("thresholdRun"), "peak should allow thresholdRun");
  assert.ok(policy.allowedTypes.includes("longRun"), "peak should allow longRun");
});

Deno.test("workoutPolicyForPhase peak phase does not exceed weekly stress limits", () => {
  const policy = workoutPolicyForPhase("peak", "fiveK", "experience_intermediate");
  const hardTypes = policy.allowedTypes.filter(t =>
    ["intervals", "tempoRun", "thresholdRun", "hillRepeats"].includes(t)
  ).length;
  assert.ok(hardTypes <= 4, "peak should limit hard workout types");
  assert.equal(policy.maxStressDays, 3, "peak maxStressDays should be 3");
});

Deno.test("workoutPolicyForPhase taperRace phase is reduced volume with light sharpness", () => {
  const policy = workoutPolicyForPhase("taperRace", "halfMarathon", "experience_intermediate");
  assert.ok(policy.allowedTypes.includes("easyRun"), "taperRace should allow easyRun");
  assert.ok(policy.allowedTypes.includes("recoveryRun"), "taperRace should allow recoveryRun");
  assert.ok(!policy.allowedTypes.includes("intervals"), "taperRace should not allow intervals");
  assert.ok(!policy.allowedTypes.includes("thresholdRun"), "taperRace should not allow thresholdRun");
  assert.ok(!policy.allowedTypes.includes("hillRepeats"), "taperRace should not allow hillRepeats");
});

Deno.test("workoutPolicyForPhase taperRace allows racePaceRun for race day", () => {
  const policy = workoutPolicyForPhase("taperRace", "marathon", "experience_experienced");
  assert.ok(policy.allowedTypes.includes("racePaceRun"), "taperRace should allow racePaceRun");
});

Deno.test("workoutPolicyForPhase build phase for marathon adds marathon-specific workouts", () => {
  const policy = workoutPolicyForPhase("build", "marathon", "experience_intermediate");
  assert.ok(policy.allowedTypes.includes("longRun"), "marathon build should allow longRun");
  assert.ok(policy.allowedTypes.includes("tempoRun"), "marathon build should allow tempoRun");
});

Deno.test("workoutPolicyForPhase beginner never gets thresholdRun", () => {
  for (const phase of ["base", "build", "specific", "peak", "taperRace"] as const) {
    const policy = workoutPolicyForPhase(phase, "fiveK", "experience_beginner");
    assert.ok(!policy.allowedTypes.includes("thresholdRun"), `beginner ${phase} should not allow thresholdRun`);
  }
});

Deno.test("workoutPolicyForPhase experienced gets full range", () => {
  const policy = workoutPolicyForPhase("specific", "fiveK", "experience_experienced");
  assert.ok(policy.allowedTypes.includes("intervals"), "experienced specific should allow intervals");
  assert.ok(policy.allowedTypes.includes("thresholdRun"), "experienced specific should allow thresholdRun");
  assert.ok(policy.allowedTypes.includes("racePaceRun"), "experienced specific should allow racePaceRun");
});

Deno.test("workoutPolicyForPhase longRun appears in all phases", () => {
  for (const phase of ["base", "build", "specific", "peak", "taperRace"] as const) {
    const policy = workoutPolicyForPhase(phase, "fiveK", "experience_intermediate");
    assert.ok(policy.allowedTypes.includes("longRun"), `${phase} should allow longRun`);
  }
});

Deno.test("workoutPolicyForPhase base phase sets maxStressDays low", () => {
  const policy = workoutPolicyForPhase("base", "fiveK", "experience_intermediate");
  assert.ok(policy.maxStressDays <= 2, "base phase should have low maxStressDays");
});

Deno.test("workoutPolicyForPhase taperRace phase sets maxStressDays to minimum", () => {
  const policy = workoutPolicyForPhase("taperRace", "fiveK", "experience_intermediate");
  assert.ok(policy.maxStressDays <= 1, "taperRace should have minimal maxStressDays");
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
