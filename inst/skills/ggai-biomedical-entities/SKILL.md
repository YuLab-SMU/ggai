---
name: ggai-biomedical-entities
description: |
  Generate a single biomedical entity as a reusable cutout asset (transparent alpha background, no labels) suitable for compositing into diagrams. Use when the goal is to produce one isolated subject — a cell, vessel, tissue cutaway, signaling cloud — that will later be placed into a scene, rather than rendering a complete figure.
aliases:
  - "biomedical cutout"
  - "transparent cell illustration"
  - "isolated bio asset"
  - "compositing-ready cell"
when_to_use: Use when the user wants a single reusable biomedical entity with a transparent background, intended for compositing into a larger scene. For whole biomedical figures, use ggai-direct-figure instead.
user-invocable: false
---

# ggai Biomedical Entity Cutouts

Your job: turn an entity description into a transparent-background cutout via the **chroma-key workflow** — generate on a flat `#00ff00` background, then convert that background to alpha locally.

## Critical: gpt-image-2 does not support native transparency

`gpt-image-2` (the default image model) **silently ignores** `background = "transparent"` and returns an opaque image. Do not rely on the model honouring `transparent_background = TRUE` for true alpha output. Instead, prompt for a flat chroma-key background and remove it locally with `ggai_remove_background()`.

Only switch to a true-transparency model (e.g. `gpt-image-1.5` with `background = "transparent"`) when the user explicitly asks for it, or when the subject is too complex for chroma-key removal (hair, fur, feathers, smoke, glass, liquids, translucent or reflective materials, soft shadows). Ask before switching.

## Atomic capabilities

- `ggai_generate_image(model, prompt, output_dir, width, height, quality, ...)` — calls the configured image model. **Do not** pass `transparent_background = TRUE` and expect alpha; use the chroma-key flow below.
- `ggai_remove_background(path, key_color = "#00ff00", ...)` — chroma-key removal with soft matte + dominance + despill. Defaults match the official Codex `imagegen` skill's recommended invocation.
- `ggai_asset_cache_key(...)`, `ggai_asset_cache_get(key)`, `ggai_asset_cache_put(src, key, metadata)` — reuse cutouts across calls.

## gpt-image-2 size constraints

Pixel-count and edge constraints (the model rejects requests that violate these):

- Max edge ≤ `3840px`
- Both edges must be multiples of `16px`
- Long-to-short edge ratio ≤ `3:1`
- **Total pixels in `[655,360, 8,294,400]`**

Safe defaults for cutouts (all valid for gpt-image-2):

| Entity | Recommended size | Notes |
|--------|------------------|-------|
| Cells (tumor, T cell, myeloid, cytokine, cell therapy) | `1024 × 1024` | Fastest square option |
| Blood vessel | `1536 × 1024` | Landscape for elongated subjects |
| Tissue cutaway | `1536 × 1024` | Landscape for wider scenes |

Do **not** use `768 × 768` — that is `589,824` pixels, below gpt-image-2's `655,360` minimum and will be rejected.

## Quality

Pass `quality = "low"` for fast draft iterations, `"medium"` or `"high"` for final cutouts (especially when subject detail matters or text/labels will be added on top). Default to `"high"` for cutouts since they get reused.

## Prompt schema

Use this labeled-line scaffold. Fill in the slots; drop lines that don't apply. Keep additions tasteful — do not invent style notes the user didn't ask for.

```
Use case: biomedical-entity-cutout
Subject: <specific entity from the catalogue or adapted>
Style/medium: clean biorender-style biomedical illustration, isolated subject cutout, no labels
Composition/framing: centered subject with generous padding
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal
Constraints: background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation; crisp silhouette; do not use #00ff00 anywhere in the subject
Avoid: checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars, contact shadow, cast shadow
```

### Specificity policy

- If the user's prompt is already specific (named entity + style cues + size), normalize it into the schema above without adding creative requirements.
- If the prompt is generic ("a cell"), pull a Subject phrase from the catalogue and apply the shared Style/Constraints/Avoid lines.

### Entity catalogue (Subject phrase)

| Entity | Subject phrase |
|--------|----------------|
| Tumor cell | `stylized biomedical tumor cell, semi-transparent membrane, visible nucleus, scientific figure illustration` |
| Activated T cell | `stylized activated T cell, rounded membrane with receptor details, scientific figure illustration` |
| Myeloid cell | `stylized immunosuppressive myeloid cell, irregular immune cell morphology, scientific figure illustration` |
| Blood vessel | `stylized blood vessel segment cross-section, endothelial wall, lumen visible, scientific figure illustration` |
| Tissue cutaway | `stylized tissue cutaway with layered extracellular matrix, scientific biomedical figure illustration` |
| Cytokine cloud | `stylized cytokine cloud, signaling molecules and diffusion effect, scientific figure illustration` |
| Cell therapy product | `stylized engineered therapeutic immune cell, programmable cell therapy, scientific figure illustration` |

For entities outside the catalogue, follow the same pattern: name the subject specifically, append `scientific figure illustration`, apply the shared Style + Constraints + Avoid lines.

## End-to-end flow

```r
subject <- "stylized activated T cell, rounded membrane with receptor details, scientific figure illustration"
style   <- "clean biorender-style biomedical illustration, isolated subject cutout, no labels"
chroma  <- paste(
  "perfectly flat solid #00ff00 chroma-key background for background removal",
  "background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation",
  "keep the subject fully separated from the background with crisp edges and generous padding",
  "do not use #00ff00 anywhere in the subject",
  "no cast shadow, no contact shadow, no reflection, no watermark, no text",
  sep = ", "
)
avoid <- "Avoid: checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars"

prompt <- paste(subject, style, chroma, avoid, sep = ", ")

out <- ggai_generate_image(
  model = ggai_image_model(),
  prompt = prompt,
  output_dir = tempdir(),
  width = 1024, height = 1024,
  quality = "high"
)

raw_path <- out$images[[1]]$path
cutout   <- ggai_remove_background(raw_path, key_color = "#00ff00")
```

`cutout` is a PNG with a true alpha channel, cropped to the subject's bounding box, with despilled edges.

### Choosing the key colour

- Default `#00ff00` (pure green).
- If the subject contains green (e.g. cytokine cloud rendered green), switch to `#ff00ff` (magenta) and tell the model `do not use #ff00ff anywhere in the subject`.
- Avoid `#0000ff` (blue) — many illustrations use blue accents that would be falsely keyed.

### When `ggai_remove_background()` is not enough

If validation shows green fringes, halos, or jagged edges:
1. First retry with a more constrained prompt (`crisp edges`, `do not use #00ff00 anywhere in the subject`, `no soft edge bloom`).
2. If the cutout is still poor, ask the user whether to fall back to a true-transparency model (`gpt-image-1.5` with `background = "transparent"`).

Do not silently downgrade models.

## Multi-candidate generation

If the first cutout is poor (subject too small, weird artifacts, key bleed-through), generate 2–3 candidates with the same prompt and pick by inspection. The agent decides — there is no pre-baked scoring function.

## Caching across calls

```r
key <- ggai_asset_cache_key(
  caller = "bio_entity",
  entity = "t_cell",
  prompt = prompt,
  width = 1024, height = 1024,
  model = ggai_image_model()
)
hit <- ggai_asset_cache_get(key)
if (!is.null(hit)) return(hit)

# … generate + ggai_remove_background …

ggai_asset_cache_put(cutout, key, metadata = list(entity = "t_cell", prompt = prompt))
```

Reuse the same `key` across sessions to skip regeneration of identical entities.
