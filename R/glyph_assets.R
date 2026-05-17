file_ext_or <- function(path, default = "png") {
  ext <- tools::file_ext(path %||% "")
  if (!nzchar(ext)) {
    default
  } else {
    ext
  }
}

as_rgba_array <- function(raster) {
  dims <- dim(raster)
  if (is.null(dims)) {
    return(NULL)
  }

  if (length(dims) == 2) {
    out <- array(1, dim = c(dims[[1]], dims[[2]], 4))
    for (i in 1:3) out[, , i] <- raster
    return(out)
  }

  if (length(dims) == 3 && dims[[3]] == 3) {
    out <- array(1, dim = c(dims[[1]], dims[[2]], 4))
    out[, , 1:3] <- raster
    return(out)
  }

  if (length(dims) == 3 && dims[[3]] >= 4) {
    return(raster[, , 1:4, drop = FALSE])
  }

  NULL
}

sample_background_palette <- function(rgba) {
  h <- dim(rgba)[1]
  w <- dim(rgba)[2]
  pad_h <- max(2L, floor(h * 0.06))
  pad_w <- max(2L, floor(w * 0.06))
  patches <- list(
    rgba[1:pad_h, 1:pad_w, 1:3, drop = FALSE],
    rgba[1:pad_h, (w - pad_w + 1):w, 1:3, drop = FALSE],
    rgba[(h - pad_h + 1):h, 1:pad_w, 1:3, drop = FALSE],
    rgba[(h - pad_h + 1):h, (w - pad_w + 1):w, 1:3, drop = FALSE]
  )
  t(vapply(patches, function(x) colMeans(matrix(x, ncol = 3)), numeric(3)))
}

background_distance <- function(rgba, palette) {
  rgb <- rgba[, , 1:3, drop = FALSE]
  dists <- lapply(seq_len(nrow(palette)), function(i) {
    p <- matrix(palette[i, ], nrow = 1)
    sqrt((rgb[, , 1] - p[1, 1])^2 + (rgb[, , 2] - p[1, 2])^2 + (rgb[, , 3] - p[1, 3])^2)
  })
  Reduce(pmin, dists)
}

remove_keyed_background <- function(rgba, tolerance = 0.16, brightness_min = 0.68) {
  palette <- sample_background_palette(rgba)
  dist <- background_distance(rgba, palette)
  brightness <- (rgba[, , 1] + rgba[, , 2] + rgba[, , 3]) / 3
  mask <- dist < tolerance & brightness > brightness_min
  rgba[, , 4][mask] <- 0
  rgba
}

crop_rgba_to_alpha <- function(rgba, pad = 8L) {
  alpha <- rgba[, , 4]
  idx <- which(alpha > 0.05, arr.ind = TRUE)
  if (!nrow(idx)) {
    return(rgba)
  }

  r1 <- max(1L, min(idx[, 1]) - pad)
  r2 <- min(dim(rgba)[1], max(idx[, 1]) + pad)
  c1 <- max(1L, min(idx[, 2]) - pad)
  c2 <- min(dim(rgba)[2], max(idx[, 2]) + pad)
  rgba[r1:r2, c1:c2, , drop = FALSE]
}

bio_asset_quality_score <- function(rgba) {
  alpha <- rgba[, , 4]
  coverage <- mean(alpha > 0.05)
  border <- c(alpha[1, ], alpha[nrow(alpha), ], alpha[, 1], alpha[, ncol(alpha)])
  border_penalty <- mean(border > 0.05)
  (1 - abs(coverage - 0.45)) - border_penalty
}

write_rgba_png <- function(rgba, path) {
  if (!requireNamespace("png", quietly = TRUE)) {
    return(NULL)
  }
  png::writePNG(rgba, target = path)
  path
}

process_bio_asset_image <- function(path, output_dir = tempdir(), prefix = "bio_asset") {
  raster <- try_read_image_raster(path)
  rgba <- as_rgba_array(raster)
  if (is.null(rgba)) {
    return(list(path = path, source_path = path, score = -Inf))
  }

  rgba <- remove_keyed_background(rgba)
  rgba <- crop_rgba_to_alpha(rgba)
  score <- bio_asset_quality_score(rgba)
  processed <- file.path(output_dir, paste0(prefix, "_processed.png"))
  written <- write_rgba_png(rgba, processed)

  list(
    path = written %||% path,
    source_path = path,
    score = score
  )
}

copy_image_to_cache <- function(source_path, cache_path) {
  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(source_path, cache_path, overwrite = TRUE)
  if (!ok) {
    rlang::abort(paste0("Failed to copy generated glyph into cache: ", cache_path))
  }

  cache_path
}

#' Generate an image through the configured `aisdk` image backend
#'
#' Thin ggai wrapper around `aisdk::generate_image()`. The OpenAI provider
#' inside aisdk handles classic-vs-Responses-API routing automatically:
#' when the classic `/v1/images/generations` endpoint is unreachable (e.g.
#' an OpenAI-compatible proxy that only serves the newer Responses API),
#' aisdk falls back to `POST /v1/responses` with the `image_generation`
#' tool. ggai doesn't need to know about either route.
#'
#' @param ... Passed through to `aisdk::generate_image()`.
#'
#' @return An `aisdk` image generation result.
#' @export
ggai_generate_image <- function(...) {
  ggai_aisdk("generate_image")(...)
}

#' Edit or extend an image through the configured `aisdk` image backend
#'
#' Thin ggai wrapper around `aisdk::edit_image()`. Use this for communication
#' layers that keep a statistical figure as a reference image, such as
#' plot-reader explainers, infographic boards, and story pages.
#'
#' @param ... Passed through to `aisdk::edit_image()`.
#'
#' @return An `aisdk` image editing result.
#' @export
ggai_edit_image <- function(...) {
  ggai_aisdk("edit_image")(...)
}

glyph_generate_asset <- function(prompt,
                                 style = NULL,
                                 negative_prompt = NULL,
                                 width = 256,
                                 height = 256,
                                 model = NULL,
                                 cache = TRUE,
                                 transparent_background = TRUE) {
  key <- glyph_cache_key(
    prompt = paste(c(prompt, negative_prompt), collapse = " || "),
    style = style,
    width = width,
    height = height,
    model = model,
    transparent_background = transparent_background
  )

  if (cache) {
    cached <- read_cached_glyph(key)
    if (!is.null(cached)) {
      return(cached)
    }
  }

  final_prompt <- paste(Filter(nzchar, c(
    prompt,
    style,
    if (!is.null(negative_prompt) && nzchar(negative_prompt)) paste0("Avoid: ", negative_prompt) else NULL
  )), collapse = ", ")
  output <- ggai_generate_image(
    model = ggai_image_model(model),
    prompt = final_prompt,
    output_dir = tempdir(),
    width = width,
    height = height,
    transparent_background = transparent_background
  )

  image <- output$images[[1]]
  if (is.null(image$path) || !file.exists(image$path)) {
    rlang::abort("Image generation did not return a materialized file path.")
  }

  ext <- file_ext_or(image$path, default = "png")
  cache_path <- glyph_cache_path(key, ext = ext)
  copy_image_to_cache(image$path, cache_path)

  asset <- list(
    path = cache_path,
    source_path = image$path,
    prompt = prompt,
    style = style,
    negative_prompt = negative_prompt,
    width = width,
    height = height,
    media_type = image$media_type %||% NULL,
    key = key
  )

  if (cache) {
    return(write_cached_glyph(key, asset))
  }

  class(asset) <- c("ggai_glyph_asset", "list")
  asset
}

try_read_image_raster <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    return(NULL)
  }

  ext <- tolower(tools::file_ext(path))
  if (ext == "png" && requireNamespace("png", quietly = TRUE)) {
    return(png::readPNG(path))
  }
  if (ext %in% c("jpg", "jpeg") && requireNamespace("jpeg", quietly = TRUE)) {
    return(jpeg::readJPEG(path))
  }

  NULL
}
