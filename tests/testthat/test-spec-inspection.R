test_that("inspect_spec summarizes a compiled layer request", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(
            geom = "text",
            mapping = list(x = "wt", y = "mpg", label = "carb"),
            params = list(colour = "red"),
            inherit_aes = FALSE
          )
        ),
        annotations = list(),
        warnings = list("demo warning")
      )
    },
    .package = "ggai"
  )

  req <- geom_ai("label a few points")
  info <- inspect_spec(req, plot = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))

  expect_equal(info$kind, "layer")
  expect_equal(info$layer_count, 1)
  expect_equal(info$geoms[[1]], "text")
})

test_that("as_code exports layer specs as ggplot code", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(
          geom = "text",
          mapping = list(x = "wt", y = "mpg", label = "carb"),
          params = list(colour = "red"),
          inherit_aes = FALSE
        )
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label a few points"
  )

  code <- as_code(compiled)

  expect_match(code, "ggplot2::geom_text")
  expect_match(code, "ggplot2::aes\\(")
  expect_match(code, "label = carb")
  expect_match(code, "\n    mapping = ")
})

test_that("as_code exports diagram specs as reproducible R code", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
      nodes = list(
        list(id = "n1", kind = "box", label = "Node", x = 3, y = 3, width = 2, height = 1, style = list(fill = "#EEE"))
      ),
      edges = list(),
      annotations = list()
    ),
    kind = "diagram",
    instruction = "draw a node"
  )

  code <- as_code(compiled)

  expect_match(code, "ggai::ggdiagram")
  expect_match(code, "ggai::add_diagram_spec")
})

test_that("plots keep compiled ggai history for later export", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(
            geom = "text",
            mapping = list(x = "wt", y = "mpg", label = "carb"),
            params = list(colour = "red"),
            inherit_aes = FALSE
          )
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")
  info <- inspect_spec(q)
  code <- as_code(q)

  expect_equal(info$kind, "layer")
  expect_match(code, "ggplot2::geom_text")
})

test_that("update_spec can patch a compiled layer spec", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(
          geom = "text",
          mapping = list(x = "wt", y = "mpg", label = "carb"),
          params = list(colour = "red"),
          inherit_aes = FALSE
        )
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label a few points"
  )

  updated <- update_spec(compiled, list(layers = list(list(params = list(colour = "blue")))))

  expect_equal(updated$spec$layers[[1]]$params$colour, "blue")
})

test_that("edit_spec can transform a compiled diagram spec", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
      nodes = list(
        list(id = "n1", kind = "box", label = "Node", x = 3, y = 3, width = 2, height = 1, style = list(fill = "#EEE"))
      ),
      edges = list(),
      annotations = list()
    ),
    kind = "diagram",
    instruction = "draw a node"
  )

  updated <- edit_spec(compiled, function(spec) {
    spec$nodes[[1]]$label <- "Edited"
    spec
  })

  expect_equal(updated$spec$nodes[[1]]$label, "Edited")
})

test_that("edit_spec can rerender a plot with updated spec history", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(
            geom = "text",
            mapping = list(x = "wt", y = "mpg", label = "carb"),
            params = list(colour = "red"),
            inherit_aes = FALSE
          )
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")
  q2 <- update_spec(q, list(layers = list(list(params = list(colour = "blue")))))

  info <- inspect_spec(q2, raw = TRUE)
  expect_equal(info$layers[[1]]$params$colour, "blue")
})

test_that("spec_history exposes versioned plot history", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(
            geom = "text",
            mapping = list(x = "wt", y = "mpg", label = "carb"),
            params = list(colour = "red"),
            inherit_aes = FALSE
          )
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")
  hist <- spec_history(q)

  expect_equal(nrow(hist), 1)
  expect_equal(hist$version[[1]], 1L)
  expect_equal(hist$kind[[1]], "layer")
})
