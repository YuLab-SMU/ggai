# Layer 2 — inspect / validate / render dispatchers for each supported engine.

skip_if_not_installed("ggplot2")

local_temp_outdir <- function() {
  path <- file.path(tempdir(), paste0("ggai_test_", as.integer(Sys.time())))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(path, recursive = TRUE), envir = parent.frame())
  path
}

# ---- inspect --------------------------------------------------------------

test_that("ggai_inspect_artifact returns ggplot-shaped info for ggplot", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "ggplot")
  expect_true(info$n_layers >= 1L)
  expect_true("plot_context" %in% info$available)
})

test_that("ggai_inspect_artifact returns grob-shaped info for grid", {
  out <- local_temp_outdir()
  code <- 'grid::rectGrob()'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "grid")
  expect_true("n_grobs" %in% info$available)
})

test_that("ggai_inspect_artifact returns recordedplot-shaped info for base", {
  out <- local_temp_outdir()
  code <- 'plot(1:5)'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "base")
  expect_true("n_operations" %in% info$available)
  expect_gt(info$n_operations, 0L)
})

# ---- validate -------------------------------------------------------------

test_that("ggai_validate_artifact reports ok for a well-formed ggplot", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  a <- ggai_execute_and_capture(code, output_dir = out)

  v <- ggai_validate_artifact(a)
  expect_identical(v$status, "ok")
  expect_identical(v$engine, "ggplot")
})

test_that("ggai_validate_artifact reports error when object is missing", {
  a <- ggai_artifact(code = "ignored", engine = "ggplot")
  v <- ggai_validate_artifact(a)
  expect_identical(v$status, "error")
})

test_that("ggai_validate_artifact rejects non-artifact input", {
  v <- ggai_validate_artifact(list(engine = "ggplot"))
  expect_identical(v$status, "error")
})

# ---- render-existing ------------------------------------------------------

test_that("ggai_render_artifact writes to a chosen path", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  a <- ggai_execute_and_capture(code, output_dir = out)

  target <- file.path(out, "explicit_path.png")
  a2 <- ggai_render_artifact(a, format = "png", path = target)
  expect_true(file.exists(target))
  expect_identical(a2$rendered$png, target)
})

test_that("ggai_render_artifact re-executes when object cache is missing", {
  out <- local_temp_outdir()
  code <- 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  stub <- ggai_artifact(code = code, engine = "ggplot")
  expect_null(stub$object)

  a <- ggai_render_artifact(stub, output_dir = out)
  expect_true(!is.null(a$object))
  expect_true("png" %in% names(a$rendered))
})
