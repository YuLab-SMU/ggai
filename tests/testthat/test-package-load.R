test_that("ggai exports the prototype entry points", {
  ns <- asNamespace("ggai")

  expect_true(exists("geom_ai", envir = ns, inherits = FALSE))
  expect_true(exists("ggdiagram", envir = ns, inherits = FALSE))
  expect_true(exists("glyph_ai", envir = ns, inherits = FALSE))
  expect_true(exists("prepare_polish_bundle", envir = ns, inherits = FALSE))
  expect_true(exists("polish_figure", envir = ns, inherits = FALSE))
})
