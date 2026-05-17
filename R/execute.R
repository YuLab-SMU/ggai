# Execute R code in a graphics-capturing environment, detect the engine that
# produced the figure, render to file, and wrap the result as a `ggai_artifact`.

#' Execute R code and capture as a `ggai_artifact`
#'
#' Evaluates `code` in an environment that records both the returned R object
#' and any base-graphics drawing operations. Detects the figure engine
#' automatically, renders the result to a file, and returns the artifact.
#'
#' Engine detection order:
#' \itemize{
#'   \item composite — `last_value` inherits `patchwork` (multi-plot composite).
#'   \item ggplot — `last_value` inherits `ggplot` / `gg`.
#'   \item complex_heatmap — `last_value` inherits `Heatmap` / `HeatmapList`.
#'   \item htmlwidget — `last_value` inherits `htmlwidget`.
#'   \item grid — `last_value` inherits `grob` / `gTree` / `gList`.
#'   \item base — the device displaylist contains operations after evaluation.
#'   \item unknown — none of the above.
#' }
#'
#' For engines that ggai cannot yet render (complex_heatmap, circlize,
#' htmlwidget, composite), the artifact is still returned with engine recorded
#' but `rendered` left empty and a warning emitted.
#'
#' @param code Character scalar of R code.
#' @param env Optional environment in which to evaluate `code`. Defaults to a
#'   fresh child of `parent.frame()`.
#' @param format Output format. One of `"png"` or `"svg"` for the graphics
#'   engines (`ggplot`, `grid`, `base`, `composite`, `complex_heatmap`,
#'   `circlize`). For `htmlwidget`, `"html"` is always supported; `"png"`
#'   additionally requires the optional `webshot2` package. When `"png"` is
#'   requested without webshot2, the artifact is saved as HTML instead
#'   (with a warning) and `rendered` will hold the HTML path.
#' @param engine_hint Optional engine override. Use when auto-detection is
#'   known to fail (e.g. `grid::grid.draw(grob)` that returns `NULL`).
#' @param output_dir Output directory. Defaults to `tempdir()`.
#' @param prefix Filename prefix.
#' @param width,height Output dimensions in pixels.
#' @param dpi DPI for raster output.
#' @param data_refs Optional list to attach to the artifact's `data_refs` slot.
#' @param provenance Optional list merged into the artifact's `provenance` slot.
#'
#' @return A `ggai_artifact`.
#' @export
ggai_execute_and_capture <- function(code,
                                     env = NULL,
                                     format = c("png", "svg", "html"),
                                     engine_hint = NULL,
                                     output_dir = tempdir(),
                                     prefix = "artifact",
                                     width = 1200L,
                                     height = 900L,
                                     dpi = 150,
                                     data_refs = list(),
                                     provenance = list()) {
  format <- match.arg(format)
  if (!is.character(code) || length(code) != 1L || !nzchar(code)) {
    rlang::abort("`code` must be a single non-empty character string.")
  }

  env <- env %||% new.env(parent = parent.frame())

  pkgs_before <- loadedNamespaces()

  # Open a null device with displaylist recording so base graphics get captured.
  grDevices::pdf(NULL, width = width / dpi, height = height / dpi)
  null_dev <- grDevices::dev.cur()
  grDevices::dev.control(displaylist = "enable")
  device_cleanup <- function() {
    if (null_dev %in% grDevices::dev.list()) {
      try(grDevices::dev.off(which = null_dev), silent = TRUE)
    }
  }
  on.exit(device_cleanup(), add = TRUE)

  expr <- tryCatch(
    parse(text = code),
    error = function(e) {
      rlang::abort(c(
        "ggai_execute_and_capture: parse error in code.",
        i = conditionMessage(e)
      ))
    }
  )

  capture <- new.env(parent = emptyenv())
  capture$last_value <- NULL
  capture$error <- NULL

  ok <- tryCatch(
    {
      capture$last_value <- eval(expr, envir = env)
      TRUE
    },
    error = function(e) {
      capture$error <- e
      FALSE
    }
  )

  recorded <- if (isTRUE(ok)) {
    tryCatch(grDevices::recordPlot(), error = function(...) NULL)
  } else {
    NULL
  }

  device_cleanup()

  if (!isTRUE(ok)) {
    rlang::abort(c(
      "ggai_execute_and_capture: code evaluation failed.",
      i = paste0("Error: ", conditionMessage(capture$error)),
      i = paste0(
        "Code preview: ",
        substr(code, 1L, 200L),
        if (nchar(code) > 200L) "..." else ""
      )
    ))
  }

  last_value <- capture$last_value
  has_base <- isTRUE(record_has_content(recorded))

  engine <- engine_hint %||% detect_engine(last_value, has_base)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  file_name <- paste0(prefix, "_", format(Sys.time(), "%H%M%S"), ".", format)
  file_path <- file.path(output_dir, file_name)

  rendered_object <- switch(
    engine,
    ggplot          = last_value,
    composite       = last_value,
    grid            = last_value,
    complex_heatmap = last_value,
    htmlwidget      = last_value,
    base            = recorded,
    circlize        = recorded,
    last_value
  )

  rendered <- list()
  actual_path <- tryCatch(
    render_to_file(
      object = rendered_object,
      engine = engine,
      path = file_path,
      format = format,
      width = width,
      height = height,
      dpi = dpi
    ),
    error = function(e) {
      warning(
        "Rendering failed for engine `", engine, "`: ",
        conditionMessage(e),
        call. = FALSE
      )
      NULL
    }
  )
  if (!is.null(actual_path) && is.character(actual_path) && file.exists(actual_path)) {
    actual_format <- tolower(tools::file_ext(actual_path))
    if (!nzchar(actual_format)) actual_format <- format
    rendered <- stats::setNames(list(actual_path), actual_format)
  }

  pkgs_used <- setdiff(loadedNamespaces(), pkgs_before)

  prov <- utils::modifyList(
    list(
      created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      source = "ggai_execute_and_capture",
      auto_detected = is.null(engine_hint)
    ),
    as.list(provenance %||% list())
  )

  ggai_artifact(
    code = code,
    engine = engine,
    object = rendered_object,
    rendered = rendered,
    data_refs = as.list(data_refs %||% list()),
    packages = pkgs_used,
    provenance = prov
  )
}

# ---- internal helpers -----------------------------------------------------

# Detect the engine from the value returned by evaluating user code plus
# whether the device captured any base-graphics drawing operations.
detect_engine <- function(last_value, has_base) {
  if (inherits(last_value, "patchwork")) return("composite")
  if (inherits(last_value, "ggplot")) return("ggplot")
  if (inherits(last_value, c("Heatmap", "HeatmapList"))) return("complex_heatmap")
  if (inherits(last_value, "htmlwidget")) return("htmlwidget")
  if (inherits(last_value, c("grob", "gTree", "gList"))) return("grid")
  if (isTRUE(has_base)) return("base")
  "unknown"
}

# Did the recordedplot capture any non-trivial drawing operations?
record_has_content <- function(recorded) {
  if (is.null(recorded) || !inherits(recorded, "recordedplot")) {
    return(FALSE)
  }
  dl <- recorded$displaylist
  if (is.null(dl) && length(recorded) >= 1L) {
    dl <- recorded[[1L]]
  }
  if (is.null(dl) || !length(dl)) {
    return(FALSE)
  }
  length(dl) > 1L
}
