ggai_goal_agent_enabled <- function(model = NULL) {
  ggai_agentic_edit_enabled(model)
}

ggai_goal_agent_state <- function(goal,
                                  model = NULL,
                                  registry = NULL,
                                  skills = NULL,
                                  skill_registry = NULL,
                                  skill_path = NULL) {
  state <- new.env(parent = emptyenv())
  state$goal <- goal
  state$model <- model
  state$registry <- registry
  state$skills <- skills
  state$skill_registry <- skill_registry
  state$skill_path <- skill_path
  state$execution_session <- NULL
  state$committed <- NULL
  state$blocker <- NULL
  state$executions <- list()
  state$plan <- list()
  state$result <- NULL
  state
}

ggai_goal_commit_plot_state <- function(state,
                                        plot,
                                        completion_summary,
                                        code = NULL,
                                        data = NULL,
                                        source_note = NULL) {
  if (!inherits(plot, "ggplot")) {
    ggai_agent_tool_abort("`plot` must be a ggplot object.")
  }
  validation <- ggai_agent_validate_plot(plot)
  if (!identical(validation$status %||% NULL, "ok")) {
    ggai_agent_tool_abort(validation$message %||% "Committed plot did not validate.")
  }
  state$committed <- list(
    plot = plot,
    data = if (is.data.frame(data)) data else if (is.data.frame(plot$data)) plot$data else NULL,
    code = code %||% "",
    completion_summary = completion_summary,
    source_note = source_note %||% "",
    validation = validation,
    committed_at = ggai_contract_timestamp()
  )
  list(
    status = "committed",
    validation = validation,
    completion_summary = completion_summary,
    source_note = source_note %||% ""
  )
}

ggai_goal_bind_session <- function(state, session) {
  state$execution_session <- session
  session$set_var("goal", state$goal, scope = "goal")
  session$set_var("ggai_commit_goal_plot", function(plot,
                                                    completion_summary,
                                                    code = NULL,
                                                    data = NULL,
                                                    source_note = NULL) {
    ggai_goal_commit_plot_state(
      state = state,
      plot = plot,
      completion_summary = completion_summary,
      code = code,
      data = data,
      source_note = source_note
    )
  }, scope = "goal")
  invisible(session)
}

ggai_goal_code_forbidden_pattern <- function() {
  paste(
    "\\b(",
    paste(
      c(
        "install\\.packages", "remotes::install", "pak::pkg_install",
        "devtools::install", "BiocManager::install"
      ),
      collapse = "|"
    ),
    ")\\s*\\(",
    sep = ""
  )
}

ggai_assert_safe_goal_code <- function(code) {
  if (!is.character(code) || length(code) != 1L || !nzchar(trimws(code))) {
    rlang::abort("Goal Agent R code must be a non-empty character string.")
  }
  if (grepl(ggai_goal_code_forbidden_pattern(), code, ignore.case = TRUE, perl = TRUE)) {
    rlang::abort("Goal Agent R code may not install packages silently.")
  }
  invisible(TRUE)
}

ggai_goal_execution_budget <- function() {
  ggai_agentic_positive_budget("ggai.goal_agent_execution_budget", Inf)
}

ggai_goal_decision_slack <- function() {
  ggai_agentic_positive_budget("ggai.goal_agent_decision_slack", 4L)
}

ggai_goal_effective_max_steps <- function(max_steps, skill_count = 0L) {
  ggai_agentic_max_steps(max_steps)
}

ggai_goal_process_output_enabled <- function() {
  (interactive() ||
    isTRUE(getOption("knitr.in.progress", FALSE)) ||
    isTRUE(getOption("ggai.agentic_process_force_output", FALSE))) &&
    identical(ggai_agentic_tool_log_mode(), "quiet")
}

ggai_goal_process_output_format <- function() {
  format <- getOption("ggai.agentic_process_output", NULL)
  if (is.null(format)) {
    format <- if (isTRUE(getOption("knitr.in.progress", FALSE))) "markdown" else "console"
  }
  format <- as.character(format)
  format <- tolower(if (length(format)) format[[1]] else "console")
  if (!format %in% c("console", "markdown")) {
    format <- "console"
  }
  format
}

ggai_goal_trim_lines <- function(text, width = 78L) {
  text <- trimws(as.character(text %||% ""))
  if (!length(text) || !nzchar(text[[1]])) {
    return(character())
  }
  unlist(strsplit(paste(strwrap(text[[1]], width = width), collapse = "\n"), "\n", fixed = TRUE), use.names = FALSE)
}

ggai_goal_status_label <- function(status) {
  status <- status %||% "pending"
  switch(status,
    done = "[x]",
    current = "[>]",
    blocked = "[!]",
    "[ ]"
  )
}

ggai_goal_event_title <- function(kind) {
  switch(kind,
    plan = "ggai Agent Plan",
    note = "ggai Agent Note",
    working = "ggai Agent Working",
    blocked = "ggai Agent Blocked",
    "ggai Agent"
  )
}

ggai_goal_event_icon <- function(kind) {
  switch(kind,
    plan = "plan",
    note = "note",
    working = "working",
    blocked = "blocked",
    "info"
  )
}

ggai_goal_cli_escape <- function(text) {
  text <- as.character(text %||% "")
  text <- gsub("{", "{{", text, fixed = TRUE)
  gsub("}", "}}", text, fixed = TRUE)
}

ggai_goal_with_cli_stdout <- function(expr) {
  app <- cli::start_app(output = "stdout", .auto_close = FALSE)
  on.exit(cli::stop_app(app), add = TRUE)
  force(expr)
}

ggai_goal_render_console_event <- function(kind, lines = character()) {
  ggai_goal_with_cli_stdout({
    label <- ggai_goal_event_icon(kind)
    label_text <- paste("ggai Agent", label)
    if (identical(kind, "plan")) {
      cli::cli_h3("{label_text}", .envir = list(label_text = label_text))
      if (length(lines)) {
        cli::cli_ul(ggai_goal_cli_escape(sub("^-\\s*", "", lines)))
      }
      cli::cli_text("")
      return(invisible(NULL))
    }
    body <- paste(lines, collapse = " ")
    if (identical(kind, "blocked")) {
      cli::cli_alert_danger(
        "{.strong {label_text}}: {body}",
        .envir = list(label_text = label_text, body = body)
      )
    } else if (identical(kind, "note")) {
      cli::cli_alert_info(
        "{.strong {label_text}}: {body}",
        .envir = list(label_text = label_text, body = body)
      )
    } else {
      cli::cli_alert(
        "{.strong {label_text}}: {body}",
        .envir = list(label_text = label_text, body = body)
      )
    }
    cli::cli_text("")
  })
  invisible(NULL)
}

ggai_goal_render_markdown_event <- function(kind, lines = character()) {
  title <- ggai_goal_event_title(kind)
  cat("> **", title, "**\n", sep = "")
  if (length(lines)) {
    cat(">\n", sep = "")
    cat(paste0("> ", lines, collapse = "\n"), "\n", sep = "")
  }
  cat("\n", sep = "")
  invisible(NULL)
}

ggai_goal_render_process_event <- function(kind, lines = character()) {
  if (!ggai_goal_process_output_enabled()) {
    return(invisible(NULL))
  }
  if (identical(ggai_goal_process_output_format(), "markdown")) {
    return(ggai_goal_render_markdown_event(kind, lines = lines))
  }
  ggai_goal_render_console_event(kind, lines = lines)
}

ggai_goal_print_status <- function(title, details = NULL) {
  title <- as.character(title %||% "")
  kind <- if (grepl("blocked", title, ignore.case = TRUE)) {
    "blocked"
  } else if (grepl("note", title, ignore.case = TRUE)) {
    "note"
  } else {
    "working"
  }
  ggai_goal_render_process_event(kind, ggai_goal_trim_lines(details))
}

ggai_goal_print_plan <- function(state) {
  if (!ggai_goal_process_output_enabled()) {
    return(invisible(NULL))
  }
  plan <- state$plan %||% list()
  if (!length(plan)) {
    return(invisible(NULL))
  }
  lines <- vapply(plan, function(item) {
    status <- item$status %||% "pending"
    mark <- ggai_goal_status_label(status)
    paste(mark, item$item %||% "")
  }, character(1))
  ggai_goal_render_process_event("plan", paste0("- ", lines))
}

ggai_goal_normalize_plan <- function(items, statuses = NULL) {
  if (is.list(items) && !is.data.frame(items)) {
    items <- unlist(items, recursive = FALSE, use.names = FALSE)
  }
  items <- as.character(items %||% character())
  items <- trimws(items[nzchar(trimws(items))])
  if (is.list(statuses) && !is.data.frame(statuses)) {
    statuses <- unlist(statuses, recursive = FALSE, use.names = FALSE)
  }
  statuses <- as.character(statuses %||% rep("pending", length(items)))
  if (length(statuses) < length(items)) {
    statuses <- c(statuses, rep("pending", length(items) - length(statuses)))
  }
  statuses <- statuses[seq_along(items)]
  statuses[!statuses %in% c("pending", "current", "done", "blocked")] <- "pending"
  Map(function(item, status) list(item = item, status = status), items, statuses)
}

ggai_goal_budget_value <- function() {
  budget <- ggai_goal_execution_budget()
  if (is.infinite(budget)) NULL else budget
}

ggai_goal_execution_count_label <- function(state) {
  count <- length(state$executions %||% list())
  budget <- ggai_goal_execution_budget()
  if (is.infinite(budget)) {
    return(paste0("R execution steps: ", count, "."))
  }
  paste0("R execution steps: ", count, "/", budget, ".")
}

ggai_goal_record_execution <- function(state, code, rationale, summary) {
  state$executions[[length(state$executions) + 1L]] <- list(
    index = length(state$executions) + 1L,
    code = ggai_context_preview_string(code, max_chars = 320L),
    rationale = ggai_context_preview_string(rationale %||% "", max_chars = 220L),
    status = summary$status %||% NULL,
    committed = isTRUE(summary$committed),
    error = ggai_context_preview_string(summary$error %||% "", max_chars = 220L),
    timestamp = ggai_contract_timestamp()
  )
  invisible(state)
}

ggai_goal_execution_history <- function(state, max_executions = 8L) {
  executions <- state$executions %||% list()
  budget <- ggai_goal_execution_budget()
  list(
    execution_count = length(executions),
    execution_budget = ggai_goal_budget_value(),
    execution_budget_unbounded = is.infinite(budget),
    execution_budget_reached = !is.infinite(budget) && length(executions) >= budget,
    executions = utils::tail(executions, max_executions),
    committed = !is.null(state$committed),
    blocker = state$blocker %||% NULL
  )
}

ggai_goal_execution_summary <- function(result, state, preview_n = 8L) {
  output <- result$output %||% character()
  budget <- ggai_goal_execution_budget()
  execution_count <- length(state$executions %||% list())
  list(
    status = if (isTRUE(result$success)) "ok" else "error",
    committed = !is.null(state$committed),
    execution_count = execution_count,
    execution_budget = ggai_goal_budget_value(),
    execution_budget_unbounded = is.infinite(budget),
    execution_budget_reached = !is.infinite(budget) && execution_count >= budget,
    result = ggai_context_compact_value(result$result, max_items = preview_n),
    output = utils::head(output, preview_n),
    error = result$error %||% NULL,
    duration_ms = result$duration_ms %||% NULL,
    next_action = if (is.null(state$committed)) {
      "Continue iterating, or call ggai_commit_goal_plot(plot = p, completion_summary = ..., code = ..., data = ..., source_note = ...) from R when the plot is ready."
    } else {
      "The plot has been committed; stop."
    }
  )
}

ggai_goal_agent_tools <- function(state) {
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")

  tools <- list(
    execute_goal_code = tool(
      name = "ggai_execute_goal_code",
      description = paste(
        "Execute one R step for the user's visualization goal in a persistent R session.",
        "Use this to inspect files/data, create or transform data, draft ggplot objects, observe errors, and repair.",
        "Objects persist across calls in the `goal` scope.",
        "When the final plot is ready, call `ggai_commit_goal_plot(plot = p, completion_summary = ..., code = ..., data = ..., source_note = ...)` inside the R code."
      ),
      parameters = z$z_object(
        code = z$z_string(description = "R code to execute in the persistent goal session"),
        rationale = z$z_string(description = "Why this R step is useful now", nullable = TRUE),
        preview_n = z$z_number(description = "Maximum output/result preview items", nullable = TRUE, default = 8),
        .required = "code"
      ),
      execute = function(code, rationale = NULL, preview_n = 8) {
        ggai_assert_safe_goal_code(code)
        if (is.null(state$execution_session)) {
          ggai_agent_tool_abort("Goal execution session is not initialized.")
        }
        if (!is.null(rationale) && nzchar(rationale)) {
          ggai_goal_print_status("ggai Agent working", rationale)
        }
        result <- state$execution_session$execute_code(
          code = code,
          scope = "goal",
          capture_output = TRUE
        )
        summary <- ggai_goal_execution_summary(result, state = state, preview_n = preview_n)
        summary$rationale <- rationale %||% ""
        ggai_goal_record_execution(state, code = code, rationale = rationale, summary = summary)
        summary$execution_count <- length(state$executions %||% list())
        budget <- ggai_goal_execution_budget()
        if (!is.infinite(budget) && summary$execution_count >= budget && is.null(state$committed)) {
          summary$execution_budget_reached <- TRUE
          summary$next_action <- "The diagnostic execution budget has been reached. Continue only if there is a concrete next step; otherwise commit a sufficient ggplot or declare a blocker."
        }
        summary
      }
    ),
    update_goal_plan = tool(
      name = "ggai_update_goal_plan",
      description = paste(
        "Update the user-visible goal plan as a short todo list.",
        "Use this when starting, changing phases, finishing a phase, or declaring a blocker."
      ),
      parameters = z$z_object(
        items = z$z_array(z$z_string(description = "One concise todo item"), description = "Todo items"),
        statuses = z$z_array(
          z$z_enum(c("pending", "current", "done", "blocked"), description = "Status for the matching todo item"),
          description = "Statuses matching the todo items",
          nullable = TRUE
        ),
        note = z$z_string(description = "Optional short note about the current phase", nullable = TRUE),
        .required = "items"
      ),
      execute = function(items, statuses = NULL, note = NULL) {
        state$plan <- ggai_goal_normalize_plan(items, statuses)
        ggai_goal_print_plan(state)
        if (!is.null(note) && nzchar(note)) {
          ggai_goal_print_status("ggai Agent note", note)
        }
        list(status = "plan_updated", plan = state$plan, note = note %||% "")
      }
    ),
    inspect_goal_executions = tool(
      name = "ggai_inspect_goal_executions",
      description = paste(
        "Inspect recent goal-level R execution steps.",
        "Use this before deciding whether to commit a plot, continue, or declare a blocker."
      ),
      parameters = z$z_object(
        max_executions = z$z_number(description = "Maximum recent executions to return", nullable = TRUE, default = 8)
      ),
      execute = function(max_executions = 8) {
        ggai_goal_execution_history(state, max_executions = max_executions)
      }
    ),
    declare_goal_blocker = tool(
      name = "ggai_declare_goal_blocker",
      description = paste(
        "Declare that the goal cannot be completed honestly with the current context and tools.",
        "Use this instead of repeated R execution when no validated ggplot can be committed."
      ),
      parameters = z$z_object(
        reason = z$z_string(description = "Concise blocker reason"),
        evidence = z$z_string(description = "Observed attempts or constraints that support the blocker", nullable = TRUE),
        next_step = z$z_string(description = "What user input or capability would make progress possible", nullable = TRUE),
        .required = "reason"
      ),
      execute = function(reason, evidence = NULL, next_step = NULL) {
        state$blocker <- list(
          reason = reason,
          evidence = evidence %||% "",
          next_step = next_step %||% "",
          executions = ggai_goal_execution_history(state)
        )
        ggai_goal_print_status("ggai Agent blocked", reason)
        list(status = "blocker_declared", blocker = state$blocker)
      }
    )
  )

  if (!is.null(state$execution_session) && inherits(state$execution_session, "ChatSession")) {
    tools <- ggai_append_unique_tool_objects(
      tools,
      ggai_aisdk_context_tools(state$execution_session)
    )
  }

  tools
}

ggai_goal_agent_system_prompt <- function() {
  paste(
    "You are ggai's goal-level visualization Agent.",
    "Optimize for completing the user's visualization goal, not for following a fixed acquisition or plotting workflow.",
    "Use `ggai_update_goal_plan` to maintain a concise todo list. Mark exactly one item as current when possible, and update it when your plan changes.",
    "Use `ggai_execute_goal_code` for persistent R execution. Use R to explore, fetch/parse reachable local references, create or transform data, draft plots, observe errors, and iterate.",
    "Use `ggai_inspect_goal_executions` when you have executed several R steps and need to decide whether to commit or stop.",
    "If no honest validated ggplot can be committed with the current context, call `ggai_declare_goal_blocker` instead of continuing to execute code.",
    "Use installed packages with explicit namespace calls when available. Do not install packages silently.",
    "When exact source data is unavailable but the user asked for a reference-inspired or tutorial-style figure, make an honest example/template plot and label limitations in the plot or source note.",
    "Finish by calling `ggai_commit_goal_plot(plot = p, completion_summary = ..., code = ..., data = ..., source_note = ...)` inside R code.",
    "Do not claim completion until that commit call succeeds.",
    sep = "\n"
  )
}

ggai_goal_reference_text <- function(image_refs = character(), mode = c("text", "vision")) {
  mode <- match.arg(mode)
  image_refs <- unique(as.character(image_refs %||% character()))
  image_refs <- image_refs[nzchar(image_refs)]
  if (!length(image_refs)) {
    return(NULL)
  }
  label <- if (identical(mode, "vision")) {
    "Reference image files attached to this message:"
  } else {
    paste(
      "Reference image files mentioned by the user.",
      "The current language model does not explicitly advertise vision input support,",
      "so these are provided as local paths for R-side inspection when possible:"
    )
  }
  paste(
    label,
    paste0("- ", image_refs, collapse = "\n"),
    sep = "\n"
  )
}

ggai_goal_agent_prompt <- function(goal, instruction = NULL, image_refs = character(), image_mode = c("text", "vision")) {
  image_mode <- match.arg(image_mode)
  paste(
    "User goal:",
    goal,
    "",
    if (!is.null(instruction) && nzchar(instruction)) paste("Additional instruction:", instruction) else NULL,
    if (length(image_refs)) ggai_goal_reference_text(image_refs, mode = image_mode) else NULL,
    "",
    "",
    "Work autonomously in R. Decide what context, data, reference handling, plotting approach, and repair steps are needed.",
    "Return a ggai session by committing one validated ggplot result.",
    sep = "\n"
  )
}

ggai_goal_model_supports_vision <- function(model) {
  if (!inherits(model, "LanguageModelV1")) {
    return(FALSE)
  }
  caps <- model$capabilities %||% list()
  isTRUE(caps$vision_input) ||
    isTRUE(caps$vision) ||
    (is.function(model$has_capability) && (
      isTRUE(model$has_capability("vision_input")) ||
        isTRUE(model$has_capability("vision"))
    ))
}

ggai_goal_capability_model <- function(model, registry = NULL) {
  if (inherits(model, "LanguageModelV1")) {
    return(model)
  }
  tryCatch(
    ggai_language_model(model, resolve = TRUE, registry = registry),
    error = function(...) model
  )
}

ggai_goal_agent_task <- function(goal, instruction = NULL, image_refs = character(), model = NULL) {
  image_refs <- unique(as.character(image_refs %||% character()))
  image_refs <- image_refs[nzchar(image_refs) & file.exists(image_refs)]
  image_refs <- if (length(image_refs)) normalizePath(image_refs, mustWork = TRUE) else character()
  can_send_images <- ggai_goal_model_supports_vision(model)
  text <- ggai_goal_agent_prompt(
    goal,
    instruction = instruction,
    image_refs = image_refs,
    image_mode = if (can_send_images) "vision" else "text"
  )
  if (!length(image_refs)) {
    return(text)
  }
  if (!can_send_images) {
    return(text)
  }
  content <- c(
    list(ggai_aisdk("input_text")(text)),
    lapply(image_refs, function(path) ggai_aisdk("input_image")(path))
  )
  list(list(role = "user", content = content))
}

ggai_goal_agent_safe_code_note <- function(code) {
  if (!is.character(code) || length(code) != 1L || !nzchar(trimws(code))) {
    return("# Plot object produced and committed by the ggai goal-level aisdk Agent.")
  }
  parsed <- tryCatch(parse(text = code), error = function(e) e)
  if (inherits(parsed, "error")) {
    return(paste(
      "# Plot object produced and committed by the ggai goal-level aisdk Agent.",
      paste0("# Agent code note: ", ggai_context_preview_string(code, max_chars = 400L)),
      sep = "\n"
    ))
  }
  code
}

ggai_goal_agent_session <- function(goal,
                                    instruction = NULL,
                                    model = NULL,
                                    registry = NULL,
                                    skills = NULL,
                                    skill_registry = NULL,
                                    skill_path = NULL,
                                    image_refs = character(),
                                    context_mentions = list(),
                                    max_steps = getOption("ggai.goal_agent_max_steps", 100L)) {
  if (is.null(model) &&
      isTRUE(getOption("ggai.goal_agent_use_default_model", TRUE)) &&
      ggai_aisdk_runtime_available()) {
    model <- ggai_default_models()$language
  }
  if (!ggai_goal_agent_enabled(model)) {
    rlang::abort(c(
      "ggai goal Agent is unavailable.",
      i = "Pass `model=` or set `options(ggai.language_model=...)` / `GGAI_LANGUAGE_MODEL`.",
      i = "Natural-language-only goals now enter the goal-level aisdk Agent instead of a fixed acquisition workflow."
    ))
  }

  max_steps <- ggai_agentic_max_steps(max_steps)
  model <- ggai_language_model(model)
  state <- ggai_goal_agent_state(
    goal = goal,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path
  )
  agent_skill_paths <- ggai_agent_skill_paths(
    skills = skills,
    query = paste(goal, instruction %||% ""),
    skill_registry = skill_registry,
    skill_path = skill_path,
    builtin_skills = c("ggai-core-persona", "ggai-goal-agent", "ggai-plot-agent", "ggai-reference-figure", "ggai-r-fonts", "ggai-single-cell-spatial")
  )
  max_steps <- ggai_goal_effective_max_steps(max_steps, skill_count = length(agent_skill_paths))
  session <- ggai_create_context_session(model = model, trace_enabled = TRUE)
  if (is.null(session)) {
    session <- ggai_aisdk("create_shared_session")(
      model = model,
      sandbox_mode = "permissive",
      trace_enabled = TRUE
    )
  }
  ggai_goal_bind_session(state, session)
  session$set_var("instruction", instruction %||% "", scope = "goal")
  ggai_register_context_objects(
    session,
    mentions = context_mentions,
    instruction = instruction %||% goal
  )
  agent <- ggai_aisdk("create_agent")(
    name = "ggai_goal_agent",
    description = "Completes natural-language visualization goals directly in an aisdk R execution environment.",
    system_prompt = ggai_goal_agent_system_prompt(),
    tools = ggai_goal_agent_tools(state),
    skills = agent_skill_paths,
    model = model
  )

  run_args <- c(
    list(
      task = ggai_goal_agent_task(
        goal,
        instruction = instruction,
        image_refs = image_refs,
        model = ggai_goal_capability_model(model, registry = registry)
      ),
      session = session,
      max_steps = max_steps,
      model = model,
      registry = registry
    ),
    ggai_agentic_run_args(model)
  )
  result <- tryCatch(
    ggai_agentic_run_agent(agent, run_args),
    error = function(e) e
  )
  state$result <- result

  if (is.null(state$committed)) {
    rlang::abort(c(
      "ggai goal Agent did not commit a plot.",
      i = "The natural-language goal was sent directly to the aisdk Agent without an acquisition workflow gate.",
      i = "The returned session was not mutated because no validated ggplot was committed.",
      i = ggai_goal_execution_count_label(state),
      i = if (!is.null(state$blocker)) paste0("Agent blocker: ", state$blocker$reason) else NULL,
      i = if (!is.null(state$blocker) && nzchar(state$blocker$next_step %||% "")) paste0("Suggested next step: ", state$blocker$next_step) else NULL,
      x = if (inherits(result, "error")) ggai_strip_ansi(conditionMessage(result)) else "The Agent stopped before calling `ggai_commit_goal_plot()`."
    ))
  }

  committed <- state$committed
  code <- ggai_goal_agent_safe_code_note(committed$code)
  compiled <- ggai_code_compiled_spec(
    code = code,
    instruction = instruction %||% goal,
    context = list(goal = goal),
    meta = list(
      edit_mode = "agentic_goal",
      agent_result_text = if (inherits(result, "error")) NULL else result$text %||% NULL,
      commit = committed[c("completion_summary", "source_note", "committed_at")],
      validation = committed$validation,
      tool_calls = if (inherits(result, "error")) list() else ggai_compact_tool_events(result$all_tool_calls %||% list()),
      tool_results = if (inherits(result, "error")) list() else ggai_compact_tool_events(result$all_tool_results %||% list()),
      executions = ggai_goal_execution_history(state),
      session_trace_summary = session$trace_summary(),
      context_session = list(
        enabled = TRUE,
        registered = tryCatch(session$get_memory("ggai_registered_context", default = list()), error = function(...) list()),
        tool_names = ggai_context_tool_names(ggai_aisdk_context_tools(session))
      )
    ),
    warnings = list("Generated by ggai's goal-level aisdk Agent.")
  )
  rendered <- record_compiled_spec(committed$plot, compiled)
  base_plot <- if (is.data.frame(committed$data)) {
    ggplot2::ggplot(data = committed$data)
  } else {
    ggplot2::ggplot()
  }
  out <- start_ggai_session(base_plot)
  entry <- new_session_entry(
    instruction = instruction %||% goal,
    compiled_spec = compiled,
    plot = rendered,
    code = code,
    edit_mode = "agentic_goal",
    parent_turn = 0L,
    turn_context = list(mode = "goal_agent")
  )
  out <- session_append_entry(out, entry)
  out <- session_record_agent_trace(
    out,
    ggai_edit_runtime_trace(
      instruction = instruction %||% goal,
      edit_mode = "agentic_goal",
      render_result = list(status = "ok", details = list(source = "goal_agent")),
      validation = committed$validation,
      turn = out$history_index %||% 0L,
      runtime = "ggai_goal_agent",
      task_prefix = "goal"
    )
  )
  out <- session_record_turn_note(
    out,
    type = "ggai_init",
    value = list(
      source = "natural_language_goal",
      requested_goal = goal,
      instruction = instruction %||% goal,
      initialization = "aisdk_goal_agent",
      model = model,
      completion_summary = committed$completion_summary,
      source_note = committed$source_note
    )
  )
  session_touch_state(out, instruction = instruction %||% goal)
}
