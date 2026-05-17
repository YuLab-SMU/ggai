# 2026-05-17 — P4: Smoke test through real LLM calls

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md) — Phase P4
- **Related session:** [2026-05-17 — P3: First five skills landed](2026-05-17-p3-first-five-skills.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)
- **Models used:** `openai:gpt-5.5` (language) via custom endpoint, `openai:gpt-image-2` (image)

## What happened

First real end-to-end runs of the refactored stack. Five smoke goals across three task paths, all on a live LLM.

| Smoke | Goal | Elapsed | Skill loaded | Tool sequence | Artifact |
|-------|------|---------|--------------|---------------|----------|
| 1 | `@mtcars Show mpg vs wt coloured by cyl ...` | 21.5 s | `ggai-data-plot` | load → exec → validate → save | Publication-grade scatter with Brewer Dark2, suppressed minor grid |
| 2 | `@mtcars Boxplot of mpg by cyl ...` | 21.5 s | `ggai-data-plot` | load → exec → validate → save | Boxplot |
| 3 | `@mtcars Distribution of mpg as a histogram ...` | ~21 s | `ggai-data-plot` | load → exec → validate → save | Histogram |
| 4 | `Draw a clean scientific illustration of a CRISPR-Cas9 knockout ...` | 65.7 s | `ggai-direct-figure` | load → exec → validate → save | 120-line grid-graphics R script that hand-draws Cas9 + sgRNA + DNA helix + DSB. Title overflowed canvas. |
| 5 | `Polish for Nature Methods: restrained palette, classic typography ...` | 32.1 s | `ggai-figure-polish` | load → exec → validate → save | Serif `theme_classic` + manual restrained palette + thoughtful margins / ticks / legend. Pure ggplot, no image model. |

## Findings

### What works

- **Self-routing is deterministic.** Three different "data + chart-type" goal phrasings (scatter, boxplot, histogram) all routed to `ggai-data-plot` on the first try. Direct-figure and polish goals routed to their respective skills correctly.
- **The tool sequence the agent followed matches the skills' suggested flow exactly**: `load_skill` → `ggai_execute_r(engine_hint = "ggplot")` → `ggai_validate_artifact` → `ggai_save_artifact`. Four tool calls, five ReAct steps (4 tool + 1 final reply).
- **Token cost is modest.** A single data-plot run used 4590 total tokens; at typical gpt-5-class rates that's < $0.005 per figure. Image-model paths (when used) add image-generation cost on top.
- **The `@mtcars` mention resolved correctly** before the agent saw the goal. The agent used `mtcars` directly inside the code without needing to `get("mtcars", envir = ...)`.
- **The data-plot output is genuinely publication-grade.** The agent picked Brewer Dark2 palette, `theme_minimal(base_size = 12)`, suppressed the minor grid, used `factor(cyl)` for grouping — every choice matches the skill's anti-pattern guidance.

### What surfaced (and matters for skill iteration)

**1. The agent prefers the cheap, vector, deterministic R-code path over the image-model path.**

In Smoke 4 (CRISPR illustration), my `ggai-direct-figure` skill prominently features `ggai_generate_image()` and an image-model candidate-loop. The agent loaded the skill — and then wrote a 120-line `grid` graphics R script that draws Cas9 / sgRNA / DNA helix / DSB symbol manually with `grobTree`. **It never called `ggai_generate_image()`.**

In Smoke 5 (polish), my `ggai-figure-polish` skill features `polish_figure()` (the image-model redraw primitive). The agent loaded the skill — and then **rewrote the source ggplot** with serif typography, manual palette, theme_classic, careful legend spacing. **It never called `polish_figure()`.**

This is the agentic principle working as intended: the agent has agency over which lever to pull, and `ggai_execute_r` is cheaper / more deterministic / vector / customizable than the image-model alternatives. The agent made smart trade-offs.

But the skills currently *imply* the image-model path is canonical. They should explicitly acknowledge both modes:
- **Code polish / code illustration** — ggplot or grid edits via `ggai_execute_r`. Cheap, vector, deterministic, customizable. Default for most cases.
- **Image-model polish / generation** — `polish_figure()` or `ggai_generate_image()`. Use when the desired result needs illustrative texture, integrated typography, or a cover-figure visual that ggplot/grid cannot reach naturally.

Filed as follow-up: refine `ggai-direct-figure` and `ggai-figure-polish` to articulate this trade-off. Move guidance from "implied canonical path" to "explicit dual mode".

**2. Grid render adapter has a title-overflow issue.**

Smoke 4's CRISPR diagram had its title rendered as `ISPR-Cas9 knockout: guide RNA directs Cas9 to cut target D` — the first and last few characters clipped against the canvas edges. The agent's code positions the title at `y = unit(0.94, "npc")` with `gp = gpar(fontsize = 20, fontface = "bold")`. With a 1200×900 default canvas at 150 dpi, that's enough margin in principle but the `textGrob` doesn't insure against glyph overflow on wide titles.

Two ways to fix:
- **Render adapter:** wrap `grid.draw(grob)` in a `viewport()` with inner margin allowance.
- **Skill snippet:** anchor titles further inside (`y = 0.91`) and wrap them via `paste0(..., "\n", ...)` when long.

Filed as follow-up; the second is easier and lives in `ggai-direct-figure` skill content.

**3. `system_prompt` mentions 4 skill tools but aisdk provides 7.**

The runtime actually exposes `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script`, `list_skill_scripts`, `list_available_skills`, `reload_skills`. My `ggai_system_prompt()` only lists the first four. The agent figured the rest out from the tool list, but tightening the prompt to mention `list_available_skills` (the entry-point for skill discovery) would shorten the first ReAct step on new tasks.

Filed as a low-priority follow-up.

### What we *didn't* see (interesting non-events)

- No tool-call errors.
- No `engine_hint` misuse.
- No agent hallucinating column names or function names.
- No retry loops.
- No image-model API errors despite using a custom OpenAI-compatible endpoint.

## Verification

All five smoke outputs are preserved under `demo_outputs/p4_*/`:

```
demo_outputs/
├── p4_smoke/         smoke1.{R,png,json}   — scatter
├── p4_smoke2/        smoke2*.{R,png,json}   — boxplot
├── p4_smoke3/        smoke3.{R,png,json}    — histogram
├── p4_direct_figure/ crispr.{R,png,json}    — CRISPR illustration (grid)
└── p4_polish/        polished1.{R,png,json} — Nature-style polish (ggplot)
```

The PNGs visually validate as expected (scatter is honest, polish is restrained, illustration is creditable despite the title clip).

## Next

Two natural directions, in priority order:

### P4.b — Skill iteration (low-cost, high-leverage)

Based on findings (1) and (2), edit `ggai-direct-figure` and `ggai-figure-polish` to:
- Add a "Modes" section explicitly listing code-path vs image-model-path, with criteria for each.
- Add a "Common rendering pitfalls" section (grid title overflow, etc).
- Re-smoke against the same goals; verify the agent still picks the right mode and the title issue is gone.

### P5 — Engine adapter expansion

The original P5 scope: ComplexHeatmap + circlize adapters. After P4, the priorities haven't changed but a new sub-question is open: should the engine adapters also include a *render-area sanity check* (clip detection, margin assertion) to catch issues like the title overflow proactively?

### What to skip

The original P4 plan asked for editing the existing `demo/biorender_*` etc. demo scripts. Those were tightly bound to the old agent runtime and the deleted compile pipeline. **They will not be updated**; they'll be deleted in a small cleanup pass, and replaced over time with cleaner demos derived from the smoke runs above (which can become the seed for the eventual `gallery/`).
