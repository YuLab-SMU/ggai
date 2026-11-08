# ggiraph and gridSVG as prior art for ggai semantic SVG

Date: 2026-11-07. Scope: the questions in the brief (ggiraph R side, coverage, reuse as a skeleton, JS side, gridSVG).
Work dir: `/tmp/ggai_research/ggiraph/` (`scripts/`, `out/`, `tooling/`). Every number below comes from a script in `scripts/` with a log in `out/`, or from a tool output in `tooling/`. Anything not verified is marked **(unverified)**.

## 0. Versions (they differ, and that matters)

| Thing | Version | Note |
|---|---|---|
| ggiraph installed (used for all R and browser runs) | 0.9.2 | `~/Library/R/arm64/4.5/library/ggiraph` |
| ggiraph source read | 0.9.7.007 (`/tmp/ggai_research/src/ggiraph`, HEAD `8515a2b` "fix: load girafe.js once") | Installed 0.9.2 behaved as this source describes on every R/C++ path I exercised (files not diffed). JS differs: 0.9.5 moved from mouse events to pointer events and added `linked` |
| ggiraph on CRAN | 0.9.6, published 2026-02-21, 55 reverse deps (incl. ggtree) | WebFetch of CRAN page |
| gridSVG | 1.7-7 (CRAN 2025-10-31, Paul Murrell; local clone last commit 2026-10-22) | installed only into `/tmp/ggai_research/rlib` from the local clone |
| ggplot2 / R | 4.0.3.9000 / 4.5.2 | |
| Licences | ggiraph GPL-3, gridSVG GPL; ggai is MIT | ggai can depend on them (Suggests/Imports) but cannot copy their code |

## 1. ggiraph mechanism, step by step

### 1.1 R side: from aesthetic to grob

1. **Layer construction.** `geom_point_interactive(...)` = `layer_interactive(geom_point, ...)` (`R/geom_point_interactive.R:18-20`). `layer_interactive()` (`R/layer_interactive.R:6-81`) removes the interactive aesthetics (`data_id`, `tooltip`, `onclick`, `hover_css`, `selected_css`, `tooltip_fill`, `hover_nearest`; list in `R/ipar.R:120-128`) from the mapping and params. It then builds the normal ggplot2 layer, swaps `layer$geom` for `GeomInteractive<Name>` (lookup by name: `find_interactive_class`, `:85-130`, which aborts with "Can't find interactive Geom" for unknown geoms), puts the aesthetics back, and appends a `.ipar` geom parameter.
2. **ggplot_build.** The interactive aesthetics are ordinary aesthetics, so they travel through stat, position, and facet splitting like `colour`. After build, `data_id`/`tooltip` are columns of `ggplot_build(p)$data[[i]]`. For stat layers they are evaluated per **built** row: one per box, one per bin, one per smooth group.
3. **draw_panel.** `GeomInteractivePoint$draw_panel` calls the stock `GeomPoint$draw_panel`, then `add_interactive_attrs(zz, coords)` (`R/geom_point_interactive.R:40-42`). That function (`R/ipar.R:217-287`) prepends the class `interactive_<cls>_grob` and stores the values on the grob as `$.interactive` (a list of vectors, one value per data row), `$.ipar`, and `$.data_attr` (`do_add_interactive_attrs`, `:291-334`). For a gTree, data rows are handed to children only if `nrow(data) == length(children)`, otherwise `abort("Can't add interactive attrs to gTree")` (`:258-274`). Points with line-based shapes (pch 3, 4, 7-14) are split into one grob per shape, because each such point emits several primitives (`:44-58`).
4. **Role namespaces.** Data marks get `data-id`. Legend keys get `key-id` (`interactive_geom_draw_key`, `R/utils.R:79-82`; guide titles and labels: `R/guide_interactive.R:236,244`). Theme elements, strips, and titles get `theme-id` (`R/element_interactive.R:152`). These three attribute names are the only L1-ish role information ggiraph writes.

### 1.2 Device side: how ids reach SVG elements (C++ `dsvg`)

5. `girafe()` opens `dsvg` with a random `canvas_id = "svg_<8 hex>"` and either `print(ggobj)` or evaluates `code` (`R/girafe.R:139,173,177`).
6. Every interactive grob class has a `drawDetails` method that wraps the normal drawing in a **tracer** (`R/interactive_points_grob.R:18-25`): `dsvg_tracer_on()`, then `NextMethod()` (grid draws the points), then `ids <- dsvg_tracer_off()`, then `interactive_attr_toxml(x, ids)`.
7. In C++, `DSVG_dev::svg_element()` registers a new element with the tracer **only while tracing is on** (`src/dsvg_dev.cpp:117-120`). `IndexedElements::push` assigns `id="<canvas_id>_e<n>"`, where n is a running counter (`src/indexed.cpp:29-38`, suffix `_e` set in `src/interactive.h:19-20`). The tracer records the first and last index (`src/interactive.cpp:17-30`), and `collect_id()` returns the contiguous range `first:last` (`:68-88`).
8. `interactive_attr_toxml()` (`R/ipar.R:360-422`) maps `tooltip` to `title` and `data_id` to `data-id`/`key-id`/`theme-id`, then calls `set_attr(name, ids, values)` (`R/tracers.R:42-87`). That function recycles values: a scalar goes to all elements; if the element count is a multiple of the value count it uses `rep(values, each = k)` (`:58-66`). Otherwise it warns "mismatched lengths of ids and values (most often ... clipping or ... NAs)" and sets **nothing** for that grob (`:68-75`). `add_attribute()` writes the attributes into the tinyxml2 DOM. `hover_css` and `selected_css` become CSS rules keyed by `[data-id = "..."]` (`src/interactive.cpp:99-166`).

### 1.3 How element ↔ row is guaranteed, and where it isn't

* **Across grobs:** by value, not by order. The `data_id` vector travels inside the grob's own data subset (per PANEL), so ggiraph never aligns the whole SVG against the built data. Observed: SVG circle order is PANEL-major (Hornet 4 Drive, Hornet Sportabout, ...), while `ggplot_build()` rows are in original row order (Mazda RX4, ...). `identical()` is FALSE, yet every circle carries the right `data-id` (`out/e2_log.txt`).
* **Within one grob: by emission order.** `values[i]` is assigned to the i-th element the device emitted while tracing. When one datum emits more or fewer primitives than one, ggiraph relies on the `rep(each=)` heuristic. That is the draw-order risk, inside ggiraph itself (see §5).

## 2. Coverage

Source counts: 51 `geom_*_interactive`, 94 `scale_*_interactive`, 4 guides (legend, bins, colourbar, coloursteps), 3 `element_*_interactive`, `facet_wrap/grid_interactive`, `labeller_interactive`, `label_interactive`, `annotate_interactive`, `annotation_raster_interactive`, and 12 exported `interactive_*_grob` constructors (`NAMESPACE`). Grob classes with tracer-wrapped draw methods: circle, lines, path, points, polygon, polyline, raster, rect, segments, text, xspline (`drawDetails`); curve, repeltree, roundrect (`makeContent`); dotstack (`makeContext`). The only extension geoms covered are ggrepel, ggbeeswarm (`quasirandom`), and sf.

Observed in `girafe()` output (counts of primitives inside the root `<g>`; `scripts/e2_girafe_html.R`, `scripts/e4_coverage_failures.R`, `out/e4_log.txt`):

| Case | primitives | id | data-id | key-id | theme-id |
|---|---|---|---|---|---|
| Brief's figure (interactive points + plain smooth + facet + interactive legend) | 137 | 35 | 32 | 3 | 0 |
| Same plot, all plain ggplot2 layers | 132 | **0** | 0 | 0 | 0 |
| `element_*_interactive` + `labeller_interactive` + `label_interactive` title | 114 | 47 | 34 | 0 | 13 |
| patchwork `p1 + p2` (points + boxplot) | 129 | 44 | 44 | 0 | 0 |
| cowplot `plot_grid(p1, p2)` | 128 | 44 | 44 | 0 | 0 |
| **base** `plot()` via `girafe(code=)` | 56 | **0** | 0 | 0 | 0 |
| **ComplexHeatmap** `draw(Heatmap())` via `girafe(code=)` | 212 | **0** | 0 | 0 | 0 |
| plain grid `interactive_points_grob(...)` | 6 | 5 | 5 | 0 | 0 |
| `geom_boxplot_interactive` (3 boxes) | 52 | 12 | 12 | - | - |
| `geom_smooth_interactive` | 38 | 4 | 4 | - | - |
| `geom_histogram_interactive` (8 bins) | 44 | 8 | 8 | - | - |

* **Non-interactive layers get nothing:** no id and no attribute. In the brief's figure the smooth lines and ribbons, axes, strips, and text are anonymous, and CSS sets `pointer-events: none` on them (`inst/htmlwidgets/girafe.css:153-163`).
* **Base graphics:** nothing. Nothing calls the tracer, so `girafe(code = plot(...))` gives a static SVG.
* **ComplexHeatmap and other grid code:** nothing, unless the code itself draws `interactive_*_grob`s.
* **patchwork and cowplot:** work, because the interactive grobs survive composition.
* **Stat layers** bind to built (summary) rows, not raw rows.

## 3. Reusing dsvg as ggai's deterministic skeleton (Q3): yes, proven

There is no exported "make this grob interactive" function. `add_interactive_attrs` and the tracer (`set_tracer_on`, `collect_id`, `set_tracer_off`, `add_attribute`) are internal. Two ways work anyway:

**(a) Own tracer via internals.** `scripts/tag_all.R`: `grid.force()` the gtable, walk it, prepend class `ggai_tagged` to every leaf grob, and register `drawDetails.ggai_tagged`, which does tracer on, `NextMethod()`, `collect_id`, then writes `data-ggai-path` (child-name path), `data-ggai-i` (emission index), `data-ggai-class`, and `data-ggai-vp` (`current.vpPath()`). It also logs, per leaf, the expected count (from the grob's vectors) against the emitted count.

**(b) No `:::`.** `scripts/e3c_exported_path.R` re-classes each leaf to ggiraph's registered `interactive_<cls>_grob` and sets `.interactive = list(data_id = path)`, `.data_attr = "data-ggai-path"`. This uses only registered S3 methods, but still depends on ggiraph's internal grob fields.

Results on the spike plot (`out/e3_log.txt`, `out/e3c_log.txt`, `out/e3d_log.txt`, `out/e3_leaf_log.csv`):

* **133 of 134** primitives in the root `<g>` are tagged (route (a) and route (b) both). The only untagged one is the device's page background rect. Compare 0 ids with svglite and 35 with idiomatic ggiraph.
* There are 62 leaf grobs. Point leaves: panel 1 emitted 19 circles for 19 built rows, panel 2 emitted 13 for 13. Spearman(cx, built x) = 1.0, and fill equals the built `colour` for every circle. The 3 legend circles are separable by path (`/guide-box-right.../key-*`). Strips, axes, annotate text, smooth line, and ribbon all get paths.
* Six leaves have expected ≠ emitted. Four are `panel.grid.major` polylines (expected 5/6, emitted 3/4: breaks outside the range become NA and are dropped). Two are the NaN ribbon of the 2-point `cyl=8, am=1` group (expected 1, emitted 0).
* **Geometry-neutral:** after stripping ids and `data-ggai-*`, the 134 primitives are byte-identical to a plain `print(p)` on dsvg (`scripts/e3d_geom_identity.R`). Pixel diff against svglite: 1.02% of pixels differ by more than 25/255 (fonts and antialiasing).
* **Other engines** (`out/e5_log.txt`, `out/e5c_log.txt`):
  * patchwork: 139 of 140 tagged.
  * Base graphics via `gridGraphics::echoGrob`: 63 of 64 tagged. Leaves are named `graphics-plot-1-points-1` (32 circles, Spearman vs `mtcars$wt` = 1) and `...points-2` (3 legend symbols).
  * ComplexHeatmap via `grid.grabExpr`: 227 of 228 tagged, but the **grob names are anonymous** (`GRID.rect.218`). The semantics live in the **viewport path**: 40 rects in `z_heatmap_body_1_1` (8×5 matrix), 26 lines in `z_dend_row_1`, 16 in `z_dend_column_1`, and `annotation_cyl_1`. The body-rect ↔ matrix-cell order was not checked **(unverified)**.
* Timing for one cold run: tagged render ≈1.0 s; dsvg plain `print(p)` 1.0 s; svglite 0.14 s; gridSVG export 0.5 s. dsvg startup is dominated by font lookup, which 0.9.7 claims to speed up **(unverified)**.

## 4. JS side (girafe widget)

The brief's figure was built as `out/e2_girafe.html` (self-contained, 707 KB) and as `serve/nsc/index.html` (external libs, selection enabled statically with `only_shiny = FALSE`). Both were served on 127.0.0.1:18731 to a headless Chrome on 127.0.0.1:19222. Both are now stopped.

* **Attributes per element, from the DOM after render:** each data circle has `id=svg_mtcars_eN`, `title=<tooltip>`, `data-id=<car>`. Legend circles have `id`, `key-id=cyl4|6|8`, `title`. The smooth polylines and polygons, axes, strips, and text have no id. `title` stays on the element: the a11y tree (Craft `web-page-show`) lists 35 `graphics-symbol` nodes named by the tooltip text, so tooltips double as accessible names.
* **Event binding is delegated.** Craft `web-listeners-list`:
  * a data circle, a legend key, and the smooth polyline each have **0 listeners**;
  * `#svg_mtcars` has 5 (`mouseover`, `mouseout`, `mousedown`, `wheel` with capture=true; `mousemove` with capture=false), plus `click` when selection is active (6 total);
  * all of them point to `girafe.js` line 0, column 298316. That column is `MouseHandler.handleEvent` in the minified bundle.

  Source: `srcjs/modules/mouse.js:19-47` calls `svgNode.addEventListener(type, this, type !== 'pointermove')`, and handlers match `event.target` by attribute (`hover.js`, `selection.js` `isValidTarget`).
* **State:** at init, each handler collects `querySelectorAll('[data-id]')` (or `[key-id]`/`[theme-id]`) and stores the element **ids** (`selection.js:39`, `hover.js:32`). State is shown by toggling CSS classes such as `hover_data_<svgid>` and `select_data_<svgid>`. Craft walkthrough after the clicks: `select_data_svg_mtcars` appeared on a data circle and `select_key_svg_mtcars` on the cyl4 legend key (`tooling/craft_walk_nsc.out.json`, screenshot `tooling/craft_walk_nsc_final.png`).
* **Shiny:**
  * `Shiny.onInputChange(<outputId>_selected | _key_selected | _theme_selected | _hovered ..., [ids])` (`selection.js:169`, `hover.js:117`; suffixes in `svg.js:136-204`).
  * The server pushes selections back through custom messages `<outputId>_set`, `_key_set`, `_theme_set`.
  * Selection is created only in Shiny unless `only_shiny = FALSE` (`svg.js:212`; default `TRUE` at `R/girafe_options.R:331`). The static page therefore had no `click` listener.

  This whole Shiny path was read from source and not run in Shiny **(unverified at runtime)**.
* **Legend ↔ data linking** (`opts_hover/opts_selection(linked = TRUE)`, 0.9.5+) forwards **the same id strings** to the other handler (`svg.js` `linkedHandlers`, `hover.js:120`). It only works when `key-id` values equal `data-id` values, so per-row ids (car names) cannot be linked to a group key (cyl). Read from source only; 0.9.2 has no `linked` **(unverified at runtime)**.
* **0.9.2 loads `girafe.js` twice:** Craft listed two identical 317,177-byte scripts (`ggiraphjs-0.9.2` and `girafe-binding-0.9.2`; `cmp` confirms they are identical). This matches the 0.9.7 NEWS fix (#361).

## 5. Failure and limit cases observed

1. **Silent misbinding from `rep(each=)`** (`out/e4b_log.txt`): labels `c("a\nb\nc", "d")` with ids `ID1, ID2` emit 4 `<text>`s. The ids are recycled `each = 2`, so **"c" (part of ID1's label) is tagged ID2**, with no warning.
2. **All-or-nothing drop:** labels `c("a\nb", "c", "d")` emit 4 elements for 3 ids, so the warning fires and **0** texts get ids.
3. **Several primitives per datum:** mixed pch 16/3/8 gives **81** `data-id` elements for 32 rows (32 distinct ids). Correct, but only because of the shape-splitting special case.
4. **NA / non-finite:** in the tag-all run, grid lines emitted fewer elements than their vectors (NA breaks dropped) and a NaN ribbon emitted 0. ggiraph's issue #325 (NA in grouped `geom_line_interactive`) was a mismatch of this kind; on 0.9.2 the reproduction (`out/e4c_log.txt`) gives 3 polylines, all with `data-id`, because a `fill_na` hook handles it (`R/geom_ribbon_interactive.R:60`, `R/ipar.R:398`).
5. **Clipping:** I could not reproduce the clipping mismatch that the warning text mentions. `coord_cartesian` windows that cut away 11 of 32 points still emitted 32 circles **(clipping-driven mismatch unverified)**.
6. **Overplotting defeats pointer picking.**
   * Craft walkthrough: clicking `circle[data-id="Valiant"]` selected **Merc 280C**, an overlapping circle drawn later.
   * REA/Playwright: the same click **timed out** at 10 s, consistent with another element intercepting pointer events.
   * ggiraph's mitigation is `hover_nearest` (`nearest.js`).
7. **Ids are not stable or semantic:** `canvas_id` is random, and `_eN` is a running counter of traced elements only, so adding a layer renumbers everything.
8. Not reached at all: unsupported extension geoms (abort at layer creation), base graphics, ComplexHeatmap, anything outside the role triplet data/key/theme.

## 6. gridSVG (Q5)

* **How it works:** gridSVG is its own SVG writer in R, not a graphics device. `grid.export()` calls `grid.force()`, then `grid.grab()`s the page, then walks it and writes SVG per primitive (`R/gridsvg.R:55,121`). So binding does not depend on device emission order: sub-elements are numbered by **vector index** in explicit loops (`subGrobName(x$name, 1:n)`, `R/griddev.R:38-41,1137,1223,1354`). Non-finite elements are skipped but **keep their number** (`R/svg.R:1146`). Observed: `panel.grid.major.y..polyline.235.1.2` exists while `.1.1` (the NA line) does not.
* **Id scheme:**
  * groups: `<grobName>.<usage>`, e.g. `geom_point.points.190.1`;
  * elements: `<grobName>.<usage>.<i>`, e.g. `geom_point.points.190.1.3` (a `<use>` of a pch symbol);
  * text: `GRID.text.50.1.1.text`;
  * viewports: `layout::strip-t-1-1.9-7-9-7.1` (vpPath with `::`, from `usePaths = "vpPaths"`; uniqueness suffixes from `getID`, `R/griddev.R:506-550`);
  * `exportMappings = "file"` writes `gridSVGMappings` (grob name → suffix, CSS selector, XPath), `out/e6_gridsvg.svg.mappings.js`.
* **Works with ggplot2 4.0.3.9000** (`out/e6_log*.txt`): 139 primitives (35 `<use>`, 60 polyline, 21 text, ...), 133 with id, 254 of 255 `<g>` with id, all ids unique. Export takes 0.49-0.51 s. Fidelity against svglite: 1.12% of pixels differ by more than 25/255 at 1008×576, close to dsvg-tagged's 1.02% (`out/e6d_log.txt`). Visual side-by-side: `out/e6_svglite_vs_gridsvg.png`.
* **`grid.garnish` with ggplot2:**
  * Garnishing must happen **after `grid.force()`**: before forcing, `grid.ls()` shows 0 `geom_point` grobs.
  * With per-element vectors and `group = FALSE`, it works: 32 of 32 `<use>` got `data-row` (`out/e6b_log.txt`).
  * Pitfalls: default `strict = TRUE` strips `data-*` attributes (`R/svg.R:1665-1677`; minimal tests in `out/e6c_log.txt`). A **scalar** attribute with `group = FALSE` on a 19-point grob produced malformed XML ("Attribute id redefined") and the export **aborted**.
* **Grob names carry session counters** (`.190` in one run, `.13` in another), so the ids are not stable across sessions.
* **Status:** active on CRAN (1.7-7), with 6 reverse imports including plotROC and Bioconductor arrayQualityMetrics. CRAN check results not inspected **(unverified)**.

## 7. Semantic levels reached

| | L0 | L1 structure | L2 data binding | L3 meaning | L4 interaction |
|---|---|---|---|---|---|
| ggiraph, idiomatic | dsvg (device-exact) | coarse role only (data/key/theme attribute), no grob/layer/panel; non-interactive layers none | per built row for `*_interactive` geoms, by user-mapped key; stat layers at summary rows; within-grob order heuristics | user-written tooltip text only | fixed menu chosen up front: tooltip, hover, select, onclick, zoom, lasso, nearest; key↔data link only by identical id strings |
| ggiraph dsvg + ggai tag-all (proof) | same | **every** primitive: grob path, vp path, class, emission index | join point leaves to built rows by PANEL (exact counts here); detectable mismatches per leaf | none | none (ggai's job) |
| gridSVG | re-implemented writer (~1% pixel diff) | every element and group: grob name, vpPath, mapping file | index-explicit within grob; garnish can attach row ids | none | none built in; garnish plus your own JS |

## 8. What ggai could borrow, and what it means for the design

1. **The tracer pattern is the key idea.** Bracketing each leaf grob's drawing gives the *exact* set of SVG elements that grob emitted. That turns the spike's global draw-order alignment (139 primitives in one sequence) into **local, checkable** alignment. Within each leaf, the expected count can be compared with the emitted count, and a mismatch fails closed instead of misbinding.
2. **Use the tracer without forking ggiraph.** Route (b) above is enough for a prototype, but it depends on undocumented fields. Route (a) needs `:::`, which CRAN rejects. Options:
   * ask upstream to export a small tracer API;
   * ship ggai's own minimal device (heavy);
   * try a device-agnostic **sentinel** variant with svglite: wrap `drawDetails` to emit a marker primitive before and after each leaf. This was not tried **(unverified idea)**.

   The licence (GPL vs MIT) means ggai should depend on ggiraph, not copy from it.
3. **Record the vp path for every element.** It is what makes ComplexHeatmap (and probably other `grid.grabExpr` engines) structurally legible.
4. **Do not copy ggiraph's `rep(each=)` recycling.** Use per-class expansion rules (text lines, pch-with-lines, polyline `id`s, NA-dropped rows), and verify them against emitted counts.
5. **Borrow from gridSVG's format:** index-explicit ids, the mapping file (name → selector/XPath), and the garnish rule (scalar → group, vector → per element). This is a precedent for `skeleton.json`. Do not take its re-implemented writer, which has fidelity risk; dsvg is the real device.
6. **JS runtime lessons:**
   * one delegated listener on the SVG root (capture);
   * attribute selectors plus class toggling;
   * `pointer-events: none` for non-interactive marks;
   * nearest-mark picking for overplotting;
   * Shiny inputs named `<id>_selected`;
   * keep `title`/ARIA so the a11y tree exposes marks.

   Avoid ggiraph's single-id-per-element limit. ggai's semantics need several keys per element (row id, group/series id, legend key), so linking is many-to-one, not string equality.
7. **Risk update for the idea doc:** order alignment across the whole SVG is unnecessary if a tracer is available. The remaining risk is *within-grob* multiplicity, and it is measurable: 6 of 62 leaves mismatched in the spike, none of them data-point leaves. The pick-render fallback stays useful for non-dsvg devices.

## 9. Tool log (what REA and Craft actually contributed)

| Tool / command | Input | Result | Beat source reading? |
|---|---|---|---|
| Craft `web-browser-connect --cdp-endpoint` | own headless Chrome on 127.0.0.1:19222 | needs global `--deep` (clean-room error otherwise); OK | n/a |
| Craft `web-page-show --with-accessibility-text` | both pages (`tooling/craft_page_show*.json`) | aggregate DOM (counts by tag, attribute *names*); script list (showed `girafe.js` loaded twice); a11y tree (35 `graphics-symbol` named by tooltip). Self-contained page: inline scripts collapsed into 1 entry | partly: a11y and the double-load were new; per-element attributes needed xml2/DOM text |
| Craft `web-listeners-list` | circle, key, smooth polyline, svg root, rootg, containers (`tooling/craft_listeners_*.json`) | **decisive**: 0 listeners on marks; 5-6 on `<svg>` with capture flags; location → `handleEvent` column in the minified bundle | **yes** (runtime fact, confirms delegation and the `only_shiny` effect) |
| Craft `web-walkthrough-record` (click ×2, DOM after each step) | needs `--allow-run`; action field `kind` | revealed the overlap (Valiant click selected Merc 280C) and the key selection class. On the self-contained page the DOM capture was **truncated at 262,143 chars** before the SVG (inline JS fills the budget), so an external-lib build was needed | **yes** (overlap behaviour) |
| Craft `js-app-map` | installed minified `girafe.js` 0.9.2 | 0.12 s; 2063 functions; 53 d3 `.on()` handler edges (zoom/drag/brush/lasso); **missed** dynamic `addEventListener(type, this, capture)`; no bundler or vendor detected | no |
| REA `analyze-javascript-application` | repo `srcjs/` (16 files) | 8 s; module import graph (svg.js hub → tooltip, hover, selection, nearest, mouse, zoom, toolbar, png, fullscreen; factory → svg; widget → factory); 30 `registers-listener`, all d3 `.on`; **missed** the MouseHandler listener; 14 "endpoint" nodes are false positives (`Map.get('pointerover')` etc. read as network endpoints) | no (16 readable files are faster to read) |
| REA same | installed bundle 0.9.2 (310 KB min) | **timed out** at the 300 s default | no |
| REA same | repo bundle 0.9.7 (118 KB) | 15.5 s; 1 webpack chunk, 8 modules; 0 listener registrations; 10,962 unknowns; same false-positive endpoints | no |
| REA `capture-browser-scenario` (Playwright launch) | wait_for, click circle, click key | wait OK; **click timed out** (overlap); later steps cancelled; DOM per step OK. Schema has no `hover` action | marginal (corroborated the overlap) |

Net: the runtime browser tools (Craft listeners, walkthrough DOM, a11y tree) produced facts I would otherwise have had to infer. The static JS analysers (REA and Craft js-app-map) were weaker than reading `srcjs/` directly: they miss the one listener that matters and add false positives.

## 10. Unverified items

* Shiny round-trip (`input$<id>_selected`, `_set` messages): source only.
* `linked` hover/selection (0.9.5+): source only; installed 0.9.2 lacks it.
* Clipping-caused id mismatches: not reproduced.
* Sentinel-based tracer for svglite: idea only.
* ComplexHeatmap body rect ↔ matrix cell order.
* gridSVG CRAN check status.
* Timings are single cold runs.

## 11. Artifact index

* Scripts: `/tmp/ggai_research/ggiraph/scripts/` (`e2_girafe_html.R`, `e2b_nonself.R`, `tag_all.R`, `e3_tag_all_spike.R`, `e3c_exported_path.R`, `e3d_geom_identity.R`, `e4_coverage_failures.R`, `e4b_text_edge.R`, `e4c_issue325.R`, `e5_tag_all_engines.R`, `e5c_chm_vp.R`, `e6_gridsvg.R`, `e6b_garnish.R`, `e6c_garnish_min.R`, `e6d_pixdiff.R`)
* Outputs: `/tmp/ggai_research/ggiraph/out/` (SVGs, logs, `e3_leaf_log.csv`, `e6_svglite_vs_gridsvg.png`)
* Tool outputs: `/tmp/ggai_research/ggiraph/tooling/` (`craft_*.json`, `craft_walk_nsc_final.png`, `rea_*.summary.json`, `rea_*.extract.txt`, `rea_scenario_hover.out.json`)
