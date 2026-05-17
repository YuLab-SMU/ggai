# Pure-R package and help inspection. Pre-P2 these threaded a `ggai_session`
# through every call to record traces; with the agent now living in aisdk, the
# session-recording branches are gone — callers can wrap with their own
# observability if needed.

ggai_dependency_abort <- function(message) {
  rlang::abort(message, class = "ggai_dependency_error")
}

ggai_package_policy <- function(policy = NULL) {
  policy <- policy %||% getOption("ggai.package_policy", "ask")
  if (!policy %in% c("ask", "auto_cran", "never")) {
    ggai_dependency_abort("`policy` must be one of 'ask', 'auto_cran', or 'never'.")
  }
  policy
}

ggai_package_installed <- function(package) {
  requireNamespace(package, quietly = TRUE)
}

#' Check whether an R package is available
#'
#' @param package Package name.
#'
#' @return A package availability record.
#' @export
ggai_check_package <- function(package) {
  if (!ggai_contract_is_string(package)) {
    ggai_dependency_abort("`package` must be a single non-empty string.")
  }
  installed <- ggai_package_installed(package)
  list(
    package = package,
    installed = installed,
    status = if (installed) "available" else "missing"
  )
}

#' Install a CRAN package according to ggai package policy
#'
#' @param package Package name.
#' @param policy One of `"ask"`, `"auto_cran"`, or `"never"`.
#' @param lib Optional library path passed to `install.packages()`.
#' @param repos CRAN repository URL.
#' @param installer Installer function, primarily for tests.
#'
#' @return A structured package action record.
#' @export
ggai_install_cran_package <- function(package,
                                      policy = NULL,
                                      lib = NULL,
                                      repos = getOption("repos"),
                                      installer = utils::install.packages) {
  if (!ggai_contract_is_string(package)) {
    ggai_dependency_abort("`package` must be a single non-empty string.")
  }
  policy <- ggai_package_policy(policy)

  if (ggai_package_installed(package)) {
    return(list(package = package, policy = policy, status = "available", installed = TRUE))
  }

  if (identical(policy, "never")) {
    return(list(package = package, policy = policy, status = "blocked", reason = "policy_never"))
  }

  if (identical(policy, "ask")) {
    return(list(package = package, policy = policy, status = "approval_required", reason = "policy_ask"))
  }

  installer(package, lib = lib, repos = repos)
  installed <- ggai_package_installed(package)
  status <- if (installed) "installed" else "install_attempted"
  list(package = package, policy = policy, status = status, installed = installed)
}

ggai_help_text <- function(package, topic = package) {
  package_name <- package
  topic_name <- topic
  help_file <- do.call(
    utils::help,
    list(topic = topic_name, package = package_name, try.all.packages = FALSE)
  )
  get_help_file <- utils::getFromNamespace(".getHelpFile", "utils")
  path <- get_help_file(help_file)
  text <- paste(utils::capture.output(tools::Rd2txt(path)), collapse = "\n")
  gsub(".\b", "", text, fixed = FALSE)
}

#' Inspect local R help for a package topic
#'
#' @param package Package name.
#' @param topic Help topic. Defaults to the package name.
#' @param max_lines Maximum help lines to return.
#'
#' @return A local help record.
#' @export
ggai_inspect_help <- function(package, topic = package, max_lines = 80) {
  if (!ggai_package_installed(package)) {
    return(list(package = package, topic = topic, status = "missing_package"))
  }
  text <- tryCatch(ggai_help_text(package, topic), error = function(e) e)
  if (inherits(text, "error")) {
    return(list(package = package, topic = topic, status = "missing_help", message = conditionMessage(text)))
  }
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  list(package = package, topic = topic, status = "ok", text = paste(utils::head(lines, max_lines), collapse = "\n"))
}

#' Inspect local examples for an R help topic
#'
#' @param package Package name.
#' @param topic Example topic.
#'
#' @return A local examples record.
#' @export
ggai_inspect_examples <- function(package, topic = package) {
  if (!ggai_package_installed(package)) {
    return(list(package = package, topic = topic, status = "missing_package"))
  }
  code <- tryCatch(utils::capture.output(utils::example(topic, package = package, character.only = TRUE, run.dontrun = FALSE, ask = FALSE)), error = function(e) e)
  if (inherits(code, "error")) {
    return(list(package = package, topic = topic, status = "missing_examples", message = conditionMessage(code)))
  }
  list(package = package, topic = topic, status = "ok", output = code)
}

#' List local vignette metadata for an R package
#'
#' @param package Package name.
#'
#' @return A vignette index record.
#' @export
ggai_vignette_index <- function(package) {
  if (!ggai_package_installed(package)) {
    return(list(package = package, status = "missing_package", vignettes = list()))
  }
  info <- utils::vignette(package = package)
  rows <- info$results
  vignettes <- if (is.null(rows) || !nrow(rows)) {
    list()
  } else {
    lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop = FALSE]))
  }
  list(package = package, status = "ok", vignettes = vignettes)
}
