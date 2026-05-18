GeomPointAi <- ggplot2::ggproto(
  "GeomPointAi",
  ggplot2::Geom,
  required_aes = c("x", "y"),
  default_aes = ggplot2::aes(size = 6, alpha = 1),
  draw_key = ggplot2::draw_key_blank,
  draw_panel = function(data, panel_params, coord, asset = NULL, na.rm = FALSE) {
    coords <- coord$transform(data, panel_params)
    raster <- try_read_image_raster(asset$path %||% NULL)

    grobs <- lapply(seq_len(nrow(coords)), function(i) {
      x <- grid::unit(coords$x[i], "native")
      y <- grid::unit(coords$y[i], "native")
      size_mm <- coords$size[i] %||% data$size[i] %||% 6
      width <- grid::unit(size_mm, "mm")
      height <- grid::unit(size_mm, "mm")

      if (!is.null(raster)) {
        return(grid::rasterGrob(
          image = raster,
          x = x,
          y = y,
          width = width,
          height = height,
          interpolate = TRUE
        ))
      }

      grid::pointsGrob(
        x = x,
        y = y,
        pch = 16,
        size = grid::unit(size_mm / 4, "mm"),
        gp = grid::gpar(alpha = coords$alpha[i] %||% 1)
      )
    })

    grid::grobTree(children = do.call(grid::gList, grobs))
  }
)

#' Draw points using a generated glyph asset
#'
#' @param mapping,data,... Standard ggplot2 layer arguments.
#' @param prompt Glyph prompt.
#' @param style Optional glyph style.
#' @param model Optional image model identifier.
#' @param cache Whether to cache the generated glyph.
#' @param inherit.aes Whether to inherit aesthetics.
#'
#' @export
geom_point_ai <- function(mapping = NULL,
                          data = NULL,
                          ...,
                          prompt,
                          style = NULL,
                          model = NULL,
                          cache = TRUE,
                          inherit.aes = TRUE) {
  asset <- generate_glyph_for_geom(
    prompt = prompt,
    style = style,
    model = model,
    cache = cache
  )

  ggplot2::layer(
    geom = GeomPointAi,
    stat = "identity",
    position = "identity",
    data = data,
    mapping = mapping,
    inherit.aes = inherit.aes,
    params = list(asset = asset, ...)
  )
}

CHROMA_KEY_PROMPT_FRAGMENT <- paste(
  "perfectly flat solid #00ff00 chroma-key background for background removal",
  "background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation",
  "keep the subject fully separated from the background with crisp edges and generous padding",
  "do not use #00ff00 anywhere in the subject",
  "no cast shadow, no contact shadow, no reflection, no watermark, no text",
  sep = ", "
)

generate_glyph_for_geom <- function(prompt,
                                    style = NULL,
                                    model = NULL,
                                    cache = TRUE,
                                    width = 1024L,
                                    height = 1024L,
                                    transparent_background = TRUE) {
  resolved_model <- model %||% ggai_default_models()$image
  key <- ggai_asset_cache_key(
    caller = "geom_point_ai",
    prompt = prompt,
    style = style,
    width = width,
    height = height,
    model = resolved_model,
    transparent_background = transparent_background
  )

  if (cache) {
    hit <- ggai_asset_cache_get(key)
    if (!is.null(hit)) return(hit)
  }

  if (isTRUE(transparent_background)) {
    final_prompt <- paste(Filter(nzchar, c(prompt, style, CHROMA_KEY_PROMPT_FRAGMENT)), collapse = ", ")
  } else {
    final_prompt <- paste(Filter(nzchar, c(prompt, style)), collapse = ", ")
  }

  output <- ggai_generate_image(
    model = ggai_image_model(model),
    prompt = final_prompt,
    output_dir = tempdir(),
    width = width,
    height = height
  )

  image <- output$images[[1]]
  if (is.null(image$path) || !file.exists(image$path)) {
    rlang::abort("Image generation did not return a materialized file path.")
  }

  final_path <- image$path
  if (isTRUE(transparent_background)) {
    cleaned <- ggai_remove_background(image$path, key_color = "#00ff00")
    final_path <- cleaned %||% image$path
  }

  metadata <- list(
    prompt = prompt,
    style = style,
    width = width,
    height = height,
    media_type = image$media_type,
    source_path = image$path,
    chroma_keyed = isTRUE(transparent_background)
  )

  if (cache) {
    return(ggai_asset_cache_put(final_path, key, metadata = metadata))
  }

  asset <- c(list(path = final_path, key = key), metadata)
  class(asset) <- c("ggai_image_asset", "list")
  asset
}
