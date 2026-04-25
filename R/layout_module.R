new_layout_spec <- function(plots,
                            ncol = NULL,
                            nrow = NULL,
                            widths = NULL,
                            heights = NULL,
                            labels = NULL,
                            title = NULL) {
  if (!length(plots)) {
    rlang::abort("`plots` must contain at least one plot.")
  }

  structure(
    list(
      plots = plots,
      ncol = ncol,
      nrow = nrow,
      widths = widths,
      heights = heights,
      labels = labels,
      title = title
    ),
    class = "ggai_layout_spec"
  )
}

normalize_layout_spec <- function(spec) {
  plots <- spec$plots %||% list()
  n <- length(plots)
  ncol <- spec$ncol %||% ceiling(sqrt(n))
  nrow <- spec$nrow %||% ceiling(n / ncol)
  widths <- spec$widths %||% rep(1, ncol)
  heights <- spec$heights %||% rep(1, nrow)
  labels <- spec$labels %||% rep(NULL, n)

  new_layout_spec(
    plots = plots,
    ncol = ncol,
    nrow = nrow,
    widths = widths,
    heights = heights,
    labels = labels,
    title = spec$title %||% NULL
  )
}

layout_matrix_default <- function(n, ncol, nrow) {
  mat <- matrix(NA_integer_, nrow = nrow, ncol = ncol)
  mat[seq_len(n)] <- seq_len(n)
  mat
}

layout_grob <- function(spec) {
  spec <- normalize_layout_spec(spec)
  grobs <- lapply(seq_along(spec$plots), function(i) {
    plot <- spec$plots[[i]]
    grob <- ggplot2::ggplotGrob(plot)
    label <- spec$labels[[i]]
    if (is.null(label) || !nzchar(label %||% "")) {
      return(grob)
    }

    grid::grobTree(
      grob,
      grid::textGrob(
        label,
        x = grid::unit(0.02, "npc"),
        y = grid::unit(0.98, "npc"),
        just = c("left", "top"),
        gp = grid::gpar(fontface = "bold", cex = 1.1)
      )
    )
  })

  matrix_idx <- layout_matrix_default(length(grobs), spec$ncol, spec$nrow)
  table <- grid::frameGrob(
    layout = grid::grid.layout(
      nrow = spec$nrow + if (!is.null(spec$title)) 1 else 0,
      ncol = spec$ncol,
      widths = grid::unit(spec$widths, "null"),
      heights = grid::unit(c(if (!is.null(spec$title)) 0.8 else NULL, spec$heights), "null")
    )
  )

  row_offset <- if (!is.null(spec$title)) 1 else 0
  if (!is.null(spec$title)) {
    table <- grid::placeGrob(
      table,
      grid::textGrob(spec$title, gp = grid::gpar(fontface = "bold", cex = 1.2)),
      row = 1,
      col = seq_len(spec$ncol)
    )
  }

  for (r in seq_len(spec$nrow)) {
    for (c in seq_len(spec$ncol)) {
      idx <- matrix_idx[r, c]
      if (!is.na(idx)) {
        table <- grid::placeGrob(table, grobs[[idx]], row = r + row_offset, col = c)
      }
    }
  }

  table
}

#' Compose multiple ggplots into a layout
#'
#' @param ... ggplot objects.
#' @param plots Optional list of ggplot objects.
#' @param ncol Number of columns.
#' @param nrow Number of rows.
#' @param widths Relative column widths.
#' @param heights Relative row heights.
#' @param labels Optional panel labels.
#' @param title Optional layout title.
#'
#' @return A `ggai_layout_spec` object.
#' @export
compose_plots <- function(...,
                          plots = NULL,
                          ncol = NULL,
                          nrow = NULL,
                          widths = NULL,
                          heights = NULL,
                          labels = NULL,
                          title = NULL) {
  dots <- list(...)
  plot_list <- plots %||% dots
  new_layout_spec(
    plots = plot_list,
    ncol = ncol,
    nrow = nrow,
    widths = widths,
    heights = heights,
    labels = labels,
    title = title
  )
}

#' Render a composed plot layout
#'
#' @param x A `ggai_layout_spec`.
#' @param ... Unused.
#'
#' @return A grob.
#' @export
render_layout <- function(x, ...) {
  UseMethod("render_layout")
}

#' @export
render_layout.ggai_layout_spec <- function(x, ...) {
  layout_grob(x)
}

#' @export
print.ggai_layout_spec <- function(x, ...) {
  grid::grid.newpage()
  grid::grid.draw(render_layout(x))
  invisible(x)
}
