# TODO

Unscoped backlog. Items here have not been promoted to a `plan/` file yet. Triage during planning sessions: either expand into a plan, fold into an existing plan, move to `idea/` for further exploration, or close as won't-do.

## In Progress

_(none — see `plan/2026-05-17-agentic-refactor-overview.md` for active phase work)_

## Backlog

### Agentic core (will be folded into the refactor plan)

- [ ] Decide whether `ggai_quick_plot()` (non-agentic shortcut for power users) is worth keeping. See ADR-0001.
- [ ] Token-usage tracing surface — observe agent loops for a week post-refactor before promising defaults.

### Skill refinement (from P4 smoke findings, 2026-05-17)

- [x] **`ggai-direct-figure`** — explicit Modes section added — resolved in P4.b.
- [x] **`ggai-figure-polish`** — explicit Modes section added — resolved in P4.b.
- [x] **Grid title overflow** — addressed in P4.b by updating the code-mode snippet to anchor titles at `y = 0.90` with explicit margin allowances. Further hardening (viewport-level margin) deferred.
- [ ] **`ggai_system_prompt()` — mention `list_available_skills`** as the canonical discovery entry-point. Currently lists only 4 of the 7 aisdk skill tools. Soft mismatch; LLM figures it out, but tightening the prompt would shorten the first ReAct step on cold goals.

### Capability probe enhancements (from P4.b, 2026-05-17)

- [ ] **Optional live reachability probe.** `ggai_capability_status()` is currently config-only. The user's custom OpenAI-compatible proxy (`jarodfund.xyz/openai/v1`) serves `/v1/chat/completions` but returns 404 on `/v1/images/generations`. Add `ggai_capability_status(probe = TRUE)` that does a tiny HEAD / sentinel call per endpoint, with a short cache so subsequent calls within ~30s reuse the result.
- [ ] **Local-inference providers (Ollama etc.).** Currently report `available = FALSE` because they don't have an env-key map. Add provider→reachability rules that don't require keys for providers that don't take keys.

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
