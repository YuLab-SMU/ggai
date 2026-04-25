test_that("deterministic style compiler extracts title and legend position", {
  compiled <- ggai:::deterministic_style_spec('set title to "Fuel efficiency" and move legend to bottom')

  expect_s3_class(compiled, "ggai_compiled_spec")
  expect_equal(compiled$spec$plot_ops[[1]]$op, "labels")
  expect_equal(compiled$spec$plot_ops[[1]]$params$title, "Fuel efficiency")
  expect_equal(compiled$spec$plot_ops[[2]]$op, "theme")
  expect_equal(compiled$spec$plot_ops[[2]]$params$legend.position, "bottom")
})

test_that("deterministic style compiler extracts axis labels", {
  compiled <- ggai:::deterministic_style_spec('change x axis label to "Weight (1000 lbs)"')

  expect_equal(compiled$spec$plot_ops[[1]]$op, "labels")
  expect_equal(compiled$spec$plot_ops[[1]]$params$x, "Weight (1000 lbs)")
})

test_that("deterministic style compiler extracts axis ranges", {
  compiled <- ggai:::deterministic_style_spec('set y axis range to 10 to 40')

  expect_equal(compiled$spec$plot_ops[[1]]$op, "scale_y")
  expect_equal(compiled$spec$plot_ops[[1]]$params$limits, c(10, 40))
})

test_that("gg_edit applies deterministic style edits without model compilation", {
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) + ggplot2::geom_point())
  s <- gg_edit(s, 'move legend to bottom and set title to "Fuel efficiency"')

  raw <- inspect_spec(s, raw = TRUE)
  expect_true(length(raw$plot_ops) >= 2)
  expect_equal(raw$plot_ops[[1]]$op, "labels")
  expect_equal(raw$plot_ops[[2]]$op, "theme")
})

test_that("compile_ggai_request uses deterministic style compiler for style-only requests", {
  req <- new_layer_ai_request("move legend to bottom")
  compiled <- ggai:::compile_ggai_request(req, plot = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))

  expect_s3_class(compiled, "ggai_compiled_spec")
  expect_equal(compiled$spec$plot_ops[[1]]$op, "theme")
})

test_that("deterministic style compiler supports theme presets", {
  compiled <- ggai:::deterministic_style_spec("use theme_classic")
  expect_equal(compiled$spec$plot_ops[[1]]$op, "theme_preset")
  expect_equal(compiled$spec$plot_ops[[1]]$params$name, "classic")
})

test_that("deterministic style compiler supports legend title", {
  compiled <- ggai:::deterministic_style_spec('set legend title to "Cylinders"')
  expect_equal(compiled$spec$plot_ops[[1]]$op, "labels")
  expect_equal(compiled$spec$plot_ops[[1]]$params$colour, "Cylinders")
})

test_that("deterministic style compiler supports axis breaks and transforms", {
  compiled <- ggai:::deterministic_style_spec("set x axis breaks to 2 3 4 and use log10 y axis")
  x_ops <- Filter(function(op) identical(op$op, "scale_x") && !is.null(op$params$breaks), compiled$spec$plot_ops)
  y_ops <- Filter(function(op) identical(op$op, "scale_y") && identical(op$params$trans, "log10"), compiled$spec$plot_ops)
  expect_equal(x_ops[[1]]$params$breaks, c(2, 3, 4))
  expect_equal(y_ops[[1]]$params$trans, "log10")
})

test_that("deterministic style compiler supports named discrete palettes", {
  compiled <- ggai:::deterministic_style_spec("use Set1 palette for colours")
  expect_equal(compiled$spec$plot_ops[[1]]$op, "scale_colour")
  expect_true(length(compiled$spec$plot_ops[[1]]$params$values) >= 3)
})

test_that("deterministic style compiler supports legend sizing", {
  compiled <- ggai:::deterministic_style_spec("set legend key size to 12 and legend text size to 9 and legend title size to 11")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 3)
})

test_that("deterministic style compiler supports axis text rotation", {
  compiled <- ggai:::deterministic_style_spec("rotate x axis text 45 degrees")
  expect_equal(compiled$spec$plot_ops[[1]]$op, "theme")
  expect_true(!is.null(compiled$spec$plot_ops[[1]]$params$axis.text.x))
})

test_that("deterministic style compiler supports grid toggles", {
  compiled <- ggai:::deterministic_style_spec("turn off minor grid and show major grid")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 2)
})

test_that("deterministic style compiler aligns fill palette and legend title", {
  compiled <- ggai:::deterministic_style_spec('use Set2 palette for fill and set legend title to "Group"')
  op_names <- vapply(compiled$spec$plot_ops, function(op) op$op, character(1))
  expect_true("scale_fill" %in% op_names)
  label_ops <- Filter(function(op) identical(op$op, "labels"), compiled$spec$plot_ops)
  expect_equal(label_ops[[1]]$params$fill, "Group")
})

test_that("deterministic style compiler supports plot title subtitle caption sizing", {
  compiled <- ggai:::deterministic_style_spec("set plot title size to 16 and subtitle size to 12 and caption size to 10")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 3)
})

test_that("deterministic style compiler supports axis title and text sizing", {
  compiled <- ggai:::deterministic_style_spec("set x axis title size to 14 and y axis text size to 9")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 2)
})

test_that("deterministic style compiler supports facet strip styling", {
  compiled <- ggai:::deterministic_style_spec("set strip text size to 11 and strip background blue")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 2)
})

test_that("deterministic style compiler supports panel and background styling", {
  compiled <- ggai:::deterministic_style_spec("set panel background blue and remove panel border")
  theme_ops <- Filter(function(op) identical(op$op, "theme"), compiled$spec$plot_ops)
  expect_true(length(theme_ops) >= 2)
})
