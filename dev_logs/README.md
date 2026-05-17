# dev_logs

Append-only record of engineering work. Unlike `plan/` (forward-looking) or `dev_docs/` (current truth), files here are a **chronological history** of what actually happened, why, and what came next.

## Conventions

- **Filename:** `YYYY-MM-DD-<slug>.md`. One file per session or per coherent task block. If a session spans several days, keep adding sections to one file rather than fragmenting.
- **First-person voice is fine.** These are work notes, not docs.
- **Link generously.** Reference the plan task you were executing, the ADRs you accepted, the commits / PRs you opened.
- **Don't rewrite.** If a later log invalidates an earlier one, write a new entry pointing back; don't edit history.

## Template

See [`_template.md`](_template.md).

## When to write a log

Always, for non-trivial work:

- A plan task moved to `[x]`.
- An ADR was accepted.
- A debugging session produced a non-obvious finding.
- A refactor was completed (or abandoned).
- A demo session surfaced a new requirement.

Don't write a log for: routine `devtools::document()` runs, typo fixes, comment edits.

## Index

Newest first.

- [2026-05-17 — P6.b: Polish loose ends](2026-05-17-p6b-polish.md)
- [2026-05-17 — P6: Composite + htmlwidget engine adapters](2026-05-17-p6-composite-htmlwidget.md)
- [2026-05-17 — P5.b: Live capability probe](2026-05-17-p5b-live-probe.md)
- [2026-05-17 — P5: ComplexHeatmap + circlize engine adapters](2026-05-17-p5-complex-heatmap-circlize.md)
- [2026-05-17 — P4.b: Capability-aware skill modes](2026-05-17-p4b-capability-modes.md)
- [2026-05-17 — P4: Smoke test through real LLM calls](2026-05-17-p4-smoke-test.md)
- [2026-05-17 — P3: First five skills landed](2026-05-17-p3-first-five-skills.md)
- [2026-05-17 — P2: Drop the in-tree agent layer](2026-05-17-p2-drop-agent-layer.md)
- [2026-05-17 — P1: Layer 2 primitives landed](2026-05-17-p1-layer2-primitives.md)
- [2026-05-17 — Agentic refactor genesis](2026-05-17-agentic-refactor-genesis.md)
