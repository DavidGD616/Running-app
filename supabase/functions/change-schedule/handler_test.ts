import type { SupabaseClient } from "@supabase/supabase-js";

import {
  AcceptRequestSchema,
  CancelRequestSchema,
  createChangeScheduleHandler,
  createProductionDependencies,
  mapRpcError,
  PreviewRequestSchema,
  ActivateRequestSchema,
  ScheduleRequestSchema,
  UndoRequestSchema,
  type ChangeScheduleDependencies,
} from "./handler.ts";
import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const sourcePlan = {
  id: "source-plan",
  currentWeekNumber: 1,
  totalWeeks: 4,
  sessions: [
    {
      id: "current-run",
      date: "2026-07-13",
      weekNumber: 1,
      type: "easyRun",
      distanceKm: 10,
      durationMinutes: 40,
    },
  ],
};

const availability = {
  days: [
    { day: 1, available: true, max_duration_minutes: 60 },
    { day: 2, available: false, max_duration_minutes: 30 },
    { day: 3, available: false, max_duration_minutes: 30 },
    { day: 4, available: false, max_duration_minutes: 30 },
    { day: 5, available: false, max_duration_minutes: 30 },
    { day: 6, available: false, max_duration_minutes: 30 },
    { day: 7, available: false, max_duration_minutes: 30 },
  ],
  target_running_days: 1,
  primary_long_run_weekday: 1,
  same_day_run_strength_preference: "separate_sessions",
};

Deno.test("request schemas enforce canonical action names and strict payload keys", () => {
  assert(PreviewRequestSchema.safeParse(previewBody()).success);
  assert(AcceptRequestSchema.safeParse({ action: "accept_now", proposalId: "proposal-1" }).success);
  assert(ScheduleRequestSchema.safeParse({ action: "schedule", proposalId: "proposal-1" }).success);
  assert(CancelRequestSchema.safeParse({ action: "cancel_scheduled", proposalId: "proposal-1" }).success);
  assert(ActivateRequestSchema.safeParse({ action: "activate_due", activationId: "activation-1" }).success);
  assert(UndoRequestSchema.safeParse({ action: "undo", proposalId: "proposal-1" }).success);

  assert(!AcceptRequestSchema.safeParse({ action: "accept", proposalId: "proposal-1" }).success);
  assert(!CancelRequestSchema.safeParse({ action: "cancel", proposalId: "proposal-1" }).success);
  assert(!ActivateRequestSchema.safeParse({ action: "activate", activationId: "activation-1" }).success);

  assert(!PreviewRequestSchema.safeParse({
    action: "preview",
    sourcePlanVersionId: "source-plan",
    availability,
    localDate: "2026-07-13",
  }).success);

  assert(!PreviewRequestSchema.safeParse({
    ...previewBody(),
    asOfDate: "2026-07-13",
  }).success);

  assert(!PreviewRequestSchema.safeParse({ ...previewBody(), unknownRootField: "x" }).success);

  assert(!PreviewRequestSchema.safeParse(previewBody({
    availability: {
      ...availability,
      // canonical aliases must be rejected
      targetRunningDays: 1,
    } as Record<string, unknown>,
  })).success);

  assert(!PreviewRequestSchema.safeParse(previewBody({
    availability: {
      ...availability,
      days: availability.days.map((entry) => ({
        ...entry,
        maxDurationMinutes: entry.max_duration_minutes,
      })),
    } as Record<string, unknown>,
  })).success);

  assert(!PreviewRequestSchema.safeParse(previewBody({
    availability: {
      ...availability,
      sameDayRunStrengthPreference: "separate_sessions",
    } as Record<string, unknown>,
  })).success);

  const availabilityWithoutPreference = { ...availability } as Record<string, unknown>;
  delete availabilityWithoutPreference.same_day_run_strength_preference;
  assert(!PreviewRequestSchema.safeParse(previewBody({
    availability: availabilityWithoutPreference,
  })).success);

  assert(!AcceptRequestSchema.safeParse({
    action: "accept_now",
    proposalId: "proposal-1",
    planVersionId: "plan-1",
    availabilityVersionId: "avail-1",
  }).success);
  assert(!CancelRequestSchema.safeParse({
    action: "cancel_scheduled",
    proposalId: "proposal-1",
    cancelledAt: "2026-07-13T10:00:00.000Z",
  }).success);
});

Deno.test("handler enforces auth and method constraints", async () => {
  const handler = createChangeScheduleHandler(fakeDependencies());

  assertEquals((await handler(new Request("http://local", { method: "GET" })).then(
    (response) => response.status,
  )), 405);

  assertEquals(
    (await handler(new Request("http://local", { method: "POST", body: "{}" }))
      .then((response) => response.status)),
    401,
  );
});

Deno.test("preview effectiveFrom accepts only current/next server Monday and rejects invalid windows", async () => {
  const fixedNow = new Date("2026-07-13T12:00:00.000Z");

  const handler = createChangeScheduleHandler(fakeDependencies({ now: () => fixedNow }));

  const current = await handler(request(previewBody()));
  const currentJson = await current.json();
  assertEquals(current.status, 200);
  assertEquals(currentJson.effectiveFrom, "2026-07-13");

  const shiftedMonday = await handler(request(previewBody({
    effectiveFrom: "2026-07-20",
  })));
  const shiftedJson = await shiftedMonday.json();
  assertEquals(shiftedMonday.status, 200);
  assertEquals(shiftedJson.effectiveFrom, "2026-07-20");

  const localDateOnly = await handler(request(previewBody({
    localDate: "2026-07-14",
    effectiveFrom: undefined,
  })));
  const localDateJson = await localDateOnly.json();
  assertEquals(localDateJson.effectiveFrom, "2026-07-13");

  const past = await handler(request(previewBody({ effectiveFrom: "2026-07-06" })));
  assertEquals(past.status, 400);

  const future = await handler(request(previewBody({ effectiveFrom: "2026-08-03" })));
  assertEquals(future.status, 400);
});

Deno.test("handler injects server-generated IDs and timestamps for all lifecycle actions", async () => {
  const now = new Date("2026-07-13T10:00:00.000Z");
  const randomIds = [
    "server-proposal",
    "server-plan-a",
    "server-avail-a",
  ];

  let acceptInputs: Array<Record<string, unknown>> = [];
  let scheduleInputs: Array<Record<string, unknown>> = [];
  let cancelInputs: Array<Record<string, unknown>> = [];
  let activateInputs: Array<Record<string, unknown>> = [];
  let undoInputs: Array<Record<string, unknown>> = [];
  const actionLog: string[] = [];
  const storeInputs: Array<Record<string, unknown>> = [];

  const handler = createChangeScheduleHandler(fakeDependencies({
    now: () => now,
    randomId: () => {
      return randomIds.shift() ?? "fallback";
    },
    storeProposal: async (input) => {
      actionLog.push("storeProposal");
      storeInputs.push({
        userId: input.userId,
      });
      return {
        id: input.proposalId,
        expires_at: input.expiresAt,
      };
    },
    acceptProposalNow: async (...inputs) => {
      actionLog.push("acceptNow");
      acceptInputs = [
        {
          userId: inputs[0],
          proposalId: inputs[1],
          planVersionId: inputs[2],
          availabilityVersionId: inputs[3],
          generatedAt: inputs[4],
          acceptedAt: inputs[5],
        },
      ];
      return {
        accepted_plan_version_id: "accepted-plan",
        plan_data: { id: "accepted-plan" },
        prior_active_plan_version_id: null,
        prior_active_availability_version_id: null,
        accepted_availability_version_id: "accepted-avail",
      };
    },
    scheduleProposal: async (...inputs) => {
      actionLog.push("schedule");
      scheduleInputs = [
        {
          userId: inputs[0],
          proposalId: inputs[1],
          planVersionId: inputs[2],
          availabilityVersionId: inputs[3],
          scheduledAt: inputs[4],
        },
      ];
      return {
        proposal_id: "proposal-1",
        activation_id: "activation-1",
        scheduled_plan_version_id: inputs[2],
        scheduled_availability_version_id: inputs[3],
        activation_status: "scheduled",
      };
    },
    cancelScheduledProposal: async (...inputs) => {
      actionLog.push("cancel");
      cancelInputs = [
        {
          userId: inputs[0],
          proposalId: inputs[1],
          cancelledAt: inputs[2],
        },
      ];
      return {
        proposal_id: "proposal-1",
        proposal_status: "cancelled",
        activation_id: null,
        scheduled_plan_version_id: null,
      };
    },
    activateDueProposal: async (...inputs) => {
      actionLog.push("activateDue");
      activateInputs = [
        {
          userId: inputs[0],
          activationId: inputs[1],
          activatedAt: inputs[2],
        },
      ];
        return {
          proposal_id: "proposal-1",
          activation_id: "activation-1",
          proposal_status: "accepted",
          accepted_plan_version_id: "plan-2",
        prior_active_plan_version_id: null,
        prior_active_availability_version_id: null,
        accepted_availability_version_id: "avail-2",
        activation_status: "activated",
      };
    },
    undoAcceptedProposal: async (...inputs) => {
      actionLog.push("undo");
      undoInputs = [
        {
          userId: inputs[0],
          proposalId: inputs[1],
          undoneAt: inputs[2],
        },
      ];
      return {
        proposal_id: "proposal-1",
        prior_plan_version_id: null,
        prior_availability_version_id: null,
        restored_plan_version_id: null,
        restored_availability_version_id: null,
      };
    },
  }));

  actionLog.length = 0;
  const previewResponse = await handler(request(previewBody()));
  assertEquals(previewResponse.status, 200);
  assertEquals(actionLog, ["storeProposal"]);
  assertEquals(storeInputs[0].userId, "token-user");

  actionLog.length = 0;
  const accepted = await handler(request({ action: "accept_now", proposalId: "proposal-1" }));
  assertEquals(accepted.status, 200);
  assertEquals(actionLog, ["acceptNow"]);

  actionLog.length = 0;
  const scheduled = await handler(request({ action: "schedule", proposalId: "proposal-1" }));
  assertEquals(scheduled.status, 200);
  assertEquals(actionLog, ["schedule"]);

  actionLog.length = 0;
  const cancelled = await handler(request({ action: "cancel_scheduled", proposalId: "proposal-1" }));
  assertEquals(cancelled.status, 200);
  assertEquals(actionLog, ["cancel"]);

  actionLog.length = 0;
  const activated = await handler(request({ action: "activate_due", activationId: "activation-1" }));
  assertEquals(activated.status, 200);
  assertEquals(actionLog, ["activateDue"]);

  actionLog.length = 0;
  const undone = await handler(request({ action: "undo", proposalId: "proposal-1" }));
  assertEquals(undone.status, 200);
  assertEquals(actionLog, ["undo"]);

      assertEquals(acceptInputs[0].planVersionId, "server-plan-a");
      assertEquals(acceptInputs[0].availabilityVersionId, "server-avail-a");
      assertEquals(acceptInputs[0].generatedAt, now.toISOString());
      assertEquals(acceptInputs[0].acceptedAt, now.toISOString());

  assertEquals(scheduleInputs[0].planVersionId, "schedule-plan:proposal-1");
  assertEquals(scheduleInputs[0].availabilityVersionId, "schedule-availability:proposal-1");
  assertEquals(scheduleInputs[0].scheduledAt, now.toISOString());

  assertEquals(cancelInputs[0].cancelledAt, now.toISOString());
  assertEquals(activateInputs[0].activatedAt, now.toISOString());
  assertEquals(undoInputs[0].undoneAt, now.toISOString());

  assertEquals(acceptInputs[0].userId, "token-user");
  assertEquals(scheduleInputs[0].userId, "token-user");
  assertEquals(cancelInputs[0].userId, "token-user");
  assertEquals(activateInputs[0].userId, "token-user");
  assertEquals(undoInputs[0].userId, "token-user");
});

Deno.test("schedule action reuses deterministic proposal IDs for sequential retries when no chain is found", async () => {
  const now = new Date("2026-07-13T10:00:00.000Z");
  const usedRandomIds: string[] = [];
  const scheduleInputs: Array<Record<string, unknown>> = [];

  const handler = createChangeScheduleHandler(fakeDependencies({
    now: () => now,
    randomId: () => {
      usedRandomIds.push("unexpected-random-id");
      return "unexpected-random-id";
    },
    scheduleProposal: async (...inputs) => {
      scheduleInputs.push({
        userId: inputs[0],
        proposalId: inputs[1],
        planVersionId: inputs[2],
        availabilityVersionId: inputs[3],
        scheduledAt: inputs[4],
      });
      return {
        proposal_id: inputs[1],
        activation_id: "activation-1",
        scheduled_plan_version_id: inputs[2],
        scheduled_availability_version_id: inputs[3],
        activation_status: "scheduled",
      };
    },
  }));

  const firstScheduled = await handler(request({ action: "schedule", proposalId: "proposal-1" }));
  assertEquals(firstScheduled.status, 200);
  const firstBody = await firstScheduled.json();
  assertEquals(firstBody.scheduledPlanVersionId, "schedule-plan:proposal-1");
  assertEquals(firstBody.scheduledAvailabilityVersionId, "schedule-availability:proposal-1");

  const secondScheduled = await handler(request({
    action: "schedule",
    proposalId: "proposal-1",
  }));
  assertEquals(secondScheduled.status, 200);
  const secondBody = await secondScheduled.json();
  assertEquals(secondBody.scheduledPlanVersionId, "schedule-plan:proposal-1");
  assertEquals(secondBody.scheduledAvailabilityVersionId, "schedule-availability:proposal-1");

  assertEquals(scheduleInputs[0].planVersionId, "schedule-plan:proposal-1");
  assertEquals(scheduleInputs[0].availabilityVersionId, "schedule-availability:proposal-1");
  assertEquals(scheduleInputs[1].planVersionId, "schedule-plan:proposal-1");
  assertEquals(scheduleInputs[1].availabilityVersionId, "schedule-availability:proposal-1");
  assertEquals(scheduleInputs[0].scheduledAt, now.toISOString());
  assertEquals(scheduleInputs[1].scheduledAt, now.toISOString());
  assertEquals(firstBody.activationId, secondBody.activationId);
  assertEquals(usedRandomIds, []);
});

Deno.test("schedule action preserves deterministic proposal IDs for concurrent pre-commit retries", async () => {
  const now = new Date("2026-07-13T10:00:00.000Z");
  const scheduleInputs: Array<Record<string, unknown>> = [];

  const handler = createChangeScheduleHandler(fakeDependencies({
    now: () => now,
    scheduleProposal: async (...inputs) => {
      scheduleInputs.push({
        userId: inputs[0],
        proposalId: inputs[1],
        planVersionId: inputs[2],
        availabilityVersionId: inputs[3],
        scheduledAt: inputs[4],
      });
      return {
        proposal_id: inputs[1],
        activation_id: "activation-1",
        scheduled_plan_version_id: inputs[2],
        scheduled_availability_version_id: inputs[3],
        activation_status: "scheduled",
      };
    },
  }));

  const [firstScheduled, secondScheduled] = await Promise.all([
    handler(request({ action: "schedule", proposalId: "proposal-1" })),
    handler(request({ action: "schedule", proposalId: "proposal-1" })),
  ]);
  assertEquals(firstScheduled.status, 200);
  assertEquals(secondScheduled.status, 200);

  const firstBody = await firstScheduled.json();
  const secondBody = await secondScheduled.json();

  assertEquals(scheduleInputs.length, 2);
  for (const input of scheduleInputs) {
    assertEquals(input.planVersionId, "schedule-plan:proposal-1");
    assertEquals(input.availabilityVersionId, "schedule-availability:proposal-1");
    assertEquals(input.scheduledAt, now.toISOString());
    assertEquals(input.userId, "token-user");
  }
  assertEquals(firstBody.scheduledPlanVersionId, "schedule-plan:proposal-1");
  assertEquals(secondBody.scheduledPlanVersionId, "schedule-plan:proposal-1");
  assertEquals(firstBody.scheduledAvailabilityVersionId, "schedule-availability:proposal-1");
  assertEquals(secondBody.scheduledAvailabilityVersionId, "schedule-availability:proposal-1");
  assertEquals(firstBody.activationId, secondBody.activationId);
});

Deno.test("production dependencies read auth claims and forward verified user id into data/rpc seams", async () => {
  const eqCalls: Array<{ table: string; column: string; value: unknown }> = [];
  const selectCalls: Array<{ table: string; columns: string | undefined }> = [];
  const rpcCalls: Array<{ name: string; params: Record<string, unknown> }> = [];
  let seenToken: string | null = null;

  const adminRows = {
    runner_profiles: {
      data: {
        data: {
          strength: {
            preferredDays: ["day_mon", "day_wed"],
          },
        },
        schema_version: 1,
        updated_at: "2026-07-13T00:00:00.000Z",
      },
      error: null,
    },
    plan_versions: {
      data: {
        id: "source-plan",
        data: sourcePlan,
      },
      error: null,
    },
    activity_records: {
      data: [{ linked_session_id: "session-1" }],
      error: null,
    },
  };

  const adminClient = {
    from(table: string) {
      const result = (adminRows as Record<string, { data: unknown; error: unknown }>)[table];
      const query = {
        select(columns?: string) {
          selectCalls.push({ table, columns });
          return query;
        },
        eq(column: string, value: unknown) {
          eqCalls.push({ table, column, value });
          return query;
        },
        maybeSingle: async () => {
          return result;
        },
        then(resolve: (value: unknown) => unknown, reject?: (reason: unknown) => unknown) {
          return Promise.resolve(result).then(resolve, reject);
        },
      };
      return query;
    },
    rpc(name: string, params: Record<string, unknown>) {
      rpcCalls.push({ name, params });
      return Promise.resolve({
        data: {
          accepted_plan_version_id: "accepted-plan",
          plan_data: { id: "accepted-plan" },
          prior_active_plan_version_id: null,
          prior_active_availability_version_id: null,
          accepted_availability_version_id: "accepted-avail",
          proposal_id: "proposal-1",
          activation_id: "activation-1",
          proposal_status: "accepted",
          scheduled_plan_version_id: "scheduled-plan",
          scheduled_availability_version_id: "scheduled-availability",
          activation_status: "activated",
          prior_plan_version_id: null,
          prior_availability_version_id: null,
          restored_plan_version_id: null,
          restored_availability_version_id: null,
          id: "stored-id",
          expires_at: "2026-07-13T12:30:00.000Z",
        },
        error: null,
      });
    },
  } as unknown as SupabaseClient;

  const publicClient = {
    auth: {
      getClaims: async (token: string) => {
        seenToken = token;
        return {
          data: {
            claims: {
              sub: "verified-user",
            },
          },
          error: null,
        };
      },
    },
  } as unknown as SupabaseClient;

  const dependencies = createProductionDependencies(publicClient, adminClient);

  const userId = await dependencies.authenticate("Bearer verified-token");
  assertEquals(userId, "verified-user");
  assertEquals(seenToken, "verified-token");

  const context = await dependencies.loadPreviewContext(userId ?? "");
  assertEquals(context?.sourcePlanVersionId, "source-plan");
  assertEquals(context?.profileSchemaVersion, 1);
  assertEquals(
    selectCalls.find((call) => call.table === "plan_versions")?.columns,
    "id,data",
  );

  const seenReadUserIds = eqCalls.filter((row) => row.column === "user_id").map((row) => row.value);
  assertEquals(seenReadUserIds.includes("verified-user"), true);

  await dependencies.acceptProposalNow(
    userId ?? "",
    "proposal-1",
    "plan-generated-1",
    "avail-generated-1",
    "2026-07-13T12:00:00.000Z",
    "2026-07-13T12:00:00.000Z",
  );
  await dependencies.scheduleProposal(
    userId ?? "",
    "proposal-1",
    "plan-generated-2",
    "avail-generated-2",
    "2026-07-13T12:00:00.000Z",
  );
  await dependencies.cancelScheduledProposal(
    userId ?? "",
    "proposal-1",
    "2026-07-13T12:00:00.000Z",
  );
  await dependencies.activateDueProposal(
    userId ?? "",
    "activation-1",
    "2026-07-13T12:00:00.000Z",
  );
  await dependencies.undoAcceptedProposal(
    userId ?? "",
    "proposal-1",
    "2026-07-13T12:00:00.000Z",
  );
  await dependencies.storeProposal({
    userId: userId ?? "",
    proposalId: "proposal-generated",
    sourcePlanVersionId: "source-plan",
    candidatePlan: {},
    impact: {},
    proposedAvailability: {},
    effectiveFrom: "2026-07-13",
    createdAt: "2026-07-13T12:00:00.000Z",
    expiresAt: "2026-07-13T12:30:00.000Z",
    sourceProfileSchemaVersion: 1,
    sourceProfileUpdatedAt: "2026-07-13T00:00:00.000Z",
  });

  const expectedSeamUserId = "verified-user";
  for (const call of rpcCalls) {
    if (Object.prototype.hasOwnProperty.call(call.params, "p_user_id")) {
      assertEquals(call.params.p_user_id, expectedSeamUserId);
    }
  }
});

Deno.test("production dependencies reject malformed lifecycle rpc response shapes", async () => {
  const publicClient = {
    auth: {
      getClaims: async () => ({
        data: {
          claims: {
            sub: "verified-user",
          },
        },
        error: null,
      }),
    },
  } as unknown as SupabaseClient;

  const malformedAccept = {
    accepted_plan_version_id: 123,
    plan_data: "not-object",
    prior_active_plan_version_id: null,
    prior_active_availability_version_id: null,
    accepted_availability_version_id: "accepted-avail",
  } as unknown;
  const malformedSchedule = {
    proposal_id: "proposal-1",
    activation_id: "activation-1",
    scheduled_plan_version_id: null,
    scheduled_availability_version_id: "avail-1",
    activation_status: "scheduled",
  } as unknown;
  const malformedCancel = {
    proposal_id: "proposal-1",
    proposal_status: 123,
    activation_id: "activation-1",
    scheduled_plan_version_id: null,
  } as unknown;
  const validAccept = {
    accepted_plan_version_id: "accepted-plan",
    plan_data: { id: "accepted-plan" },
    prior_active_plan_version_id: null,
    prior_active_availability_version_id: null,
    accepted_availability_version_id: "accepted-avail",
  } as unknown;
  const validSchedule = {
    proposal_id: "proposal-1",
    activation_id: "activation-1",
    scheduled_plan_version_id: "plan-1",
    scheduled_availability_version_id: "avail-1",
    activation_status: "scheduled",
  } as unknown;
  const malformedActivate = {
    proposal_id: null,
    activation_id: "activation-1",
    proposal_status: "accepted",
    accepted_plan_version_id: undefined,
    prior_active_plan_version_id: null,
    prior_active_availability_version_id: null,
    accepted_availability_version_id: null,
    activation_status: "activated",
  } as unknown;
  const malformedUndo = {
    proposal_id: 7,
    prior_plan_version_id: null,
    prior_availability_version_id: null,
    restored_plan_version_id: null,
    restored_availability_version_id: null,
  } as unknown;

  const acceptDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: malformedAccept, error: null }),
    } as unknown as SupabaseClient,
  );
  const acceptArrayDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [validAccept], error: null }),
    } as unknown as SupabaseClient,
  );
  const acceptEmptyDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [], error: null }),
    } as unknown as SupabaseClient,
  );
  const acceptMultiRowDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [validAccept, validAccept], error: null }),
    } as unknown as SupabaseClient,
  );
  const scheduleDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: malformedSchedule, error: null }),
    } as unknown as SupabaseClient,
  );
  const scheduleArrayDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [validSchedule], error: null }),
    } as unknown as SupabaseClient,
  );
  const scheduleEmptyDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [], error: null }),
    } as unknown as SupabaseClient,
  );
  const scheduleMultiRowDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: [validSchedule, validSchedule], error: null }),
    } as unknown as SupabaseClient,
  );
  const cancelDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: malformedCancel, error: null }),
    } as unknown as SupabaseClient,
  );
  const activateDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: malformedActivate, error: null }),
    } as unknown as SupabaseClient,
  );
  const undoDeps = createProductionDependencies(
    publicClient,
    {
      rpc: async () => ({ data: malformedUndo, error: null }),
    } as unknown as SupabaseClient,
  );

  await assertRejects(
    () =>
      acceptDeps.acceptProposalNow(
        "verified-user",
        "proposal-1",
        "plan-1",
        "avail-1",
        "2026-07-13T00:00:00.000Z",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid accept_change_schedule_proposal_now response",
  );
  const acceptedRow = await acceptArrayDeps.acceptProposalNow(
    "verified-user",
    "proposal-1",
    "plan-1",
    "avail-1",
    "2026-07-13T00:00:00.000Z",
    "2026-07-13T00:00:00.000Z",
  );
  assertEquals(acceptedRow.accepted_plan_version_id, "accepted-plan");
  await assertRejects(
    () =>
      acceptEmptyDeps.acceptProposalNow(
        "verified-user",
        "proposal-1",
        "plan-1",
        "avail-1",
        "2026-07-13T00:00:00.000Z",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid accept_change_schedule_proposal_now response",
  );
  await assertRejects(
    () =>
      acceptMultiRowDeps.acceptProposalNow(
        "verified-user",
        "proposal-1",
        "plan-1",
        "avail-1",
        "2026-07-13T00:00:00.000Z",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid accept_change_schedule_proposal_now response",
  );
  await assertRejects(
    () => scheduleDeps.scheduleProposal(
      "verified-user",
      "proposal-1",
      "plan-1",
      "avail-1",
      "2026-07-13T00:00:00.000Z",
    ),
    Error,
    "Invalid schedule_change_schedule_proposal response",
  );
  await assertRejects(
    () =>
      scheduleEmptyDeps.scheduleProposal(
        "verified-user",
        "proposal-1",
        "plan-1",
        "avail-1",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid schedule_change_schedule_proposal response",
  );
  await assertRejects(
    () =>
      scheduleMultiRowDeps.scheduleProposal(
        "verified-user",
        "proposal-1",
        "plan-1",
        "avail-1",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid schedule_change_schedule_proposal response",
  );
  const scheduledRow = await scheduleArrayDeps.scheduleProposal(
    "verified-user",
    "proposal-1",
    "plan-1",
    "avail-1",
    "2026-07-13T00:00:00.000Z",
  );
  assertEquals(scheduledRow.scheduled_plan_version_id, "plan-1");
  await assertRejects(
    () =>
      cancelDeps.cancelScheduledProposal(
        "verified-user",
        "proposal-1",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid cancel_scheduled_change_schedule_proposal response",
  );
  await assertRejects(
    () =>
      activateDeps.activateDueProposal(
        "verified-user",
        "activation-1",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid activate_due_change_schedule response",
  );
  await assertRejects(
    () =>
      undoDeps.undoAcceptedProposal(
        "verified-user",
        "proposal-1",
        "2026-07-13T00:00:00.000Z",
      ),
    Error,
    "Invalid undo_accepted_change_schedule_proposal response",
  );
});

Deno.test("malformed lifecycle response from production seam becomes 500 from handler", async () => {
  const publicClient = {
    auth: {
      getClaims: async () => ({
        data: {
          claims: {
            sub: "verified-user",
          },
        },
        error: null,
      }),
    },
  } as unknown as SupabaseClient;
  const handler = createChangeScheduleHandler(
    createProductionDependencies(
      publicClient,
      {
        from() {
          const query = {
            select: () => query,
            eq: () => query,
            maybeSingle: async () => ({
              data: {
                status: "pending",
              },
              error: null,
            }),
          };
          return query as unknown as { [key: string]: unknown };
        },
        rpc: async () => ({
          data: {
            accepted_plan_version_id: 123,
            plan_data: "not-object",
            prior_active_plan_version_id: null,
            prior_active_availability_version_id: null,
            accepted_availability_version_id: "accepted-avail",
          },
          error: null,
        }),
      } as unknown as SupabaseClient,
    ),
  );
  const response = await handler(request({ action: "accept_now", proposalId: "proposal-1" }));
  assertEquals(response.status, 500);
});

Deno.test("mapRpcError converts database errors to public keys", () => {
  assertEquals(mapRpcError(new Error("change_schedule_proposal_not_found")), {
    key: "proposal_not_found",
    status: 404,
  });
  assertEquals(
    mapRpcError(new Error("change_schedule_activation_proposal_not_available")),
    {
      key: "activation_not_available",
      status: 409,
    },
  );
  assertEquals(mapRpcError(new Error("change_schedule_availability_payload_duration_invalid")), {
    key: "invalid_request",
    status: 400,
  });
  assertEquals(mapRpcError(new Error("change_schedule_accept_profile_not_found")), {
    key: "profile_not_found",
    status: 404,
  });
  assertEquals(mapRpcError(new Error("change_schedule_plan_version_id_conflict")), {
    key: "proposal_plan_version_conflict",
    status: 409,
  });
  assertEquals(mapRpcError(new Error("change_schedule_availability_id_conflict")), {
    key: "proposal_availability_id_conflict",
    status: 409,
  });
  assertEquals(
    mapRpcError(new Error("change_schedule_accept_prior_plan_not_found")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_activation_source_plan_not_active")),
    {
      key: "source_plan_stale",
      status: 409,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_activation_proposal_inconsistent")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_activation_proposal_source_mismatch")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_activate_prior_plan_missing")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_activation_snapshot_plan_missing")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_prior_availability_not_owned")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_scheduled_plan_not_owned")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_accepted_plan_not_owned")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_accepted_availability_not_owned")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_terminalization_requires_schedule_clear")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_terminalization_lineage_rewrite")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
  assertEquals(
    mapRpcError(new Error("change_schedule_proposal_scheduled_rewrite_rejected")),
    {
      key: "proposal_inconsistent",
      status: 500,
    },
  );
});

Deno.test("handler maps schedule ID collision errors to stable 409 responses", async () => {
  const handler = createChangeScheduleHandler(fakeDependencies({
    scheduleProposal: async () => {
      throw new Error("change_schedule_plan_version_id_conflict");
    },
  }));
  const planConflict = await handler(request({
    action: "schedule",
    proposalId: "proposal-1",
  }));
  assertEquals(planConflict.status, 409);
  assertEquals(await planConflict.json(), { error: "proposal_plan_version_conflict" });

  const availabilityConflictHandler = createChangeScheduleHandler(fakeDependencies({
    scheduleProposal: async () => {
      throw new Error("change_schedule_availability_id_conflict");
    },
  }));
  const availabilityConflict = await availabilityConflictHandler(request({
    action: "schedule",
    proposalId: "proposal-1",
  }));
  assertEquals(availabilityConflict.status, 409);
  assertEquals(await availabilityConflict.json(), {
    error: "proposal_availability_id_conflict",
  });
});

Deno.test("handler maps reviewed activation/accept invariant errors to stable keys", async () => {
  const ownershipAndLineageErrors = [
    "change_schedule_proposal_prior_availability_not_owned",
    "change_schedule_proposal_scheduled_plan_not_owned",
    "change_schedule_proposal_accepted_plan_not_owned",
    "change_schedule_proposal_accepted_availability_not_owned",
    "change_schedule_proposal_terminalization_requires_schedule_clear",
    "change_schedule_proposal_terminalization_lineage_rewrite",
    "change_schedule_proposal_scheduled_rewrite_rejected",
  ];
  for (const errorCode of ownershipAndLineageErrors) {
    const response = await createChangeScheduleHandler(
      fakeDependencies({
        acceptProposalNow: async () => {
          throw new Error(errorCode);
        },
      }),
    )(request({ action: "accept_now", proposalId: "proposal-1" }));
    assertEquals(response.status, 500);
    assertEquals(await response.json(), { error: "proposal_inconsistent" });
  }

  const acceptPriorPlan = createChangeScheduleHandler(
    fakeDependencies({
      acceptProposalNow: async () => {
        throw new Error("change_schedule_accept_prior_plan_not_found");
      },
    }),
  );
  const acceptResponse = await acceptPriorPlan(
    request({ action: "accept_now", proposalId: "proposal-1" }),
  );
  assertEquals(acceptResponse.status, 500);
  assertEquals(await acceptResponse.json(), { error: "proposal_inconsistent" });

  const activateSourceInactive = createChangeScheduleHandler(
    fakeDependencies({
      activateDueProposal: async () => {
        throw new Error("change_schedule_activation_source_plan_not_active");
      },
    }),
  );
  const activateResponse = await activateSourceInactive(
    request({ action: "activate_due", activationId: "activation-1" }),
  );
  assertEquals(activateResponse.status, 409);
  assertEquals(await activateResponse.json(), { error: "source_plan_stale" });

  const activateProposalInconsistent = createChangeScheduleHandler(
    fakeDependencies({
      activateDueProposal: async () => {
        throw new Error("change_schedule_activation_proposal_inconsistent");
      },
    }),
  );
  const activateProposalInconsistentResponse = await activateProposalInconsistent(
    request({ action: "activate_due", activationId: "activation-1" }),
  );
  assertEquals(activateProposalInconsistentResponse.status, 500);
  assertEquals(await activateProposalInconsistentResponse.json(), {
    error: "proposal_inconsistent",
  });

  const activateProposalSourceMismatch = createChangeScheduleHandler(
    fakeDependencies({
      activateDueProposal: async () => {
        throw new Error("change_schedule_activation_proposal_source_mismatch");
      },
    }),
  );
  const activateProposalSourceMismatchResponse = await activateProposalSourceMismatch(
    request({ action: "activate_due", activationId: "activation-1" }),
  );
  assertEquals(activateProposalSourceMismatchResponse.status, 500);
  assertEquals(await activateProposalSourceMismatchResponse.json(), {
    error: "proposal_inconsistent",
  });

  const activateSnapshotMissing = createChangeScheduleHandler(
    fakeDependencies({
      activateDueProposal: async () => {
        throw new Error("change_schedule_activation_snapshot_plan_missing");
      },
    }),
  );
  const activateSnapshotMissingResponse = await activateSnapshotMissing(
    request({ action: "activate_due", activationId: "activation-1" }),
  );
  assertEquals(activateSnapshotMissingResponse.status, 500);
  assertEquals(await activateSnapshotMissingResponse.json(), {
    error: "proposal_inconsistent",
  });

  const activatePriorPlanMissing = createChangeScheduleHandler(
    fakeDependencies({
      activateDueProposal: async () => {
        throw new Error("change_schedule_activate_prior_plan_missing");
      },
    }),
  );
  const activatePriorPlanMissingResponse = await activatePriorPlanMissing(
    request({ action: "activate_due", activationId: "activation-1" }),
  );
  assertEquals(activatePriorPlanMissingResponse.status, 500);
  assertEquals(await activatePriorPlanMissingResponse.json(), {
    error: "proposal_inconsistent",
  });
});

function fakeDependencies(
  overrides: Partial<ChangeScheduleDependencies> = {},
): ChangeScheduleDependencies {
  return {
    authenticate: async () => "token-user",
    loadPreviewContext: async () => ({
      profile: {
        strength: {
          preferredDays: ["day_mon", "day_wed"],
        },
      },
      sourcePlan,
      sourcePlanVersionId: "source-plan",
      profileSchemaVersion: 1,
      profileUpdatedAt: "2026-07-13T00:00:00.000Z",
      immutableSessionIds: [],
    }),
    storeProposal: async (input) => ({
      id: input.proposalId,
      expires_at: input.expiresAt,
    }),
    acceptProposalNow: async () => ({
      accepted_plan_version_id: "accepted-plan",
      plan_data: { id: "accepted-plan" },
      prior_active_plan_version_id: null,
      prior_active_availability_version_id: null,
      accepted_availability_version_id: "accepted-avail",
    }),
  scheduleProposal: async () => ({
    proposal_id: "proposal-1",
    activation_id: "activation-1",
    scheduled_plan_version_id: "plan-2",
    scheduled_availability_version_id: "avail-1",
    activation_status: "scheduled",
  }),
    cancelScheduledProposal: async () => ({
      proposal_id: "proposal-1",
      proposal_status: "cancelled",
      activation_id: "activation-1",
      scheduled_plan_version_id: null,
    }),
    activateDueProposal: async () => ({
      proposal_id: "proposal-1",
      activation_id: "activation-1",
      proposal_status: "accepted",
      accepted_plan_version_id: "accepted-plan",
      prior_active_plan_version_id: null,
      prior_active_availability_version_id: null,
      accepted_availability_version_id: "accepted-avail",
      activation_status: "activated",
    }),
    undoAcceptedProposal: async () => ({
      proposal_id: "proposal-1",
      prior_plan_version_id: null,
      prior_availability_version_id: null,
      restored_plan_version_id: null,
      restored_availability_version_id: null,
    }),
    now: () => new Date("2026-07-13T12:00:00.000Z"),
    randomId: () => "fixed-id",
    ...overrides,
  };
}

function previewBody(overrides: {
  availability?: Record<string, unknown>;
  localDate?: string;
  effectiveFrom?: string;
} = {}) {
  return {
    action: "preview",
    availability: {
      ...availability,
      ...overrides.availability,
    },
    localDate: "2026-07-13",
    ...overrides,
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("http://local/change-schedule", {
    method: "POST",
    headers: {
      Authorization: "Bearer token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}
