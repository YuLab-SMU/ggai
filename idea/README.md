# idea

Exploration with no commitment. If a thought might become a plan but hasn't earned that status yet, it lives here. Free-form, may be abandoned.

## When to write here vs elsewhere

- **idea/** — "We might want to do X. Let me sketch what X looks like before deciding."
- **TODO.md** — "We will probably want to do X. Park it on the backlog."
- **plan/** — "We are doing X. Here is the task breakdown."
- **dev_docs/decisions/** — "We decided X. Here's why, so we don't relitigate."

## Conventions

- Filename: `YYYY-MM-DD-<slug>.md`. Keep dates so abandoned ideas can be found later.
- It's fine to abandon. If an idea didn't pan out, append a short closing note (`Closed YYYY-MM-DD: rejected because ...`) rather than deleting.
- If an idea matures, promote it: write a plan in `plan/`, link the idea, and add `→ promoted to plan/<file>` at the top.

## Index

- [2026-11-07-agentic-semantic-svg.md](2026-11-07-agentic-semantic-svg.md) — Agentic semantic SVG export: deterministic element/data binding plus agent-authored semantics, so interaction does not depend on pre-written converters. → promoted to [plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md](../plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md) (superseded), now continued as the standalone `semsvg` package: [design](../dev_docs/semsvg-package-design.qmd).
- [2026-11-07-semantic-svg-prior-art.md](2026-11-07-semantic-svg-prior-art.md) — Prior art and measured evidence for the above: ggiraph/gridSVG/maidr tagging, Shiny/InteractiveComplexHeatmap hit-testing, plotly/canvasXpress translation, literature, and an evaluation of REA and Craft Anything.
