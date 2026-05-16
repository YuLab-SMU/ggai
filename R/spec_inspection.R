new_compiled_spec <- function(spec, kind, instruction = NULL, context = list(), meta = list()) {
  structure(
    list(
      kind = kind,
      instruction = instruction,
      context = context,
      spec = spec,
      meta = meta
    ),
    class = c("ggai_compiled_spec", paste0("ggai_", kind, "_compiled"))
  )
}

plot_compiled_specs <- function(plot) {
  attr(plot, "ggai_compiled_specs") %||% list()
}

plot_base_plot <- function(plot) {
  attr(plot, "ggai_base_plot") %||% plot
}

record_compiled_spec <- function(plot, compiled) {
  history <- plot_compiled_specs(plot)
  compiled$meta <- utils::modifyList(
    list(
      version = length(history) + 1L,
      created_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    ),
    compiled$meta %||% list()
  )
  history[[length(history) + 1]] <- compiled
  attr(plot, "ggai_compiled_specs") <- history
  if (is.null(attr(plot, "ggai_base_plot"))) {
    attr(plot, "ggai_base_plot") <- plot
  }
  plot
}

latest_compiled_spec <- function(plot, index = NULL) {
  history <- plot_compiled_specs(plot)
  if (!length(history)) {
    return(NULL)
  }

  if (is.null(index)) {
    return(history[[length(history)]])
  }

  history[[index]]
}

compile_ggai_request <- function(x, plot = NULL, model = NULL) {
  if (inherits(x, "ggai_compiled_spec")) {
    return(x)
  }

  if (!inherits(x, "ggai_layer_request")) {
    rlang::abort("`x` must be a `ggai_layer_request`, compiled spec, or ggplot object.")
  }

  if (identical(x$target, "diagram") || identical(attr(plot, "ggai_canvas"), "diagram")) {
    spec <- compile_diagram_spec(
      instruction = x$instruction,
      scene_context = attr(plot, "ggai_canvas_spec") %||% list(),
      model = model %||% x$model
    )
    return(new_compiled_spec(
      spec = spec,
      kind = "diagram",
      instruction = x$instruction,
      context = attr(plot, "ggai_canvas_spec") %||% list()
    ))
  }

  rlang::abort(c(
    "Layer requests cannot be inspected or rendered without execution.",
    i = "Materialize the request first via `p + geom_ai(\"...\")` or `ggai(\"...\")`, then call `inspect_spec()` / `as_code()` on the resulting plot or session."
  ))
}

spec_list_to_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

indent_lines <- function(x, n = 2) {
  pad <- paste(rep(" ", n), collapse = "")
  paste0(pad, x)
}

multiline_call <- function(fun, args, indent = 2) {
  if (!length(args)) {
    return(paste0(fun, "()"))
  }

  inner <- paste(indent_lines(args, n = indent), collapse = ",\n")
  paste0(fun, "(\n", inner, "\n)")
}

recursive_modify_list <- function(x, updates) {
  if (is.null(updates)) {
    return(x)
  }
  if (!is.list(x) || !is.list(updates)) {
    return(updates)
  }

  out <- x
  nms <- names(updates)

  if (is.null(nms)) {
    for (i in seq_along(updates)) {
      out[[i]] <- recursive_modify_list(out[[i]], updates[[i]])
    }
    return(out)
  }

  for (i in seq_along(updates)) {
    nm <- nms[[i]]
    if (is.null(nm) || !nzchar(nm)) {
      out[[i]] <- recursive_modify_list(out[[i]], updates[[i]])
    } else {
      out[[nm]] <- recursive_modify_list(out[[nm]], updates[[i]])
    }
  }
  out
}

#' Inspect a compiled ggai spec
#'
#' @param x A compiled spec, `geom_ai()` request, or ggplot object with recorded ggai history.
#' @param ... Passed to methods.
#'
#' @export
inspect_spec <- function(x, ...) {
  UseMethod("inspect_spec")
}

#' @param plot Optional ggplot object used to compile a lazy request.
#' @param raw If `TRUE`, return the raw spec body rather than a summary.
#' @param model Optional model override when compiling a lazy request.
#'
#' @export
inspect_spec.default <- function(x, plot = NULL, raw = FALSE, model = NULL, ...) {
  compiled <- compile_ggai_request(x, plot = plot, model = model)
  inspect_spec(compiled, raw = raw, ...)
}

#' @param raw If `TRUE`, return the raw spec body.
#'
#' @export
inspect_spec.ggai_compiled_spec <- function(x, raw = FALSE, ...) {
  if (isTRUE(raw)) {
    return(x$spec)
  }

  spec <- x$spec
  summary <- list(
    kind = x$kind,
    instruction = x$instruction,
    meta = x$meta %||% list(),
    warnings = spec$warnings %||% list()
  )

  if (identical(x$kind, "layer")) {
    summary$layer_count <- length(spec$layers %||% list())
    summary$annotation_count <- length(spec$annotations %||% list())
    summary$geoms <- vapply(spec$layers %||% list(), function(layer) layer$geom %||% "", character(1))
  }

  if (identical(x$kind, "r_code")) {
    summary$code_lines <- length(strsplit(spec$code %||% "", "\n", fixed = TRUE)[[1]])
  }

  if (identical(x$kind, "diagram")) {
    summary$node_count <- length(spec$nodes %||% list())
    summary$edge_count <- length(spec$edges %||% list())
    summary$node_kinds <- vapply(spec$nodes %||% list(), function(node) node$kind %||% "", character(1))
  }

  summary
}

#' @param index Optional history index; defaults to the latest compiled spec on the plot.
#' @param raw If `TRUE`, return the raw spec body.
#'
#' @export
inspect_spec.ggplot <- function(x, index = NULL, raw = FALSE, ...) {
  compiled <- latest_compiled_spec(x, index = index)
  if (is.null(compiled)) {
    rlang::abort("No compiled ggai specs are attached to this plot.")
  }

  inspect_spec(compiled, raw = raw, ...)
}

mapping_to_code <- function(mapping) {
  if (is.null(mapping) || !length(mapping)) {
    return(NULL)
  }

  parts <- paste0(names(mapping), " = ", unlist(mapping, use.names = FALSE))
  multiline_call("ggplot2::aes", parts, indent = 4)
}

scalar_code <- function(x) {
  paste(deparse(x), collapse = "")
}

named_args_to_code <- function(x) {
  if (is.null(x) || !length(x)) {
    return(character(0))
  }

  mapply(
    function(name, value) {
      paste0(name, " = ", scalar_code(value))
    },
    names(x),
    x,
    USE.NAMES = FALSE,
    SIMPLIFY = TRUE
  )
}

layer_to_code <- function(layer) {
  args <- character(0)

  mapping_code <- mapping_to_code(layer$mapping)
  if (!is.null(mapping_code)) {
    args <- c(args, paste0("mapping = ", mapping_code))
  }
  if (!is.null(layer$data)) {
    args <- c(args, paste0("data = ", scalar_code(layer$data)))
  }
  if (!is.null(layer$inherit_aes)) {
    args <- c(args, paste0("inherit.aes = ", scalar_code(isTRUE(layer$inherit_aes))))
  }
  args <- c(args, named_args_to_code(layer$params %||% list()))

  multiline_call(paste0("ggplot2::geom_", layer$geom), args, indent = 4)
}

layer_spec_to_code <- function(compiled) {
  layer_codes <- vapply(compiled$spec$layers %||% list(), layer_to_code, character(1))
  if (!length(layer_codes)) {
    layer_codes <- "NULL"
  }
  lines <- c(
    paste0("# Instruction: ", compiled$instruction),
    "p +",
    paste0("  ", paste(layer_codes, collapse = " +\n  "))
  )
  paste(lines, collapse = "\n")
}

code_spec_to_code <- function(compiled) {
  paste(
    paste0("# Instruction: ", compiled$instruction),
    compiled$spec$code %||% "",
    sep = "\n"
  )
}

diagram_spec_to_code <- function(compiled) {
  canvas <- compiled$spec$canvas %||% list(width = 10, height = 6, background = "white")
  spec_code <- paste(utils::capture.output(dput(compiled$spec)), collapse = "\n")

  paste(
    paste0("# Instruction: ", compiled$instruction),
    paste0("spec <- ", spec_code),
    paste0(
      "p <- ggai::ggdiagram(width = ", scalar_code(canvas$width),
      ", height = ", scalar_code(canvas$height),
      ", background = ", scalar_code(canvas$background), ")"
    ),
    "ggai::add_diagram_spec(p, spec)",
    sep = "\n"
  )
}

#' Export a ggai result as R code
#'
#' @param x A compiled spec, `geom_ai()` request, or ggplot object with recorded ggai history.
#' @param ... Passed to methods.
#'
#' @export
as_code <- function(x, ...) {
  UseMethod("as_code")
}

#' @param plot Optional ggplot object used to compile a lazy request.
#' @param model Optional model override when compiling a lazy request.
#'
#' @export
as_code.default <- function(x, plot = NULL, model = NULL, ...) {
  compiled <- compile_ggai_request(x, plot = plot, model = model)
  as_code(compiled, ...)
}

#' @export
as_code.ggai_compiled_spec <- function(x, ...) {
  if (identical(x$kind, "diagram")) {
    return(diagram_spec_to_code(x))
  }
  if (identical(x$kind, "r_code")) {
    return(code_spec_to_code(x))
  }

  rlang::abort(paste0("`as_code()` is not supported for compiled specs of kind ", x$kind %||% "<unknown>", "."))
}

#' @param index Optional history index; defaults to the latest compiled spec on the plot.
#'
#' @export
as_code.ggplot <- function(x, index = NULL, ...) {
  compiled <- latest_compiled_spec(x, index = index)
  if (is.null(compiled)) {
    rlang::abort("No compiled ggai specs are attached to this plot.")
  }

  as_code(compiled, ...)
}

#' List versioned ggai spec history
#'
#' @param plot A ggplot object or session-like object with ggai history.
#' @param ... Passed to methods.
#'
#' @return A data frame summarizing recorded compiled specs.
#' @export
spec_history <- function(plot, ...) {
  UseMethod("spec_history")
}

#' @export
spec_history.default <- function(plot, ...) {
  rlang::abort("`spec_history()` is only available for ggplot objects with ggai history or ggai sessions.")
}

#' Inspect current session context snapshot
#'
#' @param x A `ggai_session`.
#' @param ... Unused.
#'
#' @return A list snapshot of current session context.
#' @export
session_context <- function(x, ...) {
  if (inherits(x, "ggai_session")) {
    return(session_context_snapshot(x))
  }
  UseMethod("session_context")
}

#' @export
session_context.default <- function(x, ...) {
  rlang::abort("`session_context()` is only available for `ggai_session` objects.")
}

#' @export
spec_history.ggplot <- function(plot, ...) {
  history <- plot_compiled_specs(plot)
  if (!length(history)) {
    return(data.frame())
  }

  data.frame(
    version = vapply(history, function(x) (x$meta %||% list())$version %||% NA_integer_, integer(1)),
    kind = vapply(history, function(x) x$kind %||% "", character(1)),
    instruction = vapply(history, function(x) x$instruction %||% "", character(1)),
    created_at = vapply(history, function(x) (x$meta %||% list())$created_at %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

compiled_spec_like <- function(x) {
  inherits(x, "ggai_compiled_spec") || inherits(x, "ggai_layer_request") || inherits(x, "ggplot")
}

normalize_compiled_input <- function(x, plot = NULL, model = NULL) {
  if (inherits(x, "ggplot")) {
    compiled <- latest_compiled_spec(x)
    if (is.null(compiled)) {
      rlang::abort("No compiled ggai specs are attached to this plot.")
    }
    return(list(compiled = compiled, plot = x))
  }

  if (inherits(x, "ggai_compiled_spec")) {
    return(list(compiled = x, plot = plot))
  }

  list(compiled = compile_ggai_request(x, plot = plot, model = model), plot = plot)
}

render_spec_compiled <- function(compiled, plot = NULL, data = NULL) {
  if (identical(compiled$kind, "diagram")) {
    base_plot <- if (inherits(plot, "ggplot")) {
      plot_base_plot(plot)
    } else {
      canvas <- compiled$spec$canvas %||% list(width = 10, height = 6, background = "white")
      ggdiagram(width = canvas$width, height = canvas$height, background = canvas$background)
    }
    out <- add_diagram_spec(base_plot, compiled$spec)
    return(record_compiled_spec(out, compiled))
  }

  if (identical(compiled$kind, "r_code")) {
    return(ggai_render_code_compiled(compiled, plot = plot, data = data))
  }

  rlang::abort(c(
    "render_spec() no longer supports raw layer specs.",
    i = "Layer requests are now produced and materialized by the agent runtime; re-run via `ggai()`, `gg_edit()`, or `p + geom_ai(\"...\")` to obtain a ggplot.",
    i = paste0("Got compiled spec of kind: ", compiled$kind %||% "<unknown>", ".")
  ))
}

#' Render a compiled ggai spec back into a plot
#'
#' @param x A compiled spec, lazy request, or plot with stored ggai history.
#' @param plot Optional base plot used when rendering a request or compiled spec.
#' @param model Optional model override when compiling a lazy request.
#' @param data Optional data override for layer specs.
#' @param ... Unused.
#'
#' @return A ggplot object.
#' @export
render_spec <- function(x, plot = NULL, model = NULL, data = NULL, ...) {
  norm <- normalize_compiled_input(x, plot = plot, model = model)
  render_spec_compiled(norm$compiled, plot = norm$plot, data = data)
}

#' Edit a compiled ggai spec
#'
#' @param x A compiled spec, lazy request, or plot with stored ggai history.
#' @param edit A function taking a spec list and returning a modified spec, or a named patch list.
#' @param ... Passed to methods.
#'
#' @export
edit_spec <- function(x, edit, ...) {
  UseMethod("edit_spec")
}

apply_spec_edit <- function(spec, edit) {
  if (is.function(edit)) {
    return(edit(spec))
  }
  if (is.list(edit)) {
    return(recursive_modify_list(spec, edit))
  }

  rlang::abort("`edit` must be a function or named patch list.")
}

#' @param plot Optional base plot used when compiling a lazy request.
#' @param model Optional model override when compiling a lazy request.
#' @param render If `TRUE`, render back to a plot instead of returning a compiled spec.
#' @param data Optional data override for layer specs.
#'
#' @export
edit_spec.default <- function(x, edit, plot = NULL, model = NULL, render = FALSE, data = NULL, ...) {
  norm <- normalize_compiled_input(x, plot = plot, model = model)
  updated <- new_compiled_spec(
    spec = apply_spec_edit(norm$compiled$spec, edit),
    kind = norm$compiled$kind,
    instruction = norm$compiled$instruction,
    context = norm$compiled$context
  )

  if (isTRUE(render)) {
    return(render_spec_compiled(updated, plot = norm$plot, data = data))
  }

  updated
}

#' @param render If `TRUE`, render back to a plot instead of returning a compiled spec.
#' @param data Optional data override for layer specs.
#'
#' @export
edit_spec.ggai_compiled_spec <- function(x, edit, render = FALSE, data = NULL, ...) {
  updated <- new_compiled_spec(
    spec = apply_spec_edit(x$spec, edit),
    kind = x$kind,
    instruction = x$instruction,
    context = x$context
  )

  if (isTRUE(render)) {
    return(render_spec_compiled(updated, data = data))
  }

  updated
}

#' @param index Optional history index; defaults to the latest compiled spec on the plot.
#' @param render If `TRUE`, return a plot. Defaults to `TRUE` for ggplot methods.
#' @param data Optional data override for layer specs.
#'
#' @export
edit_spec.ggplot <- function(x, edit, index = NULL, render = TRUE, data = NULL, ...) {
  compiled <- latest_compiled_spec(x, index = index)
  if (is.null(compiled)) {
    rlang::abort("No compiled ggai specs are attached to this plot.")
  }

  updated <- new_compiled_spec(
    spec = apply_spec_edit(compiled$spec, edit),
    kind = compiled$kind,
    instruction = compiled$instruction,
    context = compiled$context
  )

  if (isTRUE(render)) {
    return(render_spec_compiled(updated, plot = x, data = data))
  }

  updated
}

#' Update a compiled ggai spec using a recursive patch list
#'
#' @param x A compiled spec, lazy request, or plot with stored ggai history.
#' @param updates A named recursive patch list.
#' @param ... Passed to methods.
#'
#' @export
update_spec <- function(x, updates, ...) {
  UseMethod("update_spec")
}

#' @export
update_spec.default <- function(x, updates, ...) {
  edit_spec(x, edit = updates, ...)
}

#' @export
update_spec.ggai_compiled_spec <- function(x, updates, ...) {
  edit_spec.ggai_compiled_spec(x, edit = updates, ...)
}

#' @export
update_spec.ggplot <- function(x, updates, ...) {
  edit_spec.ggplot(x, edit = updates, ...)
}
