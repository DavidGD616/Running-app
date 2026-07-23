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
- Spawn a brand-new coder for every plan chunk. Never reuse a coder with `followup_task` for another chunk.
- Coder must use model: `gpt-5.3-codex-spark`.
- Spawn a brand-new reviewer for every chunk and every re-review. Never reuse a reviewer agent.
- Main Codex coordinates build work; it must not edit code or apply reviewer fixes itself during orchestrator-triggered implementation turns (policy rule).
- Assign every chunk one canonical task ID matching `[a-z0-9]+(?:_[a-z0-9]+)*` (lowercase snake case).
- Include exactly one `Task ID: <task-id>` line in each coder and reviewer prompt, using that canonical value unchanged.
- Name collaboration tasks `coder__<task-id>` and `reviewer__<task-id>` with the same canonical value so encrypted prompts remain hook-detectable. Only a fresh remediation or re-review agent may append a final `__<lower_snake_case_nonce>` suffix; the suffix distinguishes the agent and never changes the prompt's `Task ID:`.
- Assign every blocking review remediation pass to a brand-new coder with the blocker's `Task ID:` and bounded reviewed scope.
- Complete each chunk independently: fresh coder -> verification -> fresh reviewer -> approval/remediation loop -> task-sized commit. Start the next chunk only after that commit succeeds.
- Do not substitute a plan-wide aggregate review or commit for any per-chunk gate.
- Where hook evidence is present, the local gate tracks best-effort main-agent file-edit activity during an open coder pass and will block stop if detected.
- Absence of hook evidence does not prove no edits occurred; always treat this as a policy/investigation risk, not a hook-enforced guarantee.

## Triggered Flow

1. Acknowledge the objective and define scope in one short update.
2. Run roles sequentially unless scope demands extra exploration:
   - `explorer` (read-only) for baseline ownership/behavior and risks.
   - `researcher` only when external library/API/CLI/cloud docs are needed.
   - a fresh `coder` for exactly one bounded file set.
   - `verification` before reviewer.
   - a fresh `reviewer` after verification.
3. Main Codex evaluates diff and reviewer output, but sends all code changes and blocker remediation to coder subagents.
4. Commit the approved chunk before selecting the next chunk.
5. Continue until every chunk independently meets the completion gates.

## Evidence-First Completion Gates

Before final answer on implementation turns, require:

1. Orchestration trigger detected.
2. A fresh coder subagent recorded for each chunk and remediation pass.
3. Required verification command(s) passed after the chunk's final coder edits.
4. A fresh reviewer completed after verification for each review and re-review.
5. If review blocked, a fresh remediation coder completed after the blocking review using the same `Task ID:` and bounded scope.
6. Reviewer approval recorded for the chunk after final verification.
7. A task-sized commit recorded for the approved chunk when files changed and commit was not declined.
8. Every chunk completed these gates before the next chunk started.

If gates are unmet, continue the orchestration loop rather than finalizing.

In the final handoff, list every chunk with its coder identity, verification evidence, reviewer verdict, and commit hash.

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
