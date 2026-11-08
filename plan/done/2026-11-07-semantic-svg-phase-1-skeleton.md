# Semantic SVG export — Phase 1: deterministic skeleton, compile, verify

> Status: closed 2026-11-08, superseded before any work started (see Scope changes and Closing notes).
> Date opened: 2026-11-07. Owner: Yonghe Xia.

> **Moved 2026-11-08.** The package was renamed `gloss` and its material moved to the gloss repository: `dev_docs/semsvg-package-design.qmd` → `dev_docs/design.qmd`, `dev_docs/semantic-svg-research-report.qmd` → `dev_docs/research-report.qmd`, `dev_docs/semantic-svg-research/` → `dev_docs/research/`, `dev_docs/figures/semantic-svg/` → `dev_docs/figures/`, and the two `idea/2026-11-07-*` docs → `idea/`. Paths below are as they were at the time.

**Goal:** Export any `ggai_artifact` from a grid-based engine (ggplot, composite, grid, ComplexHeatmap, and base via gridGraphics) as an SVG in which every primitive has a stable id, S1 structure and, where it can be determined, a verified S2 data binding. Then compile a **hand-written** `semantics.json` into an interactive, ARIA-annotated SVG/HTML, with a verification report.

**Why now:** idea/2026-11-07-agentic-semantic-svg.md and its prior-art survey showed three things:
- Per-grob element capture is feasible: 133/134 primitives tagged, geometry byte-identical.
- Every existing tool is closed-world.
- The agent stage, which is the actual contribution, needs a trustworthy deterministic layer under it.

This plan builds that layer. It also covers two TODO items: "HTML / SVG assisted layout" and "semantic editing primitives".

**Architecture:**
- New Layer-2 primitives in `R/`, engine-agnostic over `ggai_artifact` (ADR-0002):
  - `ggai_svg_skeleton()` → skeleton SVG + skeleton list/JSON;
  - `ggai_svg_compile(skeleton, semantics)` → SVG/HTML;
  - `ggai_svg_verify()` → report.
- A small static JS runtime in `inst/semantic-svg/`.
- Stage-1 element capture is ggai's own mechanism, chosen in Task 2 from ggai-native candidates and recorded as ADR-0004. No capture library is a dependency.
- **Not touched:** the agent, the skills, the polish path, and the existing render adapters, except for read-only reuse of `render_to_file()` / `open_device()`.

**Out of scope:**
- Agent-authored semantics, skill authoring, prompt design → Phase 2 plan.
- MAIDR JSON export target, Shiny bindings, crosstalk interop beyond emitting compatible keys.
- htmlwidget engine; circlize (base-graphics path, deferred until gridGraphics coverage is measured).
- Depending on, or copying from, ggiraph, gridSVG, maidr, plotly or canvasXpress. They are methodological reference only. They may appear as comparison baselines in `dev_docs/scripts/`, never in `DESCRIPTION`.

**Tech stack:** R, `ggplot2`, `grid`, `svglite`, `xml2`, `jsonlite`, `gridGraphics`. Test-only: `patchwork`, `ggrepel`, `ComplexHeatmap`, `png` (pixel diff).

**Verification (plan-level):**
On the benchmark set (Task 1), for every figure:
1. All primitives except the device background carry an id.
2. Every per-grob count mismatch is listed in the skeleton report. There are 0 silent id recycles.
3. Ids are identical across two fresh R sessions.

Beyond that:
4. Every point and pointrange mark in figures (a), (e) and (h) is bound to the correct built row (coordinate round-trip within 0.5 px).
5. Compiled SVG vs a PNG rendered in the same session: under 0.5% of pixels off by more than 16 levels.
6. A 10^5-point figure exports under 3 MB using the raster + index fallback, and sampled hit-tests return the correct row.
7. `testthat::test_file()` passes on all new test files with no network access.

---

## Progress tracking

**Status legend**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked
- `[-]` Cancelled

**Plan maintenance rules**
- Update immediately after landing a task or sub-step.
- Record the verification command / observed behavior when marking `[x]`.
- If scope shifts, append a `Scope Change` note rather than silently changing completed work.

**Overall progress**
- [-] Task 1: Benchmark figure set and fixtures
- [-] Task 2: Design ggai's own element-capture mechanism → ADR-0004
- [-] Task 3: Skeleton capture (S1): stable ids, viewport paths, counts, boxes
- [-] Task 4: S2 binding for ggplot layers (built rows, group keys)
- [-] Task 5: Dense-layer raster + index fallback
- [-] Task 6: `semantics.json` schema v0 + two hand-written examples
- [-] Task 7: Compiler + JS runtime
- [-] Task 8: Verifier
- [-] Task 9: Docs, CHANGELOG, dev log; open the Phase 2 plan

---

### Task 1: Benchmark figure set and fixtures

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `tests/testthat/helper-semantic-svg.R` (figure builders, gated with `skip_if_not_installed()`)
- Create: `dev_docs/scripts/semantic-svg-benchmark.R` (runs all backends and metrics; not part of the build)

**Intent**
- One fixed figure set for every later task, reused from the survey so its numbers stay comparable:
  - (a) facet + `geom_smooth(lm)` + colour + `annotate`;
  - (b) patchwork;
  - (c) ggrepel;
  - (d) ComplexHeatmap with annotations + dendrograms;
  - (e) pointrange forest plot;
  - (f) base `plot()` via gridGraphics;
  - (g) 10^5-point scatter;
  - (h) `geom_jitter` + discrete x;
  - (i) multi-line text labels + mixed `pch` (known mismatch cases).

**Checklist**
- [ ] Builders return `ggai_artifact`s via `ggai_execute_and_capture()`
- [ ] Ground truth per figure: expected data-mark count per layer, plus built rows
- [ ] Benchmark script prints a metrics table (tagged share, mismatches, binding accuracy, size, time)
- [ ] Baselines in the script only: plain svglite always; reference tools (ggiraph, maidr, plotly, canvasXpress) when installed, for comparison

**Verification**
- `Rscript dev_docs/scripts/semantic-svg-benchmark.R` prints the table for the svglite baseline (0 ids).

---

### Task 2: Design ggai's own element-capture mechanism → ADR-0004

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `dev_docs/decisions/0004-semantic-svg-capture-mechanism.md`
- Create: `dev_docs/scripts/semantic-svg-capture-candidates.R` (prototypes; not part of the build)

**Intent**
- Decide how ggai maps each grob to the SVG elements it emits, using its own design.
- Prior art proves per-grob capture is feasible: ggiraph uses a custom C++ device tracer, maidr inserts sentinel markers. These are reference only: no dependency, no code reuse, and no assumption that ggai uses the same technique.
- ggai-native candidates, all on plain `svglite`:
  1. **Per-leaf isolated render.** Walk the forced grob tree. Render each leaf alone, inside its own viewport path, onto a page of identical size. Assemble the fragments in draw order.
     - Ownership is exact by construction.
     - Risk: reassembling clip paths and `<defs>`.
  2. **Whole-scene render, segmented by expected counts.** Render once. Predict each leaf's element count from its class and length, then slice the output in order.
     - The cheapest option.
     - Risk: one wrong prediction shifts every element after it, so this needs a cross-check.
  3. **Colour-coded pick render.** Render a second time with each leaf recoloured to a unique id colour. Pair it 1:1 with the normal render by order, then decode the colours.
     - Works as an independent check for 1 or 2.
     - Risk: fragile with alpha, gradients and patterns.
- Criteria:
  - tagged share and per-grob count fidelity across the Task 1 figures;
  - geometry identical to plain svglite;
  - id stability;
  - speed on (g);
  - code size and maintenance burden.

**Checklist**
- [ ] Prototype candidates 1–3 in the dev script
- [ ] Run them on figures (a)–(i); put the results table in the ADR
- [ ] Decide; if cheap, keep the runner-up as a cross-check in the verifier

**Verification**
- ADR-0004 accepted, with the metrics table produced by the Task 1 script.

---

### Task 3: Skeleton capture (S1)

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `R/semantic_svg_skeleton.R`
- Test: `tests/testthat/test-semantic-svg-skeleton.R`

**Intent**
- `ggai_svg_skeleton(artifact)` returns a list (with a JSON writer) plus the skeleton SVG.
- Each element records:
  - a stable id `p<panel>/l<layer>/<leaf role>/<i>`, derived from structure, not from grob-name counters;
  - grob path and viewport path;
  - class.
- Per-grob expected vs emitted counts. On a mismatch: **fail closed** (keep S1, mark the grob unbound, report it; never recycle).
- Panel and block boxes, recorded from the viewport tree after drawing (the InteractiveComplexHeatmap approach).

**Checklist**
- [ ] Capture via the ADR-0004 mechanism
- [ ] Stable id scheme; same ids across sessions
- [ ] Count check + mismatch report
- [ ] Viewport path for ComplexHeatmap (d)
- [ ] Panel/block boxes for (a), (b), (d)

**Verification**
- `Rscript -e "testthat::test_file('tests/testthat/test-semantic-svg-skeleton.R')"`
- Two `callr` sessions produce identical id sets for (a).

---

### Task 4: S2 binding for ggplot layers

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `R/semantic_svg_bind.R`
- Test: `tests/testthat/test-semantic-svg-bind.R`

**Intent**
- Bind elements of ggplot layers to `ggplot_build()` rows by (layer, PANEL, in-grob order), and verify the binding by coordinate round-trip.
- Raw-row keys: one key per row for identity stats, nested keys for summarising stats (the crosstalk model).
- Layers that cannot be bound stay S1-only and are listed as candidates for the Phase 2 agent.

**Checklist**
- [ ] Point / pointrange / text / rect bindings with round-trip check
- [ ] Jitter (h) binds to the *drawn* positions in built data, not raw columns (Shiny gets 1/32 here)
- [ ] Stat layers: nested keys for smooth and boxplot
- [ ] Unbindable layers listed in the report

**Verification**
- Plan-level check 4 passes for (a), (e), (h).

---

### Task 5: Dense-layer raster + index fallback

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Modify: `R/semantic_svg_skeleton.R`
- Create: `inst/semantic-svg/` index format notes
- Test: `tests/testthat/test-semantic-svg-dense.R`

**Intent**
- When a layer has more than N marks (default about 10^4), rasterize that layer only and emit a compact hit-test index keyed by (layer, panel, built row). Grid-like layers store block boxes plus order vectors.

**Checklist**
- [ ] Threshold option in `R/options.R`
- [ ] Index encode/decode (R) + lookup (JS)
- [ ] Heatmap block-box representation for (d)

**Verification**
- Plan-level check 6 on (g).

---

### Task 6: `semantics.json` schema v0 + hand-written examples

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `inst/semantic-svg/semantics.schema.json`
- Create: `inst/semantic-svg/examples/{facet_lm,forest}.semantics.json`

**Intent**
- Pin the contract the Phase 2 agent will write against:
  - roles (VisAnatomy-compatible taxonomy);
  - relations (typed edges between skeleton ids);
  - S4 interactions from a closed vocabulary (DIVI target × type × input);
  - a11y text;
  - claim provenance (Direct / Derived / Speculative).
- Writing it by hand first proves the compiler before any LLM is involved.

**Checklist**
- [ ] Schema with validation
- [ ] Two hand-written examples referencing real skeleton ids

**Verification**
- Both examples validate; every referenced id exists in the matching skeleton.

---

### Task 7: Compiler + JS runtime

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `R/semantic_svg_compile.R`
- Create: `inst/semantic-svg/runtime.js`
- Test: `tests/testthat/test-semantic-svg-compile.R`

**Intent**
- `ggai_svg_compile()` applies semantics to the skeleton:
  - `data-*` attributes;
  - WAI-ARIA Graphics roles (`graphics-document` / `-object` / `-symbol`; decoration hidden; no per-item ARIA on dense layers);
  - `<title>`/`<desc>`;
  - embedded data JSON restricted to an allow-list of columns.
- Output formats: standalone SVG and HTML.
- The runtime uses one delegated listener on the root plus attribute selectors and class toggles. It implements the closed S4 vocabulary (hover tooltip, linked highlight by key, legend toggle) and `pointer-events: none` on decoration.

**Checklist**
- [ ] Compile for both examples
- [ ] Column allow-list enforced (default: only columns referenced by aesthetics)
- [ ] Runtime works in the HTML output (browser smoke test, gated)

**Verification**
- Plan-level check 5.
- A manual browser check of hover and linked highlight on (a).

---

### Task 8: Verifier

**Status:** `[-]` superseded (see Scope changes)

**Files**
- Create: `R/semantic_svg_verify.R`
- Test: `tests/testthat/test-semantic-svg-verify.R`

**Intent**
- `ggai_svg_verify()` checks:
  - dangling ids;
  - per-grob counts;
  - every Direct claim against built rows;
  - pixel diff against a PNG from the same session.
- A pixel diff alone is not enough. In the survey, plotly dropped every label and still scored better than canvasXpress.

**Checklist**
- [ ] Report object with pass/fail per check
- [ ] Injected-fault tests: wrong row binding, dangling id, dropped layer

**Verification**
- All injected faults are detected; clean examples pass.

---

### Task 9: Docs, CHANGELOG, dev log; open the Phase 2 plan

**Status:** `[-]` superseded (see Scope changes)

**Checklist**
- [ ] roxygen + `devtools::document()`
- [ ] `CHANGELOG.md` `[Unreleased]` entry
- [ ] `dev_logs/` entry
- [ ] Draft `plan/…-semantic-svg-phase-2-agent.md`: skill, compressed-skeleton prompt, claim verification loop, VisAnatomy R-subset evaluation with the "agent without skeleton" ablation

---

## Scope changes

_(append-only; never edit completed tasks above)_

### Scope Change — 2026-11-08

The work moved out of ggai before any task started. Two owner decisions on 2026-11-07 and 2026-11-08 caused it:

1. Build it as a **new, standalone R package** (`semsvg`) driven by aisdk, without carrying over ggai's architecture. See [ADR-0004](../../dev_docs/decisions/0004-semantic-figure-substrate-as-standalone-package.md).
2. Change the design from a one-shot converter (skeleton → compile → verify) to a **semantic substrate**: six capabilities, append-only layered records anchored to elements, and projections as outputs. See dev_docs/semsvg-package-design.qmd.

So the `ggai_svg_*` primitives in `R/` this plan describes will not be built. All tasks are marked `[-]`. Where each one went:

| Task here | Where it lives now |
|---|---|
| 1 Benchmark set | semsvg M0 (the six capture inputs) and M5 (the benchmark with code) |
| 2 Capture mechanism → ADR-0004 | Already settled during the research: group delimiting plus probes, scripts in `dev_docs/semantic-svg-research/capture-groups/`. The ADR-0004 number now records the package decision; the capture decision will be recorded in the semsvg repo. |
| 3 Skeleton S1 | semsvg M0 (substrate) and M1 (identify, classify, organize) |
| 4 S2 ggplot binding | semsvg M1, ggplot engine plugin |
| 5 Dense-layer fallback | semsvg M0 |
| 6 `semantics.json` schema | Replaced by record schema + layer plugins, semsvg M2 |
| 7 Compiler + runtime | Replaced by projection plugins + runtime kernel with op plugins, semsvg M3 |
| 8 Verifier | semsvg M2–M3 (`sem_verify`, check primitives) |
| 9 Docs; open Phase 2 | The semsvg M0 plan will be opened in the new repo |

## Closing notes

Closed 2026-11-08 as superseded; no code was written under this plan. The research it was based on is kept and committed in `dev_docs/semantic-svg-research/`, together with the report (`dev_docs/semantic-svg-research-report.qmd`) and the package design (`dev_docs/semsvg-package-design.qmd`). Closing log: [dev_logs/2026-11-08-semsvg-decisions.md](../../dev_logs/2026-11-08-semsvg-decisions.md).

**Update 2026-11-08 (later the same day).** The package was renamed `gloss`, and the material listed above moved to the gloss repository (`dev_docs/design.qmd`, `dev_docs/research-report.qmd`, `dev_docs/research/`, `idea/`). It is no longer in ggai; ggai's git history still has it. The capture decision is gloss ADR-0001.
