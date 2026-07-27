import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { reflowPlan } from "./reflow-engine.ts";

function buildAvailability(
  overrides: Record<
    number,
    { available: boolean; maxDurationMinutes?: number }
  >,
): Record<string, { available: boolean; maxDurationMinutes: number }> {
  const availability: Record<
    string,
    { available: boolean; maxDurationMinutes: number }
  > = {};
  for (let day = 1; day <= 7; day += 1) {
    const value = overrides[day] ?? { available: true, maxDurationMinutes: 60 };
    availability[String(day)] = {
      available: value.available,
      maxDurationMinutes: value.maxDurationMinutes ?? 60,
    };
  }
  return availability;
}

function runSession(
  id: string,
  date: string,
  type: string,
  weekNumber: number,
  durationMinutes: number | null,
  opts: Record<string, unknown> = {},
) {
  return {
    id,
    date,
    weekNumber,
    type,
    ...(opts.phase == null ? {} : { phase: opts.phase }),
    ...(opts.status == null ? {} : { status: opts.status }),
    distanceKm: opts.distanceKm ?? 10,
    durationMinutes,
  };
}

function baseRequest(overrides: Record<string, unknown>) {
  return {
    sourcePlan: {
      id: "plan",
      sessions: [],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({}),
    targetRunningDays: 1,
    sameDayPreference: "separate_sessions",
    effectiveFrom: "2026-07-06",
    asOfDate: "2026-07-06",
    ...overrides,
  };
}

Deno.test("reflow preserves session id while moving within same week", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    availability: buildAvailability({
      1: { available: false, maxDurationMinutes: 60 },
      2: { available: false, maxDurationMinutes: 60 },
      3: { available: true, maxDurationMinutes: 60 },
    }),
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("run-a", "2026-07-07", "easyRun", 1, 45),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const moved = result.candidatePlan.sessions[0];
  assertEquals(moved.id, "run-a");
  assertEquals(moved.date, "2026-07-08");
  assertEquals(moved.type, "easyRun");
  const moveImpacts = result.impacts.filter((impact) => impact.key === "move");
  assertEquals(moveImpacts.length, 1);
  assertEquals(moveImpacts[0].sessionId, "run-a");
});

Deno.test("sessions before cutoff or explicitly immutable remain unchanged", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 2,
    immutableSessionIds: ["immutable"],
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("locked", "2026-07-01", "easyRun", 1, 40, {
          status: "completed",
        }),
        runSession("mutable", "2026-07-08", "easyRun", 1, 40),
        runSession("immutable", "2026-07-09", "easyRun", 1, 40),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: false, maxDurationMinutes: 20 },
      2: { available: false, maxDurationMinutes: 20 },
      3: { available: false, maxDurationMinutes: 20 },
      4: { available: true, maxDurationMinutes: 20 },
      5: { available: false, maxDurationMinutes: 20 },
      6: { available: false, maxDurationMinutes: 20 },
      7: { available: false, maxDurationMinutes: 20 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const sessions = result.candidatePlan.sessions;
  const locked = sessions.find((session) => session.id === "locked");
  const immutable = sessions.find((session) => session.id === "immutable");

  assertEquals(locked?.date, "2026-07-01");
  assertEquals(locked?.type, "easyRun");
  assertEquals(immutable?.date, "2026-07-09");
  assertEquals(immutable?.type, "easyRun");
});

Deno.test("mutable sessions do not move before cutoff inside their week", () => {
  const result = reflowPlan(baseRequest({
    effectiveFrom: "2026-07-08",
    asOfDate: "2026-07-08",
    targetRunningDays: 1,
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 60 },
      2: { available: true, maxDurationMinutes: 60 },
      3: { available: true, maxDurationMinutes: 60 },
      4: { available: false, maxDurationMinutes: 60 },
      5: { available: false, maxDurationMinutes: 60 },
      6: { available: true, maxDurationMinutes: 60 },
      7: { available: false, maxDurationMinutes: 60 },
    }),
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("friday-run", "2026-07-10", "easyRun", 1, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const updated = result.candidatePlan.sessions.find((session) =>
    session.id === "friday-run"
  );
  assert(updated != null);
  assert(updated!.date >= "2026-07-08");
  assert(updated!.date !== "2026-07-06");
  assert(updated!.date !== "2026-07-07");
});

Deno.test("long run prefers primary day when possible", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    primaryLongRunDay: 6,
    backupLongRunDay: 2,
    sourcePlan: {
      id: "plan",
      sessions: [runSession("long-primary", "2026-07-07", "longRun", 1, 100)],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({}),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;
  const moved = result.candidatePlan.sessions[0];
  assertEquals(moved.date, "2026-07-11");
  assert(!result.warnings.includes("long_run_backup"));
});

Deno.test("long run falls back to backup with warning when primary unavailable", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    primaryLongRunDay: 6,
    backupLongRunDay: 2,
    availability: buildAvailability({
      2: { available: true, maxDurationMinutes: 100 },
      6: { available: false, maxDurationMinutes: 100 },
      1: { available: true, maxDurationMinutes: 100 },
      3: { available: false, maxDurationMinutes: 100 },
      4: { available: false, maxDurationMinutes: 100 },
      5: { available: false, maxDurationMinutes: 100 },
      7: { available: false, maxDurationMinutes: 100 },
    }),
    sourcePlan: {
      id: "plan",
      sessions: [runSession("long-backup", "2026-07-08", "longRun", 1, 100)],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const moved = result.candidatePlan.sessions[0];
  assertEquals(moved.id, "long-backup");
  assertEquals(moved.date, "2026-07-07");
  assert(result.warnings.includes("long_run_backup"));
  assert(result.impacts.some((impact) => impact.key === "long_run_backup"));
});

Deno.test("time cap shortens duration and scales distance", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("long-distance", "2026-07-07", "easyRun", 1, 80, {
          distanceKm: 10,
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 45 },
      2: { available: false, maxDurationMinutes: 60 },
      3: { available: false, maxDurationMinutes: 60 },
      4: { available: false, maxDurationMinutes: 60 },
      5: { available: false, maxDurationMinutes: 60 },
      6: { available: false, maxDurationMinutes: 60 },
      7: { available: false, maxDurationMinutes: 60 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const updated = result.candidatePlan.sessions[0];

  assertEquals(updated.durationMinutes, 45);
  assertEquals(updated.distanceKm, 5.63);
  assert(
    result.impacts.some((impact) => impact.key === "shortened_for_time_cap"),
  );
});

Deno.test("phase-aware reductions keep taper quality session when possible", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("build-quality", "2026-07-07", "progressionRun", 1, 30, {
          phase: "build",
        }),
        runSession("taper-quality", "2026-07-08", "progressionRun", 1, 30, {
          phase: "taperRace",
        }),
        runSession("easy", "2026-07-09", "easyRun", 1, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const running = result.candidatePlan.sessions.filter((session) =>
    session.type !== "restDay"
  );
  assertEquals(running.length, 1);
  assertEquals(running[0].id, "taper-quality");
});

Deno.test("safe low priority removal emits constraints impact", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("run-a", "2026-07-07", "easyRun", 1, 30),
        runSession("run-b", "2026-07-08", "easyRun", 1, 30),
        runSession("run-c", "2026-07-09", "easyRun", 1, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysAfter, 1);
  assertEquals(result.goalImpact.removedSessions, 2);
  assertEquals(
    result.impacts.filter((impact) => impact.key === "removed_for_constraints")
      .length,
    2,
  );
  assert(result.warnings.includes("removed_for_constraints"));
});

Deno.test("same-date duplicate runs are counted as one running day", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("same-day-a", "2026-07-07", "easyRun", 1, 30),
        runSession("same-day-b", "2026-07-07", "easyRun", 1, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysBefore, 1);
  assertEquals(result.goalImpact.totalRunningDaysAfter, 1);
  assertEquals(result.goalImpact.removedSessions, 0);
  assertEquals(result.goalImpact.splitSessions, 0);
  assertEquals(result.goalImpact.weekly[0].beforeRunningDays, 1);
  assertEquals(result.goalImpact.weekly[0].afterRunningDays, 1);
  assertEquals(result.goalImpact.weekly[0].addedRunningDays, 0);
  assertEquals(result.goalImpact.weekly[0].removedRunningDays, 0);
});

Deno.test("frequency increase adds split run on an empty date", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 2,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("same-day-a", "2026-07-07", "easyRun", 1, 60),
        runSession("same-day-b", "2026-07-07", "easyRun", 1, 60),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const runSessions = result.candidatePlan.sessions
    .filter((session) => session.type === "easyRun");
  const runDates = new Set(runSessions.map((session) => session.date));

  assertEquals(result.goalImpact.totalRunningDaysBefore, 1);
  assertEquals(result.goalImpact.totalRunningDaysAfter, 2);
  assertEquals(result.goalImpact.splitSessions, 1);
  assertEquals(runSessions.length, 3);
  assertEquals(runDates.size, 2);
  assert(
    runSessions.some((session) =>
      session.id.includes("split") && session.date !== "2026-07-07"
    ),
  );
});

Deno.test("frequency reduction removes all mutable sessions on a removable date", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("mutable-a", "2026-07-07", "easyRun", 1, 30),
        runSession("mutable-b", "2026-07-07", "easyRun", 1, 30),
        runSession("locked", "2026-07-08", "easyRun", 1, 40, {
          status: "completed",
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysBefore, 2);
  assertEquals(result.goalImpact.totalRunningDaysAfter, 1);
  assertEquals(result.goalImpact.removedSessions, 2);
  assertEquals(
    result.impacts.filter((impact) => impact.key === "removed_for_constraints")
      .map((impact) => impact.sessionId)
      .sort(),
    ["mutable-a", "mutable-b"],
  );
  assertEquals(
    result.candidatePlan.sessions.filter((session) =>
      session.date === "2026-07-07" && session.type === "easyRun"
    ).length,
    0,
  );
});

Deno.test("locked running days warn when target running-day count is unreachable", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("locked-a", "2026-07-07", "easyRun", 1, 30, {
          status: "completed",
        }),
        runSession("locked-b", "2026-07-08", "easyRun", 1, 30, {
          status: "completed",
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysAfter, 2);
  assertEquals(result.goalImpact.removedSessions, 0);
  assert(result.warnings.includes("constraints_not_fully_supported"));
});

Deno.test("increasing frequency splits easy run without increasing load", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 2,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("single", "2026-07-07", "easyRun", 1, 60, {
          distanceKm: 12,
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysAfter, 2);
  assertEquals(result.goalImpact.totalRunningDaysBefore, 1);
  assertEquals(result.goalImpact.splitSessions, 1);

  const runSessions = result.candidatePlan.sessions
    .filter((session) => session.type === "easyRun");

  assertEquals(runSessions.length, 2);
  assertEquals(
    runSessions.reduce(
      (sum, session) => sum + (session.durationMinutes ?? 0),
      0,
    ),
    60,
  );
  assertEquals(
    runSessions.reduce((sum, session) => sum + (session.distanceKm ?? 0), 0),
    12,
  );
  assert(runSessions.some((session) => session.id.startsWith("single-split")));
});

Deno.test("frequency increase repeatedly splits a single mutable run to hit target", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 3,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("single", "2026-07-07", "easyRun", 1, 60, {
          distanceKm: 12,
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysBefore, 1);
  assertEquals(result.goalImpact.totalRunningDaysAfter, 3);
  assertEquals(result.goalImpact.splitSessions, 2);

  const runs = result.candidatePlan.sessions.filter((session) =>
    session.type === "easyRun"
  );

  assertEquals(runs.length, 3);
  assertEquals(
    runs.reduce((sum, session) => sum + (session.durationMinutes ?? 0), 0),
    60,
  );
  assertEquals(
    runs.reduce((sum, session) => sum + (session.distanceKm ?? 0), 0),
    12,
  );
  const runDates = new Set(runs.map((session) => session.date));
  assertEquals(runDates.size, 3);
  assert(runDates.has("2026-07-06"));
  assert(runDates.has("2026-07-07"));
  assert(runDates.has("2026-07-08"));
  assert(
    !result.warnings.includes("constraints_not_fully_supported"),
  );
});

Deno.test(
  "frequency split avoids split-id collisions with future-looking source IDs",
  () => {
    const request = {
      targetRunningDays: 3,
      sourcePlan: {
        id: "plan",
        sessions: [
          runSession("single", "2026-07-07", "easyRun", 1, 60, {
            distanceKm: 12,
          }),
          runSession("single-split-1", "2026-07-07", "easyRun", 1, 30),
        ],
        currentWeekNumber: 1,
        totalWeeks: 4,
      },
    };

    const first = reflowPlan(baseRequest(request));
    const second = reflowPlan(baseRequest(request));

    assertEquals(first.ok, true);
    assertEquals(second.ok, true);
    if (!first.ok || !second.ok) return;

    const firstRuns = first.candidatePlan.sessions.filter((session) =>
      session.type === "easyRun"
    ).map((session) => session.id);
    const secondRuns = second.candidatePlan.sessions.filter((session) =>
      session.type === "easyRun"
    ).map((session) => session.id);
    const firstSplitImpacts = first.impacts
      .filter((impact) => impact.key === "split_for_frequency")
      .map((impact) => impact.sessionId);
    const secondSplitImpacts = second.impacts
      .filter((impact) => impact.key === "split_for_frequency")
      .map((impact) => impact.sessionId);

    assertEquals(first.goalImpact.splitSessions, 2);
    assertEquals(second.goalImpact.splitSessions, 2);
    assertEquals(new Set(firstRuns).size, firstRuns.length);
    assertEquals(new Set(secondRuns).size, secondRuns.length);
    assertEquals(new Set(firstSplitImpacts).size, firstSplitImpacts.length);
    assertEquals(new Set(secondSplitImpacts).size, secondSplitImpacts.length);
    assert(!firstSplitImpacts.includes("single-split-1"));
    assert(!secondSplitImpacts.includes("single-split-1"));
    assertEquals(firstRuns.sort(), secondRuns.sort());
    assertEquals(first.goalImpact.totalRunningDaysAfter, 3);
    assertEquals(second.goalImpact.totalRunningDaysAfter, 3);
  },
);

Deno.test(
  "frequency split preserves cap constraints for source and split destination",
  () => {
    const result = reflowPlan(baseRequest({
      targetRunningDays: 2,
      availability: buildAvailability({
        1: { available: false, maxDurationMinutes: 60 },
        2: { available: true, maxDurationMinutes: 20 },
        3: { available: false, maxDurationMinutes: 60 },
        4: { available: false, maxDurationMinutes: 60 },
        5: { available: true, maxDurationMinutes: 60 },
        6: { available: false, maxDurationMinutes: 60 },
        7: { available: false, maxDurationMinutes: 60 },
      }),
      sourcePlan: {
        id: "plan",
        sessions: [
          runSession("single", "2026-07-10", "easyRun", 1, 60, {
            distanceKm: 12,
          }),
        ],
        currentWeekNumber: 1,
        totalWeeks: 4,
      },
    }));

    assertEquals(result.ok, true);
    if (!result.ok) return;

    const runs = result.candidatePlan.sessions.filter((session) =>
      session.type === "easyRun"
    );
    assertEquals(runs.length, 2);
    assertEquals(
      runs.reduce(
        (sum, session) => sum + (session.durationMinutes ?? 0),
        0,
      ),
      60,
    );
    assertEquals(
      runs.reduce((sum, session) => sum + (session.distanceKm ?? 0), 0),
      12,
    );

    const source = runs.find((session) => !session.id.includes("split"));
    const split = runs.find((session) => session.id.includes("split"));
    assert(source != null);
    assert(split != null);
    assert(source != null && split != null);
    assert(source!.durationMinutes! <= 60);
    assert(split!.durationMinutes! <= 20);
    assertEquals(split!.date, "2026-07-07");
    assertEquals(split!.durationMinutes, 20);
  },
);

Deno.test("frequency split honors mid-week cutoff for new split sessions", () => {
  const result = reflowPlan(baseRequest({
    effectiveFrom: "2026-07-08",
    asOfDate: "2026-07-08",
    targetRunningDays: 2,
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 20 },
      2: { available: true, maxDurationMinutes: 20 },
      3: { available: true, maxDurationMinutes: 20 },
      4: { available: true, maxDurationMinutes: 20 },
      5: { available: true, maxDurationMinutes: 60 },
      6: { available: false, maxDurationMinutes: 60 },
      7: { available: false, maxDurationMinutes: 60 },
    }),
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("single", "2026-07-10", "easyRun", 1, 60, {
          distanceKm: 12,
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const runs = result.candidatePlan.sessions
    .filter((session) => session.type === "easyRun");
  assertEquals(runs.length, 2);
  const source = runs.find((session) => session.id === "single");
  assert(source != null);
  assertEquals(source.date, "2026-07-10");
  const split = runs.find((session) => session.id.includes("split"));
  assert(split != null);
  assertEquals(split!.date, "2026-07-08");
  assert(split!.date >= "2026-07-08");
});

Deno.test("frequency split emits warning when no cap-feasible destination exists", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 2,
    availability: buildAvailability({
      1: { available: false, maxDurationMinutes: 60 },
      2: { available: false, maxDurationMinutes: 60 },
      3: { available: false, maxDurationMinutes: 60 },
      4: { available: false, maxDurationMinutes: 60 },
      5: { available: true, maxDurationMinutes: 60 },
      6: { available: false, maxDurationMinutes: 60 },
      7: { available: false, maxDurationMinutes: 60 },
    }),
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("single", "2026-07-10", "easyRun", 1, 60, {
          distanceKm: 12,
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.goalImpact.totalRunningDaysAfter, 1);
  assertEquals(result.goalImpact.splitSessions, 0);
  assert(result.warnings.includes("constraints_not_fully_supported"));
  assert(
    result.candidatePlan.sessions.every((session) =>
      session.durationMinutes === 60
    ),
  );
});

Deno.test("runs never move across week boundaries", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("w1", "2026-07-07", "easyRun", 1, 30),
        runSession("w2", "2026-07-14", "easyRun", 2, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: false, maxDurationMinutes: 30 },
      2: { available: false, maxDurationMinutes: 30 },
      3: { available: true, maxDurationMinutes: 30 },
      4: { available: false, maxDurationMinutes: 30 },
      5: { available: false, maxDurationMinutes: 30 },
      6: { available: false, maxDurationMinutes: 30 },
      7: { available: false, maxDurationMinutes: 30 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const sessions = result.candidatePlan.sessions;
  const w1Date = sessions.find((session) => session.id === "w1")!.date;
  const w2Date = sessions.find((session) => session.id === "w2")!.date;

  assert(w1Date >= "2026-07-06");
  assert(w1Date <= "2026-07-12");
  assert(w2Date >= "2026-07-13");
  assert(w2Date <= "2026-07-19");
});

Deno.test("separate_sessions preserves valid existing run date", () => {
  const result = reflowPlan(baseRequest({
    sameDayPreference: "separate_sessions",
    strengthWeekdays: [2],
    sourcePlan: {
      id: "plan",
      sessions: [runSession("strength", "2026-07-07", "easyRun", 1, 30)],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 30 },
      2: { available: true, maxDurationMinutes: 30 },
      3: { available: true, maxDurationMinutes: 30 },
      4: { available: true, maxDurationMinutes: 30 },
      5: { available: true, maxDurationMinutes: 30 },
      6: { available: true, maxDurationMinutes: 30 },
      7: { available: true, maxDurationMinutes: 30 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const updated = result.candidatePlan.sessions[0];
  assertEquals(updated.date, "2026-07-07");
});

Deno.test("avoid_same_day avoids strength weekdays", () => {
  const result = reflowPlan(baseRequest({
    sameDayPreference: "avoid_same_day",
    strengthWeekdays: [2],
    sourcePlan: {
      id: "plan",
      sessions: [runSession("strength", "2026-07-07", "easyRun", 1, 30)],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 30 },
      2: { available: true, maxDurationMinutes: 30 },
      3: { available: true, maxDurationMinutes: 30 },
      4: { available: true, maxDurationMinutes: 30 },
      5: { available: true, maxDurationMinutes: 30 },
      6: { available: true, maxDurationMinutes: 30 },
      7: { available: true, maxDurationMinutes: 30 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const updated = result.candidatePlan.sessions[0];
  assertEquals(updated.date, "2026-07-06");
});

Deno.test("one-run warning is emitted when target cannot be maintained", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 2,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("one", "2026-07-07", "easyRun", 1, 30),
        runSession("two", "2026-07-08", "easyRun", 1, 30),
        runSession("three", "2026-07-09", "easyRun", 1, 30),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
    availability: buildAvailability({
      1: { available: true, maxDurationMinutes: 30 },
      2: { available: false, maxDurationMinutes: 30 },
      3: { available: false, maxDurationMinutes: 30 },
      4: { available: false, maxDurationMinutes: 30 },
      5: { available: false, maxDurationMinutes: 30 },
      6: { available: false, maxDurationMinutes: 30 },
      7: { available: false, maxDurationMinutes: 30 },
    }),
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  assert(result.warnings.includes("one_run_warning"));
  assertEquals(result.goalImpact.totalRunningDaysAfter, 1);
});

Deno.test("malformed input fails request validation", () => {
  const result = reflowPlan({
    sourcePlan: {
      id: "plan",
      sessions: [runSession("run", "2026-07-07", "easyRun", 1, 30)],
    },
    availability: {
      1: { available: true, maxDurationMinutes: 30 },
      2: { available: true, maxDurationMinutes: 30 },
    },
    targetRunningDays: 1,
    sameDayPreference: "it_depends",
    effectiveFrom: "2026-07-06",
    asOfDate: "2026-07-06",
  });

  assertEquals(result.ok, false);
  if (result.ok) return;
  assertEquals(result.reason, "invalid_request");
});

Deno.test("malformed input with uppercase status is rejected", () => {
  const result = reflowPlan(baseRequest({
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("run", "2026-07-07", "easyRun", 1, 30, {
          status: "Completed",
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, false);
  if (result.ok) return;
  assertEquals(result.reason, "invalid_request");
});

Deno.test("reflow accepts persisted app statuses and preserves non-running session types", () => {
  const result = reflowPlan(baseRequest({
    targetRunningDays: 1,
    sourcePlan: {
      id: "plan",
      sessions: [
        runSession("upcoming-run", "2026-07-07", "easyRun", 1, 30, {
          status: "upcoming",
        }),
        runSession("cross-training", "2026-07-08", "crossTraining", 1, 30, {
          status: "today",
        }),
        runSession("race-day", "2026-07-12", "raceDay", 1, null, {
          status: "upcoming",
        }),
      ],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, true);
  if (!result.ok) return;

  const crossTraining = result.candidatePlan.sessions.find((session) =>
    session.id === "cross-training"
  );
  const raceDay = result.candidatePlan.sessions.find((session) =>
    session.id === "race-day"
  );
  assertEquals(crossTraining?.type, "crossTraining");
  assertEquals(crossTraining?.date, "2026-07-08");
  assertEquals(raceDay?.type, "raceDay");
  assertEquals(raceDay?.date, "2026-07-12");
});

Deno.test("unsupported same-day preference values are rejected", () => {
  const unsupportedResult = reflowPlan(baseRequest({
    sameDayPreference: "run_first",
  }));

  assertEquals(unsupportedResult.ok, false);
  if (unsupportedResult.ok) return;
  assertEquals(unsupportedResult.reason, "invalid_request");

  const unsupportedLiftResult = reflowPlan(baseRequest({
    sameDayPreference: "lift_first",
  }));

  assertEquals(unsupportedLiftResult.ok, false);
  if (unsupportedLiftResult.ok) return;
  assertEquals(unsupportedLiftResult.reason, "invalid_request");
});

Deno.test("malformed input with invalid type is rejected", () => {
  const result = reflowPlan(baseRequest({
    sourcePlan: {
      id: "plan",
      sessions: [runSession("run", "2026-07-07", "run", 1, 30)],
      currentWeekNumber: 1,
      totalWeeks: 4,
    },
  }));

  assertEquals(result.ok, false);
  if (result.ok) return;
  assertEquals(result.reason, "invalid_request");
});
