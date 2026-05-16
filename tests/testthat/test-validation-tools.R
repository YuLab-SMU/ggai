test_that("session artifact validation passes for a valid auto session", {
  mentioned_data <- mtcars
  session <- ggai("@mentioned_data show mpg vs wt", mode = "auto")
  ctx <- session_context(session)
  report <- ggai_validate_session_artifact(
    session,
    analysis = ctx$recent_analysis_briefs[[1]],
    visual = ctx$recent_visual_briefs[[1]],
    goal = "show mpg vs wt"
  )

  expect_true(report$status %in% c("pass", "warn"))
  expect_true(any(vapply(report$issues, function(issue) identical(issue$type, "plot_build"), logical(1))))
})

test_that("validation detects and repairs missing variable mappings", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(not_a_column, mpg)) + ggplot2::geom_point()
  session <- start_ggai_session(p)

  result <- ggai_validate_and_repair(session, max_attempts = 1)

  expect_equal(result$initial$status, "fail")
  expect_true(length(result$repairs) <= 1)
  expect_true(isTRUE(result$repairs[[1]]$repaired))
  expect_true(result$final$status %in% c("pass", "warn"))
  ctx <- session_context(result$session)
  expect_true(any(vapply(ctx$recent_agent_traces, function(trace) identical(trace$task_id, "validation_repair"), logical(1))))
})

test_that("validation flags inconsistent statistical annotations", {
  analysis <- new_analysis_brief(
    task_id = "task-1",
    question = "q",
    method_decisions = list(list(method = "pearson_correlation"))
  )
  visual <- new_visual_brief(
    task_id = "task-1",
    intent = "q",
    annotations = list(list(kind = "statistical_method", method = "linear_model"))
  )
  session <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point())

  report <- ggai_validate_session_artifact(session, analysis = analysis, visual = visual, goal = "q")

  expect_equal(report$status, "fail")
  expect_true(any(vapply(report$issues, function(issue) identical(issue$type, "stat_annotation_consistency") && identical(issue$status, "fail"), logical(1))))
})

test_that("validation flags missing source evidence coverage", {
  visual <- new_visual_brief(task_id = "task-1", intent = "diagram architecture", evidence = list())
  session <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point())

  report <- ggai_validate_session_artifact(
    session,
    visual = visual,
    goal = "diagram architecture from https://github.com/org/repo"
  )

  expect_equal(report$status, "fail")
  expect_true(any(vapply(report$issues, function(issue) identical(issue$type, "source_evidence_coverage") && identical(issue$status, "fail"), logical(1))))
})

test_that("repair loop stops after configured attempts", {
  p <- ggplot2::ggplot(data.frame(), ggplot2::aes(not_a_column, still_missing)) + ggplot2::geom_point()
  session <- start_ggai_session(p)

  result <- ggai_validate_and_repair(session, max_attempts = 1)

  expect_equal(length(result$repairs), 1)
  expect_false(isTRUE(result$repairs[[1]]$repaired))
  expect_equal(result$final$status, "fail")
})
