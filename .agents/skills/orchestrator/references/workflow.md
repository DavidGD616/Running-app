# Orchestration Workflow

## Implementation Template

1. Inspect the repo state with `git status --short`.
2. Spawn explorer for read-only context when file ownership is unclear.
3. Spawn researcher only when current external docs are required.
4. Assign one coder to one bounded task and file ownership set.
5. While coder runs, inspect non-overlapping context or prepare verification.
6. Review coder diff locally.
7. Run focused tests.
8. Spawn reviewer for correctness/security/regression review.
9. Fix reviewer findings.
10. Re-run tests and re-review if findings were blocking.
11. Commit the completed task.
12. Deploy only when appropriate.

## Debugging Template

1. Identify the failing boundary: frontend payload, backend validation, external
   API, database write, or client rendering.
2. Use explorer to map files/tests/log signatures.
3. Explain the cause before editing if the user asks for investigation only.
4. For implementation, assign the smallest backend/frontend fix to one coder.
5. Add regression coverage for the observed failure.
6. Run the narrow test, then the relevant broader suite.
7. Review and commit.
8. Deploy backend fixes when the live service needs them.

## Review-Only Template

1. Spawn reviewer or inspect locally.
2. Lead with findings ordered by severity.
3. Include file/line references.
4. Include open questions and residual risk.
5. Do not implement unless the user then asks.

## Stop Conditions

Stop and ask the user only when:
- credentials/access are missing
- a destructive command is required
- product behavior is ambiguous and a reasonable assumption is risky
- the same external blocker repeats across three attempts
