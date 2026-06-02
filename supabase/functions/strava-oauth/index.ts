import { createClient } from "@supabase/supabase-js";
import {
  hasRequiredScopes,
  OAUTH_REQUIRED_SCOPES,
} from "../_shared/strava-scopes.ts";

const STRAVA_TOKEN_URL = "https://www.strava.com/api/v3/oauth/token";
const STRAVA_DEAUTHORIZE_URL = "https://www.strava.com/oauth/deauthorize";
const STATE_TTL_SECONDS = 10 * 60;

type StravaOAuthTokenResponse = {
  access_token?: unknown;
  refresh_token?: unknown;
  expires_at?: unknown;
  scope?: unknown;
  athlete?: {
    id?: unknown;
  };
};

type StravaTokenRow = {
  access_token: string;
  refresh_token: string;
  expires_at: string;
};

type RefreshAccessTokenFn = (
  refreshToken: string,
) => Promise<StravaOAuthTokenResponse>;

type DisconnectAccessTokenSelection = {
  accessToken: string;
  refreshedTokenRow?: StravaTokenRow;
};

type SignedStatePayload = {
  userId: string;
  nonce: string;
  exp: number;
};

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

function getBearerToken(authorizationHeader: string | null): string | null {
  if (!authorizationHeader) return null;
  if (!authorizationHeader.startsWith("Bearer ")) return null;
  const token = authorizationHeader.slice("Bearer ".length).trim();
  return token.length === 0 ? null : token;
}

async function resolveUserId(authorizationHeader: string | null) {
  const jwt = getBearerToken(authorizationHeader);
  if (!jwt) return null;

  const supabasePublic = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SB_PUBLISHABLE_KEY"),
  );
  const { data: claimsData, error: claimsError } = await supabasePublic.auth
    .getClaims(jwt);
  const userId = claimsData?.claims?.sub;
  if (
    !userId ||
    claimsError ||
    typeof userId !== "string" ||
    userId.length === 0
  ) {
    console.error("getClaims failed:", claimsError);
    return null;
  }

  return userId;
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

function epochSecondsNow() {
  return Math.floor(Date.now() / 1000);
}

function base64UrlEncode(bytes: Uint8Array): string {
  const binary = String.fromCharCode(...bytes);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function base64UrlDecode(value: string): Uint8Array {
  const padded = value + "=".repeat((4 - (value.length % 4)) % 4);
  const normalized = padded.replaceAll("-", "+").replaceAll("_", "/");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

async function hmacSha256(
  secret: string,
  message: string,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return new Uint8Array(signature);
}

function timingSafeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) {
    mismatch |= left[index] ^ right[index];
  }
  return mismatch === 0;
}

async function signState(payload: SignedStatePayload): Promise<string> {
  const secret = requireEnv("STRAVA_STATE_SECRET");
  const payloadBytes = new TextEncoder().encode(JSON.stringify(payload));
  const encodedPayload = base64UrlEncode(payloadBytes);
  const signatureBytes = await hmacSha256(secret, encodedPayload);
  return `${encodedPayload}.${base64UrlEncode(signatureBytes)}`;
}

async function verifyState(state: string): Promise<SignedStatePayload | null> {
  const [encodedPayload, encodedSignature, ...rest] = state.split(".");
  if (
    rest.length > 0 ||
    !encodedPayload ||
    !encodedSignature ||
    encodedPayload.length === 0 ||
    encodedSignature.length === 0
  ) {
    return null;
  }

  const expectedSignature = await hmacSha256(
    requireEnv("STRAVA_STATE_SECRET"),
    encodedPayload,
  );
  const actualSignature = base64UrlDecode(encodedSignature);
  if (!timingSafeEqual(expectedSignature, actualSignature)) {
    return null;
  }

  const payloadText = new TextDecoder().decode(base64UrlDecode(encodedPayload));
  const payloadMap = parseJsonObject(JSON.parse(payloadText));
  const userId = payloadMap.userId;
  const nonce = payloadMap.nonce;
  const exp = payloadMap.exp;
  if (
    typeof userId !== "string" ||
    userId.length === 0 ||
    typeof nonce !== "string" ||
    nonce.length === 0 ||
    typeof exp !== "number"
  ) {
    return null;
  }

  if (exp < epochSecondsNow()) return null;
  return { userId, nonce, exp };
}

// FIX C: atomically consume a previously issued state nonce. Deleting the row
// (scoped to the signed userId) and requiring exactly one affected row makes the
// state single-use: a replayed callback finds no matching row and is rejected.
async function consumeStateNonce(
  adminClient: any,
  userId: string,
  nonce: string,
): Promise<boolean> {
  const { data, error } = await adminClient
    .from("strava_oauth_states")
    .delete()
    .eq("nonce", nonce)
    .eq("user_id", userId)
    .select("nonce");
  return interpretNonceConsumption(data, error);
}

// Pure interpretation of the conditional delete result: a state nonce is
// successfully consumed only when exactly one matching row was deleted. A
// replayed callback (already consumed) or expired/cleaned-up nonce deletes
// zero rows and is rejected.
function interpretNonceConsumption(
  data: unknown,
  error: unknown,
): boolean {
  if (error) {
    console.error("Failed to consume Strava OAuth state nonce:", error);
    return false;
  }
  return Array.isArray(data) && data.length === 1;
}

function buildDeepLink(params: Record<string, string>) {
  const query = new URLSearchParams(params).toString();
  return `striviq://login-callback?${query}`;
}

function redirectToApp(params: Record<string, string>): Response {
  return Response.redirect(buildDeepLink(params), 302);
}

function toIsoFromEpochSeconds(seconds: number): string {
  return new Date(seconds * 1000).toISOString();
}

function tokenIsExpired(expiresAtIso: string): boolean {
  const expiresAt = Date.parse(expiresAtIso);
  if (Number.isNaN(expiresAt)) return true;
  return expiresAt <= Date.now();
}

function parseStravaTokenRow(raw: unknown): StravaTokenRow | null {
  const row = parseJsonObject(raw);
  const accessToken = row.access_token;
  const refreshToken = row.refresh_token;
  const expiresAt = row.expires_at;
  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    typeof refreshToken !== "string" ||
    refreshToken.length === 0 ||
    typeof expiresAt !== "string" ||
    expiresAt.length === 0
  ) {
    return null;
  }

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_at: expiresAt,
  };
}

async function selectDisconnectAccessToken(
  tokenRow: StravaTokenRow,
  refresh: RefreshAccessTokenFn = refreshAccessToken,
): Promise<DisconnectAccessTokenSelection> {
  if (!tokenIsExpired(tokenRow.expires_at)) {
    return { accessToken: tokenRow.access_token };
  }

  const refreshed = await refresh(tokenRow.refresh_token);
  const nextAccessToken = refreshed.access_token;
  const nextRefreshToken = refreshed.refresh_token;
  const nextExpiresAt = refreshed.expires_at;
  if (
    typeof nextAccessToken !== "string" || nextAccessToken.length === 0 ||
    typeof nextRefreshToken !== "string" ||
    nextRefreshToken.length === 0 ||
    typeof nextExpiresAt !== "number"
  ) {
    throw new Error("Invalid Strava refresh payload");
  }

  return {
    accessToken: nextAccessToken,
    refreshedTokenRow: {
      access_token: nextAccessToken,
      refresh_token: nextRefreshToken,
      expires_at: toIsoFromEpochSeconds(nextExpiresAt),
    },
  };
}

async function exchangeCodeForToken(code: string) {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: requireEnv("STRAVA_CLIENT_ID"),
      client_secret: requireEnv("STRAVA_CLIENT_SECRET"),
      grant_type: "authorization_code",
      code,
    }),
  });

  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(
      `Strava token exchange failed: ${response.status} ${bodyText}`,
    );
  }

  return parseJsonObject(JSON.parse(bodyText)) as StravaOAuthTokenResponse;
}

async function refreshAccessToken(refreshToken: string) {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: requireEnv("STRAVA_CLIENT_ID"),
      client_secret: requireEnv("STRAVA_CLIENT_SECRET"),
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });

  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(`Strava refresh failed: ${response.status} ${bodyText}`);
  }

  return parseJsonObject(JSON.parse(bodyText)) as StravaOAuthTokenResponse;
}

async function deauthorizeAtStrava(accessToken: string) {
  const response = await fetch(STRAVA_DEAUTHORIZE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ access_token: accessToken }),
  });

  if (response.ok || response.status === 401) return;

  const text = await response.text();
  throw new Error(`Strava deauthorize failed: ${response.status} ${text}`);
}

async function handleStart(adminClient: any, userId: string) {
  const nonce = crypto.randomUUID();
  const expSeconds = epochSecondsNow() + STATE_TTL_SECONDS;

  // FIX C: persist the nonce so it can be consumed exactly once on callback.
  // The HMAC signature still authenticates the state; the table makes it
  // single-use and non-replayable within the TTL window.
  const { error: insertError } = await adminClient
    .from("strava_oauth_states")
    .insert({
      nonce,
      user_id: userId,
      expires_at: toIsoFromEpochSeconds(expSeconds),
    });
  if (insertError) {
    console.error("Failed to persist Strava OAuth state nonce:", insertError);
    return jsonResponse({ error: "Failed to start Strava authorization" }, 500);
  }

  const state = await signState({
    userId,
    nonce,
    exp: expSeconds,
  });

  return jsonResponse({
    state,
    scope: OAUTH_REQUIRED_SCOPES.join(","),
  });
}

async function handleRefresh(
  adminClient: any,
  userId: string,
) {
  const { data, error } = await adminClient
    .from("strava_tokens")
    .select("access_token, refresh_token, expires_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.error("Failed to read strava token for refresh:", error);
    return jsonResponse({ error: "Failed to read Strava token" }, 500);
  }
  if (!data) {
    return jsonResponse({ error: "Strava not connected" }, 404);
  }

  const tokenRow = data as StravaTokenRow;
  if (!tokenIsExpired(tokenRow.expires_at)) {
    return jsonResponse({ refreshed: false, expiresAt: tokenRow.expires_at });
  }

  try {
    const refreshed = await refreshAccessToken(tokenRow.refresh_token);
    const nextAccessToken = refreshed.access_token;
    const nextRefreshToken = refreshed.refresh_token;
    const nextExpiresAt = refreshed.expires_at;

    if (
      typeof nextAccessToken !== "string" || nextAccessToken.length === 0 ||
      typeof nextRefreshToken !== "string" ||
      nextRefreshToken.length === 0 ||
      typeof nextExpiresAt !== "number"
    ) {
      return jsonResponse({ error: "Invalid Strava refresh payload" }, 502);
    }

    const { error: updateError } = await adminClient
      .from("strava_tokens")
      .update({
        access_token: nextAccessToken,
        refresh_token: nextRefreshToken,
        expires_at: toIsoFromEpochSeconds(nextExpiresAt),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);
    if (updateError) {
      console.error(
        "Failed to update strava token after refresh:",
        updateError,
      );
      return jsonResponse({ error: "Failed to persist refreshed token" }, 500);
    }

    return jsonResponse({
      refreshed: true,
      expiresAt: toIsoFromEpochSeconds(nextExpiresAt),
    });
  } catch (error) {
    console.error("Strava refresh action failed:", error);
    return jsonResponse({ error: "Strava refresh failed" }, 502);
  }
}

async function handleDisconnect(
  adminClient: any,
  userId: string,
) {
  const { data, error } = await adminClient
    .from("strava_tokens")
    .select("access_token, refresh_token, expires_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.error("Failed to read strava token for disconnect:", error);
    return jsonResponse({ error: "Failed to read Strava token" }, 500);
  }
  if (!data) {
    return jsonResponse({ success: true });
  }

  const tokenRow = parseStravaTokenRow(data);
  if (!tokenRow) {
    console.error("Invalid strava token row for disconnect");
    return jsonResponse({ error: "Invalid Strava token row" }, 500);
  }

  try {
    const selection = await selectDisconnectAccessToken(tokenRow);
    if (selection.refreshedTokenRow) {
      const { error: updateError } = await adminClient
        .from("strava_tokens")
        .update({
          access_token: selection.refreshedTokenRow.access_token,
          refresh_token: selection.refreshedTokenRow.refresh_token,
          expires_at: selection.refreshedTokenRow.expires_at,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);
      if (updateError) {
        console.error(
          "Failed to persist refreshed token before disconnect:",
          updateError,
        );
        return jsonResponse(
          { error: "Failed to persist refreshed token" },
          500,
        );
      }
    }

    await deauthorizeAtStrava(selection.accessToken);
  } catch (error) {
    console.error("Strava deauthorize failed:", error);
    return jsonResponse({ error: "Failed to deauthorize at Strava" }, 502);
  }

  const { error: deleteError } = await adminClient
    .from("strava_tokens")
    .delete()
    .eq("user_id", userId);
  if (deleteError) {
    console.error("Failed to delete strava token row:", deleteError);
    return jsonResponse({ error: "Failed to disconnect Strava" }, 500);
  }

  return jsonResponse({ success: true });
}

async function handleOAuthCallback(requestUrl: URL): Promise<Response> {
  const deniedError = requestUrl.searchParams.get("error");
  if (deniedError === "access_denied") {
    return redirectToApp({
      strava_status: "denied",
      strava_error: deniedError,
    });
  }

  const code = requestUrl.searchParams.get("code");
  const state = requestUrl.searchParams.get("state");
  if (!code || !state) {
    return redirectToApp({
      strava_status: "error",
      strava_error: "missing_code_or_state",
    });
  }

  const statePayload = await verifyState(state).catch((error) => {
    console.error("Failed to parse Strava OAuth state:", error);
    return null;
  });
  if (!statePayload) {
    return redirectToApp({
      strava_status: "invalid_state",
      strava_error: "state_verification_failed",
    });
  }

  const adminClient = createAdminClient();

  // FIX C: a signed state is only valid the first time it is presented. If the
  // nonce was already consumed (replay) or has expired/been cleaned up, reject.
  const nonceConsumed = await consumeStateNonce(
    adminClient,
    statePayload.userId,
    statePayload.nonce,
  );
  if (!nonceConsumed) {
    return redirectToApp({
      strava_status: "invalid_state",
      strava_error: "state_already_used",
    });
  }

  let tokenPayload: StravaOAuthTokenResponse;
  try {
    tokenPayload = await exchangeCodeForToken(code);
  } catch (error) {
    console.error("Strava code exchange failed:", error);
    return redirectToApp({
      strava_status: "error",
      strava_error: "token_exchange_failed",
    });
  }

  const accessToken = tokenPayload.access_token;
  const refreshToken = tokenPayload.refresh_token;
  const expiresAtSeconds = tokenPayload.expires_at;
  const scopeText = tokenPayload.scope;
  const athleteId = tokenPayload.athlete?.id;
  if (
    typeof accessToken !== "string" || accessToken.length === 0 ||
    typeof refreshToken !== "string" || refreshToken.length === 0 ||
    typeof expiresAtSeconds !== "number" ||
    typeof scopeText !== "string" ||
    scopeText.length === 0 ||
    typeof athleteId !== "number"
  ) {
    return redirectToApp({
      strava_status: "error",
      strava_error: "invalid_token_payload",
    });
  }

  if (!hasRequiredScopes(scopeText, OAUTH_REQUIRED_SCOPES)) {
    return redirectToApp({
      strava_status: "missing_scope",
      strava_error: "required_scope_not_granted",
      strava_detail: scopeText,
    });
  }

  const { error: upsertError } = await adminClient
    .from("strava_tokens")
    .upsert({
      user_id: statePayload.userId,
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_at: toIsoFromEpochSeconds(expiresAtSeconds),
      athlete_id: athleteId,
      scope: scopeText,
      updated_at: new Date().toISOString(),
    });
  if (upsertError) {
    console.error("Failed to store strava token row:", upsertError);
    return redirectToApp({
      strava_status: "error",
      strava_error: "token_store_failed",
    });
  }

  return redirectToApp({ strava_status: "success" });
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    const requestUrl = new URL(req.url);

    if (req.method === "GET") {
      return await handleOAuthCallback(requestUrl);
    }

    if (req.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }

    const userId = await resolveUserId(req.headers.get("Authorization"));
    if (!userId) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const payload = parseJsonObject(body);
    const action = typeof payload.action === "string"
      ? payload.action
      : "start";

    const adminClient = createAdminClient();

    switch (action) {
      case "start":
        return await handleStart(adminClient, userId);
      case "refresh":
        return await handleRefresh(adminClient, userId);
      case "disconnect":
        return await handleDisconnect(adminClient, userId);
      default:
        return jsonResponse({ error: "Unsupported action" }, 400);
    }
  } catch (error) {
    console.error("Unhandled strava-oauth error:", error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
}

// Only bind the server when executed as the entrypoint (Supabase runtime).
// Importing this module from tests must not start a listener.
if (import.meta.main) {
  Deno.serve(handleRequest);
}

export {
  interpretNonceConsumption,
  selectDisconnectAccessToken,
  signState,
  verifyState,
};
