read_image_dimensions <- function(path) {
  raster <- try_read_image_raster(path)
  dims <- dim(raster)
  if (is.null(dims) || length(dims) < 2) {
    return(c(width = NA_real_, height = NA_real_))
  }
  c(width = dims[[2]], height = dims[[1]])
}

sharpness_proxy <- function(rgba) {
  if (is.null(rgba)) {
    return(0)
  }
  gray <- (rgba[, , 1] + rgba[, , 2] + rgba[, , 3]) / 3
  dx <- abs(gray[, -1] - gray[, -ncol(gray)])
  dy <- abs(gray[-1, ] - gray[-nrow(gray), ])
  mean(c(dx, dy), na.rm = TRUE)
}

edge_clutter_proxy <- function(rgba) {
  if (is.null(rgba)) {
    return(0)
  }
  gray <- (rgba[, , 1] + rgba[, , 2] + rgba[, , 3]) / 3
  mask <- gray < 0.18
  mean(mask, na.rm = TRUE)
}

blankness_proxy <- function(rgba) {
  if (is.null(rgba)) {
    return(1)
  }
  gray <- (rgba[, , 1] + rgba[, , 2] + rgba[, , 3]) / 3
  mean(gray > 0.97, na.rm = TRUE)
}

#' Evaluate a generated direct-figure candidate
#'
#' @param path Image file path.
#' @param prompt_spec Optional figure prompt bundle.
#'
#' @return A list of candidate metrics and score.
#' @export
evaluate_figure_candidate <- function(path, prompt_spec = NULL) {
  if (is.null(path) || !file.exists(path)) {
    return(list(
      score = -Inf,
      file_size = 0,
      visual_complexity = 0,
      sharpness = 0,
      clutter = 0,
      blankness = 1,
      dimensions = c(width = NA_real_, height = NA_real_)
    ))
  }

  file_size <- file.info(path)$size %||% 0
  raster <- try_read_image_raster(path)
  rgba <- as_rgba_array(raster)
  visual_complexity <- 0
  sharpness <- 0
  clutter <- 0
  blankness <- 1
  if (!is.null(rgba)) {
    visual_complexity <- stats::sd(as.numeric(rgba[, , 1:3]))
    sharpness <- sharpness_proxy(rgba)
    clutter <- edge_clutter_proxy(rgba)
    blankness <- blankness_proxy(rgba)
  }
  dims <- read_image_dimensions(path)

  score <- log1p(file_size) +
    visual_complexity * 60 +
    sharpness * 180 -
    clutter * 140 -
    blankness * 220

  list(
    score = score,
    file_size = file_size,
    visual_complexity = visual_complexity,
    sharpness = sharpness,
    clutter = clutter,
    blankness = blankness,
    dimensions = dims
  )
}

# `generate_final_figure()` and `compile_figure_prompt()` were P0-era
# fixed pipelines built on the now-deleted spec-committer agent. Their
# behavior should be re-introduced — when needed — through the agentic path:
# a Skill (e.g. `ggai-direct-figure`) drives `ggai_compile_figure_prompt`
# (TODO) + `ggai_generate_image` + `evaluate_figure_candidate` directly via
# `ggai_execute_r`. See `plan/2026-05-17-agentic-refactor-overview.md`
# Phase P3.
