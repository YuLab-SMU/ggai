# 2026-05-18 — Introduction report case 1A reframe

- **Related plan:** [plan/done/2026-05-18-intro-report-case1a-reframe.md](../plan/done/2026-05-18-intro-report-case1a-reframe.md)
- **Related ADRs:** None.
- **Related commits / PRs:** (not yet committed)
- **Worked on by:** Yonghe Xia (with Codex)

## What happened

Reviewed case 1A in `dev_docs/ggai-introduction-report.qmd` after the original comparison was flagged as having too large a quality gap. The concern was valid: the paper figure is a commissioned narrative illustration with cultural framing, project history, and dense information design, while the old ggai "knowledge tree" asset was a much simpler poster-like metaphor.

Generated a better-matched allegorical image with the built-in image tool, selected the no-text variant to avoid label corruption, and added it as `dev_docs/figures/case-clusterprofiler-allegory-v2.png`. Then rewrote the report section so it no longer claims like-for-like replacement. The new framing says what the evidence can actually support: ggai can produce a directionally correct concept study on the same day, but it is not yet a substitute for commissioned hero art.

## Findings / decisions

- "Same topic" is not the same as "same deliverable." The old comparison failed because the rhetorical job changed from flagship narrative art to decorative metaphor.
- Generated text inside artistic images is still too brittle for this report; the chosen replacement intentionally carries no text.
- This case is strongest when positioned as lowering the barrier to first-draft visual thinking, not as a cost-comparison stunt against bespoke illustration.

## Verification

- Generated replacement asset with the built-in image tool and visually inspected the selected no-text variant.
- `quarto render dev_docs/ggai-introduction-report.qmd`
- Confirmed the rendered HTML now shows the new Figure 10 asset and the revised "概念首稿" framing.

## Next

- If the report later wants to argue for production-grade image-model work, it needs a separate case where the target deliverable itself is closer to what the model can honestly produce today.
