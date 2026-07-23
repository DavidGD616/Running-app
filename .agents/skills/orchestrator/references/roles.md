# Orchestrator Roles

Use only the roles needed for the current task.

## Explorer

Use for read-only codebase questions.

Ask for:
- exact files and line references
- current behavior
- related tests
- local verification commands
- likely ownership boundaries

Do not ask explorers to edit files.

## Researcher

Use when the task depends on current external documentation for a library, SDK,
API, CLI, or cloud service.

Rules:
- Prefer Context7 MCP for library/framework/API/cloud-service docs.
- Use official docs only when browsing is needed.
- Return the smallest useful set of facts, links, and version-sensitive notes.
- Do not turn research into implementation unless explicitly assigned.

## Coder

Use for one bounded implementation task.

Agent lifecycle:
- Spawn a brand-new coder for every plan chunk and every remediation pass.
- Run only one coder at a time.
- Never reuse a coder with `followup_task` for another chunk or remediation.
- Use one canonical task ID matching `[a-z0-9]+(?:_[a-z0-9]+)*` for the chunk.
- Name the initial task `coder__<task-id>` so encrypted prompts remain hook-detectable.
- Give a remediation agent only a final `__<lower_snake_case_nonce>` suffix, for example `coder__edit_goal_form__remediation_1`. Keep the prompt's single `Task ID: edit_goal_form` unchanged.

Model:
- Use `gpt-5.3-codex-spark` for coder agents unless the user explicitly asks
  for a different coder model.

Coder prompt must include:
- exact sentinel line first (first non-empty line): `Codex-Orchestrator-Internal-Subagent: <role>` where role is the subagent role (for example `reviewer` or `coder`)
- repository path
- branch/context if relevant
- exactly one `Task ID: <task-id>` line for the one plan chunk, using its canonical task ID unchanged
- exact owned files or module boundary
- expected behavior
- tests to add or update
- verification commands to run
- instruction that they are not alone in the codebase
- instruction not to revert unrelated or user-made changes

Keep write scopes disjoint across unrelated coders. Remediation coders for a blocking review must use the blocker's `Task ID:` and may edit only within the bounded reviewed scope.

## Reviewer

Use after implementation and before final/commit when risk is non-trivial.
Reviewer prompts must start with the sentinel line `Codex-Orchestrator-Internal-Subagent: <role>` before task instructions.
Include exactly one `Task ID: <task-id>` line using the chunk's canonical task ID unchanged.

Agent lifecycle:
- Spawn a brand-new reviewer for every chunk and every re-review.
- Never reuse a reviewer agent.
- Use the chunk's canonical task ID matching `[a-z0-9]+(?:_[a-z0-9]+)*`.
- Name the initial task `reviewer__<task-id>` so encrypted prompts remain hook-detectable.
- Give a re-reviewer only a final `__<lower_snake_case_nonce>` suffix, for example `reviewer__edit_goal_form__rereview_1`. Keep the prompt's single `Task ID: edit_goal_form` unchanged.

Ask reviewers to check:
- correctness against the user request
- regression risk
- security/privacy risk
- schema/API contract consistency
- test adequacy
- deployment risk
- downstream compatibility

Require findings first, with file/line references.
Require a machine-readable overall verdict in the final paragraph using exactly one of:
- `Overall Assessment: APPROVE`
- `Overall Assessment: REQUEST_CHANGES`
- `Overall Assessment: NEEDS_DISCUSSION`
If no findings, this still requires `Overall Assessment: APPROVE` and residual risk.

Approve and commit each chunk independently. Never treat a plan-wide aggregate review or commit as a replacement for a chunk's reviewer approval and task-sized commit.

## Scribe

Use only when the task requires docs/spec/plan updates.

Ask for:
- exact doc file paths
- concise changelog or decision-log entries
- no implementation changes unless explicitly assigned
