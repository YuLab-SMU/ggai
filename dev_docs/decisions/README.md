# Architecture Decision Records (ADRs)

We use ADRs for choices that would be expensive to reverse and deserve a permanent paper trail. Format follows Michael Nygard's ADR template (lightweight).

## Conventions

- **One file per decision.** Filename: `NNNN-short-slug.md` where `NNNN` is a zero-padded sequence number.
- **Immutable once accepted.** Don't rewrite history. If a decision is overturned, write a new ADR that supersedes it, and edit only the `Status` line of the old one.
- **Status values:** `Proposed`, `Accepted`, `Superseded by ADR-NNNN`, `Deprecated`.
- **Keep it short.** Context, decision, consequences. Save the discussion for `dev_logs/`.

## Template

See [`_template.md`](_template.md).

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| [0001](0001-aisdk-as-agent-runtime.md) | aisdk as the agent runtime | Accepted | 2026-05-17 |
| [0002](0002-code-first-engine-agnostic-artifact.md) | Code-first engine-agnostic artifact | Accepted | 2026-05-17 |
| [0003](0003-skills-over-tools-for-domain-knowledge.md) | Domain knowledge lives in Skills, not tool descriptions | Accepted | 2026-05-17 |
