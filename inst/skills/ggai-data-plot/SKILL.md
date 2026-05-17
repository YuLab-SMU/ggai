---
name: ggai-data-plot
description: |
  Turn a data frame plus a natural-language instruction into a publication-quality data figure. Default engine is ggplot2; escalate to ComplexHeatmap / circlize / ggraph / base via `ggai-engine-selection` when ggplot would force contortions. Use whenever the user's goal references a tabular data source (by name, `@`-mention, file path, or "this data" anaphora) and asks for a visualization.
aliases:
  - "data plot"
  - "make a plot"
  - "show this data"
  - "ggplot from data"
  - "visualize the data"
when_to_use: Use when the user goal pairs a tabular data source with a visualization request — scatter, box, bar, line, histogram, heatmap, or similar of one or more columns.
user-invocable: true
---

# ggai Data Plot

Your job: produce a valid, faithful, communicative figure from a user-supplied data frame.

## What you have access to

- `ggai_execute_r(code, engine_hint?)` — runs R code in a graphics-capturing environment and returns an artifact summary. The last value of the code should be the figure object.
- `ggai_validate_artifact()` — validates the most recent artifact.
- `ggai_save_artifact(output_dir, prefix?)` — persists code + rendered file + manifest.
- The goal text may include `@`-mentions for caller-frame objects. ggai already resolved them and appended structured context to your task. Look at that context to find the data frame name, columns, and row count.

## Flow

1. **Read the resolved mention context** (appended to your task). It tells you the data frame's name, columns, and column types. Don't reinvent this with `head()` calls unless you need value distributions.
2. **Decide the chart type.** Map the user's verbs and column types:
   - "X vs Y" with two numeric → scatter.
   - "X by group" with one numeric + one factor → boxplot or violin.
   - "count of X" / "frequency of X" → bar.
   - "X over time" with a time column → line.
   - "distribution of X" → histogram or density.
   - Otherwise default to scatter if there's a sensible (numeric x, numeric y) pair, else histogram.
3. **Write the code.** Reference the data frame by the caller-environment name. Always start with `library(ggplot2)` (or `ggplot2::` qualified) so the reproducer code stands alone. Keep aesthetics minimal first; iterate on style only after the data mapping is right.
4. **Call `ggai_execute_r`** with the code. Inspect the returned `validation_status`.
5. **If validation reports `error`,** read the message, fix the code, re-execute. Common causes: column names with spaces, factor vs character mismatches, missing package.
6. **If validation reports `warning`,** decide: is the warning meaningful (e.g. dropped rows)? Mention it in your final reply; don't loop trying to silence it.
7. **Save the artifact** with `ggai_save_artifact` to `output_dir = tempdir()` (or whatever path the user requested).
8. **In your final reply,** state the chart type, the engine, the saved paths, and a one-sentence what-the-figure-shows note.

## Code conventions

- Use `library(ggplot2)` once at the top. Don't redundantly load it.
- Use the data frame's *unquoted* column names inside `aes()`. Factors get `factor(col)` explicitly when discrete encoding is intended.
- For coloring by a factor: `color = factor(col)` not `color = col`.
- For ordered factors that have a natural order (e.g. species, dosage): set levels explicitly with `factor(col, levels = c(...))` rather than relying on alphabetical default.
- Prefer `theme_minimal()` over the gray default; switch to `theme_classic()` for paper-style if the user mentioned a paper context.
- Don't add a title unless the data dimensions or message demand one. The data and axis labels usually carry the message.

## Reference snippets

Scatter with color group:

```r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point(size = 2.5) +
  labs(x = "Weight (1000 lbs)", y = "Miles per gallon", color = "Cylinders") +
  theme_minimal()
```

Boxplot across groups:

```r
library(ggplot2)
ggplot(mtcars, aes(factor(cyl), mpg, fill = factor(cyl))) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.15, alpha = 0.5) +
  labs(x = "Cylinders", y = "Miles per gallon") +
  theme_minimal() +
  theme(legend.position = "none")
```

Faceted line over time:

```r
library(ggplot2)
ggplot(economics_long, aes(date, value01, color = variable)) +
  geom_line() +
  facet_wrap(~ variable, scales = "free_y") +
  theme_minimal()
```

## Anti-patterns

- **Don't hide the variation behind bars.** For raw data, prefer `geom_jitter` / `geom_dotplot` / `geom_boxplot` over `geom_bar(stat = "summary", fun = "mean")`.
- **Don't add error bars from `geom_errorbar(stat = "summary")` without naming the underlying statistic.** If you need uncertainty, compute it explicitly.
- **Don't mix incompatible scales** (e.g. log-scaled axis with `scale_y_continuous(breaks = ...)`).
- **Don't pile on themes.** One `theme_*()` + at most one targeted `theme(...)` override.
- **Don't infer columns that don't exist** in the resolved mention metadata. If the user mentions a column by name that isn't in the data, ask or pick the closest match and state your guess.

## When to escalate

- If the user mentions ComplexHeatmap-flavored requirements ("annotation tracks", "split rows by", "row dendrogram"), load `ggai-engine-selection` and re-route to ComplexHeatmap.
- If the user wants single-cell specific output (UMAP, DotPlot, FeaturePlot, VlnPlot), load `ggai-single-cell-spatial` for stylistic conventions.
- If the user provides a reference image, load `ggai-reference-figure` to extract style cues before plotting.
- If the user asks for the result to "look like a Nature figure" or similar after the data plot is done, chain into `ggai-figure-polish`.
