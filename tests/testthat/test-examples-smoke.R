test_that("example scripts parse without syntax errors", {
  example_path <- function(name) {
    installed <- system.file("extdata", "examples", name, package = "ggai")
    if (nzchar(installed)) {
      return(installed)
    }

    testthat::test_path("..", "..", "inst", "extdata", "examples", name)
  }

  files <- c(
    example_path("scatter_outlier_labels.R"),
    example_path("transformer_diagram.R"),
    example_path("generated_point_glyphs.R")
  )

  for (f in files) {
    expect_no_error(parse(file = f))
  }
})
