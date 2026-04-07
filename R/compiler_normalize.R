normalize_layer_item <- function(layer) {
  layer$geom <- layer$geom %||% "text"
  layer$stat <- layer$stat %||% "identity"
  layer$mapping <- layer$mapping %||% list()
  layer$params <- layer$params %||% list()
  layer$inherit_aes <- if (is.null(layer$inherit_aes)) TRUE else isTRUE(layer$inherit_aes)
  layer
}

normalize_layer_spec_body <- function(spec) {
  spec$intent <- spec$intent %||% "annotate"
  spec$action <- spec$action %||% "annotate"
  spec$target_layer <- spec$target_layer %||% "plot"
  spec$layers <- lapply(spec$layers %||% list(), normalize_layer_item)
  spec$annotations <- spec$annotations %||% list()
  spec$warnings <- spec$warnings %||% list()
  spec
}

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

validate_layer_spec_body <- function(spec) {
  issues <- character(0)
  if (!length(spec$layers %||% list())) {
    issues <- c(issues, "spec must contain at least one layer")
  }
  for (i in seq_along(spec$layers %||% list())) {
    layer <- spec$layers[[i]]
    if (is.null(layer$geom) || !nzchar(layer$geom %||% "")) {
      issues <- c(issues, paste0("layer ", i, " is missing geom"))
    }
  }
  issues
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

validate_compiled_spec_by_kind <- function(spec, kind) {
  switch(
    kind,
    layer = validate_layer_spec_body(spec),
    diagram = validate_diagram_spec_body(spec),
    glyph = validate_glyph_spec_body(spec),
    character(0)
  )
}

normalize_compiled_spec_by_kind <- function(spec, kind) {
  switch(
    kind,
    layer = normalize_layer_spec_body(spec),
    diagram = normalize_diagram_spec_body(spec),
    glyph = normalize_glyph_spec_body(spec),
    spec
  )
}
