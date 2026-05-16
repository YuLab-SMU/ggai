normalize_glyph_spec_body <- function(spec) {
  spec$prompt <- spec$prompt %||% ""
  spec$style <- spec$style %||% NULL
  spec$negative_prompt <- spec$negative_prompt %||% NULL
  spec$width <- spec$width %||% 256
  spec$height <- spec$height %||% 256
  spec$transparent_background <- if (is.null(spec$transparent_background)) TRUE else isTRUE(spec$transparent_background)
  spec$seed <- spec$seed %||% NULL
  spec$asset_role <- spec$asset_role %||% NULL
  spec
}

normalize_diagram_spec_body <- function(spec) {
  spec$canvas <- spec$canvas %||% list(
    width = 10,
    height = 6,
    background = "white",
    coordinate_system = "cartesian"
  )
  spec$canvas$theme <- spec$canvas$theme %||% ggai_diagram_theme()
  spec$nodes <- spec$nodes %||% list()
  spec$edges <- spec$edges %||% list()
  spec$annotations <- spec$annotations %||% list()
  normalize_diagram_spec(spec)
}

validate_diagram_spec_body <- function(spec) {
  issues <- character(0)
  nodes <- spec$nodes %||% list()
  if (!length(nodes)) {
    issues <- c(issues, "diagram spec must contain at least one node")
  }
  ids <- vapply(nodes, function(node) node$id %||% "", character(1))
  if (any(!nzchar(ids))) {
    issues <- c(issues, "all diagram nodes must have non-empty ids")
  }
  if (length(unique(ids[nzchar(ids)])) != sum(nzchar(ids))) {
    issues <- c(issues, "diagram node ids must be unique")
  }
  issues
}

validate_glyph_spec_body <- function(spec) {
  issues <- character(0)
  if (!nzchar(spec$prompt %||% "")) {
    issues <- c(issues, "glyph spec must contain a non-empty prompt")
  }
  if (is.null(spec$width) || is.null(spec$height)) {
    issues <- c(issues, "glyph spec must include width and height")
  }
  issues
}
