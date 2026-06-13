---
name: orchestrator
description: >
  Use when the user asks to implement or investigate work "with orchestration",
  "with sub agents", "using specialists", "don't stop until reviewer approves",
  or mentions explorer, researcher, coder, reviewer, or scribe. Orchestrator
  mode requires a mandatory coder→verification→reviewer loop and completion evidence.
---

# Orchestrator

When triggered, run the full orchestration workflow.

## Non-negotiables

- Use at least one subagent for implementation-turn work unless the user explicitly disables automation.
- Do not self-delegate to the main agent for orchestrator-triggered implementation.
- Use one implementation coder subagent at a time.
- Coder must use model: `gpt-5.3-codex-spark`.
- Reviewer is mandatory before completion.
- Blocking review findings require a fix->verify->re-review loop.
- Commit is required after verification success when files changed and the user did not decline commit.

## Triggered Flow

1. Acknowledge the objective and define scope in one short update.
2. Run roles sequentially unless scope demands extra exploration:
   - `explorer` (read-only) for baseline ownership/behavior and risks.
   - `researcher` only when external library/API/CLI/cloud docs are needed.
   - `coder` for exactly one bounded file set.
   - `reviewer` immediately after coder output.
3. Main Codex evaluates diff, applies residual fixes, reruns verification, and re-calls reviewer when findings are blocking.
4. Continue until non-blocking completion criteria are met.

## Evidence-First Completion Gates

Before final answer on implementation turns, require:

1. Orchestration trigger detected.
2. Coder subagent activity recorded.
3. Reviewer completed on the coder work.
4. Required verification command(s) run after final edits.
5. Reviewer re-check passed after final verification (or explicit no blockers).
6. Task-sized commit made when files changed and commit requested.

If gates are unmet, continue the orchestration loop rather than finalizing.

## Roles

- **Explorer**: read-only discovery: files, tests, behavior, risk spots.
- **Researcher**: docs-backed confirmation for framework/SDK/CLI/cloud references (no edits).
- **Coder**: one bounded implementation pass; writes code in the assigned scope only.
- **Reviewer**: findings-first report, with severity ordering and blocking classification.
- **Scribe**: summary/docs-only outputs if user asks for documentation updates.

If a finding is blocking, the task remains open for correction and re-review.

## References

- `references/roles.md`: role prompts and ownership rules.
- `references/workflow.md`: step-by-step orchestration templates.
- `references/review-checklist.md`: reviewer/security checklist.
