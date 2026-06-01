const STRAVA_SCOPE_DELIMITER = /[\s,]+/u;

export const OAUTH_REQUIRED_SCOPES = [
  "read",
  "activity:read_all",
  "profile:read_all",
] as const;

// Sync only reads activities/profile data and does not require Strava's broad
// `read` scope. OAuth keeps `read` to preserve existing consent expectations.
export const SYNC_REQUIRED_SCOPES = [
  "activity:read_all",
  "profile:read_all",
] as const;

export function parseStravaScopes(scopeText: string): Set<string> {
  const normalizedScopeText = scopeText.trim();
  if (normalizedScopeText.length === 0) {
    return new Set<string>();
  }

  return new Set(
    normalizedScopeText
      .split(STRAVA_SCOPE_DELIMITER)
      .map((scope) => scope.trim())
      .filter((scope) => scope.length > 0),
  );
}

export function hasRequiredScopes(
  scopeText: string,
  requiredScopes: readonly string[],
): boolean {
  const grantedScopeSet = parseStravaScopes(scopeText);
  return requiredScopes.every((requiredScope) =>
    grantedScopeSet.has(requiredScope)
  );
}
