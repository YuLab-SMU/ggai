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

# ---- composite (patchwork) engine ----------------------------------------

test_that("patchwork composite is detected and rendered as composite engine", {
  skip_if_not_installed("patchwork")
  out <- local_temp_outdir()
  code <- 'suppressMessages({library(patchwork); library(ggplot2)})
p1 <- ggplot(mtcars, aes(mpg, wt)) + geom_point()
p2 <- ggplot(mtcars, aes(hp)) + geom_histogram(bins = 12)
p1 + p2'
  a <- ggai_execute_and_capture(code, output_dir = out)

  expect_identical(a$engine, "composite")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))
})

test_that("inspect_composite walks patchwork patches with correct visual ordering", {
  skip_if_not_installed("patchwork")
  out <- local_temp_outdir()
  # Distinct layer counts so we can verify per-panel ordering: 1, 2, 3.
  code <- 'suppressMessages({library(patchwork); library(ggplot2)})
p1 <- ggplot(mtcars, aes(mpg, wt)) + geom_point()
p2 <- ggplot(mtcars, aes(hp)) + geom_histogram(bins = 10) + geom_vline(xintercept = 150)
p3 <- ggplot(mtcars, aes(qsec, mpg)) + geom_point() + geom_smooth(method = "lm") + geom_rug()
p1 + p2 + p3'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "composite")
  expect_identical(info$n_panels, 3L)
  expect_false(info$is_container)
  # +-built: patches first, self last. Visual order p1 / p2 / p3 → 1 / 2 / 3 layers.
  expect_identical(info$panels[[1L]]$kind, "ggplot")
  expect_identical(info$panels[[1L]]$n_layers, 1L)
  expect_identical(info$panels[[2L]]$kind, "ggplot")
  expect_identical(info$panels[[2L]]$n_layers, 2L)
  expect_identical(info$panels[[3L]]$kind, "patchwork_self")
  expect_identical(info$panels[[3L]]$n_layers, 3L)
  expect_identical(info$total_leaf_layers, 6L)
})

test_that("inspect_composite handles container patchworks (patchwork-of-patchworks)", {
  skip_if_not_installed("patchwork")
  out <- local_temp_outdir()
  # A true container is produced when one operand of `|` or `/` is itself
  # a patchwork. The outer patchwork has no own ggplot identity.
  # Note: wrap_plots() and bare `p1 | p2` between ggplots are +-built,
  # not containers.
  code <- 'suppressMessages({library(patchwork); library(ggplot2)})
p1 <- ggplot(mtcars, aes(mpg, wt)) + geom_point()
p2 <- ggplot(mtcars, aes(hp)) + geom_histogram(bins = 10)
p3 <- ggplot(mtcars, aes(qsec)) + geom_density()
# Force the container path: outer | takes a ggplot and a patchwork.
p1 | (p2 + p3)'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "composite")
  expect_true(info$is_container)
  expect_identical(info$n_panels, 2L)
  expect_match(info$summary, "container", fixed = TRUE)
  expect_identical(info$panels[[1L]]$kind, "ggplot")
  expect_identical(info$panels[[2L]]$kind, "nested_patchwork")
})

test_that("inspect_composite recurses into nested patchworks", {
  skip_if_not_installed("patchwork")
  out <- local_temp_outdir()
  # p1 | (p2 / p3) — outer is container; inner (p2/p3) is +-built.
  code <- 'suppressMessages({library(patchwork); library(ggplot2)})
p1 <- ggplot(mtcars, aes(mpg, wt)) + geom_point()
p2 <- ggplot(mtcars, aes(hp)) + geom_histogram(bins = 10)
p3 <- ggplot(mtcars, aes(qsec, mpg)) + geom_point() + geom_smooth(method = "lm")
p1 | (p2 / p3)'
  a <- ggai_execute_and_capture(code, output_dir = out)

  info <- ggai_inspect_artifact(a)
  expect_identical(info$engine, "composite")
  expect_true(info$is_container)
  expect_identical(info$n_panels, 2L)
  expect_identical(info$panels[[1L]]$kind, "ggplot")
  expect_identical(info$panels[[1L]]$n_layers, 1L)
  expect_identical(info$panels[[2L]]$kind, "nested_patchwork")
  expect_identical(info$panels[[2L]]$n_panels, 2L)
  expect_length(info$panels[[2L]]$panels, 2L)
  # Total leaf layers should equal p1 (1) + p2 (1) + p3 (2) = 4
  expect_identical(info$total_leaf_layers, 4L)
})

# ---- htmlwidget engine ----------------------------------------------------

test_that("htmlwidget artifact: detect / render-to-html / inspect / validate", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")
  out <- local_temp_outdir()
  code <- 'suppressMessages(library(plotly))
plot_ly(mtcars, x = ~mpg, y = ~wt, type = "scatter", mode = "markers")'

  a2 <- ggai_execute_and_capture(code, output_dir = out, format = "html")
  expect_identical(a2$engine, "htmlwidget")
  expect_true("html" %in% names(a2$rendered))

  info <- ggai_inspect_artifact(a2)
  expect_identical(info$engine, "htmlwidget")
  expect_identical(info$widget_name, "plotly")
  expect_true(info$has_data_payload)

  v <- ggai_validate_artifact(a2)
  expect_identical(v$status, "ok")
})

test_that("htmlwidget PNG path via webshot2 (when installed)", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("webshot2")
  skip_if_not_installed("chromote")
  # Skip if no Chrome / Chromium available — webshot2 can't render without it.
  chrome <- tryCatch(chromote::find_chrome(), error = function(e) NULL)
  skip_if(is.null(chrome), "no Chrome / Chromium found via chromote::find_chrome()")

  out <- local_temp_outdir()
  code <- 'suppressMessages(library(plotly))
plot_ly(mtcars, x = ~mpg, y = ~wt, type = "scatter", mode = "markers")'

  a <- ggai_execute_and_capture(code, output_dir = out, format = "png",
                                width = 800L, height = 600L)
  expect_identical(a$engine, "htmlwidget")
  expect_true("png" %in% names(a$rendered))
  expect_true(file.exists(a$rendered$png))
  expect_gt(file.info(a$rendered$png)$size, 1000L)
})

# The webshot2-missing fallback (PNG → HTML with a warning) was extensively
# exercised in P4.b and P5 against the user's environment before webshot2
# was installed. A faithful in-process simulation of "webshot2 missing"
# requires either uninstalling the package or mocking `requireNamespace`,
# both of which are intrusive enough that the in-line P4.b/P5 evidence
# is the better record. See dev_logs/2026-05-17-p6b-polish.md.

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
