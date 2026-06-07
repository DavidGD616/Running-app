# Review Checklist

Use this checklist for reviewer agents and final local review.

## Correctness

- Does the change directly address the reported issue or requested feature?
- Are contracts aligned across producer, validator, persistence, and client?
- Are optional/null/missing values handled consistently?
- Are edge cases covered without weakening required fields?

## Security And Privacy

- No secrets, tokens, auth headers, or private activity data are logged.
- User-owned data remains scoped to the authenticated user.
- Backend validation rejects malformed or unsafe input.
- External API calls use required environment variables and fail safely.

## Regression Risk

- Existing mock/seed/local flows still work.
- Spanish and English UI boundaries are respected when UI text changes.
- Backend changes are compatible with current Flutter model parsing.
- Migrations/deployments are needed only when schema/storage changes require it.

## Tests

- Add a regression test for the observed failure.
- Preserve stricter validation for invalid values.
- Run the narrow affected test first.
- Run the broader relevant suite before commit.

## Deployment

- Supabase Edge Function code changes require deployment to affect production.
- Frontend-only mobile changes do not require Supabase deploy.
- Confirm project ref before deploying.
- Report deployed function name and project ref.
