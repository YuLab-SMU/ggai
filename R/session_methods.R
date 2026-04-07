#' Plot method for a ggai session
#'
#' @param x A `ggai_session`.
#' @param ... Passed through to `print.ggplot()`.
#'
#' @export
plot.ggai_session <- function(x, ...) {
  session_current_plot(x)
}

#' @export
inspect_spec.ggai_session <- function(x, raw = FALSE, ...) {
  compiled <- session_current_compiled(x)
  if (is.null(compiled)) {
    rlang::abort("This session has no compiled ggai edits yet.")
  }
  inspect_spec(compiled, raw = raw, ...)
}

#' @export
as_code.ggai_session <- function(x, ...) {
  compiled <- session_current_compiled(x)
  if (is.null(compiled)) {
    rlang::abort("This session has no compiled ggai edits yet.")
  }
  as_code(compiled, ...)
}

#' @export
spec_history.ggai_session <- function(plot, ...) {
  history <- plot$history %||% list()
  if (!length(history)) {
    return(data.frame())
  }
  data.frame(
    version = seq_along(history),
    instruction = vapply(history, function(x) x$instruction %||% "", character(1)),
    kind = vapply(history, function(x) x$kind %||% "", character(1)),
    edit_mode = vapply(history, function(x) x$edit_mode %||% "", character(1)),
    timestamp = vapply(history, function(x) x$timestamp %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}
