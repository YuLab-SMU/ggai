test_that("geom_point_ai returns a layer object", {
  local_mocked_bindings(
    generate_glyph_for_geom = function(...) {
      structure(
        list(path = tempfile(fileext = ".png"), prompt = "cell icon"),
        class = c("ggai_image_asset", "list")
      )
    },
    .package = "ggai"
  )

  layer <- geom_point_ai(prompt = "cell icon")

  expect_s3_class(layer, "Layer")
})
