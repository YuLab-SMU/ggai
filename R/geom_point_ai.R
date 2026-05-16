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
  asset <- glyph_ai(
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
