#' Add a lazy ggai request to an existing ggplot
#'
#' @param object A `ggai_layer_request`.
#' @param plot A ggplot object.
#' @param ... Unused compatibility arguments.
#'
#' @exportS3Method ggplot2::ggplot_add
ggplot_add.ggai_layer_request <- function(object, plot, ...) {
  base_plot <- plot_base_plot(plot)
  compiled <- compile_ggai_request(object, plot = plot, model = object$model)

  if (identical(compiled$kind, "diagram")) {
    plot <- add_diagram_spec(plot, compiled$spec)
    plot <- record_compiled_spec(plot, compiled)
    attr(plot, "ggai_base_plot") <- base_plot
    return(plot)
  }

  layers <- compile_layer_spec_to_layers(compiled$spec, data = object$data %||% plot$data)
  for (layer in layers) {
    plot <- plot + layer
  }

  plot <- record_compiled_spec(plot, compiled)
  attr(plot, "ggai_base_plot") <- base_plot
  plot
}
