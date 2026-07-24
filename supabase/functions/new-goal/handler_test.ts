import {
  AcceptRequestSchema,
  createNewGoalHandler,
  type NewGoalDependencies,
  mapRpcError,
  PreviewRequestSchema,
  RecommendRequestSchema,
} from "./handler.ts";
import type { CandidatePlan } from "../generate-plan/candidate-builder.ts";
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const profile = {
  goal: { race: "race_10k", hasRaceDate: true, raceDate: "2026-10-01" },
  schedule: {
    planStartDate: "2026-06-01",
    trainingDays: 3,
    longRunDay: "day_sun",
  },
  trainingPreferences: {
    preferredTimeOfDay: "time_of_day_morning",
  },
  health: {
    injuryStatus: "none",
  },
};

const sourcePlan = {
  id: "source-plan",
  currentWeekNumber: 2,
  totalWeeks: 6,
  sessions: [
    session("past", "2026-07-12", "easyRun", 1, 5),
    session("upcoming", "2026-07-16", "longRun", 2, 12),
  ],
};

const candidatePlan = {
  id: "candidate",
  currentWeekNumber: 1,
  totalWeeks: 10,
  sessions: [
    session("replacement", "2026-07-16", "intervals", 1, 6),
    session("replacement-2", "2026-07-17", "tempoRun", 1, 7),
  ],
};

Deno.test("recommend and preview schema validate supported races and plan dates", () => {
  assert(RecommendRequestSchema.safeParse(recommendBody()).success);
  assert(PreviewRequestSchema.safeParse(previewBody()).success);
  assertEquals(
    RecommendRequestSchema.safeParse({ ...previewBody(), race: "race_half" }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({
      ...previewBody(),
      hasRaceDate: true,
      raceDate: undefined,
    }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({
      ...previewBody(),
      hasRaceDate: false,
      raceDate: "2026-08-01",
    }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({
      ...previewBody(),
      planStartDate: "2026-07-01",
      raceDate: "2026-06-30",
    }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({ ...previewBody(), targetTimeSeconds: 2800 }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({ ...previewBody(), extra: "value" }).success,
    false,
  );
  assert(AcceptRequestSchema.safeParse({ action: "accept", proposalId: "p" }).success);
});

Deno.test("handler requires bearer auth and resolves context for authenticated user", async () => {
  const seenUsers: string[] = [];
  const response = await createNewGoalHandler(fakeDependencies({
    authenticate: async () => "token-user",
    loadPreviewContext: async (userId) => {
      seenUsers.push(userId);
      return null;
    },
  })(request({
    ...previewBody(),
    action: "recommend",
  }));

  const noAuthResponse = await createNewGoalHandler(fakeDependencies())(new Request(
    "http://local/new-goal",
    { method: "POST", body: JSON.stringify(previewBody({ action: "preview" })) },
  ));
  assertEquals(noAuthResponse.status, 401);
  assertEquals(response.status, 409);
  assertEquals(seenUsers, ["token-user"]);
});

Deno.test("recommend returns estimate-backed guidance when fitness evidence exists", async () => {
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      throw new Error("recommend should not generate a candidate");
    },
  }))(request({
    action: "recommend",
    ...previewBody(),
    fitnessResult: manualResult(),
  }));
  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.state, undefined);
  assertEquals(json.raceEstimate.centerTimeSeconds, 2400);
  assertEquals(json.raceEstimate.evidence, [{
    source: "manual",
    recordedOn: "2026-07-10",
    reason: "manual_recent_hard_result",
  }]);
});

Deno.test("recommend falls back to fitness_check_required when no usable evidence", async () => {
  const response = await createNewGoalHandler(fakeDependencies())(request({
    action: "recommend",
  }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).state, "fitness_check_required");
});

Deno.test("preview stores candidate only after valid estimate and forwards profile snapshot", async () => {
  let stored: Record<string, unknown> | null = null;
  const response = await createNewGoalHandler(fakeDependencies({
    sourceProfileSchemaVersion: 11,
    storeProposal: async (input) => {
      stored = input;
      return { id: input.proposalId, expires_at: input.expiresAt };
    },
    buildCandidate: async ({ profile, planStartDate, locale }) => {
      assertEquals(planStartDate, "2026-07-13");
      assertEquals(locale, "en");
      assertEquals((profile.schedule as Record<string, unknown>).planStartDate, "2026-07-13");
      return candidatePlan as unknown as CandidatePlan;
    },
    loadPreviewContext: async () => ({
      profile,
      sourcePlan,
      profileSchemaVersion: 11,
      profileUpdatedAt: "2026-06-01T00:00:00.000Z",
      stravaSummaries: [],
    }),
  })(request({
    action: "preview",
    ...previewBody(),
    fitnessResult: manualResult(),
  })));

  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.proposalId, "fixed-id");
  assertEquals(json.expiresAt, "2026-07-13T12:30:00.000Z");
  assertEquals(stored?.sourcePlanVersionId, "source-plan");
  assertEquals(stored?.sourceProfileSchemaVersion, 11);
  assertEquals(stored?.sourceProfileUpdatedAt, "2026-06-01T00:00:00.000Z");
  assertEquals(stored?.proposedProfileFragment, {
    acceptedRaceTarget: json.raceEstimate
      ? {
        distanceKm: 10,
        primaryTimeMs: 2400_000,
        confidence: "high",
        estimate: {
          centerTimeMs: 2400_000,
          fasterTimeMs: 2328_000,
          slowerTimeMs: 2472_000,
          confidence: "high",
          generatedAt: "2026-07-13T12:00:00.000Z",
          estimatorVersion: 1,
        },
        evidence: [{
          source: "manual",
          recordedOn: "2026-07-10",
          reason: "manual_recent_hard_result",
        }],
        planStartDate: "2026-07-13",
      }
    : null,
    schedule: {
      planStartDate: "2026-07-13",
      trainingDays: 3,
      longRunDay: "day_sun",
    },
    trainingPreferences: {
      preferredTimeOfDay: "time_of_day_morning",
    },
    health: {
      injuryStatus: "none",
    },
  });
});

Deno.test("preview does not store when fitness evidence is not available", async () => {
  let storeCount = 0;
  const response = await createNewGoalHandler(fakeDependencies({
    loadPreviewContext: async () => ({
      profile,
      sourcePlan,
      profileSchemaVersion: 11,
      profileUpdatedAt: "2026-06-01T00:00:00.000Z",
      stravaSummaries: [],
    }),
    storeProposal: async () => {
      storeCount += 1;
      return { id: "never", expires_at: "never" };
    },
  }))(request({
    action: "preview",
    ...previewBody(),
    fitnessResult: null,
  }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).state, "fitness_check_required");
  assertEquals(storeCount, 0);
});

Deno.test("accept calls acceptance seam and returns accepted version payload", async () => {
  let acceptCount = 0;
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      throw new Error("accept should not build candidate");
    },
    storeProposal: async () => {
      throw new Error("accept should not store proposal");
    },
    acceptProposal: async (userId, proposalId, versionId, generatedAt) => {
      acceptCount++;
      assertEquals(userId, "token-user");
      assertEquals(proposalId, "proposal-1");
      return {
        new_plan_version_id: versionId,
        plan_data: { id: versionId },
        profile_data: { goal: { race: "race_10k" } },
      };
    },
  })(request({
    action: "accept",
    proposalId: "proposal-1",
  })));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    versionId: "generated-version",
    plan: { id: "generated-version" },
    profile: { goal: { race: "race_10k" } },
  });
  assertEquals(acceptCount, 1);
});

Deno.test("rpc error mapping is stable and translated to contract errors", async () => {
  assertEquals(mapRpcError(new Error("new_goal_proposal_not_found")), {
    key: "proposal_not_found",
    status: 404,
  });
  assertEquals(mapRpcError({ message: "new_goal_proposal_expired" }), {
    key: "proposal_expired",
    status: 409,
  });
  assertEquals(mapRpcError(new Error("new_goal_source_profile_stale")), {
    key: "source_profile_stale",
    status: 409,
  });

  const response = await createNewGoalHandler(fakeDependencies({
    acceptProposal: async () => {
      throw new Error("new_goal_proposal_not_pending");
    },
  }))(request({
    action: "accept",
    proposalId: "proposal-1",
  }));
  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "proposal_not_pending" });
});

function fakeDependencies(
  overrides: Partial<NewGoalDependencies> & {
    sourceProfileSchemaVersion?: number;
  } = {},
): NewGoalDependencies {
  return {
    authenticate: async () => "token-user",
    loadPreviewContext: async () => {
      if (overrides.sourceProfileSchemaVersion != null) {
        return {
          profile,
          sourcePlan,
          profileSchemaVersion: overrides.sourceProfileSchemaVersion,
          profileUpdatedAt: "2026-06-01T00:00:00.000Z",
          stravaSummaries: [],
        };
      }
      return {
        profile,
        sourcePlan,
        profileSchemaVersion: 7,
        profileUpdatedAt: "2026-06-01T00:00:00.000Z",
        stravaSummaries: [],
      };
    },
    buildCandidate: async () => candidatePlan as unknown as CandidatePlan,
    storeProposal: async () => ({
      id: "fixed-id",
      expires_at: "2026-07-13T12:30:00.000Z",
    }),
    acceptProposal: async () => ({
      new_plan_version_id: "generated-version",
      plan_data: { id: "generated-version" },
      profile_data: { goal: { race: "race_10k" } },
    }),
    now: () => new Date("2026-07-13T12:00:00.000Z"),
    randomId: () => "generated-version",
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
    planStartDate: "2026-07-13",
    locale: "en",
    ...overrides,
  };
}

function recommendBody(overrides: Record<string, unknown> = {}) {
  return {
    action: "recommend",
    sourcePlanVersionId: "source-plan",
    race: "race_10k",
    hasRaceDate: true,
    raceDate: "2026-08-10",
    planStartDate: "2026-07-13",
    locale: "en",
    ...overrides,
  };
}

function manualResult(overrides: Record<string, unknown> = {}) {
  return {
    source: "manual",
    distanceKm: 10,
    elapsedSeconds: 2400,
    recordedOn: "2026-07-10",
    hardEffort: true,
    ...overrides,
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("http://local/new-goal", {
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
) {
  return {
    id,
    date,
    type,
    weekNumber,
    distanceKm,
    durationMinutes: 30,
  };
}
