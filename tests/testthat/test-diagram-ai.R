test_that("geom_ai can add a compiled diagram spec to a diagram canvas", {
  local_mocked_bindings(
    compile_diagram_spec = function(...) {
      list(
        canvas = list(
          width = 10,
          height = 6,
          background = "white",
          coordinate_system = "cartesian",
          layout = list(engine = "constraint", direction = "horizontal")
        ),
        nodes = list(
          list(id = "n1", kind = "box", label = "Node", style = list(fill = "#EEEEEE"), layout = list(stage = 1, lane = "main")),
          list(id = "n2", kind = "rounded_box", label = "Next", style = list(fill = "#FFF1D6"), layout = list(after = "n1", lane = "main"))
        ),
        edges = list(
          list(from = "n1", to = "n2", arrow = TRUE, style = list(colour = "#333"), route = "straight")
        ),
        annotations = list()
      )
    },
    .package = "ggai"
  )

  p <- ggdiagram()
  q <- p + geom_ai("draw a simple node")

  expect_s3_class(q, "ggplot")
  expect_true(length(q$layers) >= 1)
  raw <- inspect_spec(q, raw = TRUE)
  expect_equal(raw$nodes[[2]]$layout$after, "n1")
})
