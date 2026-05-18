ggai_cache_dir <- function() {
  dir <- getOption("ggai.cache_dir", Sys.getenv("GGAI_CACHE_DIR", file.path(tempdir(), "ggai-cache")))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

file_ext_or <- function(path, default = "png") {
  ext <- tools::file_ext(path %||% "")
  if (!nzchar(ext)) default else ext
}

# Hash arbitrary named inputs into a stable cache key. Callers decide what
# goes into the key; the cache layer is agnostic to prompt/style/etc.
ggai_asset_cache_key <- function(...) {
  digest::digest(list(...))
}

ggai_asset_cache_path <- function(key, ext = "png") {
  file.path(ggai_cache_dir(), paste0(key, ".", ext))
}

ggai_asset_metadata_path <- function(key) {
  file.path(ggai_cache_dir(), paste0(key, ".json"))
}

ggai_asset_cache_get <- function(key) {
  meta_path <- ggai_asset_metadata_path(key)
  if (!file.exists(meta_path)) return(NULL)

  meta <- jsonlite::fromJSON(meta_path, simplifyVector = FALSE)
  if (is.null(meta$path) || !file.exists(meta$path)) return(NULL)

  class(meta) <- c("ggai_image_asset", "list")
  meta
}

ggai_asset_cache_put <- function(source_path, key, metadata = list()) {
  if (is.null(source_path) || !file.exists(source_path)) {
    rlang::abort("ggai_asset_cache_put: source path does not exist.")
  }

  ext <- file_ext_or(source_path, default = "png")
  cache_path <- ggai_asset_cache_path(key, ext = ext)
  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source_path, cache_path, overwrite = TRUE)) {
    rlang::abort(paste0("Failed to copy asset into cache: ", cache_path))
  }

  asset <- c(list(path = cache_path, key = key), metadata)
  jsonlite::write_json(asset, ggai_asset_metadata_path(key), auto_unbox = TRUE, pretty = TRUE)
  class(asset) <- c("ggai_image_asset", "list")
  asset
}
