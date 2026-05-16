#' Schema for a compiled direct-figure prompt bundle
#'
#' @return A `z_schema` object.
#' @export
z_ggai_figure_prompt_spec <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    title = z$z_string(description = "Short figure title", nullable = TRUE),
    scene_summary = z$z_string(description = "One-paragraph scene summary for the image model"),
    objects = z$z_array(
      z$z_string(description = "Visual objects that should appear in the figure"),
      description = "Named biological or technical objects to depict"
    ),
    relations = z$z_array(
      z$z_string(description = "Spatial or causal relations between objects"),
      description = "Key relations that define the composition"
    ),
    visual_style = z$z_string(description = "Desired visual style for the final figure"),
    composition = z$z_string(description = "Composition guidance for the figure"),
    negative_prompt = z$z_string(description = "What the model should avoid", nullable = TRUE),
    prompt = z$z_string(description = "Final direct-image prompt to send to the image model"),
    .required = c("scene_summary", "objects", "relations", "visual_style", "composition", "prompt")
  )
}
