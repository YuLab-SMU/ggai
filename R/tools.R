# aisdk verb tools that wrap ggai's Layer 2 primitives. These are the only
# tools ggai contributes to the agent surface; everything else (`load_skill`,
# `execute_skill_script`, ...) comes from aisdk directly.

# Internal helpers replacing the ones in (about-to-be-deleted) R/agent_tools.R.

ggai_tool_abort <- function(message) {
  rlang::abort(message, class = "ggai_tool_error")
}

ggai_tool_empty_params <- function() {
  z <- ggai_schema_funs()
  z$z_object(
    noop = z$z_string(
      description = "Ignored. Tool takes no parameters.",
      nullable = TRUE
    )
  )
}

ggai_tool_state <- function() {
  state <- new.env(parent = emptyenv())
  state$last_artifact <- NULL
  state$output_dir <- tempdir()
  state$artifacts <- list()
  state
}

#' Create the ggai verb tools
#'
#' Returns the three tools that ggai contributes to the agent surface,
#' wrapping the Layer 2 primitives `ggai_execute_and_capture()`,
#' `ggai_validate_artifact()`, and `ggai_save_artifact()`. All three share a
#' state environment so the agent can chain
#' `execute_r` -> `validate_artifact` -> `save_artifact` without passing the
#' artifact around by id.
#'
#' @param state Optional state environment. When `NULL`, a fresh one is
#'   created; the same environment can be retrieved later via
#'   `attr(agent, "ggai_state")` after `ggai_create_agent()`.
#'
#' @return A named list of three `Tool` objects.
#' @export
ggai_create_verb_tools <- function(state = NULL) {
  state <- state %||% ggai_tool_state()
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")

  list(
    execute_r = tool(
      name = "ggai_execute_r",
      description = paste(
        "Execute R code that produces a figure. The last value of the code",
        "should be the figure object (a ggplot, a grob, or NULL when the code",
        "draws with base graphics). Engine is auto-detected. The captured",
        "artifact is stored in agent state as `last_artifact` for follow-up",
        "tool calls."
      ),
      parameters = z$z_object(
        code = z$z_string(
          description = "Complete R code that produces a figure. Use \\n for newlines."
        ),
        engine_hint = z$z_string(
          description = "Optional engine override: 'ggplot', 'grid', 'base'.",
          nullable = TRUE
        )
      ),
      execute = function(code, engine_hint = NULL) {
        artifact <- ggai_execute_and_capture(
          code = code,
          engine_hint = engine_hint,
          output_dir = state$output_dir %||% tempdir()
        )
        state$last_artifact <- artifact
        state$artifacts[[artifact$id]] <- artifact

        validation <- ggai_validate_artifact(artifact)
        info <- ggai_inspect_artifact(artifact)

        list(
          artifact_id = artifact$id,
          engine = artifact$engine,
          rendered = artifact$rendered,
          packages_used = artifact$packages,
          validation_status = validation$status,
          validation_messages = validation$messages,
          validation_warnings = validation$warnings,
          summary = info$summary
        )
      }
    ),

    validate_artifact = tool(
      name = "ggai_validate_artifact",
      description = paste(
        "Validate the most recent ggai_artifact (produced by the last",
        "ggai_execute_r call). Returns status (`ok`/`warning`/`error`),",
        "diagnostic messages, and warnings. Never throws -- callers branch on",
        "`status`."
      ),
      parameters = ggai_tool_empty_params(),
      execute = function(noop = NULL) {
        if (is.null(state$last_artifact)) {
          ggai_tool_abort(
            "No artifact in state. Call `ggai_execute_r` first."
          )
        }
        ggai_validate_artifact(state$last_artifact)
      }
    ),

    save_artifact = tool(
      name = "ggai_save_artifact",
      description = paste(
        "Persist the most recent ggai_artifact (reproducer code + rendered",
        "files + manifest) to a directory. Returns the saved paths."
      ),
      parameters = z$z_object(
        output_dir = z$z_string(
          description = "Output directory (created if missing)."
        ),
        prefix = z$z_string(
          description = "Filename prefix. Defaults to the artifact id.",
          nullable = TRUE
        ),
        overwrite = z$z_boolean(
          description = "Overwrite existing files (default FALSE).",
          nullable = TRUE
        )
      ),
      execute = function(output_dir, prefix = NULL, overwrite = FALSE) {
        if (is.null(state$last_artifact)) {
          ggai_tool_abort(
            "No artifact in state. Call `ggai_execute_r` first."
          )
        }
        ggai_save_artifact(
          artifact = state$last_artifact,
          output_dir = output_dir,
          prefix = prefix,
          overwrite = isTRUE(overwrite)
        )
      }
    )
  )
}
