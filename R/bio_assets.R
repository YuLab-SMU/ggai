bio_asset_presets <- function() {
  list(
    tumor_cell = list(
      prompt = "stylized biomedical tumor cell, semi-transparent membrane, visible nucleus, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 768,
      height = 768
    ),
    t_cell = list(
      prompt = "stylized activated T cell, rounded membrane with receptor details, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 768,
      height = 768
    ),
    myeloid_cell = list(
      prompt = "stylized immunosuppressive myeloid cell, irregular immune cell morphology, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 768,
      height = 768
    ),
    blood_vessel = list(
      prompt = "stylized blood vessel segment cross-section, endothelial wall, lumen visible, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 1024,
      height = 768
    ),
    tissue_cutaway = list(
      prompt = "stylized tissue cutaway with layered extracellular matrix, scientific biomedical figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 1024,
      height = 768
    ),
    cytokine_cloud = list(
      prompt = "stylized cytokine cloud, signaling molecules and diffusion effect, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 768,
      height = 768
    ),
    cell_therapy = list(
      prompt = "stylized engineered therapeutic immune cell, programmable cell therapy, scientific figure illustration",
      style = "clean biorender-style biomedical illustration, isolated subject cutout, transparent alpha background, no labels",
      negative_prompt = "checkerboard background, grid pattern, watermark, tiny text, infographic annotations, legends, scale bars",
      width = 768,
      height = 768
    )
  )
}

resolve_bio_asset_preset <- function(type) {
  presets <- bio_asset_presets()
  presets[[type]] %||% rlang::abort(paste0("Unknown bio asset preset: ", type))
}

#' Build a biomedical asset specification
#'
#' @param type Asset preset type such as `tumor_cell` or `t_cell`.
#' @param prompt_extra Optional extra natural-language modifiers.
#' @param style Optional style override.
#' @param width,height Optional asset dimensions in pixels.
#' @param transparent_background Whether the asset should use a transparent background.
#'
#' @return A `ggai_bio_asset_spec` object.
#' @export
bio_asset_spec <- function(type,
                           prompt_extra = NULL,
                           style = NULL,
                           width = NULL,
                           height = NULL,
                           transparent_background = TRUE) {
  preset <- resolve_bio_asset_preset(type)
  structure(
    list(
      type = type,
      prompt = preset$prompt,
      prompt_extra = prompt_extra,
      style = style %||% preset$style,
      negative_prompt = preset$negative_prompt,
      width = width %||% preset$width,
      height = height %||% preset$height,
      transparent_background = transparent_background
    ),
    class = c("ggai_bio_asset_spec", "list")
  )
}

bio_asset_prompt <- function(spec) {
  paste(Filter(nzchar, c(spec$prompt, spec$prompt_extra %||% "")), collapse = ", ")
}

#' Generate a biomedical node asset
#'
#' @param spec A `ggai_bio_asset_spec` object or a named list coercible to one.
#' @param model Optional image model identifier.
#' @param cache Whether to cache the generated asset.
#'
#' @return A `ggai_glyph_asset` object.
#' @export
generate_bio_asset <- function(spec, model = NULL, cache = TRUE) {
  if (!inherits(spec, "ggai_bio_asset_spec")) {
    spec <- do.call(bio_asset_spec, spec)
  }

  attempts <- ggai_bio_asset_attempts()
  candidates <- vector("list", attempts)
  errors <- character(0)

  for (i in seq_len(attempts)) {
    candidate <- tryCatch(
      {
        raw <- glyph_generate_asset(
          prompt = bio_asset_prompt(spec),
          style = spec$style,
          negative_prompt = spec$negative_prompt,
          width = spec$width,
          height = spec$height,
          model = model,
          cache = FALSE,
          transparent_background = isTRUE(spec$transparent_background)
        )

        if (is.null(raw$path) || !file.exists(raw$path)) {
          rlang::abort("Generated asset did not materialize to a local file.")
        }

        ext <- tools::file_ext(raw$path)
        raw_copy <- file.path(
          tempdir(),
          paste0("bio_asset_", spec$type, "_", i, "_raw", if (nzchar(ext)) paste0(".", ext) else "")
        )
        file.copy(raw$path, raw_copy, overwrite = TRUE)

        processed <- process_bio_asset_image(
          path = raw$path,
          output_dir = tempdir(),
          prefix = paste0("bio_asset_", spec$type, "_", i)
        )

        c(raw, processed[c("score", "source_path")], list(raw_copy = raw_copy))
      },
      error = function(e) {
        errors <<- c(errors, conditionMessage(e))
        NULL
      }
    )

    candidates[[i]] <- candidate
  }

  candidates <- Filter(Negate(is.null), candidates)
  if (!length(candidates)) {
    rlang::abort(paste(c(
      paste0("Biomedical asset generation failed for type `", spec$type, "`."),
      unique(errors)
    ), collapse = " "))
  }

  scores <- vapply(candidates, function(x) x$score %||% -Inf, numeric(1))
  best <- candidates[[which.max(scores)]]

  if (cache) {
    key <- glyph_cache_key(
      prompt = paste(c(spec$prompt, spec$prompt_extra %||% "", spec$negative_prompt %||% ""), collapse = " || "),
      style = spec$style,
      width = spec$width,
      height = spec$height,
      model = model,
      transparent_background = isTRUE(spec$transparent_background)
    )
    ext <- tools::file_ext(best$path %||% "")
    if (!nzchar(ext)) {
      ext <- "png"
    }
    cache_path <- glyph_cache_path(key, ext = ext)
    copy_image_to_cache(best$path, cache_path)
    best$path <- cache_path
    class(best) <- c("ggai_glyph_asset", "list")
    return(write_cached_glyph(key, best))
  }

  class(best) <- c("ggai_glyph_asset", "list")
  best
}

node_size_from_asset_type <- function(type) {
  switch(
    type,
    tumor_cell = list(width = 2.2, height = 2.2),
    t_cell = list(width = 1.8, height = 1.8),
    myeloid_cell = list(width = 2.0, height = 2.0),
    blood_vessel = list(width = 3.0, height = 1.8),
    tissue_cutaway = list(width = 3.2, height = 2.2),
    cytokine_cloud = list(width = 1.6, height = 1.2),
    cell_therapy = list(width = 1.9, height = 1.9),
    list(width = 2.0, height = 2.0)
  )
}

normalize_bio_asset_node <- function(node, model = NULL, cache = TRUE, generate_assets = TRUE) {
  bio <- node$bio_asset
  if (is.null(bio)) {
    return(node)
  }

  if (!inherits(bio, "ggai_bio_asset_spec")) {
    bio <- do.call(bio_asset_spec, bio)
  }

  size <- node_size_from_asset_type(bio$type)
  node$kind <- "image_asset"
  node$width <- node$width %||% size$width
  node$height <- node$height %||% size$height
  node$style <- node$style %||% list()

  if (isTRUE(generate_assets)) {
    asset <- generate_bio_asset(bio, model = model, cache = cache)
    node$asset_ref <- asset$path
    node$generated_asset <- asset
  }

  node$bio_asset <- bio
  node
}

copy_scene_assets <- function(spec, output_dir, prefix = "asset") {
  asset_dir <- file.path(output_dir, "assets")
  dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)

  manifest <- lapply(spec$nodes %||% list(), function(node) {
    if (is.null(node$asset_ref) || !file.exists(node$asset_ref)) {
      return(NULL)
    }

    ext <- tools::file_ext(node$asset_ref)
    target <- file.path(asset_dir, paste0(prefix, "_", node$id, if (nzchar(ext)) paste0(".", ext) else ""))
    if (!file.copy(node$asset_ref, target, overwrite = TRUE)) {
      return(NULL)
    }

    list(
      id = node$id,
      label = node$label %||% "",
      type = (node$bio_asset %||% list())$type %||% NULL,
      asset_ref = target,
      source_path = (node$generated_asset %||% list())$source_path %||% node$asset_ref %||% target,
      raw_copy = (node$generated_asset %||% list())$raw_copy %||% NULL
    )
  })

  Filter(Negate(is.null), manifest)
}

#' Prepare a hybrid biomedical scene by resolving bio asset nodes
#'
#' @param spec A diagram scene spec.
#' @param model Optional image model identifier.
#' @param cache Whether to cache generated assets.
#' @param generate_assets Whether to actually generate assets now.
#'
#' @return A diagram scene spec with `image_asset` nodes and resolved `asset_ref`s.
#' @export
prepare_hybrid_diagram_spec <- function(spec,
                                        model = NULL,
                                        cache = TRUE,
                                        generate_assets = TRUE) {
  spec$nodes <- lapply(
    spec$nodes %||% list(),
    normalize_bio_asset_node,
    model = model,
    cache = cache,
    generate_assets = generate_assets
  )
  spec
}
