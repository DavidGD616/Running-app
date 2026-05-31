import { createClient } from "@supabase/supabase-js";
import { hasRequiredScopes } from "../_shared/strava-scopes.ts";

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

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
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
  accessToken: string,
  athleteId: number,
): Promise<Record<string, unknown>> {
  const result = await stravaGet(
    `${STRAVA_ATHLETE_STATS_URL}/${athleteId}/stats`,
    accessToken,
  );
  if (result.status < 200 || result.status >= 300) {
    throwStravaError("Failed to fetch Strava athlete stats", result);
  }

  const parsed = parseStravaJsonBody(result);
  return parseJsonObject(parsed);
}

async function fetchAthleteZones(
  accessToken: string,
): Promise<Record<string, unknown> | null> {
  const result = await stravaGet(STRAVA_ZONES_URL, accessToken);
  if (result.status === 403 || result.status === 401 || result.status === 404) {
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
  accessToken: string,
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

    const result = await stravaGet(url.toString(), accessToken);
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

Deno.serve(async (req) => {
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
  if (
    !hasRequiredScopes(tokenRow.scope, [
      "activity:read_all",
      "profile:read_all",
    ])
  ) {
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
    const stats = await fetchAthleteStats(
      freshTokenRow.access_token,
      freshTokenRow.athlete_id,
    );
    const activities = await fetchActivities(freshTokenRow.access_token);
    const zones = await fetchAthleteZones(freshTokenRow.access_token);

    return jsonResponse(
      normalizeSyncResponse(freshTokenRow, stats, activities, zones),
      200,
    );
  } catch (error) {
    console.error("Strava sync failed:", error);
    return jsonResponse(
      {
        error: "Strava sync failed",
        detail: String(error),
      },
      502,
    );
  }
});
