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

ggai_package_action_trace <- function(package, action, status, policy = NULL, details = list()) {
  new_ggai_agent_trace(
    task_id = paste0("package:", package),
    status = status,
    steps = list(ggai_agent_trace_step(action, status = status, details = details)),
    tool_calls = list(list(name = paste0("ggai_package_", action), status = status)),
    observations = list(list(type = "package_action", value = utils::modifyList(list(package = package, policy = policy), details))),
    completed_at = ggai_contract_timestamp()
  )
}

ggai_record_package_action <- function(session = NULL, package, action, status, policy = NULL, details = list()) {
  if (!inherits(session, "ggai_session")) {
    return(session)
  }
  session_record_agent_trace(
    session,
    ggai_package_action_trace(package = package, action = action, status = status, policy = policy, details = details)
  )
}

#' Check whether an R package is available
#'
#' @param package Package name.
#' @param session Optional `ggai_session` that receives a trace record.
#'
#' @return A package availability record.
#' @export
ggai_check_package <- function(package, session = NULL) {
  if (!ggai_contract_is_string(package)) {
    ggai_dependency_abort("`package` must be a single non-empty string.")
  }
  installed <- ggai_package_installed(package)
  status <- if (installed) "available" else "missing"
  session <- ggai_record_package_action(
    session,
    package = package,
    action = "check",
    status = status,
    details = list(installed = installed)
  )
  list(package = package, installed = installed, status = status, session = session)
}

#' Install a CRAN package according to ggai package policy
#'
#' @param package Package name.
#' @param policy One of `"ask"`, `"auto_cran"`, or `"never"`.
#' @param lib Optional library path passed to `install.packages()`.
#' @param repos CRAN repository URL.
#' @param session Optional `ggai_session` that receives a trace record.
#' @param installer Installer function, primarily for tests.
#'
#' @return A structured package action record.
#' @export
ggai_install_cran_package <- function(package,
                                      policy = NULL,
                                      lib = NULL,
                                      repos = getOption("repos"),
                                      session = NULL,
                                      installer = utils::install.packages) {
  if (!ggai_contract_is_string(package)) {
    ggai_dependency_abort("`package` must be a single non-empty string.")
  }
  policy <- ggai_package_policy(policy)

  if (ggai_package_installed(package)) {
    session <- ggai_record_package_action(session, package, "install", "available", policy, list(installed = TRUE))
    return(list(package = package, policy = policy, status = "available", installed = TRUE, session = session))
  }

  if (identical(policy, "never")) {
    session <- ggai_record_package_action(session, package, "install", "blocked", policy, list(reason = "policy_never"))
    return(list(package = package, policy = policy, status = "blocked", reason = "policy_never", session = session))
  }

  if (identical(policy, "ask")) {
    session <- ggai_record_package_action(session, package, "install", "approval_required", policy, list(reason = "policy_ask"))
    return(list(package = package, policy = policy, status = "approval_required", reason = "policy_ask", session = session))
  }

  installer(package, lib = lib, repos = repos)
  installed <- ggai_package_installed(package)
  status <- if (installed) "installed" else "install_attempted"
  session <- ggai_record_package_action(session, package, "install", status, policy, list(installed = installed))
  list(package = package, policy = policy, status = status, installed = installed, session = session)
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
