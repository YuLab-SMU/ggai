test_that("diagram renderer creates grobs for nodes and edges", {
  spec <- list(
    canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
    nodes = list(
      list(
        id = "a",
        kind = "box",
        label = "Encoder",
        x = 2,
        y = 3,
        width = 2,
        height = 1,
        style = list(fill = "#DDEEFF")
      )
    ),
    edges = list(),
    annotations = list()
  )

  grob <- ggai:::render_diagram_spec(spec)

  expect_s3_class(grob, "grob")
  expect_true(length(grob$children) >= 1)
})

test_that("diagram auto layout assigns coordinates when omitted", {
  spec <- list(
    canvas = list(
      width = 12,
      height = 6,
      background = "white",
      coordinate_system = "cartesian",
      layout = list(engine = "flow", direction = "horizontal")
    ),
    nodes = list(
      list(id = "a", kind = "box", label = "Input", style = list(fill = "#EEE"), layout = list(order = 1, lane = "top")),
      list(id = "b", kind = "rounded_box", label = "Model", style = list(fill = "#DDD"), layout = list(order = 2, lane = "bottom"))
    ),
    edges = list(
      list(from = "a", to = "b", arrow = TRUE, style = list(colour = "#333"), route = "straight")
    ),
    annotations = list()
  )

  normalized <- ggai:::normalize_diagram_spec(spec)

  expect_true(all(vapply(normalized$nodes, function(node) !is.null(node$x) && !is.null(node$y), logical(1))))
  expect_true(normalized$nodes[[1]]$x < normalized$nodes[[2]]$x)
})

test_that("constraint layout resolves after relations into stage ordering", {
  spec <- list(
    canvas = list(
      width = 12,
      height = 6,
      background = "white",
      coordinate_system = "cartesian",
      layout = list(engine = "constraint", direction = "horizontal")
    ),
    nodes = list(
      list(id = "query", kind = "box", label = "Query", style = list(fill = "#EEE"), layout = list(stage = 1, lane = "main")),
      list(id = "retriever", kind = "rounded_box", label = "Retriever", style = list(fill = "#DDD"), layout = list(after = "query", lane = "main")),
      list(id = "memory", kind = "box", label = "Memory", style = list(fill = "#CCC"), layout = list(after = "retriever", lane = "support", group = "memory"))
    ),
    edges = list(),
    annotations = list()
  )

  normalized <- ggai:::normalize_diagram_spec(spec)

  expect_equal(normalized$nodes[[2]]$layout$stage, normalized$nodes[[1]]$layout$stage + 1)
  expect_equal(normalized$nodes[[3]]$layout$stage, normalized$nodes[[2]]$layout$stage + 1)
  expect_true(normalized$nodes[[1]]$x < normalized$nodes[[2]]$x)
  expect_true(normalized$nodes[[2]]$x < normalized$nodes[[3]]$x)
})

test_that("alignment and center_on constraints adjust resolved coordinates", {
  spec <- list(
    canvas = list(
      width = 12,
      height = 6,
      background = "white",
      coordinate_system = "cartesian",
      layout = list(engine = "constraint", direction = "horizontal")
    ),
    nodes = list(
      list(id = "a", kind = "box", label = "A", style = list(fill = "#EEE"), layout = list(stage = 1, lane = "main", order = 1)),
      list(id = "b", kind = "rounded_box", label = "B", style = list(fill = "#DDD"), layout = list(after = "a", lane = "main", order = 2, align = list(with = "a", axis = "y"))),
      list(id = "c", kind = "box", label = "C", style = list(fill = "#CCC"), layout = list(lane = "support", order = 3, center_on = list(with = "b", axis = "x")))
    ),
    edges = list(),
    annotations = list()
  )

  normalized <- ggai:::normalize_diagram_spec(spec)

  expect_equal(normalized$nodes[[2]]$y, normalized$nodes[[1]]$y)
  expect_equal(normalized$nodes[[3]]$x, normalized$nodes[[2]]$x)
})

test_that("canvas distribution evenly spaces nodes within a lane", {
  spec <- list(
    canvas = list(
      width = 12,
      height = 6,
      background = "white",
      coordinate_system = "cartesian",
      layout = list(
        engine = "constraint",
        direction = "horizontal",
        distribute = list(axis = "x", within = "lane", by = "order")
      )
    ),
    nodes = list(
      list(id = "a", kind = "box", label = "A", style = list(fill = "#EEE"), layout = list(stage = 1, lane = "main", order = 1)),
      list(id = "b", kind = "box", label = "B", style = list(fill = "#DDD"), layout = list(stage = 2, lane = "main", order = 2)),
      list(id = "c", kind = "box", label = "C", style = list(fill = "#CCC"), layout = list(stage = 3, lane = "main", order = 3))
    ),
    edges = list(),
    annotations = list()
  )

  normalized <- ggai:::normalize_diagram_spec(spec)
  xs <- vapply(normalized$nodes, function(node) node$x, numeric(1))
  gaps <- diff(xs)

  expect_equal(round(gaps[[1]], 5), round(gaps[[2]], 5))
})

test_that("diagram theme preset is applied during normalization", {
  spec <- list(
    canvas = list(width = 10, height = 6, background = NULL, theme = "blueprint", coordinate_system = "cartesian"),
    nodes = list(
      list(id = "a", kind = "box", label = "A", style = list(), layout = list(order = 1))
    ),
    edges = list(
      list(from = "a", to = "a", arrow = FALSE, style = list(), route = "straight")
    ),
    annotations = list()
  )

  normalized <- ggai:::normalize_diagram_spec(spec)

  expect_equal(normalized$canvas$theme, "blueprint")
  expect_equal(normalized$nodes[[1]]$style$fill, "#DCEEFF")
  expect_equal(normalized$edges[[1]]$style$colour, "#1565C0")
})
