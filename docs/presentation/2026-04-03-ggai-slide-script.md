# ggai Slide Script

## Slide 1: Title

### Slide Title

`ggai: Toward an AI-Native Scientific Figure System`

### On-Slide Content

- AI-native scientific figure generation
- direct image mode for publication-style figures
- structured sidecar for control and iteration

### Speaker Script

I want to show `ggai` not as another “AI image demo,” but as the start of an AI-native figure system for science. The core idea is simple: instead of drawing mechanism and workflow figures manually, we compile research intent into a final figure. The current system already produces strong platform-overview and biomedical figure demos, and we have a clear path for turning this into a real internal capability.

---

## Slide 2: The Problem

### Slide Title

`The Hardest Figures Are Still Mostly Manual`

### On-Slide Content

- mechanism figures
- workflow overviews
- platform diagrams
- translational medicine summaries

### Speaker Script

The hardest figures in papers, grants, and decks are usually not bar charts or scatter plots. They are mechanism and overview figures. Today these are still made manually in PowerPoint, Illustrator, Figma, or BioRender. The pain is not only time. The bigger pain is that scientific logic and visual construction are disconnected. Every revision is expensive, and every layout change feels like rebuilding the figure from scratch.

---

## Slide 3: Product Thesis

### Slide Title

`Our Thesis`

### On-Slide Content

- figures should be compiled, not hand-drawn
- direct image generation is the primary route
- structured sidecar remains for explainability and iteration

### Speaker Script

Our thesis is that scientific figures should be compiled. The user provides intent, object hierarchy, and composition guidance. The system compiles that into a figure prompt bundle, generates multiple final figure candidates, scores them, and keeps the structured sidecar for debugging and future editing. That is the key architectural shift. Direct image generation is the primary rendering route now. Structured specs still matter, but mainly as scaffolding and traceability.

---

## Slide 4: Demo 1

### Slide Title

`Demo 1: Platform Overview`

### Show

[`biorender_competitor_demo_best.jpg`](../../demo_outputs/biorender_competitor_demo_best.jpg)

### Speaker Script

This figure is the most product-like overview. It communicates a programmable cell therapy digital twin workflow: biopsy, spatial transcriptomics, AI circuit design, cell manufacturing, monitoring, and feedback. This is the kind of figure that people currently spend a lot of manual effort to produce. The important point is not only that the image exists. The important point is that we now have a pipeline that can systematically produce this class of figure from structured scientific intent.

---

## Slide 5: Demo 2

### Slide Title

`Demo 2: Biomedical Mechanism Figure`

### Show

[`biorender_tme_demo_best.jpg`](../../demo_outputs/biorender_tme_demo_best.jpg)

### Speaker Script

This figure is closer to the BioRender-style mechanism figure use case. It shows a before-and-after tumor microenvironment story. This matters because workflow figures are relatively easy. Mechanism figures are where people start asking whether the system can actually support scientific communication. This demo shows that we are no longer confined to generic boxes and arrows. We are moving into narrative biomedical illustration.

---

## Slide 6: Demo 3

### Slide Title

`Demo 3: Translational Pipeline`

### Show

[`biorender_crispr_demo_best.jpg`](../../demo_outputs/biorender_crispr_demo_best.jpg)

### Speaker Script

This is the translational pipeline example: CRISPR screen, computational ranking, optimization, validation, and clinical handoff. This one is useful because it demonstrates a different demand pattern. It is not primarily a biology mechanism figure. It is a translational workflow figure. If we can handle both mechanism and pipeline figures, then we are serving a large share of the figures that research teams actually need.

---

## Slide 7: Demo 4

### Slide Title

`Demo 4: Atlas-to-Therapy Closed Loop`

### Show

[`biorender_atlas_to_therapy_demo_best.jpg`](../../demo_outputs/biorender_atlas_to_therapy_demo_best.jpg)

### Speaker Script

This one shows a systems-level story: profiling, atlas construction, target nomination, therapy design, treatment, monitoring, and redesign. It is useful because it demonstrates loop structure and the ability to visually communicate a computational-biology system, rather than just a linear pipeline. That is important if we want this to become a real scientific communication tool instead of a one-off image generator.

---

## Slide 8: Architecture

### Slide Title

`How ggai Works`

### On-Slide Content

1. compile figure prompt
2. generate multiple final figures
3. evaluate and select
4. keep sidecar artifacts

### Speaker Script

Architecturally, the system now has a clean primary route. First we compile a figure prompt bundle. Second we generate multiple full-figure candidates. Third we evaluate and select the best candidate. Fourth we preserve sidecar artifacts such as prompt bundles and candidate manifests. That last part matters because it gives us a path to debugging, tuning, and eventually controllable editing. We are not just prompting blindly and hoping for the best.

---

## Slide 9: ggplot + ggai

### Slide Title

`ggplot Is Still The Data Graphics Engine`

### On-Slide Content

- `ggplot` for data mapping and statistical graphics
- `ggai` for communicative augmentation and figure generation
- additive, inspectable, exportable

### Speaker Script

This part is important because I do not want this to sound like `ggai` replaces `ggplot`. It does not. `ggplot` is still the right engine for data graphics, scales, and mappings. `ggai` complements it. On ordinary analytical plots, it can add communicative AI-compiled layers. On top of that, it also opens a separate figure-generation path for mechanism and overview figures. So the relationship is not replacement. It is extension.

---

## Slide 10: Session Editing

### Slide Title

`From Generator To Editor`

### On-Slide Content

- continuous stateful editing
- local patch-style changes
- inspectable history
- undo and code export

### Speaker Script

This is one of the most important product signals. `ggai` now has the beginning of a session editing layer for the `ggplot`-side workflow. That means the system no longer needs to regenerate the whole plot every turn. It can keep the current state, apply local edits, inspect the current sidecar, and undo when needed. That moves `ggai` from an AI figure generator toward an AI figure editor.

---

## Slide 11: Why This Is More Than Prompting

### Slide Title

`Why This Is More Than Prompting`

### On-Slide Content

- prompt bundle compiler
- candidate scoring
- structured sidecar
- figure-class specialization

### Speaker Script

What makes this more than “just prompting a model” is the system around the model. We specialize for figure classes that matter in science. We compile intent into figure-specific prompt bundles. We generate multiple candidates and score them. And we preserve structured sidecars that make the system inspectable and extensible. That is the start of a product architecture, not just an API wrapper.

---

## Slide 12: Current Boundaries

### Slide Title

`What It Does Well, And What It Does Not Yet Do`

### On-Slide Content

- strong at overview and mechanism figures
- not yet a full BioRender replacement
- no mature fine-grained editing UI
- provider quality still matters

### Speaker Script

We should be honest about current boundaries. We are already strong on overview figures and mechanism-style figures. We are not yet a full replacement for BioRender. We do not yet have a mature editing interface, a huge biological asset library, or robust vector-native editing. And image quality still depends on the quality of the provider. But the important point is that the architecture is now aligned with the right problem.

---

## Slide 13: Why Now

### Slide Title

`Why This Is Worth Pursuing`

### On-Slide Content

- scientific communication is a bottleneck
- AI models are finally good enough to matter
- current tools are still manual

### Speaker Script

This is worth pursuing because scientific communication is a real bottleneck. The quality of the figure often determines whether a complex method or biological story lands with the audience. Models are finally good enough that image generation can matter here, but the product layer around them is still missing. That gap is exactly where `ggai` can become meaningful.

---

## Slide 14: Next Steps

### Slide Title

`What We Should Do Next`

### On-Slide Content

- tighten direct-image prompt quality
- improve readability and clarity scoring
- build an internal gallery
- validate against 5-10 real use cases

### Speaker Script

The next step is not to add more random features. It is to tighten direct-image quality, improve readability scoring, build an internal gallery, and validate the system against a handful of real figures that people in the group already need. That will tell us very quickly whether this should stay a prototype or become a real internal platform.
