---
name: ggai-figure-polish
description: |
  Lift the visual quality of an existing data figure by redrawing it with an image model that uses the original ggplot as a hard constraint. Preserves data semantics (positions, groups, scales, labels) while improving typography, composition, and surface polish. Use when the user has a working figure but wants it to look like a publication, cover, or polished talk slide.
aliases:
  - "polish this figure"
  - "make this look like a paper"
  - "publication quality"
  - "improve typography"
  - "Nature style"
  - "cover figure"
  - "restyle"
when_to_use: Use when the user already has a ggplot object, ggai_artifact, or rendered PNG and asks for a visual-quality lift while preserving the data story.
user-invocable: true
---

# ggai Figure Polish

Your job: take an existing data figure and produce a polished image-model redraw that does **not** change the underlying data story.

## What you have access to

- `ggai_capability_status()` — reports whether the image model is configured. Call this first to decide the mode.
- `ggai_execute_r(code, engine_hint?)` — for code-mode polish (re-render the ggplot with new styling).
- `polish_figure(x, instruction?, image_model?, output_dir, ...)` — image-model polish primitive. Renders reference images, builds a structured prompt manifest, calls the image model in edit mode, scores candidates, returns the best.
- `prepare_polish_bundle(x, instruction?, output_dir, ...)` — same setup without running the image model. Useful to inspect the manifest before spending tokens.

`polish_figure()` accepts either a `ggplot` object or a ggplot-engine `ggai_artifact`. If the user provides a PNG path with no underlying ggplot, this skill does not apply — load `ggai-direct-figure` and use the PNG as a reference image instead.

## Modes: code polish vs image-model polish

Polish can be achieved two ways. Pick based on three signals — **user intent**, **task fit**, **capability**.

| Signal | **Code polish** — rewrite ggplot via `ggai_execute_r` | **Image-model polish** — call `polish_figure()` |
|--------|------|------|
| User words | "typography", "palette", "theme", "spacing", "tick style", "legend layout", "in ggplot", "axis breaks", "color scale" | "magazine cover", "Cell cover", "integrated illustration", "surface texture", "polished look I can't quite describe", "make it pop", "make it gallery-worthy" |
| Task fit | Edits expressible inside ggplot's grammar (themes, scales, labels, geoms, annotations) | Edits that need pixels ggplot cannot reach (textured backgrounds, decorative artwork, hand-rendered look) |
| Capability | Always available | Requires `image_available = TRUE` from `ggai_capability_status()` |
| Cost | Cheap (one LLM call to write new code), deterministic, vector output | Slower (30–90 s for image-model edit), raster output, harder to iterate on |
| Reproducibility | Full — the new code reproduces the polished figure | Limited — the reproducer just re-calls the image model, output not byte-stable |

**Decision tree** (apply in order):

1. **Capability check.** Call `ggai_capability_status()`. If `image_available` is `FALSE`, code polish is the only option. Note this briefly in your final reply.
2. **Explicit user intent wins.** If the user said "in ggplot" / "rewrite the theme" / named ggplot-internal concepts → code polish. If the user said "cover" / "magazine" / "integrated illustration" / explicitly named the image model → image-model polish. Honor it.
3. **No explicit cue — judge by task fit.** Default to code polish (cheaper, reproducible, vector). Reach for image-model polish only when the polish needs visual elements ggplot can't draw.
4. **"Make it look like a Nature paper" is ambiguous.** Default to code polish — restrained palette, classic typography, generous whitespace are all reachable in ggplot. Reach for image-model polish only if the user adds "with publication-quality texture" or similar visual-surface cues.

State the chosen mode (one sentence) in your final reply so the user understands the trade-off.

## Flow — code polish

1. Identify the source ggplot (from `@`-mention, prior artifact, or by re-running source code).
2. Pull style cues from the user's stated medium. "Nature Methods" → restrained palette, `theme_classic`, serif typography. "Lab meeting slide" → larger base size, fewer panels, direct labels. "Lecture" → bold encodings, big legend.
3. Write new ggplot code that preserves data mappings and adds the polish layers (`theme(...)`, `scale_*_manual(...)`, `labs()`, `guides()`).
4. Call `ggai_execute_r(code, engine_hint = "ggplot")`. Validate. Save with `ggai_save_artifact` (reproducer + PNG + manifest).

### Code-polish snippet

```r
library(ggplot2)

# Preserve mapping; rewrite styling.
p <- ggplot(mtcars, aes(x = wt, y = mpg, color = factor(cyl))) +
  geom_point(size = 3, alpha = 0.92, stroke = 0) +
  scale_color_manual(
    values = c("4" = "#3B6EA8", "6" = "#7A7A7A", "8" = "#B85C4A"),
    name = "Cylinders"
  ) +
  scale_x_continuous(expand = expansion(mult = c(0.04, 0.08))) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.08))) +
  labs(x = "Weight (1000 lbs)", y = "Miles per gallon") +
  theme_classic(base_size = 12, base_family = "serif") +
  theme(
    axis.line = element_line(color = "#2B2B2B", linewidth = 0.45),
    axis.ticks = element_line(color = "#2B2B2B", linewidth = 0.35),
    legend.position = "right",
    legend.box.margin = margin(0, 0, 0, 18),
    plot.margin = margin(12, 24, 12, 12)
  )
p
```

## Flow — image-model polish

1. Identify the source ggplot / artifact.
2. Decide the polish direction (medium + visual texture cues).
3. Call `polish_figure(x, instruction = "<direction>", output_dir = ..., candidate_count = 1)`. Use `candidate_count = 3` only when the user explicitly wants alternatives.
4. Inspect `result$best$path`. If it exists, you're done — `polish_figure` already wrote outputs to `output_dir`. Do NOT re-save with `ggai_save_artifact`.

### Image-model polish snippet

```r
result <- polish_figure(
  my_plot,
  instruction = "Magazine cover style: bold integrated typography, restrained warm palette, generous breathing room, illustrative texture in the background.",
  output_dir = tempdir(),
  candidate_count = 1
)
result$best$path
```

Pre-flight manifest inspection (no image-model call):

```r
bundle <- prepare_polish_bundle(
  my_plot,
  instruction = "Nature Methods style",
  output_dir = tempdir()
)
bundle$manifest_path
bundle$prompt_path
```

## What polish preserves (hard constraints)

- Axis directions, scale logic, and the relative position of every mark.
- The number, identity, and rough cluster shape of all visible groups.
- The text content of titles, labels, axis text, legends, and captions (the image model may restyle their typography, but not change their meaning).
- The presence and relative size of any outlier points or marked highlights.

## What polish may change

- Typography (fonts, weight, hierarchy).
- Palette and shading (within the same semantic role — categorical stays categorical).
- Surface treatment (backgrounds, grids, panel borders).
- Annotation styling (callouts, arrows, highlight boxes).
- Whitespace and proportions.

## Anti-patterns

- **Don't polish before validating the source.** If the source ggplot has warnings or errors, fix those first with `ggai-data-plot`. Polish makes pixels prettier, not data more correct.
- **Don't ask the image model to add data.** No "add a regression line", no "show p-values" — those are ggplot edits, not polish.
- **Don't loop on alternatives.** One round is the default. Two if the user explicitly asks for alternatives. Beyond that you're spending tokens for cosmetic churn.
- **Don't claim the polish result is the data figure.** In your final reply, distinguish: "Source ggplot at `<path>`; polished render at `<path>`." The user may want both.

## When to escalate

- If the source isn't a ggplot/composite artifact — load `ggai-direct-figure` (image-model only) and treat the source PNG as a reference image rather than running polish.
- If the user wants animation or progressive disclosure — this skill doesn't cover that; tell the user and stop.
- If the polish prompt would need to change the data story (e.g. "drop the outlier and re-polish") — go back to `ggai-data-plot`, make the data edit, then return here.
