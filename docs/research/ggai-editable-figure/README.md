# ggai Editable Figure Research

This folder records the ongoing redesign research for `ggai` editable scientific figures.

The current direction is:

- do not integrate `AutoFigure-Edit` as an external service dependency
- do not mirror `AutoFigure-Edit` API contracts into `ggai`
- borrow its pipeline ideas where useful
- redesign the system around `ggai`'s own compiler-first, sidecar-first, and session-first architecture

## Folder Contract

This folder is designed for parallel sessions and long-horizon accumulation.

- Stable documents hold the latest synthesized understanding.
- Session documents hold per-session exploration notes.
- New sessions should create new files instead of rewriting older session logs.
- Cross-session conclusions should be merged back into the stable documents.
- Prefer additive updates over destructive rewrites.

## File Map

- `00-context-and-scope.md`
  - problem framing, current scope, explicit non-goals
- `01-current-findings.md`
  - accumulated findings from repository exploration
- `02-target-architecture.md`
  - current preferred architecture and module boundaries
- `03-open-questions.md`
  - unresolved questions and decision pressure points
- `04-exploration-backlog.md`
  - future investigation streams, split for parallel sessions
- `05-migration-matrix.md`
  - what can be migrated from `AutoFigure-Edit`, what should not be migrated directly, and what still needs validation
- `06-native-object-model.md`
  - recommended `ggai-native` object family for editable figures, including alternatives considered and current preferred field boundaries
- `sessions/README.md`
  - rules for adding session-specific notes
- `sessions/2026-04-10-main-rollout.md`
  - record of the current exploration session

## Update Rules

When continuing this research:

1. add a new file under `sessions/`
2. record raw exploration there first
3. update `01-current-findings.md` only after a point is reasonably stable
4. update `02-target-architecture.md` only when a direction is preferred, not merely possible
5. update `03-open-questions.md` and `04-exploration-backlog.md` whenever scope changes

## Current Working Thesis

`ggai` should grow a native editable-figure pipeline:

- `intent_compile`
- `draft_generate`
- `region_infer`
- `asset_extract`
- `svg_template_generate`
- `svg_assemble`
- `figure_session`

This should use direct model APIs and local components where needed, but the object model, sidecars, and editing semantics should be owned by `ggai`.
