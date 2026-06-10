---
name: code-review
description: >
  Run concise, evidence-first code review for changed files. Report findings-first
  with severity and concrete file/line references.
---

# Code Review

Output format:

1. **Findings** (ordered high → low)
   - `file:line` when inferable
   - severity: blocking / high / medium / low
   - what breaks or regresses
   - minimal fix intent
2. **Open Questions** (if any uncertainty)
3. **Residual Risk** (explicit)

Rules:

- Read-only review role.
- No implementation in this pass.
- If no blocking findings: state **No blocking findings** and list residual risk.
- Include verification expectations tied to modified surface.
