test_that("geom_ai returns a lazy ggplot-add object", {
  x <- geom_ai("highlight top 3 outliers")

  expect_true(is.list(x))
  expect_s3_class(x, "ggai_layer_request")
})

test_that("geom_ai can be added to an existing plot with mocked compiler", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
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
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")

  expect_s3_class(q, "ggplot")
  expect_true(length(q$layers) == 1)
})
