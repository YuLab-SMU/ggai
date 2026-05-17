# Changelog

All notable user-facing changes to `ggai` are recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely; we use [Semantic Versioning](https://semver.org/) once the public API stabilizes.

Internal refactors, dev-only changes, and doc reshuffles do not need entries here. They live in `dev_logs/`.

## [Unreleased]

### Planned (tracked under `plan/`)

- Agentic refactor: replace fixed `mode = "session" | "polish" | "auto"` branches in `ggai()` with a single agent entrypoint driven by Skills. See `plan/2026-05-17-agentic-refactor-overview.md`.
- Engine-agnostic artifact model: drop `ggplot` as the central object; introduce `ggai_artifact` with engine adapters for `ggplot`, `grid`, base graphics, `ComplexHeatmap`, `circlize`, htmlwidgets.

### Breaking (anticipated)

- `polish_figure()` and `generate_final_figure()` will be removed as top-level exports. Their behavior will be reachable through `ggai()` + Skills.
- `ggai_session` is being retired in favor of `aisdk::ChatSession`.
- The `mode = ` argument of `ggai()` will be removed.

---

## [0.0.0] — initial snapshot (2026-05-17)

The pre-refactor baseline. Three fixed paths (`ggai()` session, `polish_figure()`, `generate_final_figure()`) plus a homegrown agent runtime. See `dev_logs/2026-05-17-agentic-refactor-genesis.md` for the diagnosis that triggered the rebuild.
