test_that("ggdiagram creates a diagram canvas object", {
  p <- ggdiagram()

  expect_s3_class(p, "ggplot")
  expect_equal(attr(p, "ggai_canvas"), "diagram")
})
