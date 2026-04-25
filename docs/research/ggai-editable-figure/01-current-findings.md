# Current Findings

## Repository Findings

### ggai

`ggai` is currently a compiler-first `R` package focused on:

- natural-language to `ggplot2` layers
- natural-language to diagram scene specs
- natural-language to generated glyph assets
- direct-image figure prompt compilation and candidate selection

Relevant evidence:

- `DESCRIPTION` describes compiler-first tools for reproducible layers, diagram scene specs, and generated glyph assets.
- `R/figure_generation.R` shows the current figure path is still prompt-bundle driven plus candidate scoring.
- `R/session_edit.R` shows `ggai` already has a stateful edit-session pattern for compiled outputs.
- `R/ai_bridge.R` shows model resolution already flows through the local `aisdk` bridge and registry pattern.

### AutoFigure-Edit

`AutoFigure-Edit` is useful as a reference design, not as a target runtime contract.

Strong ideas worth borrowing:

- staged pipeline instead of one-step prompting
- explicit intermediate artifacts
- region inference between draft image and vector template
- editable SVG as a first-class output

Useful caution:

- its current implementation is centered around Python/FastAPI/job APIs and a web-oriented runtime boundary
- that boundary is not a natural fit for `ggai`'s own source-of-truth architecture

### DeepScientist

`DeepScientist` is relevant as a future consumer and orchestration layer, but it should not drive the redesign.

Useful findings:

- it has mature skill discovery and projection machinery
- its stage router is centered on stage skills
- its documentation already treats AutoFigure-Edit as a refinement-oriented figure capability

Implication:

- future integration should likely happen after `ggai` exposes a stable editable-figure contract

## Architectural Findings

### What Should Not Happen

- `ggai` should not absorb `AutoFigure-Edit` as a direct service dependency
- `ggai` should not mirror `AutoFigure-Edit` job and artifact APIs as its own primary contract
- `ggai` should not jump directly from current `chat_edit()` semantics to SVG DOM editing without an intermediate shared object model

### What Should Happen

`ggai` should define its own native pipeline with its own owned objects:

- `ggai_figure_plan`
- `ggai_figure_draft`
- `ggai_region_map`
- `ggai_svg_template`
- `ggai_editable_figure`
- `ggai_figure_session`

## Key Design Insight

The right abstraction boundary is not:

- `ggai` -> external figure-edit service

The right abstraction boundary is:

- `ggai` compiler and artifact model
- direct model API adapters
- optional local helpers for segmentation, extraction, and SVG assembly

This preserves `ggai` as the system of record.

## Present Working Thesis

The new editable-figure stack should be:

1. compiler-first
2. artifact-first
3. session-ready
4. vector-native at the final stage
5. independent from `AutoFigure-Edit` API contracts

## Findings That Still Need Validation

- whether one unified editable figure IR can cover both direct-image figures and diagram-style figures
- how much of region inference should be model-driven versus deterministic geometry
- whether SVG template generation should be fully multimodal or partially schema-constrained
- whether figure sessions should patch SVG structure directly or patch a higher-level semantic scene and regenerate SVG
