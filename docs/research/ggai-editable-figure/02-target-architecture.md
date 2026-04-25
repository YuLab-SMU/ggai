# Target Architecture

## Preferred Direction

Build a `ggai-native editable figure pipeline` that uses direct model APIs but owns its own contracts end to end.

## Proposed Pipeline

### Stage 1: Intent Compile

Input:

- natural-language instruction
- optional scene context
- optional style context

Output:

- `ggai_figure_plan`

Responsibilities:

- identify objects
- identify relations
- identify composition
- identify style constraints
- identify edit anchors
- identify expected regions or asset candidates

### Stage 2: Draft Generate

Input:

- `ggai_figure_plan`

Output:

- `ggai_figure_draft`
- raster draft image
- generation manifest

Responsibilities:

- generate one or more draft images
- score them
- preserve candidate metadata

### Stage 3: Region Infer

Input:

- chosen draft image
- `ggai_figure_plan`

Output:

- `ggai_region_map`

Responsibilities:

- infer meaningful editable regions
- map regions to planned semantic objects
- preserve confidence and provenance

### Stage 4: Asset Extract

Input:

- draft image
- region map

Output:

- extracted region assets
- transparent cutouts where useful
- asset manifest

Responsibilities:

- crop
- clean background
- normalize asset references

### Stage 5: SVG Template Generate

Input:

- `ggai_figure_plan`
- draft image
- region map

Output:

- `ggai_svg_template`
- raw `template.svg`

Responsibilities:

- generate a semantic SVG scaffold
- align template elements with inferred regions
- keep the template inspectable and regenerable

### Stage 6: SVG Assemble

Input:

- template
- extracted assets
- region map

Output:

- `ggai_editable_figure`
- `final.svg`
- preview renders

Responsibilities:

- place assets into template
- preserve semantic IDs
- generate sidecars for later edit sessions

### Stage 7: Figure Session

Input:

- editable figure bundle

Output:

- `ggai_figure_session`

Responsibilities:

- track revisions
- support incremental edits
- preserve versioned sidecars
- make regeneration versus direct patch explicit

## Proposed Object Boundaries

### Stable R-Side Objects

- `ggai_figure_plan`
- `ggai_figure_draft`
- `ggai_region_map`
- `ggai_svg_template`
- `ggai_editable_figure`
- `ggai_figure_session`

### Supporting Sidecars

- `figure_plan.json`
- `draft_manifest.json`
- `region_map.json`
- `asset_manifest.json`
- `template.svg`
- `template_meta.json`
- `final.svg`
- `preview.png`
- `session_history.json`

## Proposed Module Slices

- `R/figure_plan.R`
- `R/figure_draft.R`
- `R/region_map.R`
- `R/svg_template.R`
- `R/editable_figure.R`
- `R/figure_session.R`
- `R/figure_sidecars.R`

These file names are not fixed decisions yet, but they reflect the target modular split.

## Integration Principle

Future `DeepScientist` integration should call `ggai` APIs after this layer exists.

It should not define the figure contract first and force `ggai` to adapt afterward.
