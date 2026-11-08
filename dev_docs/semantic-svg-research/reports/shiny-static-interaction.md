# How Shiny and InteractiveComplexHeatmap make raster plots interactive

Date: 2026-11-07. Context: input to the ggai idea `idea/2026-11-07-agentic-semantic-svg.md`.

**Versions.** Shiny source is the clone at `/tmp/ggai_research/src/shiny` (1.14.0.9000, commit 1f85217). All file:line citations refer to that clone. The installed and observed runtime was shiny 1.11.1.

The two versions behave the same:

- The R coordmap functions (`getCoordmap`, `getPrevPlotCoordmap`, `getGgplotCoordmap`, `find_panel_info_api`, `find_panel_ranges`) are byte-identical, checked with `deparse()`.
- The deployed TypeScript was recovered from `shiny.min.js.map`. It differs from the clone only in lint comments, trailing commas and a `findImageOutputs` refactor.

Other versions: InteractiveComplexHeatmap (ICH) is the clone at `/tmp/ggai_research/src/InteractiveComplexHeatmap` (1.19.1, commit 8b617e7), installed into `/tmp/ggai_research/rlib`. ggplot2 is 4.0.3.9000 and ComplexHeatmap is 2.26.0.

All raw outputs are under `/tmp/ggai_research/shiny/`. The artifact index is at the end of this report.

---

## TL;DR

- **Shiny attaches no semantics to elements.** It sends a PNG plus a small **coordmap**: one record per panel holding the data-space `domain`, the image-pixel `range`, `log` bases, discrete limits, facet values and the **first layer's** x/y variable names. The browser inverts the linear (or log) map and sends data-space `x/y` plus the panel's facet values. On the server, `nearPoints()`/`brushedPoints()` then re-scan a **user-supplied data frame** by column name.
- Nothing ties a pixel to a layer, a grob, or a built row.
- **It works when** drawn position = f(raw column) and f is linear or log. That covers point geoms with facets (wrap, grid, free scales), `coord_flip`, log and reverse scales, and `coord_fixed`: 32/32 points recovered in every one of those cases.
- **It fails silently** on:
  - jitter: 1/32 recovered;
  - stacked or dodged positions;
  - `coord_polar`: 0/32;
  - any layer after the first: 0/32;
  - expression mappings such as `factor(cyl)` or `wt*1000` (error unless you pass `xvar`);
  - patchwork, lattice, grid and ComplexHeatmap: the coordmap degenerates to "whole image, domain ≈ 0..1";
  - base `par(mfrow)`: only the last panel is mapped.
- Legends and other guides are simply "outside every panel", and clicks on them are dropped.
- **ICH** keeps Shiny's raster and transport but throws away Shiny's data-space numbers. At draw time it records the device bounding box of every named heatmap-body viewport (`<ht>_heatmap_body_<i>_<j>`). A click becomes a row/column index by pure arithmetic over the row/column order within the slice. It is **exact** for cells, and **O(slices) memory for O(cells) marks**: 80,000 cells reduce to a 6-row table of 4.5 KB.
- ICH does not hit-test annotations or dendrograms. Annotation values are joined by index after a cell is found.
- It runs outside Shiny on any R device (verified). It still needs R at query time, but the index is small and portable.
- **For ggai:** borrow (a) a per-panel coordmap recorded **from the viewport tree at draw time** (the ICH approach generalised; Shiny's gtable arithmetic is what breaks on non-ggplot engines), and (b) a raster-plus-index mode for dense layers.
- That index should be **pixel-space hit-testing against built data, keyed by (layer, PANEL, built row)**, not Shiny's data-space inversion against raw columns. This is exactly what fixes Shiny's failure list.

---

## 1. Mechanism, step by step

### 1.1 Server: render → PNG + coordmap

| Step | Where | What happens |
|---|---|---|
| Open the device | `R/render-plot.R:226-240`, `R/imageutils.R` `startPNG()` | Opens a PNG device (ragg, quartz or Cairo) at `width*pixelratio` × `height*pixelratio`. `pixelratio` is the browser's `devicePixelRatio`, sent as `.clientdata_pixelratio` (seen in the websocket init frame). `startPNG` calls `plot.new()` with `mar = 0`, which matters for the fallback below. |
| Intercept ggplot printing | `render-plot.R:268-270`, `custom_print.ggplot` at `:334-347` | Inside `renderPlot`, `print.ggplot` (and `` `print.ggplot2::ggplot` `` for ggplot2 ≥ 4) is rebound so that printing returns `structure(list(build = ggplot_build(x), gtable = ggplot_gtable(build)), class = "ggplot_build_gtable")`. Any other class (patchwork, trellis, Heatmap) uses its own print method and returns something else. |
| Build the coordmap | `render-plot.R:294`, dispatcher `getCoordmap` at `:522-528` | A `ggplot_build_gtable` goes to `getGgplotCoordmap()`. **Everything else** goes to `getPrevPlotCoordmap()`, which reads base-graphics state. |
| Base graphics | `getPrevPlotCoordmap` at `:533-573` | One panel only: `par('usr')` gives the domain, `grconvertX/Y(...,'user','ndc')` gives the pixel range, `par('xlog'/'ylog')` gives the log bases. `mapping` is empty because "We can't extract the original variable names from a base graphic". |
| ggplot | `getGgplotCoordmap` at `:579-613` → `find_panel_info_api` at `:630-765` + `find_panel_ranges` at `:983-1128` | `summarise_layout/coord/layers(b)` (`:633-635`) give one entry per PANEL: `panel`, `row`, `col`, `panel_vars` (facet values renamed `panelvar1/2`), `log` (from the scale transform or `coord$xlog`), `domain` (x/y min/max; reverse scales negated; discrete limits added by `add_discrete_limits` at `:1141`) and `mapping`. **`mapping` comes from the first layer only** (`:704`: `mapping <- layers$mapping[[1]]`), deparsed to strings. `coord_flip` swaps x and y (`:722`, `:743`). Pixel ranges are recomputed by **re-implementing gtable layout arithmetic**: null units, `coord_fixed` respect, and a quartz `res/72` workaround. Panels are matched to PANEL by sorting gtable cells named `^panel` by (t, l) (`:1113-1115`). |
| Send | `:310-320` | `img = list(src = data URI, width, height, alt, coordmap, error)`. If extraction failed, `error` is set and the JS logs it. |

### 1.2 Client: coordmap → mouse events → input payload

| Step | Where | What happens |
|---|---|---|
| The coordmap is kept out of the DOM | `srcts/src/bindings/output/image.ts:101`, `:111-113` | `opts.coordmap = data.coordmap`. Every other key is copied to `<img>` attributes; **`coordmap` is deliberately skipped**. It lives only in JS closures. Craft's DOM summary and REA's DOM capture both confirm there is no coordmap attribute. |
| Initialisation | `image.ts:162-164` → `initCoordmap.ts:148-182` | Runs on `img` load. With zero panels it creates a dummy panel where domain = range = image pixels (`:158-171`). Each panel gets `scaleImgToData`/`scaleDataToImg` (`initPanelScales.ts:34-54`, `:90-139`): linear interpolation, with `Math.log`/`Math.pow` when `log` is set. |
| Three coordinate spaces | `initCoordmap.ts:137-147` | CSS pixels (mouse), image pixels (PNG, = CSS × devicePixelRatio, plus any CSS transforms) and data space (per panel). |
| Listeners | `image.ts:174-252` | All are registered on the **container div** via jQuery under the `.image_output` namespace: `mousedown`, the custom `mousedown2`/`dblclick2`, `mousemove`, `mouseout`, `resize`, `shiny-internal:brushed`. The `img` itself only gets `reset` and `dragstart`, the latter to disable native drag. `createClickInfo.ts:57-91` turns `mousedown` into `mousedown2` (click) or `dblclick2`. When a dblclick id exists, a single click is delayed `dblclickDelay` ms so that a double-click does not also fire a click. |
| Hit-test the panel | `initCoordmap.ts:276-335` | `getPanelCss` checks which panel's `range` box contains the point. |
| Build the click/hover payload | `initCoordmap.ts:347-407` | Outside every panel: with `clip = TRUE`, **nothing is sent** (`:360-366`). Inside a panel: `{x, y}` from `panel.scaleImgToData`, plus `coords_css`, `coords_img`, `img_css_ratio`, the panel's `panel_vars` spread in, `mapping`, `domain`, `range` and `log` (`:383-405`). |
| Build the brush payload | `createHandlers.ts:180-222`, `createBrush.ts:301-314`, `:469-472` | The brush is bound to the panel under the mousedown (`startBrushing`), and its bounds are clipped to that panel (`panel.clipImg`). The payload is `{xmin, xmax, ymin, ymax}` in data space, plus `coords_css`/`coords_img`, `mapping`, `domain`, `range`, `log`, `direction`, `brushId` and `outputId`. |

### 1.3 Server: payload → rows

`R/image-interact.R`:

- **`nearPoints(df, coordinfo, threshold = 5, ...)`** (`:223-324`):
  - `xvar`/`yvar` fall back to `coordinfo$mapping$x/y` (`:254-257`) and must name columns of `df` (`:264-267`), otherwise it errors.
  - Each row is converted to a number with `asNumber()`: a discrete column becomes `match()` against `discrete_limits`, and factor/character becomes integer codes (`:412-417`).
  - Each row is projected to **image pixels** with `scaleCoords` and the payload's domain/range/log, then the Euclidean distance in **CSS pixels** to `coords_img`/`img_css_ratio` is computed (`:278-287`).
  - Rows within `threshold` are kept, filtered by `panelMatch(panelvarN)` (`:295-298`), and sorted by distance.
- **`brushedPoints()`** (`:74-140`): interval test in data space (`within_brush`, `:394-404`), plus the panel-variable filter.

So **row identity is reconstructed by spatial query at question time**, against whatever data frame the app author passes in. Nothing ties a pixel to a row.

### 1.4 Observed on the wire

App: `shiny/app/app.R`, a `facet_wrap(~cyl)` ggplot with `geom_point(colour=gear)` and `geom_smooth`, plus a base `par(mfrow=c(1,2))` plot and a patchwork plot.

- **Output frame, image + coordmap** (REA, frame 19, 181 KB, mostly the base64 PNGs). Extracted to `captures/rea/coordmaps_from_websocket.json`:
  - facet: 3 panels; `panel_vars {panelvar1: 4|6|8}`; mapping `{colour: "factor(gear)", x: "wt", y: "mpg", panelvar1: "cyl"}`; `dims` 1440×720 because devicePixelRatio = 2.
  - base: **one** panel whose `range.left` is 718 of 1200 image pixels, i.e. only the right-hand subplot.
  - patchwork: domain `-0.04..1.04`, range = the whole image, `mapping {}`.
- **Click payload** (REA, `captures/rea/ws_frame_48.json`):

  ```json
  {"facet_click":{"x":4.2706,"y":21.679,"coords_css":{"x":360,"y":179.2},"coords_img":{"x":720,"y":358.4},
   "img_css_ratio":{"x":2,"y":2},"panelvar1":6,"mapping":{...},"domain":{...},"range":{"left":468.8,...},"log":{...}}}
  ```

  This matches the hand inverse: `1.31745 + (720-468.77)/(834.76-468.77)*4.3021 = 4.2706`.
- **Other clicks:**
  - Double-click produced only `facet_dblclick`, no extra click (frame 63).
  - Clicking the centre of the base `mfrow` image sent **no frame at all**: the click landed in the left subplot, which is not in the coordmap.
  - Clicking patchwork sent `x=0.5, y=0.4997` with `mapping {}` (frame 56).
- **Brush payload** (Playwright fallback driver, `captures/ws_brush_payload_panel1.json`): `xmin 2.17, xmax 4.99, ymin 14.9, ymax 29.5, panelvar1 4, direction "xy"`. `brushedPoints()` returned Datsun 710, Merc 240D, Merc 230, Toyota Corona and Volvo 142E, which matches the prediction from the coordmap.
  - A drag from panel 1 into panel 2 (`captures/ws_brush_payload_cross.json`) was **clamped at panel 1's right edge** (`coords_css.xmax = 227`, `panelvar1 = 4`). Cross-facet brushing is impossible.
- **Listeners** (Craft `web-listeners-list` and REA `inspect-web-event-listeners`, consistent):
  - `#facet` (container): `mousedown, mousedown2, dblclick2, mousemove, mouseout, selectstart, shiny-internal:brushed, resize`.
  - `#facet img`: `reset, dragstart`.
  - `#base` (click only): `mousedown, selectstart, mousedown2`.
  - Every one resolves to jQuery's dispatcher (`jquery.min.js:1:37925`), not to Shiny's handler. See the tool log.

---

## 2. Coverage per engine

Coordmaps for 23 variants come from running Shiny's real `drawPlot()` on a `MockShinySession` (`coordmap_engines.R` → `coordmaps/*.json`). Point recovery comes from clicking the *actual drawn grob position* of every point, then asking `nearPoints()` for the row (`coverage_check.R` → `coverage_check.out`). Targeted failure cases are in `nearpoints_failures.R` → `.out`.

| Case | Coordmap | Clicked points recovered | Notes |
|---|---|---|---|
| ggplot plain / `facet_wrap` / `facet_grid` / free scales | correct, per panel, facet values | 32/32 each | `panelvar1/2`; free scales give per-panel domains. |
| `coord_flip`, `scale_y_log10`, `coord_trans(y="log10")`, `scale_x_reverse`, `coord_fixed`, `coord_cartesian(xlim)` | correct | 32/32 (flip, log, reverse, fixed) | Log goes through `log` bases; reverse through negated domain. |
| Discrete x (`aes(factor(cyl), mpg)`) | `discrete_limits` set | 27/32 with `xvar="cyl"` | The 5 misses are exactly the 5 overplotted (cyl, mpg) tie groups. Auto-inference **errors**: ``xvar ('factor(cyl)') not in names``. |
| `geom_jitter` | domain fine | **1/32** | Hit-tests raw columns, not jittered positions. Upstream rstudio/shiny#2411 (open). Stacking: #1703 (open). |
| `coord_polar` | linear domain/range emitted | **0/32** | A click on Cadillac Fleetwood maps to (3.47, 22.2); the truth is (5.25, 10.4). |
| Second layer with a different mapping | mapping = first layer only | **0/32** | Layer-2 points are invisible to `nearPoints()`. |
| Expression mapping `aes(wt*1000, ...)` | mapping `"wt * 1000"` | error | ``xvar ('wt * 1000') not in names``. Also `.data$x`: #2938 (open). Renamed facet vars: #2300. |
| Stat layers (`geom_bar`, `geom_smooth`) | `y = NULL` for bar | n/a | `nearPoints` errors (no `yvar`). A smooth line has no row. Clicking it returns whatever raw points lie within 5 px (2 in the test). |
| Legend / strips / axes | not in any panel | n/a | `clip = TRUE` means the click is dropped. Guides do not exist for Shiny. |
| patchwork | **fallback to base** `par('usr')` of the blank `plot.new()`: domain −0.04..1.04, range = whole image, `mapping {}` | n/a | `print.patchwork` wins S3 dispatch (comment at `render-plot.R:262-267`, issue #841), so no `ggplot_build_gtable` is returned. |
| lattice `xyplot(... \| cyl)` | same degenerate fallback | n/a | rstudio/shiny#2422 "Coordmap domain and range info is wrong for any non-ggplot2 grid graphics" (open since 2019). |
| grid-only, ComplexHeatmap (`draw()` or object) | same degenerate fallback | n/a | This is what ICH exploits; see §4. |
| base single panel, base log | correct | — | Base `mapping` is empty, so `xvar`/`yvar` must be passed. |
| base `par(mfrow=c(1,2))` | **last panel only** | — | A click in the left panel sends nothing (observed in the browser). |

### What the coordmap fundamentally does not know

- Which **layer, grob or geom** produced a pixel. It only knows the first layer's x/y names.
- **Legend vs data**: guides lie outside panels, and clicks on them are discarded.
- **Overlap**: several layers or overplotted rows at one pixel. `nearPoints` returns every row within the threshold, ordered by distance, with no layer and no z-order.
- **Positions after stat or position adjustment**: jitter, stack, dodge, smooth, bins, boxplot whiskers.
- **Non-linear coords**: polar, `coord_sf`, `coord_radial`. Only linear plus log is invertible in the JS.
- **Which data frame**: the app author must pass the right `df` and, if needed, `xvar`/`yvar`. The binding is a convention, not a record.
- **Composite layouts** (patchwork, multi-panel base, lattice) and any engine that does not go through `custom_print.ggplot`.

---

## 3. Concrete failure and limit cases

| # | Case | Evidence |
|---|---|---|
| 1 | Jitter or stacked positions: wrong or no rows | `coverage_check.out` (1/32); `nearpoints_failures.out` (the drawn x = 1.342 is jittered, the data x = 1). rstudio/shiny#2411, #1703 (both open). |
| 2 | Layers after the first are invisible | `coverage_check.out` (0/32); `render-plot.R:704`. |
| 3 | `coord_polar` mapped linearly | `coordmaps/gg_coord_polar.json`; `nearpoints_failures.out`. |
| 4 | Expression mappings break auto-inference (`factor(cyl)`, `wt*1000`, `.data$x`, renamed facet vars) | `nearpoints_failures.out`; #2938, #2300. |
| 5 | patchwork, lattice, grid, ComplexHeatmap get a degenerate whole-image coordmap with domain ≈ NPC | `coordmaps/patchwork_2.json`, `lattice_xyplot.json`, `complexheatmap.json`; websocket frame 56 (patchwork click `x=0.5`); #2422. |
| 6 | Base `mfrow`: only the last panel exists | `coordmaps/base_mfrow.json`; REA run (no `base_click` frame after the centre click). |
| 7 | A brush cannot span facets; it is clamped to the start panel | `captures/ws_brush_payload_cross.json`; `createBrush.ts:313-314`, `:472`. |
| 8 | Legend, strip and axis clicks are dropped | `initCoordmap.ts:360-366`; `nearpoints_failures.out` (legend click → NULL). |
| 9 | Exact ties are ambiguous | 5 misses in discrete-x = 5 tie groups. |
| 10 | Needs a live R session | Every query (`nearPoints`) and every re-render runs in R. The PNG is re-rendered when the size changes. |
| 11 | The coordmap is fragile to layout re-implementation | `find_panel_ranges` re-derives gtable sizes, with quartz `res/72` and `coord_fixed` special cases (`render-plot.R:1003-1094`, quartz fix at `:1010`). Upstream history (NEWS) shows repeated fixes: #1121 `coord_fixed`, #1433 discrete limits, ggplot2 2.2.1 and 4.0 API changes. |

---

## 4. InteractiveComplexHeatmap

### 4.1 Mechanism

1. **Record positions at draw time.** `htPositionsOnDevice()` (`R/interactive.R:560-720`) runs right after `draw(ht_list)` inside the same `renderPlot` (`R/shiny-server.R:272-286`, re-run on resize at `:444-448`).
   - It `seekViewport()`s every named body viewport `"<ht_name>_heatmap_body_<i>_<j>"`, one per row slice × column slice. It reads device coordinates with `deviceLoc(unit(0/1,"npc"))` and stores a `DataFrame(heatmap, slice, row_slice, column_slice, x_min, x_max, y_min, y_max)`.
   - With `include_annotation = TRUE` it also records the x or y span of **stand-alone** annotations in a heatmap list.
   - The table is cached in `.ENV` together with a digest of `ht_list` and `dev.size()` (`:706-714`).
2. **Use only pixel coordinates from Shiny.** ICH's `plotOutput` gets Shiny's degenerate fallback coordmap (observed: `mapping {}`, domain −0.04..1.04; click `x=0.5000`).
   - `get_pos_from_click`/`get_pos_from_brush` (`shiny-server.R:953-1004`) ignore `x/y/xmin...` and use `coords_css`. They flip y with `height = (range$bottom - range$top)/img_css_ratio$y`, which is the whole image because of the fallback, and convert to `unit(..., "bigpts")`, divided by `res/72`.
   - For hover, ICH's own JS (`inst/template/ht-main.js:87-98`, using jquery-mousestop) sends `{x, y: h - y}` directly.
3. **Hit-test analytically.** `selectPosition()` (`interactive.R:355-531`) and `selectArea()` (`:40-323`) loop over slices:

   ```
   column_index = column_order_list[[j]][ ceiling((x - x_min)/(x_max - x_min) * nc) ]
   row_index    = row_order_list[[i]][ 1 + nr - ceiling((y - y_min)/(y_max - y_min) * nr) ]
   ```

   This returns heatmap, slice, row/column index and row/column label. A brush returns `IntegerList`s per overlapped slice.
4. **Annotation semantics by index join.** `default_click_action` (`shiny-server.R:1701-1804`) looks up the matrix value and its colour, then calls `get_anno_value()` (`:1806-1844`) on top, bottom, left and right annotations with the found index. Only `anno_points`, `anno_simple`, `anno_lines` and `anno_barplot` are supported.

### 4.2 Verified behaviour

The script `ich_outside_shiny.R` → `.out` runs on a plain `png()` device with no Shiny. The heatmap is 2000×40, with `row_km = 2`, `column_km = 3`, a top annotation and a right row annotation.

- The position table has **6 rows, 4.5 KB, for 80,000 cells**.
- A computed click at slice 1_1, 5th row, 2nd column returned `row_index 660 (g660), column_index 19 (s19)`, the expected values.
- A click on the top annotation track returns `NULL`, and so does a click on the column dendrogram.
- `selectArea` across 3 column slices returned per-slice index lists (773 rows × 9/15/16 columns). The attached right annotation is not part of the position table.
- **Live** (REA, `captures/rea/rea_ich_click_frames.json`): a centre click → `expr_heatmap_body_1_2`, row 24 `g24`, column 2 `s2`, value 0.028, plus `score: 0.442` from `anno_points` via index join.

### 4.3 Semantics ICH has that Shiny's coordmap lacks

- **Named sub-regions with structural identity**: heatmap name, row and column slice (k-means or split groups).
- **An exact element index** (row/column in the original matrix) and labels. No tolerance or threshold is involved: a cell is an area, not a nearest point.
- **A mapping that respects reordering**: `row_order_list`/`column_order_list` encode clustering and splitting.
- Annotation values tied to the selected cells (partial: 4 annotation types).
- Sub-heatmap drill-down, and search by label (`selectByLabels`, `interactive.R:748`).

What ICH still lacks:

- Dendrogram nodes and branches: not hit-testable.
- Annotation tracks as click targets: clicks on them return NULL. Brushing or clicking a stand-alone annotation only flags overlap.
- `anno_text`, `anno_mark`, `anno_boxplot`, `anno_density` and custom annotations: not covered.
- Legends: not covered.
- Sub-pixel rows: with 2000 rows in 600 px, each row is about 0.25 px. Clicks resolve to a row but cannot be aimed.
- Still R-side: needs `ht_list` and R to answer queries.

### 4.4 Reusable outside Shiny?

Yes, as an R primitive. `selectPosition`/`selectArea` take `grid::unit` positions and a cached `ht_pos`, and run on any device (verified on `png()`).

For a static HTML/SVG export, the index is trivially portable. Export the slice bboxes plus `row_order_list`/`column_order_list` plus the labels as JSON, and port the two `ceiling()` lines to JS. Nothing about it depends on Shiny's coordmap.

The general idea is **"named viewport bbox recorded at draw time + analytic sub-index"**. It extends to any grid-drawn structure with regular sub-structure: tiles, rasters, facets, and patchwork cells.

---

## 5. Semantic levels reached

| Level | Shiny `plotOutput` + `nearPoints` | ICH |
|---|---|---|
| L0 geometry | Raster only (PNG). No vector geometry is shipped. | Raster only. |
| L1 structure | **Panel-level only, ggplot only**: panel index, row/col, facet values, axis transform. No layer, grob or guide. Legend = "outside". Wrong or empty for patchwork, lattice, grid, ComplexHeatmap, base `mfrow`. | **Heatmap-level**: heatmap name, body slice (row slice × column slice). Stand-alone annotations: span only. Dendrograms, legends, attached annotations: absent. |
| L2 data binding | **Not a binding.** A query-time nearest-neighbour or interval search over a user-supplied `df` using the first layer's raw x/y columns. Correct only for un-adjusted, linearly or log mapped point layers. Ambiguous on ties. | **Exact for matrix cells** (row/col index, labels, value). Partial for annotations (index join, 4 types). |
| L3 domain meaning | None. | None beyond labels and annotation names. |
| L4 interaction intent | None in the artifact. The app author writes it in R server code per app. | Fixed built-in design: click/hover → cell info; brush → sub-heatmap; search. Not per figure. |

---

## 6. What ggai should borrow, and what it means for the design

### 6.1 Borrow: a panel coordmap in the skeleton, but recorded from viewports at draw time

Shiny's coordmap is the right *shape* for L1-panel information. It is tiny (O(panels)) and gives the client enough to turn a pixel into data coordinates.

Shiny's way of *computing* it is the weak point. It re-derives gtable layout arithmetic, special-cases one engine, and hands everything else a bogus fallback.

ICH shows the robust alternative. After drawing, walk the real viewport tree and call `deviceLoc()` on each panel viewport. For ggai's grid path (`grid.force()` is already planned), record for each panel viewport:

- its device bbox;
- the scale info from `ggplot_build()$layout` (domain, transform, discrete limits, flip);
- the facet values;
- the panel's position in a composite (the patchwork cell).

This works for patchwork (nested gtables), ComplexHeatmap (named viewports), lattice (`trellis.vpname`), and base graphics via `gridGraphics::grid.echo()`. It costs nothing in SVG size.

Store the transform as **coord-aware** rather than "linear + log". Better still, see §6.2 and avoid needing the inverse at all.

### 6.2 Borrow, inverted: raster plus a hit-test index for dense layers, in pixel space against built data

Shiny shows that a raster plus a small side-table is enough for click, hover and brush at any N. Its *query design* is what fails: it inverts pixels to data space, then matches raw columns of the first layer.

ggai can do the opposite, because it has `ggplot_build()` and the drawn grobs. For each dense layer, emit:

- the layer as a raster (`<image>` inside the SVG, so non-dense guides, text and axes stay vector, with ids);
- a compact index of `(layer, PANEL, built_row, px, py)`, or bboxes for area marks, taken from the **drawn grob coordinates**.

Hit-testing then happens in pixel space. That makes jitter, dodge, stack, polar, non-linear coords, multiple layers and patchwork correct by construction. The *built row → raw row* map (group keys, as the idea doc already says) provides L2.

For regular structures (heatmap cells, `geom_tile`/`geom_raster`, facets), use **analytic indexes** the way ICH does: bbox + order vectors, O(slices) rather than O(cells).

For irregular area marks (bars, polygons, violins), the planned **ID-colour pick render** is the general form of this: an ID-encoded raster gives O(1) exact-shape hit tests.

### 6.3 Scale numbers

From `scale_measure.out`, ggplot `geom_point`, 7×5 in:

| Points | Plain svglite SVG (no ids, no `data-*`) | PNG at 144 dpi | (f32 px, f32 py, u32 row) index, raw |
|---:|---:|---:|---:|
| 10^4 | 1.0 MB | 331 KB | 117 KB |
| 10^5 | 10.2 MB | 478 KB | 1.17 MB |

Semantic attributes would multiply the SVG figure; that multiplier is unmeasured.

Implications:

- **Above roughly 10^4 marks per layer, switch that layer to raster + index.** Everything the agent annotates (L3/L4) attaches to the layer, the panel and the data table, not to 10^5 DOM nodes. That still meets "the agent annotates; it never redraws".
- The agent never needs to see per-point data: the compressed skeleton is counts plus coordmaps.
- Shiny's per-query work (`nearPoints` is O(N) in R) moves into the browser. A uniform grid or k-d tree over 10^5 points is cheap in JS.
- This removes the need for a live R server, which is Shiny's biggest deployment constraint.

### 6.4 Do not borrow

- Inferring the data↔pixel link from `mapping` strings. That is the root of failures 1–4 in §3.
- Treating guides as "outside": ggai's L1 must give legend keys their own ids, which is exactly the spike's problem.
- Clamping a brush to one panel. A linked brush across facets or patchwork cells is a natural L4 interaction for an agent to propose.

### 6.5 Design consequences for the idea doc

- Add the **panel coordmap** (viewport bbox + scale/coord + facet values + composite cell) as a first-class part of `skeleton.json`.
- It also gives the agent compressed context ("3 panels, cyl = 4/6/8, x = wt") without SVG text.
- Add a **dense-layer mode**: raster plus pixel-space index bound to built rows, with a threshold on marks per layer. That turns "Scale: out of scope for v0" into a defined fallback.
- Add **analytic indexes** for grid-like engines (ComplexHeatmap first). ICH proves the approach and its arithmetic, and its gaps (dendrograms, annotation tracks, legends) are exactly where ggai's agent-assigned L1/L3 adds value.

---

## 7. Tool log

**Session model.** The Craft CLI browser does not persist between invocations. `web-site-open` worked (`01_site_open.json`), but the next `web-pages-list` failed with `no browser is available: no endpoint was given`. In the CLI, each invocation is its own session.

Craft also defaults to clean-room mode. Page tools need `--deep`, and scripted runs need `--allow-run`.

Workaround: I started my own headless Chrome (`--remote-debugging-port=9444`, temp profile under `shiny/`), pointed Craft at it with `--cdp-endpoint`, and used REA's own launch mode for its scenarios. Port 9333 belonged to another process and was not touched.

### REA 6.8.0

| Command | Output | Value vs source reading |
|---|---|---|
| `capture-browser-scenario` (launch, devicePixelRatio 2, clicks on 3 images + dblclick, events = websockets) → `captures/rea/rea_click_scenario.json`, `rea_ws_frames.json` | **Full websocket payload text**, per step. This includes the 181 KB output frame carrying all three coordmaps, the click, dblclick and hover payloads, and the *absence* of a `base_click` frame. Also the final DOM and a screenshot. | **High.** This gave evidence source reading cannot: the real coordmaps for base `mfrow` and patchwork in a running app, the devicePixelRatio=2 split between `coords_css` and `coords_img`, dblclick suppression, and a silently dropped click. Limitation: **no drag or mouse-move action** (actions are goto, click at element centre, fill, press, select_option, check, wait_for, request, wait_for_timeout), so it cannot brush. Clicks can only hit element centres; I designed the app so the centre fell in a panel. |
| `capture-browser-scenario` on the ICH app → `rea_ich_scenario.json`, `rea_ich_click_frames.json` | ICH receives the degenerate coordmap and click `x = 0.5`. The server resolved slice/row/column from `coords_css`. | Medium–high. Confirms on the wire what the ICH source implies. |
| `inspect-web-event-listeners <ep> <target> "#facet"` → `rea_listeners_facet.json` | Same listener set as Craft. Every location is `jquery.min.js:1:37925`. | Low–medium. Confirms container-level registration and the custom events. Cannot see past jQuery's dispatcher to Shiny's handler. |
| `analyze-web-bundle --fetch-source-maps` → `rea_web_bundle.json` (10 MB) | Recovered 148 original `srcts/src/*.ts` module paths, including all 10 `imageutils/*.ts` and `bindings/output/image.ts`. | Medium. Mapped the deployed bundle to the source tree and enabled the deployed-vs-clone diff, done with the fetched `shiny.min.js.map`. That diff showed only cosmetic differences, which justifies citing the clone. |

### Craft Anything 0.5.0

| Command | Output | Value vs source reading |
|---|---|---|
| `web-site-open` → `01_site_open.json` | Page opened. The browser is gone after the process exits. | Showed the session model (above). |
| `web-page-show --with-websocket-outlines` → `03_page_show.json` | DOM summary as attribute *names* only (all the `data-click-id`, `data-brush-*`, ...), no `coordmap` attribute. Scripts and source-map URLs. No frames, because the socket predated the window. | Medium. Fast confirmation that the coordmap is not in the DOM, matching `image.ts:111-113`. |
| `web-listeners-list` on `#facet`, `#facet img`, `#base` → `04–06_*.json` | Container: 8 event types. `img`: `reset`, `dragstart`. Click-only `#base`: 3 types. | Medium. Clean evidence that listeners sit on the container, and that the set varies with the options. Same jQuery-dispatcher limitation as REA. |
| `web-page-watch --with-websocket-outlines` (25 s, run concurrently with the brush driver) → `07_page_watch_during_brush.json` | 74 frames, **outlines only** (`direction`, `opcode`, `payload_length`). Count and sizes match the raw log exactly (brush update = 684 bytes). | Low for content. Useful only to corroborate timing and sizes. |
| `web-walkthrough-record` (launch; `kind`: goto/wait/click; `capture.events: websockets`) → `08_walkthrough_click.json` | **Keeps websocket frame text** (unlike the passive watch): the full `facet_click` payload at devicePixelRatio 1. | Medium–high, equivalent to REA for clicks. The schema had to be discovered by trial (`kind`, and `wait` needs `ms`; there is no wait-for-selector). No drag either. |
| `web-page-js-analyze --load-source-maps` → `09_js_analyze.json` | Fetched both source maps, found the `ws://{location.host}` endpoint, and an event graph with minified names. It showed `mousemove.image_brush`/`mouseup.image_brush` bound on `$(document)` during a drag. It did **not** list the original TS modules. | Low–medium. One detail not obvious from listener lists (document-level drag handlers). Otherwise less informative than REA's bundle analysis or plain source. |

### Fallback I wrote

`shiny/drive_brush.mjs` uses REA's bundled `playwright-core` over CDP 9444. It reloads the page, performs two drags, and logs raw websocket frames (`captures/playwright_brush_frames.json`, `ws_brush_payload_*.json`). It was needed because neither tool can drag. Craft's passive watch ran at the same time as independent corroboration.

### Verdict

- Source reading (plus R experiments on Shiny's own `drawPlot`) answered the mechanism questions fully and was the only route to file:line.
- The tools added three things source reading cannot give:
  - the actual wire payloads;
  - proof of silent drops (base `mfrow`) and of the degenerate coordmaps that patchwork and ICH really receive;
  - DOM and listener placement in the running app.
- REA's scenario capture was the single most valuable tool call.
- Neither tool can perform a drag, so brushing needed a hand-written driver.
- Listener tools stop at jQuery's dispatcher. Craft's passive mode strips payloads.

---

## 8. Unverified or not done

- `coord_sf`, `coord_radial`, `facet_wrap` with missing panels, and `position_dodge`/`position_stack` were not run. Stacking is covered by upstream #1703, not by my test.
- How the coordmap behaves under CSS transforms or zoom was read in source (`findScalingRatio`) but not exercised.
- `gridGraphics::grid.echo()` and `trellis.vpname` were not tested as viewport sources for a ggai coordmap. The claim that they generalise the ICH approach is a design inference.
- The SVG size multiplier after adding ids and `data-*` attributes was not measured. Only plain svglite was.
- ICH dendrogram and legend behaviour inside the live app was not exercised; it comes from the source plus the off-Shiny test.
- The shiny GitHub issue states (open/closed) are as of the `gh` query date.

---

## Artifact index (`/tmp/ggai_research/shiny/`)

- Scripts:
  - `coordmap_engines.R`: 23 engine variants through `shiny:::drawPlot` → `coordmaps/*.json`.
  - `nearpoints_failures.R` → `nearpoints_failures.out`.
  - `coverage_check.R` → `coverage_check.out`.
  - `ich_outside_shiny.R` → `ich_outside_shiny.out`.
  - `scale_measure.out` (SVG vs PNG size).
  - `drive_brush.mjs` (Playwright drag driver).
- Apps: `app/app.R` (facet + base `mfrow` + patchwork), `ich_app/app.R`.
- REA (`captures/rea/`):
  - `scenario_click.json`, `rea_click_scenario.json`, `rea_ws_frames.json`, `coordmaps_from_websocket.json`, `ws_frame_48.json` (click), `ws_frame_56.json` (patchwork click), `ws_frame_63.json` (dblclick);
  - `rea_final_dom.json`, `rea_final_screenshot.png`;
  - `rea_listeners_facet.json`, `rea_web_bundle.json`;
  - `scenario_ich.json`, `rea_ich_scenario.json`, `rea_ich_click_frames.json`, `rea_ich_screenshot.png`.
- Craft (`captures/craft/`): `01`–`09` as listed in §7, plus `walk.json`.
- Brush: `captures/playwright_brush_frames.json`, `captures/ws_brush_payload_panel1.json`, `captures/ws_brush_payload_cross.json`.
- Deployed Shiny source map: `captures/shiny-1.11.1.min.js.map`.
