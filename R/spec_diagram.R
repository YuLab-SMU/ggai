ggai_diagram_node_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    id = z$z_string(description = "Unique node identifier"),
    kind = z$z_string(description = "Node kind such as box or image_asset"),
    label = z$z_string(description = "Display label", nullable = TRUE),
    x = z$z_number(description = "Center x position", nullable = TRUE),
    y = z$z_number(description = "Center y position", nullable = TRUE),
    width = z$z_number(description = "Node width", nullable = TRUE),
    height = z$z_number(description = "Node height", nullable = TRUE),
    style = z$z_any_object(description = "Visual style properties"),
    layout = z$z_any_object(description = "Layout DSL hints such as stage, lane, group, order, after, before, row, column, align, and center_on"),
    bio_asset = z$z_any_object(description = "Optional biomedical asset spec for hybrid rendered nodes"),
    asset_ref = z$z_string(
      description = "Optional generated asset reference",
      nullable = TRUE
    ),
    .required = c("id", "kind", "style")
  )
}

ggai_diagram_edge_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    from = z$z_string(description = "Source node identifier"),
    to = z$z_string(description = "Target node identifier"),
    label = z$z_string(description = "Optional edge label", nullable = TRUE),
    arrow = z$z_boolean(description = "Whether the edge ends with an arrow", default = TRUE),
    style = z$z_any_object(description = "Visual style properties"),
    route = z$z_string(description = "Edge route such as straight or elbow"),
    .required = c("from", "to", "arrow", "style", "route")
  )
}

ggai_diagram_canvas_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    width = z$z_number(description = "Canvas width"),
    height = z$z_number(description = "Canvas height"),
    background = z$z_string(description = "Canvas background color"),
    theme = z$z_string(description = "Diagram theme preset", nullable = TRUE),
    coordinate_system = z$z_string(description = "Canvas coordinate system"),
    layout = z$z_any_object(description = "Canvas layout settings such as engine, direction, spacing, margins, and distribute"),
    .required = c("width", "height", "background", "coordinate_system")
  )
}

#' Schema for a compiled diagram scene spec
#'
#' @return A `z_schema` object.
#' @export
z_ggai_diagram_spec <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    canvas = ggai_diagram_canvas_schema(),
    nodes = z$z_array(
      ggai_diagram_node_schema(),
      description = "Diagram nodes"
    ),
    edges = z$z_array(
      ggai_diagram_edge_schema(),
      description = "Diagram edges"
    ),
    annotations = z$z_array(
      ggai_annotation_item_schema(),
      description = "Additional scene annotations"
    ),
    .required = c("canvas", "nodes", "edges", "annotations")
  )
}
