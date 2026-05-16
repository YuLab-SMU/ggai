ggai_agent_tool_abort <- function(message) {
  rlang::abort(message, class = "ggai_agent_tool_error")
}

ggai_agent_tool_data <- function(data = NULL, plot = NULL) {
  if (is.data.frame(data)) {
    return(data)
  }
  if (inherits(plot, "ggplot") && is.data.frame(plot$data)) {
    return(plot$data)
  }
  ggai_agent_tool_abort("A data frame is required for this ggai agent tool.")
}

ggai_agent_tool_plot <- function(plot = NULL, session = NULL) {
  if (inherits(plot, "ggplot")) {
    return(plot)
  }
  if (inherits(session, "ggai_session")) {
    return(session_current_plot(session))
  }
  ggai_agent_tool_abort("A ggplot or ggai_session is required for this ggai agent tool.")
}

ggai_agent_profile_column <- function(x) {
  out <- list(
    class = class(x)[[1]],
    missing = sum(is.na(x)),
    unique = length(unique(x))
  )

  if (is.numeric(x)) {
    values <- x[!is.na(x)]
    out$summary <- if (length(values)) {
      list(
        min = min(values),
        median = stats::median(values),
        mean = mean(values),
        max = max(values)
      )
    } else {
      list()
    }
  } else {
    values <- unique(as.character(x[!is.na(x)]))
    out$sample_values <- utils::head(values, 10)
  }

  out
}

ggai_agent_profile_data <- function(data, columns = NULL, include_preview = FALSE, preview_n = 5) {
  if (!is.null(columns)) {
    missing <- setdiff(columns, names(data))
    if (length(missing)) {
      ggai_agent_tool_abort(paste0("Unknown data columns: ", paste(missing, collapse = ", ")))
    }
    data <- data[, columns, drop = FALSE]
  }

  out <- list(
    nrow = nrow(data),
    ncol = ncol(data),
    names = names(data),
    columns = lapply(data, ggai_agent_profile_column)
  )

  if (isTRUE(include_preview)) {
    preview_n <- max(0L, as.integer(preview_n %||% 5L))
    out$preview <- utils::head(data, preview_n)
  }

  out
}

ggai_agent_validate_plot <- function(plot) {
  warnings <- character()
  messages <- character()
  result <- tryCatch(
    withCallingHandlers(
      {
        ggplot2::ggplot_build(plot)
        ggplot2::ggplotGrob(plot)
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    return(list(
      status = "error",
      message = ggai_strip_ansi(conditionMessage(result)),
      warnings = warnings,
      messages = messages
    ))
  }

  list(
    status = "ok",
    layer_count = length(plot$layers %||% list()),
    warnings = warnings,
    messages = messages
  )
}

ggai_agent_empty_parameters <- function() {
  z <- ggai_schema_funs()
  z$z_object(
    noop = z$z_string(
      description = "Optional ignored field for tools that do not need inputs",
      nullable = TRUE
    )
  )
}

ggai_agent_tools_state <- function(data = NULL, plot = NULL, session = NULL) {
  state <- new.env(parent = emptyenv())
  state$data <- data
  state$plot <- plot
  state$session <- session
  state
}

#' Create ggai agent tool wrappers
#'
#' @param data Optional data frame available to data profiling tools.
#' @param plot Optional ggplot available to plot and compile tools.
#' @param session Optional `ggai_session` available to session tools.
#' @param model Optional model override for compiler tools.
#' @param registry Optional aisdk provider registry for compiler tools.
#' @param package_policy Optional package installation policy.
#' @param skills Optional skill names, paths, Skill objects, or inline skill lists.
#' @param skill_registry Optional aisdk SkillRegistry.
#' @param skill_path Optional path scanned into an aisdk SkillRegistry.
#' @param context_session Optional aisdk ChatSession/SharedSession used for
#'   upstream R context and semantic inspection tools.
#'
#' @return A named list of `aisdk` tool objects.
#' @export
create_ggai_agent_tools <- function(data = NULL,
                                    plot = NULL,
                                    session = NULL,
                                    model = NULL,
                                    registry = NULL,
                                    package_policy = NULL,
                                    skills = NULL,
                                    skill_registry = NULL,
                                    skill_path = NULL,
                                    context_session = NULL) {
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")
  state <- ggai_agent_tools_state(data = data, plot = plot, session = session)

  tools <- list(
    data_profile = tool(
      name = "ggai_data_profile",
      description = "Profile the local data frame available to the ggai runtime.",
      parameters = z$z_object(
        columns = z$z_array(
          z$z_string(description = "Column name"),
          description = "Optional subset of columns to profile",
          nullable = TRUE
        ),
        include_preview = z$z_boolean(
          description = "Whether to include a small data preview",
          nullable = TRUE,
          default = FALSE
        ),
        preview_n = z$z_number(
          description = "Number of rows to include when preview is enabled",
          nullable = TRUE,
          default = 5
        )
      ),
      execute = function(columns = NULL, include_preview = FALSE, preview_n = 5) {
        ggai_agent_profile_data(
          ggai_agent_tool_data(state$data, state$plot),
          columns = columns,
          include_preview = include_preview,
          preview_n = preview_n
        )
      }
    ),
    plot_inspection = tool(
      name = "ggai_plot_inspection",
      description = "Inspect the local ggplot context, mappings, layers, and recorded ggai specs.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        p <- ggai_agent_tool_plot(state$plot, state$session)
        list(
          plot_context = build_plot_context(p),
          spec_history = tryCatch(spec_history(p), error = function(...) data.frame())
        )
      }
    ),
    session_inspection = tool(
      name = "ggai_session_inspection",
      description = "Inspect the current ggai session context.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        if (!inherits(state$session, "ggai_session")) {
          ggai_agent_tool_abort("A ggai_session is required for session inspection.")
        }
        session_context_snapshot(state$session)
      }
    ),
    stat_method_selection = tool(
      name = "ggai_stat_method_selection",
      description = "Select a deterministic statistical method for the local data and return evidence.",
      parameters = z$z_object(
        goal = z$z_string(
          description = "Analysis goal used to prioritize variables and method family",
          nullable = TRUE
        )
      ),
      execute = function(goal = NULL) {
        data <- ggai_agent_tool_data(state$data, state$plot)
        list(
          profile = ggai_stat_profile(data, goal = goal),
          method_selection = ggai_select_stat_method(data, goal = goal)
        )
      }
    ),
    package_check = tool(
      name = "ggai_package_check",
      description = "Check whether a local R package is available and record the action in session trace.",
      parameters = z$z_object(
        package = z$z_string(description = "Package name"),
        .required = "package"
      ),
      execute = function(package) {
        result <- ggai_check_package(package, session = state$session)
        state$session <- result$session
        result$session <- NULL
        result
      }
    ),
    package_install = tool(
      name = "ggai_package_install",
      description = "Handle a CRAN package install request according to ggai package policy.",
      parameters = z$z_object(
        package = z$z_string(description = "Package name"),
        policy = z$z_enum(
          values = c("ask", "auto_cran", "never"),
          description = "Package installation policy",
          nullable = TRUE
        ),
        .required = "package"
      ),
      execute = function(package, policy = NULL) {
        result <- ggai_install_cran_package(
          package,
          policy = policy %||% package_policy,
          session = state$session
        )
        state$session <- result$session
        result$session <- NULL
        result
      }
    ),
    help_inspection = tool(
      name = "ggai_help_inspection",
      description = "Inspect local R help for an installed package topic.",
      parameters = z$z_object(
        package = z$z_string(description = "Package name"),
        topic = z$z_string(description = "Help topic", nullable = TRUE),
        .required = "package"
      ),
      execute = function(package, topic = NULL) {
        ggai_inspect_help(package, topic = topic %||% package)
      }
    ),
    examples_inspection = tool(
      name = "ggai_examples_inspection",
      description = "Inspect local R examples for an installed package topic.",
      parameters = z$z_object(
        package = z$z_string(description = "Package name"),
        topic = z$z_string(description = "Example topic", nullable = TRUE),
        .required = "package"
      ),
      execute = function(package, topic = NULL) {
        ggai_inspect_examples(package, topic = topic %||% package)
      }
    ),
    vignette_index = tool(
      name = "ggai_vignette_index",
      description = "List locally installed vignettes for an R package.",
      parameters = z$z_object(
        package = z$z_string(description = "Package name"),
        .required = "package"
      ),
      execute = function(package) {
        ggai_vignette_index(package)
      }
    ),
    source_url_detection = tool(
      name = "ggai_source_url_detection",
      description = "Detect URLs and GitHub repository references in local text.",
      parameters = z$z_object(
        text = z$z_string(description = "Text to scan for URLs"),
        .required = "text"
      ),
      execute = function(text) {
        ggai_detect_source_urls(text)
      }
    ),
    github_inspection = tool(
      name = "ggai_github_inspection",
      description = "Inspect a GitHub repository URL without live network access.",
      parameters = z$z_object(
        url = z$z_string(description = "GitHub repository URL"),
        .required = "url"
      ),
      execute = function(url) {
        ggai_inspect_github_url(url)
      }
    ),
    local_file_listing = tool(
      name = "ggai_local_file_listing",
      description = "List bounded local source files under a root directory.",
      parameters = z$z_object(
        root = z$z_string(description = "Root directory", nullable = TRUE),
        pattern = z$z_string(description = "Optional regex pattern", nullable = TRUE),
        max_files = z$z_number(description = "Maximum files to return", nullable = TRUE, default = 100)
      ),
      execute = function(root = ".", pattern = NULL, max_files = 100) {
        ggai_list_local_files(root = root, pattern = pattern, max_files = max_files)
      }
    ),
    local_file_reading = tool(
      name = "ggai_local_file_reading",
      description = "Read a bounded local source file under a root directory.",
      parameters = z$z_object(
        path = z$z_string(description = "Path relative to root"),
        root = z$z_string(description = "Root directory", nullable = TRUE),
        max_lines = z$z_number(description = "Maximum lines to return", nullable = TRUE, default = 200),
        .required = "path"
      ),
      execute = function(path, root = ".", max_lines = 200) {
        ggai_read_local_file(path = path, root = root, max_lines = max_lines)
      }
    ),
    source_summary = tool(
      name = "ggai_source_summary",
      description = "Summarize source evidence records.",
      parameters = z$z_object(
        evidence = z$z_any(description = "Evidence record or list of evidence records"),
        .required = "evidence"
      ),
      execute = function(evidence) {
        ggai_summarize_sources(evidence)
      }
    ),
    diagram_compilation = tool(
      name = "ggai_diagram_compilation",
      description = "Compile a natural-language instruction into a ggai diagram scene spec.",
      parameters = z$z_object(
        instruction = z$z_string(description = "Natural-language diagram instruction"),
        scene_context = z$z_any_object(description = "Optional scene context"),
        .required = "instruction"
      ),
      execute = function(instruction, scene_context = list()) {
        spec <- compile_diagram_spec(
          instruction = instruction,
          scene_context = scene_context %||% list(),
          model = model,
          registry = registry,
          skills = skills,
          skill_registry = skill_registry,
          skill_path = skill_path
        )
        compiled <- new_compiled_spec(
          spec = spec,
          kind = "diagram",
          instruction = instruction,
          context = scene_context %||% list()
        )
        list(
          summary = inspect_spec(compiled, raw = FALSE),
          spec = inspect_spec(compiled, raw = TRUE)
        )
      }
    ),
    plot_validation = tool(
      name = "ggai_plot_validation",
      description = "Build and validate the current ggplot object.",
      parameters = ggai_agent_empty_parameters(),
      execute = function(noop = NULL) {
        ggai_agent_validate_plot(ggai_agent_tool_plot(state$plot, state$session))
      }
    ),
    artifact_recording = tool(
      name = "ggai_artifact_recording",
      description = "Record an artifact in the current ggai session.",
      parameters = z$z_object(
        kind = z$z_string(description = "Artifact kind"),
        instruction = z$z_string(description = "Instruction associated with the artifact", nullable = TRUE),
        artifact_path = z$z_string(description = "Local artifact path", nullable = TRUE),
        status = z$z_string(description = "Artifact status", nullable = TRUE),
        metadata = z$z_any_object(description = "Additional artifact metadata"),
        .required = "kind"
      ),
      execute = function(kind, instruction = NULL, artifact_path = NULL, status = NULL, metadata = list()) {
        if (!inherits(state$session, "ggai_session")) {
          ggai_agent_tool_abort("A ggai_session is required for artifact recording.")
        }
        artifact <- list(
          kind = kind,
          instruction = instruction,
          artifact_path = artifact_path,
          status = status %||% "recorded",
          metadata = metadata %||% list(),
          timestamp = ggai_contract_timestamp(),
          turn = ggai_session_state(state$session)$current_turn %||% 0L
        )
        state$session <- session_record_artifact(state$session, artifact)
        list(
          artifact = artifact,
          artifact_count = length(session_artifact_log(state$session))
        )
      }
    )
  )

  if (!is.null(context_session) && inherits(context_session, "ChatSession")) {
    tools <- ggai_append_unique_tool_objects(
      tools,
      ggai_aisdk_context_tools(context_session)
    )
  }

  attr(tools, "state") <- state
  tools
}
