build_figure_prompt_compiler_prompt <- function(instruction, scene_context = list()) {
  exemplars <- retrieve_local_exemplars("diagram", instruction, n = 2)
  exemplar_text <- format_exemplars_for_prompt(exemplars)

  list(
    system = read_ggai_prompt("figure_system.txt"),
    user = paste(
      "Instruction:",
      instruction,
      "",
      "Scene context:",
      jsonlite::toJSON(scene_context, auto_unbox = TRUE, null = "null", pretty = TRUE),
      if (!is.null(exemplar_text)) paste("\nExamples:\n", exemplar_text) else ""
    )
  )
}

parse_figure_prompt_output <- function(text) {
  jsonlite::fromJSON(strip_json_fences(text), simplifyVector = FALSE)
}

normalize_figure_prompt_spec <- function(spec) {
  spec$title <- spec$title %||% NULL
  spec$scene_summary <- spec$scene_summary %||% ""
  spec$objects <- as.list(spec$objects %||% list())
  spec$relations <- as.list(spec$relations %||% list())
  spec$visual_style <- spec$visual_style %||% "clean scientific illustration with crisp edges, high legibility, and polished biomedical rendering"
  spec$composition <- spec$composition %||% "balanced horizontal composition with large readable labels, strong separation between objects, and low text density"
  spec$negative_prompt <- spec$negative_prompt %||% paste(
    c(
      "watermark",
      "tiny illegible text",
      "dense text blocks",
      "overcrowded labels",
      "blurry edges",
      "checkerboard transparency pattern",
      "UI chrome",
      "meme style",
      "cartoon exaggeration"
    ),
    collapse = ", "
  )
  spec$prompt <- spec$prompt %||% paste(
    spec$scene_summary,
    paste(spec$objects, collapse = ", "),
    paste(spec$relations, collapse = ", "),
    paste("Style:", spec$visual_style),
    paste("Composition:", spec$composition),
    paste("Avoid:", spec$negative_prompt)
  )
  spec
}

#' Compile a direct-image figure prompt bundle
#'
#' @param instruction Natural-language figure request.
#' @param scene_context Optional structured scene context.
#' @param model Optional language model identifier.
#' @param registry Optional provider registry.
#' @param system Optional system prompt override.
#' @param review Whether to run the compiler review pass.
#'
#' @return A normalized figure prompt spec.
#' @export
compile_figure_prompt <- function(instruction,
                                  scene_context = list(),
                                  model = NULL,
                                  registry = NULL,
                                  system = NULL,
                                  review = ggai_review_compiler_output()) {
  prompt <- build_figure_prompt_compiler_prompt(instruction, scene_context = scene_context)
  spec <- compile_with_kind(
    kind = "figure",
    instruction = instruction,
    prompt = prompt,
    model = model,
    registry = registry,
    system = system,
    review = review
  )
  normalize_figure_prompt_spec(spec)
}

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

#' Generate a final scientific figure by direct image generation
#'
#' @param instruction Optional natural-language figure request.
#' @param scene_context Optional structured scene context.
#' @param prompt_spec Optional precompiled figure prompt spec.
#' @param language_model Optional language model identifier.
#' @param image_model Optional image model identifier.
#' @param registry Optional provider registry.
#' @param candidate_count Number of direct-image candidates to generate.
#' @param output_dir Output directory.
#' @param prefix Output filename prefix.
#'
#' @return A `ggai_figure_result` list.
#' @export
generate_final_figure <- function(instruction = NULL,
                                  scene_context = list(),
                                  prompt_spec = NULL,
                                  language_model = NULL,
                                  image_model = NULL,
                                  registry = NULL,
                                  candidate_count = 3L,
                                  output_dir = file.path(getwd(), "demo_outputs"),
                                  prefix = "direct_figure") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  prompt_spec <- prompt_spec %||% compile_figure_prompt(
    instruction = instruction,
    scene_context = scene_context,
    model = language_model,
    registry = registry
  )

  prompt_spec <- normalize_figure_prompt_spec(prompt_spec)
  resolution <- ggai_figure_resolution()

  candidate_count <- max(1L, as.integer(candidate_count))
  candidates <- vector("list", candidate_count)

  for (i in seq_len(candidate_count)) {
    result <- ggai_generate_image(
      model = ggai_image_model(image_model),
      prompt = prompt_spec$prompt,
      output_dir = output_dir,
      width = resolution$width,
      height = resolution$height,
      transparent_background = FALSE
    )
    image <- result$images[[1]]
    score <- evaluate_figure_candidate(image$path, prompt_spec = prompt_spec)
    candidates[[i]] <- list(
      index = i,
      path = image$path,
      media_type = image$media_type %||% NULL,
      score = score$score,
      metrics = score
    )
  }

  best_idx <- which.max(vapply(candidates, function(x) x$score, numeric(1)))
  best <- candidates[[best_idx]]

  final_path <- file.path(output_dir, paste0(prefix, "_best.", file_ext_or(best$path, default = "png")))
  file.copy(best$path, final_path, overwrite = TRUE)
  prompt_path <- file.path(output_dir, paste0(prefix, "_prompt.json"))
  manifest_path <- file.path(output_dir, paste0(prefix, "_candidates.json"))

  jsonlite::write_json(prompt_spec, prompt_path, auto_unbox = TRUE, pretty = TRUE)
  jsonlite::write_json(candidates, manifest_path, auto_unbox = TRUE, pretty = TRUE)

  structure(
    list(
      prompt_spec = prompt_spec,
      candidates = candidates,
      best = utils::modifyList(best, list(path = final_path)),
      prompt_path = prompt_path,
      manifest_path = manifest_path
    ),
    class = c("ggai_figure_result", "list")
  )
}
