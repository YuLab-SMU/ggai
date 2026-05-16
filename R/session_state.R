ggai_session_defaults <- function() {
  list(
    version = 1L,
    current_turn = 0L,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    updated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    active_instruction = NULL,
    context = list(
      user_preferences = list(),
      active_constraints = list(),
      turn_notes = list(),
      tool_results = list(),
      artifact_log = list(),
      plot_summary = NULL,
      agent_tasks = list(),
      analysis_briefs = list(),
      visual_briefs = list(),
      agent_traces = list()
    )
  )
}

new_ggai_turn <- function(instruction,
                          compiled_spec,
                          plot,
                          code,
                          edit_mode = "compile",
                          parent_turn = NULL,
                          turn_context = list()) {
  list(
    instruction = instruction,
    compiled_spec = compiled_spec,
    plot = plot,
    code = code,
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE),
    kind = compiled_spec$kind %||% "layer",
    edit_mode = edit_mode,
    parent_turn = parent_turn,
    turn_context = turn_context
  )
}

merge_session_context <- function(context = NULL) {
  defaults <- ggai_session_defaults()$context
  context <- context %||% list()
  list(
    user_preferences = context$user_preferences %||% defaults$user_preferences,
    active_constraints = context$active_constraints %||% defaults$active_constraints,
    turn_notes = context$turn_notes %||% defaults$turn_notes,
    tool_results = context$tool_results %||% defaults$tool_results,
    artifact_log = context$artifact_log %||% defaults$artifact_log,
    plot_summary = context$plot_summary %||% defaults$plot_summary,
    agent_tasks = context$agent_tasks %||% defaults$agent_tasks,
    analysis_briefs = context$analysis_briefs %||% defaults$analysis_briefs,
    visual_briefs = context$visual_briefs %||% defaults$visual_briefs,
    agent_traces = context$agent_traces %||% defaults$agent_traces
  )
}

ggai_session_state <- function(session) {
  defaults <- ggai_session_defaults()
  state <- session$state %||% list()
  list(
    version = state$version %||% defaults$version,
    current_turn = state$current_turn %||% defaults$current_turn,
    created_at = state$created_at %||% defaults$created_at,
    updated_at = state$updated_at %||% defaults$updated_at,
    active_instruction = state$active_instruction %||% defaults$active_instruction,
    context = merge_session_context(state$context)
  )
}

session_set_state <- function(session, state) {
  state <- state %||% list()
  session$state <- list(
    version = state$version %||% 1L,
    current_turn = state$current_turn %||% 0L,
    created_at = state$created_at %||% format(Sys.time(), tz = "UTC", usetz = TRUE),
    updated_at = state$updated_at %||% format(Sys.time(), tz = "UTC", usetz = TRUE),
    active_instruction = state$active_instruction %||% NULL,
    context = merge_session_context(state$context)
  )
  session
}

session_touch_state <- function(session, instruction = NULL) {
  state <- ggai_session_state(session)
  state$current_turn <- as.integer(session$history_index %||% 0L)
  state$updated_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  if (!is.null(instruction) && nzchar(instruction)) {
    state$active_instruction <- instruction
  }
  session_set_state(session, state)
}

session_set_plot_summary <- function(session, plot = NULL) {
  plot <- plot %||% session_current_plot(session)
  state <- ggai_session_state(session)
  mapping_names <- names(plot$mapping %||% list())
  state$context$plot_summary <- list(
    has_data = !is.null(plot$data),
    rows = tryCatch(nrow(plot$data), error = function(...) NULL),
    columns = tryCatch(names(plot$data), error = function(...) NULL),
    mapping = mapping_names
  )
  session_set_state(session, state)
}

session_record_turn_note <- function(session, type, value) {
  state <- ggai_session_state(session)
  state$context$turn_notes[[length(state$context$turn_notes) + 1L]] <- list(
    type = type,
    value = value,
    timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  session_set_state(session, state)
}

session_record_tool_result <- function(session, result) {
  state <- ggai_session_state(session)
  state$context$tool_results[[length(state$context$tool_results) + 1L]] <- result
  session_set_state(session, state)
}

session_record_artifact <- function(session, artifact) {
  state <- ggai_session_state(session)
  state$context$artifact_log[[length(state$context$artifact_log) + 1L]] <- artifact
  session_set_state(session, state)
}

session_record_ggai_task <- function(session, task) {
  validate_ggai_task(task)
  state <- ggai_session_state(session)
  state$context$agent_tasks[[length(state$context$agent_tasks) + 1L]] <- task
  session_set_state(session, state)
}

session_record_analysis_brief <- function(session, brief) {
  validate_analysis_brief(brief)
  state <- ggai_session_state(session)
  state$context$analysis_briefs[[length(state$context$analysis_briefs) + 1L]] <- brief
  session_set_state(session, state)
}

session_record_visual_brief <- function(session, brief) {
  validate_visual_brief(brief)
  state <- ggai_session_state(session)
  state$context$visual_briefs[[length(state$context$visual_briefs) + 1L]] <- brief
  session_set_state(session, state)
}

session_record_agent_trace <- function(session, trace) {
  validate_ggai_agent_trace(trace)
  state <- ggai_session_state(session)
  state$context$agent_traces[[length(state$context$agent_traces) + 1L]] <- trace
  session_set_state(session, state)
}

ggai_context_json_safe <- function(x) {
  if (inherits(x, "ggai_contract")) {
    x <- unclass(x)
  }
  if (is.list(x)) {
    return(lapply(x, ggai_context_json_safe))
  }
  x
}

session_context_snapshot <- function(session) {
  state <- ggai_session_state(session)
  ggai_context_json_safe(list(
    current_turn = state$current_turn,
    active_instruction = state$active_instruction,
    user_preferences = state$context$user_preferences,
    active_constraints = state$context$active_constraints,
    plot_summary = state$context$plot_summary,
    recent_notes = utils::tail(state$context$turn_notes, 5),
    recent_tool_results = utils::tail(state$context$tool_results, 5),
    recent_artifacts = utils::tail(state$context$artifact_log, 5),
    recent_agent_tasks = utils::tail(state$context$agent_tasks, 5),
    recent_analysis_briefs = utils::tail(state$context$analysis_briefs, 5),
    recent_visual_briefs = utils::tail(state$context$visual_briefs, 5),
    recent_agent_traces = utils::tail(state$context$agent_traces, 5)
  ))
}

session_turn_notes <- function(session) {
  state <- ggai_session_state(session)
  state$context$turn_notes %||% list()
}

session_artifact_log <- function(session) {
  state <- ggai_session_state(session)
  state$context$artifact_log %||% list()
}

session_agent_tasks <- function(session) {
  state <- ggai_session_state(session)
  state$context$agent_tasks %||% list()
}

session_analysis_briefs <- function(session) {
  state <- ggai_session_state(session)
  state$context$analysis_briefs %||% list()
}

session_visual_briefs <- function(session) {
  state <- ggai_session_state(session)
  state$context$visual_briefs %||% list()
}

session_agent_traces <- function(session) {
  state <- ggai_session_state(session)
  state$context$agent_traces %||% list()
}
