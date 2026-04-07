new_session_entry <- function(instruction,
                              compiled_spec,
                              plot,
                              code,
                              edit_mode = "compile") {
  list(
    instruction = instruction,
    compiled_spec = compiled_spec,
    plot = plot,
    code = code,
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE),
    kind = compiled_spec$kind %||% "layer",
    edit_mode = edit_mode
  )
}

new_ggai_session <- function(base_plot,
                             history = list(),
                             history_index = 0L,
                             meta = list()) {
  structure(
    list(
      base_plot = base_plot,
      history = history,
      history_index = as.integer(history_index),
      meta = meta
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
      warnings = c(current$spec$warnings %||% list(), new$spec$warnings %||% list())
    ),
    kind = "layer",
    instruction = instruction %||% new$instruction %||% current$instruction,
    context = current$context %||% new$context,
    meta = list(edit_mode = edit_mode)
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

#' Apply a natural-language edit to a ggai session
#'
#' @param session A `ggai_session`.
#' @param instruction Natural-language edit instruction.
#' @param model Optional model override for fallback additive compilation.
#'
#' @return An updated `ggai_session`.
#' @export
chat_edit <- function(session, instruction, model = NULL) {
  if (!inherits(session, "ggai_session")) {
    rlang::abort("`session` must be a ggai_session.")
  }

  current_compiled <- session_current_compiled(session)
  current_plot <- session_current_plot(session)

  compiled <- if (is.null(current_compiled)) {
    req <- geom_ai(instruction, model = model, data = current_plot$data)
    compiled <- compile_ggai_request(req, plot = current_plot, model = model)
    compiled$meta <- utils::modifyList(compiled$meta %||% list(), list(edit_mode = "initial_compile"))
    compiled
  } else {
    patched <- deterministic_patch_spec(current_compiled, instruction)
    if (!is.null(patched)) {
      patched
    } else {
      req <- geom_ai(instruction, model = model, data = current_plot$data)
      additive <- compile_ggai_request(req, plot = current_plot, model = model)
      merge_layer_compiled_specs(current_compiled, additive, instruction = instruction, edit_mode = "append_compile")
    }
  }

  rendered <- render_spec_compiled(compiled, plot = session$base_plot, data = session$base_plot$data)
  entry <- new_session_entry(
    instruction = instruction,
    compiled_spec = compiled,
    plot = rendered,
    code = as_code(compiled),
    edit_mode = compiled$meta$edit_mode %||% "compile"
  )
  session_append_entry(session, entry)
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
  session
}
