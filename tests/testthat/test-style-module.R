test_that("layer spec may contain plot operations without layers", {
  spec <- ggai:::normalize_layer_spec_body(list(
    intent = "style",
    action = "retheme",
    target_layer = "plot",
    layers = list(),
    annotations = list(),
    plot_ops = list(
      list(op = "labels", params = list(title = "Styled plot"))
    ),
    warnings = list()
  ))

  expect_equal(ggai:::validate_layer_spec_body(spec), character(0))
})

test_that("render_spec_compiled applies plot theme and label ops", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "style",
      action = "retheme",
      target_layer = "plot",
      layers = list(),
      annotations = list(),
      plot_ops = list(
        list(op = "labels", params = list(title = "My Title", x = "Weight", y = "MPG")),
        list(op = "theme", params = list(legend.position = "bottom"))
      ),
      warnings = list()
    ),
    kind = "layer",
    instruction = "move legend to bottom and add title"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) + ggplot2::geom_point()
  out <- render_spec_compiled(compiled, plot = p)

  expect_equal(out$labels$title, "My Title")
  expect_equal(out$labels$x, "Weight")
  expect_equal(out$labels$y, "MPG")
})

test_that("render_spec_compiled applies manual scales", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "style",
      action = "rescale",
      target_layer = "plot",
      layers = list(),
      annotations = list(),
      plot_ops = list(
        list(op = "scale_colour", params = list(values = c("4" = "#377EB8", "6" = "#4DAF4A", "8" = "#E41A1C")))
      ),
      warnings = list()
    ),
    kind = "layer",
    instruction = "use custom colours"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) + ggplot2::geom_point()
  out <- render_spec_compiled(compiled, plot = p)

  expect_true(length(out$scales$scales) >= 1)
})

test_that("session merge keeps plot operations", {
  current <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(),
      annotations = list(),
      plot_ops = list(list(op = "labels", params = list(title = "A"))),
      warnings = list()
    ),
    kind = "layer",
    instruction = "title a"
  )
  new <- ggai:::new_compiled_spec(
    spec = list(
      intent = "style",
      action = "retheme",
      target_layer = "plot",
      layers = list(),
      annotations = list(),
      plot_ops = list(list(op = "theme", params = list(legend.position = "bottom"))),
      warnings = list()
    ),
    kind = "layer",
    instruction = "legend bottom"
  )

  merged <- ggai:::merge_layer_compiled_specs(current, new)
  expect_equal(length(merged$spec$plot_ops), 2)
})
