import { createClient } from "@supabase/supabase-js";
import { buildAppleClientSecret } from "../_shared/apple-jwt.ts";

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

async function revokeAppleRefreshToken(
  refreshToken: string,
): Promise<Response | null> {
  const clientSecret = await buildAppleClientSecret();
  const revokeRes = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      token: refreshToken,
      token_type_hint: "refresh_token",
      client_id: requireEnv("APPLE_BUNDLE_ID"),
      client_secret: clientSecret,
    }),
  });

  if (revokeRes.ok) {
    return null;
  }

  const detail = await revokeRes.text();
  console.error("Apple revoke failed:", detail);
  return jsonResponse(
    { error: "Apple token revocation failed" },
    502,
  );
}

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  // Use SB_PUBLISHABLE_KEY + getClaims() for asymmetric ES256 JWT verification.
  // verify_jwt = false in config.toml disables the platform-level check so we
  // handle auth here instead.
  const supabasePublic = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SB_PUBLISHABLE_KEY"),
  );

  const jwt = authHeader.replace("Bearer ", "");
  const { data: claimsData, error: claimsError } = await supabasePublic.auth
    .getClaims(jwt);
  const userId = claimsData?.claims?.sub;
  if (!userId || claimsError) {
    console.error("getClaims failed:", claimsError);
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // Service-role client — bypasses RLS for reads/writes and admin operations
  const adminClient = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );

  // 1. Look up Apple refresh token if the user signed in with Apple
  const { data: appleTokenRow, error: tokenError } = await adminClient
    .from("apple_tokens")
    .select("refresh_token")
    .eq("user_id", userId)
    .maybeSingle();

  if (tokenError) {
    console.error("Failed to query apple_tokens:", tokenError);
    return jsonResponse(
      { error: "Failed to verify Apple token state" },
      500,
    );
  }

  // 2. Revoke Apple token if present. If this fails, preserve the account and
  // stored refresh token so account deletion can be retried.
  if (appleTokenRow?.refresh_token) {
    try {
      const revokeError = await revokeAppleRefreshToken(
        appleTokenRow.refresh_token,
      );
      if (revokeError) return revokeError;
    } catch (err) {
      console.error("Apple revoke exception:", err);
      return jsonResponse(
        { error: "Apple token revocation failed" },
        502,
      );
    }
  }

  // 3. Delete the Supabase user — cascades all related tables
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    userId,
  );
  if (deleteError) {
    console.error("Failed to delete user:", deleteError);
    return jsonResponse(
      { error: "Failed to delete user", detail: deleteError.message },
      500,
    );
  }

  return jsonResponse({ success: true });
});
