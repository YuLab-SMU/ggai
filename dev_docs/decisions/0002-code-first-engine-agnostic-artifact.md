# ADR-0002: Code-first engine-agnostic artifact

- **Status:** Accepted
- **Date:** 2026-05-17
- **Deciders:** Yonghe Xia
- **Related:** [plan/2026-05-17-agentic-refactor-overview.md](../../plan/2026-05-17-agentic-refactor-overview.md), [dev_docs/architecture/agentic-architecture.md](../architecture/agentic-architecture.md)

## Context

The current `ggai` codebase treats `ggplot` as the central object. `polish_figure()`, `prepare_polish_bundle()`, `build_plot_context()`, `summarize_plot_layers_for_polish()`, `extract_layout_regions()` all assume `ggplot_build()` and `gtable`-name pattern matching. This excludes:

- **`grid` / `gTree`** — custom grobs, `gridExtra::grid.arrange`, non-gg content inside `patchwork::wrap_elements`
- **base graphics** — `plot.phylo`, `heatmap()`, `dendrogram`, most Bioconductor plot methods
- **`ComplexHeatmap`** — workhorse for genomics annotation-rich heatmaps
- **`circlize`** — circular / genomic plots
- **`ggraph` / `igraph` / `DiagrammeR`** — networks, pathways
- **htmlwidgets** (`plotly`, `leaflet`, `networkD3`) — interactive viz
- **`gganimate`, `magick`** — animation, composition

Worse, some of these engines (base graphics + `recordPlot`) produce R objects that are session-bound — they cannot be reliably round-tripped through serialization or across process boundaries.

## Decision

**Drop `ggplot` as the central object. Introduce `ggai_artifact` as the universal unit.** `code` (the R code that reproduces the figure) is canonical; `object` (a cached R object representation) is non-canonical and may be NULL.

```r
ggai_artifact <- structure(list(
  id         = "...",
  code       = "<full reproducer>",    # canonical
  engine     = "ggplot|grid|base|complex_heatmap|circlize|htmlwidget|composite",
  object     = <may be NULL>,          # cache only
  rendered   = list(png = "...", svg = "...", pdf = NULL),
  data_refs  = list(...),
  packages   = c(...),
  inspect    = list(...),              # engine-specific
  provenance = list(...)
), class = "ggai_artifact")
```

Engine-specific behavior lives in **internal adapters**:

- `render_ggplot()`, `render_grid()`, `render_base()`, `render_complex_heatmap()`, `render_circlize()`, `render_htmlwidget()`
- `inspect_ggplot()`, `inspect_grob_tree()`, `inspect_recorded()`, `inspect_ch()`, ...

Public Layer-2 primitives dispatch on `artifact$engine` and call the right adapter. The polish path no longer requires geometry/layout overlays — they become optional enrichment that ggplot can provide and other engines may skip. The agent sees only the artifact, not the engine.

## Alternatives considered

- **Stay ggplot-only and document the limitation.** Rejected: cuts off the bulk of bioinformatics visualization (ComplexHeatmap, circlize, base-graphics-heavy packages). Inconsistent with project goal of "agent for scientific figures".
- **Make `ggai_artifact` carry only the object, lazily render code.** Rejected: doesn't solve base-graphics's lack of stable object representation. Forces every engine to invent a serializable form.
- **Promote object over code as canonical.** Rejected for the same reason — `recordPlot` results are session-bound, and the LLM edits text anyway.

## Consequences

### Positive

- Adding an engine = writing two adapter functions (`render_*`, `inspect_*`). No core changes.
- Polish path works for any engine for free (it operates on PNG).
- Code is what the LLM edits, so canonical-code aligns with how editing actually happens.
- Reproducibility improves: every artifact carries its own reproducer.

### Negative / accepted tradeoffs

- Object roundtrip is no longer guaranteed. Callers who want the live `ggplot` must accept it may be NULL and re-execute `code` if needed.
- Engine detection requires heuristics (look at `last.value` class, check `dev.cur()`). First version may misclassify; mitigated by an `engine_hint = ` argument on `ggai_execute_and_capture()`.
- Inspection depth varies by engine. ggplot gives rich semantic info; base graphics gives almost nothing structured. Skills must be written to handle the lower-information case.

### Follow-ups

- P1 of the refactor plan: build `ggai_execute_and_capture()` + ggplot/base/grid adapters.
- P5: ComplexHeatmap + circlize adapters.
- P6: htmlwidget adapter (optional dependency on `webshot2`).
- Update `polish_figure` logic to consume the artifact's inspect output rather than calling `ggplot_build()` directly.
