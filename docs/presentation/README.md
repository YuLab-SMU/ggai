# ggai Presentation Pack

This folder contains the presentation materials for introducing `ggai` to a boss and research group.

## Files

- [`2026-04-03-ggai-hero-demo.md`](./2026-04-03-ggai-hero-demo.md)
  The “ggai explains ggai” flagship presentation demo.
- [`2026-04-03-ggai-ggplot-integration.md`](./2026-04-03-ggai-ggplot-integration.md)
  How to explain `ggplot + ggai` together instead of positioning them as competitors.
- [`2026-04-03-ggai-session-editing.md`](./2026-04-03-ggai-session-editing.md)
  How to explain the new stateful editing-session layer.
- [`2026-04-03-ggplot-feature-coverage.md`](./2026-04-03-ggplot-feature-coverage.md)
  A fuller answer to “is ggai only geom_ai?” with the current ggplot-side feature coverage.
- [`2026-04-03-ggai-slide-script.md`](./2026-04-03-ggai-slide-script.md)
  Full slide-by-slide content and speaker script.
- [`2026-04-03-ggai-demo-playbook.md`](./2026-04-03-ggai-demo-playbook.md)
  Practical demo sequence, fallback strategy, and exact files to show.
- [`2026-04-03-ggai-storyline.md`](./2026-04-03-ggai-storyline.md)
  Short narrative framing: problem, solution, moat, risk, roadmap.

## Recommended Showcase Images

- ggai hero figure:
  `demo_outputs/direct_ggai_hero_best.*` after running
  [`demo/direct_ggai_hero_demo.R`](/Users/xiayh/Projects/ggai/demo/direct_ggai_hero_demo.R)
- Platform overview:
  [`biorender_competitor_demo_best.jpg`](../../demo_outputs/biorender_competitor_demo_best.jpg)
- Tumor microenvironment mechanism:
  [`biorender_tme_demo_best.jpg`](../../demo_outputs/biorender_tme_demo_best.jpg)
- CRISPR screen to therapy:
  [`biorender_crispr_demo_best.jpg`](../../demo_outputs/biorender_crispr_demo_best.jpg)
- Atlas to therapy closed loop:
  [`biorender_atlas_to_therapy_demo_best.jpg`](../../demo_outputs/biorender_atlas_to_therapy_demo_best.jpg)
- Direct immunotherapy flagship:
  [`direct_immunotherapy_best.jpg`](../../demo_outputs/direct_immunotherapy_best.jpg)

## Demo Scripts

- [`demo/ggplot_integration_demo.R`](/Users/xiayh/Projects/ggai/demo/ggplot_integration_demo.R)
- [`demo/ggai_session_demo.R`](/Users/xiayh/Projects/ggai/demo/ggai_session_demo.R)
- [`demo/direct_ggai_hero_demo.R`](/Users/xiayh/Projects/ggai/demo/direct_ggai_hero_demo.R)
- [`demo/biorender_competitor_demo.R`](/Users/xiayh/Projects/ggai/demo/biorender_competitor_demo.R)
- [`demo/biorender_tme_demo.R`](/Users/xiayh/Projects/ggai/demo/biorender_tme_demo.R)
- [`demo/biorender_crispr_demo.R`](/Users/xiayh/Projects/ggai/demo/biorender_crispr_demo.R)
- [`demo/biorender_atlas_to_therapy_demo.R`](/Users/xiayh/Projects/ggai/demo/biorender_atlas_to_therapy_demo.R)
- [`demo/direct_immunotherapy_figure_demo.R`](/Users/xiayh/Projects/ggai/demo/direct_immunotherapy_figure_demo.R)

## Presenter Recommendation

If you only show three visuals, show these:

1. `direct_ggai_hero_best.*`
2. `biorender_competitor_demo_best.jpg`
3. `biorender_tme_demo_best.jpg`

That combination best demonstrates:

- platform overview
- biomedical mechanism figure quality
- the new direct-image technical route
