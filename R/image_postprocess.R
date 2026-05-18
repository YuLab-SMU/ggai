as_rgba_array <- function(raster) {
  dims <- dim(raster)
  if (is.null(dims)) return(NULL)

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

crop_rgba_to_alpha <- function(rgba, pad) {
  alpha <- rgba[, , 4]
  idx <- which(alpha > 0.05, arr.ind = TRUE)
  if (!nrow(idx)) return(rgba)

  r1 <- max(1L, min(idx[, 1]) - pad)
  r2 <- min(dim(rgba)[1], max(idx[, 1]) + pad)
  c1 <- max(1L, min(idx[, 2]) - pad)
  c2 <- min(dim(rgba)[2], max(idx[, 2]) + pad)
  rgba[r1:r2, c1:c2, , drop = FALSE]
}

parse_hex_color <- function(hex) {
  hex <- sub("^#", "", hex)
  if (!grepl("^[0-9a-fA-F]{6}$", hex)) {
    rlang::abort(paste0("key_color must be a hex RGB value like #00ff00, got: ", hex))
  }
  c(
    strtoi(substr(hex, 1, 2), base = 16L),
    strtoi(substr(hex, 3, 4), base = 16L),
    strtoi(substr(hex, 5, 6), base = 16L)
  ) / 255
}

sample_border_key <- function(rgba, mode = c("border", "corners")) {
  mode <- match.arg(mode)
  h <- dim(rgba)[1]
  w <- dim(rgba)[2]

  if (mode == "corners") {
    patch <- max(1L, min(h, w, 12L))
    boxes <- list(
      list(1L:patch, 1L:patch),
      list(1L:patch, (w - patch + 1L):w),
      list((h - patch + 1L):h, 1L:patch),
      list((h - patch + 1L):h, (w - patch + 1L):w)
    )
    samples <- do.call(rbind, lapply(boxes, function(b) {
      matrix(rgba[b[[1]], b[[2]], 1:3], ncol = 3)
    }))
  } else {
    band <- max(1L, min(h, w, 6L))
    step <- max(1L, min(h, w) %/% 256L)
    h_idx <- seq(1L, h, by = step)
    w_idx <- seq(1L, w, by = step)
    samples <- rbind(
      matrix(rgba[1L:band, w_idx, 1:3], ncol = 3),
      matrix(rgba[(h - band + 1L):h, w_idx, 1:3], ncol = 3),
      matrix(rgba[h_idx, 1L:band, 1:3], ncol = 3),
      matrix(rgba[h_idx, (w - band + 1L):w, 1:3], ncol = 3)
    )
  }

  if (!nrow(samples)) {
    rlang::abort("Could not sample border pixels for auto-key detection.")
  }
  apply(samples, 2, stats::median)
}

spill_channels_of <- function(key) {
  key_max <- max(key)
  if (key_max < 0.5) return(integer(0))
  which(key >= (key_max - 16 / 255) & key >= 0.5)
}

#' Remove a flat chroma-key background and return an alpha PNG
#'
#' Ports the algorithm used by the official Codex `imagegen` skill
#' (`remove_chroma_key.py`): sample the background key colour from the image
#' border, key off Chebyshev distance to that colour, build a smooth alpha
#' ramp between the transparent and opaque thresholds, combine with a
#' key-channel dominance penalty to catch antialiased edges, then despill
#' the key colour from partially-transparent pixels.
#'
#' This is the default post-processing step after generating an asset on a
#' chroma-key background — the recommended workflow for `gpt-image-2`,
#' which does not honour the API's `background = "transparent"` parameter.
#'
#' @param path Path to the source image (PNG or JPEG).
#' @param output_path Optional output path. Defaults to a sibling file with
#'   `_nobg.png` suffix in the same directory.
#' @param key_color Optional hex string (e.g. `"#00ff00"`). When `NULL`
#'   (the default), the key colour is sampled from the image border as the
#'   per-channel median.
#' @param transparent_threshold Chebyshev distance below which pixels are
#'   fully transparent. Default `12/255` matches the official skill.
#' @param opaque_threshold Chebyshev distance at or above which pixels are
#'   fully opaque. Default `220/255` matches the official skill's
#'   recommended invocation.
#' @param despill Whether to cap key-colour spill on partially-transparent
#'   pixels by clamping the key channels to the strongest non-key channel.
#' @param crop Whether to crop the output to the alpha bounding box.
#' @param pad Pixel padding to leave around the cropped subject.
#' @param alpha_noise_floor Alpha values at or below this (and above 0) are
#'   snapped to 0 to suppress speckle. Default `8/255`.
#'
#' @return Path to the written PNG with alpha channel. `NULL` if the image
#'   could not be read or the `png` package is unavailable.
#'
#' @export
ggai_remove_background <- function(path,
                                   output_path = NULL,
                                   key_color = NULL,
                                   transparent_threshold = 12 / 255,
                                   opaque_threshold = 220 / 255,
                                   despill = TRUE,
                                   crop = TRUE,
                                   pad = 8L,
                                   alpha_noise_floor = 8 / 255) {
  if (transparent_threshold >= opaque_threshold) {
    rlang::abort("transparent_threshold must be lower than opaque_threshold.")
  }

  raster <- try_read_image_raster(path)
  rgba <- as_rgba_array(raster)
  if (is.null(rgba)) return(NULL)

  key <- if (is.null(key_color)) sample_border_key(rgba) else parse_hex_color(key_color)

  r <- rgba[, , 1]
  g <- rgba[, , 2]
  b <- rgba[, , 3]
  a <- rgba[, , 4]

  dist <- pmax(abs(r - key[1]), abs(g - key[2]), abs(b - key[3]))

  ramp <- (dist - transparent_threshold) / (opaque_threshold - transparent_threshold)
  ramp <- pmin(1, pmax(0, ramp))
  soft_alpha <- ramp * ramp * (3 - 2 * ramp)

  spill <- spill_channels_of(key)
  non_spill <- setdiff(1:3, spill)
  channels <- list(r, g, b)
  has_spill_split <- length(spill) >= 1L && length(non_spill) >= 1L

  if (has_spill_split) {
    key_strength <- if (length(spill) == 1L) channels[[spill]] else Reduce(pmin, channels[spill])
    non_key_strength <- if (length(non_spill) == 1L) channels[[non_spill]] else Reduce(pmax, channels[non_spill])
    channel_dom <- key_strength - non_key_strength

    key_like <- (dist <= 32 / 255) | (channel_dom >= 16 / 255)

    denom <- pmax(1 / 255, max(key) - non_key_strength)
    dom_alpha <- 1 - pmin(1, pmax(0, channel_dom) / denom)

    alpha_new <- ifelse(key_like, pmin(soft_alpha, dom_alpha), 1)
    dim(alpha_new) <- dim(soft_alpha)
  } else {
    alpha_new <- soft_alpha
  }

  alpha_new <- alpha_new * a

  cull <- alpha_new > 0 & alpha_new <= alpha_noise_floor
  alpha_new[cull] <- 0

  if (despill && has_spill_split) {
    despill_mask <- alpha_new > 0 & alpha_new < (252 / 255) & key_like
    if (any(despill_mask)) {
      anchor <- if (length(non_spill) == 1L) channels[[non_spill]] else Reduce(pmax, channels[non_spill])
      cap <- pmax(0, anchor - 1 / 255)
      for (ch_idx in spill) {
        ch <- channels[[ch_idx]]
        mask <- despill_mask & ch > cap
        ch[mask] <- cap[mask]
        channels[[ch_idx]] <- ch
      }
      r <- channels[[1]]
      g <- channels[[2]]
      b <- channels[[3]]
    }
  }

  zero <- alpha_new == 0
  r[zero] <- 0
  g[zero] <- 0
  b[zero] <- 0

  out_rgba <- array(0, dim = c(dim(r), 4L))
  out_rgba[, , 1] <- r
  out_rgba[, , 2] <- g
  out_rgba[, , 3] <- b
  out_rgba[, , 4] <- alpha_new

  if (isTRUE(crop)) {
    out_rgba <- crop_rgba_to_alpha(out_rgba, pad = pad)
  }

  if (!requireNamespace("png", quietly = TRUE)) return(NULL)

  out <- output_path %||% file.path(
    dirname(path),
    paste0(tools::file_path_sans_ext(basename(path)), "_nobg.png")
  )
  png::writePNG(out_rgba, target = out)
  out
}
