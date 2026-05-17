# 2026-05-17 — Agentic refactor genesis

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md)
- **Related ADRs:** [ADR-0001](../dev_docs/decisions/0001-aisdk-as-agent-runtime.md), [ADR-0002](../dev_docs/decisions/0002-code-first-engine-agnostic-artifact.md), [ADR-0003](../dev_docs/decisions/0003-skills-over-tools-for-domain-knowledge.md)
- **Related commits / PRs:** (pending — first commits land under P0/P1 of the refactor plan)
- **Worked on by:** Yonghe Xia

## What happened

Walkthrough of the existing `ggai` codebase to identify why the current design fights itself, followed by a target-state design session and the construction of this dev doc suite.

### Diagnosis

`ggai()` currently has three hard-coded paths:

1. **Session mode** — `data + instruction → language model → ggplot R code → render`
2. **Polish mode** — `ggplot/session + instruction → reference images + prompt → image model edit → polished PNG`
3. **Direct figure mode** — `instruction → language model → prompt spec → image model generate → PNG`

These are three fixed compositions of atomic capabilities. They violate the agentic principle: an agent should *decide* how to compose capabilities, not be forced into one of three pre-baked pipelines.

Inventory of existing tools showed that the code side is reasonably well-decomposed (22 atomic tools in `R/agent_tools.R`), but the image side is monolithic. Functions like `polish_figure()`, `generate_final_figure()`, and `prepare_polish_bundle()` weld together rendering, overlay extraction, prompt building, image model calls, candidate evaluation — all things that should be primitives the agent can mix.

### Design decisions

In order:

1. **Don't reinvent the agent loop.** `aisdk` already provides Agent + ReAct + Skill + Session + Provider. ggai keeps none of its own runtime → [ADR-0001](../dev_docs/decisions/0001-aisdk-as-agent-runtime.md).
2. **Use Skills, not tools, for "knowledge".** ~22 ggai tools collapse to ~3 verb tools; everything else moves to `inst/skills/*` → [ADR-0003](../dev_docs/decisions/0003-skills-over-tools-for-domain-knowledge.md).
3. **Drop ggplot as the central object.** `ggai_artifact` becomes the universal unit; engine adapters dispatch on `artifact$engine`. Code is canonical; the R object is cache → [ADR-0002](../dev_docs/decisions/0002-code-first-engine-agnostic-artifact.md). Motivation: ggplot-centrism cuts off ComplexHeatmap, circlize, base graphics, htmlwidgets — the majority of bioinformatics visualization.
4. **Destructive refactor is acceptable.** Project is early; no external users to protect. `polish_figure()`, `generate_final_figure()`, `ggai(mode=...)`, `ggai_session` all get removed.

### Doc suite built today

- `AGENTS.md` — repo guidelines + development workflow (idea → plan → code → log → ADR loop)
- `CHANGELOG.md` — Keep a Changelog format
- `TODO.md` — global backlog (migrated from lowercase `todo.md`)
- `dev_docs/architecture/agentic-architecture.md` — target architecture
- `dev_docs/decisions/{README, _template, 0001, 0002, 0003}.md` — ADR set
- `dev_logs/{README, _template, this}.md` — log infrastructure
- `plan/{README, _template, 2026-05-17-agentic-refactor-overview}.md` — plan infrastructure + the first plan
- `idea/README.md` — idea index seed
- `.Rbuildignore` — updated to exclude the four dev directories

## Findings / decisions

- aisdk's `Agent$run(task, session, ...)` already does ReAct end-to-end via `generate_text(tools, max_steps, session)`. No wrapper needed in ggai beyond a thin factory.
- aisdk's `create_skill_tools(registry)` returns `load_skill` / `list_skill_resources` / `read_skill_resource` / `execute_skill_script`. ggai gets these for free.
- aisdk has a minor ggplot bias in the optional `agent_library.R` (a `VisualizerAgent`), but the core (`agent.R`, `skill.R`, `session.R`) is engine-neutral. ggai's engine extension does not require aisdk changes.
- Base graphics + `recordPlot` returns session-bound objects. Confirms code-as-canonical decision in ADR-0002.

## Verification

No code changes yet — pure design + documentation. Verified the doc tree:

```
ggai/
├── AGENTS.md
├── CHANGELOG.md
├── TODO.md
├── dev_docs/{architecture,decisions}/
├── dev_logs/
├── plan/
└── idea/
```

## Next

Execute the refactor plan in order:

1. **P1 — Layer 2 primitives:** lift `figure_polish.R` / `figure_generation.R` / `compiler.R` internals into engine-agnostic primitives. Start with `ggai_execute_and_capture()` + `ggai_artifact` + ggplot/base/grid adapters.
2. **P2 — Drop the agent layer:** delete `R/agent_runtime.R`, `R/goal_agent.R`, `R/agent_tools.R`, `R/agentic_edit.R`, `R/session_*.R`, `R/spec_committer_agent.R`. Rewrite `ggai()` as a ~30-line `aisdk::create_agent()` wrapper.
3. **P3 — Author the first 5 skills:** `orchestration`, `engine-selection`, `data-plot`, `figure-polish`, `direct-figure`.
4. **P4 — Smoke test:** rerun representative demos with the new agent.

P1–P4 target: within one focused work block.
