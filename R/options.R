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

ggai_env_file_paths <- function(project_root = getwd()) {
  unique(c(
    file.path(project_root, ".env"),
    file.path(project_root, ".Renviron"),
    path.expand("~/.Renviron")
  ))
}

ggai_strip_env_value <- function(value) {
  value <- trimws(value)
  if (grepl('^".*"$', value) || grepl("^'.*'$", value)) {
    value <- substring(value, 2L, nchar(value) - 1L)
  }
  value
}

ggai_read_env_file <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }

  lines <- readLines(path, warn = FALSE)
  out <- list()
  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line) || startsWith(line, "#")) {
      next
    }
    line <- sub("^export[[:space:]]+", "", line)
    eq <- regexpr("=", line, fixed = TRUE)
    if (eq < 2L) {
      next
    }
    key <- trimws(substr(line, 1L, eq - 1L))
    value <- substr(line, eq + 1L, nchar(line))
    if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", key)) {
      next
    }
    out[[key]] <- ggai_strip_env_value(value)
  }
  out
}

ggai_file_env_value <- function(keys, paths = ggai_env_file_paths()) {
  for (key in keys) {
    for (path in paths) {
      values <- ggai_read_env_file(path)
      if (!length(values)) {
        next
      }
      value <- values[[key]]
      if (!is.null(value) && nzchar(value)) {
        return(value)
      }
    }
  }
  NULL
}

ggai_env_value <- function(keys, default = NULL, paths = ggai_env_file_paths()) {
  value <- ggai_file_env_value(keys, paths = paths)
  if (!is.null(value)) {
    return(value)
  }

  values <- Sys.getenv(keys, unset = NA_character_)
  for (value in values) {
    if (!is.na(value) && nzchar(value)) {
      return(value)
    }
  }
  default
}

#' Load ggai environment files
#'
#' Reads simple `KEY=value` assignments from project `.env`, project
#' `.Renviron`, and user `~/.Renviron`. Existing process variables are preserved
#' unless `override = TRUE`.
#'
#' @param paths Optional environment file paths.
#' @param override Whether file values should replace existing process values.
#'
#' @return Invisibly returns a named character vector of loaded keys.
#' @export
ggai_load_env <- function(paths = ggai_env_file_paths(), override = FALSE) {
  loaded <- character()
  for (path in paths) {
    values <- ggai_read_env_file(path)
    if (!length(values)) {
      next
    }
    for (key in names(values)) {
      current <- Sys.getenv(key, unset = NA_character_)
      if (isTRUE(override) || is.na(current) || !nzchar(current)) {
        do.call(Sys.setenv, stats::setNames(list(values[[key]]), key))
        loaded <- c(loaded, key)
      }
    }
  }
  invisible(unique(loaded))
}
