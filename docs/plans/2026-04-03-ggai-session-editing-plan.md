# ggai Stateful Editing Session Plan

**Goal:** Add a stateful editing-session layer so `ggai` can edit an existing plot/spec incrementally instead of recompiling the whole figure from scratch every turn.

**Product Intent:** Move `ggai` from “AI figure generator/compiler” toward “AI figure editor.” A user should be able to start from a base `ggplot`, issue sequential natural-language edit instructions, inspect the current spec, undo changes, and export the current plot code at any point.

**Scope:** This plan is only for the `ggplot`-side continuous editing workflow. It does not cover direct-image figure generation, BioRender demos, or hybrid biomedical asset composition.

---

## What Exists Already

The current codebase already has the core primitives needed for a session layer:

- `inspect_spec()`
- `edit_spec()`
- `update_spec()`
- `render_spec()`
- `spec_history()`
- `as_code()`
- `compile_layer_spec()`
- plot-side compiled-spec history attached to `ggplot` objects

What is missing is the session object that turns those primitives into a coherent interaction model.

---

## Target API

The first version should support this workflow:

```r
s <- start_ggai_session(base_plot)
s <- chat_edit(s, "highlight the heavy low-MPG outlier")
s <- chat_edit(s, "use outline only, not filled area")
s <- chat_edit(s, "make the green label smaller and move it upward")

plot(s)
inspect_spec(s)
as_code(s)

s <- undo(s)
plot(s)
```

Optional helper aliases can come later, but this should be the minimum supported interaction model.

---

## Architecture

### 1. Session State Object

Create a lightweight `ggai_session` object with:

- `base_plot`
- `current_plot`
- `history`
- `history_index`
- `current_compiled`
- `meta`

Each history entry should store:

- `instruction`
- `compiled_spec`
- `plot`
- `code`
- `timestamp`
- `kind`

### 2. Editing Compiler

Do **not** start with a full LLM patch compiler.

Phase 1 should use a hybrid editing strategy:

- deterministic patch heuristics for common edits
- fallback to full spec edit when needed

This gives a usable system faster and avoids overfitting everything to the model.

### 3. Linear History First

Support:

- append edit
- inspect current version
- undo one step

Do **not** add branching history, merges, or redo stacks in the first version unless the implementation stays simple.

---

## Phase 1 Deliverables

### A. Session Constructor

Implement:

- `start_ggai_session(plot)`

Behavior:

- initialize session with `base_plot`
- carry over existing `ggai` compiled history if the plot already has one
- if there is no history yet, session starts empty but attached to `base_plot`

### B. Session Accessors

Implement:

- `plot.ggai_session()`
- `inspect_spec.ggai_session()`
- `as_code.ggai_session()`
- `spec_history.ggai_session()` or an equivalent history accessor

Behavior:

- these methods should act on the current history position

### C. Session Editing Entry Point

Implement:

- `chat_edit(session, instruction, ...)`

Behavior:

- take current compiled spec when available
- decide whether the edit can be handled with deterministic patching
- apply the patch
- rerender current plot
- append a new history version

### D. Undo

Implement:

- `undo(session)`

Behavior:

- move one history step back
- restore prior `current_plot`, `current_compiled`, and `code`

---

## Deterministic Patch Coverage For Version 1

The first version should cover the edits users are most likely to try in demos:

- change fill to outline only
- change color
- change alpha
- change line width / stroke
- change label text size
- move label up/down/left/right
- delete fill but keep border
- lighten / darken a label or highlight

These should operate on current layer specs without model calls where possible.

The concrete initial test case should be:

- start from a plot with AI-generated highlight region
- user says: “use outline only, not filled area”
- session updates the rect layer from filled highlight to outline highlight

---

## Suggested Files

### New files

- `R/session_edit.R`
- `R/session_methods.R`
- `tests/testthat/test-ggai-session.R`

### Likely touched existing files

- `R/spec_inspection.R`
- `NAMESPACE`
- `man/` via roxygen

---

## Testing Plan

### Must-pass tests

1. session starts from a base ggplot
2. session can adopt an existing `ggai`-augmented plot
3. `chat_edit()` adds a new history version
4. `undo()` restores the previous version
5. `inspect_spec(session)` returns the current spec
6. `as_code(session)` returns code for the current version
7. deterministic patch:
   - filled highlight -> outline highlight
8. deterministic patch:
   - label size or offset edit modifies current text layer params

### Nice-to-have tests

9. session can continue after multiple edits
10. `plot(session)` returns the current plot object

---

## Implementation Order

1. Add `ggai_session` constructor and object shape.
2. Add current-state accessors (`plot`, `inspect_spec`, `as_code`).
3. Implement linear history storage.
4. Implement `chat_edit()` with deterministic patching only.
5. Implement `undo()`.
6. Add tests.
7. If the deterministic path is stable, consider a model-assisted patch mode later.

---

## Deliberate Non-Goals For This Pass

Do not add these yet:

- branching edit history
- multi-user collaboration
- direct-image editing session support
- hybrid biomedical asset editing
- automatic redo unless it falls out almost for free

The purpose of this pass is to make the `ggplot + ggai` editing story real and demoable.
