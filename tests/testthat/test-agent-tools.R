test_that("ggai agent tools can be created without model calls", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  s <- start_ggai_session(p)

  tools <- create_ggai_agent_tools(data = mtcars, plot = p, session = s)

  expect_named(
    tools,
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
  expect_true(all(vapply(tools, function(x) inherits(x, "Tool"), logical(1))))
  expect_true(is.environment(attr(tools, "state")))
})

test_that("ggai agent tools can include upstream aisdk context tools", {
  sdk_session <- ggai:::ggai_create_context_session(model = "deepseek:test")
  skip_if(is.null(sdk_session), "aisdk shared context sessions are unavailable")
  sdk_session$set_var("mentioned_object", structure(list(cells = 1:3), class = "mock_sce"))

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  tools <- create_ggai_agent_tools(
    data = mtcars,
    plot = p,
    context_session = sdk_session
  )
  tool_names <- vapply(tools, function(tool) tool$name, character(1))

  expect_true("ggai_data_profile" %in% tool_names)
  expect_true("list_r_objects" %in% tool_names)
  expect_true("inspect_r_object" %in% tool_names)
  expect_true("context_search" %in% tool_names)
  expect_true("object_peek" %in% tool_names)

  listed <- tools$list_r_objects$run(list(), envir = sdk_session$get_envir())
  expect_match(listed, "mentioned_object")
})

test_that("data, plot, and session inspection tools execute locally", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  s <- start_ggai_session(p)
  tools <- create_ggai_agent_tools(data = mtcars, plot = p, session = s)

  profile <- tools$data_profile$run(list(columns = c("wt", "mpg"), include_preview = TRUE, preview_n = 2))
  expect_equal(profile$nrow, nrow(mtcars))
  expect_equal(profile$ncol, 2)
  expect_named(profile$columns, c("wt", "mpg"))
  expect_equal(nrow(profile$preview), 2)

  plot_info <- tools$plot_inspection$run(list())
  expect_true("mapped_aes" %in% names(plot_info$plot_context))

  session_info <- tools$session_inspection$run(list())
  expect_equal(session_info$current_turn, 0L)

  stats <- tools$stat_method_selection$run(list(goal = "show relationship between wt and mpg"))
  expect_equal(stats$method_selection$family, "correlation")
  expect_equal(stats$method_selection$method, "pearson_correlation")

  package <- tools$package_check$run(list(package = "stats"))
  expect_equal(package$status, "available")
  help <- tools$help_inspection$run(list(package = "stats", topic = "lm"))
  expect_equal(help$status, "ok")

  source <- tools$source_url_detection$run(list(text = "See https://github.com/org/repo"))
  expect_equal(source$github[[1]]$repo, "repo")
})

test_that("diagram_compilation tool wraps the spec-committer agent", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()

  local_mocked_bindings(
    compile_diagram_spec = function(...) {
      list(
        canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
        nodes = list(list(id = "a", kind = "box", label = "A", style = list())),
        edges = list(),
        annotations = list()
      )
    },
    .package = "ggai"
  )

  tools <- create_ggai_agent_tools(plot = p)

  diagram <- tools$diagram_compilation$run(list(instruction = "draw one node"))
  expect_equal(diagram$summary$kind, "diagram")
  expect_equal(diagram$summary$node_count, 1)
  expect_equal(diagram$spec$nodes[[1]]$id, "a")
})

test_that("plot validation and artifact recording tools execute locally", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  s <- start_ggai_session(p)
  tools <- create_ggai_agent_tools(plot = p, session = s)

  validation <- tools$plot_validation$run(list())
  expect_equal(validation$status, "ok")
  expect_equal(validation$layer_count, 1)

  recorded <- tools$artifact_recording$run(list(
    kind = "plot",
    instruction = "validate plot",
    artifact_path = "/tmp/plot.png",
    metadata = list(width = 800)
  ))

  expect_equal(recorded$artifact$status, "recorded")
  expect_equal(recorded$artifact_count, 1)
  state <- attr(tools, "state")
  expect_equal(length(ggai:::session_artifact_log(state$session)), 1)
})

test_that("plot validation captures ggplot messages instead of printing them", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_smooth()

  validation <- expect_silent(ggai:::ggai_agent_validate_plot(p))

  expect_equal(validation$status, "ok")
  expect_match(paste(validation$messages, collapse = "\n"), "geom_smooth")
})
