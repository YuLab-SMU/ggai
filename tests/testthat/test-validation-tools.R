# Pure-ggplot validation helpers. The P1-era session-coupled tests
# (`ggai_validate_session_artifact`, `ggai_validate_and_repair`) were removed
# in P2 along with the agent runtime; the validation primitives still ship.

test_that("ggai_validate_plot_build returns pass for a valid plot", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  issue <- ggai_validate_plot_build(p)
  expect_equal(issue$status, "pass")
  expect_equal(issue$type, "plot_build")
})

test_that("ggai_validate_plot_build flags a broken plot with error message", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(not_a_column, mpg)) + ggplot2::geom_point()
  issue <- ggai_validate_plot_build(p)
  expect_equal(issue$status, "fail")
  expect_true(nzchar(issue$message))
})

test_that("ggai_validate_referenced_variables flags missing columns", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(not_a_column, mpg)) + ggplot2::geom_point()
  issue <- ggai_validate_referenced_variables(p)
  expect_equal(issue$status, "fail")
  expect_true("not_a_column" %in% issue$details$missing)
})

test_that("ggai_validate_referenced_variables passes when all columns exist", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  issue <- ggai_validate_referenced_variables(p)
  expect_equal(issue$status, "pass")
})

test_that("ggai_validate_stat_annotation_consistency flags mismatched methods", {
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
  issue <- ggai_validate_stat_annotation_consistency(analysis = analysis, visual = visual)
  expect_equal(issue$status, "fail")
})

test_that("ggai_validate_source_evidence_coverage flags missing evidence", {
  visual <- new_visual_brief(task_id = "task-1", intent = "diagram", evidence = list())
  issue <- ggai_validate_source_evidence_coverage(
    goal = "diagram architecture from https://github.com/org/repo",
    visual = visual
  )
  expect_equal(issue$status, "fail")
})
