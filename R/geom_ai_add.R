#' Add a lazy ggai request to an existing ggplot
#'
#' Routes the request through the agentic edit runtime, returning a new
#' ggplot with the requested layers applied. Requires a configured agentic
#' language model (see `ggai_set_model()`).
#'
#' @param object A `ggai_layer_request`.
#' @param plot A ggplot object.
#' @param ... Unused compatibility arguments.
#'
#' @exportS3Method ggplot2::ggplot_add
ggplot_add.ggai_layer_request <- function(object, plot, ...) {
  base_plot <- plot_base_plot(plot)

  if (identical(object$target, "diagram") || identical(attr(plot, "ggai_canvas"), "diagram")) {
    spec <- compile_diagram_spec(
      instruction = object$instruction,
      scene_context = attr(plot, "ggai_canvas_spec") %||% list(),
      model = object$model
    )
    compiled <- new_compiled_spec(
      spec = spec,
      kind = "diagram",
      instruction = object$instruction,
      context = attr(plot, "ggai_canvas_spec") %||% list()
    )
    plot <- add_diagram_spec(plot, compiled$spec)
    plot <- record_compiled_spec(plot, compiled)
    attr(plot, "ggai_base_plot") <- base_plot
    return(plot)
  }

  model <- ggai_effective_agentic_model(object$model)
  if (!ggai_agentic_edit_enabled(model)) {
    rlang::abort(c(
      "geom_ai() requires an agentic language model.",
      i = "Configure via `ggai_set_model()`, `options(ggai.language_model=)`, or `GGAI_LANGUAGE_MODEL`."
    ))
  }

  data <- object$data %||% plot$data
  artifact <- ggai_agentic_repair_edit(
    compiled = NULL,
    base_plot = base_plot,
    current_plot = plot,
    data = data,
    instruction = object$instruction,
    model = model,
    context_mentions = list(),
    prior_error = NULL
  )

  result <- artifact$plot
  if (!is.null(artifact$compiled)) {
    result <- record_compiled_spec(result, artifact$compiled)
  }
  attr(result, "ggai_base_plot") <- base_plot
  result
}
