import { strict as assert } from "node:assert";
import {
  mapNormalizedActivitiesToSummaryRows,
  mapNormalizedActivityToSummaryRow,
  mapSyncError,
  normalizeActivity,
  persistStravaActivitySummaries,
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

Deno.test(
  "mapNormalizedActivityToSummaryRow maps expected fields and keeps normalized_data privacy-safe",
  () => {
    const row = mapNormalizedActivityToSummaryRow(
      "user-1",
      {
        id: "9007199254740993",
        start_date: "2026-05-24T12:00:00Z",
        distance: "5000.5",
        moving_time: "1500",
        elapsed_time: 1560,
        average_speed: 3.33,
        max_speed: "4.2",
        average_heartrate: "150.5",
        max_heartrate: 188,
        total_elevation_gain: "120.5",
        workout_type: "3",
        suffer_score: 74,
        type: " Run ",
        sport_type: "TrailRun",
        name: "Morning run",
        description: "Secret notes",
        map: { summary_polyline: "abc", id: "map-1" },
        start_latlng: [37.7, -122.4],
        end_latlng: [37.8, -122.3],
        location_city: "Denver",
        location_state: "Colorado",
        location_country: "United States",
        route: { id: "route-1" },
        gear: { id: "gear-1" },
        photos: { count: 2 },
        streams: { latlng: [[37.7, -122.4]] },
        access_token: "secret",
        refresh_token: "secret",
        raw: { id: "raw-payload" },
      },
      "2026-06-08T18:00:00.000Z",
    );

    if (row === null) throw new Error("expected a persistence row");

    assert.equal(row.user_id, "user-1");
    assert.equal(row.strava_activity_id, "9007199254740993");
    assert.equal(row.recorded_at, "2026-05-24T12:00:00.000Z");
    assert.equal(row.activity_type, "Run");
    assert.equal(row.sport_type, "TrailRun");
    assert.equal(row.distance_meters, 5000.5);
    assert.equal(row.moving_time_seconds, 1500);
    assert.equal(row.elapsed_time_seconds, 1560);
    assert.equal(row.average_speed_mps, 3.33);
    assert.equal(row.max_speed_mps, 4.2);
    assert.equal(row.average_heartrate_bpm, 150.5);
    assert.equal(row.max_heartrate_bpm, 188);
    assert.equal(row.elevation_gain_meters, 120.5);
    assert.equal(row.workout_type, 3);
    assert.equal(row.suffer_score, 74);
    assert.equal(row.synced_at, "2026-06-08T18:00:00.000Z");

    assert.deepEqual(row.normalized_data, {
      id: "9007199254740993",
      start_date: "2026-05-24T12:00:00.000Z",
      distance: 5000.5,
      moving_time: 1500,
      average_speed: 3.33,
      average_heartrate: 150.5,
      type: "Run",
      sport_type: "TrailRun",
      elapsed_time: 1560,
      max_speed: 4.2,
      max_heartrate: 188,
      total_elevation_gain: 120.5,
      workout_type: 3,
      suffer_score: 74,
    });

    const serialized = JSON.stringify(row.normalized_data);
    for (
      const sensitiveKey of [
        "name",
        "description",
        "map",
        "polyline",
        "latlng",
        "location",
        "route",
        "gear",
        "photos",
        "streams",
        "token",
        "raw",
      ]
    ) {
      assert.equal(
        serialized.includes(sensitiveKey),
        false,
        `${sensitiveKey} must not be persisted in normalized_data`,
      );
    }
  },
);

Deno.test("mapNormalizedActivitiesToSummaryRows skips invalid id or start_date", () => {
  const rows = mapNormalizedActivitiesToSummaryRows(
    "user-1",
    [
      {
        id: "123",
        start_date: "2026-05-24T12:00:00Z",
        distance: 5000,
      },
      {
        id: "",
        start_date: "2026-05-24T12:00:00Z",
        distance: 5000,
      },
      {
        id: "456",
        start_date: "not-a-date",
        distance: 5000,
      },
      {
        start_date: "2026-05-24T12:00:00Z",
        distance: 5000,
      },
      {
        id: "789",
        distance: 5000,
      },
    ],
    "2026-06-08T18:00:00.000Z",
  );

  assert.equal(rows.length, 1);
  assert.equal(rows[0].strava_activity_id, "123");
});

Deno.test("persistStravaActivitySummaries upserts with composite conflict target", async () => {
  const captured: {
    table?: string;
    rows?: Array<Record<string, unknown>>;
    options?: Record<string, unknown>;
  } = {};
  const fakeClient = {
    from(table: string) {
      captured.table = table;
      return {
        async upsert(
          rows: Array<Record<string, unknown>>,
          options: Record<string, unknown>,
        ) {
          captured.rows = rows;
          captured.options = options;
          return { error: null };
        },
      };
    },
  };

  await persistStravaActivitySummaries(
    fakeClient,
    "user-1",
    [
      {
        id: "123",
        start_date: "2026-05-24T12:00:00Z",
        distance: 5000,
      },
      {
        id: "bad id",
        start_date: "2026-05-24T12:00:00Z",
        distance: 5000,
      },
    ],
    "2026-06-08T18:00:00.000Z",
  );

  assert.equal(captured.table, "strava_activity_summaries");
  assert.equal(captured.options?.onConflict, "user_id,strava_activity_id");
  assert.equal(captured.rows?.length, 1);
  assert.equal(captured.rows?.[0].strava_activity_id, "123");
});
