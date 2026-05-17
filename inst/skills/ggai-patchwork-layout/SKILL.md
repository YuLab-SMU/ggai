---
name: ggai-patchwork-layout
description: |
  Compose multiple plots into a single figure using `patchwork`, `cowplot`, or `aplot`. Use whenever the user wants more than one panel — labeled multi-panel figures, side-by-side comparisons, A/B/C panels with shared legend, plots stacked over a metadata strip, or any layout that exceeds what a single ggplot's `facet_*` can express.
aliases:
  - "patchwork"
  - "multi-panel figure"
  - "combine plots"
  - "side-by-side plots"
  - "cowplot"
  - "aplot"
  - "panel A B C"
  - "拼图"
  - "组合图"
  - "多面板"
when_to_use: Use when the user wants more than one plot composed into a single figure, with explicit panel labels or shared scales / legends.
user-invocable: true
---

# ggai Patchwork Layout

Your job: compose multiple plots into one figure using `patchwork` (default) or `cowplot` / `aplot` when the user's request favors them.

## When this skill applies

- "Side by side", "stacked", "A / B / C panels", "subfigure (a) and (b)".
- A figure with one main plot and one or more supporting plots (e.g. histogram on the margin of a scatter, dendrogram above a heatmap).
- Sharing legends or scales across panels.
- Embedding a non-ggplot object (a grid grob, an image) alongside ggplots.

If the user just wants `facet_wrap` / `facet_grid` over a single mapping, that's a single ggplot — back to `ggai-data-plot`.

## Library choice

| Need | Library | Why |
|------|---------|-----|
| Algebraic combination (`p1 + p2`, `p1 / p2`, `(p1 \| p2) / p3`) | `patchwork` | Grammar-of-graphics-shaped composition; clean code. |
| Precise placement / inset axes / `draw_image()` overlays | `cowplot` | Better fine-grained positioning and image embedding. |
| Heatmap-with-companion-tracks (dendrogram on top, annotation on side) | `aplot` | Same x/y coord locking that ggtree composites use. |

Default to `patchwork` unless the user names `cowplot` / `aplot` or the task plainly needs one of them. Patchwork is the most teachable and the agent runtime auto-detects its output as `engine = "composite"`.

## Flow

1. **Decide the layout.** Read the user's intent: how many panels, what shape (row, column, grid, A on top + B|C below).
2. **Build each panel as a separate ggplot.** Keep them simple individually; layout is a separate concern.
3. **Compose with patchwork's `+` / `/` / `|` operators** or `wrap_plots(plotlist = ..., ncol/nrow/widths/heights)`.
4. **Apply `plot_annotation(tag_levels = "A")`** for `(a)/(b)/(c)` panel labels — almost always the user's intent when they say "panel A and B". Don't override `plot.tag` to invisible in the global theme; that strips the labels.
5. **Manage shared themes** with `&` (not `+`) for global theme application across all panels: `pw & theme_minimal(base_size = 10) & theme(legend.position = "bottom")`.
6. **The last value MUST be the patchwork object** — and **omit `engine_hint`** so the runtime auto-detects `engine = "composite"`. **Do not pass `engine_hint = "ggplot"`** even though patchwork inherits ggplot; passing it forces the wrong engine label and disables `inspect_composite`'s per-panel walk.
7. Validate. Save.

## Code conventions

- Always `library(patchwork)` (or cowplot/aplot) after the per-panel ggplots are constructed; don't pre-declare and risk shadowing.
- Use `(...)` to group panels: `(p1 | p2) / p3` — three panels with p1 and p2 side by side on top, p3 below full width.
- Use `wrap_plots(list(p1, p2, p3, p4), ncol = 2)` for a regular grid. More predictable than chained operators when the layout is rectangular.
- Use `&` (not `+`) when applying themes that should affect all panels: `pw & theme_minimal(base_size = 10)`.
- Use `plot_layout(widths = c(2, 1))` to make the first panel twice as wide.
- Don't fight patchwork: if you need pixel-precise placement, switch to `cowplot::plot_grid` or `cowplot::ggdraw + draw_plot`.

## Reference snippets

A + B (side by side) with shared theme and labeled panels:

```r
library(ggplot2)
library(patchwork)

p1 <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point(size = 2.5) +
  scale_color_brewer(palette = "Dark2") +
  labs(x = "Weight", y = "MPG", color = "Cylinders")

p2 <- ggplot(mtcars, aes(hp)) +
  geom_histogram(bins = 14, fill = "#3B82F6", color = "white") +
  labs(x = "Horsepower", y = "Count")

(p1 | p2) +
  plot_annotation(tag_levels = "A") &
  theme_minimal(base_size = 11) &
  theme(plot.tag = element_text(face = "bold", size = 14))
```

Three panels with a main panel on the left and two small ones stacked on the right:

```r
library(ggplot2)
library(patchwork)

main  <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) + geom_point(size = 3) + theme_minimal()
small1 <- ggplot(mtcars, aes(mpg))  + geom_density(fill = "#94A3B8", alpha = 0.6) + theme_minimal()
small2 <- ggplot(mtcars, aes(wt))   + geom_density(fill = "#94A3B8", alpha = 0.6) + theme_minimal()

main + (small1 / small2) +
  plot_layout(widths = c(2, 1)) +
  plot_annotation(tag_levels = "A")
```

Embedding a non-ggplot grob:

```r
library(ggplot2)
library(patchwork)
library(grid)

p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
note <- wrap_elements(panel = textGrob("Source: mtcars (1974)",
                                       gp = gpar(fontsize = 10, fontface = "italic")))

p / note + plot_layout(heights = c(8, 1))
```

## Anti-patterns

- **Don't pass `engine_hint = "ggplot"` for a patchwork.** A patchwork object inherits ggplot, but the runtime needs the `composite` label to enable per-panel inspection and downstream composite-aware skills. Omit `engine_hint` entirely; auto-detection handles it.
- **Don't apply themes with `+` inside a patchwork.** That applies only to the last panel. Use `&` to apply globally.
- **Don't manually number panels** ("A:", "B:") in titles. Use `plot_annotation(tag_levels = "A")` so the labels are positioned consistently.
- **Don't override `plot.tag` to invisible** in the global theme after using `plot_annotation(tag_levels = "A")` — that strips the very labels you just asked for.
- **Don't use `patchwork` for what `facet_*` can do.** Single ggplot with `facet_wrap` is simpler when the data shape supports it.
- **Don't compose more than ~6 panels.** Past that, faceting or a `wrap_plots(..., ncol = ?)` grid usually communicates better than algebraic composition.

## When to escalate

- For pixel-precise insets, draggable elements, or image overlays — use `cowplot::ggdraw() + draw_plot() + draw_image()`.
- For heatmap + tree composites (ggtree on top of ComplexHeatmap) — use `aplot::insert_top()` / `insert_bottom()` / `insert_left()`.
- If the layout needs to be polished beyond a clean theme — chain into `ggai-figure-polish` on the composite artifact.
