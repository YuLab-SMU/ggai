---
name: ggai-complex-heatmap
description: |
  Produce annotated heatmaps using the ComplexHeatmap package — matrix expression heatmaps with multi-track row/column annotations, dendrograms, splits, oncoPrint, and HeatmapList combinations. Use when the figure intent is a heatmap with non-trivial annotation, row or column splitting, or multiple stacked heatmaps. ggplot's `geom_tile` does not scale to these requirements.
aliases:
  - "complex heatmap"
  - "annotated heatmap"
  - "ComplexHeatmap"
  - "expression heatmap with annotations"
  - "oncoPrint"
  - "热图加注释"
  - "复杂热图"
when_to_use: Use when the heatmap needs row/column annotation tracks, dendrograms, split rows/columns, oncoPrint, multiple stacked heatmaps, or any pattern ggplot's `geom_tile` cannot express cleanly.
user-invocable: true
---

# ggai Complex Heatmap

Your job: produce an honest, well-annotated heatmap using `ComplexHeatmap::Heatmap()` (or `HeatmapList` for stacked heatmaps).

## When this skill applies

- The data is a matrix or matrix-like data frame to display as a coloured grid.
- The user wants row or column **annotations** (sample groups, cluster labels, pathway membership) shown as coloured tracks adjacent to the heatmap.
- The user wants **row or column splitting** by a grouping variable.
- The user wants a **dendrogram** for rows / columns (ComplexHeatmap clusters by default).
- The user wants **multiple heatmaps side-by-side** (e.g. expression + methylation; expression + mutation) — use `+` to build a `HeatmapList`.
- The user wants an **oncoPrint** for mutation / alteration data.

If the heatmap is small, single-track, and ggplot's `geom_tile` would do — go back to `ggai-data-plot` and skip this skill.

## Flow

1. **Read the resolved mention context.** ComplexHeatmap operates on a numeric matrix. If the user mentioned a data frame, you may need to coerce / pivot. Note row and column dimensions; if huge (> 10k rows), set `use_raster = TRUE`.
2. **Decide the annotation set.** From the user's stated columns and any sample metadata mention: which variables become row annotations, which become column annotations, which colour scale each gets.
3. **Write the code** following the conventions below. Last value should be the `Heatmap` (or `HeatmapList`) object — the agent runtime calls `ComplexHeatmap::draw()` on it.
4. **Call `ggai_execute_r(code, engine_hint = "complex_heatmap")`**. The engine_hint is optional (the class is auto-detected) but explicit is clearer.
5. **Validate** — `ggai_validate_artifact()` runs a null-device `draw()` to catch broken specs.
6. **Save** — `ggai_save_artifact(output_dir, prefix)`. The saved code is a complete reproducer; the manifest records matrix shape and annotation slots.

## Code conventions

- Always `library(ComplexHeatmap)` first; reference functions unqualified inside the body.
- Use `circlize::colorRamp2()` for continuous colour mapping; named character vectors for discrete annotations.
- For row annotations: `rowAnnotation(...)`. For column annotations: `HeatmapAnnotation(...)`. Both go inside `Heatmap(...)` via `top_annotation = `, `bottom_annotation = `, `left_annotation = `, `right_annotation = `.
- For splits: `row_split = factor(...)` and `column_split = factor(...)`. Always wrap in `factor()` with explicit levels for stable order.
- For dendrograms: ComplexHeatmap clusters by default. Disable with `cluster_rows = FALSE` / `cluster_columns = FALSE` when the user supplies an order.
- For huge matrices: `use_raster = TRUE` keeps the file size manageable.
- Heatmap names (`name = `) appear in the legend. Use them honestly: `"log2 FC"`, `"expression (Z-score)"`, not `"value"`.

## Reference snippets

Basic annotated heatmap:

```r
library(ComplexHeatmap)
library(circlize)

set.seed(1)
m <- matrix(rnorm(200), 20, 10)
rownames(m) <- paste0("gene", 1:20)
colnames(m) <- paste0("sample", 1:10)

group <- factor(rep(c("control", "treated"), each = 5),
                levels = c("control", "treated"))

col_anno <- HeatmapAnnotation(
  group = group,
  col = list(group = c(control = "#94A3B8", treated = "#E11D48")),
  annotation_name_side = "left"
)

Heatmap(
  m,
  name = "expression (Z-score)",
  col = colorRamp2(c(-2, 0, 2), c("#1E40AF", "white", "#B91C1C")),
  top_annotation = col_anno,
  row_split = factor(rep(c("upreg", "downreg"), each = 10), levels = c("upreg", "downreg")),
  cluster_columns = FALSE,
  row_title_rot = 0,
  row_names_gp = grid::gpar(fontsize = 8),
  column_names_gp = grid::gpar(fontsize = 9),
  heatmap_legend_param = list(direction = "horizontal", legend_width = grid::unit(4, "cm"))
)
```

Stacked HeatmapList (expression + methylation, sharing row order):

```r
library(ComplexHeatmap)
library(circlize)

set.seed(1)
expr <- matrix(rnorm(200), 20, 10)
methyl <- matrix(runif(200, 0, 1), 20, 10)
rownames(expr) <- rownames(methyl) <- paste0("gene", 1:20)

h1 <- Heatmap(expr, name = "expression",
              col = colorRamp2(c(-2, 0, 2), c("#1E40AF", "white", "#B91C1C")),
              cluster_columns = FALSE, show_row_names = TRUE)
h2 <- Heatmap(methyl, name = "methylation",
              col = colorRamp2(c(0, 0.5, 1), c("white", "#FDE68A", "#92400E")),
              cluster_columns = FALSE, show_row_names = FALSE)

h1 + h2
```

OncoPrint (mutation pattern):

```r
library(ComplexHeatmap)

# Example mutation matrix: rows = genes, cols = samples, cells = mutation types
mat <- matrix(sample(c("", "MUT", "AMP", "DEL", "MUT;AMP"), 60, replace = TRUE,
                      prob = c(0.6, 0.15, 0.1, 0.1, 0.05)), 6, 10)
rownames(mat) <- paste0("gene", 1:6)
colnames(mat) <- paste0("sample", 1:10)

alter_fun <- list(
  background = function(x, y, w, h) grid::grid.rect(x, y, w * 0.95, h * 0.9, gp = grid::gpar(fill = "#E5E7EB", col = NA)),
  MUT = function(x, y, w, h) grid::grid.rect(x, y, w * 0.9, h * 0.4, gp = grid::gpar(fill = "#16A34A", col = NA)),
  AMP = function(x, y, w, h) grid::grid.rect(x, y, w * 0.9, h * 0.85, gp = grid::gpar(fill = "#DC2626", col = NA)),
  DEL = function(x, y, w, h) grid::grid.rect(x, y, w * 0.9, h * 0.85, gp = grid::gpar(fill = "#2563EB", col = NA))
)

oncoPrint(mat,
          alter_fun = alter_fun,
          col = c(MUT = "#16A34A", AMP = "#DC2626", DEL = "#2563EB"),
          remove_empty_columns = FALSE)
```

## Polish + downstream

- For typography / palette tweaks: stay in ComplexHeatmap — adjust `row_names_gp`, `column_names_gp`, `heatmap_legend_param`, `col` ramps. No reason to go to `polish_figure()`.
- For surface-level "cover figure" polish: `polish_figure()` accepts ggplot artifacts only today; ComplexHeatmap polish via the image model would require converting to ggplot via `ggplotify::as.ggplot(grid.grabExpr(draw(ht)))` first. Mention this in the final reply if the user asks.

## Anti-patterns

- **Don't use `geom_tile` when the user asked for annotations**. ggplot's annotation story for grid layouts is fragile; ComplexHeatmap exists exactly for this.
- **Don't cluster huge matrices implicitly.** For > 5000 rows, set `cluster_rows = FALSE` unless the user explicitly wants clustering — otherwise the clustering step dominates runtime.
- **Don't paint a heatmap without a colorRamp2.** The default ramp is unreadable; always set `col = colorRamp2(...)` with a sensible breaks vector.
- **Don't omit the legend name.** A heatmap with `name = "value"` tells the reader nothing.
- **Don't claim a clustering result when `cluster_rows = FALSE`** was set — the row order is then the user-supplied order, not a hierarchical cluster.

## When to escalate

- If the heatmap is small and unannotated — go back to `ggai-data-plot`.
- If the user wants the heatmap composited into a multi-panel figure with other ggplots — use `patchwork::wrap_elements(grid::grid.grabExpr(draw(ht)))` to embed the heatmap. Composite engine path.
- If the user wants the heatmap on circular / genomic coordinates — load `ggai-circlize-genome`.
