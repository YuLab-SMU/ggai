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

- `polish_figure(x, instruction?, image_model?, output_dir, ...)` — the L2 primitive. Renders the input ggplot to reference images (base render + geometry overlay + layout overlay), builds a structured prompt manifest, calls the image model in edit mode, scores candidates, and returns the best.
- `prepare_polish_bundle(x, instruction?, output_dir, ...)` — same setup without running the image model. Useful when you want to inspect the manifest before spending tokens.
- `ggai_execute_r(code, engine_hint?)` — for any pre-step that produces a ggplot you then pass to `polish_figure`.

`polish_figure()` accepts either a `ggplot` object or a ggplot-engine `ggai_artifact`. If the user provides a PNG path with no underlying ggplot, this skill does not apply — load `ggai-direct-figure` and use it as a reference image instead.

## Flow

1. **Identify the source figure.** It may be:
   - A `@`-mentioned ggplot in the caller environment → use directly.
   - A `@`-mentioned `ggai_artifact` (engine = `ggplot` or `composite`) → use directly.
   - A file path to a script that produces a ggplot → run via `ggai_execute_r` first.
2. **Decide the polish direction** from the user's stated medium and style cues. Examples:
   - "Nature Methods" → restrained palette, clear hierarchy, generous whitespace, classic serif/sans labels.
   - "lab meeting slide" → larger labels, single emphasized comparison, fewer panels.
   - "magazine cover" → bolder treatment, integrated typography, more illustrative texture.
3. **Call `polish_figure(x, instruction = "<direction>")`** through `ggai_execute_r`. Use `candidate_count = 1` by default; bump to 3 only if the user wants alternatives.
4. **Inspect the returned `best$path`** — if it exists, you're done. If validation downstream produces a warning, mention it in the final reply.
5. **Save** is implicit: `polish_figure` writes to `output_dir`. Don't re-save with `ggai_save_artifact` — that's for the *primary* artifact, not polish results.

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

## Reference snippets

Basic polish from a ggplot in the caller frame (passed via mention):

```r
result <- polish_figure(
  my_plot,
  instruction = "Polish for Nature Methods: restrained palette, clear hierarchy, classic typography.",
  output_dir = tempdir()
)
result$best$path
```

Polish a ggai_artifact:

```r
result <- polish_figure(
  artifact,
  instruction = "Lab meeting slide: bigger labels, one emphasized comparison.",
  output_dir = tempdir()
)
```

Pre-flight manifest only (no image model call):

```r
bundle <- prepare_polish_bundle(
  my_plot,
  instruction = "Magazine cover style",
  output_dir = tempdir()
)
bundle$manifest_path  # JSON describing the constraint set
bundle$prompt_path    # the prompt the image model will see
```

## Anti-patterns

- **Don't polish before validating the source.** If the source ggplot has warnings or errors, fix those first with `ggai-data-plot`. Polish makes pixels prettier, not data more correct.
- **Don't ask the image model to add data.** No "add a regression line", no "show p-values" — those are ggplot edits, not polish.
- **Don't loop on alternatives.** One round is the default. Two if the user explicitly asks for alternatives. Beyond that you're spending tokens for cosmetic churn.
- **Don't claim the polish result is the data figure.** In your final reply, distinguish: "Source ggplot at `<path>`; polished render at `<path>`." The user may want both.

## When to escalate

- If the source isn't a ggplot/composite artifact — load `ggai-direct-figure` (image-model only) and treat the source PNG as a reference image rather than running polish.
- If the user wants animation or progressive disclosure — this skill doesn't cover that; tell the user and stop.
- If the polish prompt would need to change the data story (e.g. "drop the outlier and re-polish") — go back to `ggai-data-plot`, make the data edit, then return here.
