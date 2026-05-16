new_session_entry <- function(instruction,
                              compiled_spec,
                              plot,
                              code,
                              edit_mode = "compile",
                              parent_turn = NULL,
                              turn_context = list()) {
  new_ggai_turn(
    instruction = instruction,
    compiled_spec = compiled_spec,
    plot = plot,
    code = code,
    edit_mode = edit_mode,
    parent_turn = parent_turn,
    turn_context = turn_context
  )
}

new_ggai_session <- function(base_plot,
                             history = list(),
                             history_index = 0L,
                             meta = list(),
                             state = NULL) {
  structure(
    list(
      base_plot = base_plot,
      history = history,
      history_index = as.integer(history_index),
      meta = meta,
      state = utils::modifyList(ggai_session_defaults(), state %||% list())
    ),
    class = "ggai_session"
  )
}

session_current_entry <- function(session) {
  idx <- session$history_index %||% 0L
  if (idx < 1L || !length(session$history)) {
    return(NULL)
  }
  session$history[[idx]]
}

session_current_plot <- function(session) {
  entry <- session_current_entry(session)
  if (is.null(entry)) {
    return(session$base_plot)
  }
  entry$plot
}

session_current_compiled <- function(session) {
  entry <- session_current_entry(session)
  if (is.null(entry)) {
    return(NULL)
  }
  entry$compiled_spec
}

session_append_entry <- function(session, entry) {
  idx <- session$history_index %||% 0L
  if (length(session$history) > idx) {
    session$history <- session$history[seq_len(idx)]
  }
  session$history[[idx + 1L]] <- entry
  session$history_index <- idx + 1L
  session
}

reconstruct_session_history <- function(base_plot, history) {
  if (!length(history)) {
    return(list(entries = list(), index = 0L))
  }

  entries <- vector("list", length(history))
  for (i in seq_along(history)) {
    compiled <- history[[i]]
    plot_i <- if (i == length(history)) {
      render_spec_compiled(compiled, plot = base_plot)
    } else {
      render_spec_compiled(compiled, plot = base_plot)
    }
    entries[[i]] <- new_session_entry(
      instruction = compiled$instruction %||% "",
      compiled_spec = compiled,
      plot = plot_i,
      code = as_code(compiled),
      edit_mode = compiled$meta$edit_mode %||% "compile"
    )
  }

  list(entries = entries, index = length(entries))
}

#' Start a stateful ggai editing session
#'
#' @param plot A base ggplot object.
#'
#' @return A `ggai_session` object.
#' @export
start_ggai_session <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    rlang::abort("`plot` must be a ggplot object.")
  }

  base_plot <- plot_base_plot(plot)
  compiled_history <- plot_compiled_specs(plot)
  rebuilt <- reconstruct_session_history(base_plot, compiled_history)

  new_ggai_session(
    base_plot = base_plot,
    history = rebuilt$entries,
    history_index = rebuilt$index,
    meta = list(created_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
  )
}

merge_layer_compiled_specs <- function(current, new, instruction = NULL, edit_mode = "append_compile") {
  new_compiled_spec(
    spec = list(
      intent = current$spec$intent %||% new$spec$intent %||% "annotate",
      action = new$spec$action %||% current$spec$action %||% "annotate",
      target_layer = current$spec$target_layer %||% new$spec$target_layer %||% "plot",
      layers = c(current$spec$layers %||% list(), new$spec$layers %||% list()),
      annotations = c(current$spec$annotations %||% list(), new$spec$annotations %||% list()),
      plot_ops = c(current$spec$plot_ops %||% list(), new$spec$plot_ops %||% list()),
      warnings = c(current$spec$warnings %||% list(), new$spec$warnings %||% list())
    ),
    kind = "layer",
    instruction = instruction %||% new$instruction %||% current$instruction,
    context = current$context %||% new$context,
    meta = list(edit_mode = edit_mode)
  )
}

ensure_layer_compiled_spec <- function(x, instruction = NULL, context = list(), model = NULL) {
  if (inherits(x, "ggai_compiled_spec")) {
    return(x)
  }

  new_compiled_spec(
    spec = x,
    kind = "layer",
    instruction = instruction,
    context = context,
    meta = list(model = model)
  )
}

find_layers_by_geom <- function(spec, geom) {
  which(vapply(spec$layers %||% list(), function(layer) identical(layer$geom, geom), logical(1)))
}

lighten_colour <- function(colour, amount = 0.25) {
  rgb <- tryCatch(grDevices::col2rgb(colour) / 255, error = function(...) NULL)
  if (is.null(rgb)) {
    return(colour)
  }
  mixed <- rgb + (1 - rgb) * amount
  grDevices::rgb(mixed[1, 1], mixed[2, 1], mixed[3, 1])
}

apply_rect_outline_patch <- function(spec) {
  idx <- find_layers_by_geom(spec, "rect")
  if (!length(idx)) {
    return(NULL)
  }
  i <- idx[[1]]
  rect <- spec$layers[[i]]
  border <- rect$params$colour %||% rect$params$fill %||% "#4DAF4A"
  rect$params$fill <- NA
  rect$params$colour <- border
  rect$params$linewidth <- rect$params$linewidth %||% 1
  rect$params$alpha <- NULL
  spec$layers[[i]] <- rect
  spec
}

apply_colour_patch <- function(spec, instruction) {
  colour <- NULL
  if (grepl("green", instruction, ignore.case = TRUE)) colour <- "#4DAF4A"
  if (grepl("red", instruction, ignore.case = TRUE)) colour <- "#E41A1C"
  if (grepl("blue", instruction, ignore.case = TRUE)) colour <- "#377EB8"
  if (grepl("teal", instruction, ignore.case = TRUE)) colour <- "#0F766E"
  if (is.null(colour)) {
    return(NULL)
  }

  idx <- find_layers_by_geom(spec, "text")
  if (!length(idx)) {
    idx <- find_layers_by_geom(spec, "rect")
  }
  if (!length(idx)) {
    return(NULL)
  }

  i <- idx[[1]]
  layer <- spec$layers[[i]]
  layer$params$colour <- colour
  if (grepl("less saturated|lighter", instruction, ignore.case = TRUE)) {
    layer$params$colour <- lighten_colour(colour, amount = 0.35)
  }
  spec$layers[[i]] <- layer
  spec
}

apply_text_size_patch <- function(spec, instruction) {
  idx <- find_layers_by_geom(spec, "text")
  if (!length(idx)) {
    return(NULL)
  }
  factor <- if (grepl("smaller", instruction, ignore.case = TRUE)) 0.8 else if (grepl("larger|bigger", instruction, ignore.case = TRUE)) 1.2 else NULL
  if (is.null(factor)) {
    return(NULL)
  }

  for (i in idx) {
    current <- spec$layers[[i]]$params$size %||% 4
    spec$layers[[i]]$params$size <- current * factor
  }
  spec
}

apply_text_position_patch <- function(spec, instruction) {
  idx <- find_layers_by_geom(spec, "text")
  if (!length(idx)) {
    return(NULL)
  }

  delta_y <- 0
  delta_x <- 0
  if (grepl("up|upward|higher", instruction, ignore.case = TRUE)) delta_y <- 0.8
  if (grepl("down|lower", instruction, ignore.case = TRUE)) delta_y <- -0.8
  if (grepl("left", instruction, ignore.case = TRUE)) delta_x <- -0.2
  if (grepl("right", instruction, ignore.case = TRUE)) delta_x <- 0.2
  if (delta_x == 0 && delta_y == 0) {
    return(NULL)
  }

  for (i in idx) {
    layer <- spec$layers[[i]]
    if (!is.null(layer$mapping$y) && grepl("^[0-9.]+$", as.character(layer$mapping$y))) {
      layer$mapping$y <- as.character(as.numeric(layer$mapping$y) + delta_y)
    } else {
      layer$params$nudge_y <- (layer$params$nudge_y %||% 0) + delta_y
    }
    if (!is.null(layer$mapping$x) && grepl("^[0-9.]+$", as.character(layer$mapping$x))) {
      layer$mapping$x <- as.character(as.numeric(layer$mapping$x) + delta_x)
    } else if (delta_x != 0) {
      layer$params$nudge_x <- (layer$params$nudge_x %||% 0) + delta_x
    }
    spec$layers[[i]] <- layer
  }
  spec
}

apply_alpha_patch <- function(spec, instruction) {
  idx <- find_layers_by_geom(spec, "rect")
  if (!length(idx)) {
    return(NULL)
  }
  if (!grepl("transparent|alpha|opaque", instruction, ignore.case = TRUE)) {
    return(NULL)
  }

  i <- idx[[1]]
  current <- spec$layers[[i]]$params$alpha %||% 0.1
  if (grepl("more transparent|less opaque", instruction, ignore.case = TRUE)) {
    spec$layers[[i]]$params$alpha <- max(0.01, current * 0.5)
  } else if (grepl("less transparent|more opaque", instruction, ignore.case = TRUE)) {
    spec$layers[[i]]$params$alpha <- min(1, current * 1.5)
  }
  spec
}

apply_linewidth_patch <- function(spec, instruction) {
  idx <- find_layers_by_geom(spec, "rect")
  if (!length(idx)) {
    idx <- find_layers_by_geom(spec, "point")
  }
  if (!length(idx) || !grepl("thicker|thinner|stroke|line width|linewidth", instruction, ignore.case = TRUE)) {
    return(NULL)
  }

  i <- idx[[1]]
  layer <- spec$layers[[i]]
  field <- if (!is.null(layer$params$stroke) || identical(layer$geom, "point")) "stroke" else "linewidth"
  current <- layer$params[[field]] %||% 1
  if (grepl("thicker|increase", instruction, ignore.case = TRUE)) {
    layer$params[[field]] <- current + 0.5
  } else if (grepl("thinner|decrease", instruction, ignore.case = TRUE)) {
    layer$params[[field]] <- max(0.2, current - 0.5)
  }
  spec$layers[[i]] <- layer
  spec
}

deterministic_patch_spec <- function(compiled, instruction) {
  if (!identical(compiled$kind, "layer")) {
    return(NULL)
  }
  spec <- compiled$spec
  changed <- FALSE

  patchers <- list(
    function(x) if (grepl("outline only|outline instead of fill|not filled|no fill", instruction, ignore.case = TRUE)) apply_rect_outline_patch(x) else NULL,
    function(x) apply_colour_patch(x, instruction),
    function(x) apply_alpha_patch(x, instruction),
    function(x) apply_linewidth_patch(x, instruction),
    function(x) apply_text_size_patch(x, instruction),
    function(x) apply_text_position_patch(x, instruction)
  )

  for (patcher in patchers) {
    updated <- patcher(spec)
    if (!is.null(updated)) {
      spec <- updated
      changed <- TRUE
    }
  }

  if (!changed) {
    return(NULL)
  }

  new_compiled_spec(
    spec = spec,
    kind = compiled$kind,
    instruction = instruction,
    context = compiled$context,
    meta = utils::modifyList(compiled$meta %||% list(), list(edit_mode = "deterministic_patch"))
  )
}

ggai_edit_runtime_trace <- function(instruction,
                                    edit_mode,
                                    render_result,
                                    validation,
                                    turn = NULL,
                                    runtime = "gg_edit",
                                    task_prefix = "session_edit") {
  validation_status <- validation$status %||% "unknown"
  repairs <- render_result$details$repairs %||% list()
  had_repairs <- length(repairs) > 0L
  status <- if (identical(validation_status, "ok") && had_repairs) {
    "completed_with_repair"
  } else if (identical(validation_status, "ok")) {
    "completed"
  } else {
    validation_status
  }
  artifact_status <- if (identical(validation_status, "ok") && had_repairs) status else validation_status
  react_steps <- render_result$details$react_steps %||% list()
  new_ggai_agent_trace(
    task_id = paste0(task_prefix, "_", turn %||% "pending"),
    status = status,
    steps = c(
      list(
        ggai_agent_trace_step("compile_instruction", details = list(instruction = instruction, edit_mode = edit_mode)),
        ggai_agent_trace_step("render_artifact", status = render_result$status %||% "done", details = render_result$details %||% list())
      ),
      react_steps,
      list(
        ggai_agent_trace_step("validate_plot", status = validation_status, details = validation),
        ggai_agent_trace_step("record_session_turn")
      )
    ),
    tool_calls = list(
      list(name = "ggai_layer_compilation", status = "ok"),
      list(name = "ggai_plot_render", status = render_result$status %||% "ok"),
      list(name = "ggai_plot_validation", status = validation_status)
    ),
    observations = list(
      list(type = "edit_instruction", value = instruction),
      list(type = "final_validation", value = validation),
      list(type = "runtime_react_loop", value = repairs)
    ),
    artifacts = list(
      list(kind = "ggplot_session", turn = turn %||% NA_integer_, status = artifact_status)
    ),
    meta = list(runtime = runtime, bounded = TRUE),
    completed_at = ggai_contract_timestamp()
  )
}

ggai_strip_ansi <- function(x) {
  if (!is.character(x)) {
    return(x)
  }
  gsub("\033\\[[0-9;]*m", "", x)
}

ggai_discrete_scale_validation_error <- function(validation) {
  message <- validation$message %||% ""
  identical(validation$status %||% NULL, "error") &&
    grepl("Continuous value supplied to a discrete scale", message, fixed = TRUE)
}

ggai_insufficient_manual_scale_validation_error <- function(validation) {
  message <- validation$message %||% ""
  identical(validation$status %||% NULL, "error") &&
    grepl("Insufficient values in manual scale", message, fixed = TRUE)
}

ggai_manual_scale_aesthetics <- function(spec) {
  ops <- spec$plot_ops %||% list()
  aesthetics <- character()
  for (op in ops) {
    op_name <- op$op %||% ""
    if (op_name %in% c("scale_colour", "scale_color")) {
      aesthetics <- c(aesthetics, "colour", "color")
    } else if (identical(op_name, "scale_fill")) {
      aesthetics <- c(aesthetics, "fill")
    }
  }
  unique(aesthetics)
}

ggai_manual_scale_op <- function(op) {
  (op$op %||% "") %in% c("scale_colour", "scale_color", "scale_fill")
}

ggai_manual_scale_has_values <- function(op) {
  values <- op$params$values %||% NULL
  !is.null(values) && length(values) > 0L
}

ggai_factor_mapping_if_numeric <- function(value, data) {
  if (!is.character(value) || length(value) != 1L || !nzchar(value) || !is.data.frame(data)) {
    return(value)
  }
  if (grepl("^factor\\s*\\(", value)) {
    return(value)
  }

  column <- gsub("^`|`$", "", value)
  if (!column %in% names(data) || !is.numeric(data[[column]])) {
    return(value)
  }

  paste0("factor(", column, ")")
}

ggai_factor_scale_aesthetics <- function(compiled, aesthetics, data = NULL) {
  repaired <- compiled
  changed <- FALSE
  layers <- repaired$spec$layers %||% list()
  for (i in seq_along(layers)) {
    mapping <- layers[[i]]$mapping %||% list()
    for (aesthetic in aesthetics) {
      if (is.null(mapping[[aesthetic]])) {
        next
      }
      updated <- ggai_factor_mapping_if_numeric(mapping[[aesthetic]], data)
      if (!identical(updated, mapping[[aesthetic]])) {
        mapping[[aesthetic]] <- updated
        changed <- TRUE
      }
    }
    layers[[i]]$mapping <- mapping
  }

  if (!changed) {
    return(compiled)
  }
  repaired$spec$layers <- layers
  repaired
}

ggai_repair_discrete_scale_mapping <- function(compiled, data = NULL, validation = list()) {
  if (!ggai_discrete_scale_validation_error(validation)) {
    return(NULL)
  }

  aesthetics <- ggai_manual_scale_aesthetics(compiled$spec)
  if (!length(aesthetics)) {
    return(NULL)
  }

  repaired <- ggai_factor_scale_aesthetics(compiled, aesthetics = aesthetics, data = data)
  if (identical(repaired, compiled)) {
    return(NULL)
  }

  repaired$meta <- utils::modifyList(
    repaired$meta %||% list(),
    list(runtime_repair = "factorize_numeric_manual_scale_mapping")
  )
  repaired
}

ggai_repair_invalid_manual_scale <- function(compiled, data = NULL, validation = list()) {
  if (!identical(validation$status %||% NULL, "error")) {
    return(NULL)
  }

  ops <- compiled$spec$plot_ops %||% list()
  if (!length(ops)) {
    return(NULL)
  }

  has_empty_manual_scale <- any(vapply(
    ops,
    function(op) ggai_manual_scale_op(op) && !ggai_manual_scale_has_values(op),
    logical(1)
  ))
  if (!has_empty_manual_scale && !ggai_insufficient_manual_scale_validation_error(validation)) {
    return(NULL)
  }

  bad_aesthetics <- character()
  kept_ops <- list()
  changed <- FALSE
  for (op in ops) {
    if (ggai_manual_scale_op(op) && !ggai_manual_scale_has_values(op)) {
      bad_aesthetics <- c(bad_aesthetics, ggai_manual_scale_aesthetics(list(plot_ops = list(op))))
      changed <- TRUE
      next
    }
    kept_ops[[length(kept_ops) + 1L]] <- op
  }

  if (!changed) {
    return(NULL)
  }

  repaired <- compiled
  repaired$spec$plot_ops <- kept_ops
  if (length(bad_aesthetics)) {
    repaired <- ggai_factor_scale_aesthetics(repaired, aesthetics = unique(bad_aesthetics), data = data)
  }
  repaired$meta <- utils::modifyList(
    repaired$meta %||% list(),
    list(runtime_repair = "drop_invalid_manual_scale")
  )
  repaired
}

ggai_render_compiled_once <- function(compiled, base_plot, data = NULL) {
  rendered <- tryCatch(
    render_spec_compiled(compiled, plot = base_plot, data = data),
    error = function(e) e
  )

  if (inherits(rendered, "error")) {
    return(list(
      plot = NULL,
      validation = list(status = "error", message = ggai_strip_ansi(conditionMessage(rendered)), warnings = character()),
      render_result = list(status = "error", details = list(message = ggai_strip_ansi(conditionMessage(rendered))))
    ))
  }

  validation <- ggai_agent_validate_plot(rendered)
  list(
    plot = rendered,
    render_result = list(
      status = if (identical(validation$status %||% NULL, "ok")) "ok" else "error",
      details = list(layer_count = length(rendered$layers %||% list()))
    ),
    validation = validation
  )
}

ggai_select_runtime_repair <- function(compiled, data = NULL, validation = list()) {
  repaired <- ggai_repair_invalid_manual_scale(compiled, data = data, validation = validation)
  repair_action <- "drop_invalid_manual_scale"
  if (is.null(repaired)) {
    repaired <- ggai_repair_discrete_scale_mapping(compiled, data = data, validation = validation)
    repair_action <- "factorize_numeric_manual_scale_mapping"
  }

  if (is.null(repaired)) {
    return(NULL)
  }
  list(action = repair_action, compiled = repaired)
}

ggai_render_edit_artifact <- function(compiled, base_plot, data = NULL, max_attempts = 3L) {
  current <- compiled
  repairs <- list()
  react_steps <- list()

  for (attempt in seq_len(max(1L, as.integer(max_attempts)) + 1L)) {
    result <- ggai_render_compiled_once(current, base_plot = base_plot, data = data)
    validation_status <- result$validation$status %||% "unknown"

    if (identical(validation_status, "ok")) {
      if (length(repairs)) {
        last <- length(repairs)
        repairs[[last]]$repaired <- TRUE
        repairs[[last]]$final_validation <- result$validation
        repairs[[last]]$outcome <- "completed_with_repair"
        repairs[[last]]$degraded <- identical(repairs[[last]]$action, "drop_invalid_manual_scale")
      }
      result$compiled <- current
      result$repairs <- repairs
      result$render_result$details$repairs <- repairs
      result$render_result$details$react_steps <- react_steps
      return(result)
    }

    react_steps[[length(react_steps) + 1L]] <- ggai_agent_trace_step(
      "observe_validation",
      status = validation_status,
      details = list(attempt = attempt, validation = result$validation)
    )

    if (attempt > max_attempts) {
      break
    }

    repair <- ggai_select_runtime_repair(current, data = data, validation = result$validation)
    if (is.null(repair)) {
      if (length(repairs)) {
        repairs[[length(repairs)]]$repaired <- FALSE
        repairs[[length(repairs)]]$final_validation <- result$validation
      }
      break
    }

    repairs[[length(repairs) + 1L]] <- list(
      attempt = attempt,
      action = repair$action,
      observed_validation = result$validation,
      repaired = NA
    )
    react_steps[[length(react_steps) + 1L]] <- ggai_agent_trace_step(
      "repair_artifact",
      status = "attempted",
      details = list(attempt = attempt, action = repair$action)
    )
    current <- repair$compiled
  }

  rlang::abort(c(
    "ggai runtime could not produce a valid plot.",
    i = "The edit was compiled, rendered, and validated before the session was mutated.",
    x = result$validation$message %||% "Plot validation failed."
  ))
}

#' Apply a natural-language edit to a ggai session
#'
#' @param session A `ggai_session`.
#' @param instruction Natural-language edit instruction.
#' @param model Optional model override for fallback additive compilation.
#' @param mode Either `"session"` for structured ggplot edits or `"polish"` to
#'   switch the current session state into the whole-image redraw path.
#' @param image_model Optional image model override used when
#'   `mode = "polish"`.
#' @param registry Optional aisdk provider registry for model-backed agent
#'   edits.
#' @param skills Optional skill names, paths, Skill objects, or inline skill
#'   lists for model-backed agent edits.
#' @param skill_registry Optional aisdk SkillRegistry.
#' @param skill_path Optional path scanned into an aisdk SkillRegistry.
#' @param ... Passed through to [polish_figure()] when `mode = "polish"`.
#'
#' @return Either an updated `ggai_session` or a
#'   `ggai_polished_figure_result`.
#' @export
gg_edit <- function(session,
                    instruction,
                    model = NULL,
                    mode = c("session", "polish"),
                    image_model = NULL,
                    registry = NULL,
                    skills = NULL,
                    skill_registry = NULL,
                    skill_path = NULL,
                    ...) {
  mode <- match.arg(mode)
  if (!inherits(session, "ggai_session")) {
    rlang::abort("`session` must be a ggai_session.")
  }

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = instruction,
      image_model = image_model,
      ...
    ))
  }

  current_compiled <- session_current_compiled(session)
  current_plot <- session_current_plot(session)
  model <- ggai_session_agentic_model(session, model = model)

  if (!ggai_agentic_edit_enabled(model)) {
    rlang::abort(c(
      "ggai session edits require an agentic language model.",
      i = "Pass `model=`, set `options(ggai.language_model=...)`, or set `GGAI_LANGUAGE_MODEL`.",
      x = "The old direct compiler edit path is no longer used for user-facing session edits."
    ))
  }

  artifact <- ggai_agentic_repair_edit(
    compiled = current_compiled,
    base_plot = session$base_plot,
    current_plot = current_plot,
    data = session$base_plot$data,
    instruction = instruction,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path,
    prior_error = NULL
  )
  compiled <- artifact$compiled
  rendered <- artifact$plot
  entry <- new_session_entry(
    instruction = instruction,
    compiled_spec = compiled,
    plot = rendered,
    code = as_code(compiled),
    edit_mode = compiled$meta$edit_mode %||% "compile",
    parent_turn = session$history_index %||% 0L,
    turn_context = list(
      mode = if (is.null(current_compiled)) "initial" else "followup",
      context = session_context_snapshot(session)
    )
  )
  session <- session_append_entry(session, entry)
  session <- session_record_agent_trace(
    session,
    ggai_edit_runtime_trace(
      instruction = instruction,
      edit_mode = compiled$meta$edit_mode %||% "compile",
      render_result = artifact$render_result,
      validation = artifact$validation,
      turn = session$history_index %||% 0L
    )
  )
  session <- session_record_turn_note(
    session,
    type = "edit",
    value = list(
      instruction = instruction,
      edit_mode = compiled$meta$edit_mode %||% "compile",
      model = ggai_language_model(model),
      kind = compiled$kind %||% "layer"
    )
  )
  session <- session_touch_state(session, instruction = instruction)
  session <- session_set_plot_summary(session, plot = rendered)
  session
}

ggai_effective_agentic_model <- function(model = NULL) {
  if (!is.null(model) && ggai_agentic_edit_enabled(model)) {
    return(model)
  }

  default_model <- tryCatch(ggai_default_models()$language, error = function(...) NULL)
  if (!is.null(default_model) && ggai_agentic_edit_enabled(default_model)) {
    return(default_model)
  }

  NULL
}

ggai_session_agentic_model <- function(session, model = NULL) {
  if (!is.null(model)) {
    return(ggai_effective_agentic_model(model))
  }

  notes <- rev(session_turn_notes(session))
  for (note in notes) {
    value <- note$value %||% list()
    note_model <- value$model %||% value$language_model %||% NULL
    if (!is.null(note_model) && ggai_agentic_edit_enabled(note_model)) {
      return(note_model)
    }
  }

  ggai_effective_agentic_model(NULL)
}

#' Undo the last session edit
#'
#' @param session A `ggai_session`.
#'
#' @return The updated `ggai_session`.
#' @export
undo <- function(session) {
  if (!inherits(session, "ggai_session")) {
    rlang::abort("`session` must be a ggai_session.")
  }
  if ((session$history_index %||% 0L) <= 0L) {
    return(session)
  }
  session$history_index <- session$history_index - 1L
  session_touch_state(session)
}
