diagram_theme_presets <- function() {
  list(
    paper = list(
      canvas = list(background = "#FCFCF8"),
      nodes = list(
        box = list(fill = "#E8F3FF", colour = "#334E68", text_colour = "#102A43", linewidth = 1.1),
        rounded_box = list(fill = "#FFF1D6", colour = "#7C4D12", text_colour = "#3E2723", linewidth = 1.1),
        image_asset = list(
          fill = "#F7F7F7", colour = "#52606D", linewidth = 1.0,
          label_fill = grDevices::adjustcolor("white", alpha.f = 0.92),
          label_border = grDevices::adjustcolor("#D9E2EC", alpha.f = 0.9),
          label_colour = "#102A43",
          label_cex = 1.08
        ),
        text = list(text_colour = "#1F2933")
      ),
      edges = list(colour = "#486581", linewidth = 1.2, linetype = 1)
    ),
    blueprint = list(
      canvas = list(background = "#F4F8FB"),
      nodes = list(
        box = list(fill = "#DCEEFF", colour = "#1D4E89", text_colour = "#102A43", linewidth = 1.2),
        rounded_box = list(fill = "#E3F2FD", colour = "#1565C0", text_colour = "#0D47A1", linewidth = 1.2),
        image_asset = list(
          fill = "#EAF4FA", colour = "#1D4E89", linewidth = 1.0,
          label_fill = grDevices::adjustcolor("white", alpha.f = 0.92),
          label_border = grDevices::adjustcolor("#BFDBFE", alpha.f = 0.9),
          label_colour = "#0B1F33",
          label_cex = 1.08
        ),
        text = list(text_colour = "#0B1F33")
      ),
      edges = list(colour = "#1565C0", linewidth = 1.3, linetype = 1)
    ),
    warm = list(
      canvas = list(background = "#FFF9F2"),
      nodes = list(
        box = list(fill = "#FFE8CC", colour = "#9C4221", text_colour = "#7B341E", linewidth = 1.1),
        rounded_box = list(fill = "#FDEBD3", colour = "#B45309", text_colour = "#7C2D12", linewidth = 1.1),
        image_asset = list(
          fill = "#FFF4E6", colour = "#9C4221", linewidth = 1.0,
          label_fill = grDevices::adjustcolor("white", alpha.f = 0.92),
          label_border = grDevices::adjustcolor("#FED7AA", alpha.f = 0.9),
          label_colour = "#5D2A0C",
          label_cex = 1.08
        ),
        text = list(text_colour = "#5D2A0C")
      ),
      edges = list(colour = "#B45309", linewidth = 1.2, linetype = 1)
    )
  )
}

resolve_diagram_theme <- function(theme = NULL) {
  theme <- theme %||% ggai_diagram_theme()
  presets <- diagram_theme_presets()
  if (!is.character(theme) || length(theme) != 1 || !nzchar(theme) || is.null(presets[[theme]])) {
    return(presets$paper)
  }

  presets[[theme]]
}

apply_diagram_theme <- function(spec) {
  canvas <- spec$canvas %||% list()
  theme_name <- canvas$theme %||% ggai_diagram_theme()
  theme <- resolve_diagram_theme(theme_name)

  canvas$theme <- theme_name
  canvas$background <- canvas$background %||% theme$canvas$background
  spec$canvas <- canvas

  spec$nodes <- lapply(spec$nodes %||% list(), function(node) {
    kind_defaults <- theme$nodes[[node$kind %||% "box"]] %||% list()
    node$style <- utils::modifyList(kind_defaults, node$style %||% list())
    node
  })

  spec$edges <- lapply(spec$edges %||% list(), function(edge) {
    edge$style <- utils::modifyList(theme$edges %||% list(), edge$style %||% list())
    edge
  })

  spec
}
