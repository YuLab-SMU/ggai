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

- `ggai_capability_status()` — reports whether the image model is configured. Call this first to decide the mode.
- `ggai_generate_image(model, prompt, output_dir, width, height, quality, ...)` — calls an image model and returns one or more rendered images. With `gpt-image-2`, `transparent_background = TRUE` is silently ignored; use the chroma-key workflow + `ggai_remove_background()` for true alpha.
- `evaluate_figure_candidate(path, prompt_spec?)` — scores a rendered image on sharpness, clutter, blankness, visual complexity. Useful for multi-candidate picks.
- `ggai_image_model()` — returns the configured image model identifier.
- `ggai_figure_resolution()` — returns the default `(width, height)` for figure-class outputs.

## Modes: code path vs image-model path

Direct figures can be produced two ways. Pick based on three signals — **user intent**, **task fit**, **capability**.

| Signal | **Code mode** — write R via `ggai_execute_r` (grid / ggplot) | **Image-model mode** — call `ggai_generate_image()` |
|--------|------|------|
| User words | "in R", "reproducible code", "ggplot", "grid", "vector", "SVG", "PDF figure", "I want to edit it later" | "BioRender style", "realistic", "photorealistic", "anatomically detailed", "tissue section", "cover figure", "watercolor", "3D render" |
| Task fit | Geometric primitives, schematic flows, labeled boxes / arrows, panel layouts, anything the user will tweak | Naturalistic illustration, soft shading, texture, integrated typography that survives raster, single-shot artwork |
| Capability | Always available | Requires `image_available = TRUE` from `ggai_capability_status()` |
| Cost | Cheap, deterministic, vector output | Slower (often 30–60 s per candidate), raster output, harder to iterate on |

**Decision tree** (apply in order):

1. **Capability check.** Before reaching for image-model mode, call `ggai_capability_status(probe = TRUE)`. This sends a lightweight POST to the configured image endpoint to confirm the route actually exists — config-only checks can wrongly report "configured" when a custom OpenAI-compatible proxy doesn't serve `/v1/images/generations`. If `image_available` is `FALSE`, code mode is the only option. Note this briefly in your final reply. (For code mode, no probe is needed — saves a roundtrip.)
2. **Explicit user intent wins.** If the goal says "in R" / "ggplot" / "vector" / "reproducible code" → code mode. If the goal says "BioRender" / "realistic" / "cover figure" / names a visual texture → image-model mode. Honor it.
3. **No explicit cue — judge by task fit.** Default to code mode for editable, schematic, or labeled-diagram outputs. Choose image-model only when the user clearly wants naturalistic illustration or a surface texture R cannot draw.
4. **When unsure, prefer code mode.** It is cheaper, deterministic, vector-friendly, and the user can always ask for an image-model pass on top.

State the chosen mode (one sentence) in your final reply so the user understands the trade-off.

## Flow — code mode (grid / ggplot)

1. Decide composition. Sketch coordinates in your head: which objects go where, how labels attach, what the canvas margins need to be.
2. Use `grid` for free-form schematic / illustration work, `ggplot` for any data-driven layer. `ggplotify::as.grob()` bridges them when you want to embed a ggplot in a grid composition.
3. Anchor titles inside the canvas, not at `y = 0.94` or higher — grid clips at the viewport edge and long titles overflow. Use `y = 0.90` with reasonable margins, or wrap long titles via `\n`.
4. Write code whose **last value is the figure object** (a `grob` / `gTree` / ggplot). Engine detection then picks `grid` (or `ggplot`) correctly.
5. Call `ggai_execute_r(code, engine_hint = "grid")` (or `"ggplot"`). Validate. Save.

### Code-mode snippet

```r
library(grid)

fig <- grobTree(
  rectGrob(gp = gpar(fill = "white", col = NA)),
  # left: stylized protein blob
  roundrectGrob(x = unit(0.22, "npc"), y = unit(0.50, "npc"),
                width = unit(0.22, "npc"), height = unit(0.22, "npc"),
                r = unit(0.04, "npc"),
                gp = gpar(fill = "#8B5CF6", col = "#5B21B6", lwd = 2.5)),
  # right: target / outcome
  rectGrob(x = unit(0.74, "npc"), y = unit(0.50, "npc"),
           width = unit(0.20, "npc"), height = unit(0.20, "npc"),
           gp = gpar(fill = "#3B82F6", col = "#1E3A8A", lwd = 2)),
  # connecting arrow
  segmentsGrob(x0 = unit(0.36, "npc"), y0 = unit(0.50, "npc"),
               x1 = unit(0.62, "npc"), y1 = unit(0.50, "npc"),
               arrow = arrow(type = "closed", length = unit(0.025, "npc")),
               gp = gpar(col = "#111827", lwd = 3)),
  # labels — anchor inside the canvas
  textGrob("Cas9", x = unit(0.22, "npc"), y = unit(0.68, "npc"),
           gp = gpar(fontsize = 16, fontface = "bold")),
  textGrob("target DNA", x = unit(0.74, "npc"), y = unit(0.68, "npc"),
           gp = gpar(fontsize = 16, fontface = "bold", col = "#1E3A8A")),
  # title anchored inside, not at top edge
  textGrob("CRISPR-Cas9 knockout (schematic)",
           x = unit(0.50, "npc"), y = unit(0.90, "npc"),
           gp = gpar(fontsize = 18, fontface = "bold"))
)
fig
```

## Flow — image-model mode (`ggai_generate_image`)

1. **Compose a structured prompt** with six sections, in order:
   - **Scene summary** (one paragraph, declarative).
   - **Objects** (named items: "activated CD8+ T cell with extended TCR", "MHC-I complex with peptide").
   - **Relations** (spatial / causal: "T cell on the left engages tumor cell on the right via TCR-MHC contact").
   - **Visual style** ("clean scientific illustration with crisp edges, BioRender-like flat shading, high legibility").
   - **Composition** ("balanced horizontal composition with large readable labels, strong separation between objects").
   - **Negative prompt** ("watermarks, tiny illegible text, dense annotation, photo-realism unless asked, checkerboard transparency").
2. Call `ggai_generate_image` via `ggai_execute_r`. Default `n = 1`. Use `n = 3` only for high-stakes outputs (cover, publication) and pick the best via `evaluate_figure_candidate`.
3. Validate the returned path exists with reasonable file size (`> 50 KB`).
4. Save with `ggai_save_artifact`. The artifact's `engine` will be `unknown` (image-model outputs aren't engine-tagged); the saved code is a reproducer that re-runs `ggai_generate_image` with the same prompt.

### Image-model snippet

```r
result <- ggai_generate_image(
  model = ggai_image_model(),
  prompt = paste(
    "Clean scientific illustration of CRISPR-Cas9 cutting a DNA target.",
    "Cas9 protein on the left, guide RNA threading into the active site,",
    "DNA double helix on the right with the cut site clearly indicated.",
    "Style: flat BioRender-like illustration, restrained palette, large readable labels, white background.",
    "Composition: balanced horizontal layout, strong separation between objects, low text density.",
    "Avoid: watermarks, tiny text, photo-realism, checkerboard transparency."
  ),
  output_dir = tempdir(),
  width = 1536, height = 1024,   # gpt-image-2 landscape (see size constraints below)
  quality = "high"
)
result$images[[1]]$path
```

### gpt-image-2 size and quality constraints

The default image model is `gpt-image-2`. Pick `width`/`height` that satisfy all of:

- Max edge ≤ `3840px`
- Both edges multiples of `16px`
- Long-to-short ratio ≤ `3:1`
- **Total pixels in `[655,360, 8,294,400]`**

Safe sizes:

| Aspect | Size | When |
|--------|------|------|
| Square | `1024 × 1024` | Fast default |
| Landscape | `1536 × 1024` | Scientific figures, talks |
| Portrait | `1024 × 1536` | Posters |
| 2K square | `2048 × 2048` | Print-quality square |
| 4K landscape | `3840 × 2160` | Cover figures, posters |

`quality` is `"low"` (fast drafts), `"medium"`, `"high"`, or `"auto"`. Use `"low"` for iteration, `"high"` for final assets and dense text/labels.

### Transparent backgrounds with gpt-image-2

`gpt-image-2` does **not** honour the API's `background = "transparent"` parameter — it silently returns an opaque image. If the user wants a transparent cutout:

1. Prompt for a perfectly flat solid `#00ff00` chroma-key background.
2. Generate as usual.
3. Run `ggai_remove_background(path, key_color = "#00ff00")` to convert the key colour to alpha.

For single biomedical entity cutouts intended for compositing, prefer the `ggai-biomedical-entities` skill which packages this workflow.

Only switch to a true-transparency model (e.g. `gpt-image-1.5`) when the subject is too complex for chroma-key removal (hair, fur, smoke, glass, soft shadows) — and ask the user first.

Multi-candidate with scoring:

```r
imgs <- ggai_generate_image(
  model = ggai_image_model(),
  prompt = "...",
  output_dir = tempdir(),
  n = 3,
  width = 1536, height = 1024,
  quality = "high"
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
