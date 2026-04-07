test_that("plot context extracts mapped aesthetics and layer types", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  ctx <- ggai:::build_plot_context(p)

  expect_true("x" %in% ctx$mapped_aes)
  expect_true("y" %in% ctx$mapped_aes)
  expect_true("point" %in% ctx$geoms)
})

test_that("plot context is JSON-safe for ggplot2 S7 objects", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Mileage vs weight", x = "Weight", y = "MPG")

  ctx <- ggai:::build_plot_context(p)

  expect_no_error(
    jsonlite::toJSON(ctx, auto_unbox = TRUE, null = "null", pretty = TRUE)
  )
  expect_equal(ctx$labels$title, "Mileage vs weight")
})

test_that("layer compiler turns a simple annotation spec into ggplot layers", {
  spec <- list(
    intent = "annotate",
    action = "label",
    target_layer = "plot",
    layers = list(
      list(
        geom = "text",
        stat = "identity",
        mapping = list(x = "wt", y = "mpg", label = "carb"),
        params = list(colour = "red"),
        inherit_aes = FALSE
      )
    ),
    annotations = list(),
    warnings = list()
  )

  layers <- ggai:::compile_layer_spec_to_layers(spec, data = mtcars)

  expect_true(length(layers) == 1)
  expect_s3_class(layers[[1]], "Layer")
})
