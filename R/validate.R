# Engine-aware validation. Returns `status = "ok"` when the figure is
# structurally sound, or `status = "error" | "warning"` with diagnostic
# messages otherwise. Validation never throws — agents need to handle
# the result, not catch exceptions.

#' Validate a `ggai_artifact`
#'
#' Engine-aware structural validation. Returns a list describing whether the
#' figure is producible and well-formed; never throws.
#'
#' Return value fields:
#' \itemize{
#'   \item `status` — `"ok"`, `"warning"`, or `"error"`.
#'   \item `engine` — same as `artifact$engine`.
#'   \item `messages` — character vector of any diagnostic messages.
#'   \item `warnings` — character vector of any warnings.
#'   \item `error` — character scalar describing the error, when `status == "error"`.
#' }
#'
#' @param artifact A `ggai_artifact`.
#'
#' @return A list as documented above.
#' @export
ggai_validate_artifact <- function(artifact) {
  if (!is_ggai_artifact(artifact)) {
    return(list(
      status = "error",
      engine = NA_character_,
      messages = character(),
      warnings = character(),
      error = "Input is not a ggai_artifact."
    ))
  }

  res <- switch(
    artifact$engine,
    ggplot          = validate_ggplot(artifact$object),
    composite       = validate_ggplot(artifact$object),
    grid            = validate_grob(artifact$object),
    base            = validate_recorded(artifact$object),
    complex_heatmap = validate_ch(artifact$object),
    circlize        = validate_recorded(artifact$object),
    list(
      status = "warning",
      messages = paste0("No validator implemented for engine `", artifact$engine, "`."),
      warnings = character(),
      error = NULL
    )
  )

  utils::modifyList(
    list(
      engine = artifact$engine,
      status = "ok",
      messages = character(),
      warnings = character(),
      error = NULL
    ),
    res
  )
}

# ---- engine validators ----------------------------------------------------

validate_ggplot <- function(plot) {
  if (is.null(plot)) {
    return(list(
      status = "error",
      error = "ggplot object cache is NULL; cannot validate."
    ))
  }
  if (!inherits(plot, "ggplot")) {
    return(list(
      status = "error",
      error = paste0("Expected ggplot, got ", paste(class(plot), collapse = "/"))
    ))
  }

  warnings <- character()
  messages <- character()
  built <- tryCatch(
    withCallingHandlers(
      {
        ggplot2::ggplot_build(plot)
        ggplot2::ggplotGrob(plot)
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) e
  )

  if (inherits(built, "error")) {
    return(list(
      status = "error",
      error = conditionMessage(built),
      warnings = warnings,
      messages = messages
    ))
  }

  list(
    status = if (length(warnings)) "warning" else "ok",
    warnings = warnings,
    messages = messages
  )
}

validate_grob <- function(grob) {
  if (is.null(grob)) {
    return(list(
      status = "error",
      error = "grob cache is NULL; cannot validate."
    ))
  }
  if (!inherits(grob, c("grob", "gTree", "gList"))) {
    return(list(
      status = "error",
      error = paste0("Expected grob, got ", paste(class(grob), collapse = "/"))
    ))
  }
  # Best-effort: draw to a null device. If it errors, validation fails.
  warnings <- character()
  res <- tryCatch(
    withCallingHandlers(
      {
        grDevices::pdf(NULL)
        on.exit(grDevices::dev.off(), add = TRUE)
        grid::grid.newpage()
        grid::grid.draw(grob)
        TRUE
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )

  if (inherits(res, "error")) {
    return(list(
      status = "error",
      error = conditionMessage(res),
      warnings = warnings
    ))
  }

  list(
    status = if (length(warnings)) "warning" else "ok",
    warnings = warnings
  )
}

validate_ch <- function(ht) {
  if (is.null(ht)) {
    return(list(
      status = "error",
      error = "ComplexHeatmap object cache is NULL; cannot validate."
    ))
  }
  if (!inherits(ht, c("Heatmap", "HeatmapList"))) {
    return(list(
      status = "error",
      error = paste0("Expected Heatmap or HeatmapList, got ",
                     paste(class(ht), collapse = "/"))
    ))
  }
  if (!requireNamespace("ComplexHeatmap", quietly = TRUE)) {
    return(list(
      status = "warning",
      messages = "ComplexHeatmap package not available; cannot dry-run draw."
    ))
  }

  warnings <- character()
  res <- tryCatch(
    withCallingHandlers(
      {
        grDevices::pdf(NULL)
        on.exit(grDevices::dev.off(), add = TRUE)
        ComplexHeatmap::draw(ht)
        TRUE
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )

  if (inherits(res, "error")) {
    return(list(
      status = "error",
      error = conditionMessage(res),
      warnings = warnings
    ))
  }

  list(
    status = if (length(warnings)) "warning" else "ok",
    warnings = warnings
  )
}

validate_recorded <- function(recorded) {
  if (is.null(recorded)) {
    return(list(
      status = "error",
      error = "recordedplot cache is NULL; cannot validate."
    ))
  }
  if (!inherits(recorded, "recordedplot")) {
    return(list(
      status = "error",
      error = paste0("Expected recordedplot, got ", paste(class(recorded), collapse = "/"))
    ))
  }
  # A real plot has more than a trivial number of display-list operations.
  dl <- recorded$displaylist
  if (is.null(dl) && length(recorded) >= 1L) {
    dl <- recorded[[1L]]
  }
  if (is.null(dl) || !length(dl)) {
    return(list(
      status = "warning",
      messages = "recordedplot has an empty display list."
    ))
  }
  list(status = "ok")
}
