# TODO

Unscoped backlog. Items here have not been promoted to a `plan/` file yet. Triage during planning sessions: either expand into a plan, fold into an existing plan, move to `idea/` for further exploration, or close as won't-do.

## In Progress

_(none — see `plan/2026-05-17-agentic-refactor-overview.md` for active phase work)_

## Backlog

### Agentic core (will be folded into the refactor plan)

- [ ] Decide whether `ggai_quick_plot()` (non-agentic shortcut for power users) is worth keeping. See ADR-0001.
- [ ] Token-usage tracing surface — observe agent loops for a week post-refactor before promising defaults.

### Skill refinement (from P4 smoke findings, 2026-05-17)

- [ ] **`ggai-direct-figure`** — add explicit "Modes" section distinguishing code-path (grid/ggplot) vs image-model-path. Agent observed to prefer the cheap deterministic code path; the skill should legitimize both and articulate when each is preferred.
- [ ] **`ggai-figure-polish`** — same: add a "Modes" section. Agent preferred ggplot code edits over `polish_figure()`. Both are valid; document when each applies.
- [ ] **Grid render — title overflow.** Wrap `grid.draw` in a viewport with margin allowance, or update direct-figure skill snippets to anchor titles further inside the canvas and wrap long titles. Surfaced in P4 smoke 4.
- [ ] **`ggai_system_prompt()` — mention `list_available_skills`** as the canonical discovery entry-point. Currently lists only 4 of the 7 aisdk skill tools. Soft mismatch; LLM figures it out, but tightening the prompt would shorten the first ReAct step on cold goals.

### Skills to author (post-refactor)

- [ ] `ggai-complex-heatmap` — `ComplexHeatmap::Heatmap` + annotation editorial style.
- [ ] `ggai-circlize-genome` — chromosome coordinates, multi-track design.
- [ ] `ggai-base-graphics` — `par()` / `layout()` / `recordPlot` patterns.
- [ ] `ggai-grid-composition` — direct grob manipulation; glyph placement on canvas.
- [ ] `ggai-patchwork-layout` — multi-panel composition (`patchwork` / `cowplot` / `aplot`).
- [ ] `ggai-htmlwidget` — `plotly` / `leaflet` static export via `webshot2`.
- [ ] `ggai-single-cell` — UMAP / DotPlot / VlnPlot conventions.
- [ ] `ggai-pathway-diagram` — pathway illustration style.
- [ ] `ggai-clinical-figure` — survival curves, forest plots.
- [ ] `ggai-publication-style` — Nature / Cell / Science layout norms.

### Capability extensions

- [ ] Interpretation layer: leverage R's statistical strength to generate descriptive-statistics-grounded narrative alongside the figure.
- [ ] Layer / theme / scale / axis / legend semantic editing primitives.
- [ ] Multi-figure theming, composition, layout.
- [ ] Direct PDF editing pipeline.
- [ ] HTML / SVG assisted layout.

### Tooling and infrastructure

- [ ] Build a `gallery/` (or `showcase/`) site presenting the strongest `ggai` demo figures, scripts, prompt bundles, and candidate manifests. Source from `demo/` outputs.

### Pre-existing CRAN-check hygiene (surfaced 2026-05-17 during P1 check)

- [x] `tests/testthat/test-domain-template-cases.R` sources an out-of-build fixture — **resolved 2026-05-17 (P2): file deleted**.
- [x] `R/ggai_entry.R` contains non-ASCII characters — **resolved 2026-05-17 (P2): file rewritten as pure ASCII**.
- [x] `.aisdk/` directory at repo root is being included in the source tarball — **resolved 2026-05-17 (P2): added to .Rbuildignore**.

## Done

_Items move here when closed without needing a CHANGELOG entry (e.g. internal-only). User-facing completions go to `CHANGELOG.md`._

- (none yet)
