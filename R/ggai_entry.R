# The single public ggai entrypoint. Pre-P2 this file ran ~800 lines and
# implemented three fixed paths (session / polish / auto). Post-P2 it is a
# thin factory: `ggai(goal)` builds an aisdk Agent (via `ggai_create_agent()`)
# and runs it. All routing decisions live in Skills, not here.

#' Drive the ggai agent on a figure goal
#'
#' Builds (or reuses) an aisdk Agent configured with ggai's verb tools and the
#' Skills shipped under `inst/skills/`, then runs the agent on `goal`.
#'
#' The agent decides how to fulfill the goal — pick an engine, write code,
#' validate, optionally loop, persist — by loading the relevant Skill on
#' demand. There is no `mode` argument: routing is the agent's job.
#'
#' Data objects in the caller frame are reachable by `@`-mention syntax in the
#' goal string, e.g. `ggai("@mtcars show mpg vs wt, color by cyl")`. Mentions
#' are resolved by ggai before the agent runs and surfaced to the agent as
#' structured context appended to the goal.
#'
#' @param goal Character scalar. The user's figure task.
#' @param model Optional language model identifier. Defaults to
#'   `ggai_default_models()$language`.
#' @param session Optional `aisdk::ChatSession`. When omitted, the agent
#'   creates a temporary session internally.
#' @param skills Optional override for the skill search path. Defaults to
#'   `system.file("skills", package = "ggai")`.
#' @param max_steps Maximum ReAct loop iterations. Default `10`.
#' @param extra_tools Optional list of additional `aisdk::Tool` objects.
#' @param ... Passed through to `agent$run()`.
#'
#' @return A list with `result` (the aisdk result), `artifact` (the most-recent
#'   `ggai_artifact` produced — may be `NULL` if the agent produced none) and
#'   `artifacts` (every artifact produced this run, keyed by id).
#' @export
#'
#' @examples
#' \dontrun{
#' ggai("draw a CRISPR knockout diagram with three guide RNAs")
#'
#' # Reference a local data frame via @mention:
#' my_data <- mtcars
#' ggai("@my_data show mpg vs wt, color by cyl")
#' }
ggai <- function(goal,
                 model = NULL,
                 session = NULL,
                 skills = NULL,
                 max_steps = 10L,
                 extra_tools = NULL,
                 ...) {
  if (!is.character(goal) || length(goal) != 1L || !nzchar(goal)) {
    rlang::abort("`goal` must be a single non-empty character string.")
  }

  mentions <- ggai_resolve_prompt_mentions(goal, env = parent.frame())
  enriched_goal <- if (length(mentions)) {
    ggai_instruction_with_mentions(text = goal, mentions = mentions)
  } else {
    goal
  }

  agent <- ggai_create_agent(
    model = model,
    skills = skills,
    extra_tools = extra_tools
  )

  ggai_run_agent(
    agent = agent,
    goal = enriched_goal,
    session = session,
    max_steps = max_steps,
    ...
  )
}

# ---- @-mention resolution -------------------------------------------------
#
# Lets users reference data frames, file paths, character values, ggplot
# objects, or ggai_artifacts in the caller frame by `@name` inside the goal
# string. Resolved mentions are appended to the goal as structured context.

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
  if (inherits(value, "ggplot")) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "ggplot",
      resolved = TRUE,
      value = value
    ))
  }
  if (is_ggai_artifact(value)) {
    return(ggai_prompt_mention_summary(
      name = token,
      kind = "ggai_artifact",
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
    } else if (identical(mention$kind, "ggai_artifact")) {
      lines <- c(lines, paste0(
        "- ", label, ": ggai_artifact (id=", mention$value$id,
        ", engine=", mention$value$engine, ")."
      ))
    } else {
      lines <- c(lines, paste0("- ", label, ": R object of class ", mention$kind, "."))
    }
  }
  lines
}

ggai_instruction_with_mentions <- function(text, mentions = list()) {
  if (!length(mentions)) {
    return(text)
  }
  paste(
    text,
    "",
    "Mention context resolved by ggai before the agent run:",
    paste(ggai_mention_context_lines(mentions), collapse = "\n"),
    "",
    "Use mentioned data frames as user-provided data. Treat mentioned files as reference or source context.",
    sep = "\n"
  )
}
