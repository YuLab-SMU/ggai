test_that("measure_plot_canvas returns positive size", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  measured <- ggai:::measure_plot_canvas(p)

  expect_true(measured$width > 0)
  expect_true(measured$height > 0)
  expect_true(grid::is.grob(measured$gtable))
})

test_that("ensure_r_package succeeds for installed packages", {
  expect_invisible(ggai:::ensure_r_package("ggplot2"))
})

test_that("save_fixed_plot delegates to ggsave with measured canvas", {
  path <- tempfile(fileext = ".png")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    panel_sized_plot = function(plot, panel_w = 5, panel_h = 5, units = "cm") plot,
    measure_plot_canvas = function(plot, units = "cm") list(gtable = ggplot2::ggplotGrob(plot), width = 10, height = 8),
    .package = "ggai"
  )

  local_mocked_bindings(
    ggsave = function(filename, plot, width, height, units, dpi) {
      captured$filename <- filename
      captured$width <- width
      captured$height <- height
      captured$units <- units
      captured$dpi <- dpi
      invisible(NULL)
    },
    .package = "ggplot2"
  )

  out <- save_fixed_plot(p, path, panel_w = 4, panel_h = 4)

  expect_equal(captured$filename, path)
  expect_equal(captured$units, "cm")
  expect_equal(captured$dpi, 300)
  expect_equal(out$width, 10)
  expect_equal(out$height, 8)
})
