# Orchestration Workflow

## Implementation Template

1. Inspect the repo state with `git status --short`.
2. Spawn explorer for read-only context when file ownership is unclear.
3. Spawn researcher only when current external docs are required.
4. Select exactly one current task/chunk and assign one coder to that bounded file ownership set. The first non-empty line in the coder prompt must be `Codex-Orchestrator-Internal-Subagent: coder`, followed by a stable `Task ID: ...`.
5. While coder runs, inspect non-overlapping context or prepare verification.
6. Run verification after the coder pass and before reviewer sign-off.
7. Run focused tests.
8. Spawn reviewer for correctness/security/regression review **after verification**.
9. If reviewer findings are blocking, summarize the blockers and assign a new coder remediation pass for the same `Task ID`. Main Codex must not edit code itself.
10. Re-run tests and re-review after the remediation coder completes.
11. Repeat remediation coder -> verify -> re-review until no blocking findings remain.
12. If any reviewer output in an implementation turn omits `Overall Assessment: APPROVE`, `Overall Assessment: REQUEST_CHANGES`, or
    `Overall Assessment: NEEDS_DISCUSSION`, treat the review as blocking until
    corrected.
13. Commit the completed task only after reviewer approval and passing relevant
    verification.
14. Update the plan/status notes when the task is tracked in a plan document.
15. Deploy only when appropriate.

## Debugging Template

1. Identify the failing boundary: frontend payload, backend validation, external
   API, database write, or client rendering.
2. Use explorer to map files/tests/log signatures.
3. Explain the cause before editing if the user asks for investigation only.
4. For implementation, assign the smallest backend/frontend fix to one coder with a leading sentinel line (`Codex-Orchestrator-Internal-Subagent: ...`) and a `Task ID`.
5. Add regression coverage for the observed failure.
6. Run the narrow test, then the relevant broader suite.
7. Review; if blocked, send remediation to a new coder rather than editing directly.
8. Commit after reviewer approval.
9. Deploy backend fixes when the live service needs them.

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
