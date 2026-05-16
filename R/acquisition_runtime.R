ggai_text_looks_like_file_path <- function(x) {
  if (!is.character(x) || length(x) != 1L || !nzchar(x)) {
    return(FALSE)
  }
  text <- trimws(x)
  expanded <- path.expand(text)
  if (file.exists(expanded)) {
    return(TRUE)
  }
  if (grepl("[[:space:]]", text)) {
    return(FALSE)
  }
  if (grepl("^~?[/\\\\]|^[.]{1,2}[/\\\\]|^[A-Za-z]:[/\\\\]", text, perl = TRUE)) {
    return(TRUE)
  }
  if (grepl("^[^[:space:]:/\\\\]+[.](csv|tsv|txt|rds)$", text, ignore.case = TRUE, perl = TRUE)) {
    return(TRUE)
  }
  if (grepl(":", text, fixed = TRUE) || grepl(intToUtf8(0xFF1A), text, fixed = TRUE)) {
    return(FALSE)
  }
  grepl("^[^[:space:]:]+[/\\\\][^[:space:]:]+$", text, perl = TRUE)
}

ggai_supported_data_file_extension <- function(path) {
  tolower(tools::file_ext(path)) %in% c("csv", "tsv", "txt", "rds")
}

ggai_supported_data_file_path <- function(path) {
  ggai_text_looks_like_file_path(path) && ggai_supported_data_file_extension(path)
}

ggai_detect_local_paths <- function(text) {
  if (!is.character(text) || length(text) != 1L || !nzchar(text)) {
    return(character())
  }
  matches <- regmatches(
    text,
    gregexpr("(~?/[^[:space:],;]+|[.]{1,2}/[^[:space:],;]+)", text, perl = TRUE)
  )[[1]]
  if (!length(matches) || identical(matches, "-1")) {
    return(character())
  }
  candidates <- unique(gsub("[[:punct:]]+$", "", matches, perl = TRUE))
  candidates <- path.expand(candidates)
  candidates[file.exists(candidates)]
}

ggai_detect_urls <- function(text) {
  if (!is.character(text) || length(text) != 1L || !nzchar(text)) {
    return(character())
  }
  matches <- regmatches(
    text,
    gregexpr("https?://[^[:space:]<>\"',;]+", text, perl = TRUE)
  )[[1]]
  if (!length(matches) || identical(matches, "-1")) {
    return(character())
  }
  unique(gsub("[)\\]}]+$", "", matches, perl = TRUE))
}

ggai_url_is_allowed <- function(url, allowed_urls) {
  is.character(url) &&
    length(url) == 1L &&
    nzchar(url) &&
    identical(tolower(substr(url, 1L, 4L)), "http") &&
    url %in% unlist(allowed_urls %||% list(), use.names = FALSE)
}

ggai_html_to_text <- function(html) {
  html <- paste(as.character(html %||% ""), collapse = "\n")
  html <- gsub("(?is)<script[^>]*>.*?</script>", " ", html, perl = TRUE)
  html <- gsub("(?is)<style[^>]*>.*?</style>", " ", html, perl = TRUE)
  html <- gsub("(?is)<[^>]+>", " ", html, perl = TRUE)
  html <- gsub("&nbsp;|&#160;", " ", html, perl = TRUE)
  html <- gsub("&amp;", "&", html, fixed = TRUE)
  html <- gsub("&lt;", "<", html, fixed = TRUE)
  html <- gsub("&gt;", ">", html, fixed = TRUE)
  html <- gsub("&quot;", "\"", html, fixed = TRUE)
  html <- gsub("&#39;|&apos;", "'", html, perl = TRUE)
  html <- gsub("[[:space:]]+", " ", html, perl = TRUE)
  trimws(html)
}

ggai_fetch_url_text <- function(url,
                                timeout = getOption("ggai.url_fetch_timeout", 20L),
                                max_bytes = getOption("ggai.url_fetch_max_bytes", 1000000L)) {
  con <- NULL
  on.exit(if (!is.null(con)) close(con), add = TRUE)
  con <- base::url(url, open = "rb")
  raw <- readBin(con, what = "raw", n = as.integer(max_bytes))
  text <- rawToChar(raw)
  Encoding(text) <- "UTF-8"
  ggai_html_to_text(text)
}

ggai_url_reference_record <- function(url, text, goal, max_chars = getOption("ggai.url_text_max_chars", 12000L)) {
  text <- ggai_context_preview_string(text, max_chars = max_chars)
  list(
    source_url = url,
    content_excerpt = text,
    user_goal = goal,
    collected_at = ggai_contract_timestamp()
  )
}

ggai_reference_seed_data <- function() {
  groups <- c("Group A", "Group B", "Group C", "Group D")
  facets <- c("Reference pattern", "Alternative view")
  x <- rep(seq_len(6L), times = length(groups) * length(facets))
  group <- rep(groups, each = 6L, times = length(facets))
  facet <- rep(facets, each = length(groups) * 6L)
  group_index <- match(group, groups)
  facet_index <- match(facet, facets)
  value <- round(
    42 +
      x * (2.5 + group_index / 4) +
      sin(x + group_index) * 4 +
      (facet_index - 1L) * 8,
    1
  )
  data.frame(
    x = x,
    item = paste0("Item ", x),
    group = group,
    facet = facet,
    value = value,
    metric = value / max(value),
    stringsAsFactors = FALSE
  )
}

ggai_reference_brief_instruction <- function(goal, brief) {
  assumptions <- brief$assumptions %||% character()
  evidence <- brief$evidence %||% list()
  evidence_text <- vapply(evidence, function(item) {
    paste(Filter(nzchar, c(
      item$source_url %||% item$source %||% NULL,
      item$content_excerpt %||% item$summary %||% NULL,
      item$status %||% NULL
    )), collapse = ": ")
  }, character(1))
  paste(
    "Continue from this reference-only acquisition brief.",
    "",
    "Original user request:",
    goal,
    "",
    "Reference / visual goal:",
    brief$visual_goal %||% goal,
    "",
    "Reference summary:",
    brief$reference_summary %||% "No reliable reference content was extracted.",
    "",
    "Important data condition:",
    "No original source data frame was acquired. The provided data frame is only generic seed data for an illustrative/template plot.",
    "You may transform or replace the seed data inside bounded plotting code if that better completes the user's visual goal.",
    "Make the final plot honest: when using illustrative data, label or subtitle it as an example/template rather than presenting it as extracted source data.",
    "",
    "Assumptions:",
    paste(assumptions, collapse = "\n"),
    "",
    "Evidence:",
    paste(evidence_text, collapse = "\n"),
    sep = "\n"
  )
}

ggai_acquisition_from_reference_brief <- function(goal,
                                                  visual_goal,
                                                  reference_summary,
                                                  chart_type = NULL,
                                                  assumptions = NULL,
                                                  source_note = NULL,
                                                  evidence = list(),
                                                  completion_summary = NULL,
                                                  remaining_risks = NULL) {
  visual_goal <- visual_goal %||% goal
  reference_summary <- reference_summary %||% "Reference-only continuation requested by the Agent."
  assumptions <- assumptions %||% character()
  if (is.character(assumptions) && length(assumptions) == 1L) {
    assumptions <- strsplit(assumptions, "\n", fixed = TRUE)[[1]]
  }
  assumptions <- trimws(as.character(assumptions))
  assumptions <- assumptions[nzchar(assumptions)]
  if (!length(assumptions)) {
    assumptions <- "Original source data was not available; output is an illustrative template."
  }
  source_note <- ggai_acquisition_source_note(source_note %||% list(
    source = "reference_brief",
    note = "Reference-only continuation; no original source data frame was acquired.",
    policy = "best_effort_reference_continuation",
    original_data_available = FALSE
  ))
  task <- new_ggai_task(
    goal = goal,
    task_type = "reference_visualization",
    target = "plot",
    data_ref = "ggai_reference_seed_data",
    assumptions = as.list(assumptions),
    meta = list(source = "acquisition_reference_brief")
  )
  visual <- new_visual_brief(
    task_id = task$id,
    intent = visual_goal,
    chart_type = chart_type %||% "reference_driven_template",
    evidence = evidence %||% list(),
    assumptions = as.list(assumptions),
    meta = list(
      reference_summary = reference_summary,
      original_data_available = FALSE,
      completion_summary = completion_summary %||% ""
    )
  )
  brief <- list(
    visual_goal = visual_goal,
    reference_summary = reference_summary,
    chart_type = chart_type %||% "reference_driven_template",
    assumptions = assumptions,
    source_note = source_note,
    evidence = evidence %||% list(),
    completion_summary = completion_summary %||% "",
    remaining_risks = remaining_risks %||% ""
  )
  list(
    kind = "reference_brief",
    tool_name = "agent_reference_brief",
    data = ggai_reference_seed_data(),
    data_summary = summarize_data_context(ggai_reference_seed_data()),
    instruction = ggai_reference_brief_instruction(goal, brief),
    source_note = source_note,
    evidence = evidence %||% list(),
    task = task,
    visual_brief = visual,
    reference_brief = brief,
    trace = list(
      source = "agent_reference_brief",
      committed = TRUE,
      completion_summary = completion_summary %||% "",
      remaining_risks = remaining_risks %||% "",
      original_data_available = FALSE,
      committed_at = ggai_contract_timestamp()
    )
  )
}

ggai_acquisition_abort <- function(goal, reason, details = list()) {
  blocker <- details$blocker %||% NULL
  extra <- character()
  if (is.list(blocker) && !is.null(blocker$reason)) {
    extra <- c(extra, paste0("Agent blocker: ", blocker$reason))
  }
  if (is.list(blocker) && !is.null(blocker$next_step) && nzchar(blocker$next_step)) {
    extra <- c(extra, paste0("Suggested next step: ", blocker$next_step))
  }
  rlang::abort(
    c(
      "ggai acquisition could not produce data or a reference brief.",
      i = reason,
      i = extra,
      i = "Natural-language-only requests need a model-backed Agent, a configured acquisition tool, or a committed reference brief for best-effort plotting.",
      i = "The model is not allowed to generate arbitrary network or file-system code during acquisition.",
      x = "Pass `model=`, pass a data frame or file path, configure acquisition tools, or let the Agent commit a reference brief when source data is unavailable."
    ),
    class = "ggai_acquisition_error",
    goal = goal,
    blocker = c(list(reason = reason), details %||% list())
  )
}

ggai_acquisition_tool_name <- function(x) {
  if (!is.character(x) || length(x) != 1L || !nzchar(x) || grepl("[^A-Za-z0-9_.-]", x)) {
    rlang::abort("Acquisition tool `name` must be a non-empty identifier using letters, numbers, '.', '_', or '-'.")
  }
  x
}

#' Create a controlled ggai data acquisition tool
#'
#' @param name Stable tool name.
#' @param description Human-readable description of the data the tool can
#'   acquire.
#' @param acquire Function called as `acquire(goal, context)` that returns a
#'   data frame or a list with a `data` data frame.
#' @param can_handle Optional function called as `can_handle(goal, context)`.
#'   Return `TRUE` when the tool is a deterministic match for the request.
#' @param meta Optional metadata describing policy, source, and limits.
#'
#' @return A `ggai_acquisition_tool`.
#' @export
ggai_acquisition_tool <- function(name,
                                  description,
                                  acquire,
                                  can_handle = NULL,
                                  meta = list()) {
  name <- ggai_acquisition_tool_name(name)
  if (!is.character(description) || length(description) != 1L || !nzchar(description)) {
    rlang::abort("Acquisition tool `description` must be a single non-empty string.")
  }
  if (!is.function(acquire)) {
    rlang::abort("Acquisition tool `acquire` must be a function.")
  }
  if (!is.null(can_handle) && !is.function(can_handle)) {
    rlang::abort("Acquisition tool `can_handle` must be NULL or a function.")
  }
  if (!is.list(meta)) {
    rlang::abort("Acquisition tool `meta` must be a list.")
  }

  structure(
    list(
      name = name,
      description = description,
      acquire = acquire,
      can_handle = can_handle,
      meta = meta
    ),
    class = "ggai_acquisition_tool"
  )
}

ggai_normalize_acquisition_tool <- function(tool, name = NULL) {
  if (inherits(tool, "ggai_acquisition_tool")) {
    return(tool)
  }

  if (is.function(tool)) {
    return(ggai_acquisition_tool(
      name = ggai_acquisition_tool_name(name %||% "acquisition_tool"),
      description = "User-supplied ggai acquisition function.",
      acquire = tool
    ))
  }

  if (is.list(tool) && !is.null(tool$acquire)) {
    return(ggai_acquisition_tool(
      name = tool$name %||% name %||% "acquisition_tool",
      description = tool$description %||% "User-supplied ggai acquisition tool.",
      acquire = tool$acquire,
      can_handle = tool$can_handle %||% NULL,
      meta = tool$meta %||% list()
    ))
  }

  rlang::abort("Each acquisition tool must be created by `ggai_acquisition_tool()` or be a compatible list/function.")
}

ggai_acquisition_tools <- function(acquisition_tools = NULL) {
  tools <- acquisition_tools
  if (is.null(tools)) {
    tools <- getOption("ggai.acquisition_tools", list())
  }
  if (is.null(tools)) {
    tools <- list()
  }
  if (inherits(tools, "ggai_acquisition_tool") || is.function(tools)) {
    tools <- list(tools)
  }
  if (!is.list(tools)) {
    rlang::abort("`acquisition_tools` must be a list of controlled acquisition tools.")
  }

  names_in <- names(tools) %||% rep("", length(tools))
  normalized <- Map(function(tool, name) {
    ggai_normalize_acquisition_tool(tool, name = if (nzchar(name)) name else NULL)
  }, tools, names_in)
  names(normalized) <- vapply(normalized, function(tool) tool$name, character(1))
  normalized
}

ggai_acquisition_context <- function(goal) {
  list(
    goal = goal,
    created_at = ggai_contract_timestamp(),
    local_paths = as.list(ggai_detect_local_paths(goal)),
    urls = as.list(ggai_detect_urls(goal)),
    constraints = list(
      controlled_tools_only = TRUE,
      require_data_frame_or_reference_brief = TRUE,
      model_code_must_return_data_frame = TRUE,
      url_fetch_requires_explicit_user_url = TRUE
    )
  )
}

ggai_acquisition_manifest <- function(tools) {
  lapply(tools, function(tool) {
    list(
      name = tool$name,
      description = tool$description,
      meta = tool$meta %||% list()
    )
  })
}

ggai_acquisition_can_handle <- function(tool, goal, context) {
  if (is.null(tool$can_handle)) {
    return(NA)
  }
  out <- tryCatch(
    tool$can_handle(goal, context),
    error = function(e) e
  )
  if (inherits(out, "error")) {
    return(FALSE)
  }
  isTRUE(out)
}

ggai_acquisition_eligible_tools <- function(tools, goal, context) {
  if (!length(tools)) {
    return(list())
  }
  match <- vapply(tools, ggai_acquisition_can_handle, logical(1), goal = goal, context = context)
  if (any(match, na.rm = TRUE)) {
    return(tools[which(match %in% TRUE)])
  }
  if (length(tools) == 1L && is.na(match[[1]])) {
    return(tools)
  }
  list()
}

ggai_acquisition_source_note <- function(source_note) {
  if (is.null(source_note)) {
    return(list())
  }
  if (is.list(source_note)) {
    return(source_note)
  }
  list(note = as.character(source_note))
}

ggai_new_acquisition_session <- function(goal, context, model = NULL) {
  session <- ggai_aisdk("create_shared_session")(
    model = model,
    sandbox_mode = "permissive",
    trace_enabled = TRUE
  )
  session$set_var("goal", goal, scope = "acquisition")
  session$set_var("context", context, scope = "acquisition")
  session$set_var("today", Sys.Date(), scope = "acquisition")
  session
}

ggai_acquisition_value_summary <- function(value, preview_n = 5L) {
  preview_n <- max(0L, as.integer(preview_n %||% 5L))
  if (is.data.frame(value)) {
    return(list(
      class = class(value)[[1]],
      nrow = nrow(value),
      ncol = ncol(value),
      names = names(value),
      classes = stats::setNames(vapply(value, function(x) class(x)[1], character(1)), names(value)),
      preview = utils::head(value, preview_n)
    ))
  }

  if (is.list(value) && is.data.frame(value$data)) {
    return(list(
      class = class(value)[[1]] %||% "list",
      has_data = TRUE,
      data = ggai_acquisition_value_summary(value$data, preview_n = preview_n)
    ))
  }

  if (is.atomic(value)) {
    return(list(
      class = class(value)[[1]],
      length = length(value),
      preview = utils::head(value, preview_n)
    ))
  }

  list(
    class = class(value)[[1]] %||% typeof(value),
    type = typeof(value)
  )
}

ggai_acquisition_session_summary <- function(session, preview_n = 3L) {
  reserved <- c("goal", "context", "today")
  variables <- session$summarize_vars(scope = "acquisition")
  if (is.data.frame(variables) && nrow(variables)) {
    variables <- variables[!variables$name %in% reserved, , drop = FALSE]
  }
  names <- if (is.data.frame(variables) && nrow(variables)) variables$name else character()
  objects <- lapply(names, function(name) {
    value <- session$get_var(name, scope = "acquisition")
    c(list(name = name), ggai_acquisition_value_summary(value, preview_n = preview_n))
  })
  list(
    object_count = length(names),
    variables = variables,
    objects = objects
  )
}

ggai_validate_acquired_data <- function(result, goal, tool, trace = list()) {
  raw <- result
  if (is.data.frame(raw)) {
    raw <- list(data = raw)
  }
  if (!is.list(raw) || !is.data.frame(raw$data)) {
    rlang::abort(
      paste0("Acquisition tool `", tool$name, "` did not return a data frame."),
      class = "ggai_acquisition_tool_error"
    )
  }

  data <- as.data.frame(raw$data)
  list(
    kind = raw$kind %||% tool$name,
    tool_name = tool$name,
    data = data,
    instruction = raw$instruction %||% goal,
    source_note = ggai_acquisition_source_note(raw$source_note %||% raw$source %||% NULL),
    evidence = raw$evidence %||% list(),
    trace = trace,
    data_summary = summarize_data_context(data)
  )
}

ggai_run_acquisition_tool <- function(tool, goal, context, query = NULL, rationale = NULL) {
  result <- tryCatch(
    tool$acquire(query %||% goal, context),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    rlang::abort(
      paste0("Acquisition tool `", tool$name, "` failed: ", conditionMessage(result)),
      class = "ggai_acquisition_tool_error"
    )
  }
  ggai_validate_acquired_data(
    result,
    goal = goal,
    tool = tool,
    trace = list(
      mode = "tool",
      rationale = rationale %||% NULL,
      acquired_at = ggai_contract_timestamp()
    )
  )
}

ggai_acquisition_forbidden_code_pattern <- function() {
  paste(
    "\\b(",
    paste(
      c(
        "system", "system2", "shell", "pipe", "socketConnection",
        "file", "file\\.remove", "file\\.rename", "unlink",
        "write", "writeLines", "save", "saveRDS", "source", "setwd",
        "install\\.packages", "library", "require", "dyn\\.load",
        "assignInNamespace", "unlockBinding"
      ),
      collapse = "|"
    ),
    ")\\s*\\(",
    sep = ""
  )
}

ggai_assert_safe_acquisition_code <- function(code) {
  if (!is.character(code) || length(code) != 1L || !nzchar(trimws(code))) {
    rlang::abort("Acquisition code must be a non-empty character string.")
  }
  if (grepl(":::", code, fixed = TRUE)) {
    rlang::abort("Acquisition code may not use triple-colon access.")
  }
  if (grepl(ggai_acquisition_forbidden_code_pattern(), code, ignore.case = TRUE, perl = TRUE)) {
    rlang::abort("Acquisition code contains a forbidden side-effecting call.")
  }
  invisible(TRUE)
}

ggai_eval_acquisition_code <- function(code, goal, context) {
  ggai_assert_safe_acquisition_code(code)

  env <- new.env(parent = baseenv())
  env$goal <- goal
  env$context <- context
  env$today <- Sys.Date()

  exprs <- tryCatch(parse(text = code), error = function(e) e)
  if (inherits(exprs, "error")) {
    rlang::abort(conditionMessage(exprs), class = "ggai_acquisition_tool_error")
  }

  value <- NULL
  for (expr in exprs) {
    value <- eval(expr, envir = env)
  }
  value
}

ggai_acquisition_from_code <- function(code,
                                       goal,
                                       context,
                                       kind = NULL,
                                       instruction = NULL,
                                       source_note = NULL,
                                       rationale = NULL) {
  result <- tryCatch(
    ggai_eval_acquisition_code(code, goal = goal, context = context),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    rlang::abort(
      paste0("Acquisition code failed: ", conditionMessage(result)),
      class = "ggai_acquisition_tool_error"
    )
  }

  if (is.data.frame(result)) {
    result <- list(data = result)
  }
  if (!is.null(kind)) {
    result$kind <- result$kind %||% kind
  }
  if (!is.null(instruction)) {
    result$instruction <- result$instruction %||% instruction
  }
  if (!is.null(source_note)) {
    result$source_note <- result$source_note %||% source_note
  }

  tool <- ggai_acquisition_tool(
    name = "agent_data_frame_code",
    description = "Agent-generated bounded R code that returns a data frame.",
    acquire = function(goal, context) result
  )
  ggai_validate_acquired_data(
    result,
    goal = goal,
    tool = tool,
    trace = list(
      mode = "agent_data_frame_code",
      rationale = rationale %||% NULL,
      code = code,
      acquired_at = ggai_contract_timestamp()
    )
  )
}

ggai_acquisition_from_session_object <- function(name,
                                                 state,
                                                 kind = NULL,
                                                 instruction = NULL,
                                                 source_note = NULL,
                                                 rationale = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    rlang::abort("`object_name` must be a non-empty string.", class = "ggai_acquisition_tool_error")
  }
  if (!grepl("^[A-Za-z.][A-Za-z0-9_.]*$", name, perl = TRUE)) {
    rlang::abort("`object_name` must be a simple R object name.", class = "ggai_acquisition_tool_error")
  }

  missing <- new.env(parent = emptyenv())
  result <- state$acquisition_session$get_var(name, scope = "acquisition", default = missing)
  if (identical(result, missing)) {
    rlang::abort(paste0("Acquisition session object not found: ", name), class = "ggai_acquisition_tool_error")
  }
  if (is.data.frame(result)) {
    result <- list(data = result)
  }
  if (!is.list(result) || !is.data.frame(result$data)) {
    rlang::abort(
      paste0("Acquisition session object `", name, "` is not a data frame or list(data=...)."),
      class = "ggai_acquisition_tool_error"
    )
  }
  result$kind <- result$kind %||% kind %||% name
  result$instruction <- result$instruction %||% instruction %||% state$goal
  if (!is.null(source_note)) {
    result$source_note <- result$source_note %||% source_note
  }

  tool <- ggai_acquisition_tool(
    name = "agent_session_object",
    description = "Agent-selected aisdk shared-session object committed as a data frame.",
    acquire = function(goal, context) result
  )
  ggai_validate_acquired_data(
    result,
    goal = state$goal,
    tool = tool,
    trace = list(
      mode = "agent_session_object",
      object_name = name,
      rationale = rationale %||% NULL,
      steps = state$steps %||% list(),
      session_trace_summary = state$acquisition_session$trace_summary(),
      acquired_at = ggai_contract_timestamp()
    )
  )
}

ggai_run_acquisition_step_code <- function(state,
                                           code,
                                           rationale = NULL,
                                           preview_n = 5L) {
  ggai_assert_safe_acquisition_code(code)
  result <- state$acquisition_session$execute_code(
    code = code,
    scope = "acquisition",
    capture_output = TRUE
  )

  status <- if (isTRUE(result$success)) "ok" else "error"
  step <- list(
    index = length(state$steps %||% list()) + 1L,
    status = status,
    code = code,
    rationale = rationale %||% NULL,
    message = result$error %||% NULL,
    duration_ms = result$duration_ms %||% NULL,
    timestamp = ggai_contract_timestamp()
  )
  state$steps[[length(state$steps) + 1L]] <- step

  if (!isTRUE(result$success)) {
    return(list(
      status = "error",
      message = ggai_strip_ansi(result$error %||% "Acquisition step failed."),
      step = step,
      output = utils::head(result$output %||% character(), 20L),
      session = ggai_acquisition_session_summary(state$acquisition_session, preview_n = preview_n)
    ))
  }

  out <- list(
    status = "ok",
    step = step,
    result = ggai_acquisition_value_summary(result$result, preview_n = preview_n),
    output = utils::head(result$output %||% character(), 20L),
    session = ggai_acquisition_session_summary(state$acquisition_session, preview_n = preview_n)
  )

  candidate_value <- result$result
  if (is.data.frame(candidate_value) || (is.list(candidate_value) && is.data.frame(candidate_value$data))) {
    acquired <- tryCatch(
      {
        result_for_validation <- candidate_value
        if (is.data.frame(result_for_validation)) {
          result_for_validation <- list(data = result_for_validation)
        }
        result_for_validation$kind <- result_for_validation$kind %||% "acquisition_step_data"
        result_for_validation$instruction <- result_for_validation$instruction %||% state$goal
        tool <- ggai_acquisition_tool(
          name = "agent_session_step",
          description = "Data frame produced by one bounded aisdk shared-session acquisition step.",
          acquire = function(goal, context) result_for_validation
        )
        ggai_validate_acquired_data(
          result_for_validation,
          goal = state$goal,
          tool = tool,
          trace = list(
            mode = "agent_session_step",
            rationale = rationale %||% NULL,
            code = code,
            steps = state$steps %||% list(),
            session_trace_summary = state$acquisition_session$trace_summary(),
            acquired_at = ggai_contract_timestamp()
          )
        )
      },
      error = function(e) e
    )
    if (!inherits(acquired, "error")) {
      candidate_id <- ggai_store_acquisition_candidate(
        state,
        acquired = acquired,
        source = "session_step",
        rationale = rationale
      )
      out$candidate <- ggai_acquisition_candidate_response(acquired, candidate_id)
    }
  }

  out
}

ggai_store_acquisition_candidate <- function(state, acquired, source, rationale = NULL) {
  id <- paste0("acquired_", length(state$candidates %||% list()) + 1L)
  acquired$trace <- utils::modifyList(
    acquired$trace %||% list(),
    list(
      candidate_id = id,
      candidate_source = source,
      rationale = rationale %||% acquired$trace$rationale %||% NULL
    )
  )
  state$candidates[[id]] <- acquired
  id
}

ggai_acquisition_candidate_response <- function(acquired, candidate_id) {
  list(
    status = "candidate_ready",
    candidate_id = candidate_id,
    tool_name = acquired$tool_name,
    kind = acquired$kind,
    data_summary = acquired$data_summary,
    source_note = acquired$source_note,
    instruction = acquired$instruction
  )
}

ggai_select_acquisition_auto_commit_candidate <- function(state) {
  ids <- names(state$candidates %||% list())
  if (!length(ids)) {
    return(NULL)
  }
  utils::tail(ids, 1L)
}

ggai_acquisition_model_enabled <- function(model) {
  !is.null(model) &&
    (
      inherits(model, "LanguageModelV1") ||
        (is.character(model) && length(model) == 1L && nzchar(model))
    ) &&
    ggai_aisdk_runtime_available()
}

ggai_acquisition_agent_tools <- function(state) {
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")

  list(
    inspect_acquisition_context = tool(
      name = "ggai_inspect_acquisition_context",
      description = "Inspect the acquisition goal, explicitly referenced local paths, configured tools, and constraints.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        list(
          goal = state$goal,
          local_paths = state$context$local_paths %||% list(),
          urls = state$context$urls %||% list(),
          constraints = state$context$constraints %||% list(),
          configured_tools = ggai_acquisition_manifest(state$tools)
        )
      }
    ),
    inspect_acquisition_session = tool(
      name = "ggai_inspect_acquisition_session",
      description = "Inspect intermediate objects in the aisdk shared acquisition session.",
      parameters = z$z_object(
        preview_n = z$z_number(description = "Preview rows or values per object", nullable = TRUE, default = 3)
      ),
      execute = function(preview_n = 3) {
        ggai_acquisition_session_summary(state$acquisition_session, preview_n = preview_n)
      }
    ),
    run_acquisition_step = tool(
      name = "ggai_run_acquisition_step",
      description = paste(
        "Run one small bounded R step in the aisdk shared acquisition session.",
        "Use this for progressive discovery, parsing, cleaning, aggregation, and validation.",
        "Objects persist across calls. Available objects include `goal`, `context`, and `today`.",
        "If the step returns a data frame, ggai records it as a candidate; otherwise inspect the session and keep iterating."
      ),
      parameters = z$z_object(
        code = z$z_string(description = "Small R code step to run in the acquisition session"),
        rationale = z$z_string(description = "Why this step is useful now", nullable = TRUE),
        preview_n = z$z_number(description = "Preview rows or values to return", nullable = TRUE, default = 5),
        .required = "code"
      ),
      execute = function(code, rationale = NULL, preview_n = 5) {
        ggai_run_acquisition_step_code(
          state = state,
          code = code,
          rationale = rationale,
          preview_n = preview_n
        )
      }
    ),
    read_url = tool(
      name = "ggai_read_url_reference",
      description = paste(
        "Read one explicitly user-provided http/https URL from the acquisition context.",
        "This is a bounded URL-reading tool for gathering reference text or visual-description clues.",
        "It stores reference evidence in the acquisition session; it does not create or commit a data-frame candidate.",
        "Use it only for URLs listed by ggai_inspect_acquisition_context."
      ),
      parameters = z$z_object(
        url = z$z_string(description = "URL to read; must appear in acquisition context urls"),
        rationale = z$z_string(description = "Why reading this URL is needed for the user's plotting goal", nullable = TRUE),
        max_chars = z$z_number(description = "Maximum text characters to keep in the candidate excerpt", nullable = TRUE, default = 12000),
        .required = "url"
      ),
      execute = function(url, rationale = NULL, max_chars = 12000) {
        if (!ggai_url_is_allowed(url, state$context$urls %||% list())) {
          ggai_agent_tool_abort("URL reads are limited to explicit http/https URLs present in the user's request.")
        }
        text <- tryCatch(
          ggai_fetch_url_text(url),
          error = function(e) e
        )
        if (inherits(text, "error")) {
          ggai_agent_tool_abort(paste0("URL read failed: ", ggai_strip_ansi(conditionMessage(text))))
        }
        reference <- ggai_url_reference_record(
          url = url,
          text = text,
          goal = state$goal,
          max_chars = max_chars
        )
        reference_name <- paste0("url_reference_", length(state$references %||% list()) + 1L)
        state$references[[reference_name]] <- c(
          reference,
          list(
            rationale = rationale %||% NULL,
            text_chars = nchar(text)
          )
        )
        state$acquisition_session$set_var(reference_name, reference, scope = "acquisition")
        list(
          status = "reference_ready",
          reference_name = reference_name,
          source_url = url,
          content_preview = ggai_context_preview_string(text, max_chars = 1000L),
          next_actions = c(
            "Use ggai_run_acquisition_step to extract structured data or style notes from the reference.",
            "Commit a data-frame candidate only after a real data frame is produced.",
            "Declare a blocker if the reference is insufficient for the requested plot."
          )
        )
      }
    ),
    list_acquisition_tools = tool(
      name = "ggai_list_acquisition_tools",
      description = "List controlled data acquisition tools available to ggai.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        list(tools = ggai_acquisition_manifest(state$tools))
      }
    ),
    run_acquisition_tool = tool(
      name = "ggai_run_acquisition_tool",
      description = paste(
        "Run one configured acquisition tool and return a validated data-frame acquisition result.",
        "Use only the listed tools. Do not generate R code, network code, or file-system code."
      ),
      parameters = z$z_object(
        tool_name = z$z_string(description = "Name of the configured acquisition tool to run"),
        query = z$z_string(description = "Focused acquisition query for the tool", nullable = TRUE),
        rationale = z$z_string(description = "Why this tool matches the user goal", nullable = TRUE),
        .required = "tool_name"
      ),
      execute = function(tool_name, query = NULL, rationale = NULL) {
        selected <- state$tools[[tool_name]] %||% NULL
        if (is.null(selected)) {
          ggai_agent_tool_abort(paste0("Unknown acquisition tool: ", tool_name))
        }
        acquired <- ggai_run_acquisition_tool(
          selected,
          goal = state$goal,
          context = state$context,
          query = query,
          rationale = rationale
        )
        candidate_id <- ggai_store_acquisition_candidate(
          state,
          acquired = acquired,
          source = "configured_tool",
          rationale = rationale
        )
        ggai_acquisition_candidate_response(acquired, candidate_id)
      }
    ),
    try_acquisition_code = tool(
      name = "ggai_try_acquisition_code",
      description = paste(
        "Try bounded R code that returns a data frame or a list with a `data` data frame.",
        "Use this for general data acquisition or reshaping when no configured source tool matches.",
        "Allowed style: base R plus explicit namespace calls such as tools::CRAN_package_db(), utils::read.csv(), stats::aggregate(), jsonlite::fromJSON().",
        "Forbidden: package installation, library/require, system calls, writing files, deleting files, sourcing code, or arbitrary shell/network helpers."
      ),
      parameters = z$z_object(
        code = z$z_string(description = "R code whose final value is a data frame or list(data=...)"),
        kind = z$z_string(description = "Short acquisition kind", nullable = TRUE),
        instruction = z$z_string(description = "Visualization instruction for the acquired data frame", nullable = TRUE),
        source_note = z$z_string(description = "Concise source/evidence note for the acquired data", nullable = TRUE),
        rationale = z$z_string(description = "Why this code safely satisfies the acquisition goal", nullable = TRUE),
        .required = "code"
      ),
      execute = function(code, kind = NULL, instruction = NULL, source_note = NULL, rationale = NULL) {
        acquired <- ggai_acquisition_from_code(
          code = code,
          goal = state$goal,
          context = state$context,
          kind = kind,
          instruction = instruction,
          source_note = if (is.null(source_note)) NULL else list(note = source_note),
          rationale = rationale
        )
        candidate_id <- ggai_store_acquisition_candidate(
          state,
          acquired = acquired,
          source = "data_frame_code",
          rationale = rationale
        )
        ggai_acquisition_candidate_response(acquired, candidate_id)
      }
    ),
    commit_acquired_data = tool(
      name = "ggai_commit_acquired_data",
      description = "Commit a validated acquired data-frame candidate or named acquisition-session object as the data source for plotting.",
      parameters = z$z_object(
        candidate_id = z$z_string(description = "Candidate id returned by an acquisition attempt", nullable = TRUE),
        object_name = z$z_string(description = "Name of an aisdk acquisition-session object to validate and commit when no candidate id is supplied", nullable = TRUE),
        kind = z$z_string(description = "Short acquisition kind for an object_name commit", nullable = TRUE),
        instruction = z$z_string(description = "Visualization instruction for an object_name commit", nullable = TRUE),
        source_note = z$z_string(description = "Concise source/evidence note for an object_name commit", nullable = TRUE),
        completion_summary = z$z_string(description = "Why the acquired data frame is sufficient for the user goal"),
        remaining_risks = z$z_string(description = "Known limitations, missing data, or empty string when none", nullable = TRUE),
        .required = "completion_summary"
      ),
      execute = function(completion_summary,
                         candidate_id = NULL,
                         object_name = NULL,
                         kind = NULL,
                         instruction = NULL,
                         source_note = NULL,
                         remaining_risks = NULL) {
        acquired <- NULL
        if (!is.null(candidate_id) && nzchar(candidate_id)) {
          acquired <- state$candidates[[candidate_id]] %||% NULL
        }
        if (is.null(acquired) && !is.null(object_name) && nzchar(object_name)) {
          acquired <- ggai_acquisition_from_session_object(
            name = object_name,
            state = state,
            kind = kind,
            instruction = instruction,
            source_note = if (is.null(source_note)) NULL else list(note = source_note),
            rationale = completion_summary
          )
          candidate_id <- ggai_store_acquisition_candidate(
            state,
            acquired = acquired,
            source = "session_object",
            rationale = completion_summary
          )
        }
        if (is.null(acquired)) {
          ggai_agent_tool_abort("Provide a known `candidate_id` or a data-frame `object_name` from the acquisition session.")
        }
        acquired$trace <- utils::modifyList(
          acquired$trace %||% list(),
          list(
            committed = TRUE,
            candidate_id = candidate_id %||% acquired$trace$candidate_id %||% NULL,
            object_name = object_name %||% acquired$trace$object_name %||% NULL,
            completion_summary = completion_summary,
            remaining_risks = remaining_risks %||% "",
            committed_at = ggai_contract_timestamp()
          )
        )
        state$acquired <- acquired
        list(
          status = "committed",
          candidate_id = candidate_id,
          data_summary = acquired$data_summary,
          completion_summary = completion_summary,
          remaining_risks = remaining_risks %||% ""
        )
      }
    ),
    commit_reference_brief = tool(
      name = "ggai_commit_reference_brief",
      description = paste(
        "Commit a reference-only visual brief when the user wants a plot inspired by a reference, article, URL, or example but no original data frame can be acquired.",
        "Use this to continue toward a best-effort illustrative/template plot instead of blocking.",
        "Do not use it when the user explicitly requires exact source data or when a real data-frame candidate is available."
      ),
      parameters = z$z_object(
        visual_goal = z$z_string(description = "The concrete plot or visual style goal to hand to the plotting Agent"),
        reference_summary = z$z_string(description = "What is known about the reference, including access failures or visible style clues"),
        chart_type = z$z_string(description = "Likely chart type or 'unspecified'", nullable = TRUE),
        assumptions = z$z_string(description = "Newline-separated assumptions the plotting Agent must preserve", nullable = TRUE),
        source_note = z$z_string(description = "Concise source/evidence note for the session trace", nullable = TRUE),
        completion_summary = z$z_string(description = "Why a reference brief is enough to continue the user's task"),
        remaining_risks = z$z_string(description = "Known limitations, missing data, or empty string when none", nullable = TRUE),
        .required = c("visual_goal", "reference_summary", "completion_summary")
      ),
      execute = function(visual_goal,
                         reference_summary,
                         completion_summary,
                         chart_type = NULL,
                         assumptions = NULL,
                         source_note = NULL,
                         remaining_risks = NULL) {
        evidence <- unname(state$references %||% list())
        if (!length(evidence) && length(state$context$urls %||% list())) {
          evidence <- lapply(state$context$urls, function(url) {
            list(
              source_url = url,
              status = "url_reference_unavailable",
              summary = "The user supplied this URL, but no readable reference text was committed before the reference brief."
            )
          })
        }
        acquired <- ggai_acquisition_from_reference_brief(
          goal = state$goal,
          visual_goal = visual_goal,
          reference_summary = reference_summary,
          chart_type = chart_type,
          assumptions = assumptions,
          source_note = if (is.null(source_note)) {
            NULL
          } else {
            list(
              source = "reference_brief",
              note = source_note,
              policy = "best_effort_reference_continuation",
              original_data_available = FALSE
            )
          },
          evidence = evidence,
          completion_summary = completion_summary,
          remaining_risks = remaining_risks
        )
        acquired$trace <- utils::modifyList(
          acquired$trace %||% list(),
          list(
            mode = "reference_brief",
            reference_count = length(evidence),
            committed_at = ggai_contract_timestamp()
          )
        )
        state$reference_brief <- acquired$reference_brief
        state$acquired <- acquired
        list(
          status = "committed_reference_brief",
          data_summary = acquired$data_summary,
          visual_goal = visual_goal,
          completion_summary = completion_summary,
          remaining_risks = remaining_risks %||% "",
          next_action = "ggai will continue with the plotting Agent using seed data plus this reference brief."
        )
      }
    ),
    declare_acquisition_blocker = tool(
      name = "ggai_declare_acquisition_blocker",
      description = paste(
        "Declare that a data frame cannot be acquired under the current bounded tools, data access, and policy.",
        "Use this instead of repeating equivalent failed acquisition steps."
      ),
      parameters = z$z_object(
        reason = z$z_string(description = "Concise blocker reason"),
        evidence = z$z_string(description = "Observed attempts or constraints that support the blocker", nullable = TRUE),
        next_step = z$z_string(description = "What input, tool, or scope change would unblock acquisition", nullable = TRUE),
        .required = "reason"
      ),
      execute = function(reason, evidence = NULL, next_step = NULL) {
        state$blocker <- list(
          reason = reason,
          evidence = evidence %||% "",
          next_step = next_step %||% "",
          steps = state$steps %||% list(),
          candidates = names(state$candidates %||% list()),
          declared_at = ggai_contract_timestamp()
        )
        list(status = "blocker_declared", blocker = state$blocker)
      }
    )
  )
}

ggai_acquisition_system_prompt <- function() {
  paste(
    "You are ggai's controlled data acquisition agent.",
    "Use the provided bounded tools to inspect context, run configured tools, take progressive session steps, commit one validated data frame, commit a reference brief, or declare a blocker.",
    "The built-in ggai acquisition skill contains the default working style; follow it when available.",
    "Prefer real acquired data when the user needs factual values. When the task is to imitate a reference chart or create a tutorial/example and source data is unavailable, commit a reference brief so plotting can continue with explicit assumptions.",
    "For R code acquisition, use base R or explicit namespace calls, return a data frame or list(data=...), and include a source note.",
    "Do not install packages, call library/require, write files, delete files, call shell/system functions, or use unbounded crawlers.",
    sep = "\n"
  )
}

ggai_acquisition_prompt <- function(goal, manifest) {
  paste(
    "User acquisition and visualization goal:",
    goal,
    "",
    "Available controlled acquisition tools:",
    jsonlite::toJSON(manifest, auto_unbox = TRUE, null = "null", pretty = TRUE),
    "",
    "Use the tools and loaded skills to decide whether to inspect, run a step, commit a sufficient data frame, or declare a blocker.",
    "If exact source data cannot be acquired but the task can still be completed as an honest reference-inspired or tutorial template, commit a reference brief instead of blocking.",
    "The final ggai plotting agent will receive either a committed validated data frame or a reference brief with seed data and explicit assumptions.",
    sep = "\n"
  )
}

ggai_agentic_acquire_goal_data <- function(goal,
                                           tools,
                                           context,
                                           model,
                                           registry = NULL,
                                           skills = NULL,
                                           skill_registry = NULL,
                                           skill_path = NULL,
                                           max_steps = getOption("ggai.acquisition_max_steps", 100L)) {
  max_steps <- ggai_agentic_max_steps(max_steps)
  model <- ggai_language_model(model)
  state <- new.env(parent = emptyenv())
  state$goal <- goal
  state$tools <- tools
  state$context <- context
  state$acquisition_session <- ggai_new_acquisition_session(goal, context, model = model)
  state$steps <- list()
  state$candidates <- list()
  state$references <- list()
  state$reference_brief <- NULL
  state$acquired <- NULL
  state$blocker <- NULL
  agent_skill_paths <- ggai_agent_skill_paths(
    skills = skills,
    query = goal,
    skill_registry = skill_registry,
    skill_path = skill_path,
    builtin_skills = "ggai-acquisition-agent"
  )

  agent <- ggai_aisdk("create_agent")(
    name = "ggai_data_acquisition_router",
    description = "Routes natural-language data acquisition goals to controlled tools.",
    system_prompt = ggai_acquisition_system_prompt(),
    tools = ggai_acquisition_agent_tools(state),
    skills = agent_skill_paths,
    model = model
  )
  run_args <- c(
    list(
      task = ggai_acquisition_prompt(goal, ggai_acquisition_manifest(tools)),
      session = state$acquisition_session,
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

  if (is.null(state$acquired)) {
    candidate_id <- ggai_select_acquisition_auto_commit_candidate(state)
    if (!is.null(candidate_id) && isTRUE(getOption("ggai.acquisition_auto_commit_valid_candidates", TRUE))) {
      acquired <- state$candidates[[candidate_id]]
      acquired$trace <- utils::modifyList(
        acquired$trace %||% list(),
        list(
          committed = TRUE,
          auto_committed = TRUE,
          completion_summary = "Runtime auto-committed a validated acquired data-frame candidate after the Agent stopped before calling ggai_commit_acquired_data.",
          remaining_risks = "The candidate validated as a data frame; semantic fit is based on the best available acquisition candidate.",
          committed_at = ggai_contract_timestamp()
        )
      )
      state$acquired <- acquired
    }
  }

  if (!is.null(state$acquired)) {
    state$acquired$trace <- utils::modifyList(
      state$acquired$trace %||% list(),
      list(
        mode = "aisdk_agent",
        model = if (inherits(model, "LanguageModelV1")) model$model_id %||% NULL else model,
        steps = state$steps %||% list(),
        session_trace_summary = state$acquisition_session$trace_summary(),
        tool_calls = if (inherits(result, "error")) {
          list()
        } else {
          ggai_compact_tool_events(result$all_tool_calls %||% list())
        },
        tool_results = if (inherits(result, "error")) {
          list()
        } else {
          ggai_compact_tool_events(result$all_tool_results %||% list())
        }
      )
    )
    return(state$acquired)
  }

  ggai_acquisition_abort(
    goal,
    paste0("No acquisition candidate returned a committed data frame after ", max_steps, " Agent step(s)."),
    details = list(
      available_tools = names(tools),
      candidates = names(state$candidates %||% list()),
      blocker = state$blocker %||% NULL,
      runtime_error = if (inherits(result, "error")) ggai_strip_ansi(conditionMessage(result)) else NULL
    )
  )
}

ggai_deterministic_acquire_goal_data <- function(goal, tools, context) {
  eligible <- ggai_acquisition_eligible_tools(tools, goal, context)
  if (!length(eligible)) {
    ggai_acquisition_abort(
      goal,
      "No configured acquisition tool declared that it can handle this goal.",
      details = list(available_tools = names(tools))
    )
  }
  if (length(eligible) > 1L) {
    ggai_acquisition_abort(
      goal,
      "Multiple acquisition tools are eligible; pass a model so the Agent can choose, or narrow each tool's `can_handle` predicate.",
      details = list(available_tools = names(eligible))
    )
  }
  ggai_run_acquisition_tool(eligible[[1]], goal = goal, context = context)
}

ggai_acquire_goal_data <- function(goal,
                                   model = NULL,
                                   registry = NULL,
                                   acquisition_tools = NULL,
                                   skills = NULL,
                                   skill_registry = NULL,
                                   skill_path = NULL,
                                   max_steps = getOption("ggai.acquisition_max_steps", 100L)) {
  if (!is.character(goal) || length(goal) != 1L || !nzchar(goal)) {
    rlang::abort("`goal` must be a non-empty natural-language request.")
  }

  tools <- ggai_acquisition_tools(acquisition_tools)
  context <- ggai_acquisition_context(goal)
  acquisition_model <- model
  if (is.null(acquisition_model) &&
      isTRUE(getOption("ggai.acquisition_use_default_model", TRUE)) &&
      ggai_aisdk_runtime_available()) {
    acquisition_model <- ggai_default_models()$language
  }
  if (ggai_acquisition_model_enabled(acquisition_model)) {
    return(ggai_agentic_acquire_goal_data(
      goal = goal,
      tools = tools,
      context = context,
      model = acquisition_model,
      registry = registry,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path,
      max_steps = max_steps
    ))
  }

  if (!length(tools)) {
    ggai_acquisition_abort(
      goal,
      "No controlled acquisition tools are configured for natural-language-only requests."
    )
  }

  ggai_deterministic_acquire_goal_data(goal = goal, tools = tools, context = context)
}
