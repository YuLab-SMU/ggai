ggai_runtime_context <- function(plot = NULL,
                                 session = NULL,
                                 request = NULL,
                                 extras = list()) {
  plot_context <- if (inherits(plot, "ggplot")) build_plot_context(plot) else list()
  session_snapshot <- if (inherits(session, "ggai_session")) session_context_snapshot(session) else NULL

  list(
    request = request %||% list(),
    plot = plot_context,
    session = session_snapshot,
    extras = extras %||% list()
  )
}

new_ggai_runtime_request <- function(instruction,
                                     target = c("layer", "diagram", "glyph", "figure"),
                                     plot = NULL,
                                     session = NULL,
                                     context = list(),
                                     model = NULL) {
  target <- match.arg(target)
  structure(
    list(
      instruction = instruction,
      target = target,
      model = model,
      context = ggai_runtime_context(
        plot = plot,
        session = session,
        request = list(instruction = instruction, target = target),
        extras = context
      )
    ),
    class = c("ggai_runtime_request", paste0("ggai_", target, "_runtime_request"))
  )
}

coerce_runtime_request <- function(instruction,
                                   target = "layer",
                                   plot = NULL,
                                   session = NULL,
                                   context = list(),
                                   model = NULL) {
  if (inherits(instruction, "ggai_runtime_request")) {
    return(instruction)
  }
  new_ggai_runtime_request(
    instruction = instruction,
    target = target,
    plot = plot,
    session = session,
    context = context,
    model = model
  )
}

request_plot_context <- function(request) {
  request$context$plot %||% list()
}

request_session_context <- function(request) {
  request$context$session %||% NULL
}

