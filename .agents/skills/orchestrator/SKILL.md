---
name: orchestrator
description: >
  Use when the user asks to implement or investigate work "with orchestration",
  "with sub agents", "using specialists", "use the orchestrator", "don't stop
  until reviewer approves", or mentions explorer, researcher, coder, scribe, or
  reviewer agents. Coordinates scoped sub-agents for RunFlow work while the main
  Codex agent owns integration, verification, commits, and deployment decisions.
---

# Orchestrator

Run a disciplined sub-agent workflow for complex implementation, debugging, or
review tasks in this repository.

## Triggered Behavior

When this skill triggers:

1. Restate the current task and the orchestration goal in one short update.
2. Decide the smallest useful agent set for the task.
3. Use sub-agents only for concrete, bounded work.
4. Keep one main Codex agent responsible for integration, final verification,
   commits, and deployment decisions.
5. Do not stop after the first pass when the user requested reviewer approval.
   Fix reviewer findings, re-run verification, and re-review until there are no
   blocking findings or a real blocker exists.

## Default Workflow

Use this sequence unless the task is small enough for fewer roles:

1. **Explorer**: read-only codebase inspection.
2. **Researcher**: current docs/API verification only when an external library,
   SDK, API, CLI, or cloud service is involved.
3. **Coder**: one scoped implementation task with a clear file ownership set.
4. **Reviewer**: correctness, regression, test adequacy, security, and
   deployment-risk review.
5. **Main Codex**: integrate, resolve findings, run tests, commit, and deploy
   only when needed or explicitly requested.

For full role guidance, read `references/roles.md`.

## Rules

- Use one coder per task.
- Give every coder an explicit write scope.
- Tell coders they are not alone in the codebase and must not revert unrelated
  or user-made changes.
- Avoid overlapping write scopes across active coders.
- Prefer explorers for read-only questions and reviewers for independent checks.
- Do not delegate the immediate critical-path task if the main agent can do it
  faster and the sub-agent would block progress.
- Do meaningful non-overlapping local work while sub-agents run.
- Keep commits task-sized.
- Deploy only when the task changes deployed backend code or the user asks for a
  deployment.
- Never commit or deploy if verification has known blocking failures, unless the
  user explicitly instructs otherwise after being told the risk.

## Commit And Deploy Policy

When the user asks for orchestration and implementation:

1. Run relevant tests/checks.
2. Run reviewer pass.
3. Fix blocking findings.
4. Commit the task after verification passes.
5. If backend Edge Functions changed and the user has asked to fix the live
   issue, deploy the affected function after commit.

## References

- `references/roles.md`: role prompts and ownership rules.
- `references/workflow.md`: step-by-step orchestration templates.
- `references/review-checklist.md`: reviewer/security checklist.
