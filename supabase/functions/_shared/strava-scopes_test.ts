import { strict as assert } from "node:assert";
import { hasRequiredScopes, parseStravaScopes } from "./strava-scopes.ts";

Deno.test("parseStravaScopes parses comma-delimited scopes", () => {
  const scopes = parseStravaScopes("read,activity:read_all,profile:read_all");
  assert.equal(scopes.has("read"), true);
  assert.equal(scopes.has("activity:read_all"), true);
  assert.equal(scopes.has("profile:read_all"), true);
  assert.equal(scopes.size, 3);
});

Deno.test("parseStravaScopes parses mixed comma and whitespace delimiters", () => {
  const scopes = parseStravaScopes(
    " read, activity:read_all\nprofile:read_all\t,read ",
  );
  assert.equal(scopes.has("read"), true);
  assert.equal(scopes.has("activity:read_all"), true);
  assert.equal(scopes.has("profile:read_all"), true);
  assert.equal(scopes.size, 3);
});

Deno.test("hasRequiredScopes returns false when any required scope missing", () => {
  const hasAllRequiredScopes = hasRequiredScopes("read,activity:read_all", [
    "read",
    "activity:read_all",
    "profile:read_all",
  ]);
  assert.equal(hasAllRequiredScopes, false);
});
