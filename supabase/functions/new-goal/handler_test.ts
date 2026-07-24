import {
  AcceptRequestSchema,
  createNewGoalHandler,
  mapRpcError,
  type NewGoalDependencies,
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
    weekdayTime: "time_60_min",
    weekendTime: "time_90_min",
  },
  trainingPreferences: {
    planPreference: "plan_balanced",
  },
  health: {
    painLevel: "pain_no",
    injuryHistory: "injury_no",
    hasHealthConditions: "no",
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
    RecommendRequestSchema.safeParse({ ...previewBody(), race: "race_half" })
      .success,
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
    PreviewRequestSchema.safeParse({
      ...previewBody(),
      targetTimeSeconds: 2800,
    }).success,
    false,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      schedule: {
        trainingDays: 3,
        longRunDay: "day_mon",
        unknown: "x",
      },
    }).success,
    false,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      schedule: {
        trainingDays: 3,
        longRunDay: "day_sun",
        hardDays: ["day_mon", "day_mon"],
      },
    }).success,
    false,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      trainingPreferences: {
        planPreference: "plan_balanced",
        unknown: "x",
      },
    }).success,
    false,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      health: {
        painLevel: "pain_no",
        injuryHistory: "injury_no",
        hasHealthConditions: "no",
      },
    }).success,
    false,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      health: {
        painLevel: "pain_no",
        injuryHistory: "injury_no",
        hasHealthConditions: "no",
      },
      healthChanged: true,
    }).success,
    true,
  );
  assertEquals(
    RecommendRequestSchema.safeParse({
      ...recommendBody(),
      healthChanged: true,
    }).success,
    false,
  );
  assertEquals(
    PreviewRequestSchema.safeParse({ ...previewBody(), extra: "value" })
      .success,
    false,
  );
  assert(
    AcceptRequestSchema.safeParse({ action: "accept", proposalId: "p" })
      .success,
  );
});

Deno.test("recommend passes source plan id to context lookup", async () => {
  const observed: {
    userId: string | null;
    sourcePlanVersionId: string | null;
  } = { userId: null, sourcePlanVersionId: null };
  const response = await createNewGoalHandler(fakeDependencies({
    loadPreviewContext: async (userId, sourcePlanVersionId) => {
      observed.userId = userId;
      observed.sourcePlanVersionId = sourcePlanVersionId;
      return null;
    },
  }))(request(recommendBody()));
  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "source_plan_stale" });
  assertEquals(observed.userId, "token-user");
  assertEquals(observed.sourcePlanVersionId, "source-plan");
});

Deno.test("preview returns source_plan_stale when source context is missing", async () => {
  const response = await createNewGoalHandler(fakeDependencies({
    loadPreviewContext: async () => null,
  }))(request(previewBody()));
  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "source_plan_stale" });
});

Deno.test("handler requires bearer auth and resolves context for authenticated user", async () => {
  const seenUsers: string[] = [];
  const response = await createNewGoalHandler(fakeDependencies({
    authenticate: async () => "token-user",
    loadPreviewContext: async (userId) => {
      seenUsers.push(userId);
      return null;
    },
  }))(request(recommendBody()));

  const noAuthResponse = await createNewGoalHandler(fakeDependencies())(
    new Request(
      "http://local/new-goal",
      {
        method: "POST",
        body: JSON.stringify(previewBody({ action: "preview" })),
      },
    ),
  );
  assertEquals(noAuthResponse.status, 401);
  assertEquals(response.status, 409);
  assertEquals(seenUsers, ["token-user"]);
});

Deno.test("recommend returns estimate-backed guidance when fitness evidence exists", async () => {
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      throw new Error("recommend should not generate a candidate");
    },
  }))(request(recommendBody({
    fitnessResult: manualResult(),
  })));
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
  const response = await createNewGoalHandler(fakeDependencies())(
    request(recommendBody()),
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).state, "fitness_check_required");
});

Deno.test("preview stores candidate only after valid estimate and forwards profile snapshot", async () => {
  let stored: unknown = null;
  const response = await createNewGoalHandler(fakeDependencies({
    sourceProfileSchemaVersion: 11,
    storeProposal: async (input) => {
      stored = input;
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
    buildCandidate: async ({ profile, planStartDate, locale }) => {
      assertEquals(planStartDate, "2026-07-13");
      assertEquals(locale, "en");
      assertEquals(
        (profile.schedule as Record<string, unknown>).planStartDate,
        "2026-07-13",
      );
      return candidatePlan as unknown as CandidatePlan;
    },
    loadPreviewContext: async () => ({
      profile,
      sourcePlan,
      profileSchemaVersion: 11,
      profileUpdatedAt: "2026-06-01T00:00:00.000Z",
      stravaSummaries: [],
    }),
    randomId: () => "fixed-id",
  }))(request(previewBody({
    fitnessResult: manualResult(),
  })));

  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.currentGoal, json.sourceGoal);
  assertEquals(json.summary, {
    sourceGoal: {
      race: "race_10k",
      hasRaceDate: true,
      raceDate: "2026-10-01",
    },
    proposedGoal: {
      race: "race_10k",
      hasRaceDate: true,
      raceDate: "2026-08-10",
    },
    recommendationMode: "short_fixed_date",
  });
  assertEquals(json.warnings, ["short_fixed_date"]);
  const capturedStoreInput = stored as Record<string, unknown> | null;
  assertEquals(json.proposalId, "fixed-id");
  assertEquals(json.expiresAt, "2026-07-13T12:30:00.000Z");
  assertEquals(capturedStoreInput?.sourcePlanVersionId, "source-plan");
  assertEquals(capturedStoreInput?.sourceProfileSchemaVersion, 11);
  assertEquals(
    capturedStoreInput?.sourceProfileUpdatedAt,
    "2026-06-01T00:00:00.000Z",
  );
  assertEquals(capturedStoreInput?.proposedProfileFragment, {
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
          metric: "manual_manual_recent_hard_result",
          date: "2026-07-10",
          value: 2400,
          unit: "seconds",
        }],
        planStartDate: "2026-07-13",
      }
      : null,
    schedule: {
      planStartDate: "2026-07-13",
      trainingDays: 3,
      longRunDay: "day_sun",
      weekdayTime: "time_60_min",
      weekendTime: "time_90_min",
    },
    trainingPreferences: {
      planPreference: "plan_balanced",
    },
    health: {
      painLevel: "pain_no",
      injuryHistory: "injury_no",
      hasHealthConditions: "no",
    },
  });
});

Deno.test("preview merges reviewed schedule, training preferences, and health fragments", async () => {
  let capturedBuildInput: Record<string, unknown> | null = null;
  let capturedStoreInput: unknown = null;
  const response = await createNewGoalHandler(fakeDependencies({
    sourceProfileSchemaVersion: 11,
    buildCandidate: async ({ profile }) => {
      capturedBuildInput = profile as Record<string, unknown>;
      assertEquals(
        (profile.schedule as Record<string, unknown>).trainingDays,
        6,
      );
      assertEquals(
        (profile.trainingPreferences as Record<string, unknown>)
          .planPreference,
        "plan_performance",
      );
      assertEquals(
        (profile.health as Record<string, unknown>).painLevel,
        "pain_mild",
      );
      assertEquals(
        (profile.acceptedRaceTarget as Record<string, unknown>)?.distanceKm,
        10,
      );
      assertEquals(
        (profile.acceptedRaceTarget as Record<string, unknown>)?.planStartDate,
        "2026-07-13",
      );
      const acceptedTarget = profile.acceptedRaceTarget as Record<
        string,
        unknown
      >;
      assertEquals(
        (acceptedTarget.estimate as Record<string, unknown>)?.centerTimeMs,
        2400_000,
      );
      return candidatePlan as unknown as CandidatePlan;
    },
    storeProposal: async (input) => {
      capturedStoreInput = input;
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
    randomId: () => "fixed-id",
  }))(request(previewBody({
    fitnessResult: manualResult(),
    schedule: {
      trainingDays: 6,
      longRunDay: "day_mon",
    },
    trainingPreferences: {
      planPreference: "plan_performance",
    },
    health: {
      painLevel: "pain_mild",
      injuryHistory: "injury_multiple",
      hasHealthConditions: "yes",
    },
    healthChanged: true,
  })));

  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.currentGoal, json.sourceGoal);
  assertEquals(json.summary, {
    sourceGoal: {
      race: "race_10k",
      hasRaceDate: true,
      raceDate: "2026-10-01",
    },
    proposedGoal: {
      race: "race_10k",
      hasRaceDate: true,
      raceDate: "2026-08-10",
    },
    recommendationMode: "short_fixed_date",
  });
  assertEquals(json.warnings, ["short_fixed_date"]);
  assertEquals(capturedBuildInput == null, false);
  const buildInput = capturedBuildInput!;
  assertEquals(
    (buildInput.schedule as Record<string, unknown>)?.planStartDate,
    "2026-07-13",
  );
  assertEquals(
    (buildInput.schedule as Record<string, unknown>)?.trainingDays,
    6,
  );
  const stored = capturedStoreInput as Record<string, unknown> | null;
  assertEquals(stored?.proposalId, "fixed-id");
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
          metric: "manual_manual_recent_hard_result",
          date: "2026-07-10",
          value: 2400,
          unit: "seconds",
        }],
        planStartDate: "2026-07-13",
      }
      : null,
    schedule: {
      planStartDate: "2026-07-13",
      trainingDays: 6,
      longRunDay: "day_mon",
      weekdayTime: "time_60_min",
      weekendTime: "time_90_min",
    },
    trainingPreferences: {
      planPreference: "plan_performance",
    },
    health: {
      painLevel: "pain_mild",
      injuryHistory: "injury_multiple",
      hasHealthConditions: "yes",
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
  }))(request(previewBody({
    fitnessResult: null,
  })));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).state, "fitness_check_required");
  assertEquals(storeCount, 0);
});

Deno.test("recommend and preview share request-local date for race-support detection", async () => {
  const basePayload = {
    ...previewBody({
      hasRaceDate: true,
      planStartDate: "2026-07-13",
      raceDate: "2026-07-14",
      localDate: "2026-07-12",
      fitnessResult: manualResult(),
    }),
  };
  const recommendResponse = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      throw new Error("recommend should not build candidate");
    },
  }))(request({
    ...basePayload,
    action: "recommend",
  }));
  const previewResponse = await createNewGoalHandler(fakeDependencies())(
    request(basePayload),
  );
  assertEquals(recommendResponse.status, 200);
  assertEquals(previewResponse.status, 200);
  const recommendJson = await recommendResponse.json();
  const previewJson = await previewResponse.json();
  assertEquals(recommendJson.recommendation.mode, "race_support");
  assertEquals(previewJson.recommendation.mode, "race_support");
  assertEquals(recommendJson.recommendation.daysToRace, 2);
  assertEquals(previewJson.recommendation.daysToRace, 2);
});

Deno.test("localDate must be close to server now and remains urgency-only", async () => {
  const staleResponse = await createNewGoalHandler(fakeDependencies())(
    request(previewBody({
      localDate: "2025-07-01",
    })),
  );
  assertEquals(staleResponse.status, 400);
  const stale = await staleResponse.json();
  assertEquals(stale.detail?.[0].path[0], "localDate");

  const response = await createNewGoalHandler(fakeDependencies())(
    request({
      ...recommendBody({
        hasRaceDate: true,
        planStartDate: "2026-07-13",
        raceDate: "2026-07-20",
        localDate: "2026-07-12",
        fitnessResult: manualResult(),
      }),
    }),
  );
  assertEquals(response.status, 200);
  const json = await response.json();
  assertEquals(json.recommendation.startDate, "2026-07-13");
  assertEquals(json.recommendation.endDate, "2026-07-20");
  assertEquals(json.recommendation.weeks, 1);
  assertEquals(json.recommendation.daysToRace, 8);
});

Deno.test("preview applies race-support safety to generated sessions", async () => {
  let stored: unknown = null;
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      return {
        ...candidatePlan,
        sessions: [
          session("pre-start", "2026-07-11", "easyRun", 1, 6),
          session("safe-rest", "2026-07-13", "restDay", 2, 6),
          session("safe-easy", "2026-07-13", "easyRun", 2, 6),
          session("unsafe-tempo", "2026-07-13", "tempoRun", 1, 7),
          session("race-day", "2026-07-14", "raceDay", 2, 0),
          session("unsafe-late", "2026-07-15", "easyRun", 2, 7),
        ],
      } as unknown as CandidatePlan;
    },
    storeProposal: async (input) => {
      stored = input;
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
  }))(request(previewBody({
    fitnessResult: manualResult(),
    hasRaceDate: true,
    raceDate: "2026-07-14",
    localDate: "2026-07-12",
  })));
  assertEquals(response.status, 200);
  const json = await response.json();
  const candidate = json.candidatePlan as {
    sessions: Array<{ id: string; date: string; weekNumber: number }>;
  };
  assertEquals(json.recommendation.mode, "race_support");
  assertEquals(
    candidate.sessions.map((session) => session.id),
    ["safe-rest", "safe-easy", "race-day"],
  );
  const hasNoPreStartSessions = candidate.sessions.every((session) =>
    session.date >= "2026-07-13"
  );
  assertEquals(hasNoPreStartSessions, true);
  assertEquals(
    candidate.sessions.every((session) => session.weekNumber >= 1),
    true,
  );
  const proposal = stored as Record<string, unknown> | null;
  const storedSessions = (proposal?.candidatePlan as {
    sessions: Array<
      { id: string; date: string; weekNumber: number; type: string }
    >;
  }).sessions;
  assertEquals(
    storedSessions.map((session) => session.id),
    ["safe-rest", "safe-easy", "race-day"],
  );
  assertEquals(
    storedSessions.every((session) => session.date >= "2026-07-13"),
    true,
  );
  assertEquals(
    storedSessions.every((session) => session.date <= "2026-07-14"),
    true,
  );
  assertEquals(
    storedSessions.every((session) => session.weekNumber >= 1),
    true,
  );
});

Deno.test("preview builds deterministic race-support fallback when filtered sessions are unusable", async () => {
  let stored: unknown = null;
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      return {
        ...candidatePlan,
        sessions: [
          session("unsafe", "2026-07-11", "tempoRun", 1, 7),
          session("unsafe2", "2026-07-12", "thresholdRun", 2, 8),
          session("unsafe3", "2026-07-14", "intervals", 2, 9),
        ],
      } as unknown as CandidatePlan;
    },
    storeProposal: async (input) => {
      stored = input;
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
  }))(request(previewBody({
    fitnessResult: manualResult(),
    hasRaceDate: true,
    raceDate: "2026-07-14",
    localDate: "2026-07-12",
  })));
  assertEquals(response.status, 200);
  const json = await response.json();
  const candidate = json.candidatePlan as {
    sessions: Array<
      { id: string; type: string; date: string; weekNumber: number }
    >;
  };
  assertEquals(json.recommendation.mode, "race_support");
  assertEquals(
    candidate.sessions.map((session) => session.type),
    ["restDay", "raceDay"],
  );
  const proposal = stored as Record<string, unknown> | null;
  const storedSessions = (proposal?.candidatePlan as {
    sessions: Array<{ type: string; date: string; weekNumber: number }>;
  }).sessions;
  assertEquals(
    storedSessions.map((session) => session.type),
    ["restDay", "raceDay"],
  );
  assertEquals(storedSessions.length > 0, true);
  assertEquals(
    storedSessions.every((session) => session.date >= "2026-07-13"),
    true,
  );
  assertEquals(
    storedSessions.every((session) => session.date <= "2026-07-14"),
    true,
  );
  assertEquals(
    storedSessions.every((session) => session.weekNumber >= 1),
    true,
  );
});

Deno.test("preview race-support fallback starts at max(localDate, planStartDate)", async () => {
  let stored: unknown = null;
  const response = await createNewGoalHandler(fakeDependencies({
    buildCandidate: async () => {
      return {
        ...candidatePlan,
        sessions: [
          session("late-rest", "2026-07-11", "restDay", 1, 6),
          session("late-easy", "2026-07-12", "easyRun", 1, 7),
          session("too-late", "2026-07-22", "easyRun", 2, 7),
          session("race-day", "2026-07-24", "raceDay", 4, 0),
        ],
      } as unknown as CandidatePlan;
    },
    storeProposal: async (input) => {
      stored = input;
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
    now: () => new Date("2026-07-18T12:00:00.000Z"),
  }))(request(previewBody({
    fitnessResult: manualResult(),
    hasRaceDate: true,
    planStartDate: "2026-07-20",
    raceDate: "2026-07-24",
    localDate: "2026-07-18",
  })));
  assertEquals(response.status, 200);
  const json = await response.json();
  const candidate = json.candidatePlan as {
    sessions: Array<{ type: string; date: string; weekNumber: number }>;
  };
  assertEquals(json.recommendation.mode, "race_support");
  assertEquals(
    candidate.sessions.map((session) => session.type),
    ["restDay", "easyRun", "raceDay"],
  );
  assertEquals(candidate.sessions[0].date, "2026-07-20");
  assertEquals(
    candidate.sessions.every((session) => session.date >= "2026-07-20"),
    true,
  );
  assertEquals(
    candidate.sessions.every((session) => session.date <= "2026-07-24"),
    true,
  );
  assertEquals(
    candidate.sessions.every((session) => session.weekNumber >= 1),
    true,
  );
  const proposalSessions = (stored as Record<string, unknown> | null)
    ?.candidatePlan as
      | {
        sessions:
          | Array<{ type: string; date: string; weekNumber: number }>
          | undefined;
      }
      | undefined;
  assertEquals(proposalSessions?.sessions?.[0].date, "2026-07-20");
  assertEquals(
    proposalSessions?.sessions?.every((session) =>
      session.date >= "2026-07-20"
    ),
    true,
  );
  assertEquals(
    proposalSessions?.sessions?.every((session) => session.weekNumber >= 1),
    true,
  );
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
  }))(request({
    action: "accept",
    proposalId: "proposal-1",
  }));
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
