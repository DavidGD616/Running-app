import { strict as assert } from "node:assert";
import { mapSyncError, StravaReauthRequiredError } from "./index.ts";

Deno.test("mapSyncError maps a revoked grant to a distinct reconnect signal", () => {
  const mapped = mapSyncError(
    new StravaReauthRequiredError("Strava returned 401 after token refresh"),
  );

  assert.equal(mapped.status, 409, "reconnect-required uses a distinct status");
  assert.equal(mapped.body.code, "strava_reconnect_required");
  assert.equal(typeof mapped.body.error, "string");
  // The client-facing body must not leak upstream Strava detail.
  assert.equal(
    JSON.stringify(mapped.body).includes("401"),
    false,
    "client body must not reflect the raw upstream message",
  );
});

Deno.test("mapSyncError returns a generic 502 for other failures", () => {
  const mapped = mapSyncError(
    new Error(
      "Failed to fetch Strava activities (status=500, body=upstream boom)",
    ),
  );

  assert.equal(mapped.status, 502);
  assert.deepEqual(mapped.body, { error: "Strava sync failed" });
  // FIX D: no raw Strava body or status reflected to the client.
  const serialized = JSON.stringify(mapped.body);
  assert.equal(serialized.includes("upstream boom"), false);
  assert.equal(serialized.includes("500"), false);
});

Deno.test("mapSyncError still logs full detail server-side", () => {
  const mapped = mapSyncError(new Error("boom"));
  assert.ok(
    mapped.logMessage.length > 0,
    "a server-side log message is always provided",
  );
});
