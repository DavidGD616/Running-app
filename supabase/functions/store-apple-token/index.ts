import { createClient } from "@supabase/supabase-js";
import { buildAppleClientSecret } from "../_shared/apple-jwt.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

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
    requireEnv("SUPABASE_URL"),
    requireEnv("SB_PUBLISHABLE_KEY"),
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

  const body = await req.json().catch(() => ({}));
  const authorizationCode: string | undefined = body.authorizationCode;
  if (!authorizationCode) {
    return new Response(
      JSON.stringify({ error: "Missing authorizationCode" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // Build Apple client secret and exchange the authorization code
  let refreshToken: string;
  try {
    const clientSecret = await buildAppleClientSecret();
    const tokenRes = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code: authorizationCode,
        client_id: requireEnv("APPLE_BUNDLE_ID"),
        client_secret: clientSecret,
      }),
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      console.error("Apple token exchange failed:", errText);
      return new Response(
        JSON.stringify({ error: "Apple token exchange failed" }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const tokenData = await tokenRes.json();
    refreshToken = tokenData.refresh_token;
    if (!refreshToken) {
      return new Response(
        JSON.stringify({ error: "No refresh_token from Apple" }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
  } catch (err) {
    console.error("Apple token exchange exception:", err);
    return new Response(
      JSON.stringify({ error: "Apple token exchange exception" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Service-role client — bypasses RLS for writes
  const adminClient = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );

  const { error: upsertError } = await adminClient
    .from("apple_tokens")
    .upsert({
      user_id: userId,
      refresh_token: refreshToken,
      updated_at: new Date().toISOString(),
    });

  if (upsertError) {
    console.error("Failed to upsert apple_tokens:", upsertError);
    return new Response(
      JSON.stringify({ error: "Failed to store token", detail: upsertError.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
