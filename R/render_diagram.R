default_node_size <- function(kind) {
  switch(
    kind %||% "box",
    text = list(width = 1.6, height = 0.6),
    image_asset = list(width = 1.8, height = 1.8),
    rounded_box = list(width = 2.2, height = 1.0),
    list(width = 2.0, height = 1.0)
  )
}

default_canvas_layout <- function() {
  list(
    engine = "flow",
    direction = "horizontal",
    margin_x = 1.2,
    margin_y = 1.0,
    gap_x = 1.6,
    gap_y = 1.2,
    distribute = NULL
  )
}

default_node_layout <- function(index) {
  list(
    order = index,
    lane = NULL,
    group = NULL,
    stage = NULL,
    after = NULL,
    before = NULL,
    row = NULL,
    column = NULL,
    align = NULL,
    center_on = NULL
  )
}

normalize_diagram_node <- function(node, index) {
  size <- default_node_size(node$kind)
  node$width <- node$width %||% size$width
  node$height <- node$height %||% size$height
  node$style <- node$style %||% list()
  node$layout <- utils::modifyList(default_node_layout(index), node$layout %||% list())
  node
}

layout_lane_index <- function(nodes) {
  lanes <- vapply(nodes, function(node) {
    layout <- node$layout %||% list()
    layout$lane %||% layout$group %||% "default"
  }, character(1))
  lane_levels <- unique(lanes)
  stats::setNames(seq_along(lane_levels), lane_levels)
}

layout_nodes_grid <- function(nodes, canvas, layout) {
  rows <- max(vapply(nodes, function(node) (node$layout %||% list())$row %||% 1, numeric(1)))
  cols <- max(vapply(nodes, function(node) (node$layout %||% list())$column %||% 1, numeric(1)))
  cell_w <- (canvas$width - 2 * layout$margin_x) / max(cols, 1)
  cell_h <- (canvas$height - 2 * layout$margin_y) / max(rows, 1)

  lapply(nodes, function(node) {
    row <- (node$layout %||% list())$row %||% 1
    col <- (node$layout %||% list())$column %||% 1
    if (is.null(node$x)) {
      node$x <- layout$margin_x + (col - 0.5) * cell_w
    }
    if (is.null(node$y)) {
      node$y <- canvas$height - layout$margin_y - (row - 0.5) * cell_h
    }
    node
  })
}

infer_stage_from_relations <- function(nodes) {
  ids <- vapply(nodes, function(node) node$id %||% "", character(1))
  index <- stats::setNames(seq_along(ids), ids)
  stages <- vapply(nodes, function(node) {
    stage <- (node$layout %||% list())$stage
    if (is.null(stage)) NA_real_ else as.numeric(stage)
  }, numeric(1))

  changed <- TRUE
  iter <- 0
  while (changed && iter < length(nodes) * 3) {
    changed <- FALSE
    iter <- iter + 1

    for (i in seq_along(nodes)) {
      layout <- nodes[[i]]$layout %||% list()
      if (!is.na(stages[i])) {
        next
      }

      if (!is.null(layout$after) && layout$after %in% names(index)) {
        ref <- index[[layout$after]]
        if (!is.na(stages[ref])) {
          stages[i] <- stages[ref] + 1
          changed <- TRUE
          next
        }
      }

      if (!is.null(layout$before) && layout$before %in% names(index)) {
        ref <- index[[layout$before]]
        if (!is.na(stages[ref])) {
          stages[i] <- max(1, stages[ref] - 1)
          changed <- TRUE
        }
      }
    }
  }

  if (anyNA(stages)) {
    stages[is.na(stages)] <- seq_len(sum(is.na(stages)))
  }

  for (i in seq_along(nodes)) {
    nodes[[i]]$layout$stage <- stages[i]
  }

  nodes
}

layout_nodes_constraint <- function(nodes, canvas, layout) {
  nodes <- infer_stage_from_relations(nodes)
  direction <- layout$direction %||% "horizontal"
  lane_idx <- layout_lane_index(nodes)
  stage_values <- sort(unique(vapply(nodes, function(node) node$layout$stage %||% 1, numeric(1))))
  stage_map <- stats::setNames(seq_along(stage_values), as.character(stage_values))
  stage_n <- max(unname(stage_map))
  lane_n <- max(unname(lane_idx))
  margin_x <- layout$margin_x %||% 1.2
  margin_y <- layout$margin_y %||% 1.0
  span_x <- canvas$width - 2 * margin_x
  span_y <- canvas$height - 2 * margin_y

  for (i in seq_along(nodes)) {
    node <- nodes[[i]]
    stage <- stage_map[[as.character(node$layout$stage %||% 1)]]
    lane_name <- node$layout$lane %||% node$layout$group %||% "default"
    lane <- lane_idx[[lane_name]]

    if (identical(direction, "vertical")) {
      if (is.null(node$y)) {
        node$y <- canvas$height - margin_y - ((stage - 0.5) / max(stage_n, 1)) * span_y
      }
      if (is.null(node$x)) {
        node$x <- if (lane_n == 1) canvas$width / 2 else margin_x + ((lane - 0.5) / lane_n) * span_x
      }
    } else {
      if (is.null(node$x)) {
        node$x <- margin_x + ((stage - 0.5) / max(stage_n, 1)) * span_x
      }
      if (is.null(node$y)) {
        node$y <- if (lane_n == 1) canvas$height / 2 else canvas$height - margin_y - ((lane - 0.5) / lane_n) * span_y
      }
    }

    nodes[[i]] <- node
  }

  nodes
}

layout_nodes_flow <- function(nodes, canvas, layout) {
  direction <- layout$direction %||% "horizontal"
  lane_idx <- layout_lane_index(nodes)
  lanes_n <- max(unname(lane_idx))
  margin_x <- layout$margin_x %||% 1.2
  margin_y <- layout$margin_y %||% 1.0
  gap_x <- layout$gap_x %||% 1.6
  gap_y <- layout$gap_y %||% 1.2

  nodes <- nodes[order(vapply(nodes, function(node) (node$layout %||% list())$order %||% 1, numeric(1)))]
  count <- length(nodes)
  span_x <- canvas$width - 2 * margin_x
  span_y <- canvas$height - 2 * margin_y

  for (i in seq_along(nodes)) {
    node <- nodes[[i]]
    lane_layout <- node$layout %||% list()
    lane_name <- lane_layout$lane %||% lane_layout$group %||% "default"
    lane <- lane_idx[[lane_name]]

    if (identical(direction, "vertical")) {
      if (is.null(node$y)) {
        node$y <- canvas$height - margin_y - ((i - 0.5) / max(count, 1)) * span_y
      }
      if (is.null(node$x)) {
        if (lanes_n == 1) {
          node$x <- canvas$width / 2
        } else {
          node$x <- margin_x + ((lane - 0.5) / lanes_n) * span_x
        }
      }
    } else {
      if (is.null(node$x)) {
        node$x <- margin_x + ((i - 0.5) / max(count, 1)) * span_x
      }
      if (is.null(node$y)) {
        if (lanes_n == 1) {
          node$y <- canvas$height / 2
        } else {
          node$y <- canvas$height - margin_y - ((lane - 0.5) / lanes_n) * span_y
        }
      }
    }

    nodes[[i]] <- node
  }

  nodes
}

normalize_relation_hint <- function(value, default_axis = "y") {
  if (is.null(value)) {
    return(NULL)
  }

  if (is.character(value) && length(value) == 1) {
    return(list(with = value, axis = default_axis))
  }

  if (is.list(value)) {
    return(list(
      with = value$with %||% value$id %||% value$node,
      axis = value$axis %||% default_axis
    ))
  }

  NULL
}

apply_axis_match <- function(node, ref, axis) {
  if (axis %in% c("x", "both")) {
    node$x <- ref$x
  }
  if (axis %in% c("y", "both")) {
    node$y <- ref$y
  }
  node
}

apply_node_alignment_constraints <- function(nodes) {
  ids <- vapply(nodes, function(node) node$id %||% "", character(1))
  index <- stats::setNames(seq_along(ids), ids)

  for (iter in seq_len(3)) {
    for (i in seq_along(nodes)) {
      layout <- nodes[[i]]$layout %||% list()

      align <- normalize_relation_hint(layout$align, default_axis = "y")
      if (!is.null(align) && !is.null(align$with) && align$with %in% names(index)) {
        ref <- nodes[[index[[align$with]]]]
        nodes[[i]] <- apply_axis_match(nodes[[i]], ref, align$axis %||% "y")
      }

      center_on <- normalize_relation_hint(layout$center_on, default_axis = "x")
      if (!is.null(center_on) && !is.null(center_on$with) && center_on$with %in% names(index)) {
        ref <- nodes[[index[[center_on$with]]]]
        nodes[[i]] <- apply_axis_match(nodes[[i]], ref, center_on$axis %||% "x")
      }
    }
  }

  nodes
}

normalize_distribute_hint <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }

  if (is.character(value) && length(value) == 1) {
    return(list(axis = value, within = "all", by = "order"))
  }

  if (is.list(value)) {
    return(list(
      axis = value$axis %||% "x",
      within = value$within %||% "all",
      by = value$by %||% "order"
    ))
  }

  NULL
}

layout_group_key <- function(node, within) {
  layout <- node$layout %||% list()
  switch(
    within,
    lane = layout$lane %||% layout$group %||% "default",
    stage = as.character(layout$stage %||% 1),
    group = layout$group %||% "default",
    "all"
  )
}

distribute_group_positions <- function(nodes, idx, axis, canvas, layout, by = "order") {
  if (!length(idx)) {
    return(nodes)
  }

  ord_values <- vapply(idx, function(i) {
    node_layout <- nodes[[i]]$layout %||% list()
    if (identical(by, "stage")) {
      node_layout$stage %||% node_layout$order %||% i
    } else {
      node_layout$order %||% node_layout$stage %||% i
    }
  }, numeric(1))
  idx <- idx[order(ord_values)]

  margin_x <- layout$margin_x %||% 1.2
  margin_y <- layout$margin_y %||% 1.0
  if (identical(axis, "y")) {
    span <- canvas$height - 2 * margin_y
    positions <- if (length(idx) == 1) canvas$height / 2 else canvas$height - margin_y - ((seq_along(idx) - 0.5) / length(idx)) * span
    for (j in seq_along(idx)) {
      nodes[[idx[[j]]]]$y <- positions[[j]]
    }
  } else {
    span <- canvas$width - 2 * margin_x
    positions <- if (length(idx) == 1) canvas$width / 2 else margin_x + ((seq_along(idx) - 0.5) / length(idx)) * span
    for (j in seq_along(idx)) {
      nodes[[idx[[j]]]]$x <- positions[[j]]
    }
  }

  nodes
}

apply_canvas_distribution <- function(nodes, canvas, layout) {
  dist <- normalize_distribute_hint(layout$distribute)
  if (is.null(dist)) {
    return(nodes)
  }

  keys <- vapply(nodes, layout_group_key, character(1), within = dist$within %||% "all")
  groups <- split(seq_along(nodes), keys)

  for (idx in groups) {
    nodes <- distribute_group_positions(
      nodes = nodes,
      idx = idx,
      axis = dist$axis %||% "x",
      canvas = canvas,
      layout = layout,
      by = dist$by %||% "order"
    )
  }

  nodes
}

normalize_diagram_spec <- function(spec) {
  canvas <- spec$canvas %||% list(width = 10, height = 6, background = "white", coordinate_system = "cartesian")
  spec$canvas <- canvas
  spec <- apply_diagram_theme(spec)
  canvas <- spec$canvas
  canvas$layout <- utils::modifyList(default_canvas_layout(), canvas$layout %||% list())
  raw_nodes <- spec$nodes %||% list()
  nodes <- Map(normalize_diagram_node, raw_nodes, seq_along(raw_nodes))

  if (!length(nodes)) {
    spec$canvas <- canvas
    spec$nodes <- nodes
    return(spec)
  }

  all_positioned <- all(vapply(nodes, function(node) !is.null(node$x) && !is.null(node$y), logical(1)))
  if (!all_positioned) {
    has_relation_hints <- any(vapply(nodes, function(node) {
      layout <- node$layout %||% list()
      !is.null(layout$stage) || !is.null(layout$after) || !is.null(layout$before) || !is.null(layout$group)
    }, logical(1)))
    has_grid_hints <- any(vapply(nodes, function(node) {
      layout <- node$layout %||% list()
      !is.null(layout$row) || !is.null(layout$column)
    }, logical(1)))

    if (has_grid_hints || identical(canvas$layout$engine, "grid")) {
      nodes <- layout_nodes_grid(nodes, canvas = canvas, layout = canvas$layout)
    } else if (has_relation_hints || identical(canvas$layout$engine, "constraint")) {
      nodes <- layout_nodes_constraint(nodes, canvas = canvas, layout = canvas$layout)
    } else {
      nodes <- layout_nodes_flow(nodes, canvas = canvas, layout = canvas$layout)
    }
  }

  nodes <- apply_node_alignment_constraints(nodes)
  nodes <- apply_canvas_distribution(nodes, canvas = canvas, layout = canvas$layout)

  spec$canvas <- canvas
  spec$nodes <- nodes
  spec
}

coord_unit_x <- function(x, canvas) {
  grid::unit(x / canvas$width, "npc")
}

coord_unit_y <- function(y, canvas) {
  grid::unit(y / canvas$height, "npc")
}

size_unit_w <- function(width, canvas) {
  grid::unit(width / canvas$width, "npc")
}

size_unit_h <- function(height, canvas) {
  grid::unit(height / canvas$height, "npc")
}

fit_raster_into_box <- function(raster, width, height) {
  dims <- dim(raster)
  if (is.null(dims) || length(dims) < 2) {
    return(list(width = width, height = height))
  }

  img_h <- dims[[1]]
  img_w <- dims[[2]]
  if (img_h <= 0 || img_w <= 0) {
    return(list(width = width, height = height))
  }

  width_mm <- grid::convertUnit(width, "mm", valueOnly = TRUE)
  height_mm <- grid::convertUnit(height, "mm", valueOnly = TRUE)
  img_ratio <- img_w / img_h
  box_ratio <- width_mm / max(height_mm, 1e-6)

  if (img_ratio > box_ratio) {
    list(width = width, height = width / img_ratio)
  } else {
    list(width = height * img_ratio, height = height)
  }
}

diagram_style <- function(style, name, default = NULL) {
  if (is.null(style) || is.null(style[[name]])) {
    return(default)
  }

  style[[name]]
}

diagram_image_node_grob <- function(node, x, y, width, height, style) {
  asset_path <- node$asset_ref
  raster <- try_read_image_raster(asset_path)

  if (is.null(raster)) {
    return(grid::rectGrob(
      x = x,
      y = y,
      width = width,
      height = height,
      gp = grid::gpar(
        fill = diagram_style(style, "fill", "#F5F5F5"),
        col = diagram_style(style, "colour", "#36454F"),
        lwd = diagram_style(style, "linewidth", 1)
      )
    ))
  }

  matte <- grid::roundrectGrob(
    x = x,
    y = y,
    width = width,
    height = height,
    r = grid::unit(0.02, "snpc"),
    gp = grid::gpar(
      fill = diagram_style(style, "matte_fill", grDevices::adjustcolor("white", alpha.f = 0.6)),
      col = diagram_style(style, "matte_border", grDevices::adjustcolor("#D9E2EC", alpha.f = 0.8)),
      lwd = diagram_style(style, "matte_linewidth", 0.8)
    )
  )

  fitted <- fit_raster_into_box(raster, width, height)

  grid::grobTree(
    matte,
    grid::rasterGrob(
      image = raster,
      x = x,
      y = y,
      width = fitted$width,
      height = fitted$height,
      interpolate = TRUE
    )
  )
}

diagram_asset_label_grob <- function(label, x, y, width, height, style) {
  if (!nzchar(label)) {
    return(grid::nullGrob())
  }

  label_y <- y - height / 2 - grid::unit(0.018, "npc")
  label_h <- grid::unit(0.048, "npc")
  bg <- grid::roundrectGrob(
    x = x,
    y = label_y,
    width = width * 0.92,
    height = label_h,
    r = grid::unit(0.01, "snpc"),
    gp = grid::gpar(
      fill = diagram_style(style, "label_fill", grDevices::adjustcolor("white", alpha.f = 0.9)),
      col = diagram_style(style, "label_border", grDevices::adjustcolor("#D9E2EC", alpha.f = 0.9)),
      lwd = 0.8
    )
  )
  txt <- grid::textGrob(
    label = label,
    x = x,
    y = label_y,
    gp = grid::gpar(
      col = diagram_style(style, "label_colour", diagram_style(style, "text_colour", "#102A43")),
      cex = diagram_style(style, "label_cex", max(diagram_style(style, "cex", 1), 1.05)),
      fontface = diagram_style(style, "label_fontface", 2)
    )
  )
  grid::grobTree(bg, txt)
}

diagram_node_grob <- function(node, canvas) {
  style <- node$style %||% list()
  x <- coord_unit_x(node$x, canvas)
  y <- coord_unit_y(node$y, canvas)
  width <- size_unit_w(node$width, canvas)
  height <- size_unit_h(node$height, canvas)
  fill <- diagram_style(style, "fill", "#F5F5F5")
  colour <- diagram_style(style, "colour", "#36454F")
  lwd <- diagram_style(style, "linewidth", 1)
  label <- node$label %||% ""

  shape_grob <- switch(
    node$kind,
    box = grid::rectGrob(
      x = x, y = y, width = width, height = height,
      gp = grid::gpar(fill = fill, col = colour, lwd = lwd)
    ),
    rounded_box = grid::roundrectGrob(
      x = x, y = y, width = width, height = height,
      r = grid::unit(diagram_style(style, "radius", 0.08), "snpc"),
      gp = grid::gpar(fill = fill, col = colour, lwd = lwd)
    ),
    text = grid::nullGrob(),
    image_asset = diagram_image_node_grob(node, x = x, y = y, width = width, height = height, style = style),
    grid::rectGrob(
      x = x, y = y, width = width, height = height,
      gp = grid::gpar(fill = fill, col = colour, lwd = lwd)
    )
  )

  if (!nzchar(label)) {
    return(shape_grob)
  }

  if (identical(node$kind, "image_asset")) {
    return(grid::grobTree(
      shape_grob,
      diagram_asset_label_grob(label, x = x, y = y, width = width, height = height, style = style)
    ))
  }

  text_grob <- grid::textGrob(
    label = label,
    x = x,
    y = y,
    gp = grid::gpar(
      col = diagram_style(style, "text_colour", "#1F2933"),
      cex = diagram_style(style, "cex", 1)
    )
  )

  grid::grobTree(shape_grob, text_grob)
}

edge_points <- function(edge, node_index) {
  from <- node_index[[edge$from]]
  to <- node_index[[edge$to]]

  if (is.null(from) || is.null(to)) {
    return(NULL)
  }

  list(
    x0 = from$x + from$width / 2,
    y0 = from$y,
    x1 = to$x - to$width / 2,
    y1 = to$y
  )
}

diagram_edge_grob <- function(edge, node_index, canvas) {
  pts <- edge_points(edge, node_index)
  if (is.null(pts)) {
    return(grid::nullGrob())
  }

  style <- edge$style %||% list()
  gp <- grid::gpar(
    col = diagram_style(style, "colour", "#52606D"),
    lwd = diagram_style(style, "linewidth", 1.2),
    lty = diagram_style(style, "linetype", 1)
  )
  arrow_obj <- if (isTRUE(edge$arrow)) {
    grid::arrow(length = grid::unit(0.12, "inches"), type = "closed")
  } else {
    NULL
  }

  route <- edge$route %||% "straight"
  if (identical(route, "elbow")) {
    mid_x <- (pts$x0 + pts$x1) / 2
    return(grid::polylineGrob(
      x = grid::unit(c(pts$x0, mid_x, mid_x, pts$x1) / canvas$width, "npc"),
      y = grid::unit(c(pts$y0, pts$y0, pts$y1, pts$y1) / canvas$height, "npc"),
      id = rep(1L, 4),
      gp = gp,
      arrow = arrow_obj
    ))
  }

  if (identical(route, "curved")) {
    mid_x <- (pts$x0 + pts$x1) / 2
    return(grid::xsplineGrob(
      x = grid::unit(c(pts$x0, mid_x, pts$x1) / canvas$width, "npc"),
      y = grid::unit(c(pts$y0, max(pts$y0, pts$y1) + 0.5, pts$y1) / canvas$height, "npc"),
      shape = 1,
      open = FALSE,
      gp = gp,
      arrow = arrow_obj
    ))
  }

  grid::segmentsGrob(
    x0 = coord_unit_x(pts$x0, canvas),
    y0 = coord_unit_y(pts$y0, canvas),
    x1 = coord_unit_x(pts$x1, canvas),
    y1 = coord_unit_y(pts$y1, canvas),
    gp = gp,
    arrow = arrow_obj
  )
}

render_diagram_spec <- function(spec) {
  spec <- normalize_diagram_spec(spec)
  canvas <- spec$canvas %||% list(width = 10, height = 6)
  nodes <- spec$nodes %||% list()
  edges <- spec$edges %||% list()
  node_index <- stats::setNames(nodes, vapply(nodes, function(x) x$id %||% "", character(1)))

  node_grobs <- lapply(nodes, diagram_node_grob, canvas = canvas)
  edge_grobs <- lapply(edges, diagram_edge_grob, node_index = node_index, canvas = canvas)

  children <- c(edge_grobs, node_grobs)
  if (!length(children)) {
    return(grid::nullGrob())
  }

  grid::grobTree(children = do.call(grid::gList, children))
}
