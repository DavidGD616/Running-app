# Codex Orchestrator Enforcement

This repo enables a local Codex orchestration gate for requests containing orchestration
keywords (`orchestrator`, `orchestration`, `subagents`, `coder`, `reviewer`, `explorer`,
`researcher`, `scribe`, and variants).

## Trust and Activation

1. Hooks are loaded from `.codex/hooks.json`.
2. On first run in this repo, trust the hooks when Codex prompts for hook approval.
3. After trust is granted, reload or restart Codex in that session so the repo `.codex` config is active; otherwise the project hooks are not loaded.
4. For persistent use in a new session, open a new thread after trust is accepted, or restart Codex, so project-level `.codex` config loads.

## What the enforcement checks

During an orchestrator turn with implementation intent, completion is blocked until:

- A coder/subagent run is observed.
- The coder prompt records one stable task/chunk id.
- Every coder pass records explicit start evidence (`start_snapshot_recorded`) for the start event, including clean-worktree starts where `start_snapshot_signature` may be an empty list.
- Every coder pass has start-task IDs recorded exactly once; stop Task IDs are audit-only and never used for start-side repair.
- A lone `SubagentStop` with no open coder start must remain an anomalous stop-only record and must not pass validation.
- A coder completion snapshot is recorded, and the final work snapshot matches that latest coder output.
- A reviewer subagent run is completed and passes a non-blocking pass.
- If reviewer blocks, a later coder remediation pass must start from the blocking reviewer snapshot, then complete before verification and re-review.
- Verification is recorded.
- Commit is recorded when files changed and commit was requested.

Behavior is now defined per prompt baseline:

- `UserPromptSubmit` stores `files_changed_signature_at_start` from
  `git_changed_file_signatures()` in addition to file paths.
- `Stop` compares the current signature set (`files_changed_signature_current`) against
  the baseline signature set, so content edits in already-dirty files are detected.
- `Stop` gates only when:
  - implementation intent is detected, **or**
  - the signature delta against baseline is non-empty, **or**
  - a commit command is recorded in `turn.commit.commands`.
- Read-only prompts like `do not edit`, `review only`, `no edits`, etc. no longer force coder/reviewer/verification/commit checks simply because the repo is already dirty.
- Verification success stores:
  - the command sequence number (`turn.verification.last_seq`)
  - the command timestamp (`turn.verification.at`)
  - the changed-file snapshot signatures (`turn.verification.snapshot_signature`)
- Commit success stores:
  - the command sequence number (`turn.commit.last_seq`)
  - the command timestamp (`turn.commit.at`)
  - the pre-commit changed-file snapshot signatures (`turn.commit.snapshot_signature`) from
    the `PreToolUse` `git commit` snapshot to prevent edit-after-verify bypass.
  - whether pre-tool capture succeeded (`turn.commit.snapshot_from_pre_tool`)
- `Stop` blocks if:
  - a coder task id was not recorded on every pass,
  - any pass starts without exactly one Task ID,
  - a pass is missing start-snapshot recording evidence (`start_snapshot_recorded`),
  - a pass is missing a start snapshot signature when recording was attempted incorrectly,
  - a stop without open start metadata is treated as anomalous,
  - a main agent file-edit event is detected while a coder pass is open (best-effort),
  - final work differs from the latest coder completion snapshot,
  - a blocking reviewer pass was not followed by a later coder remediation pass,
  - a remediation coder pass that is accepted after blocking review did not start from the blocking reviewer snapshot,
  - verification is missing, or
  - verifier snapshot differs from the current changed-file signature, or
  - reviewer approval is stale (`reviewer_last_snapshot_signature` no longer matches
    verification snapshot, or commit snapshot when commit is required), or
  - commit was required (changes beyond baseline + commit requested) but commit is missing,
    lacked pre-tool capture, was not after successful verification, or does not match verified snapshot.

`Stop` blocks completion with `{"decision":"block","reason":"..."}` when required
evidence is missing.

Smoke checks:

- **Smoke A**: clean/read-only prompt (`Review only with orchestrator. Do not edit files.`) with a dirty repo should return `{}`/no orchestrator block for coder/verification/commit.
- **Smoke B**: implementation prompt + coder + reviewer non-blocking + `python3 -m py_compile ...` verification should only block for missing commit when required.
- **Smoke C**: implementation prompt + coder + reviewer + commit before successful verification should fail for commit ordering (`commit after successful verification`).
- **Smoke D**: hook-only changes must appear in `git_changed_files` and therefore in baseline/delta snapshots; do not ignore `.codex/hooks/`.
- **Smoke E**: implementation prompt + coder + reviewer non-blocking + successful verification + modify file contents without changing the changed-file path set after verification; `Stop` should block as stale verification or stale reviewer snapshot.
- **Smoke F**: treat `Overall Assessment: REQUEST_CHANGES...` as blocking even when non-blocking phrases appear nearby, and treat `Overall Assessment: APPROVE. No blocking findings.` as blocking because only the exact `Overall Assessment: ...` paragraph is allowed in the final paragraph.
- **Smoke G**: treat `Overall Assessment: NEEDS_DISCUSSION` as blocking.
- **Smoke H**: implementation prompt + coder + blocking reviewer + no later coder should block for missing remediation coder; adding a later coder + verification + non-blocking reviewer should clear that specific blocker.
- **Smoke H2**: implementation prompt + blocking reviewer + a dummy remediation start + later completed remediation start from mutated tree should block remediation snapshot check.
- **Smoke I**: review-only prompt + successful commit command in an otherwise clean tree should still enforce full requirements (no bypass).
- **Smoke J**: classify review-only prompts with explicit change wording as non-implementation:
  - `orchestrator review this change` → not implementation-oriented.
  - `orchestrator change the button color` → implementation-oriented.
- Missing or ambiguous reviewer verdicts are considered blocking. Implementation turns require one of:
  - `Overall Assessment: APPROVE`
  - `Overall Assessment: REQUEST_CHANGES`
  - `Overall Assessment: NEEDS_DISCUSSION`

## What it does not guarantee

- The hook cannot prove full review depth or final human-level correctness.
- It tracks events and command evidence, not semantic code quality.
- It does not verify reviewer findings are fully resolved beyond recorded stop/pass state.
- The hook does not observe every file-edit path by default. It only infers main-agent file edits from
  paired `PreToolUse`/`PostToolUse` signatures on tools covered by `.codex/hooks.json`.
  If a file edit occurs in a tool path that does not emit both hooks, no file-edit evidence is produced and this gate cannot prove enforcement for that action.
  Main-agent edit detection also depends on `tool_may_edit_files()` heuristics; a covered command can still be missed if the heuristic flags it as non-mutating (for example `python3 script.py` or `node script.js`).

## Runtime state

Runtime files are stored in `.codex/.orchestrator-state/` and ignored via
`.codex/.orchestrator-state/.gitignore`.
