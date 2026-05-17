---
name: ggai-direct-figure
description: |
  Produce a schematic, illustration, biomedical cartoon, or pure conceptual figure without underlying data. Calls an image model directly with a structured prompt, generates one or more candidates, scores them on basic visual proxies, and saves the best. Use when the goal is "draw / illustrate / diagram / sketch" and no data frame is in scope.
aliases:
  - "draw an illustration"
  - "biomedical diagram"
  - "schematic figure"
  - "scientific cartoon"
  - "concept diagram"
  - "no data figure"
when_to_use: Use when the user asks for an illustration, schematic, diagram, or biomedical cartoon and there is no tabular data driving the figure.
user-invocable: true
---

# ggai Direct Figure

Your job: turn a description into a polished illustration via direct image generation.

## What you have access to

- `ggai_generate_image(model, prompt, output_dir, width, height, transparent_background, ...)` — calls an image model and returns one or more rendered images.
- `evaluate_figure_candidate(path, prompt_spec?)` — scores a rendered image on sharpness, clutter, blankness, and visual complexity. Useful for picking the best of N candidates.
- `ggai_image_model()` — returns the configured image model identifier.
- `ggai_figure_resolution()` — returns the default (width, height) for figure-class outputs.

## Flow

1. **Read the user's intent.** Identify: subject(s), relationships, composition (left/right/center, lanes), medium (cartoon vs realistic vs schematic vs marker-and-paper feel), background.
2. **Compose a structured prompt** with these sections, in order:
   - One-paragraph **scene summary** in clear declarative language.
   - **Objects**: named items to depict ("activated T cell with engaged TCR", "MHC-I complex with peptide", ...).
   - **Relations**: spatial or causal ("T cell on the left engages tumor cell on the right via TCR-MHC contact").
   - **Visual style**: e.g. "clean scientific illustration with crisp edges, BioRender-style flat shading, high legibility".
   - **Composition**: "balanced horizontal composition with large readable labels, strong separation between objects, low text density".
   - **Negative prompt**: things to avoid (watermarks, tiny text, dense annotation, photo-realism unless asked).
3. **Call `ggai_generate_image`** through `ggai_execute_r`. Use `candidate_count = 1` (cheap) unless the user asks for alternatives or the request is high-stakes (cover, publication), in which case `candidate_count = 3` and pick the best via `evaluate_figure_candidate`.
4. **Inspect the rendered path.** If it exists and the file size is reasonable (> 50 KB), you're done.
5. **Save with `ggai_save_artifact`.** Note: the artifact's `engine` will be `unknown` (image-model output isn't a code-produced figure); the code field will be the R reproducer that calls `ggai_generate_image` with the same prompt, so future re-execution is meaningful.
6. **In your final reply**, state the saved path and a one-sentence description of the figure. Optionally include the prompt summary so the user can iterate.

## Reference snippets

Single-candidate generation:

```r
result <- ggai_generate_image(
  model = ggai_image_model(),
  prompt = paste(
    "Clean scientific illustration of a CRISPR-Cas9 knockout workflow.",
    "Three guide RNAs targeting a single locus on a chromosome.",
    "Left panel: Cas9 protein loaded with a guide RNA approaching DNA.",
    "Middle panel: double-strand break.",
    "Right panel: edited DNA with indel.",
    "Style: flat scientific illustration, BioRender-like, clean palette, large readable labels, white background.",
    "Avoid: watermarks, tiny text, photo-realism."
  ),
  output_dir = tempdir(),
  width = 1600, height = 900,
  transparent_background = FALSE
)
result$images[[1]]$path
```

Multi-candidate with scoring:

```r
prompt <- "..."  # built as above
imgs <- ggai_generate_image(
  model = ggai_image_model(),
  prompt = prompt,
  output_dir = tempdir(),
  n = 3,
  width = 1600, height = 900
)
scored <- lapply(imgs$images, function(im) {
  list(path = im$path, score = evaluate_figure_candidate(im$path)$score)
})
best <- scored[[which.max(vapply(scored, function(x) x$score, numeric(1)))]]
best$path
```

## Prompt-writing heuristics

- **Be specific about subjects.** "A T cell" is weak; "an activated CD8+ T cell with extended TCR" is strong.
- **State the composition explicitly.** Image models default to centered single-subject framings; if you want three panels, say "three panels arranged left-to-right".
- **Always include the negative prompt.** Watermarks, dense text, checkerboard transparency, meme styles, stock-photo realism — image models love producing these unless told not to.
- **Match style to medium.** Paper supplements → clean flat illustration. Talks → bolder treatment, larger shapes. Covers → more illustrative texture.
- **Constrain text density.** "Large readable labels, minimal text density, no captions inside the image" — image models render text poorly; minimize it.

## Anti-patterns

- **Don't generate without a structured prompt.** A one-line "draw a CRISPR diagram" gets you stock-image quality. Build the scene + objects + relations + style explicitly.
- **Don't expect text to render correctly.** Use the prompt to add abstract symbols (arrows, blobs, panels); add real text in post via a ggplot/grid overlay if needed.
- **Don't loop more than 3 candidates.** If 3 fail, the prompt structure needs revision, not more samples.
- **Don't claim the figure represents real data.** Direct-illustration outputs are illustrative; if the user later wants a data figure, route to `ggai-data-plot`.

## When to escalate

- If the user later supplies data and wants the illustration "with my numbers" — load `ggai-data-plot` and treat the illustration as a reference for layout/style.
- If the user wants the illustration integrated with a ggplot (e.g. as a glyph) — out of scope for this skill; tell the user and stop.
- If the user wants animation or multi-frame — out of scope; image models render single frames.
