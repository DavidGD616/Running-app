# Orchestration Workflow

## Implementation Template

1. Inspect the repo state with `git status --short`.
2. Spawn explorer for read-only context when file ownership is unclear.
3. Spawn researcher only when current external docs are required.
4. Select exactly one current task/chunk and assign it one canonical task ID matching `[a-z0-9]+(?:_[a-z0-9]+)*`. Spawn a brand-new coder named `coder__<task-id>` for its bounded file ownership set; run only one coder at a time. Never reuse a coder with `followup_task`. The first non-empty prompt line must be `Codex-Orchestrator-Internal-Subagent: coder`; include exactly one `Task ID: <task-id>` line using the same canonical value.
5. While coder runs, inspect non-overlapping context or prepare verification.
6. Run verification after the coder pass and before reviewer sign-off.
7. Run focused tests.
8. Spawn a brand-new reviewer named `reviewer__<task-id>` for correctness/security/regression review **after verification**. Use the same canonical task ID in the prompt's single `Task ID:` line. Never reuse a reviewer agent.
9. If reviewer findings are blocking, summarize the blockers and spawn a brand-new remediation coder. Append only a final `__<lower_snake_case_nonce>` to the collaboration name, for example `coder__edit_goal_form__remediation_1`; keep the prompt's single `Task ID: edit_goal_form` unchanged and retain the bounded reviewed scope. Main Codex must not edit code itself.
10. Re-run tests, then spawn a brand-new re-reviewer named the same way, for example `reviewer__edit_goal_form__rereview_1`, with the unchanged prompt line `Task ID: edit_goal_form`.
11. Repeat fresh remediation coder -> verify -> fresh re-reviewer until no blocking findings remain.
12. If any reviewer output in an implementation turn omits `Overall Assessment: APPROVE`, `Overall Assessment: REQUEST_CHANGES`, or
    `Overall Assessment: NEEDS_DISCUSSION`, treat the review as blocking until
    corrected.
13. Commit the completed chunk only after reviewer approval and passing relevant verification.
14. Record the chunk, coder identity, verification evidence, reviewer verdict, and commit hash.
15. Start the next chunk only after the current chunk's task-sized commit succeeds.
16. Never use a plan-wide aggregate review or commit to replace per-chunk gates.
17. Update the plan/status notes when the task is tracked in a plan document.
18. Deploy only when appropriate.

## Debugging Template

1. Identify the failing boundary: frontend payload, backend validation, external
   API, database write, or client rendering.
2. Use explorer to map files/tests/log signatures.
3. Explain the cause before editing if the user asks for investigation only.
4. For implementation, assign the smallest backend/frontend fix to a fresh coder. Use a canonical task ID matching `[a-z0-9]+(?:_[a-z0-9]+)*`, a leading sentinel line (`Codex-Orchestrator-Internal-Subagent: coder`), and exactly one `Task ID: <task-id>` line with that same value.
5. Add regression coverage for the observed failure.
6. Run the narrow test, then the relevant broader suite.
7. Spawn a brand-new reviewer after verification; if blocked, spawn a brand-new uniquely named remediation coder with the same `Task ID:` and bounded scope.
8. Re-verify and spawn a brand-new re-reviewer after every remediation pass.
9. Commit the approved debugging chunk before starting another chunk.
10. Deploy backend fixes when the live service needs them.

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
