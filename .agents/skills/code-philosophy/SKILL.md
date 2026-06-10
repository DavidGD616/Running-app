---
name: code-philosophy
description: >
  Use for bounded, production-minded implementation in this repository.
  Keep changes minimal, local, and test-guided.
---

# Code Philosophy

Principles for implementation agents:

- Prefer minimal diffs and narrow scopes.
- Follow existing folder boundaries and established style in this repository.
- Do not revert unrelated user-made changes.
- Avoid changing domain models in ways that leak translated strings; keep canonical values stable.
- Keep verification command choices aligned to modified surface.
- If uncertain, ask for scope confirmation before large structural edits.

Execution defaults:

- Start from owning files and interfaces, then implement to that boundary.
- Reuse existing helpers/components before introducing new abstractions.
- Preserve localizations from `l10n/` and do not hand-edit generated localization files.
- Prefer additive changes; avoid breaking callers unless explicitly requested.
