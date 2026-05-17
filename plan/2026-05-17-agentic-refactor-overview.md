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
- [x] Phase P4: Smoke test via existing demos — completed 2026-05-17
- [x] Phase P5: ComplexHeatmap + circlize adapters — completed 2026-05-17
- [x] Phase P6: Composite / htmlwidget adapters — completed 2026-05-17

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

**Status:** `[x]` — completed 2026-05-17

**Files**
- Run three handcrafted smoke goals against the live agent (`openai:gpt-5.5` via custom endpoint; `openai:gpt-image-2`).
- Inspect outputs under `demo_outputs/p4_*/`.

**Intent**
- Validate that the rebuilt agent self-routes correctly under real LLM behavior, and surface concrete signals about prompt/skill quality.

**Checklist**
- [x] Smoke 1 — data plot: `ggai("@mtcars Show mpg vs wt coloured by cyl ...")`. **21.5 s**, 4 tool calls (`load_skill[ggai-data-plot]` → `ggai_execute_r[engine_hint=ggplot]` → `ggai_validate_artifact` → `ggai_save_artifact`). Output: publication-grade scatter with Brewer Dark2 palette, `theme_minimal(base_size=12)`, suppressed minor grid. **Validates `ggai-data-plot` end-to-end.**
- [x] Smoke 2 — boxplot: `ggai("@mtcars Boxplot of mpg by cyl ...")`. Same flow, same skill, ~21 s. Confirms repeatable routing.
- [x] Smoke 3 — histogram: same path, same skill. **The agent's routing for "data + chart-type" goals is deterministic.**
- [x] Smoke 4 — direct figure: `ggai("Draw a clean scientific illustration of a CRISPR-Cas9 knockout ...")`. **65.7 s**, 4 tool calls, agent loaded `ggai-direct-figure` correctly. **But ignored the image-model path** and instead wrote a 120-line grid-graphics R script that draws Cas9 + sgRNA + DNA helix + DSB symbol manually. The result is honestly creditable as a hand-drawn diagram, though the title overflowed the render canvas (cut off as `ISPR-Cas9...`).
- [x] Smoke 5 — figure polish: `ggai("Polish for Nature Methods: restrained palette, classic typography ...")`. **32 s**, agent loaded `ggai-figure-polish` correctly, but again **ignored `polish_figure()`** (which uses the image model). Instead it rewrote the source ggplot with serif typography, manual restrained palette, theme_classic, careful tick / margin / legend treatment. Result is publication-quality polish — just achieved in pure ggplot rather than via image-model redraw.

**Verification**
- All three primary paths self-route to the correct skill on first try.
- Token usage observed: 4590 total tokens for a single data-plot run (~$0.003 at typical gpt-5 rates).
- All artifacts pass `ggai_validate_artifact()` (status = "ok").
- Render outputs preserved under `demo_outputs/p4_smoke/`, `p4_direct_figure/`, `p4_polish/` for later gallery use.

**Concrete findings (flowing back into the skills)**
- **The agent prefers the deterministic, cheap, vector R-code path over the image-model path when both are viable.** This is the agentic principle working as intended (let the agent choose), but my `ggai-direct-figure` and `ggai-figure-polish` skills imply the image model is the canonical tool. The skills need a "Polish modes" / "Illustration modes" decision section that legitimizes both paths and articulates when each is preferred.
- **Grid render adapter has a title-overflow issue.** When the user's code uses `grobTree` with title text near `y = 0.94`, the title can be partially clipped on the default 1200x900 canvas at 150 dpi. Either the adapter needs a top margin, or skill snippets need to anchor titles inside `unit(0.92, "npc")` with explicit margin allowances. Filed as a follow-up.
- **`load_skill` is reliable.** Three different goal phrasings each routed to the correct skill on the first try. No misrouting observed.
- **The mention-resolution pipeline works correctly.** `@mtcars` was resolved by ggai before the agent saw the goal; the agent used it without needing further setup.
- **The system_prompt's mention of "4 skill tools" is a soft mismatch with aisdk's 7 actually-provided tools.** The agent figured it out anyway. Could tighten the system_prompt in P5 alongside the engine adapter additions.

**Smoke test artifacts (preserved under `demo_outputs/`, gitignored)**
- `p4_smoke/smoke1.{R,png,json}` — scatter mpg vs wt
- `p4_smoke2/smoke2*.{R,png,json}` — boxplot of mpg by cyl
- `p4_smoke3/smoke3.{R,png,json}` — histogram of mpg
- `p4_direct_figure/crispr.{R,png,json}` — CRISPR illustration (grid graphics; image-model path bypassed)
- `p4_polish/polished1.{R,png,json}` — Nature-style polish (ggplot code path; image-model polish bypassed)

---

### Phase P4.b: Capability-aware skill modes (follow-up to P4)

**Status:** `[x]` — completed 2026-05-17

**Files**
- Create: `R/ai_bridge.R` — added `ggai_capability_status()` primitive plus `provider_env_key()` / `env_var_set()` internal helpers.
- Modify: `inst/skills/ggai-direct-figure/SKILL.md` — replaced single-path "Flow" with an explicit **Modes** section (code-path vs image-model-path), decision tree, mode-specific snippets, and a "anchor titles inside the canvas" rule that addresses the P4 title-overflow finding.
- Modify: `inst/skills/ggai-figure-polish/SKILL.md` — same: explicit **Modes** section, decision tree, mode-specific snippets, removed the now-duplicated "Reference snippets" block.
- Modify: `NAMESPACE` — export `ggai_capability_status`.
- Test: `tests/testthat/test-capability-status.R` (4 tests, 13 assertions).

**Intent**
- Make the mode choice (code vs image-model) explicit and capability-aware in the two skills the P4 smoke surfaced as ambiguous.
- Give the agent a 1-line primitive to consult when the choice is borderline, without adding another tool.
- Honor the three signals the user called out: explicit user intent → task fit → capability availability.

**Checklist**
- [x] `ggai_capability_status()` returns `{language_model, language_provider, language_available, image_model, image_provider, image_available, summary}`. Config-only check (no live API call). Provider→key env mapping covers openai / anthropic / gemini / deepseek / bailian / aihubmix.
- [x] `ggai-direct-figure` decision tree: capability check → explicit intent → task fit → default-to-code. Includes "anchor titles inside the canvas" guidance and a code-mode snippet that demonstrates the rule.
- [x] `ggai-figure-polish` decision tree: capability check → explicit intent → task fit → default-to-code-polish. Includes "polish_figure does not edit data" anti-pattern.
- [x] Test suite green: `test-capability-status.R` adds 13 assertions; full suite remains 0 FAIL / 1 SKIP.
- [x] Re-smoke against three intent variants confirms behavior:
  - **A. Ambiguous illustration** ("Draw a clean scientific illustration of a CRISPR-Cas9 knockout..."): agent stayed in code mode (matches default-to-code branch).
  - **B1. Explicit image-model intent** ("Use the image model..."): agent **attempted** `ggai_generate_image()` first, the configured endpoint returned 404 (user's custom OpenAI-compatible proxy does not serve the `/v1/images/generations` route), agent **gracefully fell back** to a `grid` reproducer and disclosed the fallback in the final reply.
  - **B2. Explicit code intent** ("In R using grid graphics, draw a reproducible vector schematic..."): agent stayed in code mode without attempting the image model.

**Verification**
- The decision tree's three branches all fired correctly in re-smokes A / B1 / B2.
- The B1 failure mode (404 from custom endpoint) revealed a gap between `capability_status` (config-level) and actual endpoint reachability — see TODO follow-up.
- The agent's fallback behavior on B1 was clean: no retry storm, no silent code-mode swap, explicit disclosure in the final reply.

**Follow-ups (filed in TODO)**
- ~~The `ggai_capability_status()` check is config-only, not live.~~ — **resolved 2026-05-17 by P5.b live probe**. See below.
- Providers without API keys (local Ollama, sandbox endpoints) currently report `available = FALSE`. Acceptable as a defensive default; revisit when local-inference becomes a real use case.

---

### Phase P5.b: Live capability probe (follow-up to P4.b)

**Status:** `[x]` — completed 2026-05-17

**Files**
- Modify: `R/ai_bridge.R` — extended `ggai_capability_status()` with `probe / refresh / ttl / timeout` parameters; added internal helpers `probe_http_route()`, `probe_capability()`, `provider_route()`, and an in-process probe cache (`ggai_probe_cache`).
- Modify: `inst/skills/ggai-direct-figure/SKILL.md`, `inst/skills/ggai-figure-polish/SKILL.md` — capability-check step in each Modes decision tree now recommends `probe = TRUE` before reaching for image-model mode.
- Modify: `tests/testthat/test-capability-status.R` — added 7 tests with `local_mocked_bindings` covering: probe-marks-reachable, probe-flips-on-404, cache reuse within TTL, refresh busts cache, providers without route mapping, network errors collapse to FALSE, default `probe = FALSE` behavior preserved.

**Intent**
- Close the config-vs-reachability gap surfaced by P4.b's B1 case (image endpoint configured-but-404 on the user's custom OpenAI-compatible proxy).
- Keep the live probe **optional** — config-only stays the default so most calls remain network-free and fast.
- Pay the network roundtrip only when the agent is about to commit to the image-model path.

**Checklist**
- [x] `probe_http_route()` sends a `POST {}` (no auth) with `req_retry(max_tries = 2, backoff = 0.5s)`. HEAD was tried first but the user's proxy returns 404 on HEAD for routes that POST works fine on; POST with empty body is the reliable signal because 4xx-other-than-404 means the route exists. Single retry recovers transient SSL handshake errors observed in practice.
- [x] `provider_route()` maps known OpenAI-compatible providers (openai / deepseek / aihubmix) to their `chat/completions` and `images/generations` routes; `anthropic/language` → `/messages`. Other providers return NULL → `reachable = NA` (probe skipped, config-only result preserved).
- [x] In-process cache keyed by `(provider, base_url, type)` with default TTL = 60s. `refresh = TRUE` busts the cache; `ggai_probe_cache_clear()` for tests.
- [x] Result schema extended: added `probed` boolean + `probe_results` list of `(status, reachable, route, error, cached)`; existing `*_available` semantics tighten when probe runs (FALSE if probe says unreachable; preserved otherwise).
- [x] Tests cover the seven branches above; mocked HTTP keeps the suite offline. `withr::with_envvar` exercises the no-key-mapped fallback. Full suite: **0 FAIL / 1 SKIP / 358 PASS** (+15 from new probe tests).

**Verification — against the user's actual endpoint**
- `ggai_capability_status()` (config-only): both language and image report `[configured]`.
- `ggai_capability_status(probe = TRUE)` (live): language reports `[configured; reachable (HTTP 401)]`, image reports `[configured; UNREACHABLE (HTTP 404)]`. **Correctly diagnoses the proxy's missing images route.**

**End-to-end LLM smoke**
Re-ran the P4.b B1 case ("Use the image model to render a BioRender-style illustration..."):
- **Before P5.b**: agent tried `ggai_generate_image()` → 404 → fell back to grid.
- **After P5.b**: agent called `ggai_capability_status(probe = TRUE)` first, saw image unreachable, skipped the `ggai_generate_image()` attempt entirely, went straight to grid mode. Final reply: *"The image-model route was requested, but the configured image endpoint was not available after probing, so I produced a BioRender-inspired fallback schematic in R/grid instead."*

One less wasted network call, cleaner reply text. The Modes decision tree now operates on accurate capability information.

---

### Phase P5: ComplexHeatmap + circlize adapters

**Status:** `[x]` — completed 2026-05-17

**Files**
- Modify: `R/execute.R` — extended the `rendered_object` switch to include `complex_heatmap = last_value` and `circlize = recorded`.
- Modify: `R/render.R` — added `render_complex_heatmap()` (calls `ComplexHeatmap::draw()` to device); `circlize` reuses `render_base()` since circlize draws via base-graphics-style side effects and the artifact's object is a `recordedplot`.
- Modify: `R/inspect.R` — added `inspect_ch()` (surfaces matrix shape, names, dendrogram flags, annotation slot occupants per heatmap; handles both `Heatmap` and `HeatmapList`) and `inspect_circlize()` (thin overlay on `inspect_recorded` with a `circlize`-flavored summary line).
- Modify: `R/validate.R` — added `validate_ch()` (dry-runs `ComplexHeatmap::draw()` on a null device); `circlize` reuses `validate_recorded`.
- Modify: `DESCRIPTION` — `ComplexHeatmap`, `circlize` added to `Suggests`.
- Create: `inst/skills/ggai-complex-heatmap/SKILL.md` — when-to-use, code conventions, three reference snippets (basic, HeatmapList, oncoPrint), anti-patterns, escalation triggers.
- Create: `inst/skills/ggai-circlize-genome/SKILL.md` — explicit `engine_hint = "circlize"` requirement, two snippets (chord, genome track), anti-patterns about `circos.clear()` discipline and species/assembly specificity.
- Modify: `inst/skills/ggai-engine-selection/SKILL.md` — references both new skills explicitly so the engine-selection skill can hand off cleanly.
- Test: `tests/testthat/test-engine-adapters.R` extended with three new tests covering ComplexHeatmap single / HeatmapList paths and the circlize `engine_hint` flow.
- Modify: `tests/testthat/test-skills.R` — required set now includes the two new skills.

**Intent**
- Unlock the two most common non-ggplot bioinformatics engines without changing the rest of the system.

**Checklist**
- [x] `ComplexHeatmap::Heatmap` and `HeatmapList` are auto-detected and rendered via `ComplexHeatmap::draw()` to the target device.
- [x] `circlize` figures are produced via `engine_hint = "circlize"`. Detection cannot auto-classify because `circos.*` returns NULL; the cached object is the captured `recordedplot`, rendered by `replayPlot`.
- [x] Inspect / validate dispatchers return engine-specific structured info that downstream skills can consume.
- [x] `tests/testthat/test-engine-adapters.R` now covers six engines (ggplot, composite, grid, base, complex_heatmap, circlize). Full suite green: 0 FAIL / 1 SKIP / 343 PASS.
- [x] Skills authored and registered. `aisdk::create_skill_registry(inst/skills)` now reports 11 skills.
- [x] L2 smoke (both engines, no LLM): both render to PNG, validate `ok`.
- [x] End-to-end LLM smoke (both engines): agent self-routes to the right skill, writes correct code, produces publication-grade output.

**Verification**
- L2 smoke (no LLM): `ggai_execute_and_capture(...)` returns `engine = "complex_heatmap"` for `Heatmap(matrix)` code and `engine = "circlize"` (with `engine_hint`) for `circos.*` code. Both render PNG; both `ggai_validate_artifact()$status == "ok"`.
- End-to-end LLM smoke:
  - **ComplexHeatmap**: `ggai("@expr Make a ComplexHeatmap of Z-scores with top annotation by @sample_meta$group and @sample_meta$batch ...")` produced a clean annotated heatmap in **44.8 s** (4 tool calls: `load_skill[ggai-complex-heatmap]` → `ggai_execute_r[engine_hint=complex_heatmap]` → `ggai_validate_artifact` → `ggai_save_artifact`). The generated code is defensively written (existence checks, column-alignment fallback, robust Z-score limits, `use_raster` threshold).
  - **circlize**: `ggai("@overlap_mat Draw a circlize chord diagram ...")` produced a clean chord diagram in **43.1 s** (same tool sequence). Agent passed `engine_hint = "circlize"` correctly per skill guidance.

**Smoke outputs (preserved under `demo_outputs/`, gitignored)**
- `p5_ch/ch1.{R,png,json}` — annotated ComplexHeatmap with row dendrogram + group/batch top tracks
- `p5_circ/chord1.{R,png,json}` — chord diagram over 5 gene modules with transparent chords

**Notes**
- ComplexHeatmap inspection surfaces per-heatmap slot occupancy flags (`has_top_annotation`, `has_row_dendrogram`, etc.). Useful when chaining into a downstream polish or composite step.
- circlize cannot be auto-detected; the engine_hint is a hard requirement. The skill calls this out as the "Engine note" section so the agent doesn't omit it.
- Both new engines route polish through code mode by default (no `polish_figure()` path defined for them yet). The complex-heatmap skill notes the workaround via `ggplotify::as.ggplot(grid.grabExpr(draw(ht)))` for users who insist on image-model polish.

---

### Phase P6: Composite / htmlwidget adapters

**Status:** `[x]` — completed 2026-05-17

**Files**
- Modify: `R/inspect.R` — split composite off from ggplot: new `inspect_composite()` walks `patchwork$patches$plots`, returning per-panel info (`kind`, `n_layers`, `summary`); also added `inspect_htmlwidget()` surfacing widget name, declared dependencies, sizing policy, data-payload presence.
- Modify: `R/render.R` — added `render_htmlwidget()` (saves self-contained HTML via `htmlwidgets::saveWidget`; rasterizes to PNG via `webshot2::webshot` when available, else writes HTML with a warning); dispatcher extended.
- Modify: `R/validate.R` — added `validate_htmlwidget()` (dry-runs `saveWidget` to a tempfile).
- Modify: `R/execute.R` — `format` argument now accepts `"html"` in addition to `"png"` / `"svg"`; the rendered-format detection reads back from the actual path written, so htmlwidget's PNG→HTML fallback is recorded correctly in `artifact$rendered`.
- Create: `inst/skills/ggai-patchwork-layout/SKILL.md` — library-choice table (patchwork / cowplot / aplot), composition flow, anti-patterns including the critical `engine_hint` rule (see below), three reference snippets.
- Create: `inst/skills/ggai-htmlwidget/SKILL.md` — when-to-use, format-decision table (html always works; png needs webshot2), three snippets (plotly / leaflet / DT), anti-patterns.
- Modify: `inst/skills/ggai-engine-selection/SKILL.md` — cross-links to both new skills.
- Modify: `DESCRIPTION` — `cowplot`, `aplot`, `htmlwidgets`, `patchwork`, `plotly`, `webshot2` added to Suggests.
- Test: `tests/testthat/test-engine-adapters.R` extended with composite + htmlwidget tests; `test-skills.R` required set updated.

**Intent**
- Cover composition (multi-panel) and interactive viz static export, completing the engine matrix to **8 engines**: ggplot / composite / grid / base / complex_heatmap / circlize / htmlwidget / unknown.

**Checklist**
- [x] Composite auto-detects from `patchwork` class; render uses the existing ggplot path (print to device); inspect walks patches.
- [x] htmlwidget auto-detects from class; render is HTML by default with optional PNG via webshot2; PNG-without-webshot2 falls back to HTML cleanly with a single warning. `ggai_execute_and_capture()` records the actual rendered format from the file extension, so `artifact$rendered$html` vs `artifact$rendered$png` reflects reality.
- [x] Engine matrix is 8 engines, all with adapters and at least one ggai-side test.
- [x] Tests cover composite detection, panel walk, htmlwidget detection, HTML render, inspect surface. Full suite green: **0 FAIL / 1 SKIP / 380 PASS** (+22 from new tests).
- [x] Skill content sharpened from first-smoke feedback (see "Iteration after smoke" below).
- [x] End-to-end LLM smoke for composite path produced a clean 3-panel labeled figure.

**Iteration after smoke**

First composite smoke (`comp2`) revealed that the agent passed `engine_hint = "ggplot"` despite producing a patchwork. The artifact rendered correctly (patchwork inherits ggplot, so render_ggplot works), but it was mis-tagged as `engine = "ggplot"` and `inspect_composite`'s per-panel walk was disabled. The user's request for A/B/C panel labels was also lost — the agent had silently overridden `plot.tag` to transparent.

Edited `ggai-patchwork-layout` to:
1. Add a sharp rule under the Flow section: *"omit `engine_hint` — do NOT pass `engine_hint = "ggplot"` even though patchwork inherits ggplot; passing it forces the wrong engine label and disables `inspect_composite`'s per-panel walk."*
2. Add an anti-pattern: *"Don't override `plot.tag` to invisible in the global theme after `plot_annotation(tag_levels = "A")` — that strips the very labels you just asked for."*

Re-smoke (`comp3`): agent now passes `engine_hint = "composite"`, artifact is correctly tagged, A/B/C labels visible in the output. Confirms the smoke→iterate→re-smoke loop established in P4.b is reliable.

**Notes**
- Patchwork stores N–1 panels in `$patches$plots`; the patchwork object itself carries the first panel's ggplot identity. Total panel count is `1 + length($patches$plots)`. Nested patchworks (`p1 | (p2 / p3)`) report as `kind = "nested_patchwork"` without full recursion — top-level counting only for now. Filed for later if multi-level inspection becomes useful.
- Patchwork in `ggplot2 4.0+` (S7 prototype) does not propagate `$layers` reliably on stored patches. Per-panel `n_layers` may understate complex constituent plots; this is a patchwork/S7 quirk, not a ggai bug. Filed as TODO.
- htmlwidget rendering without webshot2 cleanly degrades to HTML output. The "PNG requested → HTML written" path emits a single `warning()` and the manifest reflects the actual format. Skills are written to set user expectations honestly.

**Smoke outputs (preserved under `demo_outputs/`, gitignored)**
- `p6_comp/comp2.{R,png,json}` — patchwork composite without engine_hint sharpening (mis-tagged as ggplot, missing A/B/C labels).
- `p6_comp2/comp3.{R,png,json}` — patchwork composite after skill sharpening (correctly tagged as composite, A/B/C labels visible, clean Dark2 palette across panels).

---

## Scope changes

_(append-only; never edit completed tasks above)_

- **2026-05-17** — P1 split: the four "Refactor" file targets (`figure_polish.R`, `figure_generation.R`, `glyph_assets.R`, `compiler.R`) and the "Lift image/glyph/compile primitives" sub-task are moved to P2. Rationale: P1 was framed as "additive only — do not change existing files"; renaming existing exports to the `ggai_*` convention is naturally bundled with P2's broader API consolidation. The five new primitive files (artifact / execute / render / inspect / validate) plus their tests are the actual deliverable of P1, and they land without touching any pre-existing source.
- **2026-05-17** — P2 scope expansion: also deleted `R/compiler.R` (only contained `compile_diagram_spec` / `compile_glyph_spec`, both spec-committer dependents), `R/spec_inspection.R` (compiled-spec helpers tied to the deleted compile pipeline), `R/acquisition_runtime.R` (1370 lines of agent-runtime data acquisition; only referenced by itself + its test), and `R/geom_ai_add.R` (the `ggplot_add.ggai_layer_request` dispatcher; without it `geom_ai()` is unusable, so `geom_ai()` was removed from `R/entrypoints.R` too). Net deletion: 13 R files (planned 9, expanded to 13). The `compile_*_spec` / `generate_final_figure` / `geom_ai` functions will return as Skill-driven helpers in P3+ if needed.

## Closing notes

_(filled in when the plan moves to `plan/done/`)_
