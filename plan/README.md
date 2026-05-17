# plan

Forward-looking phase plans. Each plan covers a coherent slice of work with task-by-task tracking. Unlike `TODO.md` (unscoped backlog) or `idea/` (exploration), files here represent **committed work**.

## Conventions

- **Filename:** `YYYY-MM-DD-<slug>.md`. The date is when the plan was opened, not when work ends.
- **One plan per coherent phase.** If the work spans many weeks and changes shape, split into numbered phase plans (e.g. `...-phase-1-primitives.md`, `...-phase-2-agent-layer.md`).
- **Status discipline (in the plan body):**
  - `[ ]` Not started
  - `[~]` In progress
  - `[x]` Completed (record verification command / observed behavior)
  - `[!]` Blocked (note blocker)
  - `[-]` Cancelled (note reason)
- **Update immediately, never batch.** If you batch updates you lose the closed-loop guarantee.
- **Never silently rewrite a `[x]` task.** Append a "Scope Change — YYYY-MM-DD" note instead.
- **When a plan closes:** move the file to `plan/done/` and write a closing `dev_logs/` entry.

## Template

See [`_template.md`](_template.md).

## Active plans

- [2026-05-17 — Agentic refactor overview](2026-05-17-agentic-refactor-overview.md) — multi-phase rebuild on top of aisdk.

## Completed plans

_(none yet — completed plans live in `plan/done/`)_
