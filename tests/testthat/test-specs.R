test_that("layer spec schema is a z_schema object", {
  schema <- z_ggai_layer_request()

  expect_s3_class(schema, "z_schema")
})

test_that("diagram spec enumerates node and edge collections", {
  schema <- z_ggai_diagram_spec()
  props <- names(schema$properties)

  expect_true(all(c("nodes", "edges", "canvas") %in% props))
})

test_that("glyph spec supports asset generation metadata", {
  schema <- z_ggai_glyph_spec()
  props <- names(schema$properties)

  expect_true(all(c("prompt", "style", "width", "height") %in% props))
})
