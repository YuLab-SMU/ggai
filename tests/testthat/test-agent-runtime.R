test_that("create_ggai_agent builds a bounded local visual agent", {
  agent <- create_ggai_agent(data = mtcars, goal = "show mpg vs wt")

  expect_s3_class(agent, "ggai_agent")
  expect_equal(agent$goal, "show mpg vs wt")
  expect_named(
    agent$tools,
    c(
      "data_profile",
      "plot_inspection",
      "session_inspection",
      "stat_method_selection",
      "package_check",
      "package_install",
      "help_inspection",
      "examples_inspection",
      "vignette_index",
      "source_url_detection",
      "github_inspection",
      "local_file_listing",
      "local_file_reading",
      "source_summary",
      "diagram_compilation",
      "plot_validation",
      "artifact_recording"
    )
  )
})

test_that("ggai_agent_run returns a session with task, brief, trace, and artifact metadata", {
  agent <- create_ggai_agent(data = mtcars, goal = "show mpg vs wt")
  session <- ggai_agent_run(agent)

  expect_s3_class(session, "ggai_session")
  expect_s3_class(ggai:::session_current_plot(session), "ggplot")

  ctx <- session_context(session)
  expect_length(ctx$recent_agent_tasks, 1)
  expect_length(ctx$recent_analysis_briefs, 1)
  expect_length(ctx$recent_visual_briefs, 1)
  expect_true(length(ctx$recent_agent_traces) >= 2)
  expect_length(ctx$recent_artifacts, 1)

  expect_equal(ctx$recent_agent_tasks[[1]]$goal, "show mpg vs wt")
  expect_equal(ctx$recent_analysis_briefs[[1]]$variables$x, "mpg")
  expect_equal(ctx$recent_analysis_briefs[[1]]$method_decisions[[1]]$method, "pearson_correlation")
  expect_equal(ctx$recent_visual_briefs[[1]]$chart_type, "scatter")
  expect_equal(ctx$recent_visual_briefs[[1]]$annotations[[1]]$method, "pearson_correlation")
  expect_equal(ctx$recent_agent_traces[[1]]$status, "completed")
  expect_equal(ctx$recent_artifacts[[1]]$kind, "ggplot_session")
  expect_true(any(vapply(ctx$recent_agent_traces, function(trace) identical(trace$task_id, "validation_repair"), logical(1))))
})

test_that("ggai_agent_run can add trace metadata to an existing session", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  session <- start_ggai_session(p)

  out <- ggai_agent_run(create_ggai_agent(session = session, goal = "inspect current plot"))
  ctx <- session_context(out)

  expect_s3_class(out, "ggai_session")
  expect_equal(ctx$recent_agent_tasks[[1]]$goal, "inspect current plot")
  expect_equal(ctx$recent_visual_briefs[[1]]$validation$status, "ok")
})

test_that("ggai_agent_run records GitHub source evidence for architecture tasks", {
  mentioned_data <- mtcars
  session <- ggai("@mentioned_data diagram architecture from https://github.com/org/repo", mode = "auto")
  ctx <- session_context(session)

  evidence <- ctx$recent_visual_briefs[[1]]$evidence
  expect_true(length(evidence) >= 1)
  expect_true(any(vapply(evidence, function(item) identical(item$kind, "github_repository"), logical(1))))
  expect_true(any(vapply(ctx$recent_agent_traces[[1]]$observations, function(item) identical(item$type, "source_context"), logical(1))))
})
