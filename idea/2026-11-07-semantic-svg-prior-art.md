# Semantic SVG export: prior art and measured evidence

> Companion to [2026-11-07-agentic-semantic-svg.md](2026-11-07-agentic-semantic-svg.md).
> Date: 2026-11-07. Owner: Yonghe Xia.
> Method: four parallel investigations (device tagging, raster hit-testing, spec translation, literature), each combining source reading with two reverse-engineering tools, [REA](https://github.com/morluto/rea) 6.8.0 and [Craft Anything](https://github.com/storytold/craft-anything) 0.5.0, for runtime evidence.
> Raw reports, scripts and captures are archived in [`dev_docs/semantic-svg-research/`](../dev_docs/semantic-svg-research/README.md), including `reports/{ggiraph-gridsvg,shiny-static-interaction,translation-canvasxpress-plotly,literature-ecosystem}.md`. The full Chinese report is [`dev_docs/semantic-svg-research-report.qmd`](../dev_docs/semantic-svg-research-report.qmd).

## Summary

Existing work falls into four families. None of them combines geometry-faithful output, an open world, and verified semantics:

| Family | Examples | Geometry | S1 structure | S2 data binding | S3 meaning | S4 interaction | World |
|---|---|---|---|---|---|---|---|
| **Spec translation** (redraw in another engine) | `plotly::ggplotly`, canvasXpress | Redrawn; measured drift 6–32% of pixels | Trace ↔ layer | Partial; raw rows need `highlight_key()` | — | Engine's fixed set | Closed. Unsupported input is dropped, often silently. |
| **Raster + data-space hit test** | Shiny `plotOutput` + `nearPoints` | Exact (PNG) | Panel only, ggplot only | Nearest-neighbour guess at query time | — | Click/brush/hover | Closed |
| **Raster + recorded positions** | InteractiveComplexHeatmap | Exact (PNG) | Heatmap/slice | Exact for matrix cells | — | Fixed | ComplexHeatmap only |
| **Device-level tagging** | ggiraph `dsvg`, gridSVG, **maidr** | Exact | ggiraph: three-way role split. gridSVG and maidr: every grob. | ggiraph: `*_interactive` geoms only. maidr: about 40 hand-written geom processors. | ggiraph: user tooltip text | Fixed menu (ggiraph) or a11y runtime (maidr) | Closed. Unknown layers get no data. |
| **SVG deconstruction, heuristic or LLM** | DIVI, Mystique, VisAnatomy baselines, CSL, Athanor | Kept | Inferred (role F1 about 0.84; on R charts GPT-4o 0.692 vs DeepSeek-V3 0.959) | Inferred | LLM, unverified | NL-authored or fixed | Open, but ungrounded |

**What ggai would add**, now that the field has been mapped:
1. Open-world S2: the agent proposes bindings for layers no processor knows, and each proposal is verified against built data.
2. S3 meaning and relations between elements (legend key ↔ series, label ↔ point, bracket ↔ group pair, annotation track ↔ cluster) as first-class output.
3. A per-figure S4 interaction design, chosen from a closed vocabulary.
4. A verification gate.

**What ggai would not add:** grob ↔ SVG element tagging (ggiraph, gridSVG, maidr already do this), LLM role labelling (VisAnatomy, CSL), ARIA output (Vega, maidr).

> Naming note: "Semantic SVG / SSVG" is already used by CSL (arXiv 2026), and "L1–L4" is Lundgard & Satyanarayan's model of semantic content in chart descriptions (TVCG 2022). The idea doc now uses **S0–S4** for our levels.

## 1. Device-level tagging: ggiraph, gridSVG, maidr

### ggiraph (0.9.2 installed; source 0.9.7.007)

**Mechanism.**
- `layer_interactive()` swaps in `GeomInteractive*` and carries `data_id` and `tooltip` through `ggplot_build` as ordinary aesthetics (`R/layer_interactive.R:6-81`).
- `draw_panel` adds the class `interactive_<cls>_grob` (`R/ipar.R:217-334`).
- `drawDetails.interactive_*_grob` turns a C++ tracer on, draws, and turns it off (`R/interactive_points_grob.R:18-25`). While the tracer is on, the `dsvg` device records each element it creates (`src/dsvg_dev.cpp:117-120`, spot-checked). Value *i* is then assigned to the *i*-th emitted element (`R/tracers.R:42-87`).

**Key experiment.** Wrapping *every* leaf grob of the spike plot in the tracer tagged **133 of 134** primitives. The one exception is the device's own background rect. Spot-checked: each element carries `data-ggai-path` (full grob path), `data-ggai-i` (index within the grob) and `data-ggai-class`. Geometry is byte-identical to plain `print(p)` once the ids are stripped.
- Same method on other engines: patchwork 139/140, base graphics via `gridGraphics` 63/64, ComplexHeatmap 227/228.
- In ComplexHeatmap, the meaning sits in viewport names (`z_heatmap_body_1_1`, `z_dend_row_1`, `annotation_cyl_1`).

**Per-grob count check.** 6 of 62 leaves emitted a different number of elements than expected. All of them were grid lines with NA breaks or a NaN ribbon; none were data marks. With a tracer, the draw-order risk shrinks from "align the whole SVG" to "check the count inside each grob", and that is checkable.

**Failures observed in ggiraph itself.**
- **Silent misbinding.** Labels `"a\nb\nc"` and `"d"` emit 4 text elements. Line "c" gets the second label's id, with no warning.
- **Count mismatch drops everything.** 4 elements for 3 ids → ggiraph warns and drops them all.
- **Overlap blocks clicks.** Clicking "Valiant" selected "Merc 280C".
- **Unstable ids.** The canvas id is random and `_eN` is a running counter.
- **Untagged by default.** Without the tag-everything wrapper, plain ggplot layers, base `plot()`, and ComplexHeatmap (0 of 212 elements) get no ids.

**JS runtime.** One delegated listener sits on the `<svg>` root (Craft `web-listeners-list`: 0 listeners on marks, 5–6 on the root, all pointing to `MouseHandler.handleEvent`). Elements are found with attribute selectors and styled by toggling classes; non-interactive marks get `pointer-events: none`.

### gridSVG (CRAN 1.7-7, 2025-10-31)

- Works with ggplot2 4.x. Export takes about 0.5 s, and 1.12% of pixels differ from svglite.
- Element ids are indexed by data, e.g. `geom_point.points.190.1.3`, and a selector/XPath mapping file is written alongside.
- Pitfalls:
  - Grob names carry session counters, so ids are not stable across runs.
  - The default `strict=TRUE` strips `data-*` attributes.
  - `grid.garnish` must run after `grid.force()`.

### maidr (CRAN 0.5.0, 2026-09-29, GPL-3; mechanism spot-checked)

**Exporter** (`R/svg_export.R`):
1. `grid.force()` + `grid.grab()` the scene.
2. Walk it the way gridSVG does, redrawing each grob onto svglite. Before each draw call, insert an invisible text marker `@@maidr-svg-mark@@k`.
3. Read the markers back and remove them.

The result is gridSVG-compatible `<g id="<name>.<k>">` with exact geometry. This also solves draw-order alignment, without needing a custom device.

**Data and coverage.**
- Data comes from about 40 per-geom processors across ggplot2, base R, lattice, patchwork, pheatmap and ComplexHeatmap (heat cells, simple annotations and dendrograms; marked experimental).
- `Ggplot2UnknownLayerProcessor` returns empty data and empty selectors, so the system is closed-world.
- The runtime is a fixed accessibility layer: keyboard navigation, screen reader, sonification, braille.

**Consequence.** Per-grob capture has been proven feasible twice over. The open-world part (unknown layers, S3, S4, relations, verification) is not done anywhere.

**Decision (2026-11-07).** These packages are methodological reference only. ggai takes no dependency on them, copies no code, and designs its own capture mechanism (plan Task 2). They remain available as comparison baselines in dev scripts.

## 2. Raster + hit testing: Shiny, InteractiveComplexHeatmap

### Shiny `plotOutput` (cited from the 1.14-dev source; ran 1.11.1, same coordmap code)

**Mechanism.**
- `getGgplotCoordmap` (`R/render-plot.R:579`) emits one entry per panel: data domain, pixel range, log base, and facet values.
- Column names come from the **first layer only** (`:704`, spot-checked).
- The coordmap is deliberately kept out of the DOM (`srcts/src/bindings/output/image.ts:111`, spot-checked).
- `nearPoints()` / `brushedPoints()` project the raw columns to pixels and filter by distance.

**Measured.** Clicked the drawn position of each of 32 points and checked whether `nearPoints` recovered the right row:

| Case | Recovered |
|---|---|
| plain, facet_wrap, facet_grid, free scales, coord_flip, log, reverse, coord_fixed | 32/32 each |
| discrete x | 27/32 (the misses are the overplotted ties) |
| `geom_jitter` | 1/32 |
| `coord_polar` | 0/32 |
| any layer after the first | 0/32 |

- Engines without a real coordmap: patchwork, lattice, grid and ComplexHeatmap get a meaningless whole-image coordmap (a click on a live patchwork sent `x=0.5`). Base `par(mfrow)` maps only the last panel.
- Legend clicks are dropped. A brush cannot cross facets.
- Related upstream issues, all open: rstudio/shiny#2411, #1703, #2422, #2938, #2300.

### InteractiveComplexHeatmap

- `htPositionsOnDevice` (`R/interactive.R:560`) records each heatmap block's device box with `deviceLoc` right after `draw()`.
- A click maps to a cell by fraction × slice size over the cluster order.
- 80,000 cells → a 6-row, 4.5 KB position table; exact cell recovered. It works off Shiny on a plain PNG device.
- Limits: annotation values are joined by index, for 4 annotation types only. Dendrograms, annotation tracks and legends cannot be clicked.

### Scale (measured)

At 10^5 points:

| Output | Size |
|---|---|
| Plain svglite SVG (no ids yet) | 10.2 MB |
| PNG | 478 KB |
| Binary point index | 1.17 MB raw |

Raster + index is a viable fallback for dense layers.

## 3. Spec translation: plotly, canvasXpress

### Mechanisms

**plotly.** `ggplotly` → `gg2list` (a copy of the ggplot2 build pipeline, `R/ggplotly.R:216`) → `layers2traces`.
- Tooltips are built from the aesthetic mapping (`R/layers2traces.R:7-76`).
- An unsupported geom hits `geom2trace.default`, which emits a warning and returns `list()`, so the layer disappears (`R/layers2traces.R:986-994`, spot-checked).
- There is no patchwork method.
- `highlight_key()` attaches crosstalk keys, nested per summarised row for stat layers.

**canvasXpress.** `canvasXpress()` → `ggplot.as.list()` → `gg_cxplot()`, which ships raw data, aes, the flattened theme and a per-layer `{geom, stat, params}` list.
- The JS calls `geom_<name>` only if such a handler exists, so geoms without one are skipped with no warning. This was found in the restored 4 MB bundle with Craft `js-sources-restore`.
- 63 geom handlers. The engine re-fits smooths and re-places repel labels itself.
- The JS licence is source-available, free only while the attribution mark is visible: borrow ideas, don't depend on it.

### Experiment (700×500 px; diff = share of pixels off by more than 16 levels; SSIM in brackets)

| Figure | svglite baseline | plotly | canvasXpress |
|---|---|---|---|
| (a) facet + lm + colour + annotate | 1.6% (0.97) | 7.5% (0.82); data correct, legend keys lose the line | 24.7% (0.57). One black zig-zag through all fits, copied into both panels; annotation clipped (screenshot checked). |
| (b) patchwork | 2.2% | **only the last panel, no warning** (screenshot checked), 26.6% | both panels, 18.9%; tiny fonts, collisions |
| (c) ggrepel | 4.8% | warns, **all 32 labels dropped**, 6.5% | own label placement, 8.6%; no leader lines |
| (d) ComplexHeatmap | 2.0% | error, or blank when wrapped as a grob | error, or stack overflow when wrapped as a grob |
| (e) pointrange forest plot | 1.6% | correct, 5.7% | **silently a bar chart with the axes swapped** (screenshot checked), 31.8% |

**A pixel diff alone is not a sufficient check.** plotly dropped every label and still scored better than canvasXpress. Verification needs per-layer element counts and row bindings as well.

## 4. Literature (verified against primary sources by the survey unless marked)

**Chart deconstruction.**
- ReVision (Savva et al., UIST 2011).
- D3 Deconstructor (Harper & Agrawala, UIST 2014). Exact binding through D3's `__data__`; D3 only.
- Poco & Heer (CGF/EuroVis 2017).
- ChartDetective (Masson et al., CHI 2023).
- Mystique (Chen et al., TVCG 2024).
- DIVI (Snyder & Heer, TVCG 2024). Heuristic runtime deconstruction of ggplot2 and matplotlib SVG, plus an interaction taxonomy.
- MSC (Liu et al., TVCG 2025).

**Corpus.** VisAnatomy (Chen et al., TVCG/VIS 2025, https://github.com/hdi-umd/VisAnatomy): 942 SVG charts from 50+ tools, including R, with 383k labelled elements. LLM role labelling: mean F1 ≈ 0.84; **on R charts, GPT-4o 0.692 vs DeepSeek-V3 0.959** (checked against arXiv 2410.12268 §3.1).

**LLM on SVG, 2026, arXiv only.**
- CSL (arXiv 2606.09782). LLM plus deterministic grounding over deployed SVG; calls its output "SSVG"; accuracy 0.82–0.86. Grouping primitives before prompting improves accuracy, which supports sending the agent a compressed skeleton.
- Athanor (arXiv 2601.17736). A multimodal LLM turns a static SVG into an interactive constraint model.

**Chart-to-code** (ChartMimic, Plot2Code, ChartCoder, ChartEdit). All of these regenerate the chart. ChartEdit: GPT-4o scores 59.96 without the source code and 89.96 with it. This supports keeping code canonical.

**Accessibility.**
- WAI-ARIA Graphics Module 1.0 (W3C Rec 2018).
- SVG-AAM (Working Draft).
- Vega ≥ 5.11 ARIA output.
- Olli; Data Navigator (TVCG 2024); Chartability (CGF 2022); MAIDR (CHI 2024).
- Claim provenance (Direct / Derived / Speculative; Blanco, Zong & Satyanarayan, arXiv 2026).

## 5. Lessons for ggai (methodology only, no dependencies)

| From | Lesson | Why |
|---|---|---|
| ggiraph `dsvg` tracer, maidr marker walk | Capture elements per grob, not by whole-SVG draw order | Proven feasible; ggai designs its own mechanism (plan Task 2) |
| Our own tag-everything experiment | Per-leaf expected-vs-emitted count; **fail closed** | ggiraph's `rep(each=)` recycling misbinds silently |
| ComplexHeatmap viewports | Record the viewport path for every element | That is where heatmap semantics live |
| InteractiveComplexHeatmap | Panel and block boxes recorded from the viewport tree **after drawing** | Shiny's re-derived gtable maths breaks on every non-ggplot engine |
| InteractiveComplexHeatmap + Shiny scale measurement | Grid-like layers: block boxes + order vectors. Dense layers (≳10^4 marks): raster + binary index keyed by (layer, panel, built row). | 10^5-point SVG = 10.2 MB |
| plotly | Tooltip-from-aesthetics as a free default | Cheap baseline before the agent adds anything |
| crosstalk | Key/set model, with nested keys for stat layers | Our S2 group-key binding; interoperates with DT and plotly |
| ggiraph JS | One delegated listener on the root; attribute selectors; class toggling; `pointer-events: none` on decoration; nearest-mark picking | Small, proven runtime design |
| WAI-ARIA Graphics + Vega | Root `graphics-document`, panels as nested documents, layers/guides `graphics-object`, marks `graphics-symbol`; decoration hidden; no per-item ARIA on dense layers | Standard target for the compile step |
| maidr | What an accessibility runtime needs from the data (navigation order, per-series values) | Informs our a11y fields; interop with its schema is not planned |
| VisAnatomy | Role taxonomy plus its R subset as an evaluation set; "agent without skeleton" ablation against the published R-chart baselines (0.692 / 0.959) | External, citable benchmark |
| DIVI | Interaction taxonomy (target × type × input) as the closed S4 vocabulary | Constrains the agent's interaction design |
| Claim provenance work | Tag agent claims Direct / Derived / Speculative; verify Direct claims against built rows | Makes S3 auditable |

## 6. Tool evaluation: REA and Craft Anything

| Use | Best tool | Notes |
|---|---|---|
| Wire payloads (websocket frames, click/brush inputs) | REA `capture-browser-scenario` | Kept the 181 KB coordmap frame and showed that a base-plot click sends nothing. No drag; clicks only at element centres. |
| Which element actually has listeners | Craft `web-listeners-list` | Decisive for ggiraph (0 on marks, 5–6 on the root). Both tools stop at jQuery's dispatcher for Shiny. |
| Reading a minified engine | Craft `js-sources-restore` + `js-function-explain` | Exposed canvasXpress's silent geom skip. REA `analyze-web-bundle` timed out on the 4 MB bundle (30 s and 240 s). |
| Source map recovery | REA `analyze-web-bundle` | Recovered 148 Shiny TS module paths, which proved the deployed JS matches the clone |
| Pixel comparison | Both | Identical changed-pixel counts on all 31 comparisons. REA screenshots were exact 700×500; Craft's were 756×469. |
| Static JS analysis of small bundles | Neither | Both missed ggiraph's single `addEventListener`. REA misread `Map.get('pointerover')` as network endpoints and timed out on the 310 KB 0.9.2 bundle. |

**Friction.**
- The Craft CLI does not keep a browser open between invocations. It has to be driven through MCP mode or an external CDP endpoint, and most page tools need `--deep`.
- Neither tool can hover or drag at coordinates; small Playwright/CDP scripts filled the gap.

**Net.** Source reading explained the mechanisms. The tools added what reading cannot: real payloads, actual listener placement, silent drops, and drift measurements.
