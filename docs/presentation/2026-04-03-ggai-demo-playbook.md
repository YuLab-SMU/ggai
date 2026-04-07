# ggai Demo Playbook

## Goal

Demonstrate that `ggai` is already capable of producing compelling scientific overview figures, while being honest about what is still under construction.

## Recommended Demo Order

### Demo 0: ggplot + ggai

Show:

- `demo_outputs/ggplot_integration_base.png`
- `demo_outputs/ggplot_integration_augmented.png`
- `demo_outputs/ggplot_integration_augmented_code.R`

Say:

- “This is the safest way to explain that `ggai` does not replace `ggplot`.”
- “`ggplot` still owns the data graphic; `ggai` adds AI-compiled communication layers.”
- “This is the adoption bridge for analysts and biologists who already work in R.”

### Demo 0.5: Session Editing

Show:

- `demo_outputs/ggai_session_01_base.png`
- `demo_outputs/ggai_session_02_highlight.png`
- `demo_outputs/ggai_session_03_outline_only.png`
- `demo_outputs/ggai_session_04_label_tuned.png`
- `demo_outputs/ggai_session_05_after_undo.png`
- `demo_outputs/ggai_session_current_code.R`

Say:

- “This is where `ggai` becomes an editor, not only a generator.”
- “The system keeps the current plot state and applies local edits turn by turn.”
- “This gives continuity, undo, and exportable code after each edit.”

### Demo 1: Product Overview

Show:

- [`biorender_competitor_demo_best.jpg`](../../demo_outputs/biorender_competitor_demo_best.jpg)

Say:

- “This is the most product-like overview figure.”
- “It communicates a patient-to-digital-twin-to-therapy loop.”
- “This is the class of figure people currently build by hand.”

### Demo 2: Biomedical Mechanism

Show:

- [`biorender_tme_demo_best.jpg`](../../demo_outputs/biorender_tme_demo_best.jpg)

Say:

- “This is the mechanism-figure use case.”
- “It’s much closer to the style and narrative density people expect from BioRender-like outputs.”
- “The key here is the before/after immune state storytelling.”

### Demo 3: Translational Workflow

Show:

- [`biorender_crispr_demo_best.jpg`](../../demo_outputs/biorender_crispr_demo_best.jpg)

Say:

- “This shows that we can do more than biology mechanism art.”
- “We can also do translational workflow figures with stage hierarchy and modular structure.”

### Demo 4: Closed Loop Systems Figure

Show:

- [`biorender_atlas_to_therapy_demo_best.jpg`](../../demo_outputs/biorender_atlas_to_therapy_demo_best.jpg)

Say:

- “This demonstrates a systems-level figure with a closed feedback loop.”
- “It’s useful because many modern computational biology stories are loops, not straight pipelines.”

### Demo 5: Direct Image Primary Route

Show:

- [`direct_immunotherapy_best.jpg`](../../demo_outputs/direct_immunotherapy_best.jpg)
- [`direct_immunotherapy_prompt.json`](../../demo_outputs/direct_immunotherapy_prompt.json)
- [`direct_immunotherapy_candidates.json`](../../demo_outputs/direct_immunotherapy_candidates.json)

Say:

- “This is the new primary route.”
- “We are no longer relying on asset-by-asset composition as the main rendering strategy.”
- “We compile a figure prompt bundle, generate multiple candidates, and select the best.”

## Live Commands

If you want to run one live direct-image demo during the meeting, use:

```bash
Rscript demo/direct_immunotherapy_figure_demo.R
```

If you want one backup command:

```bash
Rscript demo/biorender_competitor_demo.R
```

If you want to show the `ggplot` integration path:

```bash
Rscript demo/ggplot_integration_demo.R
```

If you want to show the session editing path:

```bash
Rscript demo/ggai_session_demo.R
```

## Fallback Plan

If the provider is slow or unstable, do not live-generate every figure.

Instead:

1. Show the generated image.
2. Show the prompt bundle JSON.
3. Show the candidate manifest JSON.
4. Explain that generation is reproducible at the pipeline level, even if image models are probabilistic.

## What Not To Do In The Demo

- Do not spend time on old hybrid asset-composition demos.
- Do not get pulled into low-level renderer debugging live.
- Do not claim full BioRender replacement.
- Do not over-index on editability before the audience accepts the figure quality argument.

## The Core Message To Land

The message is not:

“Look, we can call an image model.”

The message is:

“We now have the beginnings of an AI-native scientific figure system, and direct-image generation already produces compelling figure classes that matter in research communication.”
