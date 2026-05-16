ggai_column_aliases <- function() {
  list(
    mpg = c("fuel efficiency", "mileage", "miles per gallon", "mpg"),
    wt = c("weight", "wt"),
    cyl = c("cylinders", "cylinder", "cyl"),
    hp = c("horsepower", "hp"),
    disp = c("displacement", "disp"),
    drat = c("rear axle ratio", "drat"),
    qsec = c("quarter mile", "qsec"),
    vs = c("engine shape", "vs"),
    am = c("transmission", "am"),
    gear = c("gears", "gear"),
    carb = c("carburetors", "carburettors", "carb")
  )
}

ggai_match_column_reference <- function(text, names) {
  if (is.null(text) || !nzchar(text)) {
    return(NULL)
  }
  text <- tolower(text)
  lower_names <- tolower(names)
  tokens <- strsplit(text, "[^[:alnum:]_.]+", perl = TRUE)[[1]]
  tokens <- tokens[nzchar(tokens)]

  for (i in seq_along(names)) {
    if (lower_names[[i]] %in% tokens) {
      return(names[[i]])
    }
  }

  aliases <- ggai_column_aliases()
  for (name in names) {
    terms <- aliases[[tolower(name)]] %||% character()
    for (term in terms) {
      if (grepl(term, text, fixed = TRUE)) {
        return(name)
      }
    }
  }

  NULL
}

ggai_instruction_roles <- function(instruction, names) {
  text <- tolower(instruction %||% "")
  if (!nzchar(text)) {
    return(list())
  }

  roles <- list()
  parts <- strsplit(text, "\\bvs\\b|\\bversus\\b|\\bagainst\\b", perl = TRUE)[[1]]
  if (length(parts) >= 2L) {
    y_col <- ggai_match_column_reference(parts[[1]], names)
    x_text <- sub("\\b(colou?r|group|fill)\\s+by\\s+.*$", "", parts[[2]], perl = TRUE)
    x_col <- ggai_match_column_reference(x_text, names)
    if (!is.null(x_col)) roles$x <- x_col
    if (!is.null(y_col)) roles$y <- y_col
  }

  colour_match <- regexec("\\b(colou?r|group|fill)\\s+by\\s+([^,.;]+)", text, perl = TRUE)
  colour_parts <- regmatches(text, colour_match)[[1]]
  if (length(colour_parts) >= 3L) {
    colour_col <- ggai_match_column_reference(colour_parts[[3]], names)
    if (!is.null(colour_col)) {
      roles$colour <- colour_col
    }
  }

  roles
}

infer_column_roles <- function(data, instruction = NULL) {
  nms <- names(data)
  is_num <- vapply(data, is.numeric, logical(1))
  numeric_cols <- nms[is_num]
  discrete_cols <- nms[!is_num]
  first_or_null <- function(x) if (length(x)) x[[1]] else NULL

  roles <- list(
    x = first_or_null(numeric_cols) %||% nms[[1]],
    y = (if (length(numeric_cols) >= 2) numeric_cols[[2]] else NULL) %||% first_or_null(numeric_cols) %||% nms[[min(2, length(nms))]],
    colour = first_or_null(discrete_cols)
  )
  utils::modifyList(roles, ggai_instruction_roles(instruction, nms))
}

summarize_data_context <- function(data) {
  list(
    nrow = nrow(data),
    ncol = ncol(data),
    names = names(data),
    classes = stats::setNames(vapply(data, function(x) class(x)[1], character(1)), names(data))
  )
}

ggai_prompt_mention_tokens <- function(text) {
  matches <- gregexpr("@[^[:space:]]+", text %||% "", perl = TRUE)[[1]]
  if (identical(matches[[1]], -1L)) {
    return(character())
  }
  tokens <- regmatches(text, list(matches))[[1]]
  tokens <- sub("^@", "", tokens)
  tokens <- sub("[,.;:!?\\)\\]\\}]+$", "", tokens, perl = TRUE)
  unique(tokens[nzchar(tokens)])
}

ggai_prompt_mention_summary <- function(name, value = NULL, kind = "unresolved", resolved = FALSE) {
  list(
    name = name,
    kind = kind,
    resolved = isTRUE(resolved),
    value = value
  )
}

ggai_resolve_prompt_mention <- function(token, env) {
  if (grepl("^(/|~|\\.)", token) && file.exists(path.expand(token))) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "local_file",
      resolved = TRUE,
      value = normalizePath(path.expand(token), mustWork = TRUE)
    ))
  }

  if (!exists(token, envir = env, inherits = TRUE)) {
    return(ggai_prompt_mention_summary(name = token))
  }

  value <- get(token, envir = env, inherits = TRUE)
  if (is.data.frame(value)) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "data_frame",
      resolved = TRUE,
      value = value
    ))
  }
  if (inherits(value, "ggai_session")) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "ggai_session",
      resolved = TRUE,
      value = value
    ))
  }
  if (inherits(value, "ggplot")) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "ggplot",
      resolved = TRUE,
      value = value
    ))
  }
  if (is.character(value) && length(value) == 1L && nzchar(value)) {
    expanded <- path.expand(value)
    if (file.exists(expanded)) {
      return(ggai_prompt_mention_summary(
        name = token,
        kind = "local_file",
        resolved = TRUE,
        value = normalizePath(expanded, mustWork = TRUE)
      ))
    }
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "character",
      resolved = TRUE,
      value = value
    ))
  }

  ggai_prompt_mention_summary(
    name = token,
    kind = paste(class(value), collapse = "/"),
    resolved = TRUE,
    value = value
  )
}

ggai_resolve_prompt_mentions <- function(text, env) {
  tokens <- ggai_prompt_mention_tokens(text)
  if (!length(tokens)) {
    return(list())
  }
  lapply(tokens, ggai_resolve_prompt_mention, env = env)
}

ggai_image_file_extension <- function(path) {
  tolower(tools::file_ext(path %||% "")) %in% c("png", "jpg", "jpeg", "gif", "webp", "bmp", "tif", "tiff")
}

ggai_extract_local_image_references <- function(text) {
  text <- text %||% ""
  if (!nzchar(text)) {
    return(character())
  }
  matches <- gregexpr("(~|/|\\.)[^[:space:]`'\"，。；;:,)\\]}]+\\.(png|jpe?g|gif|webp|bmp|tiff?)", text, ignore.case = TRUE, perl = TRUE)[[1]]
  if (identical(matches[[1]], -1L)) {
    return(character())
  }
  refs <- regmatches(text, list(matches))[[1]]
  refs <- sub("[,.;:!?，。；：！？]+$", "", refs, perl = TRUE)
  refs <- path.expand(refs)
  refs <- refs[file.exists(refs) & ggai_image_file_extension(refs)]
  unique(normalizePath(refs, mustWork = TRUE))
}

ggai_image_references_from_mentions <- function(mentions) {
  refs <- character()
  for (mention in mentions) {
    if (isTRUE(mention$resolved) &&
        identical(mention$kind, "local_file") &&
        ggai_image_file_extension(mention$value %||% "")) {
      refs <- c(refs, mention$value)
    }
  }
  unique(normalizePath(refs, mustWork = TRUE))
}

ggai_prompt_image_references <- function(text, mentions = list()) {
  unique(c(
    ggai_extract_local_image_references(text),
    ggai_image_references_from_mentions(mentions)
  ))
}

ggai_mention_context_lines <- function(mentions) {
  lines <- character()
  for (mention in mentions) {
    label <- paste0("@", mention$name)
    if (!isTRUE(mention$resolved)) {
      lines <- c(lines, paste0("- ", label, ": unresolved mention."))
    } else if (identical(mention$kind, "data_frame")) {
      data <- mention$value
      lines <- c(lines, paste0(
        "- ", label, ": data frame with ", nrow(data), " rows, ",
        ncol(data), " columns; columns: ",
        paste(utils::head(names(data), 20L), collapse = ", "),
        if (length(names(data)) > 20L) ", ..." else "",
        "."
      ))
    } else if (identical(mention$kind, "local_file")) {
      lines <- c(lines, paste0("- ", label, ": local file path `", mention$value, "`."))
    } else if (identical(mention$kind, "character")) {
      lines <- c(lines, paste0("- ", label, ": character value `", mention$value, "`."))
    } else if (identical(mention$kind, "ggplot")) {
      lines <- c(lines, paste0("- ", label, ": ggplot object available in the caller environment."))
    } else if (identical(mention$kind, "ggai_session")) {
      lines <- c(lines, paste0("- ", label, ": ggai_session object available in the caller environment."))
    } else {
      lines <- c(lines, paste0("- ", label, ": R object of class ", mention$kind, "."))
    }
  }
  lines
}

ggai_instruction_with_mentions <- function(text, instruction = NULL, mentions = list()) {
  base <- text
  if (!is.null(instruction) && nzchar(instruction)) {
    base <- paste(base, instruction, sep = "\n\nAdditional instruction:\n")
  }
  if (!length(mentions)) {
    return(base)
  }
  paste(
    base,
    "",
    "Mention context resolved by ggai before the Agent run:",
    paste(ggai_mention_context_lines(mentions), collapse = "\n"),
    "",
    "Use mentioned data frames as user-provided data. Treat mentioned files as reference or source context according to the user's wording and relevant skills.",
    sep = "\n"
  )
}

ggai_primary_data_mention <- function(mentions) {
  for (mention in mentions) {
    if (isTRUE(mention$resolved) && identical(mention$kind, "data_frame")) {
      return(mention)
    }
  }
  NULL
}

ggai_mention_metadata <- function(mentions) {
  lapply(mentions, function(mention) {
    out <- list(
      name = mention$name,
      kind = mention$kind,
      resolved = isTRUE(mention$resolved)
    )
    if (identical(mention$kind, "data_frame")) {
      data <- mention$value
      out$data <- summarize_data_context(data)
    } else if (identical(mention$kind, "local_file") || identical(mention$kind, "character")) {
      out$value <- mention$value
    } else if (isTRUE(mention$resolved) && !is.null(mention$value)) {
      out$class <- class(mention$value)
      out$size <- format(utils::object.size(mention$value), units = "auto")
    }
    out
  })
}

infer_plot_instruction <- function(data, instruction = NULL) {
  roles <- infer_column_roles(data, instruction = instruction)
  if (!is.null(instruction) && nzchar(instruction)) {
    return(list(instruction = instruction, roles = roles))
  }

  geom <- if (!is.null(roles$colour)) "scatter" else "scatter"
  inferred <- paste(
    geom,
    roles$x,
    "vs",
    roles$y,
    if (!is.null(roles$colour)) paste(", color by", roles$colour) else ""
  )
  list(instruction = inferred, roles = roles)
}

infer_chart_type <- function(data, instruction = NULL, roles = infer_column_roles(data)) {
  text <- tolower(trimws(instruction %||% ""))

  if (grepl("histogram|distribution|hist", text)) return("histogram")
  if (grepl("boxplot|box plot|compare .* across|grouped distribution", text)) return("boxplot")
  if (grepl("bar chart|bar plot|count of|counts by|frequency of", text)) return("bar")
  if (grepl("line chart|line plot|trend|over time|timeseries|time series", text)) return("line")
  if (grepl("scatter|vs|relationship|correlation", text)) return("scatter")

  if (!is.null(roles$colour)) return("scatter")
  if (!is.null(roles$x) && !is.null(roles$y)) return("scatter")
  "histogram"
}

build_initial_ggplot <- function(data, chart_type, roles) {
  if (identical(chart_type, "histogram")) {
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = !!rlang::sym(roles$x))) +
        ggplot2::geom_histogram(bins = 30)
    )
  }

  if (identical(chart_type, "boxplot")) {
    x_col <- roles$colour %||% roles$x
    y_col <- roles$y %||% roles$x
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = factor(!!rlang::sym(x_col)), y = !!rlang::sym(y_col), fill = factor(!!rlang::sym(x_col)))) +
        ggplot2::geom_boxplot()
    )
  }

  if (identical(chart_type, "bar")) {
    x_col <- roles$colour %||% roles$x
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = factor(!!rlang::sym(x_col)), fill = factor(!!rlang::sym(x_col)))) +
        ggplot2::geom_bar()
    )
  }

  if (identical(chart_type, "line")) {
    mapping <- ggplot2::aes(x = !!rlang::sym(roles$x), y = !!rlang::sym(roles$y))
    return(ggplot2::ggplot(data, mapping) + ggplot2::geom_line())
  }

  mapping <- list(x = rlang::sym(roles$x), y = rlang::sym(roles$y))
  if (!is.null(roles$colour)) {
    mapping$colour <- rlang::expr(factor(!!rlang::sym(roles$colour)))
  }
  ggplot2::ggplot(data, do.call(ggplot2::aes, mapping)) + ggplot2::geom_point()
}

build_initial_plot <- function(data, instruction = NULL) {
  inferred <- infer_plot_instruction(data, instruction = instruction)
  roles <- inferred$roles
  chart_type <- infer_chart_type(data, instruction = instruction, roles = roles)
  plot <- build_initial_ggplot(data, chart_type = chart_type, roles = roles)
  list(plot = plot, inferred_instruction = inferred$instruction, roles = roles)
}

build_local_default_session <- function(data, instruction = NULL) {
  built <- build_initial_plot(data, instruction = NULL)
  session <- start_ggai_session(built$plot)
  session <- session_record_turn_note(
    session,
    type = "ggai_init",
    value = list(
      source = "data.frame",
      instruction = instruction %||% built$inferred_instruction,
      initialization = "local_default",
      data_context = summarize_data_context(data)
    )
  )
  session_touch_state(session, instruction = instruction %||% built$inferred_instruction)
}

build_agentic_initial_session <- function(data,
                                          instruction,
                                          model,
                                          registry = NULL,
                                          skills = NULL,
                                          skill_registry = NULL,
                                          skill_path = NULL) {
  base_plot <- ggplot2::ggplot(data = data)
  session <- start_ggai_session(base_plot)
  artifact <- ggai_agentic_repair_edit(
    compiled = NULL,
    base_plot = base_plot,
    current_plot = base_plot,
    data = data,
    instruction = instruction,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path,
    context_mentions = attr(data, "ggai_prompt_mentions") %||% list(),
    prior_error = NULL
  )
  compiled <- artifact$compiled
  rendered <- artifact$plot
  entry <- new_session_entry(
    instruction = instruction,
    compiled_spec = compiled,
    plot = rendered,
    code = as_code(compiled),
    edit_mode = compiled$meta$edit_mode %||% "agentic_code_edit",
    parent_turn = 0L,
    turn_context = list(mode = "initial_agentic", context = session_context_snapshot(session))
  )
  session <- session_append_entry(session, entry)
  session <- session_record_agent_trace(
    session,
    ggai_edit_runtime_trace(
      instruction = instruction,
      edit_mode = compiled$meta$edit_mode %||% "agentic_code_edit",
      render_result = artifact$render_result,
      validation = artifact$validation,
      turn = session$history_index %||% 0L,
      runtime = "ggai_init",
      task_prefix = "session_init"
    )
  )
  session <- session_record_turn_note(
    session,
    type = "ggai_init",
    value = list(
      source = "data.frame",
      instruction = instruction,
      initialization = "aisdk_agent",
      model = ggai_language_model(model),
      data_context = summarize_data_context(data)
    )
  )
  session_touch_state(session, instruction = instruction)
}

read_supported_data_file <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(
    ext,
    csv = utils::read.csv(path, stringsAsFactors = FALSE),
    tsv = utils::read.delim(path, stringsAsFactors = FALSE),
    txt = utils::read.delim(path, stringsAsFactors = FALSE),
    rds = readRDS(path),
    rlang::abort(paste0("Unsupported data file type: .", ext))
  )
}

#' Unified ggai entrypoint
#'
#' @param x A natural-language goal string, file path, ggplot object, or ggai
#'   session. Data frames should be referenced from the goal string with
#'   compact `@` mentions, for example `ggai("@my_data make a scatter plot")`.
#' @param instruction Optional natural-language instruction.
#' @param mode Either `"session"` for the editable ggplot workflow, `"polish"`
#'   to enter the whole-image redraw path, or `"auto"` for the local agentic
#'   runtime vertical slice.
#' @param image_model Optional image model override used when `mode = "polish"`.
#' @param model Optional language model override used for agentic session
#'   initialization and edits.
#' @param registry Optional aisdk provider registry.
#' @param acquisition_tools Optional list of controlled acquisition tools used
#'   when `x` is a natural-language data request rather than a file path.
#' @param polish_instruction Optional polish direction for the final redraw. For
#'   `ggplot` and `ggai_session` inputs this defaults to `instruction` when
#'   omitted.
#' @param ... Passed through to [polish_figure()] when `mode = "polish"`.
#'
#' @return Either a `ggai_session` or a `ggai_polished_figure_result`.
#' @export
ggai <- function(x,
                 instruction = NULL,
                 mode = c("session", "polish", "auto"),
                 image_model = NULL,
                 model = NULL,
                 registry = NULL,
                 acquisition_tools = NULL,
                 polish_instruction = NULL,
                 ...) {
  mode <- match.arg(mode)
  UseMethod("ggai")
}

ggai_direct_data_frame_error <- function() {
  rlang::abort(c(
    "`ggai()` no longer accepts a data frame as the direct first argument.",
    i = "Use the string-first Agentic interface and mention data objects inside the prompt.",
    i = "Example: `my_data <- mtcars; ggai(\"@my_data show mpg vs wt, color by cyl\")`.",
    i = "This keeps `ggai()` as a natural-language goal interface while still grounding the Agent in your R data."
  ))
}

ggai_session_from_data_frame <- function(data,
                                         instruction = NULL,
                                         mode = c("session", "polish", "auto"),
                                         image_model = NULL,
                                         model = NULL,
                                         registry = NULL,
                                         polish_instruction = NULL,
                                         skills = NULL,
                                         skill_registry = NULL,
                                         skill_path = NULL,
                                         ...) {
  mode <- match.arg(mode)
  if (identical(mode, "auto")) {
    agent <- create_ggai_agent(
      data = data,
      goal = instruction,
      model = model,
      registry = registry,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path
    )
    return(ggai_agent_run(agent))
  }

  agentic_model <- ggai_effective_agentic_model(model)
  session <- if (!is.null(instruction) && nzchar(instruction) && ggai_agentic_edit_enabled(agentic_model)) {
    build_agentic_initial_session(
      data,
      instruction = instruction,
      model = agentic_model,
      registry = registry,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path
    )
  } else if (!is.null(instruction) && nzchar(instruction)) {
    rlang::abort(c(
      "ggai data-grounded prompt mentions require an agentic language model.",
      i = "Pass `model=`, set `options(ggai.language_model=...)`, or set `GGAI_LANGUAGE_MODEL`."
    ))
  } else {
    build_local_default_session(data)
  }

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction,
      image_model = image_model,
      ...
    ))
  }

  session
}

#' @export
ggai.data.frame <- function(x,
                            instruction = NULL,
                            mode = c("session", "polish", "auto"),
                            image_model = NULL,
                            model = NULL,
                            registry = NULL,
                            acquisition_tools = NULL,
                            polish_instruction = NULL,
                            skills = NULL,
                            skill_registry = NULL,
                            skill_path = NULL,
                            ...) {
  ggai_direct_data_frame_error()
}

#' @export
ggai.character <- function(x,
                           instruction = NULL,
                           mode = c("session", "polish", "auto"),
                           image_model = NULL,
                           model = NULL,
                           registry = NULL,
                           acquisition_tools = NULL,
                           polish_instruction = NULL,
                           skills = NULL,
                           skill_registry = NULL,
                           skill_path = NULL,
                           ...) {
  mode <- match.arg(mode)
  if (length(x) != 1 || !nzchar(x)) {
    rlang::abort("`x` must be a single file path or natural-language goal string.")
  }

  mentions <- ggai_resolve_prompt_mentions(x, env = parent.frame())
  image_refs <- ggai_prompt_image_references(x, mentions = mentions)
  primary_data <- ggai_primary_data_mention(mentions)
  if (!is.null(primary_data)) {
    mention_instruction <- ggai_instruction_with_mentions(
      text = x,
      instruction = instruction,
      mentions = mentions
    )
    data_value <- as.data.frame(primary_data$value)
    attr(data_value, "ggai_prompt_mentions") <- mentions
    session <- ggai_session_from_data_frame(
      data_value,
      instruction = mention_instruction,
      mode = if (identical(mode, "auto")) "auto" else "session",
      model = model,
      registry = registry,
      polish_instruction = polish_instruction,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path
    )
    session <- session_record_turn_note(
      session,
      type = "ggai_prompt_mentions",
      value = list(
        primary_data = primary_data$name,
        mentions = ggai_mention_metadata(mentions)
      )
    )

    if (identical(mode, "polish")) {
      return(polish_figure(
        session,
        instruction = polish_instruction,
        image_model = image_model,
        ...
      ))
    }

    return(session)
  }

  if (!ggai_supported_data_file_path(x)) {
    goal <- if (length(mentions)) {
      ggai_instruction_with_mentions(
        text = x,
        instruction = instruction,
        mentions = mentions
      )
    } else {
      x
    }
    session <- ggai_goal_agent_session(
      goal = goal,
      instruction = if (length(mentions)) NULL else instruction,
      model = model,
      registry = registry,
      skills = skills,
      skill_registry = skill_registry,
      skill_path = skill_path,
      image_refs = image_refs,
      context_mentions = mentions
    )

    if (identical(mode, "polish")) {
      return(polish_figure(
        session,
        instruction = polish_instruction,
        image_model = image_model,
        ...
      ))
    }

    return(session)
  }

  data <- read_supported_data_file(x)
  session <- ggai_session_from_data_frame(
    as.data.frame(data),
    instruction = instruction,
    mode = if (identical(mode, "auto")) "auto" else "session",
    model = model,
    registry = registry,
    polish_instruction = polish_instruction,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path
  )
  session <- session_record_turn_note(
    session,
    type = "ggai_source",
    value = list(source = "file", path = x)
  )

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction,
      image_model = image_model,
      ...
    ))
  }

  session
}

#' @export
ggai.ggplot <- function(x,
                        instruction = NULL,
                        mode = c("session", "polish", "auto"),
                        image_model = NULL,
                        model = NULL,
                        registry = NULL,
                        acquisition_tools = NULL,
                        polish_instruction = NULL,
                        ...) {
  mode <- match.arg(mode)
  if (identical(mode, "auto")) {
    agent <- create_ggai_agent(plot = x, goal = instruction, model = model, registry = registry)
    return(ggai_agent_run(agent))
  }

  session <- start_ggai_session(x)

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction %||% instruction,
      image_model = image_model,
      ...
    ))
  }

  if (!is.null(instruction) && nzchar(instruction)) {
    return(gg_edit(session, instruction, model = model))
  }
  session
}

#' @export
ggai.ggai_session <- function(x,
                              instruction = NULL,
                              mode = c("session", "polish", "auto"),
                              image_model = NULL,
                              model = NULL,
                              registry = NULL,
                              acquisition_tools = NULL,
                              polish_instruction = NULL,
                              ...) {
  mode <- match.arg(mode)
  if (identical(mode, "auto")) {
    agent <- create_ggai_agent(session = x, goal = instruction, model = model, registry = registry)
    return(ggai_agent_run(agent))
  }

  if (identical(mode, "polish")) {
    return(polish_figure(
      x,
      instruction = polish_instruction %||% instruction,
      image_model = image_model,
      ...
    ))
  }

  if (!is.null(instruction) && nzchar(instruction)) {
    return(gg_edit(x, instruction, model = model))
  }
  x
}

#' @export
ggai.default <- function(x,
                         instruction = NULL,
                         mode = c("session", "polish", "auto"),
                         image_model = NULL,
                         model = NULL,
                         registry = NULL,
                         acquisition_tools = NULL,
                         polish_instruction = NULL,
                         ...) {
  rlang::abort("`ggai()` currently supports natural-language goal strings, file paths, ggplot objects, and ggai_session inputs.")
}
