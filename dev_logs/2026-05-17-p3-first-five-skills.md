# 2026-05-17 — P3: First five skills landed

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md) — Phase P3
- **Related ADRs:** [ADR-0003](../dev_docs/decisions/0003-skills-over-tools-for-domain-knowledge.md) (knowledge in skills, not tool descriptions)
- **Related session:** [2026-05-17 — P2: Drop the in-tree agent layer](2026-05-17-p2-drop-agent-layer.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

Discovered on entering P3 that `inst/skills/` already held 12 skill directories from before the refactor:

- 5 P3 targets were empty stubs: `ggai-orchestration`, `ggai-engine-selection`, `ggai-data-plot`, `ggai-figure-polish`, `ggai-direct-figure`.
- 3 were full skills written for the deleted agent runtime: `ggai-goal-agent`, `ggai-plot-agent`, `ggai-acquisition-agent`. They referenced tools that no longer exist (`ggai_update_goal_plan`, `ggai_inspect_plot_attempts`, `ggai_read_url_reference`, ...).
- 4 were domain-agnostic skills that survive the refactor without changes: `ggai-core-persona`, `ggai-r-fonts`, `ggai-reference-figure`, `ggai-single-cell-spatial`.

Decisions:

- **Deleted** the 3 obsolete agent skills — their content is naturally replaced by the new orchestration + task skill set, and rewriting them in place would have been more confusing than starting fresh.
- **Edited** `ggai-core-persona/SKILL.md` to drop the one paragraph that mentioned deleted helpers (`gg_edit`, `as_code`, `spec_history`, `session_context`).
- **Authored** the 5 P3 SKILL.md files from scratch, voice-matched to aisdk's existing skills (sc_marker_dotplot, ppt_as_code).

## Skill design notes

Skills as a system (not five independent files):

- **`ggai-orchestration`** — meta-router. Loaded *only when the goal is ambiguous*; agent skips it for unambiguous goals (the system prompt already says "load the most relevant one"). Its body is a decision table + routing examples + anti-patterns.
- **`ggai-engine-selection`** — orthogonal to task type. Loaded when the figure shape implies a non-ggplot library (ComplexHeatmap, circlize, ggraph, base via recordPlot, htmlwidget, composite). Returns engine choice + rationale; agent then continues with task skill.
- **`ggai-data-plot`** — most common path. Profile → chart type → ggplot code → validate → save. Includes `library(ggplot2)` discipline, factor handling, theme guidance, and three reference snippets (scatter / boxplot / faceted line).
- **`ggai-figure-polish`** — narrowly scoped to "existing figure → image-model redraw". Explicit list of what polish preserves (positions, groups, scales, text *content*) vs may change (typography, palette, surface, annotation styling). Anti-pattern callout: polish does not edit data.
- **`ggai-direct-figure`** — instruction-only illustration. Structured-prompt recipe with six sections (scene summary / objects / relations / visual style / composition / negative prompt). Single-candidate by default; 3-candidate scoring loop with `evaluate_figure_candidate` when stakes are high.

Style discipline across all five:

- YAML frontmatter follows the aisdk convention: `name`, `description` (block scalar `|`), `aliases`, `when_to_use`, `user-invocable: true`.
- Bodies are *decision-shaped*, not workflow-shaped. Headers like "When to use", "Decision table", "Reference snippets", "Anti-patterns", "When to escalate" — not "Step 1 / Step 2 / Step 3".
- Reference snippets are concrete enough to copy-paste, generic enough not to over-fit.

## Findings / decisions

- **YAML scanner gotcha.** `description: |` block scalars work fine, but unquoted scalar values containing a mid-value `: ` (colon + space) trigger `Scanner error: mapping values are not allowed in this context`. My initial `when_to_use: ... Examples: ...` triggered it. Fixed with em-dash. Worth noting in AGENTS.md or in a doc-coauthoring skill if many more SKILL.md files get authored.
- **`system.file("skills", package = "ggai")` works under `devtools::load_all()`.** Confirmed — returns `inst/skills/` correctly. The earlier worry that load_all wouldn't resolve `system.file` was wrong.
- **`agent$skills` is intentionally NULL.** aisdk's `Agent` doesn't expose `skills` as a public field. Skill access is solely through the `load_skill` tool. My smoke test's `length(agent$skills %||% list()) == 0` is a non-bug — it just means I should look at `agent$tools` for `load_skill` instead.
- **aisdk surfaces 7 skill-related tools, not 4.** Got: `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script`, `list_skill_scripts`, `list_available_skills`, `reload_skills`. The system_prompt in `R/agent.R` mentions 4; the extra 3 are discoverable from the tool list at runtime, so this is a soft mismatch, not a bug. Could tighten the system prompt later, but the LLM will figure it out from the tool descriptions.

## Verification

```sh
Rscript -e "
suppressMessages(devtools::load_all('.', quiet = TRUE))
reg <- aisdk::create_skill_registry(system.file('skills', package = 'ggai'))
nrow(reg\$list_skills())   # 9
"
# 9

Rscript -e "testthat::test_dir('tests/testthat')"
# [ FAIL 0 | WARN 0 | SKIP 1 | PASS ~310 ]
```

End-to-end load test:

```r
agent <- ggai_create_agent()
load <- Filter(function(t) identical(t$name, "load_skill"), agent$tools)[[1]]
body <- load$run(list(skill_name = "ggai-orchestration"))
nchar(body)  # > 200, returns the body with aisdk's reply-language guard prepended
```

## Next

P4: smoke test through existing demos.

1. Walk `demo/` (excluded from `R CMD check` via `.Rbuildignore`). Each demo currently expects the pre-refactor API.
2. For each demo, decide:
   - **Update** — rewrite to the new `ggai(goal)` API. Good for demos that show a canonical path the agent should self-route through.
   - **Delete** — drop demos that were tightly bound to the old agent runtime and no longer have a counterpart.
   - **Defer** — for demos that need new skills we haven't built yet (e.g. complex_heatmap demos), park them until P5.
3. Run each surviving demo end-to-end. Verify the agent self-routes to the expected skill and produces a valid artifact.
4. Capture screenshots / outputs for the future `gallery/` showcase (already in TODO).

P4 will surface concrete signals about prompt quality, model behavior, and skill triggering. Expect to refine SKILL.md bodies based on what we observe. Plan for at least two iterations on the most-used skill (`ggai-data-plot`).
