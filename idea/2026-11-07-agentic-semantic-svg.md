# Agentic semantic SVG export

> → promoted to [plan/2026-11-07-semantic-svg-phase-1-skeleton.md](../plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md) (Phase 1: deterministic layer only).
> → 2026-11-08: that plan closed as superseded. The idea now continues as a standalone package, `semsvg`: design in [dev_docs/semsvg-package-design.qmd](../dev_docs/semsvg-package-design.qmd), decision in [ADR-0004](../dev_docs/decisions/0004-semantic-figure-substrate-as-standalone-package.md).
> Status: exploration, revised 2026-11-07 after the prior-art survey ([2026-11-07-semantic-svg-prior-art.md](2026-11-07-semantic-svg-prior-art.md)).
> Full standalone research report (Chinese, Quarto): [dev_docs/semantic-svg-research-report.qmd](../dev_docs/semantic-svg-research-report.qmd).
> Date: 2026-11-07. Owner: Yonghe Xia.

## Problem

R figures (ggplot2, base graphics, grid, ComplexHeatmap, circlize, patchwork) export to SVG with geometry only. Nothing records which element is a data point, which is a legend key, which data row a mark came from, or what an annotation means.

Existing tools cover parts of the problem. All of them stop at a fixed set of supported inputs. Evidence for each row is in the prior-art doc.

| Family | Examples | What breaks |
|---|---|---|
| Static export | `svglite` | No semantics: 134 drawn primitives, 0 ids. Legend keys look exactly like data marks. |
| Spec translation | `ggplotly`, canvasXpress | Redraws the figure in another engine. Measured drift is 6–32% of pixels, and some failures are silent: patchwork reduced to its last panel, all ggrepel labels dropped, a forest plot turned into a bar chart, smooths drawn as one zig-zag. |
| Raster + hit test | Shiny `nearPoints` | Panel-level only, and the row is guessed at query time. Recovered rows: jitter 1/32, `coord_polar` 0/32, second layer 0/32. Non-ggplot engines get no coordmap at all. |
| Device-level tagging | ggiraph, gridSVG, maidr | Exact geometry and exact grob ids. Data binding only for hand-supported geoms, and unknown layers get nothing. ggiraph also requires rewriting the plot code and choosing the interactions in advance. |
| SVG deconstruction (heuristic or LLM) | DIVI, VisAnatomy baselines, CSL, Athanor | Works on any SVG, but its output is never checked against real data. On R charts, element-role F1 is 0.692 for GPT-4o and 0.959 for DeepSeek-V3: unstable across models, and unverifiable. |

## Thesis (revised)

Prior art shows that mapping each SVG element to its grob is feasible with exact geometry: the ggiraph `dsvg` tracer and the maidr marker walk both do it. ggai treats them as methodological reference only. It designs its own capture mechanism and takes neither a dependency on those packages nor code from them. What no one does is the **open-world, verified** part.

At export time, `ggai` holds the canonical code (ADR-0002), the data, the built data, the grob and viewport tree, and an agent. So:

1. **Deterministic skeleton.** Built on per-grob element capture, not whole-SVG draw-order alignment. Covers S1 for every grob, and S2 wherever built data determines it.
2. **Agentic semantics, the actual contribution:**
   - proposed S2 bindings for layers nobody wrote a processor for;
   - S3 domain meaning;
   - **relations** between elements (legend key ↔ series, label ↔ point, bracket ↔ group pair, annotation track ↔ cluster);
   - a per-figure S4 interaction design, chosen from a closed vocabulary.
3. **Deterministic compile.** Geometry never passes through the LLM.
4. **Verification gate:**
   - per-grob element counts;
   - every claimed row binding checked against built data;
   - a pixel diff against a reference rendered in the same session.

   Agent claims are tagged Direct, Derived or Speculative; only Direct claims are checked against data.

Design rule unchanged: **the agent annotates; it never redraws.** The translation experiments are the strongest evidence for this rule.

## Semantic levels

Renamed from L0–L4 to avoid clashing with Lundgard & Satyanarayan's L1–L4.

| Level | Content | Producer |
|---|---|---|
| S0 | Geometry | Graphics device |
| S1 | Element ↔ grob path, viewport path, layer, panel, guide | Deterministic (tracer or marker walk) |
| S2 | Element ↔ built row ↔ raw row (raw rows through group keys, crosstalk-style nested keys for stat layers) | Deterministic for ggplot layers whose built data determines it; agent-proposed and verified otherwise |
| S3 | Domain meaning and relations | Agent |
| S4 | Interaction intent, from a closed vocabulary (DIVI taxonomy: target × type × input) | Agent |

## Pipeline

```
artifact (code + data)
   |  1. skeleton  [deterministic]
   v
skeleton.svg   stable id on every primitive
skeleton.json  id -> grob path, viewport path, layer, PANEL, group, built row,
               aes values; per-grob expected/emitted counts;
               panel + block boxes (recorded from the viewport tree after drawing)
   |  2. semantics [agent]
   |     input: code + ggai_inspect_artifact() + COMPRESSED skeleton
   |            (groups, counts, bbox; never the full SVG)
   v
semantics.json  roles (VisAnatomy-compatible), relations, S4 interactions,
                a11y text, claim provenance
   |  3. compile   [deterministic]
   v
figure.svg / figure.html
   - data-* attributes; WAI-ARIA Graphics roles; <title>/<desc>
   - embedded data JSON (column allow-list)
   - small runtime: one delegated listener on the root
   - optional targets: MAIDR JSON, crosstalk keys
   |  4. verify    [deterministic]
   v
report  dangling ids = 0; per-grob counts match (fail closed);
        Direct claims verified against built rows; pixel diff vs same-session PNG
```

### Stage 1 details (changed by the survey)

- **Capture.** Element capture is done per grob, by a mechanism ggai designs itself. Phase 1 Task 2 compares three ggai-native candidates: per-leaf isolated rendering, a whole-scene render segmented by expected per-grob counts, and a colour-coded pick render. Within each grob, the expected and emitted element counts must match; on a mismatch, **fail closed** (record S1 only, never recycle ids).
- **Stable ids.** Grob names carry session counters (`geom_point.points.190`), so ids are derived from structure instead: `p<panel>/l<layer>/<leaf role>/<i>`, or `…/r<built row>` when bound.
- **Viewport path.** Record it for every element; ComplexHeatmap's semantics live there.
- **Coordinate maps.** Record panel and block boxes from the viewport tree **after drawing** (InteractiveComplexHeatmap's approach), not by re-deriving gtable layout (Shiny's approach, which fails on non-ggplot engines).
- **Dense layers.** Above about 10^4 marks, use a raster layer plus a binary hit-test index keyed by (layer, panel, built row). Measured at 10^5 points: SVG 10.2 MB, PNG 478 KB, index 1.17 MB.
- **Grid-like layers** (heatmaps, tiles): store block boxes plus order vectors, not one node per cell.

## Showcase (revised)

A plain ComplexHeatmap is no longer a differentiator, because maidr covers heat cells, simple annotations and dendrograms. Show the cases where every closed-world tool fails or stays silent:
- complex annotation tracks and their relation to clusters;
- extension geoms (ggrepel, ggtree);
- forest plots (pointrange);
- stat layers bound back to raw rows;
- patchwork with cross-panel relations.

## Why it fits ggai

- Code is canonical (ADR-0002), so the skeleton can always be rebuilt and re-verified.
- It adds one primitive family and one skill. Under ADR-0003, the knowledge lives in the skill.
- It addresses two TODO items: "HTML / SVG assisted layout" and "semantic editing primitives". A semantic SVG becomes a vector-level editing format, an alternative to raster polish that keeps data fidelity.
- `agent = FALSE` still gives a deterministic S1–S2 export at zero token cost.

## Non-goals

- Replacing plotly or Shiny dashboards.
- The LLM generating geometry.
- The htmlwidget engine.
- Depending on, or copying from, ggiraph, gridSVG, maidr, plotly or canvasXpress. They are methodological reference (and benchmark baselines) only.

## Risks and open questions (revised)

- **Per-grob count mismatches.** Expected for NA grid lines and NaN ribbons, and possible for multi-line text and mixed `pch`. Fail closed and report. Unverified: mismatches caused by clipping.
- **Robustness of our own capture.** ggai owns this code, so the edge cases are ours to handle: clip paths, masks, patterns, symbol reuse (`<use>`), and grobs whose element count depends on the device. Task 2's bake-off measures these on the benchmark set.
- **Stat layers.** Bind to built rows first, then to raw rows through group keys. The agent explains whatever cannot be derived.
- **Fonts.** ggrepel placement shifts with font metrics, so the skeleton and the reference PNG must come from the same render session.
- **Embedding.** Scripts in an SVG don't run under `<img>`; ship inline SVG or HTML.
- **Data exposure.** Embedded data needs a column allow-list.
- **Cost.** The agent sees only the compressed skeleton. Cache `semantics.json` by code hash.
- **Evaluation.**
  - Our own benchmark (the seven figures used in the survey, plus base, jitter and dense data).
  - The R subset of VisAnatomy, with an "agent without skeleton" ablation against the published baselines (R charts: GPT-4o 0.692, DeepSeek-V3 0.959).
  - Baselines: maidr, ggiraph, plotly, canvasXpress.
  - Metrics: tagged share, verified-binding share, relation recall, pixel diff.

## Spike evidence (2026-11-07)

- **svglite alone.** 134 drawn primitives (plus 5 clip-path definition rects), 0 ids. 35 circles for 32 rows: the 3 extras are legend keys. Panel-1 circles match `ggplot_build()` rows in order (Spearman 1.0).
- **Tag everything with the ggiraph tracer** (a feasibility reference only; not the mechanism ggai will use). 133/134 primitives tagged, with byte-identical geometry. 6 of 62 leaves had a count mismatch, none of them data marks. Other engines: patchwork 139/140, base via gridGraphics 63/64, ComplexHeatmap 227/228. Details in the prior-art doc, §1.
