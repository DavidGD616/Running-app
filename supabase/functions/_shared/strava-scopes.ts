const STRAVA_SCOPE_DELIMITER = /[\s,]+/u;

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
