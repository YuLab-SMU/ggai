test_that("compose_plots creates a layout spec", {
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl), mpg)) + ggplot2::geom_boxplot()

  layout <- compose_plots(p1, p2, ncol = 2, labels = c("A", "B"), title = "Figure 1")

  expect_s3_class(layout, "ggai_layout_spec")
  expect_equal(length(layout$plots), 2)
  expect_equal(layout$ncol, 2)
})

test_that("render_layout returns a grob", {
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_point()

  layout <- compose_plots(p1, p2, ncol = 2)
  grob <- render_layout(layout)

  expect_true(grid::is.grob(grob))
})

test_that("layout spec normalizes rows and columns", {
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_point()
  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(disp, mpg)) + ggplot2::geom_point()

  spec <- ggai:::normalize_layout_spec(compose_plots(p1, p2, p3, ncol = 2))

  expect_equal(spec$nrow, 2)
  expect_equal(spec$ncol, 2)
})
