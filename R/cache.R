ggai_cache_dir <- function() {
  dir <- getOption("ggai.cache_dir", Sys.getenv("GGAI_CACHE_DIR", file.path(tempdir(), "ggai-cache")))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

glyph_cache_key <- function(prompt,
                            style = NULL,
                            width = 256,
                            height = 256,
                            model = NULL,
                            transparent_background = TRUE) {
  digest::digest(list(
    prompt = prompt,
    style = style,
    width = width,
    height = height,
    model = model %||% ggai_default_models()$image,
    transparent_background = transparent_background
  ))
}

glyph_cache_path <- function(key, ext = "png") {
  file.path(ggai_cache_dir(), paste0(key, ".", ext))
}

glyph_metadata_path <- function(key) {
  file.path(ggai_cache_dir(), paste0(key, ".json"))
}

read_cached_glyph <- function(key) {
  meta_path <- glyph_metadata_path(key)
  if (!file.exists(meta_path)) {
    return(NULL)
  }

  meta <- jsonlite::fromJSON(meta_path, simplifyVector = FALSE)
  if (!is.null(meta$path) && file.exists(meta$path)) {
    class(meta) <- c("ggai_glyph_asset", "list")
    return(meta)
  }

  NULL
}

write_cached_glyph <- function(key, asset) {
  jsonlite::write_json(asset, glyph_metadata_path(key), auto_unbox = TRUE, pretty = TRUE)
  class(asset) <- c("ggai_glyph_asset", "list")
  asset
}
