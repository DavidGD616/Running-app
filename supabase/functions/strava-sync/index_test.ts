import { strict as assert } from "node:assert";
import {
  mapSyncError,
  normalizeActivity,
  StravaReauthRequiredError,
} from "./index.ts";

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

Deno.test(
  "normalizeActivity enriches safe optional fields and excludes privacy-sensitive fields",
  () => {
    const normalized = normalizeActivity({
      distance: 5000,
      moving_time: 1500,
      average_speed: 3.33,
      average_heartrate: 150,
      start_date: "2026-05-24T12:00:00Z",
      type: "Run",
      sport_type: "Run",
      id: 1_234_567_890_123,
      elapsed_time: "1560",
      max_speed: 4.2,
      max_heartrate: "188",
      total_elevation_gain: "120.5",
      workout_type: "3",
      suffer_score: 74,
      name: "Morning run",
      description: "Secret notes",
      map: { summary_polyline: "abc", id: "map-1" },
      start_latlng: [37.7, -122.4],
      end_latlng: [37.8, -122.3],
      location_city: "Denver",
      route: { id: "route-1" },
      gear: { id: "gear-1" },
      photos: { count: 2 },
    });

    assert.equal(normalized.id, "1234567890123");
    assert.equal(normalized.elapsed_time, 1560);
    assert.equal(normalized.max_speed, 4.2);
    assert.equal(normalized.max_heartrate, 188);
    assert.equal(normalized.total_elevation_gain, 120.5);
    assert.equal(normalized.workout_type, 3);
    assert.equal(normalized.suffer_score, 74);

    assert.equal(normalized.name === undefined, true);
    assert.equal(normalized.description === undefined, true);
    assert.equal(normalized.map === undefined, true);
    assert.equal(normalized.start_latlng === undefined, true);
    assert.equal(normalized.end_latlng === undefined, true);
    assert.equal(normalized.location_city === undefined, true);
    assert.equal(normalized.route === undefined, true);
    assert.equal(normalized.gear === undefined, true);
    assert.equal(normalized.photos === undefined, true);
  },
);

Deno.test("normalizeActivity tolerates missing optional fields", () => {
  const normalized = normalizeActivity({
    distance: 5000,
    moving_time: 1500,
    average_speed: 3.33,
    average_heartrate: 150,
    start_date: "2026-05-24T12:00:00Z",
    type: "Run",
    sport_type: "Run",
  });

  assert.equal(normalized.elapsed_time === undefined, true);
  assert.equal(normalized.max_speed === undefined, true);
  assert.equal(normalized.max_heartrate === undefined, true);
  assert.equal(normalized.total_elevation_gain === undefined, true);
  assert.equal(normalized.workout_type === undefined, true);
  assert.equal(normalized.suffer_score === undefined, true);
});

Deno.test(
  "normalizeActivity preserves numeric string IDs above MAX_SAFE_INTEGER",
  () => {
    const normalized = normalizeActivity({
      distance: 5000,
      moving_time: 1500,
      average_speed: 3.33,
      average_heartrate: 150,
      start_date: "2026-05-24T12:00:00Z",
      type: "Run",
      sport_type: "Run",
      id: "9007199254740993",
    });

    assert.equal(normalized.id, "9007199254740993");
  },
);

Deno.test("normalizeActivity drops unsafe numeric IDs", () => {
  const normalized = normalizeActivity({
    distance: 5000,
    moving_time: 1500,
    average_speed: 3.33,
    average_heartrate: 150,
    start_date: "2026-05-24T12:00:00Z",
    type: "Run",
    sport_type: "Run",
    id: 9007199254740992,
  });

  assert.equal(normalized.id, undefined);
});

Deno.test(
  "normalizeActivity drops invalid optional numeric fields conservatively",
  () => {
    const normalized = normalizeActivity({
      distance: 5000,
      moving_time: 1500,
      average_speed: 3.33,
      average_heartrate: 150,
      start_date: "2026-05-24T12:00:00Z",
      type: "Run",
      sport_type: "Run",
      elapsed_time: -1,
      max_speed: -4.4,
      max_heartrate: 0,
      total_elevation_gain: -120.5,
      workout_type: -3,
      suffer_score: -74,
    });

    assert.equal(normalized.elapsed_time === undefined, true);
    assert.equal(normalized.max_speed === undefined, true);
    assert.equal(normalized.max_heartrate === undefined, true);
    assert.equal(normalized.total_elevation_gain === undefined, true);
    assert.equal(normalized.workout_type === undefined, true);
    assert.equal(normalized.suffer_score === undefined, true);
  },
);
