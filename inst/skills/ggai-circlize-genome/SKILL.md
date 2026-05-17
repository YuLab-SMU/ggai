---
name: ggai-circlize-genome
description: |
  Produce circular / genomic figures using the `circlize` package — chord diagrams, circular genome browsers with multiple tracks, ideograms, Circos-style multi-track figures, and similar. Use when the figure intent is circular layout or when the user names `circlize`, `circos`, "Circos", "chord diagram", or describes a multi-track circular genomic figure.
aliases:
  - "circular plot"
  - "chord diagram"
  - "circos"
  - "circlize"
  - "circular genome"
  - "genome browser circular"
  - "环图"
  - "弦图"
  - "基因组圈图"
when_to_use: Use when the figure must be drawn in a circular layout, or when the user explicitly names Circos / circlize / chord diagram tooling.
user-invocable: true
---

# ggai Circlize Genome

Your job: produce a circular / genomic figure using the `circlize` package.

## When this skill applies

- **Chord diagrams** — undirected or directed flow between categories (gene-set overlap, cell-cell interaction strength, country trade flows).
- **Circular genome browsers** — chromosomes laid around a circle with one or more tracks (coverage, mutation density, gene labels, links between regions).
- **Multi-track circular figures** — any concept where a circular axis is more honest than a linear one (cyclic time, phylogeny + traits).

If the data is linear and the user did not ask for circular layout — go back to `ggai-data-plot`.

## Engine note

`circlize` draws to the device via side effects (`circos.initialize` → `circos.track*` → ... → `circos.clear`). The R code's last value is typically `NULL`. Auto-detection therefore falls through to `base`, not `circlize`. **You must pass `engine_hint = "circlize"`** to `ggai_execute_r` so the artifact is tagged correctly.

## Flow

1. **Decide the figure kind**: chord diagram, multi-track genome browser, or generic circular layout.
2. **For genome figures**: use `circlize::circos.initializeWithIdeogram()` for hg19 / hg38 ideograms, or `circos.genomicInitialize()` for a user-supplied chromosome data frame.
3. **For chord diagrams**: use `chordDiagram()` with a matrix or adjacency data frame.
4. **Write the code**. Always begin with `library(circlize)` and end with `circos.clear()` so subsequent calls start clean. The last expression can be `invisible(NULL)` — engine detection will fall to base; that's why we pass `engine_hint = "circlize"`.
5. **Call `ggai_execute_r(code, engine_hint = "circlize")`**.
6. **Validate** — `ggai_validate_artifact()` checks the captured recordedplot is non-trivial.
7. **Save** — `ggai_save_artifact(output_dir, prefix)`.

## Code conventions

- Wrap the whole figure in `circos.clear()` calls before and after, so device state is clean.
- Use `circos.par(start.degree = 90, gap.degree = 2)` for control over starting angle and inter-sector gap.
- Set colours explicitly via `grand.gap` / `link.col` arguments; default colours are not publication-grade.
- For chord diagrams: prefer `chordDiagram(data, transparency = 0.4, ...)` — opaque chords are hard to read.
- For ideograms: `circos.initializeWithIdeogram(species = "hg38", chromosome.index = paste0("chr", 1:22))`. Always explicitly list chromosomes to avoid showing chrX/Y/M unintentionally.
- For genomic tracks: use `circos.genomicTrackPlotRegion()` with a `panel.fun` that handles the per-chromosome panel.

## Reference snippets

Chord diagram from an adjacency matrix:

```r
library(circlize)

set.seed(1)
mat <- matrix(sample(1:50, 36, replace = TRUE), 6, 6)
rownames(mat) <- colnames(mat) <- paste0("cluster_", 1:6)

circos.clear()
circos.par(start.degree = 90, gap.degree = 4)
chordDiagram(
  mat,
  transparency = 0.35,
  grid.col = setNames(viridisLite::viridis(6), rownames(mat)),
  annotationTrack = c("name", "grid"),
  annotationTrackHeight = c(0.04, 0.04)
)
circos.clear()
invisible(NULL)
```

Circular genome with one coverage track:

```r
library(circlize)

# Toy coverage signal across 5 chromosomes
set.seed(1)
chroms <- paste0("chr", 1:5)
bed <- do.call(rbind, lapply(chroms, function(ch) {
  starts <- seq(1, 1e8, by = 1e6)
  data.frame(chrom = ch, start = starts, end = starts + 1e6,
             value = rnorm(length(starts), 0, 1))
}))

circos.clear()
circos.par(start.degree = 90, gap.degree = 2)
circos.initialize(factors = chroms, xlim = cbind(0, 1e8))
circos.track(ylim = c(0, 1), bg.col = "#F1F5F9",
             panel.fun = function(x, y) {
               chr <- CELL_META$sector.index
               circos.text(CELL_META$xcenter, 0.5, chr, facing = "downward",
                           cex = 0.9, font = 2)
             })
circos.genomicTrack(
  bed,
  ylim = range(bed$value),
  panel.fun = function(region, value, ...) {
    circos.genomicLines(region, value, type = "h", col = "#1E40AF", lwd = 1.4)
  }
)
circos.clear()
invisible(NULL)
```

## Anti-patterns

- **Don't forget `circos.clear()`.** Device state leaks across calls; the second figure will inherit broken `par()` from the first.
- **Don't draw chord diagrams without `transparency`.** Opaque chords obscure each other; readers can't trace any single connection.
- **Don't use the default chromosome set** for ideograms. Always specify `chromosome.index = ...` to exclude irrelevant chromosomes.
- **Don't omit `engine_hint = "circlize"`.** Without it, the artifact is tagged `base` and downstream skills lose context.
- **Don't ask for ideograms without naming the species/assembly.** `species = "hg19"` vs `"hg38"` vs `"mm10"` matters; ask the user if unclear.

## When to escalate

- If the user wants the circular plot composed alongside a ggplot — composite path; `ggplotify::as.grob()` or `grid::grid.grabExpr()` to capture the circlize output as a grob, then embed via patchwork.
- If the user wants an annotated heatmap (linear) rather than circular — `ggai-complex-heatmap`.
- If the circular figure is purely conceptual (no genomic / numeric data) — consider `ggai-direct-figure` (code mode) with grid primitives.
