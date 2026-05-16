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

ggai_annotation_item_schema <- function() {
  z <- ggai_schema_funs()

  z$z_object(
    type = z$z_string(description = "Annotation type"),
    payload = z$z_string(description = "Annotation payload summary"),
    .required = c("type", "payload")
  )
}
