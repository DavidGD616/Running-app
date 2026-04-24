import { createClient } from "@supabase/supabase-js";
import { generatePlanFromProfile } from "./openai.ts";
import {
  addStrideDefaults,
  avoidHardDayTraining,
  ensureFullCalendarWeeks,
  ensureGoalRaceSession,
  normalizeTrainingDayCount,
  normalizeTaper,
  normalizeWorkoutTypesByPhase,
  normalizePeakLongRun,
  phaseForWeek,
  placeLongRunsOnPreferredDay,
  smoothLongRunProgression,
  spaceStressfulSessions,
} from "./plan-rules.ts";
import { buildWorkoutSteps } from "./workout-steps.ts";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Use SB_PUBLISHABLE_KEY + getClaims() for asymmetric ES256 JWT verification.
  // verify_jwt = false in config.toml disables the platform-level check so we
  // handle auth here instead.
  const supabasePublic = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SB_PUBLISHABLE_KEY")!,
  );

  const jwt = authHeader.replace("Bearer ", "");
  const { data: claimsData, error: claimsError } = await supabasePublic.auth
    .getClaims(jwt);
  const userId = claimsData?.claims?.sub;
  if (!userId || claimsError) {
    console.error("getClaims failed:", claimsError);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // User-scoped client for RLS-respecting reads (runner_profiles)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const body = await req.json().catch(() => ({}));
  const requestedBy: string = body.requestedBy ?? "onboarding";
  const locale = normalizeLocale(body.locale);

  // 1. Fetch runner profile for the authenticated user
  const { data: profileRow, error: profileError } = await supabase
    .from("runner_profiles")
    .select("data")
    .eq("user_id", userId)
    .maybeSingle();

  if (profileError || !profileRow) {
    return new Response(
      JSON.stringify({ error: "Runner profile not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const profileData = profileRow.data as Record<string, unknown>;

  // 2. Call OpenAI with structured output
  let generatedPlan;
  try {
    generatedPlan = await generatePlanFromProfile(profileData, locale);
  } catch (err) {
    console.error("OpenAI generation failed:", err);
    return new Response(
      JSON.stringify({ error: "Plan generation failed", detail: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // 3. Build phone-first workout steps deterministically for each session.
  // Schedule constraints and strides are plan rules, not only model suggestions:
  // if OpenAI ignores hard days or omits strides, enforce conservative defaults.
  const scheduleNormalizedSessions = normalizeTrainingDayCount(
    generatedPlan.sessions,
    profileData,
    locale,
  );
  const longRunPlacedSessions = placeLongRunsOnPreferredDay(
    scheduleNormalizedSessions,
    profileData,
    locale,
  );
  const stressSpacedSessions = spaceStressfulSessions(
    longRunPlacedSessions,
    profileData,
    locale,
  );
  const scheduleAdjustedSessions = avoidHardDayTraining(
    stressSpacedSessions,
    profileData,
    locale,
  );
  const fullCalendarSessions = ensureFullCalendarWeeks(
    scheduleAdjustedSessions,
    locale,
  );
  const peakNormalizedSessions = normalizePeakLongRun(
    fullCalendarSessions,
    profileData,
    generatedPlan.totalWeeks,
    locale,
  );
  const progressionSmoothedSessions = smoothLongRunProgression(
    peakNormalizedSessions,
    profileData,
    generatedPlan.totalWeeks,
    locale,
  );
  const taperNormalizedSessions = normalizeTaper(
    progressionSmoothedSessions,
    profileData,
    generatedPlan.totalWeeks,
    locale,
  );
  const phaseNormalizedSessions = normalizeWorkoutTypesByPhase(
    taperNormalizedSessions,
    profileData,
    generatedPlan.totalWeeks,
    locale,
  );
  const phaseStampedSessions = phaseNormalizedSessions.map((session) => ({
    ...session,
    phase: phaseForWeek(session.weekNumber, generatedPlan.totalWeeks, profileData),
  }));
  const raceFinalizedSessions = ensureGoalRaceSession(
    phaseStampedSessions,
    profileData,
    locale,
  );
  const sessionsWithSteps = addStrideDefaults(
    raceFinalizedSessions,
    profileData,
    generatedPlan.totalWeeks,
    locale,
  ).map((session) => ({
    ...session,
    description: session.coachNote,
    status: "upcoming",
    workoutSteps: buildWorkoutSteps(session),
  }));

  // 4-5. Service-role client — bypasses RLS for writes
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Deactivate previous active plans
  await adminClient
    .from("plan_versions")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  // 7. Insert new active plan version
  const versionId = crypto.randomUUID();

  const planJson = {
    ...generatedPlan,
    id: versionId,
    currentWeekNumber: 1,
    sessions: sessionsWithSteps,
  };
  const { error: insertError } = await adminClient.from("plan_versions").insert(
    {
      id: versionId,
      user_id: userId,
      generated_at: new Date().toISOString(),
      requested_by: requestedBy,
      is_active: true,
      schema_version: 1,
      data: planJson,
    },
  );

  if (insertError) {
    console.error("Failed to save plan version:", insertError);
    return new Response(
      JSON.stringify({
        error: "Failed to save plan",
        detail: insertError.message,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ versionId, plan: planJson }), {
    headers: { "Content-Type": "application/json" },
  });
});

function normalizeLocale(value: unknown): "en" | "es" {
  return value === "es" ? "es" : "en";
}
