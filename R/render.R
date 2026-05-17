# Engine-aware rendering. `ggai_render_artifact()` is the public entrypoint;
# `render_to_file()` is the internal worker shared with `ggai_execute_and_capture()`.

#' Render a `ggai_artifact` to a file
#'
#' Re-renders an existing artifact at a possibly different size, DPI, or format.
#' If the artifact's `object` cache is missing or stale, the code is re-executed
#' to repopulate it.
#'
#' @param artifact A `ggai_artifact`.
#' @param format Output format, one of `"png"` or `"svg"`.
#' @param path Optional output path. Auto-generated under `output_dir` when `NULL`.
#' @param output_dir Output directory. Defaults to `tempdir()`.
#' @param prefix Filename prefix when `path` is auto-generated.
#' @param width,height Output dimensions in pixels.
#' @param dpi DPI for raster output.
#' @param force_reexecute If `TRUE`, ignore the cached object and re-run `code`.
#'
#' @return The updated `ggai_artifact` with the new path recorded in `rendered`.
#' @export
ggai_render_artifact <- function(artifact,
                                 format = c("png", "svg"),
                                 path = NULL,
                                 output_dir = tempdir(),
                                 prefix = NULL,
                                 width = 1200L,
                                 height = 900L,
                                 dpi = 150,
                                 force_reexecute = FALSE) {
  if (!is_ggai_artifact(artifact)) {
    rlang::abort("`artifact` must be a ggai_artifact.")
  }
  format <- match.arg(format)

  needs_reexec <- isTRUE(force_reexecute) || is.null(artifact$object)
  if (isTRUE(needs_reexec)) {
    fresh <- ggai_execute_and_capture(
      code = artifact$code,
      format = format,
      engine_hint = artifact$engine,
      output_dir = output_dir,
      prefix = prefix %||% paste0(artifact$id, "_rerender"),
      width = width,
      height = height,
      dpi = dpi
    )
    artifact$object <- fresh$object
    artifact$engine <- fresh$engine
    artifact$rendered <- utils::modifyList(artifact$rendered, fresh$rendered)
    return(artifact)
  }

  if (is.null(path)) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    }
    file_name <- paste0(prefix %||% artifact$id, ".", format)
    path <- file.path(output_dir, file_name)
  }

  render_to_file(
    object = artifact$object,
    engine = artifact$engine,
    path = path,
    format = format,
    width = width,
    height = height,
    dpi = dpi
  )

  artifact$rendered <- utils::modifyList(
    artifact$rendered,
    stats::setNames(list(path), format)
  )
  artifact
}

# ---- internal worker ------------------------------------------------------

render_to_file <- function(object, engine, path, format,
                           width, height, dpi) {
  if (!is.character(path) || length(path) != 1L) {
    rlang::abort("`path` must be a single character string.")
  }
  parent <- dirname(path)
  if (nzchar(parent) && !dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }

  switch(
    engine,
    ggplot          = render_ggplot(object, path, format, width, height, dpi),
    composite       = render_ggplot(object, path, format, width, height, dpi),
    grid            = render_grid(object, path, format, width, height, dpi),
    base            = render_base(object, path, format, width, height, dpi),
    complex_heatmap = render_complex_heatmap(object, path, format, width, height, dpi),
    circlize        = render_base(object, path, format, width, height, dpi),
    htmlwidget      = render_htmlwidget(object, path, format, width, height, dpi),
    rlang::abort(paste0(
      "Rendering not implemented for engine `", engine, "`. ",
      "Supported: ggplot, composite, grid, base, complex_heatmap, circlize, htmlwidget."
    ))
  )
}

# ---- engine adapters ------------------------------------------------------

render_ggplot <- function(plot, path, format, width, height, dpi) {
  open_device(path, format, width, height, dpi)
  on.exit(grDevices::dev.off(), add = TRUE)
  print(plot)
  invisible(path)
}

render_grid <- function(grob, path, format, width, height, dpi) {
  open_device(path, format, width, height, dpi)
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  grid::grid.draw(grob)
  invisible(path)
}

render_base <- function(recorded, path, format, width, height, dpi) {
  if (is.null(recorded) || !inherits(recorded, "recordedplot")) {
    rlang::abort("Base-graphics render requires a recordedplot object.")
  }
  open_device(path, format, width, height, dpi)
  on.exit(grDevices::dev.off(), add = TRUE)
  grDevices::replayPlot(recorded)
  invisible(path)
}

# htmlwidgets need either a self-contained HTML file (always works) or a
# rasterized PNG (requires webshot2 + a headless Chrome via chromote).
#
# When format = "png" and webshot2 is available, this writes the PNG at
# `path`. When format = "png" and webshot2 is missing, it writes a
# self-contained HTML alongside `path` (extension swapped) and emits a
# warning so the caller knows what happened. The function always returns the
# actual path it wrote, so `ggai_execute_and_capture()` can record the right
# format in `artifact$rendered`.
render_htmlwidget <- function(widget, path, format, width, height, dpi) {
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    rlang::abort(c(
      "htmlwidgets package required for engine = 'htmlwidget'.",
      i = "Install with install.packages('htmlwidgets')."
    ))
  }

  format <- tolower(format)

  if (identical(format, "html")) {
    htmlwidgets::saveWidget(widget, path, selfcontained = TRUE)
    return(invisible(path))
  }

  if (identical(format, "png")) {
    if (!requireNamespace("webshot2", quietly = TRUE)) {
      html_path <- sub("\\.png$", ".html", path, ignore.case = TRUE)
      if (identical(html_path, path)) {
        html_path <- paste0(path, ".html")
      }
      htmlwidgets::saveWidget(widget, html_path, selfcontained = TRUE)
      warning(
        "Rendering an htmlwidget to PNG requires the `webshot2` package. ",
        "Wrote a self-contained HTML to `", html_path, "` instead. ",
        "Install webshot2 (and ensure chromote / Chrome are available) to enable PNG export.",
        call. = FALSE
      )
      return(invisible(html_path))
    }

    html_tmp <- tempfile(fileext = ".html")
    on.exit(unlink(html_tmp), add = TRUE)
    htmlwidgets::saveWidget(widget, html_tmp, selfcontained = TRUE)
    webshot2::webshot(
      url = html_tmp,
      file = path,
      vwidth = width %||% 1200L,
      vheight = height %||% 900L,
      delay = 0.5
    )
    return(invisible(path))
  }

  rlang::abort(paste0(
    "htmlwidget render does not support format `", format,
    "`. Use `format = \"html\"` (always) or `format = \"png\"` (with webshot2)."
  ))
}

# ComplexHeatmap requires its own `draw()` to render. The Heatmap / HeatmapList
# object is not a grob, not a ggplot; `print()` would print to console.
render_complex_heatmap <- function(ht, path, format, width, height, dpi) {
  if (!requireNamespace("ComplexHeatmap", quietly = TRUE)) {
    rlang::abort(
      "ComplexHeatmap package required for engine = 'complex_heatmap'. Install with BiocManager::install('ComplexHeatmap')."
    )
  }
  if (is.null(ht) || !inherits(ht, c("Heatmap", "HeatmapList"))) {
    rlang::abort(paste0(
      "complex_heatmap render expects a Heatmap or HeatmapList object; got ",
      paste(class(ht), collapse = "/")
    ))
  }
  open_device(path, format, width, height, dpi)
  on.exit(grDevices::dev.off(), add = TRUE)
  ComplexHeatmap::draw(ht)
  invisible(path)
}

# Open the right graphics device for the format. Prefer ragg / svglite if
# available; fall back to grDevices defaults.
open_device <- function(path, format, width, height, dpi) {
  format <- tolower(format)
  if (identical(format, "png")) {
    if (requireNamespace("ragg", quietly = TRUE)) {
      ragg::agg_png(
        filename = path, width = width, height = height,
        units = "px", res = dpi, background = "white"
      )
    } else {
      grDevices::png(
        filename = path, width = width, height = height,
        units = "px", res = dpi, bg = "white"
      )
    }
  } else if (identical(format, "svg")) {
    if (requireNamespace("svglite", quietly = TRUE)) {
      svglite::svglite(
        filename = path,
        width = width / dpi, height = height / dpi
      )
    } else {
      grDevices::svg(
        filename = path,
        width = width / dpi, height = height / dpi
      )
    }
  } else {
    rlang::abort(paste0("Unsupported render format: ", format))
  }
  invisible(path)
}
