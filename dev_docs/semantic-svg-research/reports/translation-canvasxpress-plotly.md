# Translation approach to interactive ggplot2: canvasXpress ggplot interface and plotly::ggplotly()

Date: 2026-11-07. Context: evidence for `ggai/idea/2026-11-07-agentic-semantic-svg.md` (the "agent annotates, never redraws" proposal).
Working dir: `/tmp/ggai_research/translate/`. All paths below are under it unless they start with `/`.

Versions: ggplot2 4.0.3.9000, plotly 4.12.0 installed (the source clone is 4.12.1 @4ff1c33; line numbers below come from that clone), canvasXpress R package 1.70.3 installed from the local clone (`/tmp/ggai_research/src/canvasXpress` @3b0d321) into `/tmp/ggai_research/rlib`, CanvasXpress JS 74.0, patchwork 1.3.2, ggrepel 0.9.8, ComplexHeatmap 2.26.0, headless Chrome 156.

## 0. Summary

- Both tools redraw the figure. They read the ggplot *spec* and paint it again with another engine (plotly.js SVG or the CanvasXpress `<canvas>`). Neither keeps ggplot's geometry.
- plotly follows ggplot most closely when every layer is supported. Even then, pixel drift against `ggsave` is 5.7–9.3% at tolerance 16, with SSIM 0.78–0.84. For comparison, `svglite` viewed in the same browser drifts 1.6–4.8% (SSIM 0.89–0.98).
- canvasXpress drifted 8.6–31.8% (SSIM 0.57–0.73). On our facet + lm + colour figure it drew wrong regression geometry. It turned a `geom_pointrange` forest plot into a bar chart. Neither problem raised a warning.
- Failures are often silent:
  - `ggplotly(patchwork)` renders only the last panel and gives no warning.
  - canvasXpress silently drops any geom that has no JS handler.
  - plotly warns for `GeomTextRepel` and `GeomCustomAnn` and then drops them.
  - ComplexHeatmap is refused by both tools.
- Semantic reach:
  - plotly: L1 (trace ↔ layer/group/panel) and partial L2. L2 means per-trace point index plus a tooltip built from aesthetics; raw-row identity needs `highlight_key()`.
  - canvasXpress: L2 for raw-data geoms. It ships the raw data frame with `Id = row.names`, so tooltips name the row.
  - Neither reaches L3. L4 is a fixed, engine-generic interaction set.
- Pixel diff alone is a weak gate. plotly dropped all 32 ggrepel labels and still scored *better* (6.5%) than canvasXpress, which kept them (8.6%). ggai's verification step needs element-level checks.

---

## 1. canvasXpress mechanism

### 1.1 R side (source reading)

1. `canvasXpress(data = <ggplot>)`: `R/canvasXpress.R:74` skips data validation for `ggplot`/`ggmatrix`/`ggsurvplot`. `:146-150` sends a ggplot to `ggplot.as.list(data, ...)`. `:151-155` handles ggmatrix and `:156-166` ggsurvplot. `:441-445` wraps the result in `htmlwidgets::createWidget("canvasXpress", x = cx_object)`.
2. `ggplot.as.list()` (`R/ggplot_as_list.R:15`):
   - patchwork (`:23-42`): one `gg_cxplot()` per sub-plot `o[[i]]`, plus `isPatchwork`, `cols`/`rows` taken from `o$patches$layout`.
   - ggmatrix (`:43-95`).
   - otherwise `gg_cxplot(o, "canvas")` (`:97`).
   - Serialized with `gg_serialize()` (`:117-136`).
3. `gg_cxplot()` (`:1072`):
   - Rewrites some aesthetics first (`gg_resolve_expr_aes`, `gg_resolve_bar_count_x`, `gg_resolve_const_aes`, `gg_resolve_factor_aes`, sankey/alluvial/forecast hoists; `:1076-1090`).
   - Runs `ggplot_build(o)` (`:1092`).
   - `data_to_matrix(o, bld)` (`:1094`, defined `:2701-2766`) turns the plot-level `o$data` into a character matrix with an `Id = row.names(d)` column (`:2761`). This is the key L2 hook: raw rows travel to the browser.
   - Builds the spec list (`:1096-1115`): `renderTo, data, aes, mappings, scales, coords, theme, labels, facet, order, layers, geoms, meta, isGGPlot, config, isR`.
   - Layer loop (`:1120-1443`): each layer becomes `{geom: class(geom)[1], params: gg_proc_layer(...)}` (`:2388`), with geom-specific patches. Examples:
     - histogram/bar → precomputed bounds;
     - GeomSmooth → only `dataColor/dataFill/dataAlpha` (`:1349`);
     - GeomText/GeomLabel → *built* x/y/label/panel (`:1398`);
     - rect/tile/raster/segment → built bounds.
   - When `geom_smooth(formula=)` is given, `gg_proc_layer` emits the built curve as flat arrays `formula$x/y/ymin/ymax` (`:2500-2515`) **with no `group` or `PANEL` column**. Experiment (a) shows the consequence.
   - Error handling (`:1424-1437`): `skippable_geoms <- character(0)`, so an R-side error in a layer is fatal: `stop("canvasXpress: failed to convert ggplot layer ...")`. An *unknown* geom class does not error on the R side. It is emitted like any other layer.
   - Facets: `gg_facet()` (`:1719-1810`) emits `facet`, `facetType` (wrap/grid), free scales, levels and topology.
   - Theme: `gg_theme()` (`:1812-1876`) flattens every theme element into `"<element>.<prop>"` strings. There were 185 keys in the live smooth example.
   - The spec also carries `decompiled`, an approximate reconstruction of the ggplot code (`:1461`, `R/ggplot_decompiled.R:27`). For figure (a) it produced `facet_wrap(...)` and turned `annotate()` into `geom_text(aes(x = x, y = y), ...)`, so it is lossy (`exp/a_facet_cx_decompiled.txt`).

### 1.2 What reaches the JS (live site + our specs)

- Live example page `https://www.canvasxpress.org/examples/ggplot/smooth.html`: 6 inline `<script>new CanvasXpress({... "isGGPlot": true ...})</script>` blocks. One is saved at `live_smooth_spec1.js`.
- The spec (`renderTo, data[235 rows incl. header], aes{x,y}, mappings, scales, coords, theme[185], labels, facet, order, layers[{..., stat, geom}], geoms, meta, isGGPlot, config, isR`) is the R output shown above. Our own specs are at `exp/*_cx_spec.json`.
- The overview page `ggplot-interface.html` does not load the engine at all. It shows 22 static `geom_*.png` thumbnails and links to `/examples/ggplot/*.html` (`craft_page_show.json`, `craft_site_capture/`).
- **The live engine is byte-identical to the one vendored in the R package.** REA exported `dist/canvasXpress.min.js` from the live page (4,103,253 bytes, sha256 `ea1b74d7…`). It is the same file as `/tmp/ggai_research/src/canvasXpress/inst/htmlwidgets/lib/canvasXpress/canvasXpress.min.js` (header "CanvasXpress 74.0"), even though `inst/htmlwidgets/canvasXpress.yaml` still says `version: 70.3`.

### 1.3 How the JS consumes it

Line numbers refer to the Craft-restored pretty print `cxjs_restored/pretty/canvasXpress.live.min.js`.

- The htmlwidget binding (`inst/htmlwidgets/canvasXpress.js:39-97`) creates a `<canvas>`. It calls `new CanvasXpress(x, ...)` for single plots, or the matrix host for `isPatchwork`/`isGGMatrix`.
- `cxplot()` (pretty L238-420) handles `isGGPlot`:
  - converts `aes`/`order`/`meta`/`mappings` (L256-330);
  - picks a CX `graphType` from the geom list (GeomDensity → Scatter2D, GeomAlluvium → Sankey, L333-344);
  - then, for each geom class name, builds a method name (`"GeomTextRepel"` → `"geom_text_repel"`, L400) and calls it **only if it exists**: `if (j[D] && !j.skipGeoms) j[D](layer)` (L401-404). An unknown geom is skipped with no warning.
  - Labels, scales, coords, theme, facet and config are applied after that (L407-412).
- 63 `geom_*` handler names exist. Besides core geoms they include `geom_text_repel`, `geom_pwc`/`geom_bracket` (ggpubr), `*_pattern` (ggpattern), `geom_alluvium`, `geom_density_ridges`, `geom_sina`, `geom_surv`, `geom_dumbbell`, `geom_forecast`. **Absent:** `geom_pointrange`, `geom_linerange`, `geom_spoke`, `geom_label_repel`, `geom_sf`, `geom_map`, and every custom grob or `annotation_custom`.
- Handlers translate onto CanvasXpress's own config instead of drawing ggplot's built geometry:
  - `geom_smooth` sets `showLoessFit` or, for `method == "lm"`, `showRegressionFit`, plus `showConfidenceIntervals` (pretty L176870-176955). The engine then fits the curve itself in JS. Without `formula=` this is what happens, and the engine also draws regression equations that ggplot never drew (the vendor's own page shows this: `craft_smooth_crop_color.png`; so does our `shots/montage_a4_noformula.png`).
  - `geom_text_repel` sets `optimizeTextPosition = true` (L177465), i.e. CX's own label placer, not ggrepel's.
- The JS identifiers are obfuscated through an encoded alias table (`CanvasXpress.alias`, L205738). Only string-keyed names (`geom_*`, config keys) are readable.

### 1.4 Supported, unsupported, themes

- Supported means "has a JS handler", not "faithful". Results:
  - (a) colour + `lm` + facet: wrong geometry.
  - (e) `geom_pointrange`: silently became a bar chart of `est` by row index, with the vline drawn horizontally.
  - The vendor's own side-by-side pages show drift too: extra or missing tick breaks, smaller points, different loess shape in facet "r", and added regression equations (`craft_smooth_crop1.png`, `craft_smooth_crop_facet.png`).
- Facets: wrap and grid are supported (topology, levels, free scales). In (a) the per-panel fit was lost and one curve was replicated in both panels.
- Themes: flattened `theme.*` props mapped onto CX config (the `GGPlot` style). Fonts and sizes differ visibly: strip and legend text is much smaller.
- Unsupported handling: an R-side failure raises an error. A geom with no JS handler is silently skipped. Non-ggplot input gets `stop("data must be a data.frame, matrix, or named list")` (`R/internal_functionality.R:131`). A ggplot wrapping a ComplexHeatmap grob via `annotation_custom` gave R error "node stack overflow".

### 1.5 Licensing

- The R package is GPL-3 (`DESCRIPTION`).
- The JS library is source-available under the "CanvasXpress Community License". It is not OSI open source.
  - It is free, including commercial use, provided the rendered attribution mark stays visible.
  - A commercial license (per developer, $360/yr individual) issues a key that removes the mark.
  - The license-key check and mark rendering are declared a technological protection measure, with an anti-circumvention clause (bundle header; license page captured in `craft_license_capture/page.html`).
- Our R-generated widgets show a "CanvasXpress" mark bottom-right. The license FAQ says R-package use "is unbranded". **Unverified** how those two fit together.
- Implication: ggai should not vendor or depend on the JS. Borrow ideas, not code.

## 2. plotly mechanism (source reading + emitted JSON)

1. `ggplotly()` is an S3 generic (`R/ggplotly.R:68`).
   - Methods: `ggplotly.ggplot` (`:146` → `gg2list` → `as_widget`), `ggplotly.ggmatrix` (`:87`, builds `subplot()`s), and `NULL`/`plotly`.
   - There is no patchwork method. A patchwork object has class `patchwork | ggplot2::ggplot | ggplot | ...`, so it goes to `ggplotly.ggplot`, and only the base plot is converted (the last one added; the earlier ones live in `$patches`). Verified in experiment (b): no warning.
2. `gg2list()` (`:174`) runs `ggplotly_build()` (`:216-455`), described as "Our internal version of ggplot2::ggplot_build(). Modified from ggplot2 plot-build.r". It re-implements ggplot's build pipeline step by step so it can capture:
   - `prestats_data`;
   - the crosstalk key (`:261-276`) and nested keys for stat layers (`:357-366`);
   - group domains;
   - pre-scale "domain" values (`:305`, `:410`).

   This copy of internals is a fidelity and maintenance liability.
3. Facets: panel → axis anchors (`:509-547`, special cases for FacetWrap free scales at `:518-540`). Each trace gets `xaxis`/`yaxis` from `layout$layout[PANEL, ]` (`R/layers2traces.R:160`). Strips become layout annotations plus rect shapes (`R/ggplotly.R:929-966`).
4. `layers2traces()` (`R/layers2traces.R:2`):
   - `to_basic()` lowers high-level geoms (`:97`). For example, `GeomSmooth` becomes `GeomPath` + `GeomPolygon` ribbon (`:229-243`).
   - The data is split by discrete legend scales, PANEL and frame (`:118-134`).
   - `geom2trace()` is dispatched per split (`:135`), and the crosstalk `set` is attached (`:137`).
   - `legendgroup` is set (`:139-157`).
5. `layers2layout()` (`R/layers2layout.R:2`) handles only `GeomRasterAnn` as an image. Its comment at `:27` reads "TODO: maybe we could support a subset of grobs in GeomCustomAnn?"
6. **Tooltip source** (`R/layers2traces.R:7-76`):
   - Per layer, `map = getAesMap(p, layer)` (`R/ggplotly.R:1532`) plus calculated aesthetics (`after_stat`), turned into labels with `make_labels`.
   - Filtered by the `tooltip=` argument (`:28-32`).
   - Positions are dropped when hovering on fills (`:35-37`).
   - The text is built as `"<var>: <value>"` from the pre-scale `<aes>_plotlyDomain` column when present (`:64-72`). The `text` aesthetic is taken verbatim (`:64`). Bars report `ymax - ymin` (`:69-71`).
   - Observed: `"wt: 1.835<br />mpg: 33.9<br />cyl_f: 4"`. Row identity is absent (`shots/montage_hover_a_facet.png`).
7. **Unsupported geoms degrade** through two defaults:
   - `to_basic.default` returns the data unchanged (`:688`).
   - `geom2trace.default` warns `"geom_<Class>() has yet to be implemented in plotly"` and returns `list()` (`:986-994`), so the layer vanishes.
   - Observed for `GeomTextRepel` (c), where all labels were dropped, and `GeomCustomAnn` (d, blank output).
   - An unknown aesthetic converter warns at `:1140`.
8. **`highlight_key()` / crosstalk:**
   - `highlight_key.default` returns `crosstalk::SharedData$new()` (`R/plotly_data.R:112`).
   - `fortify.SharedData` adds `.crossTalkKey` and the `set` attribute (`:321-327`).
   - Identity-stat layers get `key` as an aesthetic (1 mark : 1 row). Stat layers get **nested keys per (PANEL, group)**, so a smooth line carries the keys of all rows it summarises. Verified: the 6 smooth-line traces carry 3/8/4/3/12/2 car keys each (`exp/conversion_log.json`, `a_highlight_key`).
   - `highlight()` stores `on/off/persistent/color/opacityDim/selected` in `p$x$highlight` (`R/highlight.R:152`).
   - At runtime `crosstalk.SelectionHandle(set)` (`inst/htmlwidgets/plotly.js:429`) broadcasts keys. `TraceManager.updateSelection` (`:632`) matches `trace.key` against selected keys within the same `set`, adds highlighted copies, and dims the originals.
   - The linked behaviour after a click was not visually verified; the description comes from source and the emitted keys.

---

## 3. Experiment

Script: `scripts/run_experiments.R` (+ `run_variants.R`, `svg_baseline.R`).

- Ground truth: `ggsave` PNG at 700×500 px, 96 dpi, ragg.
- plotly and canvasXpress widgets were saved with zero padding, served on 127.0.0.1:8791, and captured at an exact 700×500 viewport with **REA `capture-web-screenshot`** (headless Chrome, window 700×587 → viewport 700×500).
- svglite baselines (geometry preserved, viewed in the same browser) were captured with **Craft `web-page-screenshot-take`** via `--cdp-endpoint`.
- Pixel diffs used **both Craft `web-pixels-compare`** (tolerance 16, `common_area`, which adds layout similarity and SSIM) **and REA `compare-web-screenshots`** (channel threshold 16). Changed-pixel counts were identical across the two tools for all 31 pairs (`pixel_diffs.csv`).
- Side-by-side montages (gg | plotly | cx) are in `shots/montage_*.png`.

Figures:
- (a) mtcars `wt`~`mpg`, colour = factor(cyl), `geom_point` + `geom_smooth(lm, formula = y ~ x)` + `facet_wrap(~am)` + `annotate("text")`.
- (b) patchwork `p1 + p2` (scatter + boxplot).
- (c) `geom_text_repel`.
- (d) ComplexHeatmap with a top annotation.
- (e) extra: `geom_pointrange` forest plot + `geom_vline`.
- Diagnostic variants of (a): a1 no annotate, a2 no facet, a3 points + facet + annotate, a4 lm *without* `formula=`.

### 3.1 Results (diff = share of pixels differing by more than 16 on any channel; SSIM = Craft perceptual similarity)

| Figure | Tool | Converted? | Warnings | Diff | SSIM | Qualitative drift |
|---|---|---|---|---|---|---|
| (a) | svglite (baseline) | yes | – | 1.6% | 0.97 | font antialiasing only |
| (a) | plotly | yes, 20 traces | only ggplot's own `qt` NaN (cyl 8, am 1 has 2 pts) | 7.5% | 0.82 | data, fits, ribbons, strips and annotate correct; larger fonts; legend keys lose line glyph; panel widths and axis spacing shift |
| (a) | canvasXpress | yes | none | 24.7% | 0.57 | **wrong**: one black zig-zag polyline through all groups' fits; ribbons malformed; the same curve copied into both panels; annotate text clipped; y range 5–40; hover on a point returns ":Decoration-0" |
| a2 (no facet) | cx / plotly | yes | – | 12.5% / 9.3% | 0.73 / 0.78 | cx still joins the 3 group fits into one black line |
| a3 (no smooth) | cx / plotly | yes | – | 11.6% / 6.7% | 0.70 / 0.80 | cx points correct; annotation clipped; small strip fonts |
| a4 (lm, no formula) | cx | yes | – | 17.9% | 0.62 | fits now computed by CX JS and close to ggplot, but adds unrequested regression equations and drops the 2-point cyl-8 fit in panel 1 |
| (b) | svglite | yes | – | 2.2% | 0.95 | – |
| (b) | plotly | **silently partial** | **none** | 26.6% | 0.68 | only the boxplot (last patch) rendered, full width; scatter lost |
| (b) | canvasXpress | yes (`isPatchwork`, 2 cells) | none | 18.9% | 0.67 | both panels; tiny legend fonts; x title "wt" collides with the attribution mark |
| (c) | svglite | yes | – | 4.8% | 0.89 | repel positions shift slightly (draw-time layout depends on font metrics) |
| (c) | plotly | partial | `geom_GeomTextRepel() has yet to be implemented` | 6.5% | 0.76 | **all 32 labels dropped**; points only |
| (c) | canvasXpress | yes (handler) | none | 8.6% | 0.70 | labels placed by CX `optimizeTextPosition`: overlap points, no leader segments, smaller; tooltip shows car name |
| (e) | svglite | yes | – | 1.6% | 0.96 | – |
| (e) | plotly | yes | none | 5.7% | 0.84 | correct (lines+markers); smaller point |
| (e) | canvasXpress | **silently wrong** | none | 31.8% | 0.69 | bar chart of `est` vs row index 1–4; vline drawn as a horizontal dashed line; no ranges; legend "est" |
| (d) | svglite | yes | – | 2.0% | 0.98 | – |
| (d) | plotly | **no** | error `no applicable method for 'ggplotly' ... "Heatmap"` | – | – | – |
| (d) | canvasXpress | **no** | error `data must be a data.frame, matrix, or named list` | – | – | – |
| (d) grob in `annotation_custom` | plotly | "yes" | `geom_GeomCustomAnn() has yet to be implemented` | 65.7% | 0.66 | blank page; diff identical to the blank-page calibration |
| (d) grob in `annotation_custom` | canvasXpress | no | R error "node stack overflow" | – | – | – |

Calibration: a blank white page scores 53–78% diff against these figures.

Other evidence:
- **Hover:** `shots/montage_hover_a_facet.png` and `shots/montage_hover_cx_points.png`.
  - plotly shows aesthetics only.
  - canvasXpress shows `Toyota Corolla / wt / mpg` (row Id), but omits `cyl`.
- **DOM** (Craft `web-page-show` + CDP eval):
  - plotly draws 32 `path.point` SVG nodes. Each has a d3 `__data__` = `{x, y, i, tx, trace}` (point index within trace + hovertext) and **no id or data-attributes in the markup**.
  - canvasXpress draws 1 `<canvas role="img" aria-label="Scatter2D chart. X axis wt, Y axis mpg. 32 series, 2 samples. Values 1.51 to 33.9.">` plus a visually hidden `<table><caption>Data table for chart` with 32 rows (car, mpg, wt). It has no per-mark DOM.

### 3.2 Diagnosis of the canvasXpress failure in (a)

- With `formula = y ~ x`, the R side flattens the built smooth (480 rows = 6 group×panel fits × 80 points) into bare `x/y/ymin/ymax` arrays with no group or PANEL key (`R/ggplot_as_list.R:2500-2515`). The JS evidently draws them as one path and one ribbon and repeats them per panel. This root cause is inferred from code and output; the JS draw routine itself was not traced.
- Without `formula=` (a4), the JS refits per colour group itself. That fits better, but it adds equations and drops a degenerate fit.
- So both code paths diverge from ggplot, in different ways.

---

## 4. Semantic levels reached

| Level | plotly `ggplotly` | canvasXpress |
|---|---|---|
| L0 geometry | redrawn by plotly.js (SVG); not ggplot geometry; 5.7–9.3% drift when fully supported | redrawn on canvas; 8.6–31.8% drift; no vector or DOM per mark |
| L1 structure | yes for supported layers: trace ↔ (layer, discrete group, PANEL) (`layers2traces.R:118-160`), `legendgroup` ↔ legend entry, axes per panel. Strips and axis titles become anonymous layout annotations | inside the engine only (layers, facets, "Decoration-N" hit targets); not exposed in markup |
| L2 data binding | point ↔ index within trace + aesthetic hovertext. Raw-row identity only with `highlight_key()` (1:1 for identity stats; nested group keys for stat layers) | raw plot data shipped with `Id = row.names`: tooltips and the hidden a11y table name the row. Lost for stat layers on the `formula=` path (no group/PANEL) |
| L3 domain meaning | none (variable names only) | none (aria-label exposes the engine model: "32 series, 2 samples") |
| L4 interaction intent | fixed generic set (hover, zoom/pan, legend toggle; `highlight()` options chosen in code) | fixed generic CX toolbar and hover; not designed per figure |

Which inputs:
- **plotly** covers ggplot core geoms that have `to_basic`/`geom2trace` methods, plus a few extensions with methods (ggridges, ggalluvial strata; `R/ggridges.R`, `layers2traces.R:660-687`), ggmatrix/GGally, and facets.
  - Fails: extension geoms without methods (ggrepel), `annotation_custom` grobs, patchwork (silently), ComplexHeatmap, base, grid.
- **canvasXpress** covers geoms with one of the 63 JS handlers, plus patchwork, ggmatrix and ggsurvplot.
  - Fails: geoms without a handler (silently), non-ggplot objects, custom grobs.

**What is structurally impossible for a translator:**
1. Anything not in its translation table: extension geoms whose meaning lives in `draw_panel`/`draw_group` code, custom grobs, ComplexHeatmap, base, circlize, grid.
2. Faithful L0. Both re-layout with their own text metrics, ticks, legend and strip rules, and canvasXpress re-computes stats.
3. L3. The spec holds variable names, not domain meaning.
4. Per-figure L4. Interaction is the engine's fixed vocabulary.
5. Keeping up with ggplot internals (plotly copies the build pipeline; canvasXpress tracks ggplot2 dev changes, e.g. the `band_gp` workaround at `gg_proc_layer`).

---

## 5. What ggai should borrow, and what it means for the design

Borrow:
1. **Tooltip from aesthetics (plotly):**
   - Per layer, take the mapping (aesthetic → variable label, including `after_stat` calculated aesthetics), filter it by a `tooltip` allow-list, and render values from the *pre-scale domain* (plotly's `_plotlyDomain`), not scaled codes. Treat a `text` aesthetic as verbatim.
   - This is a deterministic default L4 tooltip ggai can compute from `ggplot_build()` + mapping at skeleton time. The agent then only overrides labels with L3 wording.
2. **The crosstalk key/set model (plotly + crosstalk):**
   - Every raw row has a key; a dataset has a set (group name).
   - Identity-stat marks carry one key. Aggregate marks (smooth, boxplot, bar) carry the *nested* keys of the rows they summarise per (PANEL, group).
   - Selection broadcasts keys and non-matching marks dim (`opacityDim`).
   - This is exactly the L2 "stat geoms bind to raw rows via group keys" in the idea doc. Adopting `data-key` / `data-set` semantics, ideally crosstalk-compatible, would let a ggai SVG link with DT, leaflet or plotly widgets for free.
3. **Spec shape (canvasXpress):**
   - A positional, self-describing `layers` array (`{geom, stat, params}`), a data matrix with an explicit `Id`, explicit facet topology, and a code reconstruction (`decompiled`). These are good fields for `skeleton.json`.
   - **Do not copy its lossy step.** Every emitted element must keep `(layer, PANEL, group, row/keys)`. The (a) failure is what happens when stat output loses them.
4. **Accessibility pattern (canvasXpress):** an `aria-label` summary plus a visually hidden data table. ggai's compile stage should emit `<title>`/`<desc>`/ARIA and a table, filled with L3 text instead of engine internals.
5. **Fixture corpus (canvasXpress tests):** one tiny deterministic builder per geom/feature with golden JSON (`tests/testthat/helper-ggplot-corpus.R`). ggai's skeleton needs the same per-geom alignment fixtures.

Implications for "agent annotates, never redraws":
- **The evidence supports the principle.**
  - Keeping geometry (svglite in the browser) drifts 1.6–4.8%.
  - The best translator drifts 5.7–9.3% when it fully supports the figure, and fails outright (errors, silent drops, wrong charts) on patchwork, extension geoms, pointrange (CX) and ComplexHeatmap.
  - Redrawing turns every new geom into translation code: a closed world. Annotating keeps L0 and L1 open-world and moves only L2–L4 into a verifiable layer.
- **Both translators fail silently.** ggai's verify stage must assert per-layer element counts against `ggplot_build()` rows and row bindings. It must not rely on a whole-image pixel diff: dropping 32 labels changed only about 1.5 percentage points of pixels.
- **Even "never redraw" has device sensitivity.** ggrepel positions depend on font metrics: the svglite diff for (c) was 4.8%, against 1.6% elsewhere. So the skeleton and the delivered SVG must come from the *same* render, and the reference PNG should be rasterized from that SVG. A separate device run needs a tolerance.
- **Out of scope by design:** what translators do well is re-computation on interaction (zoom with re-ticking, filtering that refits stats). That needs a live engine. Hand that case to plotly or Shiny, consistent with the idea doc's non-goals.

---

## 6. Tool log (what REA and Craft contributed)

### Craft Anything CLI 0.5.0

| Command | Result | Value vs source reading |
|---|---|---|
| `web-site-open` then `web-site-capture` as **separate CLI calls** | capture failed: "Each CLI command starts its own browser and closes it when it ends" | Learned: **no browser session persists across CLI invocations**. Workarounds: drive `craft-anything-cli --deep --allow-run mcp` over JSON-RPC (`scripts/craft_mcp.py`), or point tools at an external CDP endpoint |
| `web-page-show` (default) | refused: `feature_missing / clean_room`; needs `--deep` | – |
| `--deep web-page-show` on ggplot-interface.html (CDP 9333) | 5 scripts, no engine on the overview page (`craft_page_show.json`) | **Beat source**: showed the overview page is static images and pointed to the example pages |
| MCP `web_site_open` + `web_site_capture` (ggplot-interface, smooth example, license) | full-page PNG + rendered HTML (`craft_site_capture/`, `craft_smooth_capture/`, `craft_license_capture/`) | **Beat source**: the live spec as shipped (6 `new CanvasXpress({isGGPlot})` blocks), the vendor's own ggplot-vs-CX side by side (drift + added equations), current license terms |
| `web-page-js-analyze` (smooth example) | 8 scripts, 6604 functions; engine exports `cxplot`, `aes`, `init`; named methods (`facet_wrap`, `facet_grid`, `ggtitle`, `theme`, `addGeom`, `initGeometry*`) in seconds (`craft_js_analyze_smooth.json`) | Useful API-surface map of the JS; not in the R source |
| `js-sources-restore` on the 4.1 MB bundle | pretty print, 213,714 lines; no module split (scope-hoisted); local names stay minified (`cxjs_restored/`) | **Essential**: made the `cxplot` dispatcher, the silent skip and the geom handlers grep-able |
| `js-function-explain` seed `cxplot` | 0.4 s: 39 callees, caller `d.prototype.render`, string table including the geom-name munging (`craft_fn_explain_cxplot.json`) | Confirmed the dispatch slice; positions are "line 27" of the one-line minified file, so citations use the pretty-print lines |
| `web-page-screenshot-take` (own session) | viewport 756×469 for a requested 700×500 window | Not usable for pixel diffs; fine via `--cdp-endpoint` on a correctly sized Chrome (svglite baselines) |
| `web-pixels-compare --common-area` | diff fraction, layout similarity, SSIM for 31 pairs (`pixel_diffs.csv`) | Main quantitative metric; SSIM and layout similarity were useful beyond raw diff |
| `web-page-show` on widget pages | DOM counts: plotly 104 paths / 32 `path.point`; CX 2 canvas + hidden 33-row table | Pointed to the a11y table, which we then inspected via CDP |

### REA 6.8.0

| Command | Result | Value |
|---|---|---|
| `analyze-web-bundle --detail summary` | rejected: requires an undocumented `--view` JSON | – |
| `analyze-web-bundle` (complete), per-script deadline 30 s and then 240 s | captured 13 scripts incl. `canvasXpress.min.js` (sha256 `ea1b74d7…`); **JS analysis of the engine timed out both times** (`rea/smooth_bundle_complete*.json`) | Gave identity hashes only; no structural findings for the engine |
| `inspect-web-page --include-script-sources` + `export-web-scripts` | exported live scripts (`rea/smooth_scripts/`); inline spec scripts not exported (attach-limited / policy-filtered) | **Beat source**: proved the live engine = the vendored R-package copy (v74.0, despite yaml 70.3) |
| `capture-browser-scenario` | `--schema` shows only `inputJson`; the real schema is in `rea-agents/dist/mcp-catalog-full.json`. No coordinate hover action | Not used further |
| `capture-web-screenshot` (16 tabs, CDP 9334) | exact 700×500 PNG artifacts once the window was sized 700×587; `--allowed-origins '["..."]'` was rejected (left at the default) | Reliable fixed-viewport capture for all widget comparisons |
| `compare-web-screenshots` | works on `{sha256, bytes, media_type, data_base64}` artifacts (ggsave PNGs wrapped the same way); changed counts identical to Craft | Independent cross-check of every pixel number |

Neither tool could hover at coordinates or read d3 `__data__`. Two small CDP scripts covered those gaps: `scripts/cdp_hover.mjs` and `scripts/cdp_eval.mjs`. Both were run only against our own 127.0.0.1 pages.

**Verdict.** Source reading of the two R packages gave the mechanism. The tools added four things source reading could not:
1. the spec and engine as deployed live, and their identity with the vendored copy;
2. the vendor's own fidelity evidence;
3. a searchable engine showing the silent geom skip;
4. reproducible fixed-size screenshots with two independent pixel metrics.

Craft was stronger for JS analysis; REA's analyzer timed out on the obfuscated 4 MB bundle. REA was simpler for fixed-viewport screenshots and the identity check. Both were clumsy about browser session state and viewport sizing, which cost several retries.

## 7. Unverified / caveats

- Root cause of the (a) canvasXpress failure: inferred from R code and output; the JS drawing routine was not traced. Likewise, why (e) became a bar chart is inferred from the missing `geom_pointrange` handler plus the `graphType` fallback.
- `geom_label_repel` and other absent handlers (linerange, spoke, sf) are *expected* to be dropped silently; only pointrange was tested.
- plotly linked brushing after a click was not visually exercised; it is documented from source plus the emitted `key`/`set`.
- The attribution mark on R-generated widgets versus the license FAQ's "R package ... unbranded": not resolved.
- canvasXpress test "pixel snapshots" (`helper-ggplot-corpus.R` mentions them) were not inspected.
- Fidelity numbers are specific to the versions above; canvasXpress's ggplot support changes often (see its NEWS.md).
- The tooltip "contains row identity" result for canvasXpress depends on meaningful `row.names` (mtcars has them; a tibble would give "1", "2", ...).

## 8. Artifact index

- `scripts/`: `run_experiments.R`, `run_variants.R`, `svg_baseline.R`, `pixel_compare.py`, `craft_mcp.py`, `cdp_hover.mjs`, `cdp_eval.mjs`, plus Craft call files.
- `exp/`: ggsave PNGs, widget HTML, `*_plotly.json`, `*_cx_spec.json`, `conversion_log.json`, svglite SVGs.
- `shots/`: REA and Craft screenshots, `montage_*.png`, hover captures.
- `pixel_diffs.csv` / `pixel_diffs.json`.
- `craft_*` (page show, captures, js analyze, restore, function explain), `cxjs_restored/`, `live_smooth_spec1.js`.
- `rea/`: bundle analyses, page inspection, exported scripts, screenshot evidence, artifacts.
