import { strict as assert } from "node:assert";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  detectSessionTypePolicyViolations,
  enforcePreRaceTaper,
  ensureFullCalendarWeeks,
  expectedTotalWeeks,
  mergeTargetedSessionRepairPatches,
  mergeTargetedSessionRepairs,
  normalizeFirstPlannedSession,
  normalizePeakLongRun,
  normalizeSessionIds,
  normalizeTaper,
  normalizeTrainingDayCount,
  normalizeWeeklyVolumeRamp,
  normalizeWeekNumbersFromDates,
  normalizeWorkoutTypesByPhase,
  peakLongRunRangeKm,
  phaseForWeek,
  phaseForWeekFromCoachingBrief,
  phasePlanFor,
  placeLongRunsOnPreferredDay,
  preferRestOnHardDays,
  resolvePlanStartDate,
  smoothLongRunProgression,
  spaceStressfulSessions,
  truncateAfterRaceDate,
  unsupportedCoachingBriefReason,
  validateGeneratedPlanAgainstCoachingBrief,
  validateGeneratedPlanShape,
  validateGeneratedSchedule,
  workoutPolicyForPhase,
} from "./plan-rules.ts";
import type { SessionRepairCandidate } from "./plan-rules.ts";
import type { CoachingBrief } from "./coaching-brief.ts";
import {
  removeSessionsOnRaceDate,
  type TargetedSessionRepairPatchItem,
} from "./schema.ts";
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

Deno.test("normalizeTrainingDayCount does not add sessions before planStartDate", () => {
  const sessions = normalizeTrainingDayCount(
    [
      session({
        id: "w1-wed-intervals",
        date: "2026-06-10",
        type: "intervals",
      }),
      session({
        id: "w1-thu-easy",
        date: "2026-06-11",
        type: "easyRun",
      }),
      session({
        id: "w1-fri-easy",
        date: "2026-06-12",
        type: "easyRun",
      }),
    ],
    profile({ trainingDays: 4, planStartDate: "2026-06-10" }),
    "en",
  );

  assert.ok(!sessions.some((session) => session.date < "2026-06-10"));
  assert.equal(trainingDayCount(sessions), 4);
  assert.ok(sessions.some((item) => item.date === "2026-06-13"));
});

Deno.test("normalizeTrainingDayCount uses user trainingDays over Strava runs-per-week", () => {
  const result = normalizeTrainingDayCount(
    [
      session({ id: "w1-mon-easy", date: "2026-04-27", type: "easyRun" }),
      session({ id: "w1-tue-rest", date: "2026-04-28", type: "restDay" }),
      session({ id: "w1-wed-easy", date: "2026-04-29", type: "easyRun" }),
      session({ id: "w1-thu-easy", date: "2026-04-30", type: "easyRun" }),
      session({ id: "w1-fri-easy", date: "2026-05-01", type: "easyRun" }),
      session({ id: "w1-sat-long", date: "2026-05-02", type: "longRun" }),
      session({ id: "w1-sun-easy", date: "2026-05-03", type: "easyRun" }),
    ],
    {
      goal: { race: "race_half_marathon", raceDate: null },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: {
          dataConfidence: "high",
          trainingBase: [
            {
              metric: "training_base_runs_per_week",
              value: 6,
              unit: "runs_per_week",
              date: "2026-04-20T00:00:00Z",
            },
          ],
        },
      },
      schedule: { trainingDays: 3, hardDays: [] },
    },
  );

  assert.equal(trainingCountForTest(result), 3);
});

Deno.test("avoidHardDayTraining treats leg strength preferred days as hard days", () => {
  const result = avoidHardDayTraining(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        weekNumber: 1,
        type: "intervals",
      }),
      session({
        id: "w1-tue-easy",
        date: "2026-04-28",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({
      trainingDays: 2,
      hardDays: [],
      strengthPreferences: {
        weeklyFrequency: 1,
        categories: ["lower_body"],
        preferredDays: ["day_mon"],
        sameDayOrder: "run_first",
      },
    }),
  );

  const monday = result.find((item) => item.date === "2026-04-27");
  assert.equal(monday?.type, "easyRun");
  const hardSession = result.find((item) => item.type === "intervals");
  assert.notEqual(hardSession?.date, "2026-04-27");
});

Deno.test("avoidHardDayTraining ignores upper-body-only strength days", () => {
  const result = avoidHardDayTraining(
    [
      session({
        id: "w1-mon-intervals",
        date: "2026-04-27",
        weekNumber: 1,
        type: "intervals",
      }),
      session({
        id: "w1-tue-easy",
        date: "2026-04-28",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({
      trainingDays: 2,
      hardDays: [],
      strengthPreferences: {
        weeklyFrequency: 1,
        categories: ["upper_body"],
        preferredDays: ["day_mon"],
        sameDayOrder: "run_first",
      },
    }),
  );

  const monday = result.find((item) => item.date === "2026-04-27");
  assert.equal(monday?.type, "intervals");
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

Deno.test("normalizeWeekNumbersFromDates corrects week labels from planStartDate anchor", () => {
  const normalized = normalizeWeekNumbersFromDates(
    [
      session({
        id: "w1-2026-06-09-easyRun",
        date: "2026-06-09",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-11-easyRun",
        date: "2026-06-11",
        weekNumber: 1,
        type: "easyRun",
      }),
      session({
        id: "w2-2026-06-16-longRun",
        date: "2026-06-16",
        weekNumber: 2,
        type: "longRun",
      }),
      session({
        id: "w2-2026-06-18-restDay",
        date: "2026-06-18",
        weekNumber: 2,
        type: "restDay",
      }),
    ],
    profile({ race: "race_half_marathon", planStartDate: "2026-06-04" }),
    new Date(Date.UTC(2026, 5, 4, 12)),
    "2026-06-04",
  );

  assert.equal(
    normalized.find((session) => session.date === "2026-06-09")?.weekNumber,
    2,
  );
  assert.equal(
    normalized.find((session) => session.date === "2026-06-11")?.weekNumber,
    2,
  );
  assert.equal(
    normalized.find((session) => session.date === "2026-06-16")?.weekNumber,
    3,
  );
  assert.equal(
    normalized.find((session) => session.date === "2026-06-18")?.weekNumber,
    3,
  );
});

Deno.test("normalizeWeekNumbersFromDates does not create invalid pre-anchor week numbers", () => {
  const normalized = normalizeWeekNumbersFromDates(
    [
      session({
        id: "w1-2026-05-31-easyRun",
        date: "2026-05-31",
        weekNumber: 1,
        type: "easyRun",
      }),
    ],
    profile({ race: "race_half_marathon", planStartDate: "2026-06-04" }),
    new Date(Date.UTC(2026, 5, 4, 12)),
    "2026-06-04",
  );

  assert.equal(normalized[0].weekNumber, 1);
});

Deno.test(
  "ensureFullCalendarWeeks adds partial first week from midweek planStartDate",
  () => {
    const normalized = normalizeWeekNumbersFromDates(
      [
        session({
          id: "w1-2026-06-09-easyRun",
          date: "2026-06-09",
          weekNumber: 1,
          type: "easyRun",
        }),
        session({
          id: "w1-2026-06-11-easyRun",
          date: "2026-06-11",
          weekNumber: 1,
          type: "easyRun",
        }),
        session({
          id: "w2-2026-06-16-longRun",
          date: "2026-06-16",
          weekNumber: 2,
          type: "longRun",
        }),
        session({
          id: "w2-2026-06-18-restDay",
          date: "2026-06-18",
          weekNumber: 2,
          type: "restDay",
        }),
      ],
      profile({
        race: "race_half_marathon",
        planStartDate: "2026-06-04",
      }),
      new Date(Date.UTC(2026, 5, 4, 12)),
      "2026-06-04",
    );
    const withCalendar = ensureFullCalendarWeeks(
      normalized,
      "en",
      "2026-06-04",
    );

    assert.equal(
      withCalendar.filter((session) => session.weekNumber === 1).length,
      4,
    );
    assert.ok(!withCalendar.some((session) => session.date < "2026-06-04"));
    assert.equal(
      withCalendar.filter((session) =>
        session.weekNumber === 1 && session.type !== "restDay"
      ).length,
      0,
    );
    assert.equal(
      withCalendar.filter((session) =>
        session.weekNumber === 1 &&
        ["2026-06-04", "2026-06-05", "2026-06-06", "2026-06-07"].includes(
          session.date,
        )
      ).length,
      4,
    );
  },
);

Deno.test(
  "date-based week normalization with session id regeneration removes week mismatch violations",
  () => {
    const normalized = normalizeWeekNumbersFromDates(
      [
        session({
          id: "w1-2026-06-09-easyRun",
          date: "2026-06-09",
          weekNumber: 1,
          type: "easyRun",
        }),
        session({
          id: "w1-2026-06-11-easyRun",
          date: "2026-06-11",
          weekNumber: 1,
          type: "easyRun",
        }),
        session({
          id: "w2-2026-06-16-longRun",
          date: "2026-06-16",
          weekNumber: 2,
          type: "longRun",
        }),
        session({
          id: "w2-2026-06-18-restDay",
          date: "2026-06-18",
          weekNumber: 2,
          type: "restDay",
        }),
      ],
      profile({ race: "race_half_marathon", planStartDate: "2026-06-04" }),
      new Date(Date.UTC(2026, 5, 4, 12)),
      "2026-06-04",
    );
    const withCalendar = ensureFullCalendarWeeks(
      normalized,
      "en",
      "2026-06-04",
    );
    const withIds = normalizeSessionIds(withCalendar);

    const violations = validateGeneratedPlanShape(
      withIds,
      3,
      profile({ race: "race_half_marathon", planStartDate: "2026-06-04" }),
      new Date(Date.UTC(2026, 5, 12, 12)),
      "2026-06-04",
    );
    assert.ok(
      !violations.some((violation) =>
        violation.rule === "session_date_week_mismatch"
      ),
    );
    assert.equal(
      withIds.find((session) => session.date === "2026-06-09")?.id,
      "w2-2026-06-09-easyRun",
    );
  },
);

Deno.test(
  "ensureFullCalendarWeeks with midweek planStartDate does not add pre-start dates",
  () => {
    const sessions = ensureFullCalendarWeeks(
      [
        session({ id: "w1-wed-run", date: "2026-06-10", type: "easyRun" }),
        session({ id: "w1-thu-run", date: "2026-06-11", type: "easyRun" }),
        session({ id: "w1-fri-run", date: "2026-06-12", type: "easyRun" }),
      ],
      "en",
      "2026-06-10",
    );

    assert.ok(!sessions.some((item) => item.date === "2026-06-08"));
    assert.ok(!sessions.some((item) => item.date === "2026-06-09"));
    assert.equal(sessions.length, 5);
    assert.equal(findByDate(sessions, "2026-06-10").type, "easyRun");
    assert.equal(findByDate(sessions, "2026-06-11").type, "easyRun");
    assert.equal(findByDate(sessions, "2026-06-12").type, "easyRun");
    assert.equal(findByDate(sessions, "2026-06-13").type, "restDay");
    assert.equal(findByDate(sessions, "2026-06-14").type, "restDay");
  },
);

Deno.test("validateGeneratedPlanShape does not require generated race workout on fixed race date", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-01-easyRun",
        date: "2026-06-01",
        weekNumber: 1,
      }),
      session({
        id: "w2-2026-06-08-easyRun",
        date: "2026-06-08",
        weekNumber: 2,
      }),
      session({
        id: "w3-2026-06-20-easyRun",
        date: "2026-06-20",
        weekNumber: 3,
      }),
    ],
    3,
    profile({ race: "race_5k", raceDate: "2026-06-21" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
    "2026-06-01",
  );

  assert.deepEqual(violations, []);
});

Deno.test("enforcePreRaceTaper uses fixed race date without generated race workout", () => {
  const sessions = enforcePreRaceTaper(
    [
      session({
        id: "w3-2026-06-13-tempoRun",
        date: "2026-06-13",
        weekNumber: 3,
        type: "tempoRun",
        durationMinutes: 45,
      }),
      session({
        id: "w3-2026-06-12-easyRun",
        date: "2026-06-12",
        weekNumber: 3,
        type: "easyRun",
      }),
    ],
    profile({
      race: "race_5k",
      raceDate: "2026-06-15",
    }),
  );

  const tapered = findSession(sessions, "w3-2026-06-13-tempoRun");
  assert.equal(tapered.type, "recoveryRun");
  assert.equal(tapered.targetZone, "recovery");
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
    policy.allowedTypes.includes("hillRepeats"),
    "experienced specific should allow hillRepeats",
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

Deno.test("normalizePeakLongRun raises 10K peak long run with strong Strava/mixed evidence above table max", () => {
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
  const profileData = {
    goal: { race: "race_10k" },
    fitness: {
      experience: "experience_intermediate",
      stravaCoachingProfile: { dataConfidence: "high" },
    },
    schedule: { hardDays: [] },
  };

  const briefSources = ["strava", "mixed"] as const;
  const expectedNormalizedPeak = 14.85;
  for (const source of briefSources) {
    const result = normalizePeakLongRun(
      sessions,
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "tenK",
        readinessLevel: "prepared",
        confidence: "high",
        source,
        currentVolumeKmPerWeek: 45,
        recentLongRunKm: 22,
        longRunCeilingKm: 15,
        planLengthWeeks: 12,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Protect base." },
          { phase: "build", weeks: 3, focus: "Build quality." },
          { phase: "specific", weeks: 3, focus: "Build specificity." },
          { phase: "peak", weeks: 1, focus: "Peak long run." },
          { phase: "taperRace", weeks: 2, focus: "Freshen up." },
        ],
      }),
    );

    const peakLongRun = result.find((s) =>
      s.weekNumber === 10 && s.type === "longRun"
    );
    assert.ok(peakLongRun, `peak phase longRun should exist for ${source}`);
    const normalizedPeak = peakLongRun!.distanceKm ?? 0;
    assert.ok(
      normalizedPeak > 13 && normalizedPeak < 15,
      `10K peak long run should be raised above static table max for ${source}, got ${normalizedPeak}`,
    );
    assert.ok(
      Math.abs(normalizedPeak - expectedNormalizedPeak) < 0.01,
      `expected evidence-aware target around 14.85km for ${source}, got ${normalizedPeak}`,
    );
    assert.ok(
      normalizedPeak <= expectedNormalizedPeak + 0.01,
      `evidence-aware cap should remain near recent-long-run target for ${source}, got ${normalizedPeak}`,
    );
    assert.ok(
      normalizedPeak <= 15,
      "result should respect coaching brief ceiling",
    );
  }
});

Deno.test(
  "normalizePeakLongRun raises 10K peak long run with medium-confidence Strava evidence",
  () => {
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
    const profileData = {
      goal: { race: "race_10k" },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: { dataConfidence: "high" },
      },
      schedule: { hardDays: [] },
    };

    const result = normalizePeakLongRun(
      sessions,
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "tenK",
        readinessLevel: "prepared",
        confidence: "medium",
        source: "strava",
        currentVolumeKmPerWeek: 45,
        recentLongRunKm: 22,
        longRunCeilingKm: 15,
        planLengthWeeks: 12,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Protect base." },
          { phase: "build", weeks: 3, focus: "Build quality." },
          { phase: "specific", weeks: 3, focus: "Build specificity." },
          { phase: "peak", weeks: 1, focus: "Peak long run." },
          { phase: "taperRace", weeks: 2, focus: "Freshen up." },
        ],
      }),
    );

    const peakLongRun = result.find((s) =>
      s.weekNumber === 10 && s.type === "longRun"
    );
    assert.ok(peakLongRun, "peak phase longRun should exist");
    assert.ok(
      Math.abs((peakLongRun!.distanceKm ?? 0) - 14.85) < 0.01,
      `expected medium-confidence evidence-aware target around 14.85km, got ${
        peakLongRun!.distanceKm
      }`,
    );
  },
);

Deno.test(
  "normalizePeakLongRun does not raise above static table for low-confidence coaching evidence",
  () => {
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
    const profileData = {
      goal: { race: "race_10k" },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: { dataConfidence: "high" },
      },
      schedule: { hardDays: [] },
    };

    const result = normalizePeakLongRun(
      sessions,
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "tenK",
        readinessLevel: "prepared",
        confidence: "limited",
        source: "strava",
        currentVolumeKmPerWeek: 45,
        recentLongRunKm: 22,
        longRunCeilingKm: 15,
        planLengthWeeks: 12,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Protect base." },
          { phase: "build", weeks: 3, focus: "Build quality." },
          { phase: "specific", weeks: 3, focus: "Build specificity." },
          { phase: "peak", weeks: 1, focus: "Peak long run." },
          { phase: "taperRace", weeks: 2, focus: "Freshen up." },
        ],
      }),
    );

    const peakLongRun = result.find((s) =>
      s.weekNumber === 10 && s.type === "longRun"
    );
    assert.ok(peakLongRun, "peak phase longRun should exist");
    assert.equal(peakLongRun!.distanceKm, 12);
  },
);

Deno.test(
  "normalizePeakLongRun requires usable current volume for evidence lift",
  () => {
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
    const profileData = {
      goal: { race: "race_10k" },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: { dataConfidence: "high" },
      },
      schedule: { hardDays: [] },
    };

    const invalidCurrentVolumeCases = [
      {
        label: "missing",
        currentVolumeKmPerWeek: undefined as unknown as number,
      },
      { label: "zero", currentVolumeKmPerWeek: 0 },
      { label: "negative", currentVolumeKmPerWeek: -10 },
    ];

    for (const { label, currentVolumeKmPerWeek } of invalidCurrentVolumeCases) {
      const brief = {
        ...coachingBriefFixture({
          raceType: "tenK",
          readinessLevel: "prepared",
          confidence: "high",
          source: "strava",
          currentVolumeKmPerWeek,
          recentLongRunKm: 22,
          longRunCeilingKm: 15,
          planLengthWeeks: 12,
          phaseStrategy: [
            { phase: "base", weeks: 3, focus: "Protect base." },
            { phase: "build", weeks: 3, focus: "Build quality." },
            { phase: "specific", weeks: 3, focus: "Build specificity." },
            { phase: "peak", weeks: 1, focus: "Peak long run." },
            { phase: "taperRace", weeks: 2, focus: "Freshen up." },
          ],
        }),
      } as CoachingBrief;

      const result = normalizePeakLongRun(
        sessions,
        profileData,
        12,
        "en",
        brief,
      );

      const peakLongRun = result.find((s) =>
        s.weekNumber === 10 && s.type === "longRun"
      );
      assert.ok(
        peakLongRun,
        `peak phase longRun should exist for ${label} current volume`,
      );
      assert.equal(
        peakLongRun!.distanceKm,
        12,
        `evidence lift should not apply for ${label} current volume`,
      );
    }
  },
);

Deno.test(
  "normalizePeakLongRun shows guardrail suppression wording when evidence lift is blocked",
  () => {
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
    const profileData = {
      goal: { race: "race_10k" },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: {
          dataConfidence: "high",
          recoveryGuardrails: [
            {
              category: "recovery_load_spike",
              priority: 2,
              message: "Recent load spike",
            },
          ],
        },
      },
      stravaCoachingProfile: {
        dataConfidence: "high",
        recoveryGuardrails: [
          {
            category: "recovery_load_spike",
            priority: 2,
            message: "Recent load spike",
          },
        ],
      },
      schedule: { hardDays: [] },
    };

    const result = normalizePeakLongRun(
      sessions,
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "tenK",
        readinessLevel: "prepared",
        confidence: "high",
        source: "strava",
        currentVolumeKmPerWeek: 45,
        recentLongRunKm: 22,
        longRunCeilingKm: 15,
        planLengthWeeks: 12,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Protect base." },
          { phase: "build", weeks: 3, focus: "Build quality." },
          { phase: "specific", weeks: 3, focus: "Build specificity." },
          { phase: "peak", weeks: 1, focus: "Peak long run." },
          { phase: "taperRace", weeks: 2, focus: "Freshen up." },
        ],
      }),
    );

    const peakLongRun = result.find((s) =>
      s.weekNumber === 10 && s.type === "longRun"
    );
    assert.ok(peakLongRun, "peak phase longRun should exist");
    assert.equal(peakLongRun!.distanceKm, 12);
    assert.match(
      peakLongRun!.coachNote ?? "",
      /safety limit.*guardrails/i,
    );
    assert.match(
      peakLongRun!.coachNote ?? "",
      /evidence-based increase.*blocked/i,
    );
  },
);

Deno.test("normalizePeakLongRun does not raise above static table for manual brief evidence", () => {
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
  const profileData = {
    goal: { race: "race_10k" },
    fitness: {
      experience: "experience_intermediate",
      stravaCoachingProfile: { dataConfidence: "high" },
    },
    schedule: { hardDays: [] },
  };

  const result = normalizePeakLongRun(
    sessions,
    profileData,
    12,
    "en",
    coachingBriefFixture({
      raceType: "tenK",
      readinessLevel: "prepared",
      confidence: "high",
      source: "manual",
      currentVolumeKmPerWeek: 45,
      recentLongRunKm: 22,
      longRunCeilingKm: 15,
      planLengthWeeks: 12,
      phaseStrategy: [
        { phase: "base", weeks: 3, focus: "Protect base." },
        { phase: "build", weeks: 3, focus: "Build quality." },
        { phase: "specific", weeks: 3, focus: "Build specificity." },
        { phase: "peak", weeks: 1, focus: "Peak long run." },
        { phase: "taperRace", weeks: 2, focus: "Freshen up." },
      ],
    }),
  );

  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.equal(peakLongRun!.distanceKm, 12);
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

Deno.test("normalizePeakLongRun does not raise coaching-brief taper long run treated as legacy peak", () => {
  const profileData = profile({
    race: "race_half_marathon",
    experience: "experience_beginner",
  });
  const brief = coachingBriefFixture({
    raceType: "halfMarathon",
    planLengthWeeks: 8,
    taper: {
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: "Fresh legs.",
    },
    phaseStrategy: [
      { phase: "base", weeks: 2, focus: "Protect base." },
      { phase: "build", weeks: 2, focus: "Controlled threshold." },
      { phase: "specific", weeks: 2, focus: "Race-specific rhythm." },
      { phase: "taperRace", weeks: 2, focus: "Freshen up." },
    ],
  });
  const sessions = [
    session({
      id: "w6-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 14,
      durationMinutes: 96,
      weekNumber: 6,
    }),
    session({
      id: "w7-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 8,
      durationMinutes: 56,
      weekNumber: 7,
    }),
    session({
      id: "w8-sat",
      date: "2026-07-04",
      type: "racePaceRun",
      distanceKm: 21.1,
      weekNumber: 8,
    }),
  ];

  assert.equal(phaseForWeek(7, 8, profileData), "peak");
  assert.equal(
    phaseForWeekFromCoachingBrief(7, 8, profileData, brief),
    "taperRace",
  );

  const result = normalizePeakLongRun(
    sessions,
    profileData,
    8,
    "en",
    brief,
  );
  const taperLongRun = result.find((s) =>
    s.weekNumber === 7 && s.type === "longRun"
  );

  assert.ok(taperLongRun, "week 7 taper longRun should exist");
  assert.equal(taperLongRun!.distanceKm, 8);
  assert.equal(taperLongRun!.durationMinutes, 56);
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

Deno.test("normalizePeakLongRun respects athleteSummary history floor when present", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 8,
      durationMinutes: 50,
      weekNumber: 1,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 8,
      durationMinutes: 52,
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
    {
      goal: { race: "race_half_marathon" },
      fitness: {
        experience: "experience_beginner",
        athleteSummary: { longestRecentRunKm: 14 },
      },
    },
    12,
    "en",
  );
  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );

  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(peakLongRun!.distanceKm != null, "distance should be present");
  assert.ok(
    peakLongRun!.distanceKm! >= 12.5,
    `peak long run should respect history floor, got ${
      peakLongRun!.distanceKm
    }`,
  );
});

Deno.test("normalizePeakLongRun uses fresh Strava endurance evidence over legacy athleteSummary", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 4,
      durationMinutes: 32,
      weekNumber: 1,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 4,
      durationMinutes: 28,
      weekNumber: 10,
    }),
    session({
      id: "w12-sat",
      date: "2026-07-11",
      type: "racePaceRun",
      distanceKm: 5,
      weekNumber: 12,
    }),
  ];

  const result = normalizePeakLongRun(
    sessions,
    {
      goal: { race: "race_5k", raceDate: null },
      fitness: {
        experience: "experience_beginner",
        athleteSummary: {
          longestRecentRunKm: 40,
        },
      },
      stravaCoachingProfile: {
        dataConfidence: "high",
        endurance: [
          {
            metric: "endurance_long_run_km",
            value: 6,
            unit: "km",
            date: "2026-06-01T00:00:00Z",
          },
        ],
      },
      schedule: { hardDays: [] },
    },
    12,
    "en",
  );

  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  const normalizedPeak = peakLongRun!.distanceKm ?? 0;
  assert.ok(
    normalizedPeak >= 5.4 && normalizedPeak < 7,
    `fresh Strava endurance evidence should dominate legacy history, got ${normalizedPeak}`,
  );
});

Deno.test("normalizePeakLongRun clamps aggressive acceptedRaceTarget to safety caps", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 8,
      durationMinutes: 52,
      weekNumber: 1,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 40,
      durationMinutes: 240,
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
    {
      goal: { race: "race_half_marathon" },
      acceptedRaceTarget: {
        distanceKm: 42.2,
        primaryTimeMs: 10000,
        stretchTimeMs: 9000,
        confidence: "high",
        evidence: [],
      },
      fitness: {
        experience: "experience_intermediate",
        stravaCoachingProfile: {
          dataConfidence: "high",
          trainingBase: [
            {
              metric: "training_base_weekly_km",
              value: 20,
              unit: "km_per_week",
              date: "2026-06-01T00:00:00Z",
            },
          ],
          endurance: [
            {
              metric: "endurance_long_run_km",
              value: 32,
              unit: "km",
              date: "2026-06-01T00:00:00Z",
            },
          ],
        },
      },
      schedule: { hardDays: [] },
    },
    12,
    "en",
  );

  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(
    peakLongRun!.distanceKm! <= 18,
    `aggressive target or fast evidence must not push peak long run over safety cap, got ${
      peakLongRun!.distanceKm
    }`,
  );
});

Deno.test("normalizePeakLongRun ignores limited evidence when guardrails are weak", () => {
  const sessions = [
    session({
      id: "w1-sat",
      date: "2026-04-25",
      type: "longRun",
      distanceKm: 8,
      durationMinutes: 52,
      weekNumber: 1,
    }),
    session({
      id: "w10-sat",
      date: "2026-06-27",
      type: "longRun",
      distanceKm: 40,
      durationMinutes: 240,
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
    {
      goal: { race: "race_half_marathon" },
      fitness: {
        experience: "experience_intermediate",
        athleteSummary: { longestRecentRunKm: 4 },
        stravaCoachingProfile: {
          dataConfidence: "limited",
          trainingBase: [
            {
              metric: "training_base_weekly_km",
              value: 20,
              unit: "km_per_week",
              date: "2026-06-01T00:00:00Z",
            },
          ],
          endurance: [
            {
              metric: "endurance_long_run_km",
              value: 40,
              unit: "km",
              date: "2026-06-01T00:00:00Z",
            },
          ],
          recoveryGuardrails: [
            {
              category: "recovery_sparse_data",
              priority: 2,
              message: "limited history",
            },
          ],
        },
      },
      schedule: { hardDays: [] },
    },
    12,
    "en",
  );

  const peakLongRun = result.find((s) =>
    s.weekNumber === 10 && s.type === "longRun"
  );
  assert.ok(peakLongRun, "peak phase longRun should exist");
  assert.ok(
    peakLongRun!.distanceKm! <= 18,
    `limited or sparse evidence should not raise safety cap, got ${
      peakLongRun!.distanceKm
    }`,
  );
});

Deno.test(
  "normalizeWorkoutTypesByPhase uses coaching brief readiness over missing profile experience",
  () => {
    const sessions = [
      session({
        id: "w3-progress",
        date: "2026-04-16",
        type: "tempoRun",
        weekNumber: 3,
      }),
    ];

    const profileData: Record<string, unknown> = {
      goal: { race: "race_10k", raceDate: null },
      fitness: {},
      schedule: { hardDays: [] },
    };

    const withoutBrief = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      8,
      "en",
    );
    assert.equal(
      findSession(withoutBrief, "w3-progress").type,
      "fartlek",
      "missing profile experience should use beginner-only workout policy",
    );

    const withPreparedBrief = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      8,
      "en",
      coachingBriefFixture({
        raceType: "tenK",
        readinessLevel: "prepared",
        planLengthWeeks: 8,
      }),
    );
    assert.equal(
      findSession(withPreparedBrief, "w3-progress").type,
      "tempoRun",
      "prepared brief should map to intermediate and allow tempo in build",
    );
  },
);

Deno.test(
  "normalizeWorkoutTypesByPhase race-ready brief unlocks peak threshold training",
  () => {
    const sessions = [
      session({
        id: "w10-threshold",
        date: "2026-05-02",
        type: "thresholdRun",
        weekNumber: 10,
      }),
    ];

    const profileData: Record<string, unknown> = {
      goal: { race: "race_marathon", raceDate: null },
      fitness: {},
      schedule: { hardDays: [] },
    };

    const withoutBrief = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      12,
      "en",
    );
    assert.equal(
      findSession(withoutBrief, "w10-threshold").type,
      "longRun",
      "missing profile experience should not keep threshold in peak",
    );

    const withRaceReadyBrief = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "marathon",
        readinessLevel: "raceReady",
        planLengthWeeks: 12,
      }),
    );
    assert.equal(
      findSession(withRaceReadyBrief, "w10-threshold").type,
      "thresholdRun",
      "race-ready brief should map to experienced and keep threshold in peak",
    );
  },
);

Deno.test("normalizeWorkoutTypesByPhase keeps brand-new brief sessions conservative", () => {
  const sessions = [
    session({
      id: "w5-racepace",
      date: "2026-04-22",
      type: "racePaceRun",
      weekNumber: 5,
    }),
  ];

  const result = normalizeWorkoutTypesByPhase(
    sessions,
    {
      goal: { race: "race_marathon", raceDate: null },
      fitness: {},
      schedule: { hardDays: [] },
    },
    8,
    "en",
    coachingBriefFixture({
      raceType: "marathon",
      readinessLevel: "underprepared",
      planLengthWeeks: 8,
    }),
  );

  assert.equal(
    findSession(result, "w5-racepace").type,
    "progressionRun",
    "underprepared/brand-new should shift to a conservative replacement",
  );
});

Deno.test("workoutPolicyForPhase build phase is strict for brand-new", () => {
  const policy = workoutPolicyForPhase(
    "build",
    "fiveK",
    "experience_brand_new",
  );
  assert.ok(
    !policy.allowedTypes.includes("progressionRun"),
    "build should not allow progressionRun for brand-new",
  );
  assert.ok(
    policy.allowedTypes.includes("fartlek"),
    "build should allow fartlek for brand-new",
  );
  assert.ok(
    policy.maxStressDays <= 2,
    "brand-new build should keep maxStressDays conservative",
  );
});

Deno.test(
  "detectSessionTypePolicyViolations recommends the same replacement as normalization",
  () => {
    const sessions = [
      session({
        id: "w4-intervals",
        date: "2026-04-29",
        type: "intervals",
        weekNumber: 4,
      }),
    ];

    const profileData: Record<string, unknown> = {
      goal: { race: "race_marathon", raceDate: null },
      fitness: { experience: "experience_intermediate" },
      schedule: { hardDays: [] },
    };

    const normalized = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      12,
      "en",
    );

    const violations = detectSessionTypePolicyViolations(
      sessions,
      profileData,
      12,
      null,
    );

    assert.equal(violations.length, 1);
    const violation = violations[0];
    const normalizedType = findSession(normalized, "w4-intervals").type;
    assert.equal(violation.recommendedType, normalizedType);
    assert.equal(violation.currentType, "intervals");
    assert.ok(violation.reason.includes("build"));
    assert.ok(violation.reason.includes("marathon"));
    assert.ok(violation.reason.includes("intermediate"));
    assert.ok(violation.reason.includes("recommend"));
    assert.ok(violation.reason.includes("intervals"));
  },
);

Deno.test(
  "detectSessionTypePolicyViolations recommends the same taper replacement as normalization",
  () => {
    const sessions = [
      session({
        id: "w11-intervals",
        date: "2026-07-08",
        type: "intervals",
        weekNumber: 11,
      }),
    ];

    const profileData: Record<string, unknown> = {
      goal: { race: "race_5k", raceDate: null },
      fitness: { experience: "experience_intermediate" },
      schedule: { hardDays: [] },
    };

    const normalized = normalizeWorkoutTypesByPhase(
      sessions,
      profileData,
      12,
      "en",
    );

    const violations = detectSessionTypePolicyViolations(
      sessions,
      profileData,
      12,
      null,
    );

    assert.equal(violations.length, 1);
    const violation = violations[0];
    const normalizedType = findSession(normalized, "w11-intervals").type;
    assert.equal(violation.recommendedType, normalizedType);
    assert.equal(normalizedType, "fartlek");
    assert.equal(violation.phase, "taperRace");
  },
);

Deno.test(
  "detectSessionTypePolicyViolations reports base-phase intervals in intermediate profile",
  () => {
    const violations = detectSessionTypePolicyViolations(
      [
        session({
          id: "w2-intervals",
          date: "2026-04-08",
          type: "intervals",
          weekNumber: 2,
        }),
      ],
      {
        goal: { race: "race_half_marathon", raceDate: null },
        fitness: { experience: "experience_intermediate" },
      },
      8,
      null,
    );

    assert.equal(violations.length, 1);
    const violation = violations[0];
    assert.equal(violation.code, "session_type_not_allowed_for_phase");
    assert.equal(violation.sessionId, "w2-intervals");
    assert.equal(violation.phase, "base");
    assert.equal(violation.currentType, "intervals");
    assert.deepEqual(
      violation.allowedTypes,
      [
        "easyRun",
        "recoveryRun",
        "longRun",
        "restDay",
        "fartlek",
        "progressionRun",
      ],
    );
    assert.equal(violation.recommendedType, "fartlek");
  },
);

Deno.test(
  "detectSessionTypePolicyViolations uses coachingBrief readiness for policy selection",
  () => {
    const sessions = [
      session({
        id: "w2-progression",
        date: "2026-04-08",
        type: "progressionRun",
        weekNumber: 2,
      }),
    ];
    const profileData = {
      goal: { race: "race_half_marathon", raceDate: null },
      fitness: { experience: "experience_beginner" },
    };

    const withoutBrief = detectSessionTypePolicyViolations(
      sessions,
      profileData,
      8,
      null,
    );
    const withRaceReadyBrief = detectSessionTypePolicyViolations(
      sessions,
      profileData,
      8,
      coachingBriefFixture({ readinessLevel: "raceReady" }),
    );

    assert.equal(withoutBrief.length, 1);
    assert.equal(
      withRaceReadyBrief.length,
      0,
      "raceReady readiness should raise policy experience for policy selection",
    );
  },
);

Deno.test(
  "detectSessionTypePolicyViolations skips valid session types and goal-race sessions",
  () => {
    const violations = detectSessionTypePolicyViolations(
      [
        session({
          id: "w1-easy",
          date: "2026-04-01",
          type: "easyRun",
          weekNumber: 1,
        }),
        session({
          id: "w2-race",
          date: "2026-04-15",
          type: "racePaceRun",
          weekNumber: 2,
        }),
      ],
      {
        goal: { race: "race_half_marathon", raceDate: "2026-04-15" },
        fitness: { experience: "experience_intermediate" },
      },
      8,
      null,
    );

    assert.equal(violations.length, 0);
  },
);

Deno.test("mergeTargetedSessionRepairs applies only valid repairs", () => {
  const originalSessions: GeneratedSession[] = [
    session({
      id: "w1-intervals",
      date: "2026-04-08",
      type: "intervals",
      weekNumber: 2,
      coachNote: "Original coach note",
    }),
    session({
      id: "w2-tempo",
      date: "2026-04-15",
      type: "tempoRun",
      weekNumber: 3,
    }),
  ];

  const requestedSessionIds = ["w1-intervals", "w2-tempo"];
  const repairs: SessionRepairCandidate[] = [
    {
      sessionId: "w1-intervals",
      repairedSession: {
        ...session({
          id: "w1-intervals",
          date: "2026-04-08",
          type: "easyRun",
          weekNumber: 2,
          coachNote: "Repaired with AI note",
        }),
        durationMinutes: 55,
      },
    },
    {
      sessionId: "w2-tempo",
      repairedSession: {
        ...session({
          id: "w2-tempo",
          date: "2026-04-01",
          type: "easyRun",
          weekNumber: 3,
          coachNote: "Wrong date, should be skipped",
        }),
        durationMinutes: 55,
      },
    },
    {
      sessionId: "w3-missing",
      repairedSession: {
        ...session({
          id: "w3-missing",
          date: "2026-04-22",
          type: "easyRun",
          weekNumber: 4,
        }),
      },
    },
  ];

  const result = mergeTargetedSessionRepairs(
    originalSessions,
    requestedSessionIds,
    repairs,
    profile({
      experience: "experience_beginner",
      race: "race_half_marathon",
    }),
    8,
  );

  assert.equal(result.sessions.length, 2);
  assert.equal(
    findSession(result.sessions, "w1-intervals").type,
    "easyRun",
  );
  assert.equal(
    findSession(result.sessions, "w1-intervals").coachNote,
    "Repaired with AI note",
  );
  assert.equal(
    findSession(result.sessions, "w2-tempo").type,
    "tempoRun",
  );
  assert.deepEqual(
    result.preservedCoachNoteSessionIds,
    ["w1-intervals"],
  );
});

Deno.test(
  "mergeTargetedSessionRepairs rejects repairs whose session type violates phase policy",
  () => {
    const originalSessions: GeneratedSession[] = [
      session({
        id: "w1-repair",
        date: "2026-04-08",
        type: "easyRun",
        weekNumber: 2,
        coachNote: "Original coach note",
      }),
    ];

    const requestedSessionIds = ["w1-repair"];
    const repairs: SessionRepairCandidate[] = [{
      sessionId: "w1-repair",
      repairedSession: {
        ...session({
          id: "w1-repair",
          date: "2026-04-08",
          type: "thresholdRun",
          weekNumber: 2,
          coachNote: "AI note should be dropped",
        }),
      },
    }];

    const result = mergeTargetedSessionRepairs(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({
        experience: "experience_beginner",
        race: "race_half_marathon",
      }),
      8,
    );

    assert.equal(findSession(result.sessions, "w1-repair").type, "easyRun");
    assert.deepEqual(
      result.preservedCoachNoteSessionIds,
      [],
    );
    assert.equal(
      findSession(result.sessions, "w1-repair").coachNote,
      "Original coach note",
    );
  },
);

Deno.test(
  "mergeTargetedSessionRepairs rejection allows deterministic fallback to normalize policy",
  () => {
    const originalSessions: GeneratedSession[] = [
      session({
        id: "w1-violating",
        date: "2026-04-08",
        type: "thresholdRun",
        weekNumber: 2,
        coachNote: "Original violating note",
      }),
    ];
    const requestedSessionIds = ["w1-violating"];
    const repairs: SessionRepairCandidate[] = [{
      sessionId: "w1-violating",
      repairedSession: {
        ...session({
          id: "w1-violating",
          date: "2026-04-08",
          type: "thresholdRun",
          weekNumber: 2,
          coachNote: "AI note should not be preserved",
        }),
      },
    }];

    const result = mergeTargetedSessionRepairs(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({
        experience: "experience_beginner",
        race: "race_half_marathon",
      }),
      8,
    );
    const normalized = normalizeWorkoutTypesByPhase(
      result.sessions,
      profile({
        experience: "experience_beginner",
        race: "race_half_marathon",
      }),
      8,
      "en",
      null,
      result.preservedCoachNoteSessionIds,
    );

    const normalizedSession = findSession(normalized, "w1-violating");
    assert.equal(normalizedSession.type, "easyRun");
    assert.equal(
      normalizedSession.coachNote,
      "Adjusted to match phase-appropriate training.",
    );
    assert.deepEqual(result.preservedCoachNoteSessionIds, []);
  },
);

Deno.test(
  "mergeTargetedSessionRepairPatches applies valid patches and rejects invalid ones",
  () => {
    const originalSessions: GeneratedSession[] = [
      {
        ...session({
          id: "w1-targeted",
          date: "2026-04-08",
          type: "easyRun",
          weekNumber: 1,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
      {
        ...session({
          id: "w2-targeted",
          date: "2026-04-10",
          type: "easyRun",
          weekNumber: 2,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
      {
        ...session({
          id: "w3-targeted",
          date: "2026-04-12",
          type: "easyRun",
          weekNumber: 3,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
      {
        ...session({
          id: "w4-targeted",
          date: "2026-04-14",
          type: "easyRun",
          weekNumber: 3,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
    ];

    const requestedSessionIds = [
      "w1-targeted",
      "w2-targeted",
      "w3-targeted",
      "w4-targeted",
      "w5-targeted",
    ];
    const repairs: TargetedSessionRepairPatchItem[] = [
      {
        sessionId: "w1-targeted",
        type: "longRun",
        coachNote: "Shift this to a longer controlled effort.",
        workoutTarget: easyWorkouts().longRunTarget,
        distanceKm: 14,
        durationMinutes: 75,
      },
      {
        sessionId: "w2-targeted",
        type: "thresholdRun",
        coachNote: "This should be rejected for type policy.",
        workoutTarget: easyWorkouts().easyTarget,
      },
      {
        sessionId: "w3-targeted",
        type: "easyRun",
        coachNote: "Adjusted to match phase-appropriate training",
      },
      {
        sessionId: "w4-targeted",
        type: "easyRun",
        coachNote: "Keep this run easy and focused.",
      },
      {
        sessionId: "w5-targeted",
        type: "easyRun",
        coachNote: "I was requested but I do not exist.",
      },
      {
        sessionId: "w6-not-requested",
        type: "easyRun",
        coachNote: "I was never requested.",
      },
    ];

    const result = mergeTargetedSessionRepairPatches(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({
        experience: "experience_beginner",
        race: "race_half_marathon",
      }),
      8,
    );

    assert.equal(result.acceptedSessionIds.length, 2);
    assert.deepEqual(result.acceptedSessionIds, ["w1-targeted", "w4-targeted"]);
    assert.equal(result.rejectedRepairs.length, 4);

    const patched = findSession(result.sessions, "w1-targeted");
    assert.equal(patched.type, "longRun");
    assert.equal(patched.coachNote, "Shift this to a longer controlled effort.");
    assert.equal(patched.distanceKm, 14);
    assert.equal(patched.durationMinutes, 75);

    assert.equal(
      findSession(result.sessions, "w2-targeted").type,
      "easyRun",
    );
    assert.equal(
      findSession(result.sessions, "w3-targeted").coachNote,
      null,
    );
    assert.equal(
      findSession(result.sessions, "w4-targeted").coachNote,
      "Keep this run easy and focused.",
    );
    assert.equal(findSession(result.sessions, "w4-targeted").type, "easyRun");
    assert.ok(
      result.rejectedRepairs.some((item) =>
        item.sessionId === "w2-targeted" &&
        item.reason.includes("not allowed")
      ),
      JSON.stringify(result.rejectedRepairs),
    );
    assert.ok(
      result.rejectedRepairs.some((item) =>
        item.sessionId === "w3-targeted" &&
        item.reason.includes("policy-explanation")
      ),
      JSON.stringify(result.rejectedRepairs),
    );
    assert.ok(
      result.rejectedRepairs.some((item) =>
        item.sessionId === "w6-not-requested" &&
        item.reason.includes("not requested")
      ),
      JSON.stringify(result.rejectedRepairs),
    );
    assert.ok(
      result.rejectedRepairs.some((item) =>
        item.sessionId === "w5-targeted" &&
        item.reason.includes("does not match an existing session")
      ),
      JSON.stringify(result.rejectedRepairs),
    );
  },
);

Deno.test("mergeTargetedSessionRepairPatches rejects patch types that violate phase policy", () => {
  const originalSessions: GeneratedSession[] = [
    {
      ...session({
        id: "w1-violation",
        date: "2026-04-08",
        type: "easyRun",
        weekNumber: 2,
        coachNote: "Original coach note",
      }),
      workoutTarget: easyWorkouts().easyTarget,
    },
  ];

  const requestedSessionIds = ["w1-violation"];
  const repairs: TargetedSessionRepairPatchItem[] = [{
    sessionId: "w1-violation",
    type: "intervals",
    coachNote: "Try a harder variant.",
    workoutTarget: easyWorkouts().easyTarget,
  }];

  const result = mergeTargetedSessionRepairPatches(
    originalSessions,
    requestedSessionIds,
    repairs,
    profile({
      experience: "experience_brand_new",
      race: "race_half_marathon",
    }),
    8,
  );

  assert.equal(result.acceptedSessionIds.length, 0);
  assert.equal(result.rejectedRepairs.length, 1);
  assert.equal(result.rejectedRepairs[0].sessionId, "w1-violation");
  assert.ok(result.rejectedRepairs[0].reason.includes("not allowed"));
  assert.equal(
    findSession(result.sessions, "w1-violation").coachNote,
    "Original coach note",
  );
});

Deno.test("mergeTargetedSessionRepairPatches rejects generic policy copy in coachNote", () => {
  const originalSessions: GeneratedSession[] = [
    {
      ...session({
        id: "w1-copy",
        date: "2026-04-08",
        type: "easyRun",
        weekNumber: 2,
      }),
      workoutTarget: easyWorkouts().easyTarget,
    },
  ];

  const requestedSessionIds = ["w1-copy"];
  const repairs: TargetedSessionRepairPatchItem[] = [{
    sessionId: "w1-copy",
    type: "easyRun",
    coachNote: "Adjusted to keep hard training days spaced safely.",
    workoutTarget: easyWorkouts().easyTarget,
  }];

  const result = mergeTargetedSessionRepairPatches(
    originalSessions,
    requestedSessionIds,
    repairs,
    profile({ experience: "experience_intermediate", race: "race_5k" }),
    8,
  );

  assert.equal(result.acceptedSessionIds.length, 0);
  assert.equal(result.rejectedRepairs.length, 1);
  assert.ok(result.rejectedRepairs[0].reason.includes("disallowed"));
  assert.equal(findSession(result.sessions, "w1-copy").type, "easyRun");
  assert.equal(findSession(result.sessions, "w1-copy").coachNote, null);
});

Deno.test(
  "mergeTargetedSessionRepairPatches rejects additional backend/policy explanation copy",
  () => {
    const originalSessions: GeneratedSession[] = [
      {
        ...session({
          id: "w1-backend-copy",
          date: "2026-04-09",
          type: "easyRun",
          weekNumber: 2,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
    ];

    const requestedSessionIds = ["w1-backend-copy"];
    const repairs: TargetedSessionRepairPatchItem[] = [{
      sessionId: "w1-backend-copy",
      type: "easyRun",
      coachNote: "Changed to satisfy the backend policy.",
      workoutTarget: easyWorkouts().easyTarget,
    }];

    const result = mergeTargetedSessionRepairPatches(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({ experience: "experience_intermediate", race: "race_half_marathon" }),
      8,
    );

    assert.equal(result.acceptedSessionIds.length, 0);
    assert.equal(result.rejectedRepairs.length, 1);
    assert.ok(result.rejectedRepairs[0].reason.includes("disallowed"));
  },
);

Deno.test(
  "mergeTargetedSessionRepairPatches rejects Spanish generic policy copy",
  () => {
    const originalSessions: GeneratedSession[] = [
      {
        ...session({
          id: "w1-spanish-copy",
          date: "2026-04-09",
          type: "easyRun",
          weekNumber: 2,
        }),
        workoutTarget: easyWorkouts().easyTarget,
      },
    ];

    const requestedSessionIds = ["w1-spanish-copy"];
    const repairs: TargetedSessionRepairPatchItem[] = [{
      sessionId: "w1-spanish-copy",
      type: "easyRun",
      coachNote: "Ajustado para coincidir con el entrenamiento apropiado de la fase.",
      workoutTarget: easyWorkouts().easyTarget,
    }];

    const result = mergeTargetedSessionRepairPatches(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({ experience: "experience_intermediate", race: "race_half_marathon" }),
      8,
    );

    assert.equal(result.acceptedSessionIds.length, 0);
    assert.equal(result.rejectedRepairs.length, 1);
    assert.ok(result.rejectedRepairs[0].reason.includes("disallowed"));
  },
);

Deno.test(
  "mergeTargetedSessionRepairPatches preserves original session identity fields",
  () => {
    const originalSessions: GeneratedSession[] = [
      {
        ...session({
          id: "w1-preserve",
          date: "2026-04-08",
          type: "easyRun",
          weekNumber: 4,
        }),
        coachNote: "Original note",
        workoutTarget: easyWorkouts().easyTarget,
      },
    ];
    const requestedSessionIds = ["w1-preserve"];
    const repairs: TargetedSessionRepairPatchItem[] = [{
      sessionId: "w1-preserve",
      type: "longRun",
      coachNote: "New note",
      distanceKm: 18,
      workoutTarget: easyWorkouts().longRunTarget,
    }];

    const result = mergeTargetedSessionRepairPatches(
      originalSessions,
      requestedSessionIds,
      repairs,
      profile({ experience: "experience_intermediate", race: "race_marathon" }),
      12,
    );
    const patched = findSession(result.sessions, "w1-preserve");

    assert.equal(patched.id, "w1-preserve");
    assert.equal(patched.date, "2026-04-08");
    assert.equal(patched.weekNumber, 4);
    assert.equal(patched.type, "longRun");
    assert.equal(patched.coachNote, "New note");
  },
);

Deno.test(
  "normalizePeakLongRun uses coaching brief readiness when profile is missing experience",
  () => {
    const createSessions = (): GeneratedSession[] => [
      session({
        id: "w10-long",
        date: "2026-05-02",
        type: "longRun",
        distanceKm: 10,
        weekNumber: 10,
      }),
      session({
        id: "w12-race",
        date: "2026-05-16",
        type: "racePaceRun",
        distanceKm: 42.2,
        weekNumber: 12,
      }),
    ];

    const profileData: Record<string, unknown> = {
      goal: { race: "race_marathon", raceDate: null },
      fitness: {},
      schedule: { hardDays: [] },
    };

    const prepared = normalizePeakLongRun(
      createSessions(),
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "marathon",
        readinessLevel: "prepared",
        planLengthWeeks: 12,
        longRunCeilingKm: 40,
      }),
    );
    assert.equal(
      findSession(prepared, "w10-long").distanceKm,
      30,
      "prepared brief should resolve to intermediate peak long-run target",
    );

    const raceReady = normalizePeakLongRun(
      createSessions(),
      profileData,
      12,
      "en",
      coachingBriefFixture({
        raceType: "marathon",
        readinessLevel: "raceReady",
        planLengthWeeks: 12,
        longRunCeilingKm: 40,
      }),
    );
    assert.equal(
      findSession(raceReady, "w10-long").distanceKm,
      32,
      "race-ready brief should resolve to experienced peak long-run target",
    );
  },
);

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

Deno.test(
  "normalizePeakLongRun caps peak long-run at coaching brief longRunCeilingKm",
  () => {
    const result = normalizePeakLongRun(
      [
        session({
          id: "w8-long",
          date: "2026-06-13",
          type: "longRun",
          distanceKm: 12,
          durationMinutes: 84,
          weekNumber: 8,
        }),
        session({
          id: "w10-long",
          date: "2026-06-27",
          type: "longRun",
          distanceKm: 34,
          durationMinutes: 196,
          weekNumber: 10,
        }),
        session({
          id: "w12-race",
          date: "2026-07-11",
          type: "racePaceRun",
          distanceKm: 42.2,
          weekNumber: 12,
        }),
      ],
      profile({ race: "race_marathon", experience: "experience_experienced" }),
      12,
      "en",
      coachingBriefFixture({
        raceType: "marathon",
        readinessLevel: "raceReady",
        planLengthWeeks: 12,
        longRunCeilingKm: 24,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Build base." },
          { phase: "build", weeks: 3, focus: "Build quality." },
          { phase: "specific", weeks: 3, focus: "Add race-specific work." },
          { phase: "peak", weeks: 2, focus: "Peak specific load." },
          { phase: "taperRace", weeks: 1, focus: "Freshen up." },
        ],
      }),
    );

    const peakLongRun = findSession(result, "w10-long");
    assert.equal(peakLongRun.distanceKm, 24);
    assert.ok(
      peakLongRun.distanceKm <= 24,
      `peak long run should respect brief longRunCeilingKm, got ${peakLongRun.distanceKm}`,
    );
  },
);

Deno.test(
  "normalizePeakLongRun ignores malformed longRunCeilingKm of 0",
  () => {
    const result = normalizePeakLongRun(
      [
        session({
          id: "w10-long",
          date: "2026-07-11",
          type: "longRun",
          distanceKm: 20,
          durationMinutes: 120,
          weekNumber: 10,
        }),
      ],
      profile({
        race: "race_half_marathon",
        experience: "experience_intermediate",
      }),
      12,
      "en",
      coachingBriefFixture({
        planLengthWeeks: 12,
        phaseStrategy: [
          { phase: "base", weeks: 3, focus: "Protect base." },
          { phase: "build", weeks: 3, focus: "Increase load." },
          { phase: "specific", weeks: 2, focus: "Race-specific rhythm." },
          { phase: "peak", weeks: 2, focus: "Peak specific load." },
          { phase: "taperRace", weeks: 2, focus: "Freshen up." },
        ],
        longRunCeilingKm: 0,
      }),
    );

    const peakLongRun = findSession(result, "w10-long");
    assert.equal(peakLongRun.distanceKm, 16);
  },
);

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

Deno.test("smoothLongRunProgression uses coaching brief peak weeks", () => {
  const brief = coachingBriefFixture({
    raceType: "fiveK",
    readinessLevel: "prepared",
    planLengthWeeks: 8,
    phaseStrategy: [
      { phase: "base", weeks: 2, focus: "Build base." },
      { phase: "build", weeks: 2, focus: "Add effort." },
      { phase: "specific", weeks: 2, focus: "Specific pace." },
      { phase: "taperRace", weeks: 2, focus: "Freshen up." },
    ],
    taper: {
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: "Fresh legs.",
    },
  });

  const sessions = [
    session({
      id: "w6-sat",
      date: "2026-06-13",
      type: "longRun",
      distanceKm: 10,
      weekNumber: 6,
    }),
    session({
      id: "w7-sat",
      date: "2026-06-20",
      type: "longRun",
      distanceKm: 20,
      weekNumber: 7,
    }),
  ];

  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_5k", experience: "experience_intermediate" }),
    8,
    "en",
    brief,
  );

  const week7 = findSession(result, "w7-sat");
  assert.equal(week7.distanceKm, 12);
  assert.ok(
    week7.durationMinutes != null && week7.durationMinutes < 120,
    "duration should be recalculated for smoothed long run",
  );
});

Deno.test(
  "smoothLongRunProgression caps smoothed long runs at coaching brief ceiling",
  () => {
    const brief = coachingBriefFixture({
      longRunCeilingKm: 9,
      phaseStrategy: [
        { phase: "base", weeks: 2, focus: "Build base." },
        { phase: "build", weeks: 2, focus: "Controlled build." },
        { phase: "specific", weeks: 2, focus: "Specific work." },
        { phase: "taperRace", weeks: 2, focus: "Freshen up." },
      ],
    });

    const sessions = [
      session({
        id: "w1-sat",
        date: "2026-04-25",
        type: "longRun",
        distanceKm: 8,
        durationMinutes: 50,
        weekNumber: 1,
      }),
      session({
        id: "w2-sat",
        date: "2026-05-02",
        type: "longRun",
        distanceKm: 10,
        durationMinutes: 60,
        weekNumber: 2,
      }),
    ];

    const result = smoothLongRunProgression(
      sessions,
      profile({ race: "race_5k", experience: "experience_beginner" }),
      8,
      "en",
      brief,
    );

    assert.equal(findSession(result, "w2-sat").distanceKm, 9);
  },
);

Deno.test("smoothLongRunProgression caps a single long run above coaching brief ceiling", () => {
  const brief = coachingBriefFixture({
    longRunCeilingKm: 10,
    currentVolumeKmPerWeek: 0,
    maxWeeklyVolumeKm: 100,
  });
  const sessions = [
    session({
      id: "w3-sat",
      date: "2026-05-09",
      type: "longRun",
      distanceKm: 16,
      weekNumber: 3,
    }),
  ];

  const result = smoothLongRunProgression(
    sessions,
    profile({ race: "race_10k", experience: "experience_intermediate" }),
    8,
    "en",
    brief,
  );

  assert.equal(findSession(result, "w3-sat").distanceKm, 10);
});

Deno.test(
  "smoothLongRunProgression caps down-week long run above coaching brief ceiling",
  () => {
    const brief = coachingBriefFixture({
      longRunCeilingKm: 10,
      currentVolumeKmPerWeek: 0,
      maxWeeklyVolumeKm: 100,
    });

    const sessions = [
      session({
        id: "w1-sat",
        date: "2026-04-25",
        type: "longRun",
        distanceKm: 18,
        weekNumber: 1,
      }),
      session({
        id: "w2-sat",
        date: "2026-05-02",
        type: "longRun",
        distanceKm: 14,
        weekNumber: 2,
      }),
    ];

    const result = smoothLongRunProgression(
      sessions,
      profile({ race: "race_10k", experience: "experience_intermediate" }),
      8,
      "en",
      brief,
    );

    assert.equal(findSession(result, "w2-sat").distanceKm, 10);
  },
);

Deno.test(
  "smoothLongRunProgression does not zero out on malformed longRunCeilingKm of 0",
  () => {
    const brief = coachingBriefFixture({
      raceType: "fiveK",
      longRunCeilingKm: 0,
      currentVolumeKmPerWeek: 0,
      maxWeeklyVolumeKm: 100,
    });
    const sessions = [
      session({
        id: "w1-sat",
        date: "2026-04-25",
        type: "longRun",
        distanceKm: 10,
        weekNumber: 1,
      }),
      session({
        id: "w2-sat",
        date: "2026-05-02",
        type: "longRun",
        distanceKm: 20,
        weekNumber: 2,
      }),
    ];

    const result = smoothLongRunProgression(
      sessions,
      profile({ race: "race_5k", experience: "experience_beginner" }),
      8,
      "en",
      brief,
    );

    assert.equal(findSession(result, "w2-sat").distanceKm, 12);
  },
);

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

Deno.test(
  "production rule pipeline with midweek planStartDate keeps week 1 partial",
  () => {
    const profileData = profile({
      race: "race_10k",
      raceDate: "2026-06-21T00:00:00.000",
      experience: "experience_intermediate",
      trainingDays: 4,
      hardDays: ["day_tue", "day_thu", "day_sun"],
      longRunDay: "day_sat",
      planStartDate: "2026-06-10",
    });
    const totalWeeks = 8;
    const input = [
      session({
        id: "w1-2026-06-10-intervals",
        date: "2026-06-10",
        type: "intervals",
      }),
      session({
        id: "w1-2026-06-11-easyRun",
        date: "2026-06-11",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-12-easyRun",
        date: "2026-06-12",
        type: "easyRun",
      }),
    ];

    const result = runProductionRulePipeline(input, profileData, totalWeeks);
    const hasPreStartSession = result.some((session) =>
      session.date < "2026-06-10"
    );
    assert.ok(!hasPreStartSession);
    assert.equal(trainingCountForTest(result), 4);
    assert.equal(findByDate(result, "2026-06-10").date, "2026-06-10");
    assert.ok(result.some((session) => session.date === "2026-06-13"));
  },
);

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

Deno.test("production rule pipeline passes coaching brief to long-run smoothing", () => {
  const profileData = profile({
    race: "race_5k",
    raceDate: "2026-06-21T00:00:00.000",
    experience: "experience_experienced",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu", "day_sun"],
    longRunDay: "day_sat",
  });
  const totalWeeks = 8;
  const brief = coachingBriefFixture({
    longRunCeilingKm: 10,
    currentVolumeKmPerWeek: 0,
    maxWeeklyVolumeKm: 100,
  });
  const input = [
    session({
      id: "w2-long",
      date: "2026-05-02",
      type: "longRun",
      distanceKm: 20,
      weekNumber: 2,
      durationMinutes: 120,
    }),
  ];

  const result = runProductionRulePipeline(
    input,
    profileData,
    totalWeeks,
    brief,
  );
  const weekTwoLongRuns = result.filter((item) =>
    item.type === "longRun" && item.weekNumber === 2
  );
  assert.equal(weekTwoLongRuns.length, 1);
  assert.equal(weekTwoLongRuns[0].distanceKm, 10);
});

Deno.test("production rule pipeline fully anchors low week 1 and enforces brief ceilings", () => {
  const profileData = profile({
    race: "race_10k",
    raceDate: "2026-06-21T00:00:00.000",
    longRunDay: "day_sat",
  });
  const totalWeeks = 8;
  const brief = coachingBriefFixture({
    source: "mixed",
    confidence: "high",
    currentVolumeKmPerWeek: 52,
    maxWeeklyVolumeKm: 45,
    longRunCeilingKm: 12,
    planLengthWeeks: 8,
    taper: {
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: "Fresh legs.",
    },
  });
  const input = [
    session({
      id: "w1-2026-04-27-easyRun",
      date: "2026-04-27",
      type: "easyRun",
      distanceKm: 12,
      weekNumber: 1,
    }),
    session({
      id: "w1-2026-04-30-easyRun",
      date: "2026-04-30",
      type: "easyRun",
      distanceKm: 12,
      weekNumber: 1,
    }),
    session({
      id: "w2-2026-05-04-easyRun",
      date: "2026-05-04",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 2,
    }),
    session({
      id: "w2-2026-05-06-easyRun",
      date: "2026-05-06",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 2,
    }),
    session({
      id: "w2-2026-05-07-longRun",
      date: "2026-05-07",
      type: "longRun",
      distanceKm: 24,
      weekNumber: 2,
    }),
    session({
      id: "w3-2026-05-11-easyRun",
      date: "2026-05-11",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 3,
    }),
    session({
      id: "w3-2026-05-14-easyRun",
      date: "2026-05-14",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 3,
    }),
    session({
      id: "w3-2026-05-17-longRun",
      date: "2026-05-17",
      type: "longRun",
      distanceKm: 24,
      weekNumber: 3,
    }),
    session({
      id: "w4-2026-05-18-easyRun",
      date: "2026-05-18",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 4,
    }),
    session({
      id: "w4-2026-05-21-easyRun",
      date: "2026-05-21",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 4,
    }),
    session({
      id: "w4-2026-05-24-longRun",
      date: "2026-05-24",
      type: "longRun",
      distanceKm: 24,
      weekNumber: 4,
    }),
    session({
      id: "w5-2026-05-25-easyRun",
      date: "2026-05-25",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 5,
    }),
    session({
      id: "w5-2026-05-28-easyRun",
      date: "2026-05-28",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 5,
    }),
    session({
      id: "w5-2026-05-31-longRun",
      date: "2026-05-31",
      type: "longRun",
      distanceKm: 24,
      weekNumber: 5,
    }),
    session({
      id: "w6-2026-06-01-easyRun",
      date: "2026-06-01",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 6,
    }),
    session({
      id: "w6-2026-06-03-easyRun",
      date: "2026-06-03",
      type: "easyRun",
      distanceKm: 20,
      weekNumber: 6,
    }),
    session({
      id: "w6-2026-06-06-longRun",
      date: "2026-06-06",
      type: "longRun",
      distanceKm: 24,
      weekNumber: 6,
    }),
  ];
  const prePipelineWeekOneVolumeKm = input
    .filter((item) => item.weekNumber === 1 && item.type !== "restDay")
    .reduce((sum, session) => sum + (session.distanceKm ?? 0), 0);

  const result = runProductionRulePipeline(
    input,
    profileData,
    totalWeeks,
    brief,
  );

  const weekOneVolumeKm = result
    .filter((item) => item.weekNumber === 1 && item.type !== "restDay")
    .reduce((sum, session) => sum + (session.distanceKm ?? 0), 0);
  assert.ok(
    weekOneVolumeKm >= 44,
    `Expected anchored week 1 volume, got ${weekOneVolumeKm}`,
  );
  assert.ok(
    weekOneVolumeKm > prePipelineWeekOneVolumeKm,
    `Expected week 1 to be raised from ${prePipelineWeekOneVolumeKm} km`,
  );

  const taperStartWeek = totalWeeks - brief.taper.weeks + 1;
  for (let weekNumber = 1; weekNumber < taperStartWeek; weekNumber += 1) {
    const weeklyVolumeKm = result
      .filter((item) =>
        item.weekNumber === weekNumber &&
        item.type !== "restDay" &&
        item.type !== "crossTraining" &&
        item.type !== "raceDay"
      )
      .reduce((sum, session) => sum + (session.distanceKm ?? 0), 0);
    assert.ok(
      weeklyVolumeKm <= brief.maxWeeklyVolumeKm + 0.01,
      `Week ${weekNumber} volume ${weeklyVolumeKm} exceeds max ${brief.maxWeeklyVolumeKm}`,
    );
  }

  const allLongRuns = result.filter((item) => item.type === "longRun");
  assert.ok(
    allLongRuns.every((item) =>
      (item.distanceKm ?? 0) <= brief.longRunCeilingKm + 0.01
    ),
    `Long runs exceeded ceiling: ${
      JSON.stringify(
        allLongRuns.map((item) => `${item.date}:${item.distanceKm}`),
      )
    }`,
  );

  const planViolations = validateGeneratedPlanAgainstCoachingBrief(
    {
      totalWeeks,
      raceGuidance: {
        schemaVersion: 1,
        raceDayExecution: "Use the evidence target.",
      },
      sessions: result,
    },
    brief,
  );
  assert.deepEqual(planViolations, []);
});

Deno.test("production rule pipeline removes inferred race day when goal raceDate is missing", () => {
  const profileData = profile({
    race: "race_5k",
    longRunDay: "day_sat",
    trainingDays: 4,
    hardDays: ["day_tue", "day_thu"],
    raceDate: null,
  });
  const totalWeeks = 2;
  const input = [
    session({
      id: "w1-2026-04-27-easyRun",
      date: "2026-04-27",
      weekNumber: 1,
      type: "easyRun",
      distanceKm: 6,
    }),
    session({
      id: "w1-2026-05-03-easyRun",
      date: "2026-05-03",
      weekNumber: 1,
      type: "easyRun",
      distanceKm: 6,
    }),
    session({
      id: "w2-2026-05-10-easyRun",
      date: "2026-05-10",
      weekNumber: 2,
      type: "easyRun",
      distanceKm: 8,
    }),
  ];

  const result = runProductionRulePipeline(input, profileData, totalWeeks);
  const inferredRaceDate = "2026-05-10";
  assert.ok(
    !result.some((item) => item.date === inferredRaceDate),
    `Expected inferred race day ${inferredRaceDate} to be removed when raceDate is missing.`,
  );
  assert.ok(
    result.some((item) => item.date === "2026-05-03"),
    "Expected earlier-week session to remain after cleanup.",
  );
});

Deno.test("expectedTotalWeeks anchors Sunday to current week's Monday", () => {
  const weeks = expectedTotalWeeks(
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
    new Date(Date.UTC(2026, 4, 31, 12)),
  );
  assert.equal(weeks, 3);
});

Deno.test("expectedTotalWeeks resolves missing planStartDate to next future Monday", () => {
  const withMissingPlanStart = expectedTotalWeeks(
    profile({ race: "race_5k", raceDate: "2026-06-22T00:00:00.000" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.equal(withMissingPlanStart, 3);

  const withResolvedPlanStart = expectedTotalWeeks(
    profile({
      race: "race_5k",
      raceDate: "2026-06-22T00:00:00.000",
      planStartDate: "2026-06-03",
    }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.equal(withResolvedPlanStart, 4);
});

Deno.test("resolvePlanStartDate falls back to next Monday when profile date is missing", () => {
  const cases: Array<
    { label: string; generationDate: Date; expected: string }
  > = [
    {
      label: "Monday",
      generationDate: new Date(Date.UTC(2026, 5, 1, 12)),
      expected: "2026-06-08",
    },
    {
      label: "Tuesday",
      generationDate: new Date(Date.UTC(2026, 5, 2, 12)),
      expected: "2026-06-08",
    },
    {
      label: "Wednesday",
      generationDate: new Date(Date.UTC(2026, 5, 3, 12)),
      expected: "2026-06-08",
    },
    {
      label: "Sunday",
      generationDate: new Date(Date.UTC(2026, 5, 7, 12)),
      expected: "2026-06-08",
    },
  ];

  for (const testCase of cases) {
    const resolved = resolvePlanStartDate({}, testCase.generationDate);
    assert.equal(resolved, testCase.expected, `${testCase.label} fallback`);
  }
});

Deno.test(
  "resolvePlanStartDate ignores ISO datetime planStartDate and uses fallback Monday",
  () => {
    const resolved = resolvePlanStartDate(
      profile({ planStartDate: "2026-06-03T10:00:00Z" }),
      new Date(Date.UTC(2026, 5, 2, 12)),
    );
    assert.equal(resolved, "2026-06-08");
  },
);

Deno.test("resolvePlanStartDate keeps explicit schedule planStartDate", () => {
  const resolved = resolvePlanStartDate(
    profile({ planStartDate: "2026-06-03" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.equal(resolved, "2026-06-03");
});

Deno.test("expectedTotalWeeks computes exact 3-week minimum window", () => {
  const weeks = expectedTotalWeeks(
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.equal(weeks, 2);
});

Deno.test("expectedTotalWeeks returns exact unsupported short window", () => {
  const weeks = expectedTotalWeeks(
    profile({ race: "race_5k", raceDate: "2026-06-01T00:00:00.000" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.equal(weeks, 0);
});

Deno.test(
  "expectedTotalWeeks returns 0 when explicit planStartDate is after fixed race date",
  () => {
    const weeks = expectedTotalWeeks(
      profile({ race: "race_5k", raceDate: "2026-06-07T00:00:00.000" }),
      new Date(Date.UTC(2026, 5, 1, 12)),
      "2026-06-10",
    );
    assert.equal(weeks, 0);
  },
);

Deno.test("expectedTotalWeeks returns null when no fixed race date", () => {
  const weeks = expectedTotalWeeks(
    profile({ race: "race_10k", raceDate: null }),
  );
  assert.equal(weeks, null);
});

Deno.test("truncateAfterRaceDate removes sessions after race date", () => {
  const sessions = truncateAfterRaceDate(
    [
      session({
        id: "w3-mon",
        date: "2026-06-15",
        type: "easyRun",
        weekNumber: 3,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        type: "racePaceRun",
        weekNumber: 3,
        distanceKm: 10,
      }),
      session({
        id: "w4-mon",
        date: "2026-06-22",
        type: "easyRun",
        weekNumber: 4,
      }),
      session({
        id: "w4-wed",
        date: "2026-06-24",
        type: "intervals",
        weekNumber: 4,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.equal(sessions.length, 2);
  assert.ok(sessions.some((s) => s.id === "race"));
  assert.ok(!sessions.some((s) => s.date > "2026-06-21"));
});

Deno.test("truncateAfterRaceDate returns unchanged when no fixed race date", () => {
  const input = [
    session({ id: "w1-mon", date: "2026-06-15", type: "easyRun" }),
    session({ id: "w2-mon", date: "2026-06-22", type: "easyRun" }),
  ];
  const sessions = truncateAfterRaceDate(
    input,
    profile({ race: "race_10k", raceDate: null }),
  );
  assert.equal(sessions.length, 2);
});

Deno.test("phaseAllocationFor 3 weeks is specific + taperRace only", () => {
  const phases = phasePlanFor(3, {});
  assert.equal(phases.length, 3);
  assert.equal(phases.filter((p) => p === "base").length, 0);
  assert.equal(phases.filter((p) => p === "build").length, 0);
  assert.equal(phases.filter((p) => p === "specific").length, 2);
  assert.equal(phases.filter((p) => p === "peak").length, 0);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
  assert.equal(phases[2], "taperRace");
});

Deno.test("phaseAllocationFor 5 weeks is build + specific + taperRace", () => {
  const phases = phasePlanFor(5, {});
  assert.equal(phases.length, 5);
  assert.equal(phases.filter((p) => p === "base").length, 0);
  assert.equal(phases.filter((p) => p === "build").length, 1);
  assert.equal(phases.filter((p) => p === "specific").length, 3);
  assert.equal(phases.filter((p) => p === "peak").length, 0);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
  assert.equal(phases[4], "taperRace");
});

Deno.test("phaseAllocationFor 7 weeks is base + build + specific + taperRace", () => {
  const phases = phasePlanFor(7, {});
  assert.equal(phases.length, 7);
  assert.equal(phases.filter((p) => p === "base").length, 1);
  assert.equal(phases.filter((p) => p === "build").length, 2);
  assert.equal(phases.filter((p) => p === "specific").length, 3);
  assert.equal(phases.filter((p) => p === "peak").length, 0);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
  assert.equal(phases[6], "taperRace");
});

Deno.test("enforcePreRaceTaper downgrades intervals day before 10K race", () => {
  const sessions = enforcePreRaceTaper(
    [
      session({
        id: "w4-sat",
        date: "2026-06-20",
        type: "intervals",
        weekNumber: 4,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        type: "racePaceRun",
        weekNumber: 4,
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
    "en",
  );
  const dayBefore = findByDate(sessions, "2026-06-20");
  assert.ok(
    dayBefore.type === "recoveryRun" || dayBefore.type === "easyRun",
    `day-before-race intervals should be downgraded, got ${dayBefore.type}`,
  );
});

Deno.test("enforcePreRaceTaper leaves rest days before race untouched", () => {
  const sessions = enforcePreRaceTaper(
    [
      session({
        id: "w4-sat",
        date: "2026-06-20",
        type: "restDay",
        weekNumber: 4,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        type: "racePaceRun",
        weekNumber: 4,
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
    "en",
  );
  assert.equal(findByDate(sessions, "2026-06-20").type, "restDay");
});

Deno.test("enforcePreRaceTaper uses 3-day quiet window for marathon", () => {
  const sessions = enforcePreRaceTaper(
    [
      session({
        id: "w4-thu",
        date: "2026-06-18",
        type: "tempoRun",
        weekNumber: 4,
      }),
      session({
        id: "w4-fri",
        date: "2026-06-19",
        type: "easyRun",
        weekNumber: 4,
      }),
      session({
        id: "w4-sat",
        date: "2026-06-20",
        type: "restDay",
        weekNumber: 4,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        type: "racePaceRun",
        weekNumber: 4,
        distanceKm: 42.2,
      }),
    ],
    profile({ race: "race_marathon", raceDate: "2026-06-21T00:00:00.000" }),
    "en",
  );
  const thu = findByDate(sessions, "2026-06-18");
  assert.ok(
    thu.type === "recoveryRun" || thu.type === "easyRun",
    `3-days-before marathon tempo should be downgraded, got ${thu.type}`,
  );
  assert.equal(findByDate(sessions, "2026-06-19").type, "easyRun");
});

Deno.test("validateGeneratedSchedule flags session after race date", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-20-easyRun",
        date: "2026-06-20",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 10,
      }),
      session({
        id: "w1-2026-06-22-intervals",
        date: "2026-06-22",
        type: "intervals",
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.equal(violations.length, 1);
  assert.equal(violations[0].rule, "session_after_race_date");
  assert.equal(violations[0].sessionId, "w1-2026-06-22-intervals");
});

Deno.test("validateGeneratedSchedule does not flag session on race date", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.deepEqual(violations, []);
});

Deno.test("validateGeneratedSchedule flags stressful session before race", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-19-easyRun",
        date: "2026-06-19",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-20-intervals",
        date: "2026-06-20",
        type: "intervals",
      }),
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.equal(violations.length, 1);
  assert.equal(violations[0].rule, "stressful_session_before_race");
  assert.equal(violations[0].sessionId, "w1-2026-06-20-intervals");
});

Deno.test("validateGeneratedSchedule does not flag easy run before race", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-19-easyRun",
        date: "2026-06-19",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-20-easyRun",
        date: "2026-06-20",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.deepEqual(violations, []);
});

Deno.test("validateGeneratedSchedule uses 3-day quiet window for marathon", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-17-easyRun",
        date: "2026-06-17",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-18-tempoRun",
        date: "2026-06-18",
        type: "tempoRun",
      }),
      session({
        id: "w1-2026-06-19-easyRun",
        date: "2026-06-19",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-20-restDay",
        date: "2026-06-20",
        type: "restDay",
      }),
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 42.2,
      }),
    ],
    profile({ race: "race_marathon", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.equal(violations.length, 1);
  assert.equal(violations[0].rule, "stressful_session_before_race");
  assert.equal(violations[0].sessionId, "w1-2026-06-18-tempoRun");
  assert.ok(!violations.some((v) => v.sessionId === "w1-2026-06-19-easyRun"));
});

Deno.test("expectedTotalWeeks returns null when race date is in the past", () => {
  const pastRaceDate = new Date(Date.now() - 60 * 86_400_000)
    .toISOString()
    .slice(0, 10);
  const weeks = expectedTotalWeeks(
    profile({ race: "race_10k", raceDate: pastRaceDate }),
  );
  assert.equal(weeks, 0);
});

Deno.test("validateGeneratedSchedule does not flag goal race as stressful_session_before_race", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-19-easyRun",
        date: "2026-06-19",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-20-easyRun",
        date: "2026-06-20",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-21-racePaceRun",
        date: "2026-06-21",
        type: "racePaceRun",
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
  );
  assert.ok(
    !violations.some((v) =>
      v.rule === "stressful_session_before_race" &&
      v.sessionId === "w1-2026-06-21-racePaceRun"
    ),
    "goal race day must never be flagged as stressful_session_before_race",
  );
});

Deno.test("enforcePreRaceTaper leaves race-day racePaceRun untouched", () => {
  const sessions = enforcePreRaceTaper(
    [
      session({
        id: "w4-fri",
        date: "2026-06-19",
        type: "easyRun",
        weekNumber: 4,
      }),
      session({
        id: "race",
        date: "2026-06-21",
        type: "racePaceRun",
        weekNumber: 4,
        distanceKm: 10,
      }),
    ],
    profile({ race: "race_10k", raceDate: "2026-06-21T00:00:00.000" }),
    "en",
  );
  const race = findByDate(sessions, "2026-06-21");
  assert.equal(race.type, "racePaceRun");
  assert.equal(race.distanceKm, 10);
});

Deno.test("phaseAllocationFor 4 weeks is build + specific + taperRace", () => {
  const phases = phasePlanFor(4, {});
  assert.equal(phases.length, 4);
  assert.equal(phases.filter((p) => p === "base").length, 0);
  assert.equal(phases.filter((p) => p === "build").length, 1);
  assert.equal(phases.filter((p) => p === "specific").length, 2);
  assert.equal(phases.filter((p) => p === "peak").length, 0);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
});

Deno.test("phaseAllocationFor 6 weeks includes base and taperRace", () => {
  const phases = phasePlanFor(6, {});
  assert.equal(phases.length, 6);
  assert.equal(phases.filter((p) => p === "base").length, 1);
  assert.equal(phases.filter((p) => p === "taperRace").length, 1);
});

Deno.test("phaseAllocationFor invariant: sums to totalWeeks and includes taperRace >= 1", () => {
  for (const totalWeeks of [3, 4, 5, 6, 7, 8, 12, 16, 20]) {
    const phases = phasePlanFor(totalWeeks, {});
    assert.equal(
      phases.length,
      totalWeeks,
      `phases length should equal ${totalWeeks}`,
    );
    const taperCount = phases.filter((p) => p === "taperRace").length;
    assert.ok(
      taperCount >= 1,
      `weeks=${totalWeeks}: taperRace count should be >= 1, got ${taperCount}`,
    );
  }
});

Deno.test("validateGeneratedSchedule returns no violations when no fixed race date", () => {
  const violations = validateGeneratedSchedule(
    [
      session({
        id: "w1-2026-06-21-easyRun",
        date: "2026-06-21",
        type: "easyRun",
      }),
      session({
        id: "w1-2026-06-22-intervals",
        date: "2026-06-22",
        type: "intervals",
      }),
      session({
        id: "w1-2026-06-23-easyRun",
        date: "2026-06-23",
        type: "easyRun",
      }),
    ],
    profile({ race: "race_10k", raceDate: null }),
  );
  assert.deepEqual(violations, []);
});

Deno.test("validateGeneratedPlanShape flags missing weeks", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-01-easyRun",
        date: "2026-06-01",
        weekNumber: 1,
      }),
      session({
        id: "w3-2026-06-15-racePaceRun",
        date: "2026-06-15",
        weekNumber: 3,
        type: "racePaceRun",
        distanceKm: 5,
      }),
    ],
    3,
    profile({ race: "race_5k", raceDate: "2026-06-15" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.ok(
    violations.some((v) =>
      v.rule === "missing_plan_week" && v.sessionId === "week-2"
    ),
  );
});

Deno.test("validateGeneratedPlanShape flags sessions after totalWeeks", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-01-easyRun",
        date: "2026-06-01",
        weekNumber: 1,
      }),
      session({
        id: "w2-2026-06-08-racePaceRun",
        date: "2026-06-08",
        weekNumber: 2,
        type: "racePaceRun",
        distanceKm: 5,
      }),
      session({
        id: "w3-2026-06-15-easyRun",
        date: "2026-06-15",
        weekNumber: 3,
      }),
    ],
    2,
    profile({ race: "race_5k", raceDate: "2026-06-08" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
  );
  assert.ok(
    violations.some((v) =>
      v.rule === "session_week_after_total_weeks" &&
      v.sessionId === "w3-2026-06-15-easyRun"
    ),
  );
});

Deno.test("validateGeneratedPlanShape flags date and week label mismatch", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-01-easyRun",
        date: "2026-06-01",
        weekNumber: 1,
      }),
      session({
        id: "w2-2026-06-15-racePaceRun",
        date: "2026-06-15",
        weekNumber: 2,
        type: "racePaceRun",
        distanceKm: 5,
      }),
    ],
    2,
    profile({ race: "race_5k", raceDate: "2026-06-15" }),
    new Date(Date.UTC(2026, 5, 1, 12)),
    "2026-06-01",
  );
  assert.ok(
    violations.some((v) =>
      v.rule === "session_date_week_mismatch" &&
      v.sessionId === "w2-2026-06-15-racePaceRun"
    ),
  );
});

Deno.test("validateGeneratedPlanShape keeps fixed-race totalWeeks strict after date normalization", () => {
  const sessions = normalizeSessionIds(
    ensureFullCalendarWeeks(
      normalizeWeekNumbersFromDates(
        [
          session({
            id: "w1-2026-06-11-racePaceRun",
            date: "2026-06-11",
            weekNumber: 1,
            type: "racePaceRun",
            distanceKm: 5,
          }),
          session({
            id: "w1-2026-06-09-easyRun",
            date: "2026-06-09",
            weekNumber: 1,
            type: "easyRun",
          }),
          session({
            id: "w2-2026-06-16-longRun",
            date: "2026-06-16",
            weekNumber: 2,
            type: "longRun",
          }),
        ],
        profile({
          race: "race_10k",
          raceDate: "2026-06-11",
          planStartDate: "2026-06-04",
        }),
        new Date(Date.UTC(2026, 5, 4, 12)),
        "2026-06-04",
      ),
      "en",
      "2026-06-04",
    ),
  );
  const violations = validateGeneratedPlanShape(
    sessions,
    2,
    profile({
      race: "race_10k",
      raceDate: "2026-06-11",
      planStartDate: "2026-06-04",
    }),
    new Date(Date.UTC(2026, 5, 12, 12)),
    "2026-06-04",
  );
  assert.ok(
    violations.some((v) => v.rule === "session_week_after_total_weeks"),
  );
});

Deno.test("validateGeneratedPlanShape rejects sessions before explicit planStartDate", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-08-easyRun",
        date: "2026-06-08",
        weekNumber: 1,
      }),
      session({
        id: "w1-2026-06-11-easyRun",
        date: "2026-06-11",
        weekNumber: 1,
      }),
    ],
    1,
    profile({
      race: "race_5k",
      raceDate: null,
      planStartDate: "2026-06-10",
    }),
    new Date(Date.UTC(2026, 5, 12, 12)),
    "2026-06-10",
  );
  assert.ok(
    violations.some((v) =>
      v.rule === "session_before_plan_start" &&
      v.sessionId === "w1-2026-06-08-easyRun"
    ),
  );
});

Deno.test("validateGeneratedPlanShape maps week labels from selected planStartDate anchor", () => {
  const violations = validateGeneratedPlanShape(
    [
      session({
        id: "w1-2026-06-11-easyRun",
        date: "2026-06-11",
        weekNumber: 1,
      }),
      session({
        id: "w1-2026-06-14-easyRun",
        date: "2026-06-14",
        weekNumber: 1,
      }),
    ],
    1,
    profile({
      race: "race_5k",
      raceDate: null,
      planStartDate: "2026-06-10",
    }),
    new Date(Date.UTC(2026, 5, 12, 12)),
    "2026-06-10",
  );
  assert.ok(!violations.some((v) => v.rule === "session_date_week_mismatch"));
  assert.ok(!violations.some((v) => v.rule === "session_before_plan_start"));
});

Deno.test("validateGeneratedPlanAgainstCoachingBrief rejects first week far below high-confidence Strava anchor", () => {
  const violations = validateGeneratedPlanAgainstCoachingBrief(
    {
      totalWeeks: 8,
      raceGuidance: {
        schemaVersion: 1,
        raceDayExecution: "Use the evidence target.",
      },
      sessions: [
        session({
          id: "w1-2026-06-08-easyRun",
          date: "2026-06-08",
          weekNumber: 1,
          distanceKm: 6,
        }),
        session({
          id: "w1-2026-06-10-easyRun",
          date: "2026-06-10",
          weekNumber: 1,
          distanceKm: 6,
        }),
        session({
          id: "w1-2026-06-13-longRun",
          date: "2026-06-13",
          weekNumber: 1,
          type: "longRun",
          distanceKm: 8,
        }),
      ],
    },
    coachingBriefFixture({
      currentVolumeKmPerWeek: 52,
      maxWeeklyVolumeKm: 68,
      longRunCeilingKm: 24,
    }),
  );

  assert.ok(
    violations.some((violation) =>
      violation.rule === "coaching_brief_week_one_below_anchor"
    ),
    JSON.stringify(violations),
  );
});

Deno.test("validateGeneratedPlanAgainstCoachingBrief rejects long run above brief ceiling", () => {
  const violations = validateGeneratedPlanAgainstCoachingBrief(
    {
      totalWeeks: 8,
      raceGuidance: {
        schemaVersion: 1,
        raceDayExecution: "Use the evidence target.",
      },
      sessions: [
        session({
          id: "w1-2026-06-13-longRun",
          date: "2026-06-13",
          weekNumber: 1,
          type: "longRun",
          distanceKm: 28,
        }),
      ],
    },
    coachingBriefFixture({
      currentVolumeKmPerWeek: 45,
      maxWeeklyVolumeKm: 68,
      longRunCeilingKm: 22,
    }),
  );

  assert.ok(
    violations.some((violation) =>
      violation.rule === "coaching_brief_long_run_above_ceiling"
    ),
    JSON.stringify(violations),
  );
});

Deno.test("phaseForWeekFromCoachingBrief preserves final two-week taper after legacy phase rewrite", () => {
  const brief = coachingBriefFixture({
    planLengthWeeks: 8,
    taper: {
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: "Fresh legs.",
    },
    phaseStrategy: [
      { phase: "base", weeks: 2, focus: "Protect base." },
      { phase: "build", weeks: 2, focus: "Controlled threshold." },
      { phase: "specific", weeks: 2, focus: "Race-specific rhythm." },
      { phase: "taperRace", weeks: 2, focus: "Freshen up." },
    ],
  });
  const profileData = profile({ race: "race_half_marathon" });
  const legacyFinalWeekSevenPhase = phaseForWeek(7, 8, profileData);
  const finalSessions = [
    session({
      id: "w7-2026-07-20-easyRun",
      date: "2026-07-20",
      weekNumber: 7,
      phase: phaseForWeekFromCoachingBrief(7, 8, profileData, brief),
    }),
    session({
      id: "w8-2026-07-27-easyRun",
      date: "2026-07-27",
      weekNumber: 8,
      phase: phaseForWeekFromCoachingBrief(8, 8, profileData, brief),
    }),
  ];

  assert.equal(legacyFinalWeekSevenPhase, "peak");
  assert.equal(finalSessions[0].phase, "taperRace");
  assert.deepEqual(
    validateGeneratedPlanAgainstCoachingBrief(
      {
        totalWeeks: 8,
        raceGuidance: {
          schemaVersion: 1,
          raceDayExecution: "Use the evidence target.",
        },
        sessions: finalSessions,
      },
      brief,
    ).filter((violation) =>
      violation.rule === "coaching_brief_taper_phase_mismatch"
    ),
    [],
  );
});

Deno.test("validateGeneratedPlanAgainstCoachingBrief catches post-transform taper phase mismatch", () => {
  const violations = validateGeneratedPlanAgainstCoachingBrief(
    {
      totalWeeks: 8,
      raceGuidance: {
        schemaVersion: 1,
        raceDayExecution: "Use the evidence target.",
      },
      sessions: [
        session({
          id: "w7-2026-07-20-easyRun",
          date: "2026-07-20",
          weekNumber: 7,
          phase: "peak",
        }),
        session({
          id: "w8-2026-07-27-easyRun",
          date: "2026-07-27",
          weekNumber: 8,
          phase: "taperRace",
        }),
      ],
    },
    coachingBriefFixture(),
  );

  assert.ok(
    violations.some((violation) =>
      violation.rule === "coaching_brief_taper_phase_mismatch"
    ),
    JSON.stringify(violations),
  );
});

Deno.test("unsupportedCoachingBriefReason rejects custom race briefs before generation", () => {
  const reason = unsupportedCoachingBriefReason(
    coachingBriefFixture({
      raceType: "other",
      readinessLevel: "unsupported",
      evidenceTarget: {
        distanceKm: null,
        timeSec: null,
        paceSecPerKm: null,
        confidence: "limited",
        source: "manual",
        supported: false,
        reason: "Custom race distance.",
      },
    }),
  );

  assert.ok(reason?.includes("Custom race distances"));
});

Deno.test("unsupportedCoachingBriefReason allows supported standard race briefs", () => {
  assert.equal(unsupportedCoachingBriefReason(coachingBriefFixture()), null);
});

function profile({
  experience = "experience_beginner",
  hardDays = [],
  longRunDay = null,
  race = "race_5k",
  raceDate = null,
  trainingDays = null,
  planStartDate = null,
  strengthPreferences = null,
}: {
  experience?: string;
  hardDays?: string[];
  longRunDay?: string | null;
  race?: string;
  raceDate?: string | null;
  trainingDays?: number | null;
  planStartDate?: string | null;
  strengthPreferences?: Record<string, unknown> | null;
} = {}): Record<string, unknown> {
  return {
    goal: { race, raceDate },
    fitness: { experience },
    schedule: {
      hardDays,
      longRunDay,
      trainingDays,
      ...(planStartDate == null ? {} : { planStartDate }),
    },
    ...(strengthPreferences == null ? {} : { strengthPreferences }),
  };
}

function coachingBriefFixture(
  overrides: Partial<CoachingBrief> = {},
): CoachingBrief {
  const evidenceTarget = {
    distanceKm: 21.097,
    timeSec: 6900,
    paceSecPerKm: 327,
    confidence: "high" as const,
    source: "strava" as const,
    supported: true,
    reason: "Backed by measured evidence.",
  };

  return {
    raceType: "halfMarathon",
    readinessLevel: "prepared",
    confidence: "high",
    source: "strava",
    currentVolumeKmPerWeek: 52,
    currentRunsPerWeek: 5,
    recentLongRunKm: 18,
    planLengthWeeks: 8,
    phaseStrategy: [
      { phase: "base", weeks: 2, focus: "Protect base." },
      { phase: "build", weeks: 2, focus: "Controlled threshold." },
      { phase: "specific", weeks: 2, focus: "Race-specific rhythm." },
      { phase: "taperRace", weeks: 2, focus: "Freshen up." },
    ],
    maxWeeklyVolumeKm: 68,
    longRunCeilingKm: 24,
    weeklyRunDays: 5,
    taper: {
      weeks: 2,
      volumeReductionPercent: 35,
      finalWeekFocus: "Fresh legs.",
    },
    workoutEmphasis: ["aerobic volume", "threshold"],
    evidenceTarget,
    ambitiousTarget: {
      ...evidenceTarget,
      timeSec: 6600,
      paceSecPerKm: 313,
      confidence: "limited",
      supported: false,
      reason: "Too aggressive for current evidence.",
    },
    constraints: ["Do not prescribe unsupported race-pace workouts."],
    rationale: ["Used measured Strava evidence."],
    ...overrides,
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

function easyWorkouts(): {
  easyTarget: NonNullable<GeneratedSession["workoutTarget"]>;
  longRunTarget: NonNullable<GeneratedSession["workoutTarget"]>;
} {
  return {
    easyTarget: {
      schemaVersion: 1,
      type: "pace" as const,
      zone: "easy",
      paceMinSecPerKm: 390,
      paceMaxSecPerKm: 420,
      effortCue: "easy",
    },
    longRunTarget: {
      schemaVersion: 1,
      type: "pace" as const,
      zone: "longRun",
      paceMinSecPerKm: 450,
      paceMaxSecPerKm: 510,
      effortCue: "easy",
    },
  };
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
  coachingBrief: CoachingBrief | null = null,
): GeneratedSession[] {
  const scheduleCandidate = profileData.schedule;
  const schedule = typeof scheduleCandidate === "object" &&
      scheduleCandidate != null &&
      !Array.isArray(scheduleCandidate)
    ? scheduleCandidate as Record<string, unknown>
    : undefined;
  const scheduleNormalizedSessions = normalizeTrainingDayCount(
    input,
    profileData,
    "en",
    typeof schedule?.planStartDate === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(schedule.planStartDate)
      ? schedule.planStartDate
      : undefined,
  );
  const longRunPlacedSessions = placeLongRunsOnPreferredDay(
    scheduleNormalizedSessions,
    profileData,
  );
  const stressSpacedSessions = spaceStressfulSessions(
    longRunPlacedSessions,
    profileData,
  );
  const planStartDate = typeof schedule?.planStartDate === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(schedule.planStartDate)
    ? schedule.planStartDate
    : undefined;
  const fullCalendarSessions = ensureFullCalendarWeeks(
    stressSpacedSessions,
    "en",
    planStartDate,
  );
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
  const volumeRampedSessions = normalizeWeeklyVolumeRamp(
    scheduleAdjustedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const peakNormalizedSessions = normalizePeakLongRun(
    volumeRampedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const progressionSmoothedSessions = smoothLongRunProgression(
    peakNormalizedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const volumeStabilizedSessions = normalizeWeeklyVolumeRamp(
    progressionSmoothedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const taperNormalizedSessions = normalizeTaper(
    volumeStabilizedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
    taperNormalizedSessions,
    profileData,
    totalWeeks,
    "en",
    coachingBrief,
  );
  const firstSessionNormalizedSessions = normalizeFirstPlannedSession(
    phaseNormalizedSessions,
    profileData,
  );
  const phaseStampedSessions = firstSessionNormalizedSessions.map((
    session,
  ) => ({
    ...session,
    phase: phaseForWeekFromCoachingBrief(
      session.weekNumber,
      totalWeeks,
      profileData,
      coachingBrief,
    ),
  }));
  const truncatedSessions = truncateAfterRaceDate(
    phaseStampedSessions,
    profileData,
  );
  const goal = typeof profileData.goal === "object" &&
      profileData.goal != null &&
      !Array.isArray(profileData.goal)
    ? profileData.goal as Record<string, unknown>
    : undefined;
  const sessionsWithoutRaceDate = removeSessionsOnRaceDate(
    truncatedSessions,
    typeof goal?.raceDate === "string" ? goal.raceDate : undefined,
  );
  const raceDate = typeof goal?.raceDate === "string"
    ? goal.raceDate
    : undefined;
  const preRaceTaperedSessions = enforcePreRaceTaper(
    sessionsWithoutRaceDate,
    profileData,
  );
  const raceDayDate = raceDate == null
    ? lastSessionDateInString(preRaceTaperedSessions)
    : raceDate;
  const sessionsBeforeRaceDayInfo = raceDayDate == null
    ? preRaceTaperedSessions
    : removeSessionsOnRaceDate(preRaceTaperedSessions, raceDayDate);
  return normalizeSessionIds(sessionsBeforeRaceDayInfo);
}

function lastSessionDateInString(
  sessions: ReadonlyArray<{ date: string }>,
): string | null {
  const sorted = sessions.map((session) => session.date?.slice(0, 10)).filter((
    date,
  ): date is string => typeof date === "string" && date.length > 0).sort();
  return sorted.length === 0 ? null : sorted[sorted.length - 1];
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
    phase: overrides.phase,
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
