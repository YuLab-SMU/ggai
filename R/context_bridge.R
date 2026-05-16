ggai_context_session_supported <- function() {
  ggai_aisdk_has("create_shared_session")
}

ggai_create_context_session <- function(model = NULL, trace_enabled = TRUE) {
  if (!ggai_context_session_supported()) {
    return(NULL)
  }

  session <- tryCatch(
    ggai_aisdk("create_shared_session")(
      model = model,
      sandbox_mode = "permissive",
      trace_enabled = trace_enabled
    ),
    error = function(...) NULL
  )
  if (is.null(session)) {
    return(NULL)
  }

  if (is.function(session$set_context_management_config)) {
    tryCatch(
      session$set_context_management_config(mode = "adaptive"),
      error = function(...) NULL
    )
  } else if (is.function(session$set_context_management_mode)) {
    tryCatch(
      session$set_context_management_mode("adaptive"),
      error = function(...) NULL
    )
  }

  session
}

ggai_context_safe_name <- function(name) {
  name <- as.character(name %||% "")
  name <- gsub("[^A-Za-z0-9_.]+", "_", name, perl = TRUE)
  name <- gsub("_+", "_", name, perl = TRUE)
  name <- sub("^_+", "", sub("_+$", "", name))
  if (!nzchar(name) || grepl("^[0-9]", name)) {
    name <- paste0("ggai_object_", name)
  }
  name
}

ggai_context_set_var <- function(session, name, value, scope = "global") {
  if (is.null(session) || !inherits(session, "ChatSession")) {
    return(invisible(FALSE))
  }

  safe_name <- ggai_context_safe_name(name)
  if (is.function(session$set_var)) {
    tryCatch(
      {
        session$set_var(safe_name, value, scope = scope)
        return(invisible(TRUE))
      },
      error = function(...) NULL
    )
  }

  env <- tryCatch(session$get_envir(), error = function(...) NULL)
  if (is.environment(env)) {
    assign(safe_name, value, envir = env)
    return(invisible(TRUE))
  }

  invisible(FALSE)
}

ggai_context_set_memory <- function(session, key, value) {
  if (is.null(session) || !inherits(session, "ChatSession") || !is.function(session$set_memory)) {
    return(invisible(FALSE))
  }
  tryCatch(
    {
      session$set_memory(key, value)
      invisible(TRUE)
    },
    error = function(...) invisible(FALSE)
  )
}

ggai_register_context_objects <- function(session,
                                          mentions = list(),
                                          data = NULL,
                                          plot = NULL,
                                          ggai_session = NULL,
                                          instruction = NULL) {
  if (is.null(session) || !inherits(session, "ChatSession")) {
    return(invisible(session))
  }

  registered <- list()
  for (mention in mentions %||% list()) {
    if (!isTRUE(mention$resolved) || is.null(mention$value)) {
      next
    }
    var_name <- ggai_context_safe_name(mention$name)
    ggai_context_set_var(session, var_name, mention$value)
    registered[[length(registered) + 1L]] <- list(
      mention = mention$name,
      variable = var_name,
      kind = mention$kind,
      class = class(mention$value)
    )
  }

  if (!is.null(data)) {
    ggai_context_set_var(session, "data", data)
    registered[[length(registered) + 1L]] <- list(
      mention = NULL,
      variable = "data",
      kind = "data",
      class = class(data)
    )
  }
  if (inherits(plot, "ggplot")) {
    ggai_context_set_var(session, "current_plot", plot)
    ggai_context_set_var(session, "p", plot)
    registered[[length(registered) + 1L]] <- list(
      mention = NULL,
      variable = "current_plot",
      kind = "ggplot",
      class = class(plot)
    )
  }
  if (inherits(ggai_session, "ggai_session")) {
    ggai_context_set_var(session, "ggai_session", ggai_session)
    ggai_context_set_memory(session, "ggai_session_context", session_context_snapshot(ggai_session))
  }
  if (!is.null(instruction) && nzchar(instruction)) {
    ggai_context_set_memory(session, "ggai_instruction", instruction)
  }

  ggai_context_set_memory(session, "ggai_registered_context", registered)
  invisible(session)
}

ggai_context_tool_names <- function(tools) {
  vapply(tools %||% list(), function(tool) tool$name %||% "", character(1))
}

ggai_append_unique_tool_objects <- function(tools, extra_tools) {
  tools <- tools %||% list()
  extra_tools <- extra_tools %||% list()
  existing <- ggai_context_tool_names(tools)

  for (extra in extra_tools) {
    name <- extra$name %||% ""
    if (!nzchar(name) || name %in% existing) {
      next
    }
    key <- name
    if (key %in% names(tools)) {
      key <- paste0("aisdk_", key)
    }
    tools[[key]] <- extra
    existing <- c(existing, name)
  }

  tools
}

ggai_aisdk_context_tools <- function(session = NULL) {
  tools <- list()

  if (ggai_aisdk_has("create_r_context_tools")) {
    tools <- ggai_append_unique_tool_objects(
      tools,
      tryCatch(ggai_aisdk("create_r_context_tools")(), error = function(...) list())
    )
  }

  if (!is.null(session) &&
      inherits(session, "ChatSession") &&
      ggai_aisdk_has("create_context_query_tools")) {
    tools <- ggai_append_unique_tool_objects(
      tools,
      tryCatch(ggai_aisdk("create_context_query_tools")(session), error = function(...) list())
    )
  }

  tools
}

