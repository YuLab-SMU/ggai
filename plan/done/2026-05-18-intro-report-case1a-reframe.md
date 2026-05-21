# Introduction report case 1A reframe

> Status: completed.
> Date opened: 2026-05-18. Owner: Yonghe Xia.

**Goal:** Replace the overstated case-1A comparison with a better-matched allegorical asset and a truthful claim about what ggai actually contributes.

**Why now:** Review of case 1A found that the current "knowledge tree" image is not a credible peer comparison for paper #3 Figure 1; it changes both the visual task and the artistic ambition.

**Architecture:** Keep the work inside `dev_docs/`: add one new generated allegory image, revise the case-1A text/table, and render the report. Preserve the old asset for history instead of overwriting it.

**Out of scope:**
- Claiming parity with commissioned cultural illustration.
- Reworking all case-study rhetoric across the report.
- Changing package code or public behavior.

**Tech stack:** Built-in image generation, Quarto.

**Verification:** Inspect the new asset, render the report, and confirm case 1A now frames ggai as a fast concept-study path rather than a like-for-like replacement for the commissioned original.

---

## Progress tracking

**Status legend**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed

**Overall progress**
- [x] Task 1: Add a better-matched allegorical image asset. — selected no-text generated variant and copied `case-clusterprofiler-allegory-v2.png`.
- [x] Task 2: Rewrite the case-1A argument. — revised source in `dev_docs/ggai-introduction-report.qmd`.
- [x] Task 3: Render, verify, and log the patch. — `quarto render dev_docs/ggai-introduction-report.qmd`; documented in `dev_logs/2026-05-18-intro-report-case1a-reframe.md`.

---

### Task 1: Add a better-matched allegorical image asset

**Status:** `[x]`

**Files**
- Create: `dev_docs/figures/case-clusterprofiler-allegory-v2.png`

**Intent**
- Use an image that at least answers the same rhetorical problem as the paper figure: multi-omics inputs becoming biological understanding through a human-scale allegory.

**Checklist**
- [x] Generate variants with the built-in image tool.
- [x] Select a no-text variant to avoid label corruption.
- [x] Copy the selected asset into the report figures directory.

**Verification**
- Visually inspected `dev_docs/figures/case-clusterprofiler-allegory-v2.png`.

---

### Task 2: Rewrite the case-1A argument

**Status:** `[x]`

**Files**
- Modify: `dev_docs/ggai-introduction-report.qmd`

**Intent**
- Separate "same rhetorical job" from "same artistic level" and stop presenting a concept study as if it were an equal substitute for a commissioned hero illustration.

**Checklist**
- [x] Swap Figure 10 to the new allegory asset.
- [x] Replace the current cost/time table with one that distinguishes flagship art from concept study.
- [x] Rewrite the closing takeaway.

**Verification**
- Read the revised section in source and rendered output.

---

### Task 3: Render, verify, and log the patch

**Status:** `[x]`

**Files**
- Create: `dev_logs/2026-05-18-intro-report-case1a-reframe.md`

**Intent**
- Record why "same topic" is not enough to claim equivalence in a case study.

**Checklist**
- [x] Render the report.
- [x] Update the plan and write the dev log.

**Verification**
- `quarto render dev_docs/ggai-introduction-report.qmd`

---

## Scope changes

_(append-only; never edit completed tasks above)_

## Closing notes

Closed 2026-05-18. Case 1A now uses a better-matched allegorical replacement asset and presents ggai as a rapid concept-study tool rather than a replacement for commissioned illustration. See [dev_logs/2026-05-18-intro-report-case1a-reframe.md](../../dev_logs/2026-05-18-intro-report-case1a-reframe.md).
