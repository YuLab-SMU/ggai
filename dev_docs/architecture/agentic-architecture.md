# Agentic Architecture (target state)

> Status: target state for the [2026-05-17 agentic refactor](../../plan/2026-05-17-agentic-refactor-overview.md). Some pieces are still being built; sections marked **[Built]** exist, **[Target]** does not yet.
>
> Last updated: 2026-05-17

## Premise

`ggai` is a domain package on top of [`aisdk`](https://github.com/YuLab-SMU/aisdk). `aisdk` already provides everything an agent runtime needs (ReAct loop, Skill system, ChatSession, Provider abstraction, Mission orchestration). `ggai`'s job is to provide:

1. A small, clean set of **R primitives** for scientific figure work that are easy to call from agent code.
2. A library of **Skills** that teach the agent how to compose those primitives for real figure tasks.
3. A single user-facing entrypoint, `ggai()`, that wires the two together.

Anything beyond that — agent loop, tool routing, session state, provider selection — is `aisdk`'s job, and `ggai` must not reinvent it.

## Three layers

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 3: inst/skills/*   [Target]                             │
│  Domain knowledge as progressive-disclosure SKILL.md packages. │
│  Teach the agent how to compose Layer 2 primitives.            │
└────────────────────────────────────────────────────────────────┘
                          ↑  loaded on demand via aisdk
┌────────────────────────────────────────────────────────────────┐
│  Layer 2: R/ primitives   [Partial]                            │
│  Pure R functions, no tool wrapping, no agent dependency.      │
│  Return structured data; never print, never call dev.new().    │
│                                                                 │
│  Engine-agnostic:                                              │
│    ggai_execute_and_capture(code, env, ...)                    │
│    ggai_render_artifact(artifact, format, path, ...)           │
│    ggai_inspect_artifact(artifact)                             │
│    ggai_validate_artifact(artifact)                            │
│                                                                 │
│  Image and glyph:                                              │
│    ggai_compile_figure_prompt(...)                             │
│    ggai_generate_image(...)                                    │
│    ggai_edit_image_with_refs(...)                              │
│    ggai_evaluate_figure_candidate(...)                         │
│    ggai_generate_glyph(...)                                    │
│    ggai_compose_glyphs_onto_artifact(...)                      │
│                                                                 │
│  Engine adapters (internal):                                   │
│    render_ggplot / render_grid / render_base /                 │
│    render_complex_heatmap / render_circlize / render_htmlwidget│
│    inspect_ggplot / inspect_grob_tree / inspect_recorded / ... │
└────────────────────────────────────────────────────────────────┘
                          ↑  called by Skill scripts / agent code-exec
┌────────────────────────────────────────────────────────────────┐
│  Layer 1: aisdk  [External dependency, Built]                  │
│  Agent / ChatSession / Skill / SkillRegistry / Tool /          │
│  Provider / Mission / generate_text (ReAct)                    │
└────────────────────────────────────────────────────────────────┘
```

## The central data structure: `ggai_artifact`

See [ADR-0002](../decisions/0002-code-first-engine-agnostic-artifact.md).

`ggai_artifact` is the universal unit the system passes around. It is intentionally engine-neutral.

```r
ggai_artifact <- structure(list(
  id         = "fig_<timestamp>_<short_hash>",
  code       = "<full R code that reproduces this figure>",  # canonical
  engine     = "ggplot|grid|base|complex_heatmap|circlize|htmlwidget|composite",
  object     = <R object cache, may be NULL>,                # not canonical
  rendered   = list(png = "...", svg = "...", pdf = NULL),
  data_refs  = list(...),
  packages   = c("ggplot2", "ComplexHeatmap"),
  inspect    = list(...),       # engine-specific introspection
  provenance = list(...)        # which skill / agent step produced this
), class = "ggai_artifact")
```

**Code is canonical, object is cache.** Some engines (base graphics with `recordPlot`) have no clean object representation that survives across sessions or process boundaries. Code is the only reliable source of truth.

## The user-facing entrypoint

```r
ggai(goal, ..., model = NULL, session = NULL, max_steps = 10)
# Internally:
#   agent <- aisdk::create_agent(
#     name         = "ggai",
#     description  = "Scientific figure agent",
#     system_prompt= ggai_system_prompt(),     # short; bulk of guidance lives in skills
#     tools        = ggai_verb_tools(),         # ~3 tools
#     skills       = system.file("skills", package = "ggai"),
#     model        = model %||% ggai_default_models()$language
#   )
#   agent$run(goal, session = session, max_steps = max_steps)
```

No `mode = ` argument. No `polish_figure()` / `generate_final_figure()` parallel entrypoints. The agent decides.

## ggai's tool surface (intentionally tiny)

`aisdk::create_skill_tools(registry)` already provides `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script`. `ggai` adds only verbs that aisdk doesn't:

1. `ggai_execute_r` — run R code in a controlled, graphics-capturing environment; return an `ggai_artifact`.
2. `ggai_validate_artifact` — inspect / validate any engine's artifact.
3. `ggai_save_artifact` — persist artifact (code + rendered files + manifest) to disk and register provenance.

That's it. Everything else is a **primitive** (Layer 2) or **knowledge** (Layer 3).

## Engine support roadmap

| Engine | Priority | Adapter status |
|--------|----------|----------------|
| `ggplot` | Day 1 | Existing code can be lifted from `figure_polish.R` and `compiler.R`. |
| `base` + `recordPlot` | Day 1 | Required for `plot.phylo`, `heatmap`, `dendrogram`, most Bioc plot methods. |
| `grid` / `gTree` | Day 1 | Required for `glyph` composition, `gridExtra`, `patchwork::wrap_elements` non-gg content. |
| `ComplexHeatmap` | High | Genomics workhorse; complex annotation editorial. |
| `circlize` | High | Circular / genomic plots. |
| `composite` (patchwork / cowplot / aplot) | Medium | Recursive inspect needed. |
| `htmlwidget` | Medium | Needs `webshot2` / `chromote`; optional dependency. |
| `gganimate` / `magick` animation | Low | Defer until needed. |

## What is NOT in this architecture

- No `ggai_session` R6 / S3 class. Use `aisdk::ChatSession`.
- No internal Agent class. Use `aisdk::Agent`.
- No ggai-side tool registry. Use `aisdk` tools + Skills.
- No `mode` switch in `ggai()`. The agent routes.
- No `ggplot`-specific assumptions in the polish path. All inspection goes through the engine adapter.

## References

- [ADR-0001: aisdk as the agent runtime](../decisions/0001-aisdk-as-agent-runtime.md)
- [ADR-0002: Code-first engine-agnostic artifact](../decisions/0002-code-first-engine-agnostic-artifact.md)
- [ADR-0003: Knowledge lives in Skills, not in tool descriptions](../decisions/0003-skills-over-tools-for-domain-knowledge.md)
- [Refactor plan (overview)](../../plan/2026-05-17-agentic-refactor-overview.md)
- [Genesis log](../../dev_logs/2026-05-17-agentic-refactor-genesis.md)
