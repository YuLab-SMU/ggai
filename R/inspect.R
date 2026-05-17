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
    ggplot          = inspect_ggplot(artifact$object),
    composite       = inspect_composite(artifact$object),
    grid            = inspect_grob_tree(artifact$object),
    base            = inspect_recorded(artifact$object),
    complex_heatmap = inspect_ch(artifact$object),
    circlize        = inspect_circlize(artifact$object),
    htmlwidget      = inspect_htmlwidget(artifact$object),
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

# Inspection over a ComplexHeatmap Heatmap / HeatmapList. Surfaces matrix
# shape, names, dendrograms, and annotation slot occupants — enough for
# Skills to decide whether the heatmap needs polish, restyle, or a follow-up
# annotation layer.
inspect_ch <- function(ht) {
  if (is.null(ht)) {
    return(list(summary = "ComplexHeatmap object missing (object cache is NULL)."))
  }
  if (!inherits(ht, c("Heatmap", "HeatmapList"))) {
    return(list(summary = paste0(
      "Expected Heatmap or HeatmapList, got ", paste(class(ht), collapse = "/")
    )))
  }

  heatmaps <- if (inherits(ht, "HeatmapList")) {
    ht@ht_list
  } else {
    list(ht)
  }

  per <- lapply(heatmaps, function(h) {
    if (!inherits(h, "Heatmap")) {
      return(list(name = NA_character_, class = paste(class(h), collapse = "/")))
    }
    mat <- tryCatch(h@matrix, error = function(...) NULL)
    list(
      name = h@name %||% NA_character_,
      nrow = if (is.null(mat)) NA_integer_ else nrow(mat),
      ncol = if (is.null(mat)) NA_integer_ else ncol(mat),
      row_title = if (length(h@row_title)) h@row_title else NA_character_,
      column_title = if (length(h@column_title)) h@column_title else NA_character_,
      has_row_dendrogram = isTRUE(h@row_dend_param$cluster %||% FALSE),
      has_column_dendrogram = isTRUE(h@column_dend_param$cluster %||% FALSE),
      has_top_annotation = !is.null(h@top_annotation),
      has_bottom_annotation = !is.null(h@bottom_annotation),
      has_left_annotation = !is.null(h@left_annotation),
      has_right_annotation = !is.null(h@right_annotation)
    )
  })

  n <- length(heatmaps)
  summary_first <- per[[1L]]
  summary_dims <- if (!is.na(summary_first$nrow)) {
    paste0(summary_first$nrow, "x", summary_first$ncol)
  } else {
    "?"
  }
  summary <- paste0(
    "ComplexHeatmap: ", n, " heatmap(s); first = `",
    summary_first$name %||% "?", "` (", summary_dims, ")"
  )

  list(
    summary = summary,
    available = c("n_heatmaps", "heatmaps"),
    n_heatmaps = n,
    heatmaps = per
  )
}

# A patchwork object is built from one of two operator families:
#
#  - `pw1 + pw2`: the result inherits `pw2`'s ggplot identity (`$layers` =
#    `pw2$layers`) and earlier plots go into `$patches$plots` in original
#    order. Visually the rendered grid is `patches[1], ..., patches[N-1],
#    self` (self = last-added).
#
#  - `pw1 | pw2`, `pw1 / pw2`, `wrap_plots(...)`: produces a "container"
#    patchwork with no own ggplot identity (`$layers` is empty). All
#    constituent plots live in `$patches$plots`; there is no `self` panel.
#
# `inspect_composite()` distinguishes the two by inspecting
# `length(pw$layers)`: > 0 means "+"-built (carries a self panel); 0 means
# container ("|" / "/" / "wrap_plots" — patches list is everything).
#
# Nested patchworks (e.g. `p1 | (p2 / p3)`) are walked recursively: each
# entry in `$patches$plots` that is itself a patchwork gets full descent and
# returns its own `panels` sublist with sub-indices.
#
# Per-panel `n_layers` is read directly from `length(p$layers)`. Empirically
# this is reliable for patchwork 1.3 + ggplot2 S7 in practice; earlier
# concerns about $-access being stripped turned out to be a mis-reading of
# the patches order (self = last-added, not first). `count_layers_safe()`
# falls back to `ggplot_build()` when direct access fails.
inspect_composite <- function(pw) {
  if (is.null(pw)) {
    return(list(summary = "composite object missing (object cache is NULL)."))
  }
  if (!inherits(pw, "patchwork")) {
    return(inspect_ggplot(pw))
  }

  composite_panel <- function(p, index) {
    panel <- list(index = index, class = paste(class(p), collapse = "/"))
    if (inherits(p, "patchwork")) {
      panel$kind <- "nested_patchwork"
      nested <- inspect_composite(p)
      panel$n_panels <- nested$n_panels %||% NA_integer_
      panel$panels <- nested$panels %||% list()
      panel$summary <- nested$summary %||% NA_character_
    } else if (inherits(p, "ggplot")) {
      panel$kind <- "ggplot"
      panel$n_layers <- count_layers_safe(p)
      panel$summary <- paste0("ggplot with ", panel$n_layers, " layer(s)")
    } else if (inherits(p, c("grob", "gTree", "gList"))) {
      panel$kind <- "grob"
      panel$class_chain <- class(p)
    } else {
      panel$kind <- "other"
    }
    panel
  }

  patches <- tryCatch(pw$patches$plots, error = function(...) list())
  if (is.null(patches)) patches <- list()

  # Visual ordering: patches first, then self.
  patch_panels <- lapply(seq_along(patches), function(i) {
    composite_panel(patches[[i]], index = i)
  })

  # Detect container vs +-built: container patchworks (`|`, `/`, wrap_plots)
  # have an empty `$layers`; their visible panels are exactly the patches.
  pw_direct_layers <- tryCatch(length(pw$layers), error = function(...) 0L)
  is_container <- isTRUE(pw_direct_layers == 0L)

  panels <- patch_panels
  self_inspect <- NULL
  if (!is_container) {
    self_n <- count_layers_safe(pw)
    self_panel <- list(
      index = length(patches) + 1L,
      class = paste(class(pw), collapse = "/"),
      kind = "patchwork_self",
      n_layers = self_n,
      summary = paste0("patchwork self (last-added panel) with ",
                       self_n, " layer(s)")
    )
    panels <- c(patch_panels, list(self_panel))
    self_inspect <- safe_call(inspect_ggplot, pw)
  }

  total_layers <- sum_leaf_layers(panels)
  n <- length(panels)
  flavor <- if (is_container) "container (|, /, or wrap_plots)" else "+-built (last plot as self)"
  summary <- paste0("patchwork composite [", flavor, "]: ",
                    n, " panel(s); ",
                    total_layers, " total leaf-layer(s) across all panels")

  list(
    summary = summary,
    available = c("n_panels", "panels", "total_leaf_layers", "is_container", "self_inspect"),
    n_panels = n,
    panels = panels,
    total_leaf_layers = total_layers,
    is_container = is_container,
    self_inspect = self_inspect
  )
}

# Layer count for a single ggplot. Primary: direct $layers access (works
# for patchwork-stored patches in current patchwork 1.3+). Fallback:
# ggplot_build()$data for malformed inputs.
count_layers_safe <- function(p) {
  if (is.null(p) || !inherits(p, "ggplot")) {
    return(NA_integer_)
  }
  via_dollar <- tryCatch(length(p$layers), error = function(...) NA_integer_)
  if (!is.na(via_dollar)) return(via_dollar)
  built <- tryCatch(
    suppressMessages(suppressWarnings(ggplot2::ggplot_build(p))),
    error = function(...) NULL
  )
  if (!is.null(built) && !is.null(built$data)) {
    return(length(built$data))
  }
  NA_integer_
}

# Sum leaf-layer counts across the panel tree (recurses into nested).
sum_leaf_layers <- function(panels) {
  if (!length(panels)) return(0L)
  Reduce(`+`, lapply(panels, function(p) {
    if (identical(p$kind, "nested_patchwork") && length(p$panels)) {
      sum_leaf_layers(p$panels)
    } else if (identical(p$kind, "ggplot") || identical(p$kind, "patchwork_self")) {
      v <- p$n_layers
      if (is.null(v) || is.na(v)) 0L else as.integer(v)
    } else {
      0L
    }
  }), 0L)
}

# Surfaces widget identity, declared dependencies, and sizing policy. Does
# NOT serialise the widget — that's the render step's job.
inspect_htmlwidget <- function(widget) {
  if (is.null(widget)) {
    return(list(summary = "htmlwidget missing (object cache is NULL)."))
  }
  if (!inherits(widget, "htmlwidget")) {
    return(list(summary = paste0(
      "Expected htmlwidget, got ", paste(class(widget), collapse = "/")
    )))
  }

  widget_name <- setdiff(class(widget), c("htmlwidget", "list"))
  widget_name <- if (length(widget_name)) widget_name[[1L]] else "htmlwidget"

  deps <- tryCatch(widget$dependencies, error = function(...) NULL)
  dep_names <- if (length(deps)) {
    vapply(deps, function(d) d$name %||% NA_character_, character(1))
  } else {
    character()
  }

  policy <- tryCatch(widget$sizingPolicy, error = function(...) NULL)
  has_x <- !is.null(widget$x)

  list(
    summary = paste0("htmlwidget: ", widget_name,
                     "; ", length(dep_names), " declared dependencies",
                     if (has_x) "; data payload attached" else "; no data payload"),
    available = c("widget_name", "dependencies", "sizing_policy", "has_data_payload"),
    widget_name = widget_name,
    dependencies = dep_names,
    sizing_policy = policy,
    has_data_payload = has_x
  )
}

# Circlize draws via base-graphics-style side effects, so the cached object is
# a `recordedplot`. The inspector returns the same minimal metadata as base
# plus an `engine_hint` flag so downstream skills can branch on it.
inspect_circlize <- function(recorded) {
  base_info <- inspect_recorded(recorded)
  base_info$engine_kind <- "circlize"
  if (!is.null(base_info$summary) && !grepl("^circlize", base_info$summary)) {
    base_info$summary <- paste0("circlize plot: ", base_info$n_operations %||% 0L,
                                 " display-list operation(s)")
  }
  base_info
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
