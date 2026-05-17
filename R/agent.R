# Thin factory over aisdk::create_agent. ggai owns no agent runtime; this file
# just configures aisdk with the verb tools, skill discovery, and a domain
# system prompt.

#' Default system prompt for the ggai agent
#'
#' Intentionally short. The bulk of the agent's guidance lives in Skills under
#' `inst/skills/`, loaded on demand via aisdk's `load_skill` tool.
#'
#' @return Character scalar.
#' @export
ggai_system_prompt <- function() {
  paste(
    "You are ggai, an agent that produces scientific figures.",
    "",
    "Tools you can call:",
    "- `ggai_execute_r(code, engine_hint?)` -- run R code that returns a figure object (ggplot, grob) or draws with base graphics. The result is captured as an artifact and stashed in your session state.",
    "- `ggai_validate_artifact()` -- validate the most recent artifact. Returns status (ok/warning/error) plus diagnostic messages.",
    "- `ggai_save_artifact(output_dir, prefix?, overwrite?)` -- persist the most recent artifact (code + rendered file + manifest) to disk.",
    "- `load_skill`, `list_skill_resources`, `read_skill_resource`, `execute_skill_script` -- load domain knowledge from the ggai skill library *before* deciding how to act.",
    "",
    "Decision flow:",
    "1. If you're not sure what kind of figure the user wants, list available skills and load the most relevant one before writing code.",
    "2. Write code whose *last value* is the figure object (a ggplot or grob). For base graphics, just draw to device.",
    "3. Run `ggai_validate_artifact`. If it errors, fix the code and re-execute.",
    "4. Save the artifact to the requested output directory (or `tempdir()` if unspecified).",
    "5. In your final reply, briefly describe what was produced and reference the saved paths.",
    "",
    "Conventions:",
    "- Prefer ggplot for tabular data visualization. Reach for ComplexHeatmap, circlize, ggraph, base graphics, etc. only when the task calls for them (load the engine-selection skill if unsure).",
    "- Reproducibility matters: write code that runs from a clean session -- load packages explicitly, don't depend on hidden state.",
    "- When validation reports warnings (not errors), report them in your final reply but do not loop indefinitely retrying.",
    sep = "\n"
  )
}

#' Create a ggai agent
#'
#' Configures an `aisdk::Agent` for scientific figure work: wires up the three
#' verb tools, points skill discovery at `inst/skills/` of the installed
#' package, applies a short domain system prompt, and selects the ggai
#' default language model.
#'
#' @param model Optional language model identifier. Defaults to the ggai
#'   default returned by `ggai_default_models()$language`.
#' @param skills Optional override for the skill search path. Defaults to
#'   `system.file("skills", package = "ggai")` (no skills are loaded when the
#'   directory does not exist yet -- agent runs with verb tools only).
#' @param extra_tools Optional list of additional `Tool` objects to append.
#' @param state Optional shared state environment for the verb tools.
#'
#' @return An `aisdk::Agent` object. The shared state environment is attached
#'   as `attr(agent, "ggai_state")` for post-run artifact retrieval.
#' @export
ggai_create_agent <- function(model = NULL,
                              skills = NULL,
                              extra_tools = NULL,
                              state = NULL) {
  state <- state %||% ggai_tool_state()
  verb_tools <- ggai_create_verb_tools(state = state)

  all_tools <- c(unname(verb_tools), as.list(extra_tools %||% list()))

  skills_path <- skills %||% system.file("skills", package = "ggai")
  skills_arg <- if (is.character(skills_path) &&
                    nzchar(skills_path) &&
                    dir.exists(skills_path)) {
    skills_path
  } else {
    NULL
  }

  create_agent <- ggai_aisdk("create_agent")
  agent <- create_agent(
    name = "ggai",
    description = "Scientific figure agent: composes Layer-2 R primitives via Skills to produce reproducible figures across ggplot, grid, base, and image-model engines.",
    system_prompt = ggai_system_prompt(),
    tools = all_tools,
    skills = skills_arg,
    model = model %||% ggai_default_models()$language
  )

  attr(agent, "ggai_state") <- state
  agent
}

#' Run a ggai agent on a goal
#'
#' Thin wrapper around `Agent$run()` that surfaces the produced artifact in
#' the returned result.
#'
#' @param agent An aisdk `Agent` (e.g. from `ggai_create_agent()`).
#' @param goal Character scalar describing the figure task.
#' @param session Optional aisdk `ChatSession` for shared state across calls.
#' @param model Optional model override.
#' @param max_steps Maximum ReAct loop iterations. Default `10`.
#' @param ... Passed through to `Agent$run()`.
#'
#' @return A list with the aisdk result and the produced artifact:
#'   \itemize{
#'     \item `result` -- the value returned by `agent$run()`.
#'     \item `artifact` -- the most-recent `ggai_artifact` from the shared state, or `NULL` if the agent didn't produce one.
#'     \item `artifacts` -- all artifacts produced this run, indexed by id.
#'   }
#' @export
ggai_run_agent <- function(agent,
                           goal,
                           session = NULL,
                           model = NULL,
                           max_steps = 10L,
                           ...) {
  if (is.null(agent) || !inherits(agent, "Agent")) {
    rlang::abort("`agent` must be an aisdk Agent (e.g. from `ggai_create_agent()`).")
  }
  if (!is.character(goal) || length(goal) != 1L || !nzchar(goal)) {
    rlang::abort("`goal` must be a single non-empty character string.")
  }

  state <- attr(agent, "ggai_state")
  if (!is.null(state)) {
    state$last_artifact <- NULL
    state$artifacts <- list()
  }

  result <- agent$run(
    task = goal,
    session = session,
    model = model,
    max_steps = max_steps,
    ...
  )

  list(
    result = result,
    artifact = if (is.null(state)) NULL else state$last_artifact,
    artifacts = if (is.null(state)) list() else state$artifacts
  )
}
