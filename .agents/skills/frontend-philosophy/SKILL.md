---
name: frontend-philosophy
description: >
  Apply RunFlow-specific UI and interaction conventions for Flutter screens and
  widgets when editing user-facing code.
---

# Frontend Philosophy

Guidelines for this repo:

- Keep UI consistent with existing `core/theme` tokens.
- Preserve dark-theme as source design unless user explicitly requests otherwise.
- Use existing reusable widgets before creating new ones.
- For localized text, use `AppLocalizations` at render boundaries.
- Respect existing navigation and state patterns used in feature-first screen layout.
- Keep spacing/typography conservative and readable; avoid introducing new ad-hoc palettes.
