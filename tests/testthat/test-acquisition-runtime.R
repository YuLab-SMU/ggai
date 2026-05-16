test_that("acquisition tools validate controlled tool definitions", {
  tool <- ggai_acquisition_tool(
    name = "local_counts",
    description = "Produces a small local count table.",
    acquire = function(goal, context) data.frame(group = c("a", "b"), value = c(1, 2))
  )

  expect_s3_class(tool, "ggai_acquisition_tool")
  expect_equal(tool$name, "local_counts")
  expect_error(
    ggai_acquisition_tool("bad name", "desc", function(goal, context) data.frame()),
    "identifier"
  )
})

test_that("deterministic acquisition uses configured tools and validates data frames", {
  old <- options(ggai.acquisition_use_default_model = FALSE)
  on.exit(options(old), add = TRUE)

  tool <- ggai_acquisition_tool(
    name = "trend_table",
    description = "Produces a trend table.",
    can_handle = function(goal, context) grepl("trend", goal, fixed = TRUE),
    acquire = function(goal, context) {
      list(
        kind = "trend_table",
        data = data.frame(month = as.Date("2026-01-01") + 0:2, value = 1:3),
        instruction = "Plot value by month.",
        source_note = list(source = "unit_test")
      )
    }
  )

  acquired <- ggai:::ggai_acquire_goal_data(
    "make a trend chart",
    acquisition_tools = list(tool)
  )

  expect_equal(acquired$kind, "trend_table")
  expect_equal(acquired$tool_name, "trend_table")
  expect_equal(acquired$instruction, "Plot value by month.")
  expect_equal(acquired$source_note$source, "unit_test")
  expect_s3_class(acquired$data, "data.frame")
})

test_that("acquisition code tool validates data frames and rejects unsafe calls", {
  context <- ggai:::ggai_acquisition_context("collect monthly counts")
  acquired <- ggai:::ggai_acquisition_from_code(
    code = "data.frame(month = as.Date('2026-01-01') + 0:2, value = c(1, 2, 4))",
    goal = "collect monthly counts",
    context = context,
    kind = "monthly_counts",
    instruction = "Plot value by month.",
    source_note = list(source = "unit_test_code")
  )

  expect_equal(acquired$kind, "monthly_counts")
  expect_equal(acquired$tool_name, "agent_data_frame_code")
  expect_equal(acquired$instruction, "Plot value by month.")
  expect_equal(acquired$source_note$source, "unit_test_code")

  expect_error(
    ggai:::ggai_acquisition_from_code("system('echo no')", "bad", context),
    class = "ggai_acquisition_tool_error"
  )
})

test_that("agent acquisition tools expose primitive context, candidate, and commit actions", {
  state <- new.env(parent = emptyenv())
  state$goal <- "collect monthly counts"
  state$context <- ggai:::ggai_acquisition_context("collect monthly counts")
  state$tools <- list()
  state$acquisition_session <- ggai:::ggai_new_acquisition_session(
    state$goal,
    state$context,
    model = "deepseek:test"
  )
  state$steps <- list()
  state$candidates <- list()
  state$references <- list()
  state$acquired <- NULL
  state$blocker <- NULL

  tools <- ggai:::ggai_acquisition_agent_tools(state)
  context <- tools$inspect_acquisition_context$run(list())
  expect_equal(context$goal, "collect monthly counts")

  candidate <- tools$try_acquisition_code$run(list(
    code = "data.frame(month = as.Date('2026-01-01') + 0:1, value = c(2, 3))",
    kind = "monthly_counts",
    instruction = "Plot value by month.",
    source_note = "unit test"
  ))
  expect_equal(candidate$status, "candidate_ready")
  expect_equal(length(state$candidates), 1)

  committed <- tools$commit_acquired_data$run(list(
    candidate_id = candidate$candidate_id,
    completion_summary = "Monthly count data is available."
  ))
  expect_equal(committed$status, "committed")
  expect_equal(state$acquired$kind, "monthly_counts")

  blocker <- tools$declare_acquisition_blocker$run(list(
    reason = "No further bounded source is available.",
    evidence = "Unit test evidence.",
    next_step = "Configure an acquisition tool."
  ))
  expect_equal(blocker$status, "blocker_declared")
  expect_match(state$blocker$reason, "bounded source")
})

test_that("acquisition detects explicit URLs and reads them through a bounded tool", {
  goal <- "https://example.com/article 看看这个文章，我也要画这种图"
  context <- ggai:::ggai_acquisition_context(goal)
  expect_equal(context$urls[[1]], "https://example.com/article")

  state <- new.env(parent = emptyenv())
  state$goal <- goal
  state$context <- context
  state$tools <- list()
  state$acquisition_session <- ggai:::ggai_new_acquisition_session(
    state$goal,
    state$context,
    model = "deepseek:test"
  )
  state$steps <- list()
  state$candidates <- list()
  state$references <- list()
  state$acquired <- NULL
  state$blocker <- NULL

  local_mocked_bindings(
    ggai_fetch_url_text = function(url, ...) {
      expect_equal(url, "https://example.com/article")
      "<html><body><h1>Chart style article</h1><p>Use layered annotations and a compact legend.</p></body></html>"
    },
    .package = "ggai"
  )

  tools <- ggai:::ggai_acquisition_agent_tools(state)
  context_out <- tools$inspect_acquisition_context$run(list())
  expect_equal(context_out$urls[[1]], "https://example.com/article")

  reference <- tools$read_url$run(list(
    url = "https://example.com/article",
    rationale = "The user explicitly asked to inspect this article."
  ))
  expect_equal(reference$status, "reference_ready")
  expect_match(reference$content_preview, "Chart style article")
  expect_equal(length(state$candidates), 0)
  expect_equal(length(state$references), 1)
  expect_equal(state$references$url_reference_1$source_url, "https://example.com/article")
  expect_match(state$references$url_reference_1$content_excerpt, "layered annotations")

  inspected <- tools$inspect_acquisition_session$run(list())
  expect_true("url_reference_1" %in% vapply(inspected$objects, `[[`, character(1), "name"))
})

test_that("bounded URL reader refuses URLs not present in the user request", {
  state <- new.env(parent = emptyenv())
  state$goal <- "https://example.com/a use this"
  state$context <- ggai:::ggai_acquisition_context(state$goal)
  state$tools <- list()
  state$acquisition_session <- ggai:::ggai_new_acquisition_session(
    state$goal,
    state$context,
    model = "deepseek:test"
  )
  state$steps <- list()
  state$candidates <- list()
  state$references <- list()
  state$acquired <- NULL
  state$blocker <- NULL

  tools <- ggai:::ggai_acquisition_agent_tools(state)
  expect_error(
    tools$read_url$run(list(url = "https://example.com/b")),
    "limited to explicit"
  )
})

test_that("agent acquisition can commit a reference brief instead of blocking", {
  state <- new.env(parent = emptyenv())
  state$goal <- "https://example.com/a 看看这个文章，我也要画这种图"
  state$context <- ggai:::ggai_acquisition_context(state$goal)
  state$tools <- list()
  state$acquisition_session <- ggai:::ggai_new_acquisition_session(
    state$goal,
    state$context,
    model = "deepseek:test"
  )
  state$steps <- list()
  state$candidates <- list()
  state$references <- list(
    url_reference_1 = list(
      source_url = "https://example.com/a",
      content_excerpt = "The page uses small multiples, strong title hierarchy, and grouped colors."
    )
  )
  state$reference_brief <- NULL
  state$acquired <- NULL
  state$blocker <- NULL

  tools <- ggai:::ggai_acquisition_agent_tools(state)
  committed <- tools$commit_reference_brief$run(list(
    visual_goal = "Create a reference-inspired small-multiple chart.",
    reference_summary = "Reference suggests small multiples with grouped colors.",
    chart_type = "small_multiples",
    assumptions = "Original source data is unavailable.\nUse illustrative seed data.",
    source_note = "unit test reference brief",
    completion_summary = "A reference brief is enough for a best-effort template plot.",
    remaining_risks = "Values are illustrative."
  ))

  expect_equal(committed$status, "committed_reference_brief")
  expect_equal(state$acquired$kind, "reference_brief")
  expect_equal(state$acquired$tool_name, "agent_reference_brief")
  expect_s3_class(state$acquired$data, "data.frame")
  expect_s3_class(state$acquired$visual_brief, "visual_brief")
  expect_equal(state$acquired$source_note$original_data_available, FALSE)
  expect_match(state$acquired$instruction, "reference-only acquisition brief")
  expect_match(state$acquired$instruction, "illustrative/template plot")
})

test_that("acquisition blocker reason is surfaced in abort messages", {
  expect_error(
    ggai:::ggai_acquisition_abort(
      "read a blocked URL",
      "No acquisition candidate returned a committed data frame after 100 Agent step(s).",
      details = list(
        blocker = list(
          reason = "The site blocks automated access.",
          next_step = "Open the page manually or provide article text."
        )
      )
    ),
    "Agent blocker: The site blocks automated access"
  )
})

test_that("agent acquisition tools support progressive aisdk session steps", {
  state <- new.env(parent = emptyenv())
  state$goal <- "build word counts"
  state$context <- ggai:::ggai_acquisition_context("build word counts")
  state$tools <- list()
  state$acquisition_session <- ggai:::ggai_new_acquisition_session(
    state$goal,
    state$context,
    model = "deepseek:test"
  )
  state$steps <- list()
  state$candidates <- list()
  state$acquired <- NULL
  state$blocker <- NULL

  tools <- ggai:::ggai_acquisition_agent_tools(state)
  first <- tools$run_acquisition_step$run(list(
    code = "tokens <- c('agent', 'plot', 'agent', 'trace'); length(tokens)",
    rationale = "Create and inspect intermediate tokens."
  ))
  expect_equal(first$status, "ok")
  expect_equal(first$result$preview, 4L)

  inspected <- tools$inspect_acquisition_session$run(list())
  expect_true("tokens" %in% vapply(inspected$objects, `[[`, character(1), "name"))

  second <- tools$run_acquisition_step$run(list(
    code = "word_counts <- as.data.frame(table(tokens)); names(word_counts) <- c('word', 'n'); word_counts",
    rationale = "Aggregate intermediate tokens into a data frame."
  ))
  expect_equal(second$status, "ok")
  expect_equal(second$candidate$status, "candidate_ready")

  committed <- tools$commit_acquired_data$run(list(
    object_name = "word_counts",
    kind = "word_counts",
    instruction = "Plot word counts as a word cloud style chart.",
    source_note = "unit test session objects",
    completion_summary = "Word count data frame is available."
  ))
  expect_equal(committed$status, "committed")
  expect_equal(state$acquired$kind, "word_counts")
  expect_equal(state$acquired$source_note$note, "unit test session objects")
  expect_equal(nrow(state$acquired$data), 3L)
  expect_length(state$steps, 2)
})

test_that("agent acquisition passes discovered skills to aisdk create_agent", {
  old_mode <- getOption("ggai.agentic_tool_log_mode", NULL)
  on.exit(options(ggai.agentic_tool_log_mode = old_mode), add = TRUE)
  options(ggai.agentic_tool_log_mode = "inherit")

  root <- tempfile()
  dir.create(file.path(root, "skills", "data-acquire"), recursive = TRUE)
  writeLines(
    c(
      "---",
      "name: data-acquire",
      "description: Acquire and tabulate external research data for plotting.",
      "---",
      "# data-acquire",
      "Prefer audited source notes and compact data frames."
    ),
    file.path(root, "skills", "data-acquire", "SKILL.md")
  )
  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    ggai_aisdk = function(name) {
      ns <- asNamespace("aisdk")
      if (identical(name, "create_agent")) {
        return(function(name, description, system_prompt = NULL, tools = NULL, skills = NULL, model = NULL) {
          captured$skills <- skills
          list(run = function(...) {
            candidate <- tools$try_acquisition_code$run(list(
              code = "data.frame(month = as.Date('2026-01-01') + 0:1, value = c(2, 3))",
              kind = "monthly_counts",
              instruction = "Plot value by month.",
              source_note = "unit test"
            ))
            tools$commit_acquired_data$run(list(
              candidate_id = candidate$candidate_id,
              completion_summary = "Monthly count data is available."
            ))
            list(
              text = "committed",
              all_tool_results = list(list(
                name = "ggai_try_acquisition_code",
                result = list(
                  code = paste(rep("data.frame(value = 1)", 40), collapse = "\n"),
                  candidate = candidate
                )
              ))
            )
          })
        })
      }
      get(name, envir = ns, inherits = FALSE)
    },
    .package = "ggai"
  )

  acquired <- ggai:::ggai_agentic_acquire_goal_data(
    goal = "acquire research data for plotting",
    tools = list(),
    context = ggai:::ggai_acquisition_context("acquire research data for plotting"),
    model = "deepseek:test",
    skill_path = file.path(root, "skills")
  )

  expect_equal(acquired$kind, "monthly_counts")
  expect_true(normalizePath(file.path(root, "skills", "data-acquire")) %in% captured$skills)
  expect_true(any(basename(captured$skills) == "ggai-acquisition-agent"))
  expect_match(acquired$trace$tool_results[[1]]$result$code, "\\.\\.\\.$")
})

test_that("embedded local paths are acquisition goals, not data file paths", {
  path <- tempfile(fileext = ".txt")
  writeLines("alpha beta beta gamma gamma gamma", path)
  goal <- paste0("制作这篇论文的词云分析：", path)

  expect_false(ggai:::ggai_text_looks_like_file_path(goal))
  expect_true(path %in% ggai:::ggai_detect_local_paths(goal))
  expect_false(ggai:::ggai_supported_data_file_path(goal))
  expect_true(ggai:::ggai_supported_data_file_path(path))
})

test_that("acquisition reports blockers instead of guessing sources", {
  old <- options(ggai.acquisition_use_default_model = FALSE)
  on.exit(options(old), add = TRUE)

  expect_error(
    ggai:::ggai_acquire_goal_data("fetch data from an unspecified external source"),
    class = "ggai_acquisition_error"
  )

  bad_tool <- ggai_acquisition_tool(
    name = "bad_tool",
    description = "Returns the wrong shape.",
    can_handle = function(goal, context) TRUE,
    acquire = function(goal, context) list(message = "not a data frame")
  )

  expect_error(
    ggai:::ggai_acquire_goal_data("make a chart", acquisition_tools = list(bad_tool)),
    class = "ggai_acquisition_tool_error"
  )
})

test_that("acquisition refuses ambiguous deterministic tool choices", {
  old <- options(ggai.acquisition_use_default_model = FALSE)
  on.exit(options(old), add = TRUE)

  tool_a <- ggai_acquisition_tool(
    name = "tool_a",
    description = "First possible tool.",
    can_handle = function(goal, context) TRUE,
    acquire = function(goal, context) data.frame(x = 1, y = 1)
  )
  tool_b <- ggai_acquisition_tool(
    name = "tool_b",
    description = "Second possible tool.",
    can_handle = function(goal, context) TRUE,
    acquire = function(goal, context) data.frame(x = 2, y = 2)
  )

  expect_error(
    ggai:::ggai_acquire_goal_data("make a chart", acquisition_tools = list(tool_a, tool_b)),
    "Multiple acquisition tools are eligible",
    class = "ggai_acquisition_error"
  )
})
