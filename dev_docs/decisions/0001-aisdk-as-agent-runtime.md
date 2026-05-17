# ADR-0001: aisdk as the agent runtime

- **Status:** Accepted
- **Date:** 2026-05-17
- **Deciders:** Yonghe Xia
- **Related:** [plan/2026-05-17-agentic-refactor-overview.md](../../plan/2026-05-17-agentic-refactor-overview.md), [dev_logs/2026-05-17-agentic-refactor-genesis.md](../../dev_logs/2026-05-17-agentic-refactor-genesis.md)

## Context

`ggai` currently ships its own agent loop (`R/agent_runtime.R`, `R/goal_agent.R`, `R/agent_tools.R`, `R/agentic_edit.R`, the `ggai_session` machinery in `R/session_*.R`). At the same time, the project depends on `aisdk`, which already provides:

- `Agent` R6 class with a built-in ReAct loop (`Agent$run()` → `generate_text(tools, max_steps, session)`)
- `ChatSession` for shared state, memory, environment
- `Skill` + `SkillRegistry` with progressive disclosure (L1 frontmatter, L2 body, L3 scripts/refs)
- `create_skill_tools(registry)` exposing `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script` as agent tools out of the box
- Provider abstraction across OpenAI / Anthropic / Gemini / DeepSeek / Bailian / Aihubmix / custom
- Mission / multi-agent orchestration

Keeping both is unjustifiable duplication. Maintaining `ggai`'s in-tree agent loop would (a) require continuous porting of `aisdk` improvements, (b) confuse contributors about where the real runtime lives, (c) prevent `ggai` Skills from being shareable across other aisdk-based agents.

## Decision

**`ggai` does not own an agent runtime.** All agent loop, session, provider, and skill-loading concerns are delegated to `aisdk`. `ggai`'s public entrypoint `ggai(goal, ...)` becomes a thin factory that builds an `aisdk::Agent` configured with:

- A short system prompt
- A tiny tool surface (~3 verb tools that aisdk doesn't already provide)
- `skills = system.file("skills", package = "ggai")` for auto-discovery
- A model resolved through `aisdk`'s provider stack

The files `R/agent_runtime.R`, `R/goal_agent.R`, `R/agent_tools.R`, `R/agentic_edit.R`, `R/spec_committer_agent.R`, `R/session_*.R` are removed.

## Alternatives considered

- **Keep ggai's runtime and depend on aisdk only for providers.** Rejected: duplicates ReAct, Skill, and Session implementations indefinitely. Already drifting.
- **Fork aisdk for ggai-specific changes.** Rejected: same author, single ecosystem; better to upstream improvements.
- **Wait until ggai's needs diverge from aisdk's.** Rejected: speculative. Today's needs are well-covered; tomorrow's divergence can be handled with a focused aisdk extension PR.

## Consequences

### Positive

- ~6 source files deleted; codebase shrinks meaningfully.
- ggai inherits every aisdk improvement (token budgeting, provider additions, observability) for free.
- ggai Skills become portable: any aisdk-based agent can load them.
- Single source of truth for what an "agent" means in this stack.

### Negative / accepted tradeoffs

- ggai is tightly bound to aisdk's API surface. Breaking changes in aisdk require ggai updates.
- Project-early breakage of users of `polish_figure()` / `generate_final_figure()` / `ggai(mode=...)` — accepted because the project is in early development.

### Follow-ups

- Delete the listed files in P2 of the refactor plan.
- Replace `ggai_session` references with `aisdk::ChatSession` throughout.
- Migrate `spec_committer_agent.R` schema validation to `aisdk::generate_text(schema = ...)`.
