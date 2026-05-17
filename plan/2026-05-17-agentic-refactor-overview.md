# Agentic Refactor — Overview & Phase Plan

> Status: **active**. Opened 2026-05-17. Owner: Yonghe Xia.

**Goal:** Replace ggai's three hard-coded paths (`session` / `polish` / `direct figure`) with a single agent entrypoint that composes engine-agnostic primitives via Skills, delegating Agent / ReAct / Session / Provider concerns entirely to `aisdk`.

**Why now:** See [dev_logs/2026-05-17-agentic-refactor-genesis.md](../dev_logs/2026-05-17-agentic-refactor-genesis.md). The fixed paths violate the agentic principle; ggplot-centrism cuts off the majority of bioinformatics visualization; ggai duplicates aisdk's runtime.

**Architecture:** Three layers — `aisdk` (Layer 1, external), ggai R primitives (Layer 2, in `R/`), Skills (Layer 3, in `inst/skills/`). The central data structure is `ggai_artifact` with engine adapters. See [`dev_docs/architecture/agentic-architecture.md`](../dev_docs/architecture/agentic-architecture.md).

**Out of scope:**
- No CRAN submission concerns this phase.
- No backward compatibility shims — project is early, destructive refactor is acceptable ([ADR-0001](../dev_docs/decisions/0001-aisdk-as-agent-runtime.md)).
- No new engine adapters beyond ggplot / base / grid in P1. ComplexHeatmap / circlize / htmlwidget are P5+.
- No `gallery/` / `showcase/` work (tracked in `TODO.md`).

**Tech stack:** R, `aisdk` (>= 1.2.0), `ggplot2`, `grid`, `grDevices`, `ragg`, `svglite`. Optional: `ComplexHeatmap`, `circlize`, `webshot2` (later phases).

**Verification:**
- `ggai("draw a CRISPR knockout diagram, no data needed")` produces a PNG via image model only — agent self-routes, no `mode` arg.
- `ggai("@mtcars show mpg vs wt, color by cyl")` produces a ggplot artifact and a rendered PNG.
- `ggai(<existing ggplot>, "polish for Nature Methods")` produces a redrawn image referencing the original plot.
- `ggai("plot a Heatmap of @expr_matrix with top annotation by @sample_meta$group")` produces a ComplexHeatmap artifact (after P5).
- `R/agent_runtime.R` and friends are deleted; `wc -l R/*.R` significantly lower than baseline.

---

## Progress tracking

**Status legend**
- `[ ]` Not started · `[~]` In progress · `[x]` Completed · `[!]` Blocked · `[-]` Cancelled

**Overall progress**
- [x] Phase P0: Build the doc suite (this file, ADRs, dev_docs, dev_logs, AGENTS.md, CHANGELOG.md, TODO.md, .Rbuildignore)
- [x] Phase P1: Extract Layer 2 primitives (engine-agnostic; ggplot/base/grid adapters) — completed 2026-05-17
- [x] Phase P2: Drop the in-tree agent layer; rewrite `ggai()` as an aisdk thin wrapper — completed 2026-05-17
- [x] Phase P3: Author the first 5 skills (`orchestration`, `engine-selection`, `data-plot`, `figure-polish`, `direct-figure`) — completed 2026-05-17
- [ ] Phase P4: Smoke test via existing demos
- [ ] Phase P5: ComplexHeatmap + circlize adapters
- [ ] Phase P6: Composite / htmlwidget adapters

---

### Phase P0: Build the doc suite

**Status:** `[x]` — completed 2026-05-17

**Files**
- Create: `AGENTS.md`, `CHANGELOG.md`, `TODO.md`
- Create: `dev_docs/{README, architecture/agentic-architecture}.md`
- Create: `dev_docs/decisions/{README, _template, 0001, 0002, 0003}.md`
- Create: `dev_logs/{README, _template, 2026-05-17-agentic-refactor-genesis}.md`
- Create: `plan/{README, _template, this}.md`
- Create: `idea/README.md`
- Modify: `.Rbuildignore` (exclude `dev_docs/`, `dev_logs/`, `plan/`, `idea/`, `TODO.md`)
- Delete: `todo.md` (migrated to `TODO.md`)

**Intent**
- Land the closed-loop dev workflow (idea → plan → code → log → ADR) before any code changes, so the refactor itself is fully traceable.

**Verification**
- `ls dev_docs dev_logs plan idea` shows the four directories populated.
- `R CMD build .` would not pick up dev files (visual check of `.Rbuildignore`).

---

### Phase P1: Extract Layer 2 primitives

**Status:** `[x]` — completed 2026-05-17

**Files**
- Create: `R/artifact.R` — `ggai_artifact()` constructor, `print.ggai_artifact()`, `is_ggai_artifact()`.
- Create: `R/execute.R` — `ggai_execute_and_capture(code, env, format, engine_hint, ...)`.
- Create: `R/render.R` — `ggai_render_artifact()` dispatcher + internal `render_ggplot()`, `render_base()`, `render_grid()`.
- Create: `R/inspect.R` — `ggai_inspect_artifact()` dispatcher + internal `inspect_ggplot()`, `inspect_recorded()`, `inspect_grob_tree()`.
- Create: `R/validate.R` — `ggai_validate_artifact()` dispatcher.
- Modify: `NAMESPACE` — export the new primitives.
- Test: `tests/testthat/test-artifact.R`, `tests/testthat/test-execute-capture.R`, `tests/testthat/test-engine-adapters.R`.

**Intent**
- Establish the engine-agnostic core so subsequent phases can lean on it. After P1, every primitive returns structured data and is callable from Skill scripts.

**Checklist**
- [x] Define `ggai_artifact` class + constructor + minimal print method. — `R/artifact.R`.
- [x] Implement `ggai_execute_and_capture()` with auto engine detection for ggplot / composite / grid / base; accept `engine_hint`. — `R/execute.R`.
- [x] Implement `ggai_render_artifact()` dispatcher with ggplot / grid / base adapters; prefer `ragg::agg_png` / `svglite::svglite` when available, fall back to `grDevices`. — `R/render.R`.
- [x] Implement `ggai_inspect_artifact()` dispatcher. ggplot inspector reuses `build_plot_context()` / `summarize_plot_layers_for_polish()` / `extract_layout_regions()` / `summarize_plot_data_contract()`. — `R/inspect.R`.
- [x] Implement `ggai_validate_artifact()` dispatcher — `R/validate.R`. (Adds a fourth public verb alongside inspect/render/execute; useful both inside the agent loop and as a standalone QC entrypoint.)
- [x] Add `tests/testthat/test-artifact.R` covering: constructor, predicates, print, slot coercion (6 tests).
- [x] Add `tests/testthat/test-execute-capture.R` covering: ggplot / base / grid auto-detection, engine_hint override, error surfacing, SVG output (7 tests).
- [x] Add `tests/testthat/test-engine-adapters.R` covering: inspect / validate / render per engine (9 tests).
- [x] `Rscript -e "devtools::document()"` clean — regenerated `man/ggai_*_artifact.Rd` etc.
- [x] Manual NAMESPACE update — repo's NAMESPACE is hand-managed (no roxygen marker), so the new `export(...)` and `S3method(...)` lines were added by hand.

**Deferred to P2 (scope refinement, see "Scope changes" below)**
- Lift `compile_figure_prompt` / `evaluate_figure_candidate` / `ggai_generate_image` / `ggai_edit_image` to the new `ggai_*` naming convention (already exported, low priority; cleaner to do as part of P2's API consolidation).
- Refactor `R/figure_polish.R` to consume `ggai_inspect_artifact()` output — the existing public functions still work; the consumer switch makes more sense when `polish_figure()` itself is being rewritten in P2.
- `devtools::check()` full clean — pending background run; baseline already has unrelated warnings that need a separate pass.

**Verification**
- `testthat::test_dir('tests/testthat')` — 468 PASS / 0 FAIL / 1 SKIP (`visual-regression` skip is pre-existing on-CRAN guard).
- The three new test files contribute 22 of the 468 tests.
- Smoke: `ggai_execute_and_capture('ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()')` returns `engine = "ggplot"`, populated `rendered$png`, `inspect$plot_context`.
- `R/agent_runtime.R` / `goal_agent.R` / etc. untouched — P1 is purely additive.

---

### Phase P2: Drop the in-tree agent layer

**Status:** `[x]` — completed 2026-05-17

**Files**
- Delete: `R/agent_runtime.R`, `R/goal_agent.R`, `R/agent_tools.R`, `R/agentic_edit.R`, `R/spec_committer_agent.R`, `R/session_state.R`, `R/session_edit.R`, `R/session_methods.R`, `R/context_bridge.R`.
- Refactor: `R/ggai_entry.R` — strip `mode` argument; keep the dispatch on `x` type (string / file / ggplot / artifact); body becomes `aisdk::create_agent()` + `agent$run()`.
- Refactor: `R/print.R` — remove `print.ggai_session` and related.
- Refactor: `R/data.R`, demos — replace `ggai_session` references with artifact + `aisdk::ChatSession`.
- Modify: `NAMESPACE` — remove deleted exports.
- Delete: man pages for removed functions (regenerate via `devtools::document()`).

**Intent**
- Excise duplicated runtime. Force the rewrite to lean on aisdk; reveal any remaining hidden ggai-side state.

**Checklist**
- [x] Delete the doomed source files — twelve in total ended up going (the planned nine plus `R/geom_ai_add.R`, `R/spec_inspection.R`, `R/compiler.R`, `R/acquisition_runtime.R`).
- [x] Add the new agent stack additively (P2.a): `R/agent.R`, `R/tools.R`, plus `ggai_save_artifact()` in `R/artifact.R`. New tests in `tests/testthat/test-verb-tools.R` and `tests/testthat/test-agent-factory.R` pass alongside the existing suite.
- [x] Rewrite `ggai()` as ~150 lines (entry + `@`-mention plumbing): build agent → run agent → return `{result, artifact, artifacts}`.
- [x] Strip `mode = "session" | "polish" | "auto"` from the function signature; remove all S3 methods on `ggai`.
- [x] Surgical edits to drop session/spec-committer references from surviving files — `figure_polish.R`, `figure_generation.R`, `dependency_tools.R`, `validation_tools.R`, `print.R`, `entrypoints.R`.
- [x] `polish_figure()` and `prepare_polish_bundle()` survive as primitives; `compile_figure_prompt()` and `generate_final_figure()` removed (they depended on the deleted spec-committer agent; will return as Skill-driven helpers in P3+).
- [x] `geom_ai()` removed (its `ggplot_add.ggai_layer_request` dispatcher was in the deleted agentic-edit stack).
- [x] Manually update `NAMESPACE` — repo convention is hand-managed, so 30 dead S3 methods + 21 dead exports were removed by hand and the new file is reorganized by layer with comments.
- [x] Find/replace `ggai_session` → either delete (where pure session ops) or `ggai_artifact` (where polish needed a plot reference).
- [x] Remove broken tests: deleted `test-agent-runtime.R`, `test-agent-tools.R`, `test-geom-ai.R`, `test-acquisition-runtime.R`, `test-diagram-ai.R`, `test-figure-generation.R`, `test-domain-template-cases.R` (7 files). Refactored `test-validation-tools.R`, `test-dependency-tools.R`, `test-package-load.R` to test the surviving surface. Removed one session-coupled test from `test-figure-polish.R`.
- [x] `devtools::document()` clean.
- [x] `testthat::test_dir('tests/testthat')` runs 0 FAIL / 1 SKIP across 23 test files (up from the P1 baseline of 25 test files; 2 lost to deletion, ~3 reduced in scope).

**Verification**
- `wc -l R/*.R` shows 6218 lines across 38 files. Pre-P2 baseline: ~10k lines across 47 files. **~38% reduction.**
- Full test suite: `0 FAIL / 0 WARN / 1 SKIP` (skip is pre-existing on-CRAN guard in `test-visual-regression.R`).
- Smoke: `ggai_create_agent()` returns an `aisdk::Agent`; `agent$tools` includes the three ggai verb tools; `attr(agent, "ggai_state")` is a fresh state environment.

---

### Phase P3: Author the first 5 skills

**Status:** `[x]` — completed 2026-05-17

**Files**
- Create: `inst/skills/ggai-orchestration/SKILL.md` — meta-skill, always loaded first. Intent classification → which task skill to load.
- Create: `inst/skills/ggai-engine-selection/SKILL.md` — heuristics for choosing ggplot / base / grid / ComplexHeatmap / circlize / htmlwidget based on task.
- Create: `inst/skills/ggai-data-plot/SKILL.md` (+ `scripts/build_initial.R`, `references/style.md`) — data + instruction → ggplot artifact.
- Create: `inst/skills/ggai-figure-polish/SKILL.md` (+ `scripts/polish.R`) — existing artifact → polished image via image model.
- Create: `inst/skills/ggai-direct-figure/SKILL.md` (+ `scripts/generate.R`) — instruction-only → image model generated figure with candidate scoring loop.

**Intent**
- Provide enough skill coverage for the agent to handle the three legacy paths plus genuine free composition (e.g. "data plot + polish").

**Checklist**
- [x] Authored `inst/skills/ggai-orchestration/SKILL.md` — meta-router with intent-classification table and routing examples.
- [x] Authored `inst/skills/ggai-engine-selection/SKILL.md` — decision table for ggplot / grid / base / ComplexHeatmap / circlize / htmlwidget / composite + calling conventions per engine.
- [x] Authored `inst/skills/ggai-data-plot/SKILL.md` — flow, code conventions, reference snippets, anti-patterns, escalation triggers.
- [x] Authored `inst/skills/ggai-figure-polish/SKILL.md` — when polish applies, what it preserves vs may change, snippets for `polish_figure()` and `prepare_polish_bundle()`.
- [x] Authored `inst/skills/ggai-direct-figure/SKILL.md` — structured-prompt recipe, single-and-multi-candidate snippets, prompt-writing heuristics.
- [x] Deleted 3 obsolete skills that referenced the deleted agent runtime: `ggai-goal-agent`, `ggai-plot-agent`, `ggai-acquisition-agent`.
- [x] Edited `ggai-core-persona/SKILL.md` to drop references to deleted helpers (`gg_edit`, `as_code`, `spec_history`, `session_context`).
- [x] Confirmed `ggai-r-fonts`, `ggai-reference-figure`, `ggai-single-cell-spatial` are tool-agnostic and safe to keep.
- [x] Added `tests/testthat/test-skills.R` (4 tests, 14 assertions): canonical set present, every SKILL.md parses, agent can load each via `load_skill`, verb + skill tools both surface on the built agent.
- [x] End-to-end smoke: `ggai_create_agent()` exposes 10 tools (3 ggai verbs + 7 aisdk skill tools). `aisdk::create_skill_registry(inst/skills)` discovers all 9 skills cleanly.

**Verification**
- `aisdk::create_skill_registry(system.file('skills', package = 'ggai'))$list_skills()` returns 9 rows.
- `agent$tools` includes both ggai verb tools and `load_skill` / `list_skill_resources` / `read_skill_resource` / `execute_skill_script` from aisdk.
- `load_skill$run(list(skill_name = "ggai-orchestration"))` returns the body (with aisdk's reply-language guard prepended).
- All testthat tests pass (~310 PASS, 0 FAIL, 1 SKIP — the pre-existing on-CRAN guard).

**Notes**
- `system.file("skills", package = "ggai")` works correctly under `devtools::load_all()` — no special handling needed.
- The aisdk `Agent` does not surface `skills` as a public attribute; skills are accessible only through the agent's `load_skill` tool. `attr(agent, "ggai_state")` carries the verb-tool state separately.
- YAML frontmatter pitfall: a `when_to_use:` value containing the substring `Examples:` triggers a scanner error. Use em-dash or comma to avoid mid-value colons in unquoted scalars. Worth flagging in `AGENTS.md` if more skills are authored.

---

### Phase P4: Smoke test via existing demos

**Status:** `[ ]`

**Files**
- Modify: `demo/biorender_*` — adjust API calls to new `ggai()` signature.
- Modify: `demo/brain_dev_clusterprofiler_case.R` — same.
- Modify: any other demo broken by removed exports.

**Intent**
- Validate that the rebuilt agent reproduces every legacy path's output through self-routing.

**Checklist**
- [ ] Run each demo end-to-end; record output figures.
- [ ] Compare against the pre-refactor baseline (visual diff is acceptable; semantic faithfulness is required).
- [ ] Open follow-up issues for any path that requires a skill beyond the initial 5.

**Verification**
- All updated demos run to completion.
- Output figures are saved to `demo_outputs/` and pass `ggai_validate_artifact()`.

---

### Phase P5: ComplexHeatmap + circlize adapters

**Status:** `[ ]`

**Files**
- Modify: `R/render.R`, `R/inspect.R` — add `render_complex_heatmap`, `inspect_ch`, `render_circlize`, `inspect_circlize`.
- Create: `inst/skills/ggai-complex-heatmap/SKILL.md`, `inst/skills/ggai-circlize-genome/SKILL.md`.
- Test: `tests/testthat/test-engine-adapters.R` extended.

**Intent**
- Unlock the two most common non-ggplot bioinformatics engines.

**Checklist**
- [ ] Adapter implementations.
- [ ] Skills authored with concrete editorial guidance.
- [ ] Smoke test demos added: one heatmap, one circular genome plot.

---

### Phase P6: Composite / htmlwidget adapters

**Status:** `[ ]`

**Files**
- Modify: `R/render.R`, `R/inspect.R` — add `render_composite` (patchwork/cowplot/aplot; recursive inspect), `render_htmlwidget` (via `webshot2`).
- Create: `inst/skills/ggai-patchwork-layout/SKILL.md`, `inst/skills/ggai-htmlwidget/SKILL.md`.
- Modify: `DESCRIPTION` — add `webshot2` as Suggests.

**Intent**
- Cover composition (multi-panel) and interactive viz static export.

---

## Scope changes

_(append-only; never edit completed tasks above)_

- **2026-05-17** — P1 split: the four "Refactor" file targets (`figure_polish.R`, `figure_generation.R`, `glyph_assets.R`, `compiler.R`) and the "Lift image/glyph/compile primitives" sub-task are moved to P2. Rationale: P1 was framed as "additive only — do not change existing files"; renaming existing exports to the `ggai_*` convention is naturally bundled with P2's broader API consolidation. The five new primitive files (artifact / execute / render / inspect / validate) plus their tests are the actual deliverable of P1, and they land without touching any pre-existing source.
- **2026-05-17** — P2 scope expansion: also deleted `R/compiler.R` (only contained `compile_diagram_spec` / `compile_glyph_spec`, both spec-committer dependents), `R/spec_inspection.R` (compiled-spec helpers tied to the deleted compile pipeline), `R/acquisition_runtime.R` (1370 lines of agent-runtime data acquisition; only referenced by itself + its test), and `R/geom_ai_add.R` (the `ggplot_add.ggai_layer_request` dispatcher; without it `geom_ai()` is unusable, so `geom_ai()` was removed from `R/entrypoints.R` too). Net deletion: 13 R files (planned 9, expanded to 13). The `compile_*_spec` / `generate_final_figure` / `geom_ai` functions will return as Skill-driven helpers in P3+ if needed.

## Closing notes

_(filled in when the plan moves to `plan/done/`)_
