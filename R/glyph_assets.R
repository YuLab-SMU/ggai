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

try_read_image_raster <- function(path) {
  if (is.null(path) || !file.exists(path)) return(NULL)

  ext <- tolower(tools::file_ext(path))
  reader <- NULL
  if (ext == "png" && requireNamespace("png", quietly = TRUE)) {
    reader <- function() png::readPNG(path)
  } else if (ext %in% c("jpg", "jpeg") && requireNamespace("jpeg", quietly = TRUE)) {
    reader <- function() jpeg::readJPEG(path)
  }

  if (is.null(reader)) return(NULL)

  tryCatch(reader(), error = function(e) NULL)
}
