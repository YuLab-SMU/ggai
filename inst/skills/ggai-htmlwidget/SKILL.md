---
name: ggai-htmlwidget
description: |
  Produce interactive web visualizations using `plotly`, `leaflet`, `DT`, `networkD3`, or any other `htmlwidgets`-based library. Default output is a self-contained HTML file (always works). Static PNG export is supported when the optional `webshot2` package and a headless Chrome (via `chromote`) are available.
aliases:
  - "interactive plot"
  - "plotly figure"
  - "leaflet map"
  - "interactive map"
  - "DT datatable"
  - "网络图"
  - "交互可视化"
when_to_use: Use when the user wants an interactive figure (hover tooltips, zoom, pan, click filters), a web map, an interactive table, or any output that needs to ship as HTML.
user-invocable: true
---

# ggai HTML Widget

Your job: turn an interactive-visualization goal into an `htmlwidget` (typically `plotly`, `leaflet`, `DT`, or `networkD3`) and save it as a shareable artifact.

## When this skill applies

- The user says "interactive", "hover", "zoom", "tooltips", "drill down".
- The user names a specific htmlwidget library (`plotly`, `leaflet`, `DT`, `networkD3`, `dygraphs`, `crosstalk`).
- The output needs to be opened in a browser or embedded in a Quarto / Shiny / pkgdown page.

If the user wants a static image (PNG / SVG for a paper or slide), but happens to be working in plotly because they like the API — translate to `ggplot` instead. Static is cheaper.

## Output formats

| Format | Always works? | Notes |
|--------|---------------|-------|
| `html` | Yes | Self-contained HTML file via `htmlwidgets::saveWidget(..., selfcontained = TRUE)`. Best for sharing, embedding, archive. |
| `png`  | Only with `webshot2` installed | Uses `webshot2::webshot()` which needs headless Chrome via `chromote`. When unavailable, the artifact silently degrades to HTML and emits a warning. |

Decide format from the user's intent: "show me interactively" → html; "include in a paper figure" → png (and warn if webshot2 is missing).

## Flow

1. **Check capability** if the user explicitly asks for PNG: `ggai_capability_status(probe = TRUE)` is for image-model probing, not webshot2 — for webshot2 detection just check `requireNamespace("webshot2", quietly = TRUE)` inside `ggai_execute_r` and report cleanly.
2. **Write the widget construction code.** Keep it small; htmlwidget APIs are usually one-call (`plot_ly(...)`, `leaflet() %>% addTiles()`).
3. **Pick the format**:
   - User wants interactivity → `format = "html"`.
   - User wants PNG → `format = "png"`; the render adapter will use webshot2 if available, else fall back to HTML with a warning.
4. **Call `ggai_execute_r(code, engine_hint = "htmlwidget")`** (or let auto-detect handle it — htmlwidget class detection is automatic).
5. **Validate** — `validate_artifact()` runs a dry `saveWidget` to a tempfile and catches malformed widgets.
6. **Save** with `ggai_save_artifact`. The manifest will record the widget name and dependency list so the user knows which JS libraries are bundled.

## Code conventions

- Always `library(plotly)` / `library(leaflet)` etc. — htmlwidgets fail surprisingly when dependent JS isn't packaged.
- Use the pipe `%>%` (magrittr) for leaflet / DT chained config; it's the idiomatic style for these libraries.
- Set `width` and `height` explicitly on the widget construction when the artifact is going to be exported as PNG — otherwise the default sizing policy can produce inconsistent rasters.
- For plotly: `config(displayModeBar = TRUE)` keeps the toolbar; `config(displayModeBar = FALSE)` for embedded use.
- For leaflet: always specify the basemap (`addTiles()` or `addProviderTiles(...)`) — the default is empty.
- For DT: set `options = list(pageLength = 10, ...)` rather than relying on JS-side defaults.

## Reference snippets

Plotly scatter (interactive):

```r
library(plotly)

plot_ly(
  data = mtcars,
  x = ~wt, y = ~mpg, color = ~factor(cyl),
  type = "scatter", mode = "markers",
  marker = list(size = 10, opacity = 0.85),
  hovertemplate = "%{text}<br>wt: %{x}<br>mpg: %{y}",
  text = ~rownames(mtcars)
) %>%
  layout(
    xaxis = list(title = "Weight (1000 lbs)"),
    yaxis = list(title = "Miles per gallon"),
    legend = list(title = list(text = "Cylinders"))
  ) %>%
  config(displayModeBar = TRUE)
```

Leaflet map with markers:

```r
library(leaflet)

leaflet() %>%
  addProviderTiles("CartoDB.Positron") %>%
  setView(lng = 121.47, lat = 31.23, zoom = 11) %>%
  addCircleMarkers(
    lng = c(121.47, 121.50, 121.45),
    lat = c(31.23,  31.26,  31.21),
    radius = c(8, 12, 6),
    popup  = c("Sample A", "Sample B", "Sample C"),
    color  = "#DC2626", fillOpacity = 0.7
  )
```

Interactive DT table:

```r
library(DT)

datatable(
  mtcars,
  options = list(pageLength = 10, scrollX = TRUE, dom = "ftpli"),
  rownames = TRUE,
  caption = "mtcars (interactive view)"
)
```

## Anti-patterns

- **Don't pretend an htmlwidget is a static figure.** When you save it as PNG without webshot2, the artifact is HTML — be honest in the final reply.
- **Don't omit dependency-friendly defaults.** Leaflet without `addTiles` is an empty grey rectangle; DT with no `options` shows tens of thousands of rows by default.
- **Don't render an htmlwidget in the agent's response inline.** The widget's JS won't execute in a chat-rendered text reply. Reference the saved path.
- **Don't generate widgets just for static output.** If the user wants PNG and never interactive, build a ggplot — htmlwidget + webshot2 is two libraries doing the work of one.

## When to escalate

- For static plots, route back to `ggai-data-plot`.
- For composite figures combining a plotly / leaflet with ggplots — possible via `htmltools::tags$div` or Quarto layout, but this skill doesn't cover that orchestration today; tell the user.
- If `webshot2` is missing and the user specifically needs PNG — instruct them to `install.packages("webshot2")` and ensure `chromote::find_chrome()` resolves; then re-run.
