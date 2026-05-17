# dev_docs

Long-lived engineering documentation. Unlike `dev_logs/` (append-only history) or `plan/` (forward-looking phase plans), files here are **the current truth** and get rewritten as the system evolves.

## Layout

- [`architecture/`](architecture/) — Current target architecture. Updated when ADRs are accepted.
- [`decisions/`](decisions/) — Architecture Decision Records (ADRs). Numbered, immutable once accepted; superseded by later ADRs rather than rewritten.

## When to add a doc here

- **architecture/** — When the shape of the system changes meaningfully. Re-read it before starting any cross-cutting refactor.
- **decisions/** — When a choice would be expensive to reverse and deserves a paper trail. Examples: which agent runtime to depend on, what the central data structure is, whether to drop a public API.

If you're writing a one-shot post-mortem, a meeting note, or a session summary, put it in `dev_logs/` instead.

## Index

- [Architecture — Agentic core](architecture/agentic-architecture.md)
- [ADR Index](decisions/README.md)
