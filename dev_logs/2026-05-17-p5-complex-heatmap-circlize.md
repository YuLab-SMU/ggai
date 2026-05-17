# 2026-05-17 — P5: ComplexHeatmap + circlize engine adapters

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md) — Phase P5
- **Related ADRs:** [ADR-0002](../dev_docs/decisions/0002-code-first-engine-agnostic-artifact.md) (engine-agnostic artifact)
- **Related session:** [2026-05-17 — P4.b: Capability-aware skill modes](2026-05-17-p4b-capability-modes.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

Added first-class support for the two most common non-ggplot bioinformatics engines: **ComplexHeatmap** (annotated genomics heatmaps) and **circlize** (circular / genomic plots).

### Adapter changes (R/)

- **`R/execute.R`** — extended the engine→object switch:
  ```r
  complex_heatmap = last_value    # the Heatmap / HeatmapList object
  circlize        = recorded      # the recordedplot from circlize's base-graphics draws
  ```
- **`R/render.R`** — added `render_complex_heatmap()` (opens device, calls `ComplexHeatmap::draw(ht)`, closes). `circlize` reuses `render_base()` because circlize draws via base-graphics side effects.
- **`R/inspect.R`** — added `inspect_ch()` (per-heatmap slot occupancy: name, matrix shape, dendrogram flags, top/bottom/left/right annotation presence) and `inspect_circlize()` (overlay on `inspect_recorded` with circlize-flavored summary).
- **`R/validate.R`** — added `validate_ch()` (dry-runs `ComplexHeatmap::draw()` on a null device). `circlize` reuses `validate_recorded`.

All four dispatchers now branch on six engines: `ggplot / composite / grid / base / complex_heatmap / circlize`. The skeleton is set up to add `htmlwidget` later (P6) by following the same pattern.

### Skills (inst/skills/)

- **`ggai-complex-heatmap/SKILL.md`** — when-to-use, code conventions (`colorRamp2` for continuous, named vectors for discrete, `factor()` with explicit levels for splits, `use_raster = TRUE` for huge matrices), three reference snippets (basic annotated, HeatmapList stack, oncoPrint), anti-patterns, escalation triggers.
- **`ggai-circlize-genome/SKILL.md`** — explicit `engine_hint = "circlize"` requirement (the **engine note** section), `circos.clear()` discipline, species/assembly specificity, two snippets (chord, genome track), anti-patterns.
- **`ggai-engine-selection/SKILL.md`** — updated decision-table rows for complex_heatmap and circlize to explicitly hand off to the new skills.

### Detection nuance: circlize cannot be auto-detected

`circos.*` functions draw via base-graphics-style side effects and return NULL. Auto-detection sees `last_value = NULL`, `has_base = TRUE` (device captured the drawing), and returns `"base"`. To tag the artifact correctly as `circlize`, the agent **must** pass `engine_hint = "circlize"`. The skill calls this out prominently as an "Engine note" section.

ComplexHeatmap is the opposite: `Heatmap()` returns an S4 `Heatmap` object that auto-detects cleanly without any hint.

## Verification

### Unit tests

`tests/testthat/test-engine-adapters.R` now covers six engines (was four). New tests:
- ComplexHeatmap single Heatmap path — detect / render / inspect / validate.
- ComplexHeatmap HeatmapList path — confirms `n_heatmaps == 2` and per-heatmap names.
- circlize path — confirms `engine_hint = "circlize"` produces engine-tagged artifact + non-trivial recordedplot.

`tests/testthat/test-skills.R` extended `required` set to include `ggai-complex-heatmap` and `ggai-circlize-genome`. Full suite: **343 PASS / 0 FAIL / 1 SKIP**.

### L2 smoke (no LLM)

```r
# ComplexHeatmap
a <- ggai_execute_and_capture('
  suppressMessages(library(ComplexHeatmap))
  set.seed(1)
  m <- matrix(rnorm(50), 10, 5)
  rownames(m) <- paste0("gene", 1:10)
  colnames(m) <- paste0("sample", 1:5)
  Heatmap(m, name = "expr")
')
a$engine           # "complex_heatmap"
ggai_inspect_artifact(a)$summary  # "ComplexHeatmap: 1 heatmap(s); first = `expr` (10x5)"
ggai_validate_artifact(a)$status  # "ok"

# circlize
a2 <- ggai_execute_and_capture('
  suppressMessages(library(circlize))
  circos.clear()
  circos.initialize(letters[1:5], xlim = c(0, 10))
  circos.track(ylim = c(0, 1), panel.fun = function(x, y) NULL)
  circos.clear()
', engine_hint = "circlize")
a2$engine          # "circlize"
ggai_validate_artifact(a2)$status  # "ok"
```

### End-to-end LLM smoke

Both agent runs hit their target skill on the first try.

**ComplexHeatmap** (44.8 s, 4 tool calls):
```
load_skill[ggai-complex-heatmap]
ggai_execute_r[engine_hint=complex_heatmap]
ggai_validate_artifact
ggai_save_artifact[prefix=ch1]
```
The generated R is **defensively written**:
- Existence check for `sample_meta`, with a clean error if missing.
- Column-set diff against required `c("group", "batch")`.
- Three-tier sample alignment: by-name when colnames overlap, by-position fallback when nrow matches, otherwise hard stop.
- Robust Z-score colour limits derived from `quantile(abs(values), 0.98)` clipped at ±2.
- Annotation palette built from `colorRampPalette` over a 6-colour reference set so it stably extends to larger factor levels.
- `use_raster = nrow(expr_mat) > 2000` — matches the skill's "huge matrix" guidance even though this matrix is small.

The resulting figure: row dendrogram, top annotation tracks for `group` (control/treated) and `batch` (A/B), divergent blue-white-red colorbar centred at 0, clean legends — publication-quality.

**circlize** (43.1 s, 4 tool calls):
```
load_skill[ggai-circlize-genome]
ggai_execute_r[engine_hint=circlize]
ggai_validate_artifact
ggai_save_artifact[prefix=chord1]
```
Generated a `chordDiagram()` over 5 modules (A–E) with distinct sector colours and transparent chords — clean and readable.

## Findings / decisions

- **The agent honoured the skill's `engine_hint = "circlize"` requirement.** The circlize skill's "Engine note" was apparently enough to make the requirement stick. Encouraging: explicit prose in the skill body translates reliably into tool argument choice.
- **Defensive code generation matters.** The ComplexHeatmap run wrote 80 lines including three layers of input validation. This is the agent extending the skill's spirit (the snippets are tighter than what the agent produced) — a sign the skill is teaching enough principles that the agent generalises sensibly.
- **circlize as base-flavour was the right call.** Trying to invent a non-base render path for circlize would have added complexity for no value; the `recordedplot` machinery already works perfectly. The engine label distinguishes it for downstream skills without requiring a separate render function.
- **ComplexHeatmap polish is not yet supported.** `polish_figure()` only accepts ggplot/composite. The ComplexHeatmap skill notes a workaround (`ggplotify::as.ggplot(grid.grabExpr(draw(ht)))`) but it hasn't been integrated. Filed implicitly as part of "polish for non-ggplot engines" — not in TODO yet because no user has asked.

## Next

Two natural directions:

### P6 — Composite + htmlwidget adapters

The original P5/P6 split. After P5 the skeleton is well-shaped to add htmlwidget (needs `webshot2` to rasterize) and composite (needs recursive inspection over `patchwork::wrap_plots` outputs).

### Skill iteration (continuous)

P5's smoke surfaced that the ComplexHeatmap skill works on first try with realistic input. Worth running a couple more genomics-flavored goals (oncoPrint, sample correlation heatmap, expression+methylation HeatmapList) to confirm the snippet coverage. Park as ongoing maintenance — not a phase.

### Gallery seed (grown to 10 outputs)

The smoke directory now has 10 small but real outputs:
- 3 mtcars data plots (P4)
- 1 CRISPR illustration (P4)
- 1 Nature-style polish (P4)
- 3 P4.b variants (no-cue, image-model intent, code intent) — the "polished mode-decision evidence"
- 1 ComplexHeatmap (P5)
- 1 chord diagram (P5)

Enough material for a real `gallery/` showcase whenever attention time allows.
