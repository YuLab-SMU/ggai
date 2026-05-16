ggai_agentic_edit_enabled <- function(model = NULL) {
  isTRUE(getOption("ggai.agentic_edit", TRUE)) &&
    !is.null(model) &&
    (
      inherits(model, "LanguageModelV1") ||
        (is.character(model) && length(model) == 1L && nzchar(model))
    ) &&
    ggai_aisdk_runtime_available()
}

ggai_agentic_model_provider <- function(model) {
  if (inherits(model, "LanguageModelV1")) {
    return(tolower(model$provider %||% ""))
  }
  ggai_model_provider(ggai_language_model(model))
}

ggai_agentic_run_args <- function(model) {
  args <- getOption("ggai.agentic_edit_run_args", list())
  if (is.null(args)) {
    args <- list()
  }
  if (!is.list(args)) {
    rlang::abort("`options(ggai.agentic_edit_run_args=)` must be a list.")
  }

  provider <- ggai_agentic_model_provider(model)
  if (identical(provider, "deepseek") &&
      is.null(args$thinking) &&
      is.null(args$reasoning_effort) &&
      isTRUE(getOption("ggai.deepseek_disable_thinking_for_tools", TRUE))) {
    args$thinking <- list(type = "disabled")
  }

  args
}

ggai_agentic_max_steps <- function(max_steps = NULL) {
  max_steps <- max_steps %||% getOption("ggai.agentic_edit_max_steps", 100L)
  if (!is.numeric(max_steps) || length(max_steps) != 1L || is.na(max_steps) || max_steps < 1) {
    rlang::abort("`max_steps` must be a positive number.")
  }
  as.integer(max_steps)
}

ggai_agentic_positive_budget <- function(option_name, default) {
  value <- getOption(option_name, default)
  if (identical(value, FALSE) || is.infinite(value)) {
    return(Inf)
  }
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 1) {
    rlang::abort(paste0("`options(", option_name, "=)` must be a positive number, `Inf`, or `FALSE`."))
  }
  as.integer(value)
}

ggai_agentic_tool_log_mode <- function(mode = getOption("ggai.agentic_tool_log_mode", "quiet")) {
  mode <- mode %||% "quiet"
  if (!is.character(mode) || length(mode) != 1L || !nzchar(mode)) {
    rlang::abort("`options(ggai.agentic_tool_log_mode=)` must be one of 'quiet', 'compact', 'detailed', or 'inherit'.")
  }
  mode <- tolower(mode)
  if (!mode %in% c("quiet", "compact", "detailed", "inherit")) {
    rlang::abort("`options(ggai.agentic_tool_log_mode=)` must be one of 'quiet', 'compact', 'detailed', or 'inherit'.")
  }
  mode
}

ggai_context_preview_string <- function(x, max_chars = 160L) {
  x <- as.character(x %||% "")
  if (!length(x) || is.na(x[[1]])) {
    return("")
  }
  x <- x[[1]]
  if (!nzchar(x) || nchar(x) <= max_chars) {
    return(x)
  }
  paste0(substr(x, 1L, max_chars), "...")
}

ggai_context_compact_value <- function(x,
                                       depth = 0L,
                                       max_depth = 3L,
                                       max_items = 6L,
                                       max_chars = 160L) {
  if (is.null(x)) {
    return(NULL)
  }
  if (inherits(x, "ggplot")) {
    return(list(
      class = "ggplot",
      layer_count = length(x$layers %||% list())
    ))
  }
  if (is.data.frame(x)) {
    return(list(
      class = class(x)[[1]],
      nrow = nrow(x),
      ncol = ncol(x),
      names = utils::head(names(x), max_items)
    ))
  }
  if (is.character(x)) {
    if (length(x) == 1L) {
      return(ggai_context_preview_string(x, max_chars = max_chars))
    }
    return(list(
      class = class(x)[[1]],
      length = length(x),
      preview = utils::head(vapply(x, ggai_context_preview_string, character(1), max_chars = max_chars), max_items)
    ))
  }
  if (is.atomic(x)) {
    if (length(x) <= max_items) {
      return(x)
    }
    return(list(
      class = class(x)[[1]],
      length = length(x),
      preview = utils::head(x, max_items)
    ))
  }
  if (!is.list(x)) {
    return(list(class = class(x)[[1]] %||% typeof(x)))
  }
  if (depth >= max_depth) {
    return(list(
      class = class(x)[[1]] %||% "list",
      length = length(x)
    ))
  }

  item_count <- length(x)
  if (!item_count) {
    return(list())
  }
  keys <- names(x) %||% rep("", item_count)
  if (length(keys) < item_count) {
    keys <- c(keys, rep("", item_count - length(keys)))
  }
  keys <- keys[seq_len(item_count)]
  keys <- utils::head(keys, max_items)
  values <- tryCatch(utils::head(as.list(x), max_items), error = function(...) NULL)
  if (is.null(values)) {
    return(list(
      class = class(x)[[1]] %||% "list",
      length = length(x)
    ))
  }
  out <- vector("list", length(values))
  for (i in seq_along(values)) {
    value <- values[[i]]
    compacted_value <- ggai_context_compact_value(
      value,
      depth = depth + 1L,
      max_depth = max_depth,
      max_items = max_items,
      max_chars = max_chars
    )
    out[i] <- list(compacted_value)
  }
  keys <- keys[seq_along(out)] %||% character()
  if (length(keys) < length(out)) {
    keys <- c(keys, rep("", length(out) - length(keys)))
  }
  if (length(out)) {
    names(out) <- ifelse(nzchar(keys), keys, paste0("item_", seq_along(out)))
  }
  if (length(x) > max_items) {
    out$.truncated <- TRUE
    out$.total_items <- length(x)
  }
  out
}

ggai_compact_tool_events <- function(events,
                                     max_items = 8L,
                                     max_depth = 3L,
                                     max_chars = 160L) {
  if (!length(events)) {
    return(list())
  }
  events <- as.list(events)
  utils::head(
    lapply(events, ggai_context_compact_value, depth = 0L, max_depth = max_depth, max_items = max_items, max_chars = max_chars),
    max_items
  )
}

ggai_agentic_run_agent <- function(agent, run_args) {
  mode <- ggai_agentic_tool_log_mode()
  if (identical(mode, "inherit")) {
    return(do.call(agent$run, run_args))
  }

  if (identical(mode, "quiet")) {
    old_opts <- options(
      aisdk.tool_log_mode = "compact",
      aisdk.show_thinking = FALSE
    )
    on.exit(options(old_opts), add = TRUE)
    result <- NULL
    invisible(utils::capture.output(
      result <- do.call(agent$run, run_args),
      type = "message"
    ))
    return(result)
  }

  if (ggai_aisdk_has("with_console_chat_display")) {
    with_display <- ggai_aisdk("with_console_chat_display")
    return(with_display(
      verbose = identical(mode, "detailed"),
      show_thinking = FALSE,
      code = do.call(agent$run, run_args)
    ))
  }

  old_opts <- options(
    aisdk.tool_log_mode = mode,
    aisdk.show_thinking = FALSE
  )
  on.exit(options(old_opts), add = TRUE)
  do.call(agent$run, run_args)
}

ggai_forbidden_code_pattern <- function() {
  paste(
    "\\b(",
    paste(
      c(
        "system", "system2", "shell", "pipe", "socketConnection",
        "file", "file\\.remove", "file\\.rename", "unlink",
        "readLines", "writeLines", "write", "save", "saveRDS",
        "readRDS", "source", "setwd", "download\\.file",
        "install\\.packages", "library", "require"
      ),
      collapse = "|"
    ),
    ")\\s*\\(",
    sep = ""
  )
}

ggai_assert_safe_plot_code <- function(code) {
  if (!is.character(code) || length(code) != 1L || !nzchar(trimws(code))) {
    rlang::abort("Candidate code must be a non-empty character string.")
  }
  if (grepl(":::", code, fixed = TRUE)) {
    rlang::abort("Candidate code may not use triple-colon access.")
  }
  if (grepl(ggai_forbidden_code_pattern(), code, ignore.case = TRUE, perl = TRUE)) {
    rlang::abort("Candidate code contains a forbidden side-effecting call.")
  }
  invisible(TRUE)
}

ggai_eval_plot_code <- function(code, data = NULL, current_plot = NULL) {
  ggai_assert_safe_plot_code(code)

  env <- new.env(parent = asNamespace("ggplot2"))
  env$data <- data
  env$current_plot <- current_plot
  env$p <- current_plot

  exprs <- tryCatch(parse(text = code), error = function(e) e)
  if (inherits(exprs, "error")) {
    rlang::abort(conditionMessage(exprs))
  }

  value <- NULL
  for (expr in exprs) {
    value <- eval(expr, envir = env)
  }

  if (!inherits(value, "ggplot")) {
    rlang::abort("Candidate code must return a ggplot object.")
  }
  value
}

ggai_code_compiled_spec <- function(code,
                                    instruction = NULL,
                                    context = list(),
                                    meta = list(),
                                    warnings = list()) {
  new_compiled_spec(
    spec = list(
      code = code,
      warnings = warnings %||% list()
    ),
    kind = "r_code",
    instruction = instruction,
    context = context,
    meta = meta
  )
}

ggai_render_code_compiled <- function(compiled, plot = NULL, data = NULL) {
  current_plot <- if (inherits(plot, "ggplot")) plot else NULL
  out <- ggai_eval_plot_code(compiled$spec$code %||% "", data = data, current_plot = current_plot)
  record_compiled_spec(out, compiled)
}

ggai_agentic_edit_state <- function(data = NULL,
                                    current_plot = NULL,
                                    instruction = NULL,
                                    model = NULL,
                                    registry = NULL,
                                    skills = NULL,
                                    skill_registry = NULL,
                                    skill_path = NULL,
                                    context_session = NULL) {
  state <- new.env(parent = emptyenv())
  state$data <- data
  state$current_plot <- current_plot
  state$instruction <- instruction
  state$model <- model
  state$registry <- registry
  state$skills <- skills
  state$skill_registry <- skill_registry
  state$skill_path <- skill_path
  state$context_session <- context_session
  state$candidates <- list()
  state$attempts <- list()
  state$committed_id <- NULL
  state$blocker <- NULL
  state$decision_gate_hits <- 0L
  state
}

ggai_agentic_candidate_summary <- function(plot) {
  labels <- plot$labels %||% list()
  list(
    layer_count = length(plot$layers %||% list()),
    mapping = ggai_mapping_labels(plot$mapping),
    layers = lapply(plot$layers %||% list(), ggai_layer_context),
    facet = class(plot$facet)[1],
    coord = class(plot$coordinates)[1],
    labels = list(
      title = labels$title %||% NULL,
      subtitle = labels$subtitle %||% NULL,
      x = labels$x %||% NULL,
      y = labels$y %||% NULL,
      colour = labels$colour %||% labels$color %||% NULL,
      fill = labels$fill %||% NULL,
      size = labels$size %||% NULL,
      shape = labels$shape %||% NULL
    )
  )
}

ggai_agentic_store_candidate <- function(state,
                                         source,
                                         plot = NULL,
                                         code = NULL,
                                         compiled = NULL,
                                         validation = NULL,
                                         rationale = NULL,
                                         error = NULL,
                                         details = list()) {
  id <- paste0("candidate_", length(state$candidates) + 1L)
  validation <- validation %||% list(
    status = "error",
    message = error %||% "Candidate did not produce a plot.",
    warnings = character(),
    messages = character()
  )

  signature <- ggai_agentic_candidate_signature(
    source = source,
    plot = plot,
    code = code,
    validation = validation
  )

  state$candidates[[id]] <- list(
    id = id,
    source = source,
    code = code,
    compiled = compiled,
    rationale = rationale,
    plot = plot,
    validation = validation,
    error = error,
    signature = signature,
    details = details %||% list()
  )
  state$attempts[[length(state$attempts) + 1L]] <- list(
    id = id,
    source = source,
    rationale = rationale,
    validation = validation,
    error = error,
    signature = signature,
    details = details %||% list()
  )

  id
}

ggai_agentic_candidate_signature <- function(source,
                                             plot = NULL,
                                             code = NULL,
                                             validation = NULL) {
  payload <- list(
    source = source %||% NULL,
    status = validation$status %||% NULL
  )
  if (inherits(plot, "ggplot")) {
    payload$plot <- ggai_agentic_candidate_summary(plot)
  } else if (is.character(code) && length(code) == 1L) {
    payload$code <- gsub("[[:space:]]+", " ", trimws(code), perl = TRUE)
  } else {
    payload$message <- validation$message %||% NULL
  }
  out <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", pretty = FALSE)
  ggai_context_preview_string(out, max_chars = 800L)
}

ggai_agentic_attempt_history <- function(state, max_attempts = 12L) {
  attempts <- state$attempts %||% list()
  if (!length(attempts)) {
    return(list(
      attempts = list(),
      attempt_count = 0L,
      valid_candidates = character(),
      repeated_signatures = list()
    ))
  }

  rows <- lapply(attempts, function(attempt) {
    list(
      id = attempt$id %||% NULL,
      source = attempt$source %||% NULL,
      status = attempt$validation$status %||% "error",
      message = ggai_context_preview_string(attempt$validation$message %||% attempt$error %||% "", max_chars = 220L),
      rationale = ggai_context_preview_string(attempt$rationale %||% "", max_chars = 220L),
      signature = attempt$signature %||% NULL
    )
  })
  signatures <- vapply(rows, function(row) row$signature %||% "", character(1))
  repeated <- names(which(table(signatures[nzchar(signatures)]) > 1L))
  repeated <- lapply(repeated, function(signature) {
    list(
      signature = signature,
      count = sum(signatures == signature),
      candidates = vapply(rows[signatures == signature], function(row) row$id %||% "", character(1))
    )
  })

  list(
    attempts = utils::tail(rows, max_attempts),
    attempt_count = length(attempts),
    valid_candidates = ggai_agentic_valid_candidate_ids(state),
    repeated_signatures = repeated
  )
}

ggai_agentic_candidate_decision_gate <- function(state) {
  valid_budget <- ggai_agentic_positive_budget("ggai.agentic_valid_candidate_budget", 4L)
  attempt_budget <- ggai_agentic_positive_budget("ggai.agentic_candidate_attempt_budget", 16L)
  valid_ids <- ggai_agentic_valid_candidate_ids(state)
  attempts <- length(state$attempts %||% list())

  reason <- NULL
  if (length(valid_ids) >= valid_budget) {
    reason <- paste0(
      "There are already ", length(valid_ids),
      " validation-ok candidate(s), meeting the valid-candidate budget of ",
      valid_budget, "."
    )
  } else if (attempts >= attempt_budget) {
    reason <- paste0(
      "There have already been ", attempts,
      " candidate attempt(s), meeting the candidate-attempt budget of ",
      attempt_budget, "."
    )
  }
  if (is.null(reason)) {
    return(NULL)
  }

  state$decision_gate_hits <- state$decision_gate_hits + 1L
  list(
    status = "decision_required",
    reason = reason,
    required_next_action = "Call ggai_commit_plot_candidate for a sufficient validated candidate, call ggai_inspect_plot_attempts if you need to compare attempts, or call ggai_declare_plot_blocker if no existing candidate satisfies the request.",
    valid_candidates = valid_ids,
    attempts = attempts,
    gate_hits = state$decision_gate_hits,
    attempt_history = ggai_agentic_attempt_history(state)
  )
}

ggai_agentic_candidate_response <- function(state, id) {
  candidate <- state$candidates[[id]]
  out <- list(
    candidate_id = id,
    source = candidate$source,
    status = candidate$validation$status %||% "error",
    validation = candidate$validation,
    error = candidate$error
  )
  if (inherits(candidate$plot, "ggplot")) {
    out$plot_summary <- ggai_agentic_candidate_summary(candidate$plot)
  }
  if (inherits(candidate$compiled, "ggai_compiled_spec")) {
    out$compiled_summary <- tryCatch(
      inspect_spec(candidate$compiled),
      error = function(e) list(kind = candidate$compiled$kind %||% "unknown", error = ggai_strip_ansi(conditionMessage(e)))
    )
  }
  out
}

ggai_agentic_valid_candidate_ids <- function(state) {
  ids <- names(state$candidates)
  if (!length(ids)) {
    return(character())
  }
  ids[vapply(state$candidates, function(candidate) {
    identical(candidate$validation$status %||% NULL, "ok")
  }, logical(1))]
}

ggai_agentic_select_auto_commit_candidate <- function(state) {
  valid_ids <- ggai_agentic_valid_candidate_ids(state)
  if (!length(valid_ids)) {
    return(NULL)
  }

  code_ids <- valid_ids[vapply(state$candidates[valid_ids], function(candidate) {
    identical(candidate$source %||% NULL, "code")
  }, logical(1))]
  id <- if (length(code_ids)) {
    utils::tail(code_ids, 1L)
  } else {
    utils::tail(valid_ids, 1L)
  }
  state$candidates[[id]]
}

ggai_agentic_convergence_assessment <- function(state, result = NULL, max_steps = NULL) {
  attempts <- state$attempts %||% list()
  valid_ids <- ggai_agentic_valid_candidate_ids(state)
  last_attempt <- if (length(attempts)) attempts[[length(attempts)]] else NULL

  status <- if (!is.null(state$blocker)) {
    "blocker_declared"
  } else if (length(valid_ids)) {
    "validated_candidate_available"
  } else if (length(attempts)) {
    "no_valid_candidate"
  } else {
    "no_candidate_attempted"
  }

  list(
    status = status,
    decision = if (length(valid_ids)) "commit_validated_candidate" else "stop_without_mutation",
    max_steps = max_steps,
    attempts = length(attempts),
    valid_candidates = valid_ids,
    last_candidate = last_attempt$id %||% NULL,
    last_source = last_attempt$source %||% NULL,
    last_validation = last_attempt$validation %||% NULL,
    blocker = state$blocker %||% NULL,
    runtime_error = if (inherits(result, "error")) ggai_strip_ansi(conditionMessage(result)) else NULL,
    can_continue = is.null(state$blocker) && !length(valid_ids) && !inherits(result, "error")
  )
}

ggai_agentic_commit_summary_is_final <- function(summary) {
  if (!is.character(summary) || length(summary) != 1L || !nzchar(trimws(summary))) {
    return(FALSE)
  }
  exploratory_patterns <- c(
    "\\bto inspect\\b",
    "\\binspect the current state\\b",
    "\\bcurrent state\\b",
    "\\bintermediate\\b",
    "\\btemporary\\b",
    "\\bpartial\\b",
    "\\bdraft\\b",
    "\\bplaceholder\\b",
    "\\bnot final\\b"
  )
  !grepl(paste(exploratory_patterns, collapse = "|"), tolower(summary), perl = TRUE)
}

ggai_agentic_auto_commit <- function(state, candidate, convergence) {
  state$committed_id <- candidate$id
  state$commit <- list(
    candidate_id = candidate$id,
    completion_summary = "Runtime auto-committed a validation-ok candidate after the Agent stopped before calling ggai_commit_plot_candidate.",
    remaining_risks = "The candidate passed ggplot validation; semantic fit is based on the best available Agent candidate.",
    auto_committed = TRUE,
    convergence = convergence
  )
  invisible(candidate)
}

ggai_agentic_tools <- function(state) {
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")

  tools <- list(
    inspect_current_plot = tool(
      name = "ggai_inspect_current_plot",
      description = "Inspect the current ggplot and local data columns before proposing code.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        list(
          instruction = state$instruction,
          data = summarize_data_context(state$data),
          plot_context = build_plot_context(state$current_plot)
        )
      }
    ),
    try_plot_code = tool(
      name = "ggai_try_plot_code",
      description = paste(
        "Try complete R code that returns a ggplot object.",
        "Available objects: `data` is the data frame, `current_plot` and `p` are the current ggplot.",
        "Use ggplot2 functions with `ggplot2::`; do not install packages, read/write files, or use network."
      ),
      parameters = z$z_object(
        code = z$z_string(description = "R code returning a ggplot object"),
        rationale = z$z_string(description = "Why this code should satisfy the edit", nullable = TRUE),
        .required = "code"
      ),
      execute = function(code, rationale = NULL) {
        gate <- ggai_agentic_candidate_decision_gate(state)
        if (!is.null(gate)) {
          return(gate)
        }

        result <- tryCatch(
          {
            plot <- ggai_eval_plot_code(code, data = state$data, current_plot = state$current_plot)
            validation <- ggai_agent_validate_plot(plot)
            list(plot = plot, validation = validation, error = NULL)
          },
          error = function(e) list(
            plot = NULL,
            validation = list(status = "error", message = ggai_strip_ansi(conditionMessage(e)), warnings = character(), messages = character()),
            error = ggai_strip_ansi(conditionMessage(e))
          )
        )

        id <- ggai_agentic_store_candidate(
          state = state,
          source = "code",
          code = code,
          plot = result$plot,
          validation = result$validation,
          rationale = rationale,
          error = result$error
        )
        ggai_agentic_candidate_response(state, id)
      }
    ),
    inspect_attempts = tool(
      name = "ggai_inspect_plot_attempts",
      description = paste(
        "Inspect the Agent's recent ggplot candidate attempts, validation status, and repeated candidate signatures.",
        "Use this before deciding whether to continue, commit a valid candidate, or declare a blocker."
      ),
      parameters = z$z_object(
        max_attempts = z$z_number(description = "Maximum recent attempts to return", nullable = TRUE, default = 12)
      ),
      execute = function(max_attempts = 12) {
        ggai_agentic_attempt_history(state, max_attempts = max_attempts)
      }
    ),
    declare_blocker = tool(
      name = "ggai_declare_plot_blocker",
      description = paste(
        "Declare that the plot task cannot be completed under the current bounded tools, data, and validation gates.",
        "Use this instead of repeated equivalent attempts when no valid or sufficient candidate is reachable."
      ),
      parameters = z$z_object(
        reason = z$z_string(description = "Concise blocker reason"),
        evidence = z$z_string(description = "What attempts or observations support this blocker", nullable = TRUE),
        next_step = z$z_string(description = "What input, tool, or scope change would unblock the task", nullable = TRUE),
        .required = "reason"
      ),
      execute = function(reason, evidence = NULL, next_step = NULL) {
        state$blocker <- list(
          reason = reason,
          evidence = evidence %||% "",
          next_step = next_step %||% "",
          attempts = ggai_agentic_attempt_history(state),
          declared_at = ggai_contract_timestamp()
        )
        list(status = "blocker_declared", blocker = state$blocker)
      }
    ),
    commit_candidate = tool(
      name = "ggai_commit_plot_candidate",
      description = "Commit a previously validated ggplot candidate as the final answer.",
      parameters = z$z_object(
        candidate_id = z$z_string(description = "Candidate id returned by ggai_compile_plot_candidate or ggai_try_plot_code"),
        completion_summary = z$z_string(description = "Brief description of how the candidate satisfies the user edit"),
        remaining_risks = z$z_string(description = "Known limitations or empty string when none", nullable = TRUE),
        .required = c("candidate_id", "completion_summary")
      ),
      execute = function(candidate_id, completion_summary, remaining_risks = NULL) {
        candidate <- state$candidates[[candidate_id]] %||% NULL
        if (is.null(candidate)) {
          ggai_agent_tool_abort(paste0("Unknown candidate id: ", candidate_id))
        }
        if (!identical(candidate$validation$status %||% NULL, "ok")) {
          ggai_agent_tool_abort("Only candidates with validation status `ok` can be committed.")
        }
        if (!ggai_agentic_commit_summary_is_final(completion_summary)) {
          ggai_agent_tool_abort(
            "Commit summary describes an exploratory or partial result. Keep iterating and commit only the final answer."
          )
        }
        state$committed_id <- candidate_id
        state$commit <- list(
          candidate_id = candidate_id,
          completion_summary = completion_summary,
          remaining_risks = remaining_risks %||% "",
          auto_committed = FALSE
        )
        list(
          status = "committed",
          candidate_id = candidate_id,
          validation = candidate$validation,
          completion_summary = completion_summary,
          remaining_risks = remaining_risks %||% ""
        )
      }
    )
  )

  if (!is.null(state$context_session) && inherits(state$context_session, "ChatSession")) {
    tools <- ggai_append_unique_tool_objects(
      tools,
      ggai_aisdk_context_tools(state$context_session)
    )
  }

  tools
}

ggai_agentic_edit_system_prompt <- function(skill_text = NULL) {
  prompt <- paste(
    "You are ggai's autonomous ggplot editing agent.",
    "Use the provided bounded tools to inspect data, produce candidates, validate plots, inspect attempt history, commit a final candidate, or declare a blocker.",
    "The built-in ggai plotting skill contains the default working style; follow it when available.",
    "Do not claim success until `ggai_commit_plot_candidate` succeeds.",
    "When writing code, write against the provided `data` data frame and use explicit `ggplot2::` calls.",
    "Do not install packages, read files, write files, use network, or call external processes.",
    sep = "\n"
  )
  if (!is.null(skill_text) && nzchar(skill_text)) {
    prompt <- paste(prompt, skill_text, sep = "\n\n")
  }
  prompt
}

ggai_agentic_edit_prompt <- function(instruction, prior_error = NULL) {
  context <- if (!is.null(prior_error)) {
    paste(
      "A previous structured ggai compiler attempt could not complete this edit.",
      "Observed runtime error:",
      prior_error,
      sep = "\n"
    )
  } else {
    "Complete this edit as an autonomous ggplot agent using the available tools and loaded skills."
  }

  paste(
    "User edit request:",
    instruction,
    "",
    context,
    "",
    "Use the tools and loaded skills to decide whether to inspect, create another candidate, commit a sufficient validated plot, or declare a blocker.",
    sep = "\n"
  )
}

ggai_agentic_repair_edit <- function(compiled,
                                     base_plot,
                                     current_plot,
                                     data = NULL,
                                     instruction,
                                     model = NULL,
                                     registry = NULL,
                                     skills = NULL,
                                     skill_registry = NULL,
                                     skill_path = NULL,
                                     context_mentions = list(),
                                     context_session = NULL,
                                     prior_error = NULL,
                                     max_steps = getOption("ggai.agentic_edit_max_steps", 100L)) {
  if (!ggai_agentic_edit_enabled(model)) {
    rlang::abort(prior_error %||% "Agentic edit repair is unavailable.")
  }

  max_steps <- ggai_agentic_max_steps(max_steps)
  model <- ggai_language_model(model)
  context_session <- context_session %||% ggai_create_context_session(model = model, trace_enabled = TRUE)
  ggai_register_context_objects(
    context_session,
    mentions = context_mentions,
    data = data,
    plot = current_plot,
    instruction = instruction
  )
  state <- ggai_agentic_edit_state(
    data = data,
    current_plot = current_plot,
    instruction = instruction,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path,
    context_session = context_session
  )
  agent_skill_paths <- ggai_agent_skill_paths(
    skills = skills,
    query = instruction,
    skill_registry = skill_registry,
    skill_path = skill_path,
    builtin_skills = c("ggai-core-persona", "ggai-plot-agent", "ggai-reference-figure", "ggai-r-fonts", "ggai-single-cell-spatial")
  )
  agent <- ggai_aisdk("create_agent")(
    name = "ggai_ggplot_editor",
    description = "Autonomously repairs and completes ggplot editing tasks using validated R code candidates.",
    system_prompt = ggai_agentic_edit_system_prompt(),
    tools = ggai_agentic_tools(state),
    skills = agent_skill_paths,
    model = model
  )

  run_args <- c(
    list(
      task = ggai_agentic_edit_prompt(instruction, prior_error = prior_error),
      session = context_session,
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

  committed <- if (!is.null(state$committed_id)) {
    state$candidates[[state$committed_id]]
  } else NULL
  convergence <- ggai_agentic_convergence_assessment(
    state = state,
    result = result,
    max_steps = max_steps
  )

  if (is.null(committed) &&
      is.null(state$blocker) &&
      isTRUE(getOption("ggai.agentic_auto_commit_valid_candidates", TRUE))) {
    committed <- ggai_agentic_select_auto_commit_candidate(state)
    if (!is.null(committed)) {
      convergence$decision <- "auto_commit_validated_candidate"
      convergence$auto_committed <- TRUE
      ggai_agentic_auto_commit(state, committed, convergence)
    }
  }

  if (is.null(committed)) {
    rlang::abort(c(
      "ggai agentic edit repair could not produce a valid plot.",
      i = paste0("Runtime judgement: ", convergence$status, " after ", convergence$attempts, " candidate attempt(s)."),
      i = "The session was not mutated because no validation-ok candidate was available to commit.",
      i = if (!is.null(convergence$blocker)) paste0("Agent blocker: ", convergence$blocker$reason) else NULL,
      x = if (inherits(result, "error")) ggai_strip_ansi(conditionMessage(result)) else prior_error %||% "No valid candidate was committed."
    ))
  }

  repaired_from <- if (is.null(compiled)) "agentic_direct" else compiled$meta$edit_mode %||% "compile"
  candidate_source <- committed$source %||% "code"
  action <- paste0(
    "aisdk_agent_",
    candidate_source,
    if (is.null(prior_error)) "_edit" else "_repair"
  )
  edit_mode <- paste0(
    "agentic_",
    candidate_source,
    if (is.null(prior_error)) "_edit" else "_repair"
  )
  agent_meta <- list(
    edit_mode = edit_mode,
    repaired_from = repaired_from,
    agent_candidate_source = candidate_source,
    agent_result_text = if (inherits(result, "error")) NULL else result$text %||% NULL,
    committed_candidate = committed$id,
    attempts = state$attempts,
    commit = state$commit %||% list(),
    convergence = convergence,
    tool_calls = if (inherits(result, "error")) {
      list()
    } else {
      ggai_compact_tool_events(result$all_tool_calls %||% list())
    },
    tool_results = if (inherits(result, "error")) {
      list()
    } else {
      ggai_compact_tool_events(result$all_tool_results %||% list())
    },
    run_args = names(ggai_agentic_run_args(model))
  )
  if (!is.null(context_session) && inherits(context_session, "ChatSession")) {
    agent_meta$context_session <- list(
      enabled = TRUE,
      registered = tryCatch(context_session$get_memory("ggai_registered_context", default = list()), error = function(...) list()),
      tool_names = ggai_context_tool_names(ggai_aisdk_context_tools(context_session))
    )
  }

  repaired <- if (inherits(committed$compiled, "ggai_compiled_spec")) {
    out <- committed$compiled
    out$instruction <- instruction
    out$context <- build_plot_context(current_plot)
    out$meta <- utils::modifyList(out$meta %||% list(), agent_meta)
    out
  } else {
    ggai_code_compiled_spec(
      code = committed$code,
      instruction = instruction,
      context = build_plot_context(current_plot),
      meta = agent_meta,
      warnings = list("Generated by aisdk Agent validated-code editing.")
    )
  }

  rendered <- record_compiled_spec(committed$plot, repaired)
  repairs <- if (is.null(prior_error)) {
    list()
  } else {
    list(list(
      attempt = length(state$attempts),
      action = action,
      observed_validation = list(status = "error", message = prior_error %||% ""),
      repaired = TRUE,
      final_validation = committed$validation,
      outcome = "completed_with_agent"
    ))
  }

  list(
    plot = rendered,
    compiled = repaired,
    validation = committed$validation,
    repairs = repairs,
    render_result = list(
      status = "ok",
      details = list(
        layer_count = length(rendered$layers %||% list()),
        repairs = repairs,
        react_steps = list(
          ggai_agent_trace_step(
            if (is.null(prior_error)) "agentic_edit" else "agentic_repair",
            status = "completed",
            details = list(
              action = action,
              candidate_id = committed$id,
              attempts = length(state$attempts),
              completion_summary = state$commit$completion_summary %||% NULL,
              auto_committed = isTRUE(state$commit$auto_committed),
              convergence_status = convergence$status,
              convergence_decision = convergence$decision
            )
          )
        )
      )
    )
  )
}
