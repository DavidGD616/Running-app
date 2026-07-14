import {
  AcceptRequestSchema,
  buildWarnings,
  createEditGoalHandler,
  type EditGoalDependencies,
  mapRpcError,
  mergeImmutableHistory,
  PreviewRequestSchema,
  summarizePlanChanges,
} from "./handler.ts";
import type { CandidatePlan } from "../generate-plan/candidate-builder.ts";
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const profile = {
  goal: { race: "race_10k", hasRaceDate: true, raceDate: "2026-10-01" },
  acceptedRaceTarget: {
    distanceKm: 10,
    primaryTimeMs: 3_600_000,
    evidence: [],
  },
  fitnessSource: "manual",
  fitness: {
    fitnessSource: "manual",
    experience: "experience_intermediate",
    weeklyVolume: "weekly_volume_3",
    longestRun: "longest_run_3",
    benchmark: "benchmark_skip",
  },
  schedule: {
    trainingDays: 3,
    longRunDay: "day_sun",
    weekdayTime: "time_45_min",
    weekendTime: "time_60_min",
    preferredTimeOfDay: "time_of_day_morning",
    unavailableDays: [],
  },
};

const sourcePlan = {
  id: "source-plan",
  currentWeekNumber: 2,
  totalWeeks: 4,
  sessions: [
    session("past", "2026-07-12", "easyRun", 1, 5),
    session("completed", "2026-07-13", "tempoRun", 2, 7, 30, "completed"),
    session("skipped", "2026-07-15", "longRun", 2, 10, 30, "skipped"),
    session("replace", "2026-07-16", "easyRun", 2, 5, 30, "upcoming"),
  ],
};

const candidatePlan = {
  id: "candidate",
  currentWeekNumber: 1,
  totalWeeks: 2,
  sessions: [
    session("generated-completed", "2026-07-13", "restDay", 1, null),
    session("generated-skipped", "2026-07-15", "easyRun", 1, 4),
    session("new-replacement", "2026-07-16", "intervals", 1, 6),
    session("new-date", "2026-07-20", "longRun", 2, 12),
  ],
};

Deno.test("preview schema strictly validates goal and date consistency", () => {
  assert(PreviewRequestSchema.safeParse(previewBody()).success);
  assertEquals(
    PreviewRequestSchema.safeParse(previewBody({ race: "race_other" })).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse(previewBody({ targetTimeSeconds: 0 }))
      .success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse(
      previewBody({ raceDate: "2026-07-19" }),
    ).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse(
      previewBody({ hasRaceDate: false, raceDate: "2026-08-01" }),
    ).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse(previewBody({ unexpected: true })).success,
    false,
  );
  assert(
    AcceptRequestSchema.safeParse({ action: "accept", proposalId: "p" })
      .success,
  );
});

Deno.test("handler requires bearer auth and scopes preview loads to token user", async () => {
  const seen: string[] = [];
  const deps = fakeDependencies({
    authenticate: async () => "token-user",
    loadPreviewContext: async (userId) => {
      seen.push(userId);
      return null;
    },
  });
  const handler = createEditGoalHandler(deps);
  assertEquals(
    (await handler(new Request("http://local", { method: "POST" }))).status,
    401,
  );
  const response = await handler(request(previewBody()));
  assertEquals(response.status, 409);
  assertEquals(seen, ["token-user"]);
});

Deno.test("preview stores a proposal without invoking acceptance", async () => {
  let storeCount = 0;
  let acceptCount = 0;
  let storedUser: string | null = null;
  const deps = fakeDependencies({
    storeProposal: async (input) => {
      storeCount++;
      storedUser = input.userId;
      return { id: input.proposalId, expires_at: input.expiresAt };
    },
    acceptProposal: async () => {
      acceptCount++;
      throw new Error("must not activate during preview");
    },
  });
  const response = await createEditGoalHandler(deps)(request(previewBody()));
  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.proposalId, "fixed-id");
  assertEquals(json.sourcePlanVersionId, "source-plan");
  assertEquals(storeCount, 1);
  assertEquals(acceptCount, 0);
  assertEquals(storedUser, "token-user");
});

Deno.test("immutable merge preserves terminal statuses without linkage rows", () => {
  const merged = mergeImmutableHistory({
    sourcePlan,
    candidatePlan,
    localDate: "2026-07-13",
    activityLinkedSessionIds: [],
    skipAdjustmentSessionIds: [],
  });
  const sessions = merged.plan.sessions as Record<string, unknown>[];
  assertEquals(sessions.map((item) => item.id), [
    "past",
    "completed",
    "skipped",
    "new-replacement",
    "new-date",
  ]);
  assertEquals(
    sessions[1],
    (sourcePlan.sessions as Record<string, unknown>[])[1],
  );
  assertEquals(
    sessions[2],
    (sourcePlan.sessions as Record<string, unknown>[])[2],
  );
  assertEquals(merged.plan.currentWeekNumber, 2);
  assertEquals(merged.plan.totalWeeks, 3);
});

Deno.test("unknown missing and nonterminal statuses remain replaceable", () => {
  const replaceableSource = {
    currentWeekNumber: 2,
    sessions: [
      session("upcoming", "2026-07-14", "easyRun", 2, 5, 30, "upcoming"),
      session("unknown", "2026-07-15", "tempoRun", 2, 7, 30, "done"),
      session("missing", "2026-07-16", "longRun", 2, 10),
    ],
  };
  const replacement = {
    sessions: [
      session("new-upcoming", "2026-07-14", "intervals", 1, 6),
      session("new-unknown", "2026-07-15", "easyRun", 1, 5),
      session("new-missing", "2026-07-16", "recoveryRun", 1, 4),
    ],
  };

  const merged = mergeImmutableHistory({
    sourcePlan: replaceableSource,
    candidatePlan: replacement,
    localDate: "2026-07-13",
    activityLinkedSessionIds: [],
    skipAdjustmentSessionIds: [],
  });

  assertEquals(
    (merged.plan.sessions as Record<string, unknown>[]).map((item) => item.id),
    ["new-upcoming", "new-unknown", "new-missing"],
  );
  assertEquals([...merged.preservedIds], []);
});

Deno.test("merge avoids duplicate race-day info", () => {
  const raceSource = {
    sessions: [session("race-day-info", "2026-08-01", "raceDay", 3, null)],
    currentWeekNumber: 3,
  };
  const merged = mergeImmutableHistory({
    sourcePlan: raceSource,
    candidatePlan: {
      sessions: [
        session("race-day-info-new", "2026-08-01", "raceDay", 1, null),
      ],
    },
    localDate: "2026-07-13",
    activityLinkedSessionIds: ["race-day-info"],
    skipAdjustmentSessionIds: [],
  });
  assertEquals((merged.plan.sessions as unknown[]).length, 1);
});

Deno.test("warnings include short notice and evidence-based aggressive target", () => {
  assertEquals(
    buildWarnings({
      hasRaceDate: true,
      raceDate: "2026-08-10",
      localDate: "2026-07-13",
      targetTimeSeconds: 2_900,
    }, 3_000),
    ["short_notice", "aggressive_target"],
  );
  assertEquals(
    buildWarnings({
      hasRaceDate: false,
      raceDate: null,
      localDate: "2026-07-13",
      targetTimeSeconds: 3_000,
    }, 3_000),
    [],
  );
});

Deno.test("summary matches upcoming sessions by date and detects material changes", () => {
  const merged = mergeImmutableHistory({
    sourcePlan,
    candidatePlan,
    localDate: "2026-07-13",
    activityLinkedSessionIds: [],
    skipAdjustmentSessionIds: [],
  });
  const summary = summarizePlanChanges(
    sourcePlan,
    merged.plan,
    "2026-07-13",
    merged.preservedIds,
  );
  assertEquals(summary, {
    preservedCount: 3,
    addedUpcomingCount: 1,
    removedUpcomingCount: 0,
    materiallyChangedUpcomingCount: 1,
    addedUpcomingSessions: [{
      localDate: "2026-07-20",
      beforeSessionType: null,
      afterSessionType: "longRun",
      beforeDurationMinutes: null,
      afterDurationMinutes: 30,
      beforeDistanceKm: null,
      afterDistanceKm: 12,
    }],
    removedUpcomingSessions: [],
    materiallyChangedUpcomingSessions: [{
      localDate: "2026-07-16",
      beforeSessionType: "easyRun",
      afterSessionType: "intervals",
      beforeDurationMinutes: 30,
      afterDurationMinutes: 30,
      beforeDistanceKm: 5,
      afterDistanceKm: 6,
    }],
    totalWeeks: 3,
    endDate: "2026-07-20",
  });
});

Deno.test("summary details are stable for multiple sessions on one date", () => {
  const source = {
    totalWeeks: 2,
    sessions: [
      session("old-speed", "2026-07-16", "tempoRun", 1, 7, 40),
      session("old-tempo", "2026-07-14", "tempoRun", 1, 8, 45),
      session("old-long", "2026-07-15", "longRun", 1, 12, 60),
      session("old-easy", "2026-07-14", "easyRun", 1, 5, 30),
    ],
  };
  const proposed = {
    totalWeeks: 2,
    sessions: [
      session("new-added-later", "2026-07-17", "recoveryRun", 1, 3, 20),
      session("new-tempo", "2026-07-14", "tempoRun", 1, 8, 45),
      session("new-speed", "2026-07-16", "intervals", 1, 6, 35),
      session("new-easy", "2026-07-14", "easyRun", 1, 5, 35),
      session("new-added-same-day", "2026-07-14", "intervals", 1, 6, 25),
    ],
  };

  const summary = summarizePlanChanges(
    source,
    proposed,
    "2026-07-13",
    new Set(),
  );

  assertEquals(summary.addedUpcomingSessions, [
    {
      localDate: "2026-07-14",
      beforeSessionType: null,
      afterSessionType: "intervals",
      beforeDurationMinutes: null,
      afterDurationMinutes: 25,
      beforeDistanceKm: null,
      afterDistanceKm: 6,
    },
    {
      localDate: "2026-07-17",
      beforeSessionType: null,
      afterSessionType: "recoveryRun",
      beforeDurationMinutes: null,
      afterDurationMinutes: 20,
      beforeDistanceKm: null,
      afterDistanceKm: 3,
    },
  ]);
  assertEquals(summary.removedUpcomingSessions, [{
    localDate: "2026-07-15",
    beforeSessionType: "longRun",
    afterSessionType: null,
    beforeDurationMinutes: 60,
    afterDurationMinutes: null,
    beforeDistanceKm: 12,
    afterDistanceKm: null,
  }]);
  assertEquals(summary.materiallyChangedUpcomingSessions, [
    {
      localDate: "2026-07-14",
      beforeSessionType: "easyRun",
      afterSessionType: "easyRun",
      beforeDurationMinutes: 30,
      afterDurationMinutes: 35,
      beforeDistanceKm: 5,
      afterDistanceKm: 5,
    },
    {
      localDate: "2026-07-16",
      beforeSessionType: "tempoRun",
      afterSessionType: "intervals",
      beforeDurationMinutes: 40,
      afterDurationMinutes: 35,
      beforeDistanceKm: 7,
      afterDistanceKm: 6,
    },
  ]);
  assertEquals(
    summary.addedUpcomingCount,
    summary.addedUpcomingSessions.length,
  );
  assertEquals(
    summary.removedUpcomingCount,
    summary.removedUpcomingSessions.length,
  );
  assertEquals(
    summary.materiallyChangedUpcomingCount,
    summary.materiallyChangedUpcomingSessions.length,
  );
});

Deno.test("accept calls only acceptance RPC seam and returns persisted result", async () => {
  let acceptedUser: string | null = null;
  let buildCount = 0;
  const deps = fakeDependencies({
    buildCandidate: async () => {
      buildCount++;
      return candidatePlan as unknown as CandidatePlan;
    },
    acceptProposal: async (userId, proposalId) => {
      acceptedUser = userId;
      assertEquals(proposalId, "proposal-1");
      return {
        new_plan_version_id: "new-version",
        plan_data: { id: "new-version" },
        profile_data: { goal: { race: "race_5k" } },
      };
    },
  });
  const response = await createEditGoalHandler(deps)(request({
    action: "accept",
    proposalId: "proposal-1",
  }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).versionId, "new-version");
  assertEquals(acceptedUser, "token-user");
  assertEquals(buildCount, 0);
});

Deno.test("handler returns an idempotent accepted RPC result as success", async () => {
  let acceptCount = 0;
  const acceptedResult = {
    new_plan_version_id: "already-accepted-version",
    plan_data: { id: "already-accepted-version", sessions: [] },
    profile_data: { goal: { race: "race_10k" }, updatedAt: "accepted-at" },
  };
  const handler = createEditGoalHandler(fakeDependencies({
    acceptProposal: async () => {
      acceptCount++;
      return acceptedResult;
    },
  }));

  const first = await handler(request({
    action: "accept",
    proposalId: "proposal-1",
  }));
  const repeated = await handler(request({
    action: "accept",
    proposalId: "proposal-1",
  }));

  assertEquals(first.status, 200);
  assertEquals(repeated.status, 200);
  assertEquals(await first.json(), {
    versionId: acceptedResult.new_plan_version_id,
    plan: acceptedResult.plan_data,
    profile: acceptedResult.profile_data,
  });
  assertEquals(await repeated.json(), {
    versionId: acceptedResult.new_plan_version_id,
    plan: acceptedResult.plan_data,
    profile: acceptedResult.profile_data,
  });
  assertEquals(acceptCount, 2);
});

Deno.test("canonical RPC errors map to stable HTTP contracts", async () => {
  assertEquals(mapRpcError(new Error("goal_edit_proposal_not_found")), {
    key: "proposal_not_found",
    status: 404,
  });
  assertEquals(mapRpcError({ message: "goal_edit_proposal_expired" }), {
    key: "proposal_expired",
    status: 409,
  });
  assertEquals(mapRpcError(new Error("goal_edit_source_plan_stale")), {
    key: "source_plan_stale",
    status: 409,
  });
  assertEquals(mapRpcError(new Error("goal_edit_proposal_inconsistent")), {
    key: "proposal_inconsistent",
    status: 500,
  });
  const deps = fakeDependencies({
    acceptProposal: async () => {
      throw new Error("goal_edit_proposal_not_pending");
    },
  });
  const response = await createEditGoalHandler(deps)(request({
    action: "accept",
    proposalId: "proposal-1",
  }));
  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "proposal_not_pending" });

  const inconsistent = await createEditGoalHandler(fakeDependencies({
    acceptProposal: async () => {
      throw new Error("goal_edit_proposal_inconsistent");
    },
  }))(request({ action: "accept", proposalId: "proposal-1" }));
  assertEquals(inconsistent.status, 500);
  assertEquals(await inconsistent.json(), { error: "proposal_inconsistent" });
});

function fakeDependencies(
  overrides: Partial<EditGoalDependencies> = {},
): EditGoalDependencies {
  return {
    authenticate: async () => "token-user",
    loadPreviewContext: async () => ({
      profile,
      sourcePlan,
      activityLinkedSessionIds: [],
      skipAdjustmentSessionIds: [],
      stravaSummaries: [],
    }),
    buildCandidate: async () => candidatePlan as unknown as CandidatePlan,
    storeProposal: async (input) => ({
      id: input.proposalId,
      expires_at: input.expiresAt,
    }),
    acceptProposal: async () => ({
      new_plan_version_id: "new-version",
      plan_data: { id: "new-version" },
      profile_data: profile,
    }),
    now: () => new Date("2026-07-13T12:00:00.000Z"),
    randomId: () => "fixed-id",
    ...overrides,
  };
}

function previewBody(overrides: Record<string, unknown> = {}) {
  return {
    action: "preview",
    sourcePlanVersionId: "source-plan",
    race: "race_10k",
    hasRaceDate: true,
    raceDate: "2026-08-10",
    targetTimeSeconds: 3_000,
    localDate: "2026-07-13",
    locale: "en",
    ...overrides,
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("http://local/edit-goal", {
    method: "POST",
    headers: {
      Authorization: "Bearer token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function session(
  id: string,
  date: string,
  type: string,
  weekNumber: number,
  distanceKm: number | null,
  durationMinutes = 30,
  status?: string,
) {
  return {
    id,
    date,
    type,
    weekNumber,
    distanceKm,
    durationMinutes,
    ...(status == null ? {} : { status }),
  };
}
