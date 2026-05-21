# 2026-05-18 — README architecture figure

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md)
- **Related ADRs:** none
- **Related commits / PRs:** none
- **Worked on by:** Codex

## What happened

Added the selected white-background `ggai` architecture infographic to the repository and surfaced it near the top of `README.md`. The figure was placed under `man/figures/` so it follows the same package-level asset convention already used by the README's quick-start artwork.

## Findings / decisions

- The clearest generated candidate was the white-background version, not the earlier dark blueprint-style render.
- The most natural README placement is between the high-level workflow summary and Quick Start, where it can orient readers before setup details.
- This was a docs-only change, so no `CHANGELOG.md` entry was needed.

## Verification

- `test -f man/figures/ggai-architecture-overview.png`
- `rg -n "ggai-architecture-overview" README.md`

## Next

If the README is refreshed again soon, the next useful pass is to reconcile its older session-oriented prose with the newer agentic architecture now documented in the image.
