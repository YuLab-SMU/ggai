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

# ---- ComplexHeatmap engine ------------------------------------------------

test_that("ComplexHeatmap artifact: detect / render / inspect / validate", {
  skip_if_not_installed("ComplexHeatmap")
  out <- local_temp_outdir()
  code <- 'suppressMessages(library(ComplexHeatmap))
set.seed(1)
m <- matrix(rnorm(50), 10, 5)
rownames(m) <- paste0("gene", 1:10)
colnames(m) <- paste0("sample", 1:5)
Heatmap(m, name = "expr")'
  a <- ggai_execute_and_capture(code, output_dir = out)

  expect_identical(a$engine, "complex_heatmap")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "complex_heatmap")
  expect_identical(info$n_heatmaps, 1L)
  expect_identical(info$heatmaps[[1L]]$name, "expr")
  expect_identical(info$heatmaps[[1L]]$nrow, 10L)
  expect_identical(info$heatmaps[[1L]]$ncol, 5L)

  v <- ggai_validate_artifact(a)
  expect_identical(v$status, "ok")
})

test_that("ComplexHeatmap HeatmapList path is supported", {
  skip_if_not_installed("ComplexHeatmap")
  out <- local_temp_outdir()
  code <- 'suppressMessages(library(ComplexHeatmap))
set.seed(2)
m1 <- matrix(rnorm(40), 8, 5); rownames(m1) <- paste0("g", 1:8); colnames(m1) <- paste0("s", 1:5)
m2 <- m1 + 1
Heatmap(m1, name = "A") + Heatmap(m2, name = "B")'
  a <- ggai_execute_and_capture(code, output_dir = out)

  expect_identical(a$engine, "complex_heatmap")
  info <- ggai_inspect_artifact(a)
  expect_identical(info$n_heatmaps, 2L)
  expect_identical(info$heatmaps[[1L]]$name, "A")
  expect_identical(info$heatmaps[[2L]]$name, "B")
})

# ---- circlize engine ------------------------------------------------------

test_that("circlize artifact: explicit engine_hint, render, inspect, validate", {
  skip_if_not_installed("circlize")
  out <- local_temp_outdir()
  code <- 'suppressMessages(library(circlize))
circos.clear()
circos.par("track.height" = 0.1)
circos.initialize(letters[1:5], xlim = c(0, 10))
circos.track(ylim = c(0, 1),
             panel.fun = function(x, y) circos.rect(0, 0, 10, 1, col = "#cbd5e1"))
circos.clear()
invisible(NULL)'
  a <- ggai_execute_and_capture(code, output_dir = out, engine_hint = "circlize")

  expect_identical(a$engine, "circlize")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "circlize")
  expect_identical(info$engine_kind, "circlize")
  expect_gt(info$n_operations, 0L)

  v <- ggai_validate_artifact(a)
  expect_identical(v$status, "ok")
})
