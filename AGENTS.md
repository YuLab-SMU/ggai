# Repository Guidelines

`ggai` is an R package for agent-driven scientific figure creation. It builds on top of [`aisdk`](https://github.com/YuLab-SMU/aisdk) (Agent + Skills + Provider infrastructure) and **does not own its own agent runtime**.

## Project Structure & Module Organization

- `R/` — Package source. Pure R primitives only: rendering, image generation, glyph synthesis, artifact inspection, engine adapters. No agent loop, no tool-calling runtime.
- `inst/skills/` — Skill packages (`SKILL.md` + optional `scripts/` + `references/`). Each skill teaches the agent how to compose primitives for one kind of task.
- `man/` — Generated documentation. Do not edit `.Rd` files; they are regenerated from roxygen comments in `R/`.
- `tests/testthat/` — Unit and integration tests. Entrypoint `tests/testthat.R`.
- `demo/` — End-to-end demo scripts. Each demo doubles as a smoke test for one agent path.
- `vignettes/` — Long-form user documentation (Quarto).
- `dev_docs/` — Architecture, ADRs, and long-lived engineering notes. **Not part of the build.**
- `dev_logs/` — Time-stamped engineering session logs (append-only history). **Not part of the build.**
- `plan/` — Phase plans with task-by-task progress tracking. One file per phase. **Not part of the build.**
- `idea/` — Product/architecture exploration that has not yet been promoted to a plan. **Not part of the build.**

## Build, Test, Document

- `Rscript -e "devtools::document()"` — regenerate `NAMESPACE` and `man/*.Rd` from roxygen.
- `Rscript -e "devtools::load_all()"` — load the package for interactive development.
- `Rscript -e "testthat::test_dir('tests/testthat')"` — run the test suite.
- `Rscript -e "testthat::test_file('tests/testthat/test-<name>.R')"` — run one test file.
- `R CMD build .` — build a source tarball.
- `R CMD check --as-cran ggai_*.tar.gz` — CRAN-style check.

## Development Workflow

The doc suite implements a **closed-loop process**. Every code change either lands as part of an active plan or as a tracked patch with a corresponding dev log entry. Nothing of consequence happens silently.

### Doc-to-code lifecycle

```
  idea/         ──promote──▶   plan/        ──execute──▶  code + tests
                                  │                          │
                                  │                          ▼
                                  │                       dev_logs/
                                  │                          │
                                  ▼                          ▼
                          (close plan)               CHANGELOG.md (if user-facing)
                                                            │
                                                            ▼
                                          (ADR if architectural and irreversible)
                                                            │
                                                            ▼
                                              dev_docs/decisions/ + architecture/
```

### When you start work

1. Identify the active plan in `plan/` that the work belongs to.
2. If no plan covers it, draft a new one from `plan/_template.md` (or stretch an existing one and note the scope change).
3. If you are exploring without commitment, write in `idea/` first; promote to `plan/` only when the shape is clear.

### When you finish a unit of work

1. Update the plan checklist immediately — don't batch. Record the verification command when marking `[x]`.
2. Write a `dev_logs/<YYYY-MM-DD>-<slug>.md` entry summarizing what changed, why, and what's next. One log per work session is enough; you don't need one per commit.
3. If user-facing behavior changed, add a line to `CHANGELOG.md` under `[Unreleased]`.
4. If the work introduced or settled an architectural decision, write a numbered ADR under `dev_docs/decisions/`.

### Plan status discipline

- Status legend: `[ ]` Not started, `[~]` In progress, `[x]` Done, `[!]` Blocked, `[-]` Cancelled.
- Update immediately, not in batches.
- Never silently rewrite a `[x]` task. If scope shifts, append a **Scope Change** note dated at the bottom.
- When a plan closes, move the file to `plan/done/` and write a closing dev log.

### TODO vs plan vs idea

- **`TODO.md`** — small, unscoped items that aren't worth a plan file. Triage during planning sessions; promote to `plan/` once shape is clear.
- **`idea/`** — exploration with no commitment. Free-form, may be abandoned.
- **`plan/`** — committed phase with dated filename and task tracking.

## Coding Style

- Standard R style, 2-space indentation. Use `snake_case` for functions and helpers; `CamelCase` only for R6 classes.
- Document exported functions with `roxygen2` inline.
- Returns over side effects: primitives should return structured data, not `print()` or `plot()`. The agent loop needs results to chain.
- Engine-agnostic where possible: code that works on `ggai_artifact` rather than `ggplot` directly.
- Prefer pure functions over R6 state machines unless lifecycle/identity is genuinely needed.

## Tests

- `testthat` edition 3.
- Name files `test-<feature>.R`. Helpers in `tests/testthat/helper-*.R` or `setup.R`.
- Tests must not require network calls or paid API keys by default. Gate provider-touching tests behind `Sys.getenv()` and `skip_if_not()`.

## Commit & PR

- Short imperative subjects: `feat(skills): add ggai-figure-polish skill`, `fix(render): handle empty layout regions`, `docs(adr): accept ADR-0002 engine-agnostic artifact`.
- Reference the plan task and link the dev log in the PR body when relevant.
- Always run `devtools::document()` and at least the affected `testthat` files before PR.

## CRAN Hygiene (when we get there)

Same as `aisdk` upstream: ASCII-safe docs, `tempdir()` defaults, no `<<-`, no `.GlobalEnv` writes, no `Rplots*.pdf` artifacts in tarball, no `dev_docs/` / `dev_logs/` / `plan/` / `idea/` leaking into the build.
