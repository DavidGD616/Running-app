import {
  adaptationJsonSchema,
  applyPatchesToPlan,
  buildWeeklyTrainingSummary,
  currentDateAtTimezoneOffset,
  parseTimezoneOffsetMinutes,
  revalidateAdaptationForAcceptance,
  revalidateAdaptationForAcceptanceAtInstant,
  validateAdaptationPatches,
} from "./index.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function assertStrictObjectSchemas(
  schema: Record<string, unknown>,
  path = "$",
): void {
  if (schema.type === "object") {
    const properties = schema.properties as Record<
      string,
      Record<string, unknown>
    >;
    const required = new Set(schema.required as string[]);
    assertEquals(
      [...required].sort(),
      Object.keys(properties).sort(),
      `${path} must require every declared property`,
    );
    for (const [name, property] of Object.entries(properties)) {
      assertStrictObjectSchemas(property, `${path}.${name}`);
    }
  }

  if (schema.type === "array") {
    assertStrictObjectSchemas(
      schema.items as Record<string, unknown>,
      `${path}[]`,
    );
  }
}

Deno.test("adaptation JSON schema satisfies strict structured outputs", () => {
  const schema = adaptationJsonSchema();
  assertStrictObjectSchemas(schema);

  const patches = (schema.properties as Record<string, Record<string, unknown>>)
    .patches;
  const patchProperties = (patches.items as Record<string, unknown>)
    .properties as Record<string, Record<string, unknown>>;
  for (
    const optionalName of [
      "sessionId",
      "targetDate",
      "targetType",
      "targetDistanceKm",
      "targetDurationMinutes",
    ]
  ) {
    const property = patchProperties[optionalName];
    const types = Array.isArray(property.type)
      ? property.type
      : [property.type];
    assertEquals(
      types.includes("null"),
      true,
      `${optionalName} must be nullable instead of omitted`,
    );
  }
});

Deno.test("nullable structured fields are omitted from sanitized patches", () => {
  const result = validateAdaptationPatches(
    [{
      type: "noChange",
      sessionId: null,
      targetDate: null,
      targetType: null,
      targetDistanceKm: null,
      targetDurationMinutes: null,
      reasonKey: "adapt_reason_no_change",
    }],
    [],
    {
      weekStart: "2026-07-06",
      weekEnd: "2026-07-12",
      plannedSessions: 0,
      completedSessions: 0,
      skippedSessions: 0,
      plannedDistanceKm: 0,
      completedDistanceKm: 0,
      plannedDurationMinutes: 0,
      completedDurationMinutes: 0,
      plannedHardSessions: 0,
      completedHardSessions: 0,
      veryHardFeedbackCount: 0,
      poorRecoveryCount: 0,
      painFeedbackCount: 0,
      completionRatio: 0,
      distanceRatio: 0,
      classification: "insufficient_data",
      severity: "info",
      reasonKeys: [],
    },
  );

  assertEquals(result, {
    ok: true,
    patches: [{
      type: "noChange",
      reasonKey: "adapt_reason_no_change",
    }],
  });
});

Deno.test("timezone offsets derive the runner's date across UTC midnight", () => {
  assertEquals(
    currentDateAtTimezoneOffset(
      new Date("2026-07-06T06:30:00.000Z"),
      -7 * 60,
    ),
    "2026-07-05",
  );
  assertEquals(
    currentDateAtTimezoneOffset(
      new Date("2026-07-05T11:30:00.000Z"),
      14 * 60,
    ),
    "2026-07-06",
  );
});

Deno.test("timezone offsets accept real bounds and reject malformed values", () => {
  assertEquals(parseTimezoneOffsetMinutes(undefined), 0);
  assertEquals(parseTimezoneOffsetMinutes(-12 * 60), -12 * 60);
  assertEquals(parseTimezoneOffsetMinutes(14 * 60), 14 * 60);
  for (const value of [null, "-420", 1.5, -12 * 60 - 1, 14 * 60 + 1]) {
    assertEquals(parseTimezoneOffsetMinutes(value), null);
  }
});

Deno.test("acceptance revalidation uses the persisted local date context", () => {
  const input = {
    plan: {
      sessions: [{
        id: "pacific-sunday",
        date: "2026-07-05T00:00:00.000Z",
        type: "easyRun",
        distanceKm: 5,
        durationMinutes: 35,
      }],
    },
    patches: [{
      type: "progressSlightly" as const,
      sessionId: "pacific-sunday",
      targetDistanceKm: 5.2,
      reasonKey: "adapt_reason_progress",
    }],
    activities: [],
    feedback: [],
    weekStart: "2026-06-29",
    weekEnd: "2026-07-05",
  };
  const instant = new Date("2026-07-06T06:30:00.000Z");

  const localResult = revalidateAdaptationForAcceptanceAtInstant({
    ...input,
    instant,
    timezoneOffsetMinutes: -7 * 60,
  });
  const utcResult = revalidateAdaptationForAcceptance({
    ...input,
    asOfDate: "2026-07-06",
  });

  assertEquals(localResult.ok, true);
  assertEquals(utcResult, { ok: false, reason: "unknown_session" });
});

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

const safeSummary = {
  weekStart: "2026-07-06",
  weekEnd: "2026-07-12",
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
  painFeedbackCount: 0,
  completionRatio: 1,
  distanceRatio: 1,
  classification: "on_track" as const,
  severity: "info" as const,
  reasonKeys: ["adapt_reason_on_track"],
};

const remainingSessions = [
  {
    id: "today-1",
    date: "2026-07-09T00:00:00.000Z",
    type: "recoveryRun" as const,
    distanceKm: 3,
    durationMinutes: 25,
  },
  {
    id: "easy-1",
    date: "2026-07-10T00:00:00.000Z",
    type: "easyRun" as const,
    distanceKm: 5,
    durationMinutes: 35,
  },
  {
    id: "long-1",
    date: "2026-07-12T00:00:00.000Z",
    type: "longRun" as const,
    distanceKm: 12,
    durationMinutes: 75,
  },
  {
    id: "easy-2",
    date: "2026-07-20T00:00:00.000Z",
    type: "easyRun" as const,
    distanceKm: 6,
    durationMinutes: 40,
  },
];

function validate(
  patches: Parameters<typeof validateAdaptationPatches>[0],
) {
  return validateAdaptationPatches(
    patches,
    remainingSessions,
    safeSummary,
    { asOfDate: "2026-07-09" },
  );
}

Deno.test("validateAdaptationPatches requires exclusive noChange", () => {
  assertEquals(
    validate([
      { type: "noChange", reasonKey: "adapt_reason_no_change" },
      {
        type: "moveSession",
        sessionId: "easy-1",
        targetDate: "2026-07-11",
        reasonKey: "adapt_reason_move",
      },
    ]),
    { ok: false, reason: "no_change_must_be_exclusive" },
  );
  assertEquals(
    validate([{
      type: "noChange",
      sessionId: "easy-1",
      reasonKey: "adapt_reason_no_change",
    }]),
    { ok: false, reason: "no_change_has_target_fields" },
  );
});

Deno.test("validateAdaptationPatches rejects unsupported repeatWeek", () => {
  assertEquals(
    validate([{
      type: "repeatWeek",
      sessionId: "easy-1",
      reasonKey: "adapt_reason_repeat",
    }]),
    { ok: false, reason: "unsupported_patch_type" },
  );
});

Deno.test("validateAdaptationPatches enforces reduction semantics", () => {
  assertEquals(
    validate([{
      type: "reduceSession",
      sessionId: "easy-1",
      reasonKey: "adapt_reason_reduce",
    }]),
    { ok: false, reason: "reduction_requires_target_metric" },
  );
  assertEquals(
    validate([{
      type: "reduceSession",
      sessionId: "easy-1",
      targetDistanceKm: 5,
      targetDurationMinutes: 35,
      reasonKey: "adapt_reason_reduce",
    }]),
    { ok: false, reason: "reduction_must_reduce_metric" },
  );
  assertEquals(
    validate([{
      type: "reduceSession",
      sessionId: "easy-1",
      targetDistanceKm: 4,
      targetDurationMinutes: 36,
      reasonKey: "adapt_reason_reduce",
    }]),
    { ok: false, reason: "reduction_cannot_increase_metric" },
  );
  assertEquals(
    validate([{
      type: "reduceSession",
      sessionId: "easy-1",
      targetDistanceKm: 4,
      targetDurationMinutes: 35,
      reasonKey: "adapt_reason_reduce",
    }]).ok,
    true,
  );
});

Deno.test("validateAdaptationPatches only shortens long runs", () => {
  assertEquals(
    validate([{
      type: "shortenLongRun",
      sessionId: "easy-1",
      targetDistanceKm: 4,
      reasonKey: "adapt_reason_shorten",
    }]),
    { ok: false, reason: "shorten_requires_long_run" },
  );
  assertEquals(
    validate([{
      type: "shortenLongRun",
      sessionId: "long-1",
      targetDistanceKm: 12,
      targetDurationMinutes: 75,
      reasonKey: "adapt_reason_shorten",
    }]),
    { ok: false, reason: "reduction_must_reduce_metric" },
  );
  assertEquals(
    validate([{
      type: "shortenLongRun",
      sessionId: "long-1",
      targetDurationMinutes: 70,
      reasonKey: "adapt_reason_shorten",
    }]).ok,
    true,
  );
});

Deno.test("validateAdaptationPatches enforces progression direction and cap", () => {
  assertEquals(
    validate([{
      type: "progressSlightly",
      sessionId: "easy-1",
      targetDistanceKm: 5,
      reasonKey: "adapt_reason_progress",
    }]),
    { ok: false, reason: "progression_must_increase_metric" },
  );
  assertEquals(
    validate([{
      type: "progressSlightly",
      sessionId: "easy-1",
      targetDistanceKm: 5.2,
      targetDurationMinutes: 34,
      reasonKey: "adapt_reason_progress",
    }]),
    { ok: false, reason: "progression_cannot_reduce_metric" },
  );
  assertEquals(
    validate([{
      type: "progressSlightly",
      sessionId: "easy-1",
      targetDistanceKm: 5.5,
      reasonKey: "adapt_reason_progress",
    }]),
    { ok: false, reason: "distance_increase_too_large" },
  );
  assertEquals(
    validate([{
      type: "progressSlightly",
      sessionId: "easy-1",
      targetDistanceKm: 5.4,
      reasonKey: "adapt_reason_progress",
    }]).ok,
    true,
  );
});

Deno.test("validateAdaptationPatches requires a different replacement type", () => {
  assertEquals(
    validate([{
      type: "replaceSession",
      sessionId: "easy-1",
      reasonKey: "adapt_reason_replace",
    }]),
    { ok: false, reason: "replacement_requires_target_type" },
  );
  assertEquals(
    validate([{
      type: "replaceSession",
      sessionId: "easy-1",
      targetType: "easyRun",
      reasonKey: "adapt_reason_replace",
    }]),
    { ok: false, reason: "replacement_must_change_type" },
  );
});

Deno.test("validateAdaptationPatches validates move dates and plan bounds", () => {
  const cases = [
    ["2026-7-11", "invalid_target_date"],
    ["2026-02-30", "invalid_target_date"],
    ["2026-07-08", "target_date_must_be_future"],
    ["2026-07-09", "target_date_must_be_future"],
    ["2026-07-10", "move_must_change_date"],
    ["2026-07-21", "target_date_outside_plan"],
  ] as const;
  for (const [targetDate, reason] of cases) {
    assertEquals(
      validate([{
        type: "moveSession",
        sessionId: "easy-1",
        targetDate,
        reasonKey: "adapt_reason_move",
      }]),
      { ok: false, reason },
    );
  }
  assertEquals(
    validate([{
      type: "moveSession",
      sessionId: "easy-1",
      targetDate: "2026-07-11",
      reasonKey: "adapt_reason_move",
    }]).ok,
    true,
  );
});

Deno.test("acceptance revalidation uses fresh safety signals", () => {
  const result = revalidateAdaptationForAcceptance({
    plan: {
      sessions: [
        {
          id: "completed-1",
          date: "2026-07-07T00:00:00.000Z",
          type: "easyRun",
          distanceKm: 5,
          durationMinutes: 35,
        },
        remainingSessions[1],
      ],
    },
    patches: [{
      type: "progressSlightly",
      sessionId: "easy-1",
      targetDistanceKm: 5.2,
      reasonKey: "adapt_reason_progress",
    }],
    activities: [],
    feedback: [{
      plannedSessionId: "completed-1",
      difficulty: null,
      recoveryStatus: null,
      sleep: null,
      legs: null,
      pain: "pain_mild",
      motivation: null,
      recordedAt: "2026-07-07T12:00:00.000Z",
    }],
    weekStart: "2026-07-06",
    weekEnd: "2026-07-12",
    asOfDate: "2026-07-09",
  });

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.reason, "progression_blocked_by_high_severity");
  }
});
