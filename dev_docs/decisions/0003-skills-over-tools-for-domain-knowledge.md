# ADR-0003: Domain knowledge lives in Skills, not tool descriptions

- **Status:** Accepted
- **Date:** 2026-05-17
- **Deciders:** Yonghe Xia
- **Related:** [ADR-0001](0001-aisdk-as-agent-runtime.md), [ADR-0002](0002-code-first-engine-agnostic-artifact.md), [dev_docs/architecture/agentic-architecture.md](../architecture/agentic-architecture.md)

## Context

The current `R/agent_tools.R` registers 22 tools (`ggai_data_profile`, `ggai_stat_method_selection`, `ggai_help_inspection`, `ggai_diagram_compilation`, ...). Most of them are not really verbs the agent invokes mechanically; they are **knowledge encoded as tool descriptions and execute bodies**. The descriptions tell the agent "when to use this" — which is the same job a SKILL.md does, but worse: tool descriptions are always loaded into context (token cost), and knowledge gets entangled with execution.

`aisdk` already provides:

- `Skill` class with progressive disclosure (L1 frontmatter / L2 body / L3 scripts and references)
- `create_skill_tools(registry)` which auto-registers `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script`
- `create_agent(skills = "auto" | path)` to auto-discover skills

This is strictly more flexible than baking knowledge into tools.

## Decision

**Knowledge lives in `inst/skills/<skill-name>/SKILL.md`.** Tools are reserved for true verbs the agent invokes mechanically. `ggai` exposes only ~3 verb tools to the agent:

1. `ggai_execute_r` — run R code in a graphics-capturing environment; return a `ggai_artifact`.
2. `ggai_validate_artifact` — validate any artifact via the engine adapter.
3. `ggai_save_artifact` — persist code + rendered files + manifest; register provenance.

Everything previously expressed as a tool (data profiling, stat method selection, help inspection, source URL detection, diagram compilation, ...) moves into a SKILL.md. The SKILL.md tells the agent **when** to do something and **how** to compose the L2 primitives via `ggai_execute_r`. Reusable code snippets live in the skill's `scripts/` subfolder and are invoked via aisdk's `execute_skill_script`.

## Alternatives considered

- **Keep all 22 tools.** Rejected: token cost (tool descriptions are always in context), and tool descriptions are a poor medium for narrative guidance.
- **Hybrid: tools for hot paths, skills for cold paths.** Rejected as muddled. Doesn't simplify the contract. Adopting it later is cheap if we discover a true hot-path verb.
- **Skills only, zero tools.** Rejected: the agent still needs raw R execution and artifact persistence as fast verbs. Three is the right minimum.

## Consequences

### Positive

- Token-cheap on cold queries: the agent only loads SKILL.md bodies it needs.
- Skills are portable across aisdk-based agents; not coupled to `ggai`-specific tool wiring.
- Adding a new domain (single-cell, phylogenetics, etc.) = add a folder under `inst/skills/`. No code change.
- Narrative knowledge ("for survival curves, prefer log-rank annotation in the upper-right") fits skills natively; it would be awkward as a tool description.

### Negative / accepted tradeoffs

- Agent must do an extra step (`load_skill`) before acting on a skill. Mitigated by the `ggai-orchestration` meta-skill that's always loaded first.
- Skill discovery quality depends on YAML frontmatter `description` and `aliases`. Maintaining good triggering metadata is a continuous job.
- Cannot rely on tool-call telemetry alone to understand what the agent did; need to track `load_skill` events too.

### Follow-ups

- Phase P3 of the refactor plan: write the first 5 skills (`orchestration`, `engine-selection`, `data-plot`, `figure-polish`, `direct-figure`).
- Delete `R/agent_tools.R` once those skills cover the existing knowledge.
- Establish a convention for skill scripts (input args via `args$<name>`, return list, never print).
