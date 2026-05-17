---
name: ggai-engine-selection
description: |
  Decide which R visualization engine to use for a figure: ggplot2, grid/grob, base graphics, ComplexHeatmap, circlize, ggraph/DiagrammeR, htmlwidget (plotly/leaflet), or composite (patchwork/cowplot/aplot). Load this skill when the user names a non-ggplot library, when the figure shape suggests a specialized library, or when ggplot would require contortions to reach the intended result.
aliases:
  - "which library"
  - "which engine"
  - "ggplot or ComplexHeatmap"
  - "best library for this plot"
  - "should I use circlize"
when_to_use: Use when the figure intent is incompatible with ggplot's grammar, the user names a specific viz library, the data has genomic/network/circular structure, or the figure must be interactive.
user-invocable: true
---

# ggai Engine Selection

ggai supports multiple R graphics engines through one `ggai_artifact` type. Your job is to pick the right engine for the task, return a short rationale, and then continue with the task skill that fits.

## Decision table

| Intent | Engine | Why |
|--------|--------|-----|
| Tabular EDA, statistical visualization, faceted comparisons | `ggplot` | Grammar of graphics; richest tooling; default. |
| Annotated heatmap with row/column annotation tracks (genomics, expression, oncoPrint) | `complex_heatmap` | ComplexHeatmap's annotation model is the only one that scales cleanly here; ggplot+geom_tile gets ugly fast. |
| Circular / genomic-coordinate plot, chord diagram, multi-track circle | `circlize` | Native circular layout + track API. |
| Network / graph / phylogeny with ggplot-style aesthetics | `ggplot` via `ggraph` or `ggtree` | Same artifact engine as ggplot. |
| Phylogenetic tree, dendrogram via classic Bioc APIs | `base` (via `recordPlot`) | `plot.phylo`, `plot.hclust` produce base output; capture via the recording device. |
| Custom grobs, manual layout, glyph composition over a chart | `grid` | Direct grob manipulation; viewport math. |
| Multi-panel composite from several existing artifacts | `composite` | `patchwork` / `cowplot` / `aplot`. Recursive. |
| Interactive viz (zoomable scatter, choropleth, dashboard) | `htmlwidget` | `plotly` / `leaflet` / `networkD3`. Needs `webshot2` for static PNG export. |

## How the agent uses this

1. Pick the engine and one-sentence rationale.
2. If the chosen engine is **not** ggplot, mention it in `engine_hint =` when you call `ggai_execute_r`. Auto-detection works for the common cases, but explicit is better for circlize / ComplexHeatmap.
3. Continue with whichever task skill applies (`ggai-data-plot` for most non-direct-illustration paths). The task skill cares about composition; engine choice is orthogonal.

## Calling conventions per engine

- **ggplot** — code's *last value* is the `ggplot` object. Don't `print()` unless you want to draw to device.
- **complex_heatmap** — code's last value is the `Heatmap` or `HeatmapList`. The artifact's render path runs `ComplexHeatmap::draw(<last_value>)` on a target device.
- **circlize** — code draws into the device (`circos.initialize` ... `circos.clear()`); set `engine_hint = "base"` because the last value is `NULL` and detection falls back to the device displaylist.
- **grid** — code returns a `grob` / `gTree` / `gList` as the last value.
- **base** — code draws to device with `plot(...)`, `heatmap(...)`, etc.; last value can be anything (NULL is fine).
- **htmlwidget** — code's last value is an htmlwidget object. P6 work; not yet supported by the render adapter. Until then, treat as `unknown` and capture the HTML by hand.
- **composite** — assemble with `patchwork::wrap_plots(...)` or `cowplot::plot_grid(...)`; last value is the composite.

## Common mis-routings

- "Heatmap of expression data with sample annotations" → don't reach for `ggplot + geom_tile + facet_grid`. Use `ComplexHeatmap`.
- "Genome coordinates around a region of interest" → don't reach for `ggplot + geom_segment`. Use `circlize` or `Gviz` / `karyoploteR` (the latter two are base-graphics; engine = `base`).
- "Network of pathway interactions" → ggraph (still ggplot engine) is the default; only escalate to DiagrammeR if the user wants a real graph layout language.
- "Survival curve with risk table" → `ggplot` + `survminer` works. Don't escalate to a heatmap library.

## When to fall back to ggplot anyway

Even when a specialized engine fits, prefer ggplot if:

- The user explicitly said "ggplot" or "ggplot2".
- The downstream consumer is `ggsave` + patchwork composition.
- The polish path will run; ggplot artifacts have the richest inspection metadata for the polish step.

## After choosing

Tell the user in your final reply *which engine you used* and one-line *why*. The user should not have to read the code to figure it out.
