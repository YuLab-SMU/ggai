# Context And Scope

## Problem

`ggai` already has:

- compiler-first language-to-visual-spec workflows
- direct figure prompt compilation plus image candidate selection
- stateful session editing for compiled `ggplot`-side outputs

What it does not yet have is a native editable scientific figure pipeline that ends in structured, inspectable, and revisable vector output.

## Current Position

The present redesign direction is:

- use direct bottom-layer model APIs
- do not depend on `AutoFigure-Edit` service APIs
- do not copy `AutoFigure-Edit` runtime contracts blindly
- reuse only the useful architectural ideas from AutoFigure-style staged generation

## Why This Matters

`ggai` is not just another image-generation app.

Its special ecological position in this repository is:

- it is an `R` package
- it already owns the compiler abstraction
- it already owns inspectable sidecars
- it already owns session-style editing semantics
- it should become the canonical interface for future figure work, even if other systems later consume it

That means the editable-figure system should be expressed in `ggai`'s own abstractions first.

## In Scope

- document the redesign space
- capture current findings from `ggai`, `DeepScientist`, and `AutoFigure-Edit`
- define a sustainable document structure for parallel exploration
- converge on a `ggai-native` editable figure architecture
- identify exploration workstreams and open questions

## Out Of Scope For Now

- implementing the new pipeline
- choosing final concrete model vendors
- designing the final UI
- integrating with `DeepScientist` runtime in code
- reproducing `AutoFigure-Edit` feature-for-feature

## Working Constraints

- the system should remain compiler-first
- the system should preserve inspectable intermediate artifacts
- the system should support future session-based editing
- the system should not make `ggai` depend on a separate long-running service to be conceptually complete
- future `DeepScientist` integration should consume `ggai` contracts, not define them

## Current Rejected Direction

Rejected for now:

- using `AutoFigure-Edit` as a direct API dependency

Reason:

- it would let an external runtime define the artifact contract
- it would bypass `ggai`'s own object model
- it would make later editing semantics harder to unify with `ggai` sessions
