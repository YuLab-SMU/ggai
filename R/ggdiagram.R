#' Add a compiled diagram spec onto a diagram canvas
#'
#' @param plot A `ggdiagram()` plot.
#' @param spec A diagram scene specification.
#'
#' @return A ggplot object with the rendered diagram scene attached.
#' @export
add_diagram_spec <- function(plot, spec) {
  canvas <- spec$canvas %||% attr(plot, "ggai_canvas_spec") %||% list(width = 10, height = 6, background = "white")
  grob <- render_diagram_spec(spec)

  current_canvas <- attr(plot, "ggai_canvas_spec")
  if (is.null(current_canvas) || !identical(current_canvas$width, canvas$width) || !identical(current_canvas$height, canvas$height)) {
    plot <- plot + ggplot2::coord_cartesian(
      xlim = c(0, canvas$width),
      ylim = c(0, canvas$height),
      expand = FALSE,
      clip = "off"
    )
  }

  plot + ggplot2::annotation_custom(
    grob = grob,
    xmin = 0,
    xmax = canvas$width,
    ymin = 0,
    ymax = canvas$height
  )
}
