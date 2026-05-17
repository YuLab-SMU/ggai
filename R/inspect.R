# Engine-aware structural introspection. The agent / Skills use the output to
# decide what to edit, polish, or annotate. Inspection depth varies by engine:
# ggplot gives rich semantic info; base graphics gives almost nothing structured.

#' Inspect a `ggai_artifact`
#'
#' Returns engine-specific structural information about the figure. The shape
#' of the returned list varies by engine; callers should branch on
#' `artifact$engine` or use the common fields documented below.
#'
#' Common fields (present for all engines):
#' \itemize{
#'   \item `engine` — same as `artifact$engine`.
#'   \item `summary` — short character description.
#'   \item `available` — what kinds of inspection are populated for this engine.
#' }
#'
#' Engine-specific fields:
#' \itemize{
#'   \item ggplot / composite — `plot_context`, `layer_summaries`, `layout_regions`, `data_contract`.
#'   \item grid — `tree_summary`, `children_classes`, `n_grobs`.
#'   \item base — `n_operations`, `engine_version`, `r_version`.
#' }
#'
#' @param artifact A `ggai_artifact`.
#'
#' @return A named list.
#' @export
ggai_inspect_artifact <- function(artifact) {
  if (!is_ggai_artifact(artifact)) {
    rlang::abort("`artifact` must be a ggai_artifact.")
  }

  base_info <- list(
    engine = artifact$engine,
    id = artifact$id,
    summary = NA_character_,
    available = character()
  )

  engine_info <- switch(
    artifact$engine,
    ggplot    = inspect_ggplot(artifact$object),
    composite = inspect_ggplot(artifact$object),
    grid      = inspect_grob_tree(artifact$object),
    base      = inspect_recorded(artifact$object),
    list(summary = paste0(
      "No structured inspection available for engine `",
      artifact$engine, "`."
    ))
  )

  utils::modifyList(base_info, engine_info)
}

# ---- engine inspectors ----------------------------------------------------

inspect_ggplot <- function(plot) {
  if (is.null(plot)) {
    return(list(summary = "ggplot object missing (object cache is NULL)."))
  }
  if (!inherits(plot, "ggplot")) {
    return(list(summary = paste0(
      "Expected ggplot, got ", paste(class(plot), collapse = "/")
    )))
  }

  plot_context <- safe_call(build_plot_context, plot)
  layer_summaries <- safe_call(summarize_plot_layers_for_polish, plot)
  layout_regions <- safe_call(extract_layout_regions, plot)
  data_contract <- safe_call(summarize_plot_data_contract, plot)

  n_layers <- length(plot$layers %||% list())
  summary <- paste0("ggplot with ", n_layers, " layer(s)")

  list(
    summary = summary,
    available = c("plot_context", "layer_summaries", "layout_regions", "data_contract"),
    n_layers = n_layers,
    plot_context = plot_context,
    layer_summaries = layer_summaries,
    layout_regions = layout_regions,
    data_contract = data_contract
  )
}

inspect_grob_tree <- function(grob) {
  if (is.null(grob)) {
    return(list(summary = "grob missing (object cache is NULL)."))
  }
  if (!inherits(grob, c("grob", "gTree", "gList"))) {
    return(list(summary = paste0(
      "Expected grob, got ", paste(class(grob), collapse = "/")
    )))
  }

  children <- character()
  n_grobs <- 1L
  if (inherits(grob, "gTree") && !is.null(grob$children)) {
    children <- vapply(
      grob$children,
      function(child) class(child)[[1L]],
      character(1L)
    )
    n_grobs <- length(grob$children) + 1L
  } else if (inherits(grob, "gList")) {
    children <- vapply(grob, function(child) class(child)[[1L]], character(1L))
    n_grobs <- length(grob)
  }

  list(
    summary = paste0("grid grob: ", class(grob)[[1L]], "; ", n_grobs, " node(s)"),
    available = c("tree_summary", "children_classes", "n_grobs"),
    tree_summary = class(grob),
    children_classes = children,
    n_grobs = n_grobs
  )
}

inspect_recorded <- function(recorded) {
  if (is.null(recorded)) {
    return(list(summary = "recordedplot missing (object cache is NULL)."))
  }
  if (!inherits(recorded, "recordedplot")) {
    return(list(summary = paste0(
      "Expected recordedplot, got ", paste(class(recorded), collapse = "/")
    )))
  }

  dl <- recorded$displaylist
  if (is.null(dl) && length(recorded) >= 1L) {
    dl <- recorded[[1L]]
  }
  n_ops <- if (is.null(dl)) 0L else length(dl)

  list(
    summary = paste0("base recordedplot: ", n_ops, " display-list operation(s)"),
    available = c("n_operations", "engine_version", "r_version"),
    n_operations = n_ops,
    engine_version = recorded$engineVersion %||% NA,
    r_version = recorded$Rversion %||% NA
  )
}

# ---- safe-call wrapper ----------------------------------------------------

# Call an existing internal helper but never propagate errors out of inspect.
# Inspection is best-effort; the caller decides how to react to missing info.
safe_call <- function(fn, ...) {
  if (!is.function(fn)) {
    return(NULL)
  }
  tryCatch(fn(...), error = function(...) NULL)
}
