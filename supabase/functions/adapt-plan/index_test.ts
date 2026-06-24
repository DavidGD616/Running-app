import {
  applyPatchesToPlan,
  buildWeeklyTrainingSummary,
  validateAdaptationPatches,
} from "./index.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("buildWeeklyTrainingSummary flags pain as recovery needed", () => {
  const summary = buildWeeklyTrainingSummary({
    weekStart: "2026-06-22",
    weekEnd: "2026-06-28",
    plan: {
      sessions: [
        {
          id: "s1",
          date: "2026-06-23T00:00:00.000Z",
          type: "intervals",
          distanceKm: 6,
          durationMinutes: 45,
        },
      ],
    },
    activities: [
      {
        id: "a1",
        linkedSessionId: "s1",
        completionStatus: "completed",
        actualDistanceKm: 6,
        actualDurationMinutes: 45,
        perceivedEffort: "effort_hard",
        recordedAt: "2026-06-23T12:00:00.000Z",
      },
    ],
    feedback: [
      {
        plannedSessionId: "s1",
        difficulty: "feedback_very_hard",
        recoveryStatus: "recovery_fatigued",
        sleep: "sleep_poor",
        legs: "legs_heavy",
        pain: "pain_mild",
        motivation: "motivation_okay",
        recordedAt: "2026-06-23T12:10:00.000Z",
      },
    ],
  });

  assertEquals(summary.classification, "recovery_needed");
  assertEquals(summary.severity, "high");
  assertEquals(summary.painFeedbackCount, 1);
});

Deno.test("buildWeeklyTrainingSummary ignores future and same-day incomplete sessions", () => {
  const summary = buildWeeklyTrainingSummary({
    weekStart: "2026-06-22",
    weekEnd: "2026-06-28",
    asOfDate: "2026-06-24",
    plan: {
      sessions: [
        {
          id: "past-complete",
          date: "2026-06-23T00:00:00.000Z",
          type: "easyRun",
          distanceKm: 5,
          durationMinutes: 35,
        },
        {
          id: "today-incomplete",
          date: "2026-06-24T00:00:00.000Z",
          type: "easyRun",
          distanceKm: 6,
          durationMinutes: 40,
        },
        {
          id: "future",
          date: "2026-06-26T00:00:00.000Z",
          type: "longRun",
          distanceKm: 12,
          durationMinutes: 75,
        },
      ],
    },
    activities: [
      {
        id: "activity-past",
        linkedSessionId: "past-complete",
        completionStatus: "completed",
        actualDistanceKm: 5,
        actualDurationMinutes: 35,
        perceivedEffort: null,
        recordedAt: "2026-06-23T12:00:00.000Z",
      },
    ],
    feedback: [],
  });

  assertEquals(summary.plannedSessions, 1);
  assertEquals(summary.completedSessions, 1);
  assertEquals(summary.skippedSessions, 0);
  assertEquals(summary.classification, "on_track");
});

Deno.test("validateAdaptationPatches rejects intensity when pain is reported", () => {
  const result = validateAdaptationPatches(
    [
      {
        type: "replaceSession",
        sessionId: "s2",
        targetType: "intervals",
        reasonKey: "adapt_reason_bad",
      },
    ],
    [
      {
        id: "s2",
        date: "2026-06-25T00:00:00.000Z",
        type: "easyRun",
        distanceKm: 5,
        durationMinutes: 35,
      },
    ],
    {
      weekStart: "2026-06-22",
      weekEnd: "2026-06-28",
      plannedSessions: 1,
      completedSessions: 1,
      skippedSessions: 0,
      plannedDistanceKm: 5,
      completedDistanceKm: 5,
      plannedDurationMinutes: 35,
      completedDurationMinutes: 35,
      plannedHardSessions: 0,
      completedHardSessions: 0,
      veryHardFeedbackCount: 0,
      poorRecoveryCount: 0,
      painFeedbackCount: 1,
      completionRatio: 1,
      distanceRatio: 1,
      classification: "recovery_needed",
      severity: "high",
      reasonKeys: ["adapt_reason_pain_reported"],
    },
  );

  assertEquals(result.ok, false);
});

Deno.test("applyPatchesToPlan updates future session fields", () => {
  const plan = {
    id: "plan-1",
    paceZones: {
      recovery: { paceMinSecPerKm: 420, paceMaxSecPerKm: 460 },
      easy: { paceMinSecPerKm: 360, paceMaxSecPerKm: 400 },
    },
    sessions: [
      {
        id: "s1",
        date: "2026-06-25T00:00:00.000Z",
        type: "intervals",
        distanceKm: 8,
        durationMinutes: 50,
        intervalReps: 6,
        intervalRepDistanceMeters: 400,
        intervalRecoverySeconds: 90,
      },
    ],
  };

  const next = applyPatchesToPlan(plan, [
    {
      type: "replaceSession",
      sessionId: "s1",
      targetType: "easyRun",
      targetDistanceKm: 5,
      targetDurationMinutes: 35,
      reasonKey: "adapt_reason_high_effort_recovery",
    },
  ]);

  const session = (next.sessions as Array<Record<string, unknown>>)[0];
  assertEquals(session.type, "easyRun");
  assertEquals(session.distanceKm, 5);
  assertEquals(session.durationMinutes, 35);
  assertEquals(session.targetZone, "easy");
});
