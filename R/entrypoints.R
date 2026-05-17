# geom_ai() was removed in the P2 agentic refactor: its dispatcher
# (ggplot_add.ggai_layer_request) lived in the deleted agentic_edit / geom_ai_add
# stack. The equivalent ergonomic — adding an AI-generated layer to a ggplot —
# will return as a Skill-driven helper in P3+.

#' Create a diagram canvas
#'
#' @param width Canvas width.
#' @param height Canvas height.
#' @param background Background color.
#' @param theme Theme preset name.
#'
#' @export
ggdiagram <- function(width = 10, height = 6, background = "white", theme = ggai_diagram_theme()) {
  plot <- ggplot2::ggplot() +
    ggplot2::coord_cartesian(
      xlim = c(0, width),
      ylim = c(0, height),
      expand = FALSE,
      clip = "off"
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = background, colour = background),
      panel.background = ggplot2::element_rect(fill = background, colour = background)
    )

  attr(plot, "ggai_canvas") <- "diagram"
  attr(plot, "ggai_canvas_spec") <- list(width = width, height = height, background = background, theme = theme)
  plot
}

#' Generate or retrieve an AI glyph asset
#'
#' @param prompt Primary glyph prompt.
#' @param style Optional style string.
#' @param width Width in pixels.
#' @param height Height in pixels.
#' @param model Optional image model identifier.
#' @param cache Whether to reuse cached output.
#' @param transparent_background Whether to request transparency.
#'
#' @export
glyph_ai <- function(prompt,
                     style = NULL,
                     width = 256,
                     height = 256,
                     model = NULL,
                     cache = TRUE,
                     transparent_background = TRUE) {
  glyph_generate_asset(
    prompt = prompt,
    style = style,
    width = width,
    height = height,
    model = model,
    cache = cache,
    transparent_background = transparent_background
  )
}
