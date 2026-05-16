ggai_agent_goal <- function(goal = NULL, data = NULL) {
  if (!is.null(goal) && is.character(goal) && length(goal) == 1L && nzchar(goal)) {
    return(goal)
  }
  if (is.data.frame(data)) {
    return(infer_plot_instruction(data)$instruction)
  }
  "Create a ggai visual analysis"
}

ggai_agent_data_ref <- function(data = NULL, plot = NULL) {
  if (is.data.frame(data)) {
    return(list(source = "data.frame", nrow = nrow(data), ncol = ncol(data), names = names(data)))
  }
  if (inherits(plot, "ggplot") && is.data.frame(plot$data)) {
    return(list(source = "ggplot", nrow = nrow(plot$data), ncol = ncol(plot$data), names = names(plot$data)))
  }
  list(source = "unknown")
}

ggai_agent_build_session <- function(agent) {
  if (inherits(agent$session, "ggai_session")) {
    return(agent$session)
  }
  if (inherits(agent$plot, "ggplot")) {
    return(start_ggai_session(agent$plot))
  }
  if (is.data.frame(agent$data)) {
    built <- build_initial_plot(agent$data, instruction = agent$goal)
    return(start_ggai_session(built$plot))
  }
  rlang::abort("`ggai_agent_run()` requires a session, plot, or data frame.")
}

ggai_agent_profile_from_tools <- function(agent) {
  tryCatch(
    agent$tools$data_profile$run(list(include_preview = FALSE)),
    error = function(e) list(error = conditionMessage(e))
  )
}

ggai_agent_plot_validation_from_tools <- function(agent) {
  tryCatch(
    agent$tools$plot_validation$run(list()),
    error = function(e) list(status = "error", message = conditionMessage(e), warnings = character())
  )
}

ggai_agent_stats_from_tools <- function(agent) {
  tryCatch(
    agent$tools$stat_method_selection$run(list(goal = agent$goal)),
    error = function(e) list(
      profile = list(error = conditionMessage(e)),
      method_selection = list(
        family = "descriptive_summary",
        method = "descriptive_summary",
        variables = list(),
        evidence = list(error = conditionMessage(e)),
        result = list(status = "error", message = conditionMessage(e))
      )
    )
  )
}

ggai_agent_roles <- function(agent, profile = list()) {
  data <- if (is.data.frame(agent$data)) {
    agent$data
  } else if (inherits(agent$plot, "ggplot") && is.data.frame(agent$plot$data)) {
    agent$plot$data
  } else {
    NULL
  }

  if (is.data.frame(data) && length(names(data))) {
    return(infer_column_roles(data))
  }

  list(x = NULL, y = NULL, colour = NULL, profile_names = profile$names %||% character())
}

ggai_agent_chart_type <- function(agent, roles) {
  data <- if (is.data.frame(agent$data)) {
    agent$data
  } else if (inherits(agent$plot, "ggplot") && is.data.frame(agent$plot$data)) {
    agent$plot$data
  } else {
    NULL
  }

  if (is.data.frame(data) && length(names(data))) {
    return(infer_chart_type(data, instruction = agent$goal, roles = roles))
  }

  "unspecified"
}

ggai_agent_trace_step <- function(step, status = "done", details = list()) {
  list(
    step = step,
    status = status,
    details = details,
    timestamp = ggai_contract_timestamp()
  )
}

ggai_agent_record_contracts <- function(session, task, analysis, visual, trace) {
  session <- session_record_ggai_task(session, task)
  session <- session_record_analysis_brief(session, analysis)
  session <- session_record_visual_brief(session, visual)
  session_record_agent_trace(session, trace)
}

ggai_agent_stat_annotation <- function(method_selection) {
  result <- method_selection$result %||% list()
  list(
    kind = "statistical_method",
    family = method_selection$family %||% NULL,
    method = method_selection$method %||% NULL,
    variables = method_selection$variables %||% list(),
    status = result$status %||% NULL,
    p_value = result$p_value %||% NULL
  )
}

ggai_agent_source_context <- function(goal) {
  detected <- ggai_detect_source_urls(goal %||% "")
  evidence <- detected$evidence %||% list()
  list(
    detected = detected,
    evidence = evidence,
    summary = ggai_summarize_sources(evidence)
  )
}

#' Create a minimal ggai visual agent
#'
#' @param data Optional data frame.
#' @param plot Optional ggplot object.
#' @param session Optional `ggai_session`.
#' @param goal Optional user goal.
#' @param model Optional model identifier reserved for later compiler-backed stages.
#' @param registry Optional provider registry reserved for later compiler-backed stages.
#' @param skills Optional skill names, paths, Skill objects, or inline skill lists.
#' @param skill_registry Optional aisdk SkillRegistry.
#' @param skill_path Optional path scanned into an aisdk SkillRegistry.
#'
#' @return A `ggai_agent` object.
#' @export
create_ggai_agent <- function(data = NULL,
                              plot = NULL,
                              session = NULL,
                              goal = NULL,
                              model = NULL,
                              registry = NULL,
                              skills = NULL,
                              skill_registry = NULL,
                              skill_path = NULL) {
  if (!is.null(data) && !is.data.frame(data)) {
    rlang::abort("`data` must be a data frame when provided.")
  }
  if (!is.null(plot) && !inherits(plot, "ggplot")) {
    rlang::abort("`plot` must be a ggplot object when provided.")
  }
  if (!is.null(session) && !inherits(session, "ggai_session")) {
    rlang::abort("`session` must be a ggai_session when provided.")
  }

  if (is.null(plot) && inherits(session, "ggai_session")) {
    plot <- session_current_plot(session)
  }
  if (is.null(data) && inherits(plot, "ggplot") && is.data.frame(plot$data)) {
    data <- plot$data
  }

  goal <- ggai_agent_goal(goal, data = data)
  tools <- create_ggai_agent_tools(
    data = data,
    plot = plot,
    session = session,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path
  )

  structure(
    list(
      goal = goal,
      data = data,
      plot = plot,
      session = session,
      tools = tools,
      model = model,
      registry = registry,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path
    ),
    class = "ggai_agent"
  )
}

#' Run the minimal ggai visual agent
#'
#' @param agent A `ggai_agent` object.
#' @param goal Optional goal override.
#' @param ... Reserved for future runtime options.
#'
#' @return A `ggai_session` with task, brief, trace, and artifact metadata.
#' @export
ggai_agent_run <- function(agent, goal = NULL, ...) {
  if (!inherits(agent, "ggai_agent")) {
    rlang::abort("`agent` must be a ggai_agent.")
  }

  if (!is.null(goal) && is.character(goal) && length(goal) == 1L && nzchar(goal)) {
    agent$goal <- goal
  }

  session <- ggai_agent_build_session(agent)
  agent$session <- session
  agent$plot <- session_current_plot(session)
  attr(agent$tools, "state")$session <- session
  attr(agent$tools, "state")$plot <- agent$plot

  profile <- ggai_agent_profile_from_tools(agent)
  roles <- ggai_agent_roles(agent, profile = profile)
  chart_type <- ggai_agent_chart_type(agent, roles)
  validation <- ggai_agent_plot_validation_from_tools(agent)
  stats <- ggai_agent_stats_from_tools(agent)
  method_selection <- stats$method_selection
  source_context <- ggai_agent_source_context(agent$goal)
  trace_status <- if (identical(validation$status %||% NULL, "ok")) "completed" else validation$status %||% "completed"

  task <- new_ggai_task(
    goal = agent$goal,
    task_type = "visual_analysis",
    target = "plot",
    data_ref = ggai_agent_data_ref(agent$data, agent$plot),
    constraints = list(local_only = TRUE, no_package_install = TRUE, no_external_fetch = TRUE)
  )
  analysis <- new_analysis_brief(
    task_id = task$id,
    question = agent$goal,
    data_summary = profile,
    variables = roles,
    method_candidates = list(method_selection$family %||% "descriptive_summary"),
    method_decisions = list(method_selection),
    assumptions = list("Stage 4 runtime uses deterministic local statistical checks only.")
  )
  visual <- new_visual_brief(
    task_id = task$id,
    intent = agent$goal,
    chart_type = chart_type,
    encodings = roles,
    layers = as.list(vapply(agent$plot$layers %||% list(), geom_name_from_layer, character(1))),
    annotations = list(ggai_agent_stat_annotation(method_selection)),
    validation = validation,
    evidence = source_context$evidence,
    assumptions = list("No live model call was used to produce this visual brief.")
  )

  trace <- new_ggai_agent_trace(
    task_id = task$id,
    status = trace_status,
    steps = list(
      ggai_agent_trace_step("profile_data", details = list(columns = profile$names %||% character())),
      ggai_agent_trace_step("infer_variables", details = roles),
      ggai_agent_trace_step("select_stat_method", details = list(method = method_selection$method %||% NULL, family = method_selection$family %||% NULL)),
      ggai_agent_trace_step("collect_source_evidence", details = source_context$summary),
      ggai_agent_trace_step("produce_visual_brief", details = list(chart_type = chart_type)),
      ggai_agent_trace_step("validate_plot", status = validation$status %||% "done", details = validation),
      ggai_agent_trace_step("record_session_trace")
    ),
    tool_calls = list(
      list(name = "ggai_data_profile", status = if (is.null(profile$error)) "ok" else "error"),
      list(name = "ggai_stat_method_selection", status = method_selection$result$status %||% "ok"),
      list(name = "ggai_plot_validation", status = validation$status %||% "ok")
    ),
    observations = list(
      list(type = "data_profile", value = profile),
      list(type = "variable_roles", value = roles),
      list(type = "stat_method_selection", value = method_selection),
      list(type = "source_context", value = source_context$summary),
      list(type = "chart_type", value = chart_type),
      list(type = "plot_validation", value = validation)
    ),
    artifacts = list(
      list(kind = "ggplot_session", status = validation$status %||% "recorded")
    ),
    completed_at = ggai_contract_timestamp()
  )

  session <- session_record_turn_note(
    session,
    type = "ggai_agent_run",
    value = list(
      goal = agent$goal,
      chart_type = chart_type,
      method = method_selection$method %||% NULL,
      validation = validation$status %||% NULL
    )
  )
  session <- session_touch_state(session, instruction = agent$goal)
  session <- session_record_artifact(
    session,
    list(
      kind = "ggplot_session",
      edit_mode = "agent_runtime",
      instruction = agent$goal,
      status = validation$status %||% "recorded",
      timestamp = ggai_contract_timestamp(),
      turn = ggai_session_state(session)$current_turn %||% 0L
    )
  )
  session <- ggai_agent_record_contracts(session, task, analysis, visual, trace)
  repaired <- ggai_validate_and_repair(session, analysis = analysis, visual = visual, goal = agent$goal, max_attempts = 1L)
  session <- repaired$session

  session
}
