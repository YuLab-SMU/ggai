# Exploration Backlog

This backlog is organized so parallel sessions can work independently.

## Stream A: ggai Native Object Model

Goal:

- define the minimal stable objects for editable figure work

Tasks:

- compare current `ggai_compiled_spec` and session objects with proposed figure objects
- sketch `ggai_figure_plan` schema
- sketch `ggai_editable_figure` schema
- decide which sidecars are mandatory versus optional

Suggested session file prefix:

- `sessions/*-stream-a-*.md`

## Stream B: Direct Model API Design

Goal:

- design a provider-agnostic figure runtime without depending on `AutoFigure-Edit` APIs

Tasks:

- separate text planning, image generation, multimodal SVG generation, and optional segmentation calls
- identify which provider capabilities are required at each stage
- define fallback behavior when one provider lacks a capability

Suggested session file prefix:

- `sessions/*-stream-b-*.md`

## Stream C: Region And Asset Inference

Goal:

- define how draft images become editable regions and reusable assets

Tasks:

- compare segmentation-first versus layout-first approaches
- identify what must be deterministic
- identify what can remain heuristic
- define a first `region_map.json` candidate schema

Suggested session file prefix:

- `sessions/*-stream-c-*.md`

## Stream D: SVG Template Strategy

Goal:

- choose how `template.svg` should be generated and validated

Tasks:

- compare pure LLM SVG generation versus scaffold-plus-fill approaches
- define template validation rules
- define semantic ID requirements for later editing

Suggested session file prefix:

- `sessions/*-stream-d-*.md`

## Stream E: Figure Session Semantics

Goal:

- define how editable figure revisions should work in `ggai`

Tasks:

- compare plan-patch, template-patch, and final-svg-patch approaches
- define session history rules
- define export and preview semantics

Suggested session file prefix:

- `sessions/*-stream-e-*.md`

## Stream F: Future DeepScientist Consumption

Goal:

- define the thinnest useful integration contract after `ggai` owns the core design

Tasks:

- identify which `ggai` functions DeepScientist would need
- identify which durable artifacts matter
- avoid letting DeepScientist-specific routing leak back into `ggai`

Suggested session file prefix:

- `sessions/*-stream-f-*.md`

## Immediate Next Investigations

- derive an initial R API sketch from the native object model
- map current `generate_final_figure()` to the proposed new staged pipeline
- decide whether region inference is a first-class `ggai` stage or an optional helper
- draft a first candidate schema for `ggai_region_map`
