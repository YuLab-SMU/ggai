coerce_polish_plot <- function(x) {
  if (inherits(x, "ggai_session")) {
    return(session_current_plot(x))
  }
  if (inherits(x, "ggplot")) {
    return(x)
  }
  rlang::abort("`x` must be a ggplot object or ggai_session.")
}

coerce_polish_source_meta <- function(x) {
  if (inherits(x, "ggai_session")) {
    return(list(
      input_class = class(x),
      source_kind = "ggai_session",
      session_context = session_context_snapshot(x),
      spec_history = spec_history.ggai_session(x),
      current_spec = tryCatch(inspect_spec.ggai_session(x, raw = FALSE), error = function(...) NULL)
    ))
  }

  if (inherits(x, "ggplot")) {
    compiled <- latest_compiled_spec(x)
    history <- tryCatch(spec_history(x), error = function(...) data.frame())
    return(list(
      input_class = class(x),
      source_kind = "ggplot",
      session_context = NULL,
      spec_history = history,
      current_spec = if (is.null(compiled)) NULL else inspect_spec(compiled, raw = FALSE)
    ))
  }

  list(
    input_class = class(x),
    source_kind = "unknown",
    session_context = NULL,
    spec_history = data.frame(),
    current_spec = NULL
  )
}

mapping_labels <- function(mapping) {
  if (is.null(mapping) || !length(mapping)) {
    return(list())
  }

  out <- vector("list", length(mapping))
  nms <- names(mapping)
  for (i in seq_along(mapping)) {
    out[[i]] <- rlang::as_label(mapping[[i]])
  }
  stats::setNames(out, nms)
}

summarize_vector_contract <- function(x) {
  if (is.null(x) || !length(x)) {
    return(NULL)
  }

  if (is.numeric(x)) {
    finite <- x[is.finite(x)]
    if (!length(finite)) {
      return(list(type = class(x)[1], n = length(x)))
    }
    return(list(
      type = class(x)[1],
      n = length(x),
      min = unname(min(finite)),
      max = unname(max(finite))
    ))
  }

  if (inherits(x, "Date") || inherits(x, "POSIXt")) {
    return(list(
      type = class(x)[1],
      n = length(x),
      min = as.character(min(x, na.rm = TRUE)),
      max = as.character(max(x, na.rm = TRUE))
    ))
  }

  values <- unique(as.character(stats::na.omit(x)))
  list(
    type = class(x)[1],
    n = length(x),
    levels = utils::head(values, 12)
  )
}

summarize_plot_data_contract <- function(plot) {
  data <- plot$data %||% NULL
  mapping <- mapping_labels(plot$mapping)
  if (is.null(data) || !is.data.frame(data)) {
    return(list(
      rows = NULL,
      columns = NULL,
      mappings = mapping,
      mapped_columns = list()
    ))
  }

  mapped_columns <- list()
  for (nm in names(mapping)) {
    expr <- mapping[[nm]]
    if (!is.null(expr) && expr %in% names(data)) {
      mapped_columns[[nm]] <- list(
        column = expr,
        summary = summarize_vector_contract(data[[expr]])
      )
    }
  }

  list(
    rows = nrow(data),
    columns = stats::setNames(vapply(data, function(col) class(col)[1], character(1)), names(data)),
    mappings = mapping,
    mapped_columns = mapped_columns
  )
}

summarize_built_layer <- function(layer, built, index) {
  spatial_cols <- intersect(
    c("x", "y", "xmin", "xmax", "ymin", "ymax", "xend", "yend"),
    names(built)
  )

  spatial_bounds <- lapply(spatial_cols, function(col) {
    vals <- built[[col]]
    vals <- vals[is.finite(vals)]
    if (!length(vals)) {
      return(NULL)
    }
    list(min = unname(min(vals)), max = unname(max(vals)))
  })
  names(spatial_bounds) <- spatial_cols
  spatial_bounds <- Filter(Negate(is.null), spatial_bounds)

  list(
    index = index,
    geom = geom_name_from_layer(layer),
    rows = nrow(built),
    columns = names(built),
    panel_count = if ("PANEL" %in% names(built)) length(unique(built$PANEL)) else NULL,
    group_count = if ("group" %in% names(built)) length(unique(stats::na.omit(built$group))) else NULL,
    spatial_bounds = spatial_bounds
  )
}

summarize_plot_layers_for_polish <- function(plot) {
  built <- ggplot2::ggplot_build(plot)
  if (!length(built$data)) {
    return(list())
  }

  lapply(seq_along(built$data), function(i) {
    layer <- plot$layers[[min(i, length(plot$layers))]]
    summarize_built_layer(layer, built$data[[i]], i)
  })
}

with_null_pdf_device <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

sum_width_inches <- function(x) {
  if (!length(x)) {
    return(0)
  }
  grid::convertWidth(sum(x), "in", valueOnly = TRUE)
}

sum_height_inches <- function(x) {
  if (!length(x)) {
    return(0)
  }
  grid::convertHeight(sum(x), "in", valueOnly = TRUE)
}

bbox_from_gtable_cells <- function(gt, rows, cols, label) {
  if (!length(rows) || !length(cols)) {
    return(NULL)
  }

  with_null_pdf_device({
    total_w <- sum_width_inches(gt$widths)
    total_h <- sum_height_inches(gt$heights)

    left <- if (min(cols) > 1) sum_width_inches(gt$widths[seq_len(min(cols) - 1)]) else 0
    right <- sum_width_inches(gt$widths[seq_len(max(cols))])
    top <- if (min(rows) > 1) sum_height_inches(gt$heights[seq_len(min(rows) - 1)]) else 0
    bottom <- sum_height_inches(gt$heights[seq_len(max(rows))])

    xmin <- left / total_w
    xmax <- right / total_w
    ymax <- 1 - (top / total_h)
    ymin <- 1 - (bottom / total_h)

    list(
      label = label,
      xmin = xmin,
      xmax = xmax,
      ymin = ymin,
      ymax = ymax,
      x = (xmin + xmax) / 2,
      y = (ymin + ymax) / 2,
      width = xmax - xmin,
      height = ymax - ymin
    )
  })
}

region_bbox_from_pattern <- function(gt, pattern, label) {
  idx <- grepl(pattern, gt$layout$name)
  if (!any(idx)) {
    return(NULL)
  }

  bbox_from_gtable_cells(
    gt = gt,
    rows = unique(unlist(mapply(seq, gt$layout$t[idx], gt$layout$b[idx], SIMPLIFY = FALSE))),
    cols = unique(unlist(mapply(seq, gt$layout$l[idx], gt$layout$r[idx], SIMPLIFY = FALSE))),
    label = label
  )
}

extract_layout_regions <- function(plot) {
  gt <- ggplot2::ggplotGrob(plot)

  Filter(Negate(is.null), list(
    title = region_bbox_from_pattern(gt, "^title$|^plot\\.title", "title"),
    subtitle = region_bbox_from_pattern(gt, "^subtitle$|^plot\\.subtitle", "subtitle"),
    caption = region_bbox_from_pattern(gt, "^caption$|^plot\\.caption", "caption"),
    data_panel = region_bbox_from_pattern(gt, "^panel", "data_panel"),
    legend = region_bbox_from_pattern(gt, "^guide-box|^guides", "legend"),
    x_axis = region_bbox_from_pattern(gt, "^axis-b|^xlab-b", "x_axis"),
    y_axis = region_bbox_from_pattern(gt, "^axis-l|^ylab-l", "y_axis")
  ))
}

layout_region_palette <- function(name) {
  switch(
    name,
    title = "#2563EB",
    subtitle = "#0F766E",
    caption = "#6B7280",
    data_panel = "#DC2626",
    legend = "#7C3AED",
    x_axis = "#D97706",
    y_axis = "#D97706",
    "#111827"
  )
}

save_layout_overlay <- function(regions, path, width_px, height_px, dpi = 300) {
  grDevices::png(
    filename = path,
    width = width_px,
    height = height_px,
    units = "px",
    res = dpi,
    bg = "white"
  )
  on.exit(grDevices::dev.off(), add = TRUE)

  grid::grid.newpage()
  grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))

  for (nm in names(regions)) {
    region <- regions[[nm]]
    colour <- layout_region_palette(nm)
    fill <- grDevices::adjustcolor(colour, alpha.f = 0.16)
    grid::grid.rect(
      x = grid::unit(region$x, "npc"),
      y = grid::unit(region$y, "npc"),
      width = grid::unit(region$width, "npc"),
      height = grid::unit(region$height, "npc"),
      gp = grid::gpar(fill = fill, col = colour, lwd = 2)
    )
    grid::grid.text(
      label = region$label,
      x = grid::unit(max(region$xmin + 0.01, 0.02), "npc"),
      y = grid::unit(min(region$ymax - 0.02, 0.98), "npc"),
      just = c("left", "top"),
      gp = grid::gpar(col = colour, cex = 0.9, fontface = "bold")
    )
  }

  invisible(path)
}

build_geometry_overlay_plot <- function(plot) {
  plot +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.box.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(colour = "transparent"),
      plot.subtitle = ggplot2::element_text(colour = "transparent"),
      plot.caption = ggplot2::element_text(colour = "transparent"),
      axis.title = ggplot2::element_text(colour = "transparent"),
      axis.text = ggplot2::element_text(colour = "transparent"),
      axis.ticks = ggplot2::element_line(colour = "transparent"),
      axis.line = ggplot2::element_line(colour = "transparent"),
      legend.title = ggplot2::element_text(colour = "transparent"),
      legend.text = ggplot2::element_text(colour = "transparent"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

save_plot_reference <- function(plot, path, width_px, height_px, dpi = 300, bg = "white") {
  ggplot2::ggsave(
    filename = path,
    plot = plot,
    width = width_px / dpi,
    height = height_px / dpi,
    units = "in",
    dpi = dpi,
    bg = bg
  )
  invisible(path)
}

build_semantic_constraints <- function(plot_context, layer_summaries, instruction = NULL) {
  geoms <- unique(unlist(lapply(layer_summaries, function(layer) layer$geom %||% NULL)))

  constraints <- c(
    "Preserve axis direction, scale logic, and the relative positions of all major marks.",
    "Do not invent, remove, or merge visible data groups, categories, clusters, or standout outliers.",
    "Keep all visible text logically attached to the same chart regions even if the styling is redrawn."
  )

  if ("point" %in% geoms) {
    constraints <- c(
      constraints,
      "Preserve point-cloud shape, relative density, and any isolated outlier points."
    )
  }
  if ("line" %in% geoms || "path" %in% geoms) {
    constraints <- c(
      constraints,
      "Preserve line trajectories, turning points, crossings, and overall trend direction."
    )
  }
  if (any(c("bar", "col") %in% geoms)) {
    constraints <- c(
      constraints,
      "Preserve bar ordering, relative heights, and grouped comparisons."
    )
  }

  if (!is.null(instruction) && nzchar(instruction)) {
    constraints <- c(
      constraints,
      paste0("Honor this requested polish direction without breaking the data semantics: ", instruction)
    )
  }

  unique(constraints)
}

build_allow_redraw_contract <- function() {
  c(
    "Redraw the full figure from scratch rather than tracing the original pixels.",
    "Improve typography, spacing, annotation styling, color treatment, shading, and surface finish.",
    "Use richer illustration treatment, cleaner composition, and more intentional visual hierarchy.",
    "You may restyle legends, labels, icons, and decorative surfaces as long as the figure remains semantically faithful."
  )
}

build_polish_layer_manifest <- function(reference_paths, render_info, layout_regions = list()) {
  canvas <- list(
    width = render_info$width_px,
    height = render_info$height_px,
    composite_background = "#ffffff"
  )

  list(
    version = 1L,
    ordering = "bottom_to_top",
    canvas = canvas,
    ggplot_reference_layers = list(
      list(
        order = 1L,
        name = "Base ggplot render",
        role = "ggplot_composite",
        file = reference_paths$base_plot,
        fit = "cover",
        opacity = 1,
        locked = TRUE,
        ggplot_role = "final plot composition",
        guidance = "Use as the factual composite reference for data, labels, scales, guide placement, theme, and chart text."
      ),
      list(
        order = 2L,
        name = "Data geometry overlay",
        role = "ggplot_data_layer_anchor",
        file = reference_paths$geometry_overlay,
        fit = "cover",
        opacity = 1,
        locked = TRUE,
        ggplot_role = "geom/stat position anchor",
        guidance = "Use as an alignment layer for geoms and stats. Preserve mark positions, point-cloud shape, trajectories, bars, and relative spatial relationships."
      ),
      list(
        order = 3L,
        name = "Guide and layout overlay",
        role = "ggplot_layout_anchor",
        file = reference_paths$layout_overlay,
        fit = "cover",
        opacity = 1,
        locked = TRUE,
        ggplot_role = "theme/guide/facet/label layout anchor",
        guidance = "Use as a layout guide for title, subtitle, panels, axes, legends, captions, facets, and data zones."
      )
    ),
    ggplot_output_roles = list(
      list(
        order = 1L,
        name = "Theme surface",
        role = "theme",
        guidance = "Background, grid, margins, spacing, and surface treatment. Do not obscure data."
      ),
      list(
        order = 2L,
        name = "Data layers",
        role = "geoms_and_stats",
        guidance = "Faithful redrawn geoms and statistical summaries. Preserve relative positions, group identity, ordering, and scale logic."
      ),
      list(
        order = 3L,
        name = "Scales and guides",
        role = "scales_guides_axes",
        guidance = "Readable axes, ticks, scales, legends, and guide hierarchy with the same chart semantics."
      ),
      list(
        order = 4L,
        name = "Labels and annotations",
        role = "labels_annotations",
        guidance = "Titles, labels, callouts, and explanatory notes attached to the same chart regions."
      ),
      list(
        order = 5L,
        name = "Communication polish",
        role = "visual_hierarchy",
        guidance = "Hierarchy, typography, emphasis, and optional explainer details that do not change the data story."
      )
    ),
    layout_regions = layout_regions,
    export_note = "This is a ggplot-native layer contract for image redraw. It follows ggplot's own layer, scale, guide, theme, label, and annotation model."
  )
}

build_polish_manifest <- function(source,
                                  plot,
                                  instruction,
                                  render_info,
                                  reference_paths,
                                  prompt_path = NULL) {
  plot_context <- build_plot_context(plot)
  layer_summaries <- summarize_plot_layers_for_polish(plot)
  layout_regions <- extract_layout_regions(plot)
  source_meta <- coerce_polish_source_meta(source)

  list(
    version = 1L,
    mode = "whole_image_redraw",
    layer_mode = "ggplot_layered_redraw",
    instruction = instruction %||% "",
    source = source_meta,
    render = render_info,
    references = list(
      base_plot = reference_paths$base_plot,
      geometry_overlay = reference_paths$geometry_overlay,
      layout_overlay = reference_paths$layout_overlay
    ),
    layer_manifest = build_polish_layer_manifest(
      reference_paths = reference_paths,
      render_info = render_info,
      layout_regions = layout_regions
    ),
    plot_context = plot_context,
    data_contract = summarize_plot_data_contract(plot),
    layer_summaries = layer_summaries,
    layout_regions = layout_regions,
    semantic_constraints = build_semantic_constraints(
      plot_context = plot_context,
      layer_summaries = layer_summaries,
      instruction = instruction
    ),
    allow_redraw = build_allow_redraw_contract(),
    prompt_path = prompt_path
  )
}

build_polish_prompt_contract <- function(manifest) {
  list(
    mode = manifest$mode,
    instruction = manifest$instruction,
    reference_roles = list(
      reference_1 = "Base ggplot render with the factual chart layout and visible text.",
      reference_2 = "Geometry-anchor overlay preserving data marks and spatial relationships.",
      reference_3 = "Layout-region overlay marking title, axes, legend, caption, and data zones."
    ),
    plot_context = manifest$plot_context,
    data_contract = manifest$data_contract,
    layer_summaries = manifest$layer_summaries,
    layout_regions = manifest$layout_regions,
    layer_manifest = manifest$layer_manifest,
    semantic_constraints = manifest$semantic_constraints,
    allow_redraw = manifest$allow_redraw
  )
}

write_text_file <- function(path, text) {
  writeLines(enc2utf8(text), path, useBytes = TRUE)
  invisible(path)
}

polish_artifact_record <- function(result, instruction = NULL, image_model = NULL) {
  list(
    kind = "polish",
    edit_mode = "whole_image_redraw",
    instruction = instruction %||% "",
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE),
    turn = NULL,
    image_model = image_model %||% NULL,
    artifact_path = result$best$path %||% NULL,
    bundle_manifest_path = result$bundle_manifest_path %||% NULL,
    candidate_manifest_path = result$candidate_manifest_path %||% NULL,
    prompt_path = result$prompt_path %||% NULL,
    candidate_count = length(result$candidates %||% list())
  )
}

attach_polish_result_to_session <- function(result,
                                            source,
                                            instruction = NULL,
                                            image_model = NULL) {
  if (!inherits(source, "ggai_session")) {
    return(result)
  }

  session <- source
  artifact <- polish_artifact_record(
    result = result,
    instruction = instruction,
    image_model = image_model
  )
  artifact$turn <- ggai_session_state(session)$current_turn %||% (session$history_index %||% 0L)

  session <- session_record_turn_note(
    session,
    type = "polish",
    value = artifact
  )
  session <- session_record_tool_result(
    session,
    list(
      type = "polish_result",
      turn = artifact$turn,
      best_path = artifact$artifact_path,
      candidate_manifest_path = artifact$candidate_manifest_path
    )
  )
  session <- session_record_artifact(session, artifact)
  session <- session_touch_state(session, instruction = instruction)

  result$session <- session
  result
}

build_polish_prompt <- function(manifest) {
  contract <- build_polish_prompt_contract(manifest)

  paste(
    "Redraw this entire figure as a polished final scientific graphic.",
    "Treat the supplied references as hard constraints and keep the figure semantically faithful to the original data.",
    "Reference image 1 is the factual ggplot render.",
    "Reference image 2 isolates geometry anchors that preserve data marks and relative positions.",
    "Reference image 3 marks the intended layout zones.",
    "Use the layer contract below as a ggplot-native mental model: theme surface, data layers, scales/guides/axes, labels/annotations, then communication polish.",
    "The overlays are alignment and layout layers, not visible decorative layers in the final image.",
    "You may redraw every pixel, but do not change the underlying data story, chart logic, or relative relationships.",
    if (nzchar(manifest$instruction %||% "")) paste("Requested polish direction:", manifest$instruction) else NULL,
    "Layer contract:",
    jsonlite::toJSON(manifest$layer_manifest, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    "Critical constraints:",
    paste(paste0("- ", manifest$semantic_constraints), collapse = "\n"),
    "What you are allowed to improve:",
    paste(paste0("- ", manifest$allow_redraw), collapse = "\n"),
    "Structured contract:",
    jsonlite::toJSON(contract, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    sep = "\n\n"
  )
}

figure_render_dimensions <- function(width = NULL, height = NULL) {
  resolution <- ggai_figure_resolution()
  list(
    width = as.integer(width %||% resolution$width),
    height = as.integer(height %||% resolution$height)
  )
}

#' Prepare a whole-image figure polish bundle
#'
#' Writes the factual base plot, geometry overlay, layout overlay, and a
#' structured manifest that can be sent to an image model for whole-image redraw.
#'
#' @param x A `ggplot` object or `ggai_session`.
#' @param instruction Optional polish direction for the final redraw.
#' @param output_dir Output directory for intermediate artifacts.
#' @param prefix Filename prefix for bundle artifacts.
#' @param width,height Optional raster dimensions in pixels. Defaults to the
#'   value returned by `ggai_figure_resolution()`.
#' @param dpi Raster DPI used when rendering the reference images.
#'
#' @return A `ggai_figure_polish_bundle` list.
#' @export
prepare_polish_bundle <- function(x,
                                  instruction = NULL,
                                  output_dir = tempdir(),
                                  prefix = "figure_polish",
                                  width = NULL,
                                  height = NULL,
                                  dpi = 300) {
  plot <- coerce_polish_plot(x)
  dims <- figure_render_dimensions(width = width, height = height)

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  base_plot_path <- file.path(output_dir, paste0(prefix, "_base_plot.png"))
  geometry_overlay_path <- file.path(output_dir, paste0(prefix, "_geometry_overlay.png"))
  layout_overlay_path <- file.path(output_dir, paste0(prefix, "_layout_overlay.png"))
  manifest_path <- file.path(output_dir, paste0(prefix, "_bundle.json"))
  prompt_path <- file.path(output_dir, paste0(prefix, "_prompt.txt"))

  save_plot_reference(plot, base_plot_path, width_px = dims$width, height_px = dims$height, dpi = dpi)
  save_plot_reference(
    build_geometry_overlay_plot(plot),
    geometry_overlay_path,
    width_px = dims$width,
    height_px = dims$height,
    dpi = dpi
  )

  layout_regions <- extract_layout_regions(plot)
  save_layout_overlay(layout_regions, layout_overlay_path, width_px = dims$width, height_px = dims$height, dpi = dpi)

  render_info <- list(
    width_px = dims$width,
    height_px = dims$height,
    dpi = dpi
  )
  reference_paths <- list(
    base_plot = base_plot_path,
    geometry_overlay = geometry_overlay_path,
    layout_overlay = layout_overlay_path
  )
  manifest <- build_polish_manifest(
    source = x,
    plot = plot,
    instruction = instruction,
    render_info = render_info,
    reference_paths = reference_paths,
    prompt_path = prompt_path
  )
  prompt <- build_polish_prompt(manifest)

  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  write_text_file(prompt_path, prompt)

  structure(
    list(
      plot = plot,
      instruction = instruction,
      prompt = prompt,
      render = render_info,
      reference_images = unname(unlist(reference_paths, use.names = FALSE)),
      base_plot_path = base_plot_path,
      geometry_overlay_path = geometry_overlay_path,
      layout_overlay_path = layout_overlay_path,
      manifest = manifest,
      manifest_path = manifest_path,
      prompt_path = prompt_path
    ),
    class = c("ggai_figure_polish_bundle", "list")
  )
}

#' Redraw a data-grounded figure into a polished final image
#'
#' Uses the ggplot render, geometry overlay, and layout overlay as joint
#' reference images for a whole-image redraw with an image model.
#'
#' @param x A `ggplot` object or `ggai_session`.
#' @param instruction Optional polish direction for the final redraw.
#' @param image_model Optional image model identifier.
#' @param registry Optional provider registry passed to `aisdk`.
#' @param candidate_count Number of image candidates to request from the model.
#' @param output_dir Output directory for the final images and manifests.
#' @param prefix Filename prefix for generated artifacts.
#' @param width,height Optional raster dimensions in pixels for the reference
#'   bundle. Defaults to the value returned by `ggai_figure_resolution()`.
#' @param dpi Raster DPI used when rendering the reference bundle.
#' @param output_format Output image format passed through to the image model.
#' @param output_compression Optional compression level for JPEG or WebP output.
#' @param quality Optional provider-specific quality setting.
#' @param background Optional provider-specific background setting.
#' @param input_fidelity Optional input fidelity override for providers that
#'   support image editing fidelity controls.
#' @param timeout_seconds Legacy alias for `total_timeout_seconds`, passed
#'   through to `aisdk`.
#' @param total_timeout_seconds Optional total request timeout in seconds.
#' @param first_byte_timeout_seconds Optional time-to-first-byte timeout in
#'   seconds.
#' @param connect_timeout_seconds Optional connection-establishment timeout in
#'   seconds.
#' @param idle_timeout_seconds Optional stall timeout in seconds.
#'
#' @return A `ggai_polished_figure_result` list.
#' @export
polish_figure <- function(x,
                          instruction = NULL,
                          image_model = NULL,
                          registry = NULL,
                          candidate_count = 1L,
                          output_dir = file.path(getwd(), "demo_outputs"),
                          prefix = "figure_polish",
                          width = NULL,
                          height = NULL,
                          dpi = 300,
                          output_format = c("png", "jpeg", "webp"),
                          output_compression = NULL,
                          quality = "high",
                          background = "opaque",
                          input_fidelity = NULL,
                          timeout_seconds = NULL,
                          total_timeout_seconds = NULL,
                          first_byte_timeout_seconds = NULL,
                          connect_timeout_seconds = NULL,
                          idle_timeout_seconds = NULL) {
  output_format <- match.arg(output_format)
  candidate_count <- max(1L, as.integer(candidate_count))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  bundle <- prepare_polish_bundle(
    x = x,
    instruction = instruction,
    output_dir = output_dir,
    prefix = prefix,
    width = width,
    height = height,
    dpi = dpi
  )

  edit_args <- list(
    model = ggai_image_model(image_model),
    image = bundle$reference_images,
    prompt = bundle$prompt,
    output_dir = output_dir,
    registry = registry,
    n = candidate_count,
    quality = quality,
    background = background,
    output_format = output_format
  )
  if (!is.null(output_compression)) {
    edit_args$output_compression <- output_compression
  }
  if (!is.null(input_fidelity)) {
    edit_args$input_fidelity <- input_fidelity
  }
  if (!is.null(timeout_seconds)) {
    edit_args$timeout_seconds <- timeout_seconds
  }
  if (!is.null(total_timeout_seconds)) {
    edit_args$total_timeout_seconds <- total_timeout_seconds
  }
  if (!is.null(first_byte_timeout_seconds)) {
    edit_args$first_byte_timeout_seconds <- first_byte_timeout_seconds
  }
  if (!is.null(connect_timeout_seconds)) {
    edit_args$connect_timeout_seconds <- connect_timeout_seconds
  }
  if (!is.null(idle_timeout_seconds)) {
    edit_args$idle_timeout_seconds <- idle_timeout_seconds
  }

  result <- do.call(ggai_edit_image, edit_args)
  images <- result$images %||% list()
  if (!length(images)) {
    rlang::abort("Image editing did not return any output images.")
  }

  candidates <- lapply(seq_along(images), function(i) {
    image <- images[[i]]
    metrics <- evaluate_figure_candidate(image$path, prompt_spec = bundle$manifest)
    list(
      index = i,
      path = image$path,
      media_type = image$media_type %||% NULL,
      revised_prompt = image$revised_prompt %||% NULL,
      score = metrics$score,
      metrics = metrics
    )
  })

  best_idx <- which.max(vapply(candidates, function(candidate) candidate$score, numeric(1)))
  best <- candidates[[best_idx]]
  final_path <- file.path(output_dir, paste0(prefix, "_best.", output_format))
  file.copy(best$path, final_path, overwrite = TRUE)

  candidate_manifest_path <- file.path(output_dir, paste0(prefix, "_candidates.json"))
  jsonlite::write_json(candidates, candidate_manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")

  result_obj <- structure(
    list(
      bundle = bundle,
      prompt = bundle$prompt,
      prompt_path = bundle$prompt_path,
      bundle_manifest_path = bundle$manifest_path,
      candidate_manifest_path = candidate_manifest_path,
      candidates = candidates,
      best = utils::modifyList(best, list(path = final_path)),
      raw_response = result$raw_response %||% NULL
    ),
    class = c("ggai_polished_figure_result", "list")
  )

  attach_polish_result_to_session(
    result = result_obj,
    source = x,
    instruction = instruction,
    image_model = ggai_image_model(image_model)
  )
}
