# 2026-11-08 — semsvg: open decisions settled, plugin architecture, Phase 1 plan closed

- **Related plan:** [plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md](../plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md) (closed as superseded)
- **Related ADRs:** [ADR-0004](../dev_docs/decisions/0004-semantic-figure-substrate-as-standalone-package.md) (new, accepted)
- **Related docs:** dev_docs/semsvg-package-design.qmd
- **Previous log:** [2026-11-07-semantic-svg-prior-art.md](2026-11-07-semantic-svg-prior-art.md)
- **Worked on by:** Yonghe Xia, Claude

## What happened

The design doc ended the previous session with nine open decisions. The owner answered the ones that shape the design, and the rest were set to the recommended defaults. The doc is updated and renders with no unresolved cross-references (`quarto render dev_docs/semsvg-package-design.qmd --to html`).

**Owner decisions:**

1. **Row keys are inferred, never required, and can be changed later at will.**
   - Inference order: meaningful row names → columns the code uses as label / group / join key (from context sniffing) → unique non-missing columns → unique column combinations → row hash + duplicate index. Tables that fall back to the hash are flagged in the status report.
   - `sem_key()` changes the key at any time. Old and new keys point at the same rows, so every data-key selector is rewritten automatically. The rewrite is an append-only record and can be undone.
2. **Conflicts are judged in context, not by a fixed precedence.**
   - Evidence that can be weighed: check results, provenance and grounds of each record, time order, intent the user stated in the session or document, the figure's use.
   - A resolution is a record with rationale and evidence, written by the review stage or a person, and can be superseded.
   - The one hard constraint stays: a claim whose check fails is never projected as fact.
3. **The single file carries everything and restores freely.**
   - The SVG/HTML embeds the whole bundle plus a comprehensive context record. It converts losslessly to and from the directory form (`sem_write` / `sem_read`).
   - Context is sniffed, not typed in: code, data source, engine and extensions, environment, document and output target, git state. Each item comes from its own sniffer plugin; missing items are left empty with a reason.
   - Restoring also sniffs first and recovers what it can: full bundle, data stripped, plugin missing, or plain SVG with no bundle.
4. **Browser-side operations start simple and depend on context.**
   - v0 in the browser: select, highlight / fade, show / hide, tooltip, legend filtering, keyboard navigation. R side implements the full vocabulary.
   - Which operations a figure gets depends on the sniffed output target, the chart type and the existing semantic layers.
   - Web Annotation is a simple one-way exporter plugin.
5. **Plugin-based build.** The core holds only the substrate, anchors, records, verification and the registry. Eight extension points (engines, classify rules, layers, check primitives, operations, projections / exporters, context sniffers, agent stages) share one `sem_register()` interface and one contract-test helper. Built-in features register the same way.

**Recommended defaults adopted:** name `semsvg`; a separate repository (recorded as ADR-0004); v0 engines ggplot + patchwork + ComplexHeatmap first, with base and general grid in the second half of M1; the default disclosure to the model is `summary`, and data embedded in the single file is controlled separately by `embed`.

**Safety point added while writing it up.** With a full context record in the file, `sem_rebase(fig)` can re-run the original code. Code restored from a file someone else sent is never run automatically: it is listed first and needs `trust = TRUE`.

**Doc changes:** summary, design principles 7–9, the data interface (row keys), conflicts, projections, operations (browser v0 + choosing operations from context), update (`sem_rebase` without a new plot), agent stages and tools (`get_context`; the review stage resolves conflicts), storage (two equivalent bundle forms, context table, restore cases, `embed`), a new plugin chapter, package layout (core / capabilities / built-in plugins), tests (storage and plugin rows), milestones, and the decisions chapter, now a table of settled items.

**Plan closed.** The Phase 1 plan described `ggai_svg_*` primitives inside ggai. With the standalone-package decision and the substrate redesign it no longer applies. All tasks are marked `[-]` with a Scope Change note that maps each one to a semsvg milestone, and the file moved to `plan/done/`.

**ADR-0004.** The Phase 1 plan had reserved this number for the capture mechanism. It now records the package decision; the capture decision (group delimiting plus probes) will be recorded in the semsvg repo. The 2026-11-07 log still says "ADR-0004 (capture backend) is pending"; that is left as history.

## What's next

- Create the semsvg repository, move the design doc and the `capture-groups/` spike scripts there, and open the M0 plan: plugin registry, substrate, row-key inference, context sniffing, bundle read/write.
- Spike first: context sniffing for code (srcref, knitr chunk, call) and the single-file round trip, since restoring freely depends on both.

## Update (same day): renamed to gloss and moved to its own repository

The owner rejected `semsvg` as not compelling or friendly enough. Candidates were checked first: `gloss`, `inkling`, `semio`, `marginalia`, `legible`, `figsense`, `plotsense`, `glean`, `plotwise`, `scholia` and `figlens` are all free on CRAN and Bioconductor, none ever appeared in the CRAN archive, and only `marginalia` has a same-named R repo on GitHub (0 stars). The owner chose **gloss**: medieval glosses were notes anchored to particular words, added by many readers over time, with the text left untouched, which is the design. Public API: `gloss()` builds the figure, every other function is `gl_*`.

**New repository:** local only for now, at `~/Projects/gloss` (`git init`, no commits, no remote yet). Moved there (path in ggai → path in gloss):

- `dev_docs/semsvg-package-design.qmd` → `dev_docs/design.qmd`
- `dev_docs/semantic-svg-research-report.qmd` → `dev_docs/research-report.qmd`
- `dev_docs/semantic-svg-research/` → `dev_docs/research/`
- `dev_docs/figures/semantic-svg/` → `dev_docs/figures/`
- `idea/2026-11-07-agentic-semantic-svg.md`, `idea/2026-11-07-semantic-svg-prior-art.md` → `idea/`

In gloss: `semsvg` → `gloss` and `sem_*` → `gl_*` throughout, including the grob names and probe class in the capture spikes. History notes were added where the docs say "ggai" in the sense of the host package at the time. New files: README, AGENTS.md (with the design principles and the prior-art rule), DESCRIPTION, MIT license, NEWS.md, ignore files, doc indexes, and ADR-0001 (capture by group delimiting plus probes, the decision the Phase 1 plan had reserved ADR-0004 for), ADR-0002 (substrate with append-only anchored records) and ADR-0003 (plugin-based core). The migration has its own log there: `dev_logs/2026-11-08-bootstrap-from-ggai.md`.

**Verification in gloss:** no broken relative links (one false positive inside inline code); `probe.R` and `groups.R` re-run after the rename (identical drawn sequence, 134 primitives, no probe output in the SVG); `design.qmd` and `research-report.qmd` render with no unresolved cross-references and all figures embedded.

**In ggai:** the moved files are deleted (git history keeps them). Links to them in this log, the 2026-11-07 log, the closed plan and ADR-0004 are now plain text, and each of those files got a dated note mapping old paths to new ones; their history text keeps the paths of the time. ADR-0004 gets a note on the name change, since accepted ADRs are not rewritten. The idea, plan and ADR indexes are updated.
