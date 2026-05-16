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

ggai_validate_reproducible_code <- function(session) {
  code <- tryCatch(as_code(session), error = function(e) e)
  if (inherits(code, "error")) {
    return(ggai_validation_issue("reproducible_code", "warn", conditionMessage(code)))
  }
  if (!is.character(code) || !length(code) || !nzchar(code[[1]])) {
    return(ggai_validation_issue("reproducible_code", "fail", "Generated code is empty."))
  }
  ggai_validation_issue("reproducible_code", "pass", "Reproducible code is available.", list(code = code))
}

#' Validate a ggai session artifact
#'
#' @param session A `ggai_session`.
#' @param analysis Optional `analysis_brief`.
#' @param visual Optional `visual_brief`.
#' @param goal Optional user goal.
#'
#' @return A validation report.
#' @export
ggai_validate_session_artifact <- function(session, analysis = NULL, visual = NULL, goal = NULL) {
  if (!inherits(session, "ggai_session")) {
    rlang::abort("`session` must be a ggai_session.")
  }
  plot <- session_current_plot(session)
  issues <- list(
    ggai_validate_plot_build(plot),
    ggai_validate_referenced_variables(plot),
    ggai_validate_stat_annotation_consistency(analysis = analysis, visual = visual),
    ggai_validate_source_evidence_coverage(goal = goal, visual = visual),
    ggai_validate_reproducible_code(session)
  )
  statuses <- vapply(issues, function(issue) issue$status %||% "fail", character(1))
  list(
    status = if (any(statuses == "fail")) "fail" else if (any(statuses == "warn")) "warn" else "pass",
    issues = issues
  )
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

ggai_repair_session_once <- function(session, report) {
  failures <- Filter(function(issue) identical(issue$status, "fail"), report$issues %||% list())
  for (issue in failures) {
    if (identical(issue$type, "referenced_variables")) {
      repaired <- ggai_repair_missing_variable_plot(session_current_plot(session), issue)
      if (inherits(repaired, "ggplot")) {
        session$base_plot <- repaired
        session$history <- list()
        session$history_index <- 0L
        session <- session_touch_state(session, instruction = session$state$active_instruction %||% NULL)
        return(list(session = session, repaired = TRUE, action = "replace_missing_variable_mapping"))
      }
    }
  }
  list(session = session, repaired = FALSE, action = "none")
}

#' Run a bounded validation and repair loop
#'
#' @param session A `ggai_session`.
#' @param analysis Optional `analysis_brief`.
#' @param visual Optional `visual_brief`.
#' @param goal Optional user goal.
#' @param max_attempts Maximum repair attempts.
#'
#' @return A list with `session`, `initial`, `final`, and `repairs`.
#' @export
ggai_validate_and_repair <- function(session, analysis = NULL, visual = NULL, goal = NULL, max_attempts = 1L) {
  initial <- ggai_validate_session_artifact(session, analysis = analysis, visual = visual, goal = goal)
  repairs <- list()
  current <- session
  final <- initial

  attempts <- max(0L, as.integer(max_attempts %||% 0L))
  if (identical(initial$status, "fail") && attempts > 0L) {
    for (i in seq_len(attempts)) {
      repaired <- ggai_repair_session_once(current, final)
      repairs[[length(repairs) + 1L]] <- list(attempt = i, action = repaired$action, repaired = repaired$repaired)
      current <- repaired$session
      final <- ggai_validate_session_artifact(current, analysis = analysis, visual = visual, goal = goal)
      if (!identical(final$status, "fail") || !isTRUE(repaired$repaired)) {
        break
      }
    }
  }

  trace <- new_ggai_agent_trace(
    task_id = "validation_repair",
    status = final$status,
    steps = list(
      ggai_agent_trace_step("validate_artifact", status = initial$status, details = initial),
      ggai_agent_trace_step("repair_artifact", status = if (length(repairs)) "attempted" else "skipped", details = list(repairs = repairs)),
      ggai_agent_trace_step("validate_final_artifact", status = final$status, details = final)
    ),
    observations = list(
      list(type = "initial_validation", value = initial),
      list(type = "repair_attempts", value = repairs),
      list(type = "final_validation", value = final)
    ),
    completed_at = ggai_contract_timestamp()
  )
  current <- session_record_agent_trace(current, trace)
  list(session = current, initial = initial, final = final, repairs = repairs)
}
