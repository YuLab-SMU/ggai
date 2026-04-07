# ggai Session Editing

## Why It Matters

This is the bridge from “AI figure generator” to “AI figure editor.”

Without session editing, the system behaves like:

- prompt in
- figure out

With session editing, the system behaves like:

- start from an existing plot
- keep current state
- apply local edits incrementally
- inspect the structured sidecar
- undo and continue

That is much closer to a real interactive user workflow.

## The Key Message

Use this sentence:

> “`ggai` is not only able to generate figures. It can also hold on to the current plot state and make incremental edits instead of recompiling the whole figure from scratch every turn.”

## Demo Script

Use:

[`demo/ggai_session_demo.R`](/Users/xiayh/Projects/ggai/demo/ggai_session_demo.R)

This demonstrates:

- `start_ggai_session(base_plot)`
- `chat_edit()`
- `inspect_spec()`
- `spec_history()`
- `as_code()`
- `undo()`

## Outputs

The demo produces:

- `demo_outputs/ggai_session_01_base.png`
- `demo_outputs/ggai_session_02_highlight.png`
- `demo_outputs/ggai_session_03_outline_only.png`
- `demo_outputs/ggai_session_04_label_tuned.png`
- `demo_outputs/ggai_session_05_after_undo.png`
- `demo_outputs/ggai_session_current_code.R`

## Why This Is Strategically Important

This feature answers a very practical question:

> “Can AI do local editing on an existing plot, or does it regenerate everything every time?”

If the answer is “yes, it can edit incrementally,” adoption becomes much easier.
