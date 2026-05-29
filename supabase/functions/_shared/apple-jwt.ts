import { decodeBase64, encodeBase64 } from "jsr:@std/encoding/base64";

function base64UrlEncode(text: string): string {
  return encodeBase64(text)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(b64).buffer;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

/**
 * Builds an Apple client-secret JWT (ES256) used to authenticate
 * server-to-server requests with Apple’s IDMS.
 *
 * Required environment variables:
 *   APPLE_TEAM_ID     – 10-character Apple Team ID
 *   APPLE_KEY_ID      – the Key ID from the .p8 file
 *   APPLE_BUNDLE_ID   – App Bundle ID / Service ID
 *   APPLE_PRIVATE_KEY – full PEM contents of the .p8 file
 */
export async function buildAppleClientSecret(): Promise<string> {
  const teamId = requireEnv("APPLE_TEAM_ID");
  const keyId = requireEnv("APPLE_KEY_ID");
  const bundleId = requireEnv("APPLE_BUNDLE_ID");
  const privateKeyPem = requireEnv("APPLE_PRIVATE_KEY");

  const now = Math.floor(Date.now() / 1000);
  const exp = now + 15777000; // ~6 months (Apple max)

  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = {
    iss: teamId,
    iat: now,
    exp,
    aud: "https://appleid.apple.com",
    sub: bundleId,
  };

  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;

  const keyData = pemToArrayBuffer(privateKeyPem);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const signatureB64 = encodeBase64(new Uint8Array(signature))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  return `${signingInput}.${signatureB64}`;
}
