# Layer-3 verb tools: aisdk Tool wrappers around the L2 primitives.

skip_if_not_installed("ggplot2")
skip_if_not_installed("aisdk")

test_that("ggai_create_verb_tools returns three named Tool objects", {
  tools <- ggai_create_verb_tools()
  expect_named(tools, c("execute_r", "validate_artifact", "save_artifact"))
  for (nm in names(tools)) {
    expect_s3_class(tools[[nm]], "Tool")
  }
})

test_that("execute_r tool runs and stores artifact in shared state", {
  state <- ggai_tool_state()
  tools <- ggai_create_verb_tools(state = state)
  out <- tools$execute_r$run(list(
    code = 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  ))
  expect_identical(out$engine, "ggplot")
  expect_true(is.character(out$artifact_id) && nzchar(out$artifact_id))
  expect_identical(out$validation_status, "ok")
  expect_true(is_ggai_artifact(state$last_artifact))
})

test_that("validate_artifact tool reads from shared state set by execute_r", {
  state <- ggai_tool_state()
  tools <- ggai_create_verb_tools(state = state)
  tools$execute_r$run(list(
    code = 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  ))
  v <- tools$validate_artifact$run(list())
  expect_identical(v$status, "ok")
  expect_identical(v$engine, "ggplot")
})

test_that("validate_artifact aborts when no artifact has been captured", {
  state <- ggai_tool_state()
  tools <- ggai_create_verb_tools(state = state)
  expect_error(
    tools$validate_artifact$run(list()),
    "No artifact in state"
  )
})

test_that("save_artifact persists code, rendered file, and manifest", {
  out_dir <- file.path(tempdir(), paste0("ggai_save_", as.integer(Sys.time())))
  withr::defer(unlink(out_dir, recursive = TRUE))

  state <- ggai_tool_state()
  tools <- ggai_create_verb_tools(state = state)
  tools$execute_r$run(list(
    code = 'ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()'
  ))
  paths <- tools$save_artifact$run(list(output_dir = out_dir))

  expect_true(file.exists(paths$code))
  expect_true(file.exists(paths$manifest))
  expect_true(any(grepl("\\.png$", unlist(paths))))
})

test_that("execute_r honours engine_hint", {
  state <- ggai_tool_state()
  tools <- ggai_create_verb_tools(state = state)
  out <- suppressWarnings(
    tools$execute_r$run(list(
      code = '1 + 1',
      engine_hint = "unknown"
    ))
  )
  expect_identical(out$engine, "unknown")
})
