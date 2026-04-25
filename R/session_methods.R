#' Plot method for a ggai session
#'
#' @param x A `ggai_session`.
#' @param ... Passed through to `print.ggplot()`.
#'
#' @export
plot.ggai_session <- function(x, ...) {
  session_current_plot(x)
}

#' List recorded session artifacts
#'
#' @param x A `ggai_session`.
#' @param ... Passed to methods.
#'
#' @return A list of recorded session artifacts.
#' @export
artifacts <- function(x, ...) {
  UseMethod("artifacts")
}

#' @export
artifacts.default <- function(x, ...) {
  rlang::abort("`artifacts()` is only available for `ggai_session` objects.")
}

#' @export
artifacts.ggai_session <- function(x, ...) {
  session_artifact_log(x)
}

#' Return the latest recorded session artifact
#'
#' @param x A `ggai_session`.
#' @param kind Optional artifact kind filter such as `"polish"`.
#' @param ... Passed to methods.
#'
#' @return A single artifact record or `NULL` when no match exists.
#' @export
latest_artifact <- function(x, kind = NULL, ...) {
  UseMethod("latest_artifact")
}

#' @export
latest_artifact.default <- function(x, kind = NULL, ...) {
  rlang::abort("`latest_artifact()` is only available for `ggai_session` objects.")
}

#' @export
latest_artifact.ggai_session <- function(x, kind = NULL, ...) {
  log <- session_artifact_log(x)
  if (!length(log)) {
    return(NULL)
  }

  if (!is.null(kind)) {
    log <- Filter(function(item) identical(item$kind %||% NULL, kind), log)
  }
  if (!length(log)) {
    return(NULL)
  }

  log[[length(log)]]
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
  artifact_log <- session_artifact_log(plot)

  history_df <- if (length(history)) {
    data.frame(
      version = seq_along(history),
      turn = seq_along(history),
      instruction = vapply(history, function(x) x$instruction %||% "", character(1)),
      kind = vapply(history, function(x) x$kind %||% "", character(1)),
      edit_mode = vapply(history, function(x) x$edit_mode %||% "", character(1)),
      timestamp = vapply(history, function(x) x$timestamp %||% "", character(1)),
      artifact_path = NA_character_,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      version = integer(),
      turn = integer(),
      instruction = character(),
      kind = character(),
      edit_mode = character(),
      timestamp = character(),
      artifact_path = character(),
      stringsAsFactors = FALSE
    )
  }

  artifact_df <- if (length(artifact_log)) {
    data.frame(
      version = rep(NA_integer_, length(artifact_log)),
      turn = vapply(artifact_log, function(x) as.integer(x$turn %||% NA_integer_), integer(1)),
      instruction = vapply(artifact_log, function(x) x$instruction %||% "", character(1)),
      kind = vapply(artifact_log, function(x) x$kind %||% "artifact", character(1)),
      edit_mode = vapply(artifact_log, function(x) x$edit_mode %||% "artifact", character(1)),
      timestamp = vapply(artifact_log, function(x) x$timestamp %||% "", character(1)),
      artifact_path = vapply(artifact_log, function(x) x$artifact_path %||% "", character(1)),
      stringsAsFactors = FALSE
    )
  } else {
    history_df[0, , drop = FALSE]
  }

  out <- rbind(history_df, artifact_df)
  if (!nrow(out)) {
    return(out)
  }

  out[order(out$timestamp, na.last = TRUE), , drop = FALSE]
}

#' @export
session_context.ggai_session <- function(x, ...) {
  session_context_snapshot(x)
}
