#' Default local `aisdk` development path
#'
#' @return A scalar character string.
#' @export
ggai_default_aisdk_path <- function() {
  "/Users/xiayh/Projects/aisdk"
}

ggai_aisdk_path <- function() {
  getOption("ggai.aisdk_path", Sys.getenv("GGAI_AISDK_PATH", ggai_default_aisdk_path()))
}

ggai_cache_dir <- function() {
  getOption("ggai.cache_dir", Sys.getenv("GGAI_CACHE_DIR", file.path(tempdir(), "ggai-cache")))
}

ggai_verbose <- function() {
  opt <- getOption("ggai.verbose", NULL)
  if (!is.null(opt)) {
    return(isTRUE(opt))
  }
  tolower(Sys.getenv("GGAI_VERBOSE", "false")) %in% c("1", "true", "yes", "on")
}

ggai_diagram_theme <- function() {
  getOption("ggai.diagram_theme", Sys.getenv("GGAI_DIAGRAM_THEME", "paper"))
}

ggai_compiler_max_attempts <- function() {
  raw <- getOption("ggai.compiler_max_attempts", Sys.getenv("GGAI_COMPILER_MAX_ATTEMPTS", "2"))
  max(1L, as.integer(raw))
}

ggai_review_compiler_output <- function() {
  opt <- getOption("ggai.review_compiler_output", NULL)
  if (!is.null(opt)) {
    return(isTRUE(opt))
  }
  tolower(Sys.getenv("GGAI_REVIEW_COMPILER_OUTPUT", "false")) %in% c("1", "true", "yes", "on")
}

ggai_bio_asset_attempts <- function() {
  raw <- getOption("ggai.bio_asset_attempts", Sys.getenv("GGAI_BIO_ASSET_ATTEMPTS", "1"))
  max(1L, as.integer(raw))
}

ggai_figure_resolution <- function() {
  raw <- getOption("ggai.figure_resolution", Sys.getenv("GGAI_FIGURE_RESOLUTION", "2048x1365"))
  parts <- strsplit(raw, "x", fixed = TRUE)[[1]]
  if (length(parts) != 2) {
    return(list(width = 2048L, height = 1365L))
  }
  list(width = as.integer(parts[[1]]), height = as.integer(parts[[2]]))
}
