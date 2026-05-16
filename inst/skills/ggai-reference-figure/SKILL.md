---
name: ggai-reference-figure
description: Guidance for adapting paper figures, screenshots, and reference images to user data in ggai.
when_to_use: Use when the user says to draw a plot like a reference image, article figure, screenshot, paper figure, example chart, or style sample.
---

# ggai-reference-figure

## Goal

Turn reference-figure requests into honest, data-faithful ggplot work. The
reference may be a local image path, article path, URL, screenshot, paper
figure, method description, or a phrase such as "use my data to draw this kind
of plot".

Do not require fixed arguments such as `reference_image=` or `reference_mode=`.
Infer the reference role from the user's natural-language request and available
context.

## Reference Roles

Classify the reference before acting:

- **Style reference**: borrow palette, typography, spacing, legend treatment,
  annotation style, visual hierarchy, and overall finish.
- **Structure reference**: borrow chart family, coordinate system, panel layout,
  grouping strategy, statistical layer, ordering, legend placement, and
  annotation pattern.
- **Method reference**: use the user's method description or article text to
  choose the analysis and plot grammar; the image is secondary.
- **Data remake**: use the user's data as the factual source and recreate the
  visual idea with new values.
- **Polish reference**: first make a validated ggplot from the user's data,
  then use image-level polish only for final raster presentation.

One request can combine several roles. Prefer this priority:

1. user data truth;
2. requested analysis/method;
3. intended message and communication context;
4. chart structure;
5. style reference;
6. final polish.

## Working Procedure

1. Identify all usable inputs from the prompt and session: data frames, file
   paths, reference images, article/Markdown/PDF paths, URLs, user method
   descriptions, and existing plots.
2. Decide whether the user needs an editable ggplot, a final polished image, or
   both. If unsure, produce an editable ggplot first.
3. Extract or infer the reference's communication brief when possible: main
   message, audience, viewing context, expected interaction, and level of
   detail.
4. If the prompt includes actual multimodal image input, inspect the image
   directly with the model's vision capability. Do not spend R steps on pixel
   sampling, OCR, ASCII previews, or palette extraction unless direct vision is
   unavailable or a precise numeric artifact is explicitly needed.
5. If visual inspection is available, extract only robust visual facts:
   chart type, encodings, layout, facet structure, approximate palette,
   annotation style, and legend treatment.
6. If visual inspection is not available, do not block by default. Use the
   method description, article text, file name, or user-provided explanation as
   a reference brief. State assumptions in the source note.
7. Map the user's data to the reference structure with ggplot grammar. Do not
   copy values from the reference unless the user explicitly asks for data
   extraction and the extraction is reliable.
8. Adjust graph density to the target context. Borrow complexity only when the
   user's audience and medium can support it.
9. Use the reference style after the data mapping is correct: palette, theme,
   label hierarchy, legend placement, panel spacing, and annotations.
10. Validate the ggplot before committing. If the user later asks for stronger
   polish, continue from the committed ggplot or use the image polish path.

## What To Preserve

For structure references, preserve the intent rather than the pixels:

- chart family such as scatter/PCA, volcano, heatmap, dot plot, bar summary,
  box/violin, trajectory, network, map, timeline, or multi-panel figure;
- semantic encodings such as color for group, size for magnitude, shape for
  class, facet for condition, and label for selected entities;
- comparison logic such as case/control, before/after, ranked terms, clusters,
  or treatment groups;
- message hierarchy such as the single takeaway for a talk or the richer
  inspection structure for a paper/poster;
- important layout relationships such as panel order, legend position,
  annotation callouts, and guide hierarchy.

For style references, preserve only styling:

- approximate palette and contrast;
- background and grid density;
- typography scale and hierarchy;
- axis, legend, caption, and label treatment;
- use of highlight colors, halos, connectors, or inset labels.

## Communication Context

When adapting a reference, do not copy its density blindly:

- lab meetings can tolerate method detail and raw-level diagnostics because
  discussion can clarify complexity;
- posters can support detail, but the figure should still be quickly scannable;
- talks and public lectures need fewer messages, stronger hierarchy, and direct
  annotation;
- papers can carry more information if structure, labels, and captions support
  repeated inspection;
- online or dashboard contexts can use overview-first layouts with optional
  detail, facets, filtering, or companion tables.

## Honesty Rules

- The user's data is the source of truth for plotted values.
- A reference image is not evidence for the user's data.
- Do not pretend that approximate colors, labels, or values were extracted
  exactly from an image.
- If values are simulated, illustrative, or inferred from a method description,
  say so in the source note or subtitle.
- If exact reverse-engineering is required but unavailable, state the missing
  condition and offer the closest honest template.

## Completion Standard

Commit when the plot:

- uses the user's data or clearly disclosed illustrative data;
- matches the requested reference role well enough for the next edit turn;
- fits the intended audience, viewing time, and interaction level when known;
- validates as a ggplot;
- has a source note that separates user data, reference guidance, assumptions,
  and unsupported visual inferences.

## Failure Standard

Declare a blocker only when:

- the user requires exact extraction from an inaccessible or unreadable
  reference;
- no usable data or method description is available and an illustrative
  template would be misleading;
- current tools cannot create the requested chart family in ggplot without
  inventing unsupported structure.
