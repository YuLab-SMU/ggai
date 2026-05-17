# Layer-3 agent factory: ggai wires aisdk::create_agent with verb tools and
# skill discovery. No actual LLM calls — those are gated by API keys and live
# in separate manual tests.

skip_if_not_installed("aisdk")

test_that("ggai_create_agent builds an aisdk Agent with verb tools attached", {
  agent <- ggai_create_agent()
  expect_s3_class(agent, "Agent")

  state <- attr(agent, "ggai_state")
  expect_true(is.environment(state))
  expect_null(state$last_artifact)
})

test_that("agent tools include the three ggai verbs", {
  agent <- ggai_create_agent()
  tool_names <- vapply(agent$tools, function(t) t$name, character(1))
  expect_true("ggai_execute_r" %in% tool_names)
  expect_true("ggai_validate_artifact" %in% tool_names)
  expect_true("ggai_save_artifact" %in% tool_names)
})

test_that("ggai_create_agent accepts an extra_tools list", {
  z <- ggai_schema_funs()
  tool <- ggai_aisdk("tool")
  extra <- tool(
    name = "marker_tool",
    description = "Test marker tool.",
    parameters = z$z_object(
      x = z$z_string(description = "ignored")
    ),
    execute = function(x) list(echo = x)
  )
  agent <- ggai_create_agent(extra_tools = list(extra))
  tool_names <- vapply(agent$tools, function(t) t$name, character(1))
  expect_true("marker_tool" %in% tool_names)
})

test_that("state is shared between verb tools and the agent attribute", {
  state <- ggai_tool_state()
  agent <- ggai_create_agent(state = state)

  exec_tool <- Filter(
    function(t) identical(t$name, "ggai_execute_r"),
    agent$tools
  )[[1L]]
  skip_if_not_installed("ggplot2")
  exec_tool$run(list(
    code = 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  ))
  expect_true(is_ggai_artifact(state$last_artifact))
  expect_identical(attr(agent, "ggai_state")$last_artifact$id, state$last_artifact$id)
})

test_that("ggai_run_agent rejects non-Agent input", {
  expect_error(ggai_run_agent(NULL, "draw a scatter"), "must be an aisdk Agent")
  expect_error(ggai_run_agent("not an agent", "draw a scatter"), "must be an aisdk Agent")
})

test_that("ggai_run_agent rejects empty goal", {
  agent <- ggai_create_agent()
  expect_error(ggai_run_agent(agent, ""), "non-empty")
  expect_error(ggai_run_agent(agent, character()), "non-empty")
})
