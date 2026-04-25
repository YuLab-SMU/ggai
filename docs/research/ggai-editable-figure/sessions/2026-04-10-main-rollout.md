# 2026-04-10 Main Rollout

## Goal

Explore how `ggai` should integrate ideas from `AutoFigure-Edit` using software engineering discipline, then decide whether integration should happen through:

- direct dependency on `AutoFigure-Edit`
- `DeepScientist` skill orchestration
- or a `ggai-native` redesign

## Files And Systems Explored

### ggai

- `DESCRIPTION`
- `R/compiler.R`
- `R/figure_generation.R`
- `R/ai_bridge.R`
- `R/spec_inspection.R`
- `R/session_edit.R`
- `R/spec_diagram.R`
- `R/bio_assets.R`

### DeepScientist

- `src/deepscientist/skills/registry.py`
- `src/deepscientist/skills/installer.py`
- `src/deepscientist/daemon/app.py`
- `src/deepscientist/prompts/builder.py`
- `src/skills/figure-polish/SKILL.md`
- `src/skills/write/SKILL.md`

### AutoFigure-Edit

- `README.md`
- `README_ZH.md`
- `docs/TECH_STACK.md`
- `server.py`
- `autofigure2.py`

## Main Findings

### Early Conclusion That Was Explored

An early plausible direction was:

- keep `AutoFigure-Edit` as a sidecar service
- let `DeepScientist` consume it as a companion skill
- let `ggai` only wrap the result

This direction was architecturally clean, but it was later rejected as the preferred path.

### Why The Sidecar-Service Idea Was Rejected

The user clarified the stronger target:

- do not integrate `AutoFigure-Edit` API
- connect to bottom-layer model APIs directly
- reuse `AutoFigure` ideas only as design inspiration

This shifts the center of gravity back to `ggai`.

### Updated Preferred Conclusion

The preferred direction became:

- `ggai` should own the editable-figure contract
- `ggai` should define native pipeline stages and sidecars
- `AutoFigure-Edit` should be treated as a research reference, not a runtime dependency
- `DeepScientist` should only integrate later, after `ggai` has a stable native figure contract

## Architectural Insight

The deepest mismatch is this:

- current `ggai` editing semantics are compiled-spec and rerender oriented
- `AutoFigure-Edit` editing semantics are SVG pipeline and artifact oriented

So the right move is not to force them together immediately.

The right move is to design a new intermediate family of `ggai` objects for editable figures.

## Candidate New ggai Objects

- `ggai_figure_plan`
- `ggai_figure_draft`
- `ggai_region_map`
- `ggai_svg_template`
- `ggai_editable_figure`
- `ggai_figure_session`

## Follow-Up Work Triggered By This Session

- create stable research docs
- preserve the rejected sidecar-service option as historical context
- document the new preferred direction explicitly
- define backlog streams that future parallel sessions can pick up independently
- define a native object model so later discussions stop renaming the same concepts

## Notes On Process

Parallel sub-sessions were useful for:

- repository structure reconnaissance
- `AutoFigure-Edit` capability and API boundary reading
- `DeepScientist` skill routing and integration reading

The stable lesson is that future parallel sessions should continue using separate session files and only merge resolved conclusions back into stable docs.

## Later Additions In The Same Day

After the migration-boundary question was clarified, the research docs were extended with:

- a migration matrix
- a native object model document

The object-model direction chosen here is:

- do not extend `ggai_compiled_spec` directly
- create a parallel family for editable figures
- keep `ggai_editable_figure` as the durable artifact
- keep `ggai_figure_session` as an opt-in editing wrapper
