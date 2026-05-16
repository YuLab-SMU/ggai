test_that("ggai task contracts validate and serialize", {
  task <- new_ggai_task(
    goal = "Compare mpg by cylinder count",
    task_type = "visual_analysis",
    target = "plot",
    data_ref = list(name = "mtcars"),
    constraints = list(no_network = TRUE),
    assumptions = list("mtcars is available")
  )

  expect_s3_class(task, "ggai_task")
  expect_no_error(validate_ggai_task(task))
  expect_equal(task$contract_type, "ggai_task")

  json <- serialize_ggai_contract(task)
  restored <- deserialize_ggai_contract(json)

  expect_s3_class(restored, "ggai_task")
  expect_equal(restored$goal, task$goal)
  expect_equal(restored$constraints$no_network, TRUE)
})

test_that("analysis and visual brief contracts validate required structure", {
  task <- new_ggai_task("Explain the relationship between wt and mpg")

  analysis <- new_analysis_brief(
    task_id = task$id,
    question = "How does weight relate to mpg?",
    data_summary = list(rows = nrow(mtcars), columns = names(mtcars)),
    variables = list(x = "wt", y = "mpg"),
    method_candidates = list("correlation", "linear_model"),
    method_decisions = list(list(method = "linear_model", reason = "two numeric variables"))
  )

  visual <- new_visual_brief(
    task_id = task$id,
    intent = "Show the relationship and trend",
    chart_type = "scatterplot",
    encodings = list(x = "wt", y = "mpg"),
    layers = list("point", "smooth"),
    validation = list(status = "pending")
  )

  expect_s3_class(analysis, "analysis_brief")
  expect_s3_class(visual, "visual_brief")
  expect_no_error(validate_analysis_brief(analysis))
  expect_no_error(validate_visual_brief(visual))
})

test_that("agent trace contracts round-trip through JSON", {
  task <- new_ggai_task("Build a scatterplot")
  trace <- new_ggai_agent_trace(
    task_id = task$id,
    status = "completed",
    steps = list(list(step = "profile_data", status = "done")),
    tool_calls = list(list(name = "profile_data", status = "ok")),
    observations = list(list(type = "data_shape", value = c(rows = 32L, columns = 11L))),
    artifacts = list(list(kind = "plot", status = "validated")),
    completed_at = "2026-04-27 00:00:00 UTC"
  )

  expect_s3_class(trace, "ggai_agent_trace")
  expect_no_error(validate_ggai_agent_trace(trace))

  restored <- deserialize_ggai_contract(serialize_ggai_contract(trace))
  expect_s3_class(restored, "ggai_agent_trace")
  expect_equal(restored$status, "completed")
  expect_equal(restored$steps[[1]]$step, "profile_data")
})

test_that("contract validators reject malformed records", {
  expect_error(new_ggai_task(""), class = "ggai_contract_error")
  expect_error(
    new_analysis_brief(task_id = "task-1", question = "q", variables = "x"),
    class = "ggai_contract_error"
  )
  expect_error(
    deserialize_ggai_contract("{\"contract_type\":\"unknown\"}"),
    class = "ggai_contract_error"
  )
})
