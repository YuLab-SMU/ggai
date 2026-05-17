---
name: ggai-orchestration
description: |
  Meta-router for ggai goals. Load this skill first when the user's goal is ambiguous, multi-modal, or could plausibly map to more than one of: data plot, figure polish, direct illustration, glyph-augmented chart, or iterative edit. The skill classifies intent and tells you which downstream skill to load next. Skip this skill and load a task skill directly when the goal is unambiguous (e.g. a clear data-plot phrasing or a clear "draw a cartoon" phrasing).
aliases:
  - "what should I do"
  - "how do I start"
  - "ggai routing"
  - "figure intent"
  - "agent orchestration"
when_to_use: Use when the user's request has multiple plausible execution paths, mixes goals (e.g. "plot this and make it look like a paper figure"), is too short to classify confidently, or you are unsure which skill applies.
user-invocable: true
---

# ggai Orchestration

You are routing a figure goal. Your job is to read the goal, classify it into one of the canonical task shapes, and then call `load_skill("<chosen-skill>")` before doing anything else.

## Canonical task shapes

| Shape | Signals | Skill to load |
|-------|---------|----|
| **Data plot** | Goal references a data frame (by name, `@`-mention, or file path); words like *show / scatter / bar / boxplot / heatmap / vs / over / by* with column names. | `ggai-data-plot` |
| **Figure polish** | Goal references an existing ggplot/artifact/PNG path; words like *polish / publication / Nature / Cell / cover / cleaner / typography / restyle*. | `ggai-figure-polish` |
| **Direct illustration** | Goal asks for a schematic, diagram, cartoon, biomedical illustration; no data; words like *draw / illustrate / diagram / cartoon / sketch*. | `ggai-direct-figure` |
| **Engine choice** | The user names a non-ggplot library (`ComplexHeatmap`, `circlize`, `ggraph`, `plotly`, ...) or describes a figure that ggplot can't easily produce (annotated genomic heatmap, circular genome, network, interactive). | `ggai-engine-selection` (first), then the task skill from the row above. |

For composite goals — e.g. "plot this and then polish it" — load the **first** skill the goal implies (usually `ggai-data-plot`), produce the artifact, then load the second skill (`ggai-figure-polish`) before continuing.

## Routing examples

- "@mtcars show mpg vs wt, color by cyl" → `ggai-data-plot`.
- "draw a CRISPR knockout diagram with three guide RNAs" → `ggai-direct-figure`.
- "polish @my_plot for Nature Methods" → `ggai-figure-polish`.
- "plot @expr_matrix as a heatmap with sample annotation on top" → `ggai-engine-selection` (recommends ComplexHeatmap), then back to a task path.
- "make this look like the figure in @paper.pdf" → `ggai-reference-figure`, then either `ggai-figure-polish` or `ggai-data-plot` depending on whether user data is involved.

## When to skip orchestration

Skip this skill and go straight to a task skill when:

- The goal trivially matches one shape (data + chart type words, or only "draw a ..." with no data).
- You have already loaded a task skill this turn and the user is iterating within it.

There is no value in re-routing on every turn. Route once, then commit to the path.

## Anti-patterns

- **Don't call `ggai_execute_r` before routing.** Decide the skill first; primitives are levers, not the plan.
- **Don't load multiple skills speculatively.** Pick one. If you discover mid-execution that a different skill applies, switch then.
- **Don't return routing as the final answer.** Your final reply to the user must reference the produced artifact. Routing is internal.
- **Don't ignore the user's stated medium.** If the user said "for a paper", carry that forward into the chosen skill's stylistic choices.

## After routing

Immediately call `load_skill("<chosen-skill>")` and follow that skill's guidance. Mention in your final reply *what* you produced (engine, file path), not *how* you routed.
