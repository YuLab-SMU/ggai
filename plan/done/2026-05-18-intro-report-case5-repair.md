# Introduction report case 5 repair

> Status: completed.
> Date opened: 2026-05-18. Owner: Yonghe Xia.

**Goal:** Replace the weak case-5 comparison in the introduction report with a structurally comparable TF enrichment matrix example and truthful framing.

**Why now:** Review of `dev_docs/ggai-introduction-report.qmd` found that the current side-by-side compares paper #1 Figure 3 against an unrelated single-panel GO dotplot, which overstates what the evidence shows.

**Architecture:** Keep the change scoped to report-only assets under `dev_docs/`: add one reproducible figure-generation script, add one derived PNG, and revise the case-5 prose and prompt. No package API or shipped skill behavior changes.

**Out of scope:**
- Reproducing the paper's original biological data.
- Adding a new public ggai feature.
- Refactoring unrelated report sections.

**Tech stack:** R, `ggplot2`, `patchwork`, Quarto.

**Verification:** Render the figure script, inspect the PNG, then render the Quarto report and confirm the case-5 section shows a genuinely comparable layout and no unsupported equivalence claim.

---

## Progress tracking

**Status legend**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked
- `[-]` Cancelled

**Overall progress**
- [x] Task 1: Build a structurally comparable case-5 figure. — `Rscript dev_docs/scripts/build-case-tf-enrichment-matrix.R`; visually inspected `case-tf-enrichment-matrix.png`.
- [x] Task 2: Rewrite the case-5 report text around the new evidence. — source updated in `dev_docs/ggai-introduction-report.qmd`.
- [x] Task 3: Verify the rendered report and log the patch. — `quarto render dev_docs/ggai-introduction-report.qmd`; documented in `dev_logs/2026-05-18-intro-report-case5-repair.md`.

---

### Task 1: Build a structurally comparable case-5 figure

**Status:** `[x]`

**Files**
- Create: `dev_docs/scripts/build-case-tf-enrichment-matrix.R`
- Create: `dev_docs/figures/case-tf-enrichment-matrix.png`

**Intent**
- Close the core evidence gap by showing the same visual grammar as paper #1 Figure 3: shared TF-gene x-axis, upper time-point strip, family annotation bar, and lower enrichment dot matrix.

**Checklist**
- [x] Create a reproducible toy-data script for the matrix figure.
- [x] Generate the PNG asset.
- [x] Visually confirm that the result is structurally comparable to the paper figure.

**Verification**
- `Rscript dev_docs/scripts/build-case-tf-enrichment-matrix.R`
- Inspected `dev_docs/figures/case-tf-enrichment-matrix.png`.

---

### Task 2: Rewrite the case-5 report text around the new evidence

**Status:** `[x]`

**Files**
- Modify: `dev_docs/ggai-introduction-report.qmd`

**Intent**
- Replace the misleading single-panel comparison with honest language that distinguishes structural reproduction from biological data reproduction.

**Checklist**
- [x] Swap the unrelated figure for the new matrix figure.
- [x] Remove the claim that the old panel had "完全一致" semantics.
- [x] Update the example prompt so it describes the full matrix layout rather than a plain dotplot.

**Verification**
- Read the revised section in source and rendered output.

---

### Task 3: Verify the rendered report and log the patch

**Status:** `[x]`

**Files**
- Create: `dev_logs/2026-05-18-intro-report-case5-repair.md`

**Intent**
- Keep the documentation workflow closed-loop and leave a durable note about the distinction between "same encoding" and "same chart problem."

**Checklist**
- [x] Render the report.
- [x] Record what changed, why, and what remains out of scope.

**Verification**
- `quarto render dev_docs/ggai-introduction-report.qmd`
- Read the rendered HTML around case 5.

---

## Scope changes

_(append-only; never edit completed tasks above)_

## Closing notes

Closed 2026-05-18. The report now uses a structurally comparable TF enrichment matrix asset and states the claim honestly as figure-grammar reproduction over toy data. See [dev_logs/2026-05-18-intro-report-case5-repair.md](../../dev_logs/2026-05-18-intro-report-case5-repair.md).
