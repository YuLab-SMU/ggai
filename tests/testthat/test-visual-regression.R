test_that("diagram renderer stays visually stable", {
  skip_if_not_installed("vdiffr")

  p <- ggdiagram()
  spec <- list(
    canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
    nodes = list(
      list(id = "input", kind = "box", label = "Input", x = 2, y = 3, width = 1.8, height = 0.8, style = list(fill = "#E8F3FF")),
      list(id = "model", kind = "rounded_box", label = "Model", x = 5, y = 3, width = 2.2, height = 1, style = list(fill = "#FFF1D6"))
    ),
    edges = list(
      list(from = "input", to = "model", label = NULL, arrow = TRUE, style = list(colour = "#334455"), route = "straight")
    ),
    annotations = list()
  )

  q <- ggai:::add_diagram_spec(p, spec)
  vdiffr::expect_doppelganger("basic-diagram-scene", q)
})
