# ADR-0004: The semantic figure substrate is a standalone package (semsvg), not part of ggai

- **Status:** Accepted
- **Date:** 2026-11-08
- **Deciders:** Yonghe Xia
- **Related:** [dev_docs/semsvg-package-design.qmd](../semsvg-package-design.qmd), [plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md](../../plan/done/2026-11-07-semantic-svg-phase-1-skeleton.md), [dev_logs/2026-11-07-semantic-svg-prior-art.md](../../dev_logs/2026-11-07-semantic-svg-prior-art.md), [dev_logs/2026-11-08-semsvg-decisions.md](../../dev_logs/2026-11-08-semsvg-decisions.md)

## Context

The 2026-11-07 Phase 1 plan put semantic SVG export inside ggai as Layer-2 primitives (`ggai_svg_skeleton()`, `ggai_svg_compile()`, `ggai_svg_verify()`) over `ggai_artifact`.

The review and redesign that followed changed what the thing is:

- ggai **makes and edits** figures. The new work **reads** a figure that is already drawn, and keeps what it learns: layered, append-only records anchored to elements, verified against the data, and carried through later edits to the figure.
- It has its own long-lived object (the figure substrate and its bundle format), its own extension points (engines, classify rules, layers, checks, operations, projections, context sniffers, agent stages) and a browser runtime.
- Its hard requirements differ from ggai's: R >= 4.2 for `groupGrob()`, svglite >= 2.2, xml2, a JS runtime. It also has to work on figures ggai never produced.
- The owner asked for it to be designed as a new aisdk-driven package that does not carry over ggai's architecture.

## Decision

**Build it as a standalone R package, working name `semsvg`, in its own repository.** ggai and semsvg do not depend on each other and share no code.

- Both use aisdk as the agent runtime (consistent with ADR-0001), independently.
- They meet at the figure object: anything ggai produces (a ggplot, a patchwork, a ComplexHeatmap, a recorded base plot) can be captured by semsvg. Data problems semsvg exposes can be handed back to ggai to fix the figure. Any bridge is optional and lives on the ggai side as a `Suggests`.
- Until the repository exists, the design doc and the spike scripts stay in ggai's `dev_docs/`. They are not part of ggai's build.

## Alternatives considered

- **Primitives inside ggai (the Phase 1 plan).** Rejected. It ties a figure-reading tool to a figure-making package, puts heavy dependencies on every ggai user, and limits it to `ggai_artifact` inputs.
- **Incubate in a subdirectory of the ggai repo.** Rejected. An R package cannot be nested cleanly in another package's source tree; it would have to be moved out later anyway, with the history split.

## Consequences

### Positive

- ggai keeps its scope and dependencies.
- semsvg can define its own object model, bundle format and plugin system without fitting ggai's artifact contract.
- Third-party packages can extend semsvg without touching ggai.

### Negative / accepted tradeoffs

- Two repositories to maintain; cross-package work needs coordination.
- The ADR-0004 number was reserved in the Phase 1 plan for the capture mechanism. It now records this decision; the capture decision (group delimiting plus probes) will be recorded in the semsvg repo.

### Follow-ups

- Create the semsvg repository; move the design doc and `dev_docs/semantic-svg-research/capture-groups/` scripts there.
- Open the semsvg M0 plan in that repository.
- Optional later: a ggai-side bridge that passes an artifact's code and context to semsvg.
