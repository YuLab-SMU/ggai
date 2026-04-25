# Migration Matrix

This document answers a narrow question:

What from `AutoFigure-Edit` can be migrated into `ggai`, what should not be migrated directly, and what still needs validation?

The key rule is:

- migrate architectural principles
- do not blindly migrate runtime packaging or API contracts

## Summary

### Direct Answer

Not everything worth learning from `AutoFigure-Edit` should be moved into `ggai`.

The safe migration target is:

- ideas
- stage decomposition
- artifact discipline
- editable-output goals

The unsafe migration target is:

- service contracts
- job orchestration shape
- web-first runtime assumptions
- implementation-coupled details that would distort `ggai`'s own architecture

## Matrix

| Source area | Can migrate? | How to treat it in `ggai` | Notes |
|---|---|---|---|
| Staged pipeline mindset | Yes | Rebuild as native `ggai` pipeline stages | This is one of the strongest transferable ideas |
| Intent -> draft -> regions -> SVG -> final assembly flow | Yes, with redesign | Preserve the sequence, but redefine each stage with `ggai` objects | Do not preserve AutoFigure names mechanically |
| Intermediate artifact discipline | Yes | Keep sidecars and manifests as first-class outputs | Strong fit with `ggai` inspectability |
| Editable SVG as a first-class deliverable | Yes | Make `ggai_editable_figure` a durable artifact type | Strong strategic fit |
| Region inference step | Yes, conceptually | Add a native `region_map` stage | Exact implementation still open |
| Asset extraction / cleanup | Yes | Add as a native helper stage | Should use `ggai` sidecar conventions |
| Template SVG generation | Yes | Rebuild with `ggai` prompt/model contracts | Validation rules need native design |
| Assembly of extracted assets into template | Yes | Keep as a native assembly stage | Preserve semantic IDs where possible |
| Multi-candidate generation and scoring | Partly | Reuse where it helps draft generation | `ggai` already does this for direct-image figures |
| FastAPI service boundary | No | Do not adopt as a primary `ggai` contract | Wrong center of gravity for `ggai` |
| `/api/run` style job submission contract | No | Do not mirror into `ggai` | Makes an external runtime define the core contract |
| SSE events / job polling model | No, not as core design | Only relevant if a future consumer needs async orchestration | Belongs outside core `ggai` design |
| Uploaded-file web workflow | No | Ignore for now | Product/UI concern, not core compiler concern |
| Embedded SVG editor packaging | No, not yet | Defer until `ggai` owns a stable editable figure object | UI should follow object model, not lead it |
| Python-heavy service packaging | No | Do not import wholesale | Violates `ggai`'s ecological role |
| Specific AutoFigure API argument shape | No | Redesign from `ggai`'s own functions outward | Avoid compatibility trap |
| Prompt engineering lessons | Yes, selectively | Extract into native figure-planning prompts | Needs curation, not copy-paste |
| Placeholder / label alignment strategy | Yes, selectively | Reinterpret as native semantic anchor design | Worth studying carefully |
| Service-oriented artifact URLs | No | Replace with local sidecar references | `ggai` should own its own artifact paths |

## What Should Be Actively Reused

### 1. Stage Decomposition

The biggest reusable asset is the realization that editable scientific figure generation should not be a one-shot prompt.

`ggai` should retain a multi-stage design such as:

- `intent_compile`
- `draft_generate`
- `region_infer`
- `asset_extract`
- `svg_template_generate`
- `svg_assemble`
- `figure_session`

### 2. Artifact Discipline

Every important stage should leave inspectable artifacts.

Recommended native `ggai` sidecars:

- `figure_plan.json`
- `draft_manifest.json`
- `region_map.json`
- `asset_manifest.json`
- `template.svg`
- `template_meta.json`
- `final.svg`
- `preview.png`
- `session_history.json`

### 3. Editable Output Goal

The final output should not just be an image.

It should be:

- a durable editable artifact
- a previewable output
- a session-ready object for future patching and regeneration

## What Should Be Rejected

### 1. External API As Source Of Truth

`ggai` should not define editable figures as “whatever an AutoFigure-like service returns”.

Reason:

- it would make `ggai` downstream of a foreign runtime contract
- it would weaken `ggai`'s compiler-first identity
- it would make future editing semantics harder to unify

### 2. Web-Service-Centered Thinking

`ggai` is not primarily a web app.

Its core design should stay centered on:

- compiler objects
- local sidecars
- reproducible generation contracts
- session history

### 3. Direct Runtime Shape Copying

Even if some `AutoFigure-Edit` runtime interfaces are clean, they should not be copied directly.

Reason:

- the packaging reflects that project's product boundary
- the `ggai` boundary is different
- copied runtime shape would create long-term architectural drag

## What Still Needs Validation

### 1. Region Map Design

Open question:

- what exact schema should a `ggai_region_map` use?

Need to validate:

- semantic anchors
- coordinates
- confidence
- provenance
- editability metadata

### 2. SVG Template Strategy

Open question:

- should `template.svg` be mostly model-generated or mostly schema-generated?

Need to validate:

- controllability
- failure modes
- repairability
- compatibility with later session edits

### 3. Figure Session Patch Layer

Open question:

- should edits patch the plan, the template, or the final SVG?

Need to validate:

- which layer produces the least destructive history
- which layer is easiest to inspect
- which layer is easiest to regenerate deterministically

### 4. Provider Layer Split

Open question:

- should `ggai` expose separate helper interfaces for text planning, image generation, segmentation, and multimodal SVG generation?

Current leaning:

- yes

But this needs more explicit contract design work.

## Current Recommendation

The recommended migration policy is:

1. extract the architectural ideas
2. re-express them as native `ggai` objects and stages
3. preserve inspectable sidecars
4. reject direct API and runtime-shape copying
5. validate uncertain areas through targeted parallel exploration

## Cross References

- [README.md](/Users/xiayh/Projects/ggai/docs/research/ggai-editable-figure/README.md)
- [01-current-findings.md](/Users/xiayh/Projects/ggai/docs/research/ggai-editable-figure/01-current-findings.md)
- [02-target-architecture.md](/Users/xiayh/Projects/ggai/docs/research/ggai-editable-figure/02-target-architecture.md)
- [03-open-questions.md](/Users/xiayh/Projects/ggai/docs/research/ggai-editable-figure/03-open-questions.md)
- [04-exploration-backlog.md](/Users/xiayh/Projects/ggai/docs/research/ggai-editable-figure/04-exploration-backlog.md)
