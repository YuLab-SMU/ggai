# 2026-05-18 — ggai PPT deck

- **Related plan:** [plan/done/2026-05-18-ggai-ppt-deck.md](../plan/done/2026-05-18-ggai-ppt-deck.md)
- **Related ADRs:** none
- **Related commits / PRs:** none
- **Worked on by:** Codex

## What happened

Built a 10-slide `ggai` overview deck in response to the user's request to combine the supplied PPT-skill references with the repo's own product story. The deck uses authentic repo assets, a Swiss-grid-inspired visual system, and an engineering-platform narrative: broken workflow, system abstraction, editable-until-last-mile loop, product proof, flagship brain-dev case, evidence-preservation matrix, skill-based architecture, metric tower, and closing manifesto.

## Findings / decisions

- The strongest available proof objects were already in-repo: the brain-dev story page, plot-reader explainer, polished dotplot, and advanced before/after cases.
- The deck works better when the supplied references shape the design discipline rather than becoming deck content themselves.
- A restrained cobalt / ink / paper system was enough; the source images provide the needed secondary color variety.
- This was a documentation artifact task only, so there was no `CHANGELOG.md` entry.

## Verification

- Built the deck with artifact-tool:
  - `node .../build_artifact_deck.mjs --workspace .../ggai-ppt --slides-dir .../slides --out .../output/ggai-overview.pptx --preview-dir .../preview --layout-dir .../layout/final --contact-sheet .../preview/contact-sheet.png --slide-count 10`
- Reviewed the generated contact sheet and several full-size slide previews manually.
- Ran layout QA in warn-only mode:
  - `node .../check_layout_quality.mjs --layout .../layout/final --warn-only`
  - Result: `0 error(s), 25 warning(s)`; warnings were tight-text / split-inline style warnings without visible render defects.

## Next

If this deck becomes a recurring asset, the next useful step is to turn its narrative and visual grammar into a reusable `ggai` presentation template or a first-class `inst/skills/` deck skill.
