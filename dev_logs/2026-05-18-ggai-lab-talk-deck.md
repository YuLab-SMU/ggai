# 2026-05-18 — ggai lab talk deck

- **Related plan:** [plan/done/2026-05-18-ggai-lab-talk-deck.md](../plan/done/2026-05-18-ggai-lab-talk-deck.md)
- **Related ADRs:** none
- **Related commits / PRs:** none
- **Worked on by:** Codex

## What happened

Built a 13-slide Chinese `ggai` deck for a lab audience of the PI and group members. Compared with the earlier general overview deck, this version shifts the story toward a research-group setting: fragmented figure workflows, why wrappers are insufficient, the `atomic capabilities + skills + agent loop` model, current architecture, bounded execution loop, authentic repo outputs, evidence-preservation guardrails, concrete lab value, and a 90-day adoption path.

## Findings / decisions

- A PI/lab audience needs reassurance about provenance and guardrails earlier than a general product audience does, so the deck places architecture and evidence-preservation before adoption messaging.
- The strongest proof objects again came from the repo itself: the advanced before/after case, the `brain-dev` progression, the architecture overview, and the current in-repo outputs.
- The current repository has 14 skill directories, so the deck uses `14` rather than the older `13` figure that still appears in some prose docs.
- This was a documentation artifact task only, so there was no `CHANGELOG.md` entry.

## Verification

- Built the deck with artifact-tool:
  - `node .../build_artifact_deck.mjs --workspace .../ggai-lab-talk --slides-dir .../slides --out .../output/ggai-lab-talk.pptx --preview-dir .../preview --layout-dir .../layout/final --contact-sheet .../preview/contact-sheet.png --slide-count 13`
- Reviewed the generated contact sheet and several full-size slides manually.
- Ran layout QA in warn-only mode:
  - `node .../check_layout_quality.mjs --layout .../layout/final --warn-only`
  - Result: `0 error(s), 35 warning(s)`; warnings were tight-text / split-inline style warnings without visible render defects.

## Next

If this deck becomes the main group-meeting asset, the next useful step is to add speaker notes or a shorter 7-slide variant for quick internal updates.
