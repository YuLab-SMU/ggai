# 2026-11-07 — Semantic SVG export: idea, prior-art survey, Phase 1 plan

- **Related plan:** [plan/2026-11-07-semantic-svg-phase-1-skeleton.md](../plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md)
- **Related ADRs:** ADR-0002 (code-first artifact). ADR-0004 (capture backend) is pending; it is plan Task 2.
- **Related commits / PRs:** none yet; docs only, uncommitted.
- **Worked on by:** Yonghe Xia, Claude

## What happened

The idea: export R figures as SVG carrying semantics, not just geometry, with the agent adding meaning on top of a deterministic element ↔ data binding.

1. Wrote the idea doc and ran a 1-file svglite spike.
2. At the user's request, surveyed existing approaches in four parallel threads: device tagging, raster hit-testing, spec translation, and literature. Each thread combined source reading with the REA 6.8.0 and Craft Anything 0.5.0 reverse-engineering tools.
3. Spot-checked the key claims myself (maidr exporter source, Shiny `image.ts` / `render-plot.R` lines, the tagged SVG attributes, plotly `geom2trace.default`, three canvasXpress/plotly screenshots).
4. Wrote the prior-art doc, revised the idea doc, and drafted the Phase 1 plan.

## Findings / decisions

- **maidr already does most of Stage 1.** maidr (CRAN 0.5.0, GPL-3) uses an invisible-marker walk on svglite that produces gridSVG-style grob ids with exact geometry. It binds data through about 40 hand-written processors; unknown layers get nothing.
- **The ggiraph `dsvg` tracer works on every leaf grob.** Wrapping every leaf, not just interactive geoms, tagged 133/134 primitives with byte-identical geometry. Per-grob capture removes the need to align draw order across the whole SVG.
- **Our contribution narrows.** It is: open-world S2 bindings proposed by the agent and verified against data; S3 meaning and relations; a per-figure S4 interaction design from a closed vocabulary; and the verification gate.
- **Translation tools fail silently on common figures** (measured). plotly reduces a patchwork to its last panel and drops every ggrepel label. canvasXpress turns a forest plot into a bar chart and draws the smooths as one zig-zag. This strongly supports "the agent annotates, never redraws".
- **A pixel diff is not a sufficient check.** plotly dropped all labels and still scored better than canvasXpress. The verifier needs per-layer counts and row bindings.
- **Shiny `nearPoints` breaks easily:** jitter 1/32, `coord_polar` 0/32, second layer 0/32. Use InteractiveComplexHeatmap's approach instead: record positions from the viewport tree after drawing.
- **Dense data has a measured fallback.** At 10^5 points, plain SVG is 10.2 MB vs a 1.17 MB binary index. Use raster + index above about 10^4 marks.
- **Licensing.** ggiraph, gridSVG and maidr are GPL and ggai is MIT. Depend on them or reimplement independently; never copy code.
- **Naming.** The semantic levels were renamed from L0–L4 to S0–S4, to avoid a clash with Lundgard & Satyanarayan's L1–L4. Avoid the name "SSVG" (used by CSL).
- **Tools.**
  - Useful: REA `capture-browser-scenario` (wire payloads), Craft `web-listeners-list` (listener placement), and Craft `js-sources-restore` (exposed canvasXpress's silent skip).
  - Weak: both tools' static JS analysers on these bundles.
  - Friction: the Craft CLI doesn't keep a browser open between invocations (use MCP mode or an external CDP endpoint, plus `--deep`), and neither tool can hover or drag at coordinates.

## Verification

- Spike: `dev_docs/semantic-svg-research/spike/spike.R` → 134 drawn primitives (the earlier "139" also counted 5 clip-path definition rects), 0 ids; panel-1 Spearman 1.0.
- Tag-all: `dev_docs/semantic-svg-research/ggiraph/out/e3_log.txt` → 134 primitives, 133 with id; mismatches only on NA grid lines and a NaN ribbon.
- Pixel diffs: `dev_docs/semantic-svg-research/translate/pixel_diffs.csv`. Craft and REA agree on all comparisons.
- Research artifacts were produced under `/tmp/ggai_research/` and later archived; see the update below.

## Next

- Plan Task 1 (benchmark fixtures), then Task 2 (capture-backend bake-off → ADR-0004).
- Open question for the owner: should ggai depend on a GPL capture backend (ggiraph or maidr), or reimplement the marker walk under MIT? The bake-off informs this, but it is ultimately a licensing and maintenance decision.

## Update (same day): prior art is reference only

The owner resolved the open question. ggiraph, gridSVG, maidr, plotly and canvasXpress are methodological reference only:
- no dependency on them;
- no code reuse;
- no assumption that ggai uses their techniques.

Changes made:
- Plan Task 2 is now "Design ggai's own element-capture mechanism". It compares three ggai-native candidates on plain svglite: per-leaf isolated render, whole-scene render segmented by expected counts, and a colour-coded pick render.
- The reference tools may still appear as comparison baselines in `dev_docs/scripts/`, never in `DESCRIPTION`.
- The idea doc and the prior-art doc are updated to match.

## Update (same day): standalone research report

Wrote [dev_docs/semantic-svg-research-report.qmd](../dev_docs/semantic-svg-research-report.qmd), a complete Chinese research report. At the owner's request it ignores ggai's existing architecture, plans and code, and treats the idea as a fresh direction.

Contents:
- problem statement and the S0–S4 levels;
- method;
- the five families of existing approaches, with measured evidence;
- positioning;
- the four-stage design;
- a worked verification example;
- novelty and limits, risks, evaluation, roadmap;
- appendices on tool evaluation and reproducibility;
- verified references.

Notes:
- **Evidence screenshots.** Copied from `/tmp` into `dev_docs/figures/semantic-svg/` so they survive a reboot.
- **Worked example.** The annotation "heavier = thirstier" holds for 5 of 6 groups. The exception is am=0, cyl=4: slope +3.07, n=3. This shows why claims must be verified against data.
- **Correction.** VisAnatomy's R-chart role F1 was cited as "GPT-4o 0.69". The source (arXiv 2410.12268 §3.1) gives GPT-4o 0.692 vs DeepSeek-V3 0.959. The point is cross-model instability, not just low accuracy. Fixed in the idea docs.
- **Verification.** `quarto render dev_docs/semantic-svg-research-report.qmd --to html` gives no warnings, no unresolved crossrefs, and no broken reference anchors. Layout was checked with a headless Chrome screenshot.

## Update (same day): research artifacts archived in the repo

At the owner's request, the scratch research directory is now archived in [`dev_docs/semantic-svg-research/`](../dev_docs/semantic-svg-research/README.md) (8.6 MB, about 295 files):
- the four thread reports;
- the spike;
- every experiment script with its logs and outputs;
- the REA and Craft captures;
- the screenshots and the pixel-diff table.

Scripts are kept as run. Their `/tmp/ggai_research/<x>` paths map to `dev_docs/semantic-svg-research/<x>`, and the README records the upstream commit SHAs.

Excluded:
- third-party code: `girafe.js`, the htmlwidgets JS, the canvasXpress engine (its source-available licence forbids removing attribution), Shiny's source map, and full-page DOM snapshots that embedded those bundles;
- 87 KB of jQuery source, stripped from one listener capture;
- raw captures of canvasxpress.org;
- Chrome profiles, local tool installs, the scratch R library, and the source clones.

A secret scan of the archive found only redaction metadata and jQuery's `password` input type.

## Update (same day): proposal review and new-package design

The owner asked for a review of the proposal and a design for implementing it as a **new** R package driven by aisdk, without carrying over ggai's approach. Result: [`dev_docs/semsvg-package-design.qmd`](../dev_docs/semsvg-package-design.qmd), in Chinese.

**New capture mechanism (verified).** Wrap every leaf of the `grid.force()`d scene in a `groupGrob()`, with the leaf's `vp` hoisted to an outer gTree, plus a zero-output probe grob.
- svglite 2.2 emits `<defs><g id="group-k">` and `<use>` per leaf. Inlining the `<use>` elements gives a drawn-primitive sequence **identical** to plain svglite (tag, attributes and text) for all six inputs: ggplot facet (60 leaves, 132 primitives), patchwork (82/184), base via gridGraphics `echoGrob` (14/60), ComplexHeatmap (14/275), ggrepel (51/115), and 10^4 points (13/10034; 3.1 s for three renders).
- The only unowned primitive in each case is the device background.
- The probes record `current.vpPath()` and the device box with no SVG output. For ComplexHeatmap they give `z_heatmap_body_1_1`, `z_dend_row_1`, `annotation_cyl_1` and so on.
- This supersedes the three capture candidates in the report. Scripts are in `dev_docs/semantic-svg-research/capture-groups/`.

**Review findings folded into the design:**
- VisAnatomy has no plotting code, so it can only evaluate the "agent without skeleton" ablation. The full pipeline needs a benchmark with code, plus masked evaluation (hide the deterministic S2 results and score the agent's proposals against them).
- The compile stage should check structural identity, not pixels.
- Missing security (prompt-injected text written into SVG/HTML) and data-disclosure levels.
- Claim checks need a closed DSL.
- Open-world S2 must be expressed as testable binding hypotheses.
- Ids must stay stable across small code edits.
- Base-graphics S2 can come from the display list (not yet verified).
- Caching and provenance.

**Correction.** The report's "139 primitives" counted 5 clip-path definition rects. 134 primitives are drawn. Fixed in the report, the idea doc, this log and the archive README.

**aisdk 1.5.0 facts relied on** (from `~/Projects/aisdk-family/aisdk`):
- `tool(name, description, parameters = z_object(...), execute)`;
- `create_agent(..., tools, skills, model)` with `$run(task, max_steps)`;
- `generate_object(schema, mode = "tool", max_retries)`;
- `LanguageModelV1` can be subclassed for scripted test models (see `tests/testthat/helper-mock.R`);
- `set_run_trace_sink()`, `schema_to_json()`, `expect_tool_trajectory()`, `eval_task()`, `run_eval_suite()`.

**Working name.** `semsvg`, free on CRAN and GitHub, as are `svgsense` and `grobsense`. Open decisions for the owner: name, repo location, v0 engine scope, default disclosure level.

## Update (same day): design restructured around six capabilities

The owner made two corrections, and the design doc was rewritten accordingly (`dev_docs/semsvg-package-design.qmd`):

1. "Identical to plain svglite" is not a capability, only a regression test; plain SVG export was never the problem. The foundation's value is what it can do with elements: **identify, classify, organize into hierarchies, attach semantics, operate, update.**
2. Semantics are not produced in one pass. They are layered, staged, and continuously added or revised by several agents and by people. The package is therefore a **semantic substrate** (long-lived figure object, append-only layered records anchored to elements, projections as read-only outputs), not a converter.

New spikes (`dev_docs/semantic-svg-research/capture-groups/classify.R`, `hierarchy.R`, with `.out` files):
- Deterministic classification from naming conventions alone: ggplot 132/134 elements, ComplexHeatmap 292/292, base 59/60. The base `legend()` frame and line were **misclassified as data marks**: the legend structure no longer exists after export. That case defines the classify stage: pluggable rules, agent fill-in, correctable records with provenance.
- The semantic tree (panel → layer → mark; legend key → series with colour from `get_guide_data()`) rebuilds deterministically from the grob tree. It also exposed a data problem: panel 2's smooth layer has 3 fewer elements because am=1, cyl=8 has only 2 rows.

Design changes:
- Core model: substrate (graphics + data interfaces), anchors with multiple selector kinds (data key, predicate, structural path, role, region, element id), append-only JSONL layer logs with status propagation and conflict policy, projections.
- Layer DAG: structure → binding → meaning/relation → claim → narrative; behavior and overlay on top; custom layers with schema.
- Operations vocabulary shared by R-side materialization, the browser runtime, and agents; overlays declared by agents and drawn by the substrate.
- Update as a first-class capability: `sem_rebase` → re-anchor → status → repair only what broke.
- The agent layer becomes a set of small staged agents (classify fill-in, bind, meaning, relation, claim, narrative, a11y, interaction design, review, repair), each a client of the substrate API via aisdk `create_agent` + read-only tools + one `propose` tool. `sem_annotate()` is now just a recipe.
- Previous review items R1–R10 are mapped to their new sections in appendix A.

Open decisions added: row-key policy for keyless data, conflict default, single-file round-trip, Web Annotation export.
