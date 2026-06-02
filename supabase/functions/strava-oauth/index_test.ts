import { strict as assert } from "node:assert";

Deno.env.set("STRAVA_STATE_SECRET", "test-state-secret-value");

const {
  interpretNonceConsumption,
  selectDisconnectAccessToken,
  signState,
  verifyState,
} = await import("./index.ts");

Deno.test("interpretNonceConsumption: exactly one deleted row means consumed", () => {
  assert.equal(interpretNonceConsumption([{ nonce: "abc" }], null), true);
});

Deno.test("interpretNonceConsumption: zero rows (replay/expired) is rejected", () => {
  assert.equal(interpretNonceConsumption([], null), false);
});

Deno.test("interpretNonceConsumption: a delete error is rejected", () => {
  assert.equal(
    interpretNonceConsumption(null, { message: "db down" }),
    false,
  );
});

Deno.test("signState/verifyState round-trips a valid signed state", async () => {
  const payload = {
    userId: "11111111-1111-1111-1111-111111111111",
    nonce: crypto.randomUUID(),
    exp: Math.floor(Date.now() / 1000) + 600,
  };
  const state = await signState(payload);
  const verified = await verifyState(state);
  assert.ok(verified, "valid state should verify");
  assert.equal(verified!.userId, payload.userId);
  assert.equal(verified!.nonce, payload.nonce);
});

Deno.test("verifyState rejects a tampered signature", async () => {
  const state = await signState({
    userId: "11111111-1111-1111-1111-111111111111",
    nonce: crypto.randomUUID(),
    exp: Math.floor(Date.now() / 1000) + 600,
  });
  const [encodedPayload] = state.split(".");
  const tampered = `${encodedPayload}.AAAA`;
  assert.equal(await verifyState(tampered), null);
});

Deno.test("verifyState rejects an expired state", async () => {
  const state = await signState({
    userId: "11111111-1111-1111-1111-111111111111",
    nonce: crypto.randomUUID(),
    exp: Math.floor(Date.now() / 1000) - 1,
  });
  assert.equal(await verifyState(state), null);
});

Deno.test("selectDisconnectAccessToken: uses current access token before expiry", async () => {
  let refreshCalled = false;
  const accessToken = await selectDisconnectAccessToken(
    {
      access_token: "current-access-token",
      refresh_token: "stored-refresh-token",
      expires_at: new Date(Date.now() + 60_000).toISOString(),
    },
    async () => {
      refreshCalled = true;
      return { access_token: "fresh-access-token" };
    },
  );

  assert.equal(accessToken.accessToken, "current-access-token");
  assert.equal(accessToken.refreshedTokenRow, undefined);
  assert.equal(refreshCalled, false);
});

Deno.test("selectDisconnectAccessToken: refreshes expired access token", async () => {
  let refreshTokenSeen = "";
  const expiresAtSeconds = Math.floor(Date.now() / 1000) + 3600;
  const accessToken = await selectDisconnectAccessToken(
    {
      access_token: "expired-access-token",
      refresh_token: "stored-refresh-token",
      expires_at: new Date(Date.now() - 60_000).toISOString(),
    },
    async (refreshToken: string) => {
      refreshTokenSeen = refreshToken;
      return {
        access_token: "fresh-access-token",
        refresh_token: "fresh-refresh-token",
        expires_at: expiresAtSeconds,
      };
    },
  );

  assert.equal(refreshTokenSeen, "stored-refresh-token");
  assert.equal(accessToken.accessToken, "fresh-access-token");
  assert.deepEqual(accessToken.refreshedTokenRow, {
    access_token: "fresh-access-token",
    refresh_token: "fresh-refresh-token",
    expires_at: new Date(expiresAtSeconds * 1000).toISOString(),
  });
});

Deno.test("selectDisconnectAccessToken: rejects invalid refresh payload", async () => {
  await assert.rejects(
    () =>
      selectDisconnectAccessToken(
        {
          access_token: "expired-access-token",
          refresh_token: "stored-refresh-token",
          expires_at: new Date(Date.now() - 60_000).toISOString(),
        },
        async () => ({ refresh_token: "fresh-refresh-token" }),
      ),
    /Invalid Strava refresh payload/,
  );
});

Deno.test("selectDisconnectAccessToken: requires rotated refresh metadata", async () => {
  await assert.rejects(
    () =>
      selectDisconnectAccessToken(
        {
          access_token: "expired-access-token",
          refresh_token: "stored-refresh-token",
          expires_at: new Date(Date.now() - 60_000).toISOString(),
        },
        async () => ({
          access_token: "fresh-access-token",
          expires_at: Math.floor(Date.now() / 1000) + 3600,
        }),
      ),
    /Invalid Strava refresh payload/,
  );
});
