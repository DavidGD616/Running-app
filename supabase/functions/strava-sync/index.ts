import { createClient } from "@supabase/supabase-js";
import {
  hasRequiredScopes,
  SYNC_REQUIRED_SCOPES,
} from "../_shared/strava-scopes.ts";

const STRAVA_TOKEN_URL = "https://www.strava.com/api/v3/oauth/token";
const STRAVA_ATHLETE_STATS_URL = "https://www.strava.com/api/v3/athletes";
const STRAVA_ACTIVITIES_URL = "https://www.strava.com/api/v3/athlete/activities";
const STRAVA_ZONES_URL = "https://www.strava.com/api/v3/athlete/zones";
const STRAVA_RATE_LIMIT_BUFFER_MS = 200;
const STRAVA_ACTIVITY_PAGE_SIZE = 100;
const STRAVA_MAX_ACTIVITY_PAGES = 6;
const TWELVE_WEEKS_IN_SECONDS = 84 * 24 * 60 * 60;

type StravaTokenRow = {
  user_id: string;
  access_token: string;
  refresh_token: string;
  expires_at: string;
  athlete_id: number;
  scope: string;
};

type StravaOAuthTokenResponse = {
  access_token?: unknown;
  refresh_token?: unknown;
  expires_at?: unknown;
};

type StravaHttpResult = {
  status: number;
  headers: Headers;
  bodyText: string;
};

type NormalizedStravaSyncResponse = {
  athlete: Record<string, unknown>;
  stats: Record<string, unknown>;
  activities: Array<Record<string, unknown>>;
  zones?: Record<string, unknown> | null;
  meta: {
    syncedAt: string;
    fetchedActivitiesCount: number;
  };
};

// Raised when Strava rejects the access token (401) and a forced refresh also
// fails, meaning the integration can no longer recover without the user
// reconnecting on Strava's side.
class StravaReauthRequiredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "StravaReauthRequiredError";
  }
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function createAdminClient() {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

function parseJsonObject(raw: unknown): Record<string, unknown> {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return {};
  }
  const map: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) {
    map[key] = value;
  }
  return map;
}

function getBearerToken(authorizationHeader: string | null): string | null {
  if (!authorizationHeader) return null;
  if (!authorizationHeader.startsWith("Bearer ")) return null;
  const token = authorizationHeader.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

async function resolveUserId(authorizationHeader: string | null) {
  const jwt = getBearerToken(authorizationHeader);
  if (!jwt) return null;

  const supabasePublic = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SB_PUBLISHABLE_KEY"),
  );
  const { data, error } = await supabasePublic.auth.getClaims(jwt);
  if (error) {
    console.error("getClaims failed:", error);
    return null;
  }

  const userId = data?.claims?.sub;
  if (typeof userId !== "string" || userId.length === 0) return null;
  return userId;
}

function tokenIsExpired(expiresAtIso: string): boolean {
  const expiresAtMs = Date.parse(expiresAtIso);
  if (Number.isNaN(expiresAtMs)) return true;
  return expiresAtMs <= Date.now();
}

function toIsoFromEpochSeconds(seconds: number): string {
  return new Date(seconds * 1000).toISOString();
}

function epochSecondsNow() {
  return Math.floor(Date.now() / 1000);
}

async function refreshTokenIfNeeded(
  adminClient: any,
  tokenRow: StravaTokenRow,
) {
  if (!tokenIsExpired(tokenRow.expires_at)) return tokenRow;
  return await forceRefreshToken(adminClient, tokenRow);
}

async function forceRefreshToken(
  adminClient: any,
  tokenRow: StravaTokenRow,
) {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: requireEnv("STRAVA_CLIENT_ID"),
      client_secret: requireEnv("STRAVA_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: tokenRow.refresh_token,
    }),
  });

  const bodyText = await response.text();
  if (!response.ok) {
    // A 400/401 from the token endpoint means the refresh token itself is no
    // longer valid (e.g. the user revoked access on Strava). The integration
    // cannot recover without a fresh OAuth grant, so clear the dead row and
    // signal that a reconnect is required.
    if (response.status === 400 || response.status === 401) {
      await clearStoredToken(adminClient, tokenRow.user_id);
      throw new StravaReauthRequiredError(
        `Strava refresh rejected: ${response.status} ${bodyText}`,
      );
    }
    throw new Error(`Strava refresh failed: ${response.status} ${bodyText}`);
  }

  const payload = parseJsonObject(JSON.parse(bodyText)) as StravaOAuthTokenResponse;
  const nextAccessToken = payload.access_token;
  const nextRefreshToken = payload.refresh_token;
  const nextExpiresAtSeconds = payload.expires_at;
  if (
    typeof nextAccessToken !== "string" || nextAccessToken.length === 0 ||
    typeof nextRefreshToken !== "string" || nextRefreshToken.length === 0 ||
    typeof nextExpiresAtSeconds !== "number"
  ) {
    throw new Error("Invalid Strava refresh payload");
  }

  const nextExpiresAt = toIsoFromEpochSeconds(nextExpiresAtSeconds);
  const { error: updateError } = await adminClient
    .from("strava_tokens")
    .update({
      access_token: nextAccessToken,
      refresh_token: nextRefreshToken,
      expires_at: nextExpiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", tokenRow.user_id);
  if (updateError) {
    throw new Error(`Failed to persist refreshed token: ${updateError.message}`);
  }

  return {
    ...tokenRow,
    access_token: nextAccessToken,
    refresh_token: nextRefreshToken,
    expires_at: nextExpiresAt,
  } satisfies StravaTokenRow;
}

async function clearStoredToken(adminClient: any, userId: string) {
  const { error } = await adminClient
    .from("strava_tokens")
    .delete()
    .eq("user_id", userId);
  if (error) {
    // Surfacing this would mask the underlying reauth signal; log and move on.
    console.error("Failed to clear revoked Strava token row:", error);
  }
}

// Shared per-request state so a forced token refresh triggered by one core
// endpoint is reused by every later endpoint in the same sync.
type SyncContext = {
  adminClient: any;
  tokenRow: StravaTokenRow;
  refreshedOnce: boolean;
};

async function stravaGet(
  url: string,
  accessToken: string,
): Promise<StravaHttpResult> {
  const response = await fetch(url, {
    method: "GET",
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const bodyText = await response.text();
  await maybePauseForRateLimit(response.headers);
  return { status: response.status, headers: response.headers, bodyText };
}

// Performs a Strava GET, and if Strava answers 401 (token revoked or
// invalidated early), forces a single token refresh and retries once. If the
// refresh fails because the grant is gone, forceRefreshToken throws
// StravaReauthRequiredError, which the top-level handler maps to a distinct
// "reconnect required" client status.
async function stravaGetWithReauth(
  ctx: SyncContext,
  url: string,
): Promise<StravaHttpResult> {
  const result = await stravaGet(url, ctx.tokenRow.access_token);
  if (result.status !== 401) return result;

  if (ctx.refreshedOnce) {
    // Already refreshed during this sync and Strava still rejects us.
    await clearStoredToken(ctx.adminClient, ctx.tokenRow.user_id);
    throw new StravaReauthRequiredError(
      `Strava returned 401 after token refresh for ${url}`,
    );
  }

  ctx.tokenRow = await forceRefreshToken(ctx.adminClient, ctx.tokenRow);
  ctx.refreshedOnce = true;

  const retry = await stravaGet(url, ctx.tokenRow.access_token);
  if (retry.status === 401) {
    await clearStoredToken(ctx.adminClient, ctx.tokenRow.user_id);
    throw new StravaReauthRequiredError(
      `Strava returned 401 after token refresh for ${url}`,
    );
  }
  return retry;
}

async function maybePauseForRateLimit(headers: Headers) {
  const usage = headers.get("x-ratelimit-usage");
  const limit = headers.get("x-ratelimit-limit");
  if (!usage || !limit) return;

  const [usage15, usageDay] = usage.split(",").map((value) =>
    Number.parseInt(value.trim(), 10)
  );
  const [limit15, limitDay] = limit.split(",").map((value) =>
    Number.parseInt(value.trim(), 10)
  );

  if (
    Number.isNaN(usage15) || Number.isNaN(usageDay) || Number.isNaN(limit15) ||
    Number.isNaN(limitDay)
  ) {
    return;
  }

  const fifteenMinNearLimit = usage15 >= Math.max(1, limit15 - 2);
  const dayNearLimit = usageDay >= Math.max(1, limitDay - 10);
  if (fifteenMinNearLimit || dayNearLimit) {
    await new Promise((resolve) => {
      setTimeout(resolve, STRAVA_RATE_LIMIT_BUFFER_MS);
    });
  }
}

function parseStravaJsonBody(result: StravaHttpResult): unknown {
  try {
    return JSON.parse(result.bodyText);
  } catch {
    return null;
  }
}

function throwStravaError(message: string, result: StravaHttpResult): never {
  throw new Error(
    `${message} (status=${result.status}, body=${result.bodyText})`,
  );
}

function normalizeActivity(raw: Record<string, unknown>): Record<string, unknown> {
  return {
    distance: raw.distance,
    moving_time: raw.moving_time,
    average_speed: raw.average_speed,
    average_heartrate: raw.average_heartrate,
    start_date: raw.start_date,
    type: raw.type,
    sport_type: raw.sport_type,
  };
}

async function fetchAthleteStats(
  ctx: SyncContext,
): Promise<Record<string, unknown>> {
  const result = await stravaGetWithReauth(
    ctx,
    `${STRAVA_ATHLETE_STATS_URL}/${ctx.tokenRow.athlete_id}/stats`,
  );
  if (result.status < 200 || result.status >= 300) {
    throwStravaError("Failed to fetch Strava athlete stats", result);
  }

  const parsed = parseStravaJsonBody(result);
  return parseJsonObject(parsed);
}

async function fetchAthleteZones(
  ctx: SyncContext,
): Promise<Record<string, unknown> | null> {
  // Zones are optional. A 401 still routes through the shared reauth retry for
  // consistency with the other core endpoints; only 403/404 are treated as a
  // benign "not available" signal here.
  const result = await stravaGetWithReauth(ctx, STRAVA_ZONES_URL);
  if (result.status === 403 || result.status === 404) {
    return null;
  }
  if (result.status < 200 || result.status >= 300) {
    throwStravaError("Failed to fetch Strava athlete zones", result);
  }

  const parsed = parseStravaJsonBody(result);
  if (!parsed) return null;
  if (Array.isArray(parsed)) return null;
  return parseJsonObject(parsed);
}

async function fetchActivities(
  ctx: SyncContext,
): Promise<Array<Record<string, unknown>>> {
  const after = epochSecondsNow() - TWELVE_WEEKS_IN_SECONDS;
  const activities: Array<Record<string, unknown>> = [];

  for (
    let pageNumber = 1;
    pageNumber <= STRAVA_MAX_ACTIVITY_PAGES;
    pageNumber++
  ) {
    const url = new URL(STRAVA_ACTIVITIES_URL);
    url.searchParams.set("after", String(after));
    url.searchParams.set("per_page", String(STRAVA_ACTIVITY_PAGE_SIZE));
    url.searchParams.set("page", String(pageNumber));

    const result = await stravaGetWithReauth(ctx, url.toString());
    if (result.status < 200 || result.status >= 300) {
      throwStravaError("Failed to fetch Strava activities", result);
    }

    const parsed = parseStravaJsonBody(result);
    if (!Array.isArray(parsed)) {
      throw new Error("Unexpected Strava activities payload");
    }

    if (parsed.length === 0) break;

    for (const raw of parsed) {
      activities.push(normalizeActivity(parseJsonObject(raw)));
    }
  }

  return activities;
}

function mapAthleteFromTokenAndZones(
  tokenRow: StravaTokenRow,
  zones: Record<string, unknown> | null,
) {
  const heartRate = zones?.heart_rate;
  const heartRateMap = parseJsonObject(heartRate);
  const zonesList = heartRateMap.zones;

  return {
    sex: null,
    weight: null,
    athlete_id: tokenRow.athlete_id,
    heart_rate_zones: {
      zones: Array.isArray(zonesList)
          ? zonesList.map((zone) => parseJsonObject(zone))
          : [],
    },
  } satisfies Record<string, unknown>;
}

function normalizeSyncResponse(
  tokenRow: StravaTokenRow,
  stats: Record<string, unknown>,
  activities: Array<Record<string, unknown>>,
  zones: Record<string, unknown> | null,
) {
  return {
    athlete: mapAthleteFromTokenAndZones(tokenRow, zones),
    stats,
    activities,
    zones,
    meta: {
      syncedAt: new Date().toISOString(),
      fetchedActivitiesCount: activities.length,
    },
  } satisfies NormalizedStravaSyncResponse;
}

async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const userId = await resolveUserId(req.headers.get("Authorization"));
  if (!userId) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const adminClient = createAdminClient();

  const { data, error } = await adminClient
    .from("strava_tokens")
    .select("user_id, access_token, refresh_token, expires_at, athlete_id, scope")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.error("Failed to load strava token row:", error);
    return jsonResponse({ error: "Failed to read Strava token" }, 500);
  }
  if (!data) {
    return jsonResponse({ error: "Strava not connected" }, 404);
  }

  const tokenRow = data as StravaTokenRow;
  if (!hasRequiredScopes(tokenRow.scope, SYNC_REQUIRED_SCOPES)) {
    return jsonResponse(
      {
        error: "Stored Strava scope is insufficient",
        detail: tokenRow.scope,
      },
      412,
    );
  }

  try {
    const freshTokenRow = await refreshTokenIfNeeded(adminClient, tokenRow);
    const ctx: SyncContext = {
      adminClient,
      tokenRow: freshTokenRow,
      refreshedOnce: tokenIsExpired(tokenRow.expires_at),
    };
    const stats = await fetchAthleteStats(ctx);
    const activities = await fetchActivities(ctx);
    const zones = await fetchAthleteZones(ctx);

    return jsonResponse(
      normalizeSyncResponse(ctx.tokenRow, stats, activities, zones),
      200,
    );
  } catch (error) {
    const mapped = mapSyncError(error);
    // FIX D: log the full upstream detail server-side; the returned body never
    // reflects raw Strava error bodies back to the client.
    console.error(mapped.logMessage, error);
    return jsonResponse(mapped.body, mapped.status);
  }
}

// Only bind the server when executed as the entrypoint (Supabase runtime).
// Importing this module from tests must not start a listener.
if (import.meta.main) {
  Deno.serve(handleRequest);
}

type SyncErrorMapping = {
  status: number;
  body: Record<string, unknown>;
  logMessage: string;
};

// Pure mapping from a caught sync error to a safe client response.
// FIX A: a revoked/early-invalidated grant returns a distinct, app-actionable
// "reconnect required" signal instead of a generic upstream failure.
// FIX D: every other failure returns a generic message with no upstream detail.
export function mapSyncError(error: unknown): SyncErrorMapping {
  if (error instanceof StravaReauthRequiredError) {
    return {
      status: 409,
      body: {
        error: "Strava authorization is no longer valid",
        code: "strava_reconnect_required",
      },
      logMessage: "Strava reauthorization required:",
    };
  }
  return {
    status: 502,
    body: { error: "Strava sync failed" },
    logMessage: "Strava sync failed:",
  };
}

export { StravaReauthRequiredError };
