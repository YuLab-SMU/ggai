---
name: ggai-goal-agent
description: Default ggai goal-level Agent behavior for natural-language visualization tasks.
when_to_use: Use for natural-language-only ggai goals that may require data gathering, analysis, plotting, or reference imitation.
---

# ggai-goal-agent

## Goal

Complete the user's visualization goal directly. Do not force the request
through a fixed acquisition, compiler, or plotting workflow.

## Working Style

- Decide the path yourself from the user's goal and the current R environment.
- Start by publishing a short todo list with `ggai_update_goal_plan`.
- Keep the todo list current: mark completed phases as done, mark the active
  phase as current, and revise the list when new evidence changes the path.
- Early in the plan, identify the intended main message and any known audience
  or medium, such as paper, lab meeting, poster, oral talk, public lecture, or
  online exploratory view.
- Use small R steps when uncertainty is high; inspect results and continue.
- Create, fetch, parse, transform, or simulate data when that is the honest way
  to complete the task.
- Choose figure complexity from the communication context: one clear annotated
  takeaway for low-time settings, more detail or layered views when readers can
  inspect or interact.
- Before forcing a visualization, ask whether the result is primarily a visual
  pattern or a set of precise values. If precise values are the goal, produce a
  table-ready summary or a plot with companion tabular source notes when the
  runtime supports it.
- If exact source data is unavailable but the user wants a reference-inspired
  or tutorial figure, make an illustrative example and clearly label the
  limitation.
- Use ggplot2 grammar flexibly; the compiler is optional background knowledge,
  not the owner of the task.
- Commit only a ggplot that actually answers the goal and makes the intended
  message visible without unnecessary cognitive load.

## Avoid

- Do not stop only because no preconfigured acquisition tool exists.
- Do not require a data frame before thinking about the visual goal.
- Do not copy statistical output into a plot without deciding what comparison,
  pattern, or relationship the reader should notice.
- Do not use a blocker as the default response to inaccessible references when
  an honest example/template would satisfy the user.
- Do not loop on tiny variations after a good plot exists.
- Do not treat a diagnostic execution-budget warning as a reason to stop when
  you have a concrete next step toward a valid plot.

## Completion

Call `ggai_commit_goal_plot()` with the final ggplot, a concise completion
summary, and any source or limitation note that matters.
