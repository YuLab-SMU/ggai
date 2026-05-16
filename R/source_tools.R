ggai_source_abort <- function(message) {
  rlang::abort(message, class = "ggai_source_error")
}

ggai_detect_urls <- function(text) {
  if (is.null(text) || !is.character(text) || !length(text)) {
    return(character())
  }
  matches <- regmatches(text, gregexpr("https?://[^[:space:]<>()]+", text, perl = TRUE))
  unique(unlist(matches, use.names = FALSE))
}

ggai_parse_github_url <- function(url) {
  pattern <- "^https?://github[.]com/([^/]+)/([^/#?]+)(?:/(.*))?$"
  match <- regexec(pattern, url, perl = TRUE)
  parts <- regmatches(url, match)[[1]]
  if (!length(parts)) {
    return(NULL)
  }
  path <- parts[[4]] %||% ""
  list(
    url = url,
    host = "github.com",
    owner = parts[[2]],
    repo = sub("[.]git$", "", parts[[3]]),
    path = path,
    is_repository = TRUE
  )
}

ggai_source_evidence <- function(kind, source, summary, locator = NULL, assumptions = list()) {
  list(
    kind = kind,
    source = source,
    locator = locator,
    summary = summary,
    assumptions = assumptions,
    timestamp = ggai_contract_timestamp()
  )
}

#' Detect URLs and GitHub repository references
#'
#' @param text Input text.
#'
#' @return A structured URL detection record.
#' @export
ggai_detect_source_urls <- function(text) {
  urls <- ggai_detect_urls(text)
  github <- Filter(Negate(is.null), lapply(urls, ggai_parse_github_url))
  list(
    urls = as.list(urls),
    github = github,
    evidence = c(
      lapply(urls, function(url) ggai_source_evidence("url", url, "Detected URL in user-provided text.", locator = url)),
      lapply(github, function(repo) ggai_source_evidence("github_repository", repo$url, paste0(repo$owner, "/", repo$repo), locator = repo$url))
    )
  )
}

#' Inspect a GitHub repository URL without network access
#'
#' @param url GitHub repository URL.
#'
#' @return A structured repository context record.
#' @export
ggai_inspect_github_url <- function(url) {
  repo <- ggai_parse_github_url(url)
  if (is.null(repo)) {
    ggai_source_abort("`url` must be a GitHub repository URL.")
  }
  list(
    repository = repo,
    evidence = list(ggai_source_evidence(
      "github_repository",
      repo$url,
      paste0("Parsed GitHub repository reference: ", repo$owner, "/", repo$repo),
      locator = repo$url,
      assumptions = list("No live GitHub fetch was performed.")
    ))
  )
}

ggai_source_root <- function(root = ".") {
  normalizePath(root, mustWork = TRUE)
}

ggai_source_safe_path <- function(path, root = ".") {
  root <- ggai_source_root(root)
  full <- tryCatch(
    normalizePath(file.path(root, path), mustWork = TRUE),
    error = function(e) ggai_source_abort(conditionMessage(e))
  )
  root_prefix <- paste0(root, .Platform$file.sep)
  if (!identical(full, root) && !startsWith(full, root_prefix)) {
    ggai_source_abort("`path` must stay within `root`.")
  }
  full
}

#' List local source files under a root
#'
#' @param root Root directory.
#' @param pattern Optional regular expression.
#' @param max_files Maximum files to return.
#'
#' @return A local file listing record.
#' @export
ggai_list_local_files <- function(root = ".", pattern = NULL, max_files = 100) {
  root <- ggai_source_root(root)
  files <- list.files(root, recursive = TRUE, all.files = FALSE, full.names = FALSE, no.. = TRUE)
  if (!is.null(pattern) && nzchar(pattern)) {
    files <- files[grepl(pattern, files)]
  }
  files <- utils::head(files, max_files)
  list(
    root = root,
    files = as.list(files),
    evidence = list(ggai_source_evidence("local_file_list", root, paste0("Listed ", length(files), " local files."), locator = root))
  )
}

#' Read a bounded local source file
#'
#' @param path Path relative to `root`.
#' @param root Root directory.
#' @param max_lines Maximum lines to return.
#'
#' @return A local source read record.
#' @export
ggai_read_local_file <- function(path, root = ".", max_lines = 200) {
  full <- ggai_source_safe_path(path, root = root)
  info <- file.info(full)
  if (isTRUE(info$isdir)) {
    ggai_source_abort("`path` must point to a file, not a directory.")
  }
  lines <- readLines(full, warn = FALSE, n = max_lines)
  list(
    path = path,
    root = ggai_source_root(root),
    lines = as.list(lines),
    truncated = length(lines) >= max_lines,
    evidence = list(ggai_source_evidence("local_file", path, paste0("Read local file: ", path), locator = full))
  )
}

#' Summarize source evidence records
#'
#' @param evidence Evidence record or list of evidence records.
#'
#' @return A source summary record.
#' @export
ggai_summarize_sources <- function(evidence) {
  evidence <- if (is.null(evidence)) list() else evidence
  if (length(evidence) && !is.null(evidence$kind)) {
    evidence <- list(evidence)
  }
  list(
    evidence_count = length(evidence),
    kinds = as.list(unique(vapply(evidence, function(item) item$kind %||% "unknown", character(1)))),
    sources = lapply(evidence, function(item) item$source %||% item$locator %||% NULL),
    summary = paste(vapply(evidence, function(item) item$summary %||% "", character(1)), collapse = "\n")
  )
}
