ggai_spec_committer_system_prompt <- function(kind, body) {
  paste(
    body,
    "",
    "Workflow:",
    "- You have a single primary tool named ggai_commit_<kind>_spec.",
    "- Read the user instruction and any context you are given.",
    "- Call ggai_commit_<kind>_spec exactly once with a complete spec that satisfies the schema.",
    "- If the commit tool returns issues, call it again with a corrected spec.",
    "- Stop once the commit tool returns status=\"committed\".",
    "Do not call unrelated tools or emit text other than the final acknowledgement.",
    sep = "\n"
  )
}

ggai_spec_committer_task <- function(instruction, context = list(), context_label = "Context") {
  paste(
    "Instruction:",
    instruction,
    "",
    paste0(context_label, ":"),
    jsonlite::toJSON(context, auto_unbox = TRUE, null = "null", pretty = TRUE),
    "",
    "Call the commit tool with a complete spec that matches the schema.",
    sep = "\n"
  )
}

ggai_run_spec_committer_agent <- function(kind,
                                          instruction,
                                          system_body,
                                          schema,
                                          context = list(),
                                          context_label = "Context",
                                          normalize = identity,
                                          validate = function(spec) character(0),
                                          model = NULL,
                                          registry = NULL,
                                          skills = NULL,
                                          skill_registry = NULL,
                                          skill_path = NULL,
                                          max_steps = getOption("ggai.spec_committer_max_steps", 6L)) {
  if (!ggai_aisdk_runtime_available()) {
    rlang::abort("aisdk runtime required for spec-committer agent.")
  }
  model <- ggai_language_model(model)

  tool <- ggai_aisdk("tool")
  create_agent <- ggai_aisdk("create_agent")

  state <- new.env(parent = emptyenv())
  state$committed <- NULL
  state$last_issues <- character(0)

  tool_name <- paste0("ggai_commit_", kind, "_spec")
  commit_tool <- tool(
    name = tool_name,
    description = paste0("Commit the final ", kind, " spec. Call exactly once when the spec is ready."),
    parameters = schema,
    execute = function(...) {
      spec <- list(...)
      normalized <- tryCatch(normalize(spec), error = function(e) {
        state$last_issues <- ggai_strip_ansi(conditionMessage(e))
        NULL
      })
      if (is.null(normalized)) {
        return(list(status = "rejected", issues = state$last_issues))
      }
      issues <- tryCatch(validate(normalized), error = function(e) ggai_strip_ansi(conditionMessage(e)))
      if (length(issues)) {
        state$last_issues <- issues
        return(list(status = "rejected", issues = issues))
      }
      state$committed <- normalized
      list(status = "committed")
    }
  )

  system_prompt <- ggai_spec_committer_system_prompt(kind, system_body)
  skill_paths <- ggai_agent_skill_paths(
    skills = skills,
    query = instruction,
    skill_registry = skill_registry,
    skill_path = skill_path,
    builtin_skills = character(0)
  )
  agent <- create_agent(
    name = paste0("ggai_", kind, "_committer"),
    description = paste0("Produces a structured ", kind, " spec via a single commit tool."),
    system_prompt = system_prompt,
    tools = list(commit_tool),
    skills = skill_paths,
    model = model
  )

  task <- ggai_spec_committer_task(instruction, context = context, context_label = context_label)
  run_args <- c(
    list(task = task, max_steps = max_steps, model = model, registry = registry),
    ggai_agentic_run_args(model)
  )
  tryCatch(
    ggai_agentic_run_agent(agent, run_args),
    error = function(e) {
      rlang::abort(paste0(kind, " spec committer agent failed: ", ggai_strip_ansi(conditionMessage(e))))
    }
  )

  if (is.null(state$committed)) {
    rlang::abort(paste0(
      "The ", kind, " agent did not commit a valid spec",
      if (length(state$last_issues)) paste0(" (last issues: ", paste(state$last_issues, collapse = "; "), ")") else "",
      "."
    ))
  }
  state$committed
}
