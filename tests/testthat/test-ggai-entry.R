test_that("ggai(data.frame) returns editable session", {
  s <- ggai(mtcars, "show fuel efficiency vs weight, color by cylinders")

  expect_s3_class(s, "ggai_session")
  expect_s3_class(ggai:::session_current_plot(s), "ggplot")
  s2 <- gg_edit(s, 'move legend to bottom')
  expect_s3_class(s2, "ggai_session")
})

test_that("ggai can switch from data grounding into polish mode", {
  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    polish_figure = function(x, instruction = NULL, image_model = NULL, ...) {
      captured$x <- x
      captured$instruction <- instruction
      captured$image_model <- image_model
      structure(list(kind = "polished"), class = "ggai_polished_figure_result")
    },
    .package = "ggai"
  )

  res <- ggai(
    mtcars,
    "show fuel efficiency vs weight, color by cylinders",
    mode = "polish",
    polish_instruction = "make it feel like a premium product figure",
    image_model = "openai:gpt-image-2"
  )

  expect_s3_class(res, "ggai_polished_figure_result")
  expect_s3_class(captured$x, "ggai_session")
  expect_equal(captured$instruction, "make it feel like a premium product figure")
  expect_equal(captured$image_model, "openai:gpt-image-2")
})

test_that("ggai(ggplot) returns session and can edit immediately", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  s <- ggai(p, 'set title to "Fuel efficiency"')

  expect_s3_class(s, "ggai_session")
  raw <- inspect_spec(s, raw = TRUE)
  expect_true(length(raw$plot_ops) >= 1)
})

test_that("ggai can polish an existing ggplot directly", {
  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    polish_figure = function(x, instruction = NULL, image_model = NULL, ...) {
      captured$x <- x
      captured$instruction <- instruction
      captured$image_model <- image_model
      structure(list(kind = "polished"), class = "ggai_polished_figure_result")
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  res <- ggai(p, "make it look like a flagship figure", mode = "polish")

  expect_s3_class(res, "ggai_polished_figure_result")
  expect_s3_class(captured$x, "ggai_session")
  expect_equal(captured$instruction, "make it look like a flagship figure")
})

test_that("ggai(file path) reads csv and returns session", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(mtcars, path, row.names = FALSE)

  s <- ggai(path, "show fuel efficiency vs weight")

  expect_s3_class(s, "ggai_session")
  expect_s3_class(ggai:::session_current_plot(s), "ggplot")
})

test_that("ggai infers boxplot intent from grouped comparison instruction", {
  s <- ggai(mtcars, "compare mpg across cylinders")
  p <- ggai:::session_current_plot(s)
  geoms <- vapply(p$layers, ggai:::geom_name_from_layer, character(1))

  expect_true("boxplot" %in% geoms)
})

test_that("ggai infers histogram intent from distribution instruction", {
  s <- ggai(mtcars, "show distribution of mpg")
  p <- ggai:::session_current_plot(s)
  geoms <- vapply(p$layers, ggai:::geom_name_from_layer, character(1))

  expect_true("bar" %in% geoms)
})

test_that("ggai infers line chart intent from trend instruction", {
  dat <- data.frame(time = 1:10, value = cumsum(rnorm(10)))
  s <- ggai(dat, "show trend over time")
  p <- ggai:::session_current_plot(s)
  geoms <- vapply(p$layers, ggai:::geom_name_from_layer, character(1))

  expect_true("line" %in% geoms)
})
