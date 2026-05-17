# Layer 2 — engine auto-detection and end-to-end execute → capture → render.

skip_if_not_installed("ggplot2")

local_temp_outdir <- function() {
  path <- file.path(tempdir(), paste0("ggai_test_", as.integer(Sys.time())))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(path, recursive = TRUE), envir = parent.frame())
  path
}

test_that("ggplot engine is detected and rendered to PNG", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  a <- ggai_execute_and_capture(code, output_dir = out)
  expect_s3_class(a, "ggai_artifact")
  expect_identical(a$engine, "ggplot")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))
  expect_gt(file.info(a$rendered$png)$size, 0)
})

test_that("base engine is detected via device displaylist", {
  out <- local_temp_outdir()
  code <- 'plot(1:10, 1:10, main = "test")'
  a <- ggai_execute_and_capture(code, output_dir = out)
  expect_identical(a$engine, "base")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))
})

test_that("grid engine is detected from grob return value", {
  out <- local_temp_outdir()
  code <- 'grid::rectGrob(width = 0.5, height = 0.5, gp = grid::gpar(fill = "steelblue"))'
  a <- ggai_execute_and_capture(code, output_dir = out)
  expect_identical(a$engine, "grid")
  expect_true("png" %in% names(a$rendered))
})

test_that("engine_hint overrides auto-detection", {
  out <- local_temp_outdir()
  code <- '1 + 1'
  a <- suppressWarnings(
    ggai_execute_and_capture(code, output_dir = out, engine_hint = "unknown")
  )
  expect_identical(a$engine, "unknown")
})

test_that("evaluation errors are surfaced with code preview", {
  expect_error(
    ggai_execute_and_capture("stop('boom')", output_dir = tempdir()),
    "code evaluation failed"
  )
})

test_that("parse errors are surfaced before evaluation", {
  expect_error(
    ggai_execute_and_capture("foo(", output_dir = tempdir()),
    "parse error"
  )
})

test_that("SVG format is honoured for ggplot", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  a <- ggai_execute_and_capture(code, output_dir = out, format = "svg")
  expect_true("svg" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$svg))
})
