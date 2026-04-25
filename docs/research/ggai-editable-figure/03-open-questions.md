# Open Questions

## Contract Questions

### Q1

Should `ggai_figure_plan` be a purely semantic object, or should it already include weak geometry hints?

Current leaning:

- include weak geometry hints
- avoid hard coordinates at compile time

Why it matters:

- this affects how much control later region inference and template generation can reuse

### Q2

Should `ggai_editable_figure` be the primary user-facing object, or should `ggai_figure_session` be the main entrypoint?

Current leaning:

- `ggai_editable_figure` should be the durable artifact
- `ggai_figure_session` should wrap it only when iterative editing starts

## Runtime Questions

### Q3

How much of region inference should depend on external segmentation models versus prompt-derived deterministic grouping?

Need to explore:

- cost
- latency
- failure modes
- reproducibility

### Q4

Should SVG template generation be fully model-generated, or partially schema-compiled from `ggai_figure_plan`?

Current uncertainty:

- model generation is flexible
- schema compilation is more stable
- a hybrid may be better

## Editing Questions

### Q5

Should edits patch:

- semantic plan
- template SVG
- assembled final SVG

Current leaning:

- preserve all three layers
- make the edited layer explicit in history

### Q6

Can one shared session abstraction cover:

- `ggplot` compiled edits
- diagram scene edits
- editable SVG figure edits

Current uncertainty:

- likely yes at the history/version layer
- probably no at the patch primitive layer

## Ecosystem Questions

### Q7

What is the minimum `ggai` contract that `DeepScientist` should later consume?

Candidate answer:

- one durable artifact object
- one generation function
- one session-start function
- one export/preview function

### Q8

Should `ggai` expose provider-agnostic helper interfaces for image generation, multimodal reasoning, and SVG generation separately?

Current leaning:

- yes
- keep them narrower than the current generic text/image bridge

## Documentation Process Questions

### Q9

When parallel sessions disagree, where should conflicting hypotheses live before resolution?

Current answer:

- keep disagreements in session files
- only write resolved syntheses into stable docs
