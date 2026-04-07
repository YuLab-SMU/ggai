ggai_schema_funs <- function() {
  list(
    z_any = ggai_aisdk("z_any"),
    z_any_object = ggai_aisdk("z_any_object"),
    z_array = ggai_aisdk("z_array"),
    z_boolean = ggai_aisdk("z_boolean"),
    z_enum = ggai_aisdk("z_enum"),
    z_number = ggai_aisdk("z_number"),
    z_object = ggai_aisdk("z_object"),
    z_string = ggai_aisdk("z_string")
  )
}

ggai_layer_item_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    geom = z$z_string(description = "ggplot2 geom name such as point or text"),
    stat = z$z_string(
      description = "ggplot2 stat name",
      nullable = TRUE,
      default = "identity"
    ),
    mapping = z$z_any_object(description = "Aesthetic mapping expressions"),
    data = z$z_any(
      description = "Optional layer-specific data payload or reference",
      nullable = TRUE
    ),
    params = z$z_any_object(description = "Constant layer parameters"),
    inherit_aes = z$z_boolean(
      description = "Whether to inherit plot-level aesthetics",
      nullable = TRUE,
      default = TRUE
    ),
    .required = c("geom", "mapping", "params")
  )
}

ggai_annotation_item_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    type = z$z_string(description = "Annotation type"),
    payload = z$z_any(description = "Annotation payload"),
    .required = c("type", "payload")
  )
}

#' Schema for a layer request
#'
#' @return A `z_schema` object.
#' @export
z_ggai_layer_request <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    instruction = z$z_string(description = "Natural-language layer instruction"),
    target = z$z_enum(
      values = c("layer", "diagram", "glyph"),
      description = "Requested compilation target",
      default = "layer"
    ),
    context = z$z_any_object(description = "Optional plot or scene context"),
    .required = c("instruction", "target", "context")
  )
}

#' Schema for a compiled layer spec
#'
#' @return A `z_schema` object.
#' @export
z_ggai_layer_spec <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    intent = z$z_string(description = "High-level visualization intent"),
    action = z$z_string(description = "Specific action such as highlight or label"),
    target_layer = z$z_string(description = "Target layer identifier or plot"),
    layers = z$z_array(
      ggai_layer_item_schema(),
      description = "Concrete ggplot2 layers to add"
    ),
    annotations = z$z_array(
      ggai_annotation_item_schema(),
      description = "Non-layer annotations or side effects"
    ),
    warnings = z$z_array(
      z$z_string(description = "Compilation warnings"),
      description = "Warnings returned by the compiler"
    ),
    .required = c("intent", "action", "target_layer", "layers", "annotations", "warnings")
  )
}
