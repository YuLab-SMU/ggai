#' Plot a polished figure result
#'
#' @param x A `ggai_polished_figure_result`.
#' @param y Unused; included for plot method compatibility.
#' @param ... Passed to `plot()`.
#'
#' @return Invisibly returns the plotted ggplot object.
#' @export
plot.ggai_polished_figure_result <- function(x, y, ...) {
    img <- magick::image_read(x$best$path)
    p <- ggplotify::as.ggplot(img)
    plot(p, y, ...)
    invisible(p)
}

#' Print a polished figure result summary
#'
#' @param x A `ggai_polished_figure_result`.
#' @param ... Unused.
#'
#' @return Invisibly returns `x`.
#' @export
print.ggai_polished_figure_result <- function(x, ...) {
  candidate_count <- length(x$candidates %||% list())
  best_path <- x$best$path %||% ""
  best_score <- x$best$score %||% NULL

  cat("<ggai_polished_figure_result>\n")
  if (nzchar(best_path)) {
    cat("Best image: ", best_path, "\n", sep = "")
  }
  if (!is.null(best_score)) {
    cat("Best score: ", format(best_score), "\n", sep = "")
  }
  cat("Candidates: ", candidate_count, "\n", sep = "")
  if (nzchar(x$prompt_path %||% "")) {
    cat("Prompt: ", x$prompt_path, "\n", sep = "")
  }
  if (nzchar(x$bundle_manifest_path %||% "")) {
    cat("Bundle manifest: ", x$bundle_manifest_path, "\n", sep = "")
  }
  if (nzchar(x$candidate_manifest_path %||% "")) {
    cat("Candidate manifest: ", x$candidate_manifest_path, "\n", sep = "")
  }
  if (inherits(x$session, "ggai_session")) {
    cat("Session: updated with polish artifact\n")
  }
  cat("Use plot(x), x$best$path, artifacts(x$session), or latest_artifact(x$session).\n")
  invisible(x)
}
