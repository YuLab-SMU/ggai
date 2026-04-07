#' Schema for a generated glyph spec
#'
#' @return A `z_schema` object.
#' @export
z_ggai_glyph_spec <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    prompt = z$z_string(description = "Primary image-generation prompt"),
    style = z$z_string(description = "Visual style preset", nullable = TRUE),
    negative_prompt = z$z_string(
      description = "Negative prompt to avoid undesired content",
      nullable = TRUE
    ),
    width = z$z_number(description = "Requested output width in pixels"),
    height = z$z_number(description = "Requested output height in pixels"),
    transparent_background = z$z_boolean(
      description = "Whether to request a transparent background",
      default = TRUE
    ),
    seed = z$z_string(description = "Optional reproducibility seed", nullable = TRUE),
    asset_role = z$z_string(
      description = "Intended usage such as point_mark or diagram_node",
      nullable = TRUE
    ),
    .required = c("prompt", "width", "height", "transparent_background")
  )
}
