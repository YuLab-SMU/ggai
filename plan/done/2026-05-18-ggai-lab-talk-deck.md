# ggai Lab Talk Deck

> Status: active.
> Date opened: 2026-05-18. Owner: Codex.

**Goal:** Deliver a polished Chinese `ggai` presentation deck for the PI and labmates that explains the motivation, current capabilities, architecture, evidence, and near-term path into the group's research workflow.

**Why now:** The user asked for a `ggai` PPT explicitly aimed at the research group rather than a general product audience.

**Architecture:** This is a documentation/artifact task. The work reuses current in-repo figures and technical docs, builds a new deck in the thread-scoped presentation workspace, and records the session in the repository planning loop. Package runtime code and exported APIs are intentionally untouched.

**Out of scope:**
- No changes to `ggai` runtime behavior.
- No new reusable presentation template or slide skill.
- No public-facing marketing copy beyond what the lab-talk deck needs.

**Tech stack:** Existing repo docs/assets, Codex `Presentations` skill, artifact-tool presentation builder.

**Verification:** Rendered previews, contact-sheet review, final `.pptx` export, and layout-quality QA.

---

## Progress tracking

**Status legend**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked
- `[-]` Cancelled

**Plan maintenance rules**
- Update immediately after landing a task or sub-step.
- Record the verification command / observed behavior when marking `[x]`.
- If scope shifts, append a `Scope Change` note rather than silently changing completed work.

**Overall progress**
- [x] Task 1: Distill the lab-facing story and proof assets.
- [x] Task 2: Build the deck and review the rendered slides.
- [x] Task 3: Close the documentation loop and hand off the final artifact.

---

### Task 1: Distill the lab-facing story and proof assets

**Status:** `[x]`

**Files**
- Read: `README.md`, `dev_docs/ggai-introduction-report.qmd`, `dev_docs/ggai-advanced-cases.qmd`
- Reuse: `man/figures/ggai-architecture-overview.png`, `docs/assets/cases/brain-dev/*`, `dev_docs/figures/*`

**Intent**
- Reframe the existing project story for a PI/lab audience before writing slides, so the deck answers lab-review questions instead of sounding like a product brochure.

**Checklist**
- [x] Read the current architecture/product docs.
- [x] Inspect available repo-native visual assets.
- [x] Choose a lab-talk arc centered on pain point, proof, and adoption path.

**Verification**
- Story spine selected: `why this matters -> what ggai is -> how it works -> what it already proves -> how the lab can use it next`.

---

### Task 2: Build and render the deck

**Status:** `[x]`

**Files**
- Create: `outputs/<thread>/presentations/ggai-lab-talk/*`

**Intent**
- Produce a finished deck with precise technical claims, strong visual rhythm, and authentic in-repo proof objects.

**Checklist**
- [x] Lock the deck profile, design system, and claim spine.
- [x] Author the slide modules.
- [x] Render previews and contact sheet.
- [x] Iterate weak slides after QA.

**Verification**
- `build_artifact_deck.mjs` exported `output/ggai-lab-talk.pptx` with 13 slides.
- `check_layout_quality.mjs --warn-only` reported 0 errors.
- Contact sheet and representative full-size previews reviewed manually.

---

### Task 3: Close the loop

**Status:** `[x]`

**Files**
- Modify: `plan/README.md`
- Create: `dev_logs/2026-05-18-ggai-lab-talk-deck.md`

**Intent**
- Keep the repository workflow honest once the artifact lands.

**Checklist**
- [x] Record verification.
- [x] Write the dev log.
- [x] Move the plan to `plan/done/`.

**Verification**
- `dev_logs/2026-05-18-ggai-lab-talk-deck.md` created.
- Plan prepared for closure and relocation to `plan/done/`.

---

## Scope changes

_(append-only; never edit completed tasks above)_

## Closing notes

Completed 2026-05-18. The finished artifact is `outputs/019e3aeb-1ff5-7a41-8dff-6646017060b8/presentations/ggai-lab-talk/output/ggai-lab-talk.pptx`. Closing log: `dev_logs/2026-05-18-ggai-lab-talk-deck.md`.
