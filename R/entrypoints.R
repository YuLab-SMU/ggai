#' Create an AI-driven ggplot layer request
#'
#' Returns a lazy request object that is compiled when added to a ggplot.
#'
#' @param instruction A natural-language visualization instruction.
#' @param model Optional language model identifier.
#' @param image_model Optional image model identifier reserved for future use.
#' @param data Optional data override used for the compiled layers.
#' @param cache Reserved for future use.
#' @param mode Compilation mode. Currently only `"layer"` is supported.
#'
#' @export
geom_ai <- function(instruction,
                    model = NULL,
                    image_model = NULL,
                    data = NULL,
                    cache = TRUE,
                    mode = c("layer", "diagram")) {
  mode <- match.arg(mode)
  if (!is.character(instruction) || length(instruction) != 1L || !nzchar(instruction)) {
    rlang::abort("`instruction` must be a single non-empty string.")
  }

  structure(
    list(
      instruction = instruction,
      target = mode,
      model = model,
      image_model = image_model,
      data = data,
      cache = cache
    ),
    class = c("ggai_layer_request", "ggplot_add")
  )
}

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
