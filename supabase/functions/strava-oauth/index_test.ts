import { strict as assert } from "node:assert";

Deno.env.set("STRAVA_STATE_SECRET", "test-state-secret-value");

const { interpretNonceConsumption, signState, verifyState } = await import(
  "./index.ts"
);

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
