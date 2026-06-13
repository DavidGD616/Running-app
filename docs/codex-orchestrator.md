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
- A reviewer subagent run is completed and passes a non-blocking pass.
- Verification is recorded.
- Commit is recorded when files changed and commit was requested.

Behavior is now defined per prompt baseline:

- `UserPromptSubmit` stores `files_changed_signature_at_start` from
  `git_changed_file_signatures()` in addition to file paths.
- `Stop` compares the current signature set (`files_changed_signature_current`) against
  the baseline signature set, so content edits in already-dirty files are detected.
- `Stop` gates only when:
  - implementation intent is detected, **or**
  - the signature delta against baseline is non-empty.
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
- **Smoke F**: treat `Overall Assessment: REQUEST_CHANGES...` as blocking even when non-blocking phrases appear nearby, and treat `Overall Assessment: APPROVE. No blocking findings.` as non-blocking.

## What it does not guarantee

- The hook cannot prove full review depth or final human-level correctness.
- It tracks events and command evidence, not semantic code quality.
- It does not verify reviewer findings are fully resolved beyond recorded stop/pass state.

## Runtime state

Runtime files are stored in `.codex/.orchestrator-state/` and ignored via
`.codex/.orchestrator-state/.gitignore`.
