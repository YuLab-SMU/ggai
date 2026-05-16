test_that("geom_ai returns a lazy ggplot-add object", {
  x <- geom_ai("highlight top 3 outliers")

  expect_true(is.list(x))
  expect_s3_class(x, "ggai_layer_request")
  expect_identical(x$instruction, "highlight top 3 outliers")
  expect_identical(x$target, "layer")
})

test_that("geom_ai rejects empty instructions", {
  expect_error(geom_ai(""), "non-empty")
})

test_that("p + geom_ai requires an agentic model", {
  skip_if_not_installed("withr")
  withr::local_options(list(ggai.language_model = NULL, ggai.agentic_edit = FALSE))
  withr::local_envvar(c(GGAI_LANGUAGE_MODEL = NA_character_))
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))

  expect_error(p + geom_ai("label a few points"), "agentic language model")
})
