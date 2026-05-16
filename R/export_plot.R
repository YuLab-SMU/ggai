ensure_r_package <- function(pkg, auto_install = TRUE) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    return(invisible(TRUE))
  }

  if (isTRUE(auto_install)) {
    tryCatch(
      utils::install.packages(pkg),
      error = function(...) NULL,
      warning = function(...) NULL
    )
  }

  if (!requireNamespace(pkg, quietly = TRUE)) {
    rlang::abort(paste0("Package `", pkg, "` could not be installed automatically."))
  }

  invisible(TRUE)
}

panel_sized_plot <- function(plot, panel_w = 5, panel_h = 5, units = "cm") {
  ensure_r_package("ggh4x")
  plot + ggh4x::force_panelsizes(
    rows = grid::unit(panel_h, units),
    cols = grid::unit(panel_w, units)
  )
}

measure_plot_canvas <- function(plot, units = "cm") {
  gt <- ggplot2::ggplotGrob(plot)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  list(
    gtable = gt,
    width = grid::convertWidth(sum(gt$widths), units, valueOnly = TRUE),
    height = grid::convertHeight(sum(gt$heights), units, valueOnly = TRUE)
  )
}

#' Save a ggplot with fixed panel dimensions
#'
#' @param plot A ggplot object.
#' @param filename Output file path.
#' @param panel_w Width of each panel in physical units.
#' @param panel_h Height of each panel in physical units.
#' @param units Physical unit passed to `grid::unit()`. Defaults to `"cm"`.
#' @param dpi Raster DPI for bitmap outputs.
#'
#' @return Invisibly returns a list with filename, width, and height.
#' @export
save_fixed_plot <- function(plot,
                            filename,
                            panel_w = 5,
                            panel_h = 5,
                            units = "cm",
                            dpi = 300) {
  if (!inherits(plot, "ggplot")) {
    rlang::abort("`plot` must be a ggplot object.")
  }
  if (!is.character(filename) || length(filename) != 1 || !nzchar(filename)) {
    rlang::abort("`filename` must be a non-empty string.")
  }

  fixed_plot <- panel_sized_plot(plot, panel_w = panel_w, panel_h = panel_h, units = units)
  measured <- measure_plot_canvas(fixed_plot, units = units)

  ggplot2::ggsave(
    filename = filename,
    plot = measured$gtable,
    width = measured$width + 0.01,
    height = measured$height + 0.01,
    units = units,
    dpi = dpi
  )

  message(
    paste0(
      "Saved: ", filename,
      " (canvas: ", round(measured$width, 2), " x ", round(measured$height, 2), " ", units, ")"
    )
  )

  invisible(list(filename = filename, width = measured$width, height = measured$height, units = units))
}
