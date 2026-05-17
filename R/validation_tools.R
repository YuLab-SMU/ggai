# Pure ggplot-side validation helpers. Pre-P2 this file also defined
# session-coupled validate/repair loops; those moved out with the agent layer.
# Callers that need looped repair should drive it through the new agent
# (which has `ggai_validate_artifact` as a tool) rather than re-introducing
# a session-state mutator here.

ggai_validation_issue <- function(type, status, message, details = list()) {
  list(type = type, status = status, message = message, details = details)
}

ggai_mapping_variables <- function(mapping) {
  if (is.null(mapping) || !length(mapping)) {
    return(character())
  }
  unique(unlist(lapply(mapping, function(item) {
    expr <- tryCatch(rlang::get_expr(item), error = function(...) item)
    tryCatch(all.vars(expr), error = function(...) character())
  }), use.names = FALSE))
}

ggai_plot_referenced_variables <- function(plot) {
  vars <- ggai_mapping_variables(plot$mapping)
  for (layer in plot$layers %||% list()) {
    vars <- c(vars, ggai_mapping_variables(layer$mapping))
  }
  unique(vars)
}

ggai_validate_plot_build <- function(plot) {
  warnings <- character()
  built <- tryCatch(
    withCallingHandlers(
      ggplot2::ggplot_build(plot),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  if (inherits(built, "error")) {
    return(ggai_validation_issue("plot_build", "fail", conditionMessage(built), list(warnings = warnings)))
  }
  ggai_validation_issue("plot_build", "pass", "Plot builds successfully.", list(warnings = warnings))
}

ggai_validate_referenced_variables <- function(plot) {
  data <- plot$data %||% NULL
  vars <- ggai_plot_referenced_variables(plot)
  if (!is.data.frame(data) || !length(vars)) {
    return(ggai_validation_issue("referenced_variables", "pass", "No data-backed variable references to validate.", list(referenced = vars)))
  }
  missing <- setdiff(vars, names(data))
  if (length(missing)) {
    return(ggai_validation_issue(
      "referenced_variables",
      "fail",
      "Plot references variables that are not present in data.",
      list(referenced = vars, missing = missing, available = names(data))
    ))
  }
  ggai_validation_issue("referenced_variables", "pass", "All referenced variables exist.", list(referenced = vars))
}

ggai_validate_stat_annotation_consistency <- function(analysis = NULL, visual = NULL) {
  decisions <- analysis$method_decisions %||% list()
  annotations <- visual$annotations %||% list()
  if (!length(decisions) || !length(annotations)) {
    return(ggai_validation_issue("stat_annotation_consistency", "pass", "No statistical annotation consistency check needed."))
  }

  decision_methods <- vapply(decisions, function(item) item$method %||% "", character(1))
  annotation_methods <- vapply(annotations, function(item) item$method %||% "", character(1))
  annotation_methods <- annotation_methods[nzchar(annotation_methods)]
  if (length(annotation_methods) && !all(annotation_methods %in% decision_methods)) {
    return(ggai_validation_issue(
      "stat_annotation_consistency",
      "fail",
      "Visual statistical annotations do not match analysis method decisions.",
      list(decision_methods = decision_methods, annotation_methods = annotation_methods)
    ))
  }
  ggai_validation_issue("stat_annotation_consistency", "pass", "Statistical annotations match method decisions.")
}

ggai_validate_source_evidence_coverage <- function(goal = NULL, visual = NULL) {
  detected <- ggai_detect_source_urls(goal %||% "")
  if (!length(detected$urls %||% list())) {
    return(ggai_validation_issue("source_evidence_coverage", "pass", "No source URLs were requested."))
  }

  evidence <- visual$evidence %||% list()
  evidence_sources <- vapply(evidence, function(item) item$source %||% item$locator %||% "", character(1))
  missing <- setdiff(unlist(detected$urls, use.names = FALSE), evidence_sources)
  if (length(missing)) {
    return(ggai_validation_issue(
      "source_evidence_coverage",
      "fail",
      "Requested source URLs are missing evidence records.",
      list(missing = missing, evidence_sources = evidence_sources)
    ))
  }
  ggai_validation_issue("source_evidence_coverage", "pass", "Source URL evidence is covered.")
}

ggai_repair_missing_variable_plot <- function(plot, issue) {
  data <- plot$data %||% NULL
  available <- issue$details$available %||% names(data)
  if (!is.data.frame(data) || length(available) < 1L) {
    return(NULL)
  }
  x <- available[[1]]
  y <- available[[min(2L, length(available))]]
  ggplot2::ggplot(data, ggplot2::aes(x = !!rlang::sym(x), y = !!rlang::sym(y))) + ggplot2::geom_point()
}
