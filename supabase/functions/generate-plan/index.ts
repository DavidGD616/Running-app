import { createClient } from "@supabase/supabase-js";
import { generatePlanFromProfile } from "./openai.ts";
import { buildWorkoutSteps } from "./workout-steps.ts";
import type { GeneratedSession } from "./schema.ts";

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
    generatedPlan = await generatePlanFromProfile(profileData);
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
  const scheduleAdjustedSessions = avoidHardDayTraining(
    generatedPlan.sessions,
    profileData,
  );
  const sessionsWithSteps = addStrideDefaults(
    scheduleAdjustedSessions,
    profileData,
    generatedPlan.totalWeeks,
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

function addStrideDefaults(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
  totalWeeks: number,
): GeneratedSession[] {
  const config = strideConfigFor(profileData);
  if (config == null) return sessions;
  const hardDays = hardDaySetFor(profileData);

  const weeksWithStrides = new Set<number>();
  for (const session of sessions) {
    if (hasStrides(session)) weeksWithStrides.add(session.weekNumber);
  }

  return sessions.map((session) => {
    if (
      !isStrideEligible(session, config, totalWeeks, weeksWithStrides, hardDays)
    ) {
      return session;
    }

    weeksWithStrides.add(session.weekNumber);
    return {
      ...session,
      strideReps: config.reps,
      strideSeconds: config.seconds,
      strideRecoverySeconds: config.recoverySeconds,
      coachNote: appendStrideCue(session.coachNote),
    };
  });
}

type StrideConfig = {
  startWeek: number;
  reps: number;
  seconds: number;
  recoverySeconds: number;
};

function strideConfigFor(
  profileData: Record<string, unknown>,
): StrideConfig | null {
  const fitness = objectOrNull(profileData.fitness);
  const experience = typeof fitness?.experience === "string"
    ? fitness.experience
    : null;

  switch (experience) {
    case "experience_experienced":
      return { startWeek: 1, reps: 6, seconds: 20, recoverySeconds: 80 };
    case "experience_intermediate":
      return { startWeek: 1, reps: 4, seconds: 20, recoverySeconds: 90 };
    default:
      return null;
  }
}

function isStrideEligible(
  session: GeneratedSession,
  config: StrideConfig,
  totalWeeks: number,
  weeksWithStrides: Set<number>,
  hardDays: Set<string>,
): boolean {
  if (weeksWithStrides.has(session.weekNumber)) return false;
  if (session.weekNumber < config.startWeek) return false;
  if (session.weekNumber > Math.max(1, totalWeeks - 2)) return false;
  if (session.type !== "easyRun") return false;
  if (hardDays.has(dayKeyForDate(session.date))) return false;
  if (hasStrides(session)) return false;
  if ((session.durationMinutes ?? 0) < 25) return false;
  return true;
}

function hasStrides(session: GeneratedSession): boolean {
  return (session.strideReps ?? 0) > 0 && (session.strideSeconds ?? 0) > 0;
}

function appendStrideCue(coachNote: string | null): string {
  const strideCue =
    "Finish with relaxed strides: fast but smooth, not a sprint.";
  if (!coachNote) return strideCue;
  if (coachNote.toLowerCase().includes("stride")) return coachNote;
  return `${coachNote} ${strideCue}`;
}

function objectOrNull(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function avoidHardDayTraining(
  sessions: GeneratedSession[],
  profileData: Record<string, unknown>,
): GeneratedSession[] {
  const hardDays = hardDaySetFor(profileData);
  if (hardDays.size === 0) return sessions;

  const adjusted = sessions.map((session) => ({ ...session }));
  for (let i = 0; i < adjusted.length; i += 1) {
    const session = adjusted[i];
    if (!isStressfulSession(session)) continue;
    if (isGoalRaceSession(session, profileData)) continue;
    if (!hardDays.has(dayKeyForDate(session.date))) continue;

    const swapIndex = findHardDaySwapIndex(adjusted, i, hardDays);
    if (swapIndex == null) continue;

    const swapSession = adjusted[swapIndex];
    adjusted[i] = withScheduleNote({ ...session, date: swapSession.date });
    adjusted[swapIndex] = { ...swapSession, date: session.date };
  }

  return adjusted;
}

function findHardDaySwapIndex(
  sessions: GeneratedSession[],
  sourceIndex: number,
  hardDays: Set<string>,
): number | null {
  const source = sessions[sourceIndex];
  let bestIndex: number | null = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < sessions.length; i += 1) {
    if (i === sourceIndex) continue;

    const candidate = sessions[i];
    if (candidate.weekNumber !== source.weekNumber) continue;
    if (hardDays.has(dayKeyForDate(candidate.date))) continue;
    if (!isLowStressSession(candidate)) continue;

    const score = sessionSwapScore(candidate);
    if (score < bestScore) {
      bestIndex = i;
      bestScore = score;
    }
  }

  return bestIndex;
}

function hardDaySetFor(profileData: Record<string, unknown>): Set<string> {
  const schedule = objectOrNull(profileData.schedule);
  const hardDays = Array.isArray(schedule?.hardDays) ? schedule.hardDays : [];
  return new Set(
    hardDays.filter((day): day is string =>
      typeof day === "string" && day.startsWith("day_")
    ),
  );
}

function dayKeyForDate(date: string): string {
  const [year, month, day] = date.slice(0, 10).split("-").map(Number);
  if (!year || !month || !day) return "";

  const dayIndex = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return [
    "day_sun",
    "day_mon",
    "day_tue",
    "day_wed",
    "day_thu",
    "day_fri",
    "day_sat",
  ][dayIndex] ?? "";
}

function isStressfulSession(session: GeneratedSession): boolean {
  return [
    "longRun",
    "progressionRun",
    "intervals",
    "hillRepeats",
    "fartlek",
    "tempoRun",
    "thresholdRun",
    "racePaceRun",
  ].includes(session.type);
}

function isGoalRaceSession(
  session: GeneratedSession,
  profileData: Record<string, unknown>,
): boolean {
  const goal = objectOrNull(profileData.goal);
  const raceDate = typeof goal?.raceDate === "string" ? goal.raceDate : null;
  return session.type === "racePaceRun" &&
    raceDate != null &&
    session.date.slice(0, 10) === raceDate.slice(0, 10);
}

function isLowStressSession(session: GeneratedSession): boolean {
  return ["restDay", "recoveryRun", "easyRun", "crossTraining"].includes(
    session.type,
  );
}

function sessionSwapScore(session: GeneratedSession): number {
  switch (session.type) {
    case "restDay":
      return 0;
    case "recoveryRun":
      return 1;
    case "easyRun":
      return 2;
    case "crossTraining":
      return 3;
    default:
      return 4;
  }
}

function withScheduleNote(session: GeneratedSession): GeneratedSession {
  const scheduleCue = "Moved away from a day you marked hard to train.";
  const coachNote = session.coachNote;
  if (!coachNote) return { ...session, coachNote: scheduleCue };
  if (coachNote.toLowerCase().includes("hard to train")) return session;
  return { ...session, coachNote: `${coachNote} ${scheduleCue}` };
}
