ggai_contract_timestamp <- function() {
  format(Sys.time(), tz = "UTC", usetz = TRUE)
}

ggai_contract_id <- function(prefix) {
  paste0(prefix, "-", format(Sys.time(), "%Y%m%d%H%M%OS3", tz = "UTC"), "-", sample.int(999999L, 1L))
}

ggai_contract_abort <- function(message) {
  rlang::abort(message, class = "ggai_contract_error")
}

ggai_contract_is_string <- function(x, allow_empty = FALSE) {
  is.character(x) && length(x) == 1L && !is.na(x) && (allow_empty || nzchar(x))
}

ggai_contract_require_string <- function(x, name, allow_empty = FALSE) {
  if (!ggai_contract_is_string(x, allow_empty = allow_empty)) {
    ggai_contract_abort(paste0("`", name, "` must be a single non-empty string."))
  }
  invisible(x)
}

ggai_contract_require_list <- function(x, name) {
  if (!is.list(x)) {
    ggai_contract_abort(paste0("`", name, "` must be a list."))
  }
  invisible(x)
}

ggai_contract_require_class <- function(x, class) {
  if (!inherits(x, class)) {
    ggai_contract_abort(paste0("`x` must be a ", class, " object."))
  }
  invisible(x)
}

ggai_contract_type <- function(x) {
  types <- c("ggai_task", "analysis_brief", "visual_brief", "ggai_agent_trace")
  matched <- types[vapply(types, function(type) inherits(x, type), logical(1))]
  matched[[1]] %||% NULL
}

new_ggai_contract <- function(type, fields) {
  fields$contract_type <- type
  structure(fields, class = c(type, "ggai_contract"))
}

#' Create a ggai task contract
#'
#' @param goal User-facing goal for the runtime.
#' @param task_type Task classification.
#' @param target Intended output target.
#' @param data_ref Optional data reference or summary.
#' @param constraints Structured constraints.
#' @param assumptions Structured assumptions.
#' @param meta Additional metadata.
#' @param id Optional stable task id.
#' @param created_at Optional creation timestamp.
#'
#' @return A `ggai_task` contract.
#' @export
new_ggai_task <- function(goal,
                          task_type = "visual_analysis",
                          target = "plot",
                          data_ref = NULL,
                          constraints = list(),
                          assumptions = list(),
                          meta = list(),
                          id = NULL,
                          created_at = NULL) {
  task <- new_ggai_contract(
    "ggai_task",
    list(
      id = id %||% ggai_contract_id("task"),
      goal = goal,
      task_type = task_type,
      target = target,
      data_ref = data_ref,
      constraints = constraints %||% list(),
      assumptions = assumptions %||% list(),
      meta = meta %||% list(),
      created_at = created_at %||% ggai_contract_timestamp()
    )
  )
  validate_ggai_task(task)
  task
}

#' Validate a ggai task contract
#'
#' @param x Object to validate.
#'
#' @return `x`, invisibly, when valid.
#' @export
validate_ggai_task <- function(x) {
  ggai_contract_require_class(x, "ggai_task")
  ggai_contract_require_string(x$id, "id")
  ggai_contract_require_string(x$goal, "goal")
  ggai_contract_require_string(x$task_type, "task_type")
  ggai_contract_require_string(x$target, "target")
  ggai_contract_require_list(x$constraints, "constraints")
  ggai_contract_require_list(x$assumptions, "assumptions")
  ggai_contract_require_list(x$meta, "meta")
  ggai_contract_require_string(x$created_at, "created_at")
  invisible(x)
}

#' Create an analysis brief contract
#'
#' @param task_id Associated `ggai_task` id.
#' @param question Analysis question.
#' @param data_summary Structured data summary.
#' @param variables Structured variable roles.
#' @param method_candidates Candidate methods.
#' @param method_decisions Selected methods and evidence.
#' @param assumptions Structured assumptions.
#' @param blockers Structured blockers.
#' @param meta Additional metadata.
#' @param id Optional stable brief id.
#' @param created_at Optional creation timestamp.
#'
#' @return An `analysis_brief` contract.
#' @export
new_analysis_brief <- function(task_id,
                               question,
                               data_summary = list(),
                               variables = list(),
                               method_candidates = list(),
                               method_decisions = list(),
                               assumptions = list(),
                               blockers = list(),
                               meta = list(),
                               id = NULL,
                               created_at = NULL) {
  brief <- new_ggai_contract(
    "analysis_brief",
    list(
      id = id %||% ggai_contract_id("analysis"),
      task_id = task_id,
      question = question,
      data_summary = data_summary %||% list(),
      variables = variables %||% list(),
      method_candidates = method_candidates %||% list(),
      method_decisions = method_decisions %||% list(),
      assumptions = assumptions %||% list(),
      blockers = blockers %||% list(),
      meta = meta %||% list(),
      created_at = created_at %||% ggai_contract_timestamp()
    )
  )
  validate_analysis_brief(brief)
  brief
}

#' Validate an analysis brief contract
#'
#' @param x Object to validate.
#'
#' @return `x`, invisibly, when valid.
#' @export
validate_analysis_brief <- function(x) {
  ggai_contract_require_class(x, "analysis_brief")
  ggai_contract_require_string(x$id, "id")
  ggai_contract_require_string(x$task_id, "task_id")
  ggai_contract_require_string(x$question, "question")
  ggai_contract_require_list(x$data_summary, "data_summary")
  ggai_contract_require_list(x$variables, "variables")
  ggai_contract_require_list(x$method_candidates, "method_candidates")
  ggai_contract_require_list(x$method_decisions, "method_decisions")
  ggai_contract_require_list(x$assumptions, "assumptions")
  ggai_contract_require_list(x$blockers, "blockers")
  ggai_contract_require_list(x$meta, "meta")
  ggai_contract_require_string(x$created_at, "created_at")
  invisible(x)
}

#' Create a visual brief contract
#'
#' @param task_id Associated `ggai_task` id.
#' @param intent Visual intent.
#' @param chart_type Planned chart type.
#' @param encodings Structured aesthetic encodings.
#' @param layers Planned layers.
#' @param annotations Planned annotations.
#' @param validation Structured validation status.
#' @param evidence Evidence records.
#' @param assumptions Structured assumptions.
#' @param meta Additional metadata.
#' @param id Optional stable brief id.
#' @param created_at Optional creation timestamp.
#'
#' @return A `visual_brief` contract.
#' @export
new_visual_brief <- function(task_id,
                             intent,
                             chart_type = "unspecified",
                             encodings = list(),
                             layers = list(),
                             annotations = list(),
                             validation = list(),
                             evidence = list(),
                             assumptions = list(),
                             meta = list(),
                             id = NULL,
                             created_at = NULL) {
  brief <- new_ggai_contract(
    "visual_brief",
    list(
      id = id %||% ggai_contract_id("visual"),
      task_id = task_id,
      intent = intent,
      chart_type = chart_type,
      encodings = encodings %||% list(),
      layers = layers %||% list(),
      annotations = annotations %||% list(),
      validation = validation %||% list(),
      evidence = evidence %||% list(),
      assumptions = assumptions %||% list(),
      meta = meta %||% list(),
      created_at = created_at %||% ggai_contract_timestamp()
    )
  )
  validate_visual_brief(brief)
  brief
}

#' Validate a visual brief contract
#'
#' @param x Object to validate.
#'
#' @return `x`, invisibly, when valid.
#' @export
validate_visual_brief <- function(x) {
  ggai_contract_require_class(x, "visual_brief")
  ggai_contract_require_string(x$id, "id")
  ggai_contract_require_string(x$task_id, "task_id")
  ggai_contract_require_string(x$intent, "intent")
  ggai_contract_require_string(x$chart_type, "chart_type")
  ggai_contract_require_list(x$encodings, "encodings")
  ggai_contract_require_list(x$layers, "layers")
  ggai_contract_require_list(x$annotations, "annotations")
  ggai_contract_require_list(x$validation, "validation")
  ggai_contract_require_list(x$evidence, "evidence")
  ggai_contract_require_list(x$assumptions, "assumptions")
  ggai_contract_require_list(x$meta, "meta")
  ggai_contract_require_string(x$created_at, "created_at")
  invisible(x)
}

#' Create an agent trace contract
#'
#' @param task_id Associated `ggai_task` id.
#' @param status Trace status.
#' @param steps Ordered trace steps.
#' @param tool_calls Tool call records.
#' @param observations Observation records.
#' @param blockers Structured blockers.
#' @param artifacts Artifact records.
#' @param meta Additional metadata.
#' @param id Optional stable trace id.
#' @param started_at Optional start timestamp.
#' @param completed_at Optional completion timestamp.
#'
#' @return A `ggai_agent_trace` contract.
#' @export
new_ggai_agent_trace <- function(task_id,
                                 status = "pending",
                                 steps = list(),
                                 tool_calls = list(),
                                 observations = list(),
                                 blockers = list(),
                                 artifacts = list(),
                                 meta = list(),
                                 id = NULL,
                                 started_at = NULL,
                                 completed_at = NULL) {
  trace <- new_ggai_contract(
    "ggai_agent_trace",
    list(
      id = id %||% ggai_contract_id("trace"),
      task_id = task_id,
      status = status,
      steps = steps %||% list(),
      tool_calls = tool_calls %||% list(),
      observations = observations %||% list(),
      blockers = blockers %||% list(),
      artifacts = artifacts %||% list(),
      meta = meta %||% list(),
      started_at = started_at %||% ggai_contract_timestamp(),
      completed_at = completed_at
    )
  )
  validate_ggai_agent_trace(trace)
  trace
}

#' Validate an agent trace contract
#'
#' @param x Object to validate.
#'
#' @return `x`, invisibly, when valid.
#' @export
validate_ggai_agent_trace <- function(x) {
  ggai_contract_require_class(x, "ggai_agent_trace")
  ggai_contract_require_string(x$id, "id")
  ggai_contract_require_string(x$task_id, "task_id")
  ggai_contract_require_string(x$status, "status")
  ggai_contract_require_list(x$steps, "steps")
  ggai_contract_require_list(x$tool_calls, "tool_calls")
  ggai_contract_require_list(x$observations, "observations")
  ggai_contract_require_list(x$blockers, "blockers")
  ggai_contract_require_list(x$artifacts, "artifacts")
  ggai_contract_require_list(x$meta, "meta")
  ggai_contract_require_string(x$started_at, "started_at")
  if (!is.null(x$completed_at)) {
    ggai_contract_require_string(x$completed_at, "completed_at")
  }
  invisible(x)
}

validate_ggai_contract <- function(x) {
  type <- ggai_contract_type(x)
  if (is.null(type)) {
    ggai_contract_abort("`x` must be a ggai contract object.")
  }
  switch(
    type,
    ggai_task = validate_ggai_task(x),
    analysis_brief = validate_analysis_brief(x),
    visual_brief = validate_visual_brief(x),
    ggai_agent_trace = validate_ggai_agent_trace(x)
  )
}

#' Serialize a ggai runtime contract
#'
#' @param x A ggai contract object.
#' @param pretty Whether to pretty-print JSON.
#'
#' @return A JSON string.
#' @export
serialize_ggai_contract <- function(x, pretty = FALSE) {
  validate_ggai_contract(x)
  jsonlite::toJSON(unclass(x), auto_unbox = TRUE, null = "null", pretty = pretty)
}

#' Deserialize a ggai runtime contract
#'
#' @param json JSON produced by `serialize_ggai_contract()`.
#'
#' @return A ggai contract object.
#' @export
deserialize_ggai_contract <- function(json) {
  if (!ggai_contract_is_string(json)) {
    ggai_contract_abort("`json` must be a single non-empty string.")
  }
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  type <- payload$contract_type %||% NULL
  if (!ggai_contract_is_string(type)) {
    ggai_contract_abort("Serialized contract is missing `contract_type`.")
  }
  if (!type %in% c("ggai_task", "analysis_brief", "visual_brief", "ggai_agent_trace")) {
    ggai_contract_abort(paste0("Unknown ggai contract type: ", type))
  }
  out <- structure(payload, class = c(type, "ggai_contract"))
  validate_ggai_contract(out)
  out
}
