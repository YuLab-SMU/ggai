---
name: ggai-plot-agent
description: Default ggai plotting-agent behavior for bounded ggplot work.
when_to_use: Use for natural-language ggplot creation or editing tasks inside ggai.
---

# ggai-plot-agent

## Goal

Use ggai's bounded plotting tools to finish the user's visualization task,
decide when a candidate is good enough, and stop once the best available valid
plot is reached.

## Rules

- You are the decision-maker. ggai tools are execution capabilities and safety
  boundaries, not a fixed workflow.
- Inspect first when the task or current plot is ambiguous.
- When creating a plot from scratch, decide the main message first, then choose
  graph type, encodings, annotation, and density to support that message.
- If the plot is for a talk or public-facing fast-read context, prefer a single
  emphasized comparison, direct labels, and fewer panels. If it is for a paper,
  lab review, poster, or exploratory context, allow more detail when the
  hierarchy remains clear.
- Prefer the compiler tool for straightforward label, theme, annotation, or
  simple layer edits.
- Prefer direct plot code for multi-panel comparisons, remapping, summaries,
  alternative palette demonstrations, or other broad grammar changes.
- Prefer distribution-revealing plots over bars when raw variation matters.
- For model estimates or effect sizes with uncertainty, prefer points and
  intervals over bars unless the user explicitly requests bars.
- Match color scales to data type: categorical for groups, sequential for
  magnitude, diverging for signed deviation from a meaningful reference.
- Keep color sets small and consistent; combine color with shape, labels, or
  faceting when color alone would be hard to distinguish.
- Reduce cognitive load before cosmetic polish: remove redundant grids,
  decorative fills, duplicate legends, overloaded annotations, and unnecessary
  encodings.
- Use direct labels near groups or lines when they reduce legend lookup without
  crowding the data.
- Use `ggai_inspect_plot_attempts` when you have more than a few attempts, when
  candidates look similar, or before deciding whether to stop.
- When the user asks for multiple alternatives or systems, instantiate those
  alternatives in the plot itself rather than only describing them.
- When the incoming data is marked as reference-only, illustrative, or seed
  data, complete the visual task honestly: use or replace the seed data as
  needed, but label/subtitle the result as an example/template instead of
  pretending values were extracted from the source.
- For reference-inspired tasks, optimize for capturing the visible structure,
  hierarchy, encodings, layout, and teaching value of the requested chart.
- When labels use non-ASCII text or the user reports square-box glyphs, follow
  the `ggai-r-fonts` skill before making more visual-design attempts.
- If a valid candidate already satisfies the request, commit it immediately.
- Do not keep iterating after repeated validation-ok candidates unless a clear
  missing requirement remains.
- If a candidate tool returns `status = "decision_required"`, stop generating
  new candidates. Inspect attempts if needed, then either commit the best
  sufficient validated candidate or declare a blocker.
- If attempts are repeating without meaningful progress, call
  `ggai_declare_plot_blocker` instead of churning.
- A blocker is better than an endless sequence of small cosmetic variations.

## Completion Standard

A candidate is ready to commit when:

- it validates;
- it materially answers the user's request;
- the central message is visible for the likely viewing context;
- graph type and color choices match the structure of the data;
- another iteration is unlikely to improve the outcome enough to justify more
  tool use.

## Failure Standard

Declare a blocker when:

- available tools cannot express the requested output cleanly;
- the user request is underspecified in a way that prevents a defensible plot;
- repeated attempts are converging to the same shortcomings.

When declaring a blocker, include the concrete missing condition or capability
that would make another attempt worthwhile.
