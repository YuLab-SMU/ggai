# Layer 2 — ggai_artifact constructor, predicates, and print method.

test_that("ggai_artifact() builds a valid object with auto-generated id", {
  a <- ggai_artifact(
    code = "p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()",
    engine = "ggplot"
  )
  expect_s3_class(a, "ggai_artifact")
  expect_true(is_ggai_artifact(a))
  expect_identical(a$engine, "ggplot")
  expect_true(is.character(a$id) && nzchar(a$id))
  expect_true(grepl("^fig_", a$id))
})

test_that("ggai_artifact() preserves user-supplied id", {
  a <- ggai_artifact(code = "plot(1:10)", engine = "base", id = "fixture_001")
  expect_identical(a$id, "fixture_001")
})

test_that("ggai_artifact() rejects bad input", {
  expect_error(
    ggai_artifact(code = c("a", "b"), engine = "ggplot"),
    "single character"
  )
  expect_error(
    ggai_artifact(code = "ok", engine = ""),
    "non-empty"
  )
  expect_error(
    ggai_artifact(code = NULL, engine = "ggplot"),
    "single character"
  )
})

test_that("is_ggai_artifact() returns FALSE for non-artifacts", {
  expect_false(is_ggai_artifact(list(code = "x")))
  expect_false(is_ggai_artifact(NULL))
  expect_false(is_ggai_artifact(42L))
})

test_that("print.ggai_artifact does not error and exposes engine", {
  a <- ggai_artifact(
    code = "plot(1:10)",
    engine = "base",
    packages = c("graphics", "grDevices")
  )
  out <- capture.output(print(a))
  expect_true(any(grepl("ggai_artifact", out)))
  expect_true(any(grepl("base", out)))
  expect_true(any(grepl("graphics", out)))
})

test_that("default rendered / packages / data_refs slots are coerced", {
  a <- ggai_artifact(code = "1", engine = "unknown")
  expect_identical(a$rendered, list())
  expect_identical(a$packages, character())
  expect_identical(a$data_refs, list())
  expect_identical(a$inspect, list())
})
