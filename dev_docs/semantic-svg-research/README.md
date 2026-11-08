# Semantic SVG research archive (2026-11-07)

Evidence behind [`../semantic-svg-research-report.qmd`](../semantic-svg-research-report.qmd) (the full report, in Chinese) and [`../../idea/2026-11-07-semantic-svg-prior-art.md`](../../idea/2026-11-07-semantic-svg-prior-art.md). Everything here was produced during a single investigation session and is kept **as run**. Nothing here is part of the package build: `dev_docs/` is in `.Rbuildignore`.

## Layout

| Path | What it is |
|---|---|
| `reports/` | The four thread reports. Each one is long, with file:line citations: `ggiraph-gridsvg.md`, `shiny-static-interaction.md`, `translation-canvasxpress-plotly.md`, `literature-ecosystem.md`. |
| `spike/` | The first svglite spike (`spike.R`, output `p.svg`): 134 drawn primitives plus 5 clip-path definition rects, 0 ids. |
| `capture-groups/` | Follow-up spike (2026-11-07): native capture with graphics-engine groups plus zero-output probes. `groups.R` shows the drawn sequence is identical to plain svglite; `groups_engines.R` covers ggplot, patchwork, base via gridGraphics, ComplexHeatmap, ggrepel and 10^4 points; `probe.R` records viewport paths and device boxes. |
| `ggiraph/scripts/` | Device-tagging experiments. `tag_all.R` / `e3_tag_all_spike.R` give 133/134 tagged; `e5_tag_all_engines.R` covers patchwork, base and ComplexHeatmap; `e4_*` are the failure cases; `e6_*` are the gridSVG runs. |
| `ggiraph/out/` | Logs (`e*_log.txt`, `e3_leaf_log.csv`), plus the tagged SVGs and gridSVG outputs. |
| `ggiraph/tooling/` | Craft Anything / REA outputs: event-listener captures, DOM summaries, the JS app map, and bundle-analysis summaries. |
| `shiny/` | Coordmap and `nearPoints` experiments (`coverage_check.R`, `nearpoints_failures.R`, `coordmap_engines.R`, `ich_outside_shiny.R`), plus their `.out` files, the two apps, and the Playwright brush driver. |
| `shiny/coordmaps/` | Coordmap JSON per engine and per case. |
| `shiny/captures/` | Websocket frames, click/brush payloads, and listener and page captures from REA and Craft. |
| `translate/scripts/` | The plotly / canvasXpress experiments (`run_experiments.R`, `run_variants.R`, `svg_baseline.R`), plus pixel comparison and CDP/MCP drivers. |
| `translate/shots/` | All 700×500 screenshots used for the pixel comparisons. |
| `translate/exp/` | Generated specs, SVGs and widget pages. The widget pages need their `lib/` folder, which is not archived. |
| `translate/pixel_diffs.{csv,json}` | The pixel-diff table. Craft and REA agree on every row. |

## Paths inside scripts

The scripts and reports refer to the original scratch locations. Map them as follows:

- `/tmp/ggai_research/<x>` → `dev_docs/semantic-svg-research/<x>`
- `/tmp/ggai_svg_spike/` → `dev_docs/semantic-svg-research/spike/`
- `/tmp/ggai_research/src/<pkg>` → a clone of the upstream repo at the commit listed below (not archived)
- `/tmp/ggai_research/tools/` → REA 6.8.0 (`npm install rea-agents@6.8.0`, needs Node ≥ 22.23.4) and the Craft Anything CLI 0.5.0 (GitHub release `v0.5.0`). Neither is archived.
- `/tmp/ggai_research/rlib` → a scratch R library holding canvasXpress, gridSVG and patchwork/ggrepel (not archived)

## Deliberately excluded

The excluded material falls into four groups:

- **Third-party code.**
  - ggiraph's `girafe.js` and the htmlwidgets JS (GPL/MIT).
  - The canvasXpress engine (`cxjs/`, `cxjs_restored/`). Its licence is source-available and forbids removing the attribution mark.
  - Shiny's source map, and website scripts exported by REA.
  - Full-page DOM snapshots that embedded those bundles (`rea_scenario_hover.out.json`, `craft_walk.out.json`, `08_walkthrough_click.json`, `09_js_analyze.json`).
  - 87 KB of jQuery source, stripped from `shiny/captures/rea/rea_listeners_facet.json`; the listener records themselves are intact.
- **Raw captures of canvasxpress.org.** Third-party site content.
- **Bulky duplicates.** REA evidence dumps over 7 MB, and base64 screenshot envelopes that duplicate the PNGs.
- **Machine state.** Chrome profiles, pid and log files, and local tool and R-library installs.

## Upstream sources read (shallow clones, default branch)

| Repo | Commit | Commit date |
|---|---|---|
| davidgohel/ggiraph | `8515a2b3d48d` | 2026-10-28 |
| pmur002/gridsvg | `bc02bf571cc5` | 2026-10-22 |
| xability/r-maidr | `9f5a014fa9b0` | 2026-11-05 |
| rstudio/shiny | `1f8521793266` | 2026-11-06 |
| jokergoo/InteractiveComplexHeatmap | `8b617e72415f` | 2026-01-30 |
| plotly/plotly.R | `4ff1c3335b19` | 2026-07-24 |
| neuhausi/canvasXpress | `3b0d3211bd37` | 2026-11-05 |

## Runtime environment

macOS arm64, Chrome. R packages: ggplot2 4.0.3.9000, svglite 2.2.2, ggiraph 0.9.2, plotly 4.12.0, shiny 1.11.1, htmlwidgets 1.6.4, ComplexHeatmap 2.26.0, gridGraphics 0.5.1, xml2 1.4.1. gridSVG 1.7-7 and canvasXpress were installed in the scratch library.
