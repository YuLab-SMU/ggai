# Native Object Model

This document defines the current preferred object model for `ggai-native` editable figures.

The purpose is not to lock implementation details too early.
The purpose is to prevent drift across parallel sessions by fixing:

- object names
- object responsibilities
- lifecycle boundaries
- minimum fields

## Requirements Summary

The object model must satisfy these constraints:

- compiler-first rather than editor-first
- inspectable at every important stage
- compatible with sidecar files
- session-ready for later iterative edits
- not dependent on `AutoFigure-Edit` runtime contracts
- compatible with future `DeepScientist` consumption, but not shaped by it

## Alternatives Considered

### Option A: Extend `ggai_compiled_spec`

Idea:

- represent editable figures as another `kind` under the current compiled-spec family

Benefits:

- reuses existing naming and inspection conventions
- may reduce API surface

Costs:

- `ggai_compiled_spec` currently fits layer and diagram semantics better than image-to-SVG pipelines
- would mix plan objects and artifact-heavy runtime objects too early
- likely to create awkward optional fields and overloaded meaning

Status:

- not recommended

### Option B: Separate Figure-Native Object Family

Idea:

- create a parallel object family dedicated to editable figures

Benefits:

- cleaner lifecycle boundaries
- easier to attach stage-specific sidecars
- easier to evolve without distorting `ggplot` and diagram abstractions

Costs:

- slightly larger conceptual surface
- requires explicit bridges to existing inspection/session helpers

Status:

- recommended

### Option C: Make Session The Primary Object

Idea:

- treat every editable figure as a session from the beginning

Benefits:

- editing is central from day one

Costs:

- durable artifact versus active editing state becomes blurry
- over-rotates toward workflow before the base artifact contract is stable

Status:

- not recommended

## Recommended Direction

Use Option B.

That means:

- `ggai_editable_figure` is the durable artifact
- `ggai_figure_session` is a wrapper used only when iterative editing starts
- upstream stage objects remain explicit instead of being hidden inside one giant bundle

## Object Family

### 1. `ggai_figure_plan`

Role:

- semantic compiler output for an editable scientific figure

It should describe:

- what the figure is trying to communicate
- which semantic objects should appear
- how those objects relate
- what style constraints matter
- what edit anchors should exist later

Minimum fields:

- `instruction`
- `scene_summary`
- `objects`
- `relations`
- `composition`
- `style_contract`
- `edit_anchors`
- `generation_hints`
- `provenance`

Should not contain:

- final coordinates
- extracted assets
- final SVG

### 2. `ggai_figure_draft`

Role:

- selected raster draft plus the metadata needed to explain where it came from

Minimum fields:

- `plan_id`
- `selected_candidate_id`
- `candidates`
- `selected_path`
- `image_dimensions`
- `scoring_summary`
- `provider_info`
- `provenance`

Notes:

- this object can reference multiple candidates, but it should still identify one selected draft

### 3. `ggai_region_map`

Role:

- editable-region interpretation of the chosen draft

Minimum fields:

- `draft_id`
- `regions`
- `region_groups`
- `anchor_links`
- `confidence_summary`
- `inference_method`
- `provenance`

Each `region` should eventually support fields like:

- `region_id`
- `label`
- `semantic_role`
- `bbox`
- `polygon` or `mask_ref`
- `confidence`
- `anchor_id`
- `source_kind`

Notes:

- exact schema is still open
- this object is the likely bridge between semantic plan and editable SVG structure

### 4. `ggai_extracted_asset_set`

Role:

- normalized output of crop / cleanup / background-removal stages

Minimum fields:

- `draft_id`
- `region_map_id`
- `assets`
- `asset_manifest_path`
- `provenance`

Each asset should eventually support:

- `asset_id`
- `region_id`
- `path`
- `transparent_path`
- `media_type`
- `dimensions`
- `cleanup_steps`

### 5. `ggai_svg_template`

Role:

- semantic SVG scaffold before final assembly

Minimum fields:

- `plan_id`
- `draft_id`
- `region_map_id`
- `template_path`
- `element_index`
- `validation_summary`
- `provenance`

The `element_index` should eventually map:

- semantic object or anchor
- template element ID
- expected region or asset reference
- editability role

### 6. `ggai_editable_figure`

Role:

- final durable editable figure bundle

This is the main user-facing artifact.

Minimum fields:

- `figure_id`
- `plan`
- `draft`
- `region_map`
- `asset_set`
- `svg_template`
- `final_svg_path`
- `preview_paths`
- `sidecar_paths`
- `export_summary`
- `provenance`

Notes:

- this object should be inspectable without needing a live session
- future `DeepScientist` integration should probably consume this object first

### 7. `ggai_figure_session`

Role:

- active editing state over a durable `ggai_editable_figure`

Minimum fields:

- `figure_id`
- `base_figure`
- `history`
- `history_index`
- `active_layer`
- `open_edits`
- `session_meta`

The `active_layer` should make it explicit whether the latest edit targets:

- `plan`
- `template`
- `final_svg`

This is important because edit history should preserve which layer was patched.

## Lifecycle

Recommended lifecycle:

1. `compile_figure_plan()` -> `ggai_figure_plan`
2. `generate_figure_draft()` -> `ggai_figure_draft`
3. `infer_figure_regions()` -> `ggai_region_map`
4. `extract_figure_assets()` -> `ggai_extracted_asset_set`
5. `generate_svg_template()` -> `ggai_svg_template`
6. `assemble_editable_figure()` -> `ggai_editable_figure`
7. `start_figure_session()` -> `ggai_figure_session`

## Shared Metadata Rules

Every object in this family should carry enough metadata to answer:

- where did this come from?
- which upstream object produced it?
- which files represent it on disk?
- which provider/model/runtime settings were used?
- can it be regenerated deterministically enough for debugging?

Recommended common metadata fragments:

- `id`
- `created_at`
- `upstream_ids`
- `artifact_paths`
- `provider_info`
- `runtime_info`
- `notes`

## Invariants

The current preferred invariants are:

- `ggai_figure_plan` never stores final assembled SVG bytes
- `ggai_figure_draft` always names one selected draft, even if many candidates were tried
- `ggai_region_map` always links back to a draft and forward to semantic anchors where possible
- `ggai_svg_template` is valid independently of the final assembled figure
- `ggai_editable_figure` can be inspected without opening a session
- `ggai_figure_session` never becomes the only copy of durable state

## Sidecar Relationship

These objects should map naturally to sidecar files rather than hide everything in memory.

Suggested mapping:

- `ggai_figure_plan` -> `figure_plan.json`
- `ggai_figure_draft` -> `draft_manifest.json`
- `ggai_region_map` -> `region_map.json`
- `ggai_extracted_asset_set` -> `asset_manifest.json`
- `ggai_svg_template` -> `template.svg` plus `template_meta.json`
- `ggai_editable_figure` -> `final.svg` plus preview files and a bundle manifest
- `ggai_figure_session` -> `session_history.json`

## Immediate Consequences For API Design

This object model implies that the future R API should not jump directly from:

- instruction -> final SVG

without giving access to the staged objects.

It should support both:

- high-level convenience calls
- explicit stage-by-stage calls

## Remaining Unresolved Points

- exact `regions` schema
- exact `style_contract` schema
- whether `ggai_extracted_asset_set` should remain a public object or be folded into `ggai_editable_figure`
- how much of `provider_info` should be normalized across text, image, segmentation, and multimodal stages

## Current Recommendation

Treat this object family as the current preferred naming contract for future design and implementation discussion.

If later sessions want to revise it, they should:

1. record the challenge in a new session file
2. explain which invariants break
3. update this document only after the replacement is clearly better
