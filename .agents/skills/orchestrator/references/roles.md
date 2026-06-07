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

Coder prompt must include:
- repository path
- branch/context if relevant
- exact owned files or module boundary
- expected behavior
- tests to add or update
- verification commands to run
- instruction that they are not alone in the codebase
- instruction not to revert unrelated or user-made changes

Keep write scopes disjoint across coders.

## Reviewer

Use after implementation and before final/commit when risk is non-trivial.

Ask reviewers to check:
- correctness against the user request
- regression risk
- security/privacy risk
- schema/API contract consistency
- test adequacy
- deployment risk
- downstream compatibility

Require findings first, with file/line references. If no findings, ask for a
clear "No findings" verdict and residual risk.

## Scribe

Use only when the task requires docs/spec/plan updates.

Ask for:
- exact doc file paths
- concise changelog or decision-log entries
- no implementation changes unless explicitly assigned
