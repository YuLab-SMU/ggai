test_that("session starts from a base ggplot", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  s <- start_ggai_session(p)

  expect_s3_class(s, "ggai_session")
  expect_s3_class(ggai:::session_current_plot(s), "ggplot")
  expect_equal(nrow(spec_history(s)), 0)
  ctx <- session_context(s)
  expect_equal(ctx$current_turn, 0L)
  expect_null(ctx$active_instruction)
})

test_that("session can adopt an existing ggai-augmented plot", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(geom = "text", mapping = list(x = "wt", y = "mpg", label = "carb"), params = list(colour = "red"), inherit_aes = FALSE)
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")
  s <- start_ggai_session(q)

  expect_equal(nrow(spec_history(s)), 1)
  expect_equal(spec_history(s)$kind[[1]], "layer")
})

test_that("gg_edit adds an initial compiled version", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "highlight",
        target_layer = "plot",
        layers = list(
          list(geom = "rect", mapping = list(), params = list(xmin = 1.5, xmax = 2.5, ymin = 27, ymax = 35, alpha = 0.1, fill = "#4DAF4A"), inherit_aes = FALSE)
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))
  s <- gg_edit(s, "highlight the high-efficiency cluster")

  expect_equal(nrow(spec_history(s)), 1)
  expect_s3_class(ggai:::session_current_plot(s), "ggplot")
  ctx <- session_context(s)
  expect_equal(ctx$current_turn, 1L)
  expect_equal(ctx$active_instruction, "highlight the high-efficiency cluster")
  expect_true(length(ggai:::session_turn_notes(s)) >= 1)
})

test_that("gg_edit can switch a session into polish mode", {
  captured <- new.env(parent = emptyenv())
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))

  local_mocked_bindings(
    polish_figure = function(x, instruction = NULL, image_model = NULL, ...) {
      captured$x <- x
      captured$instruction <- instruction
      captured$image_model <- image_model
      structure(list(kind = "polished", session = x), class = "ggai_polished_figure_result")
    },
    .package = "ggai"
  )

  res <- gg_edit(
    s,
    "turn this into a publication hero figure",
    mode = "polish",
    image_model = "openai:gpt-image-2"
  )

  expect_s3_class(res, "ggai_polished_figure_result")
  expect_identical(captured$x, s)
  expect_equal(captured$instruction, "turn this into a publication hero figure")
  expect_equal(captured$image_model, "openai:gpt-image-2")
})

test_that("spec_history includes polish artifacts alongside edit turns", {
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))
  s <- ggai:::session_record_artifact(
    s,
    list(
      kind = "polish",
      edit_mode = "whole_image_redraw",
      instruction = "make it camera-ready",
      timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE),
      turn = 0L,
      artifact_path = "/tmp/final.png"
    )
  )

  hist <- spec_history(s)
  expect_true(any(hist$kind == "polish"))
  expect_true(any(hist$artifact_path == "/tmp/final.png"))
})

test_that("artifacts helpers expose session artifact log", {
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))
  s <- ggai:::session_record_artifact(
    s,
    list(
      kind = "preview",
      edit_mode = "artifact",
      instruction = "draft preview",
      timestamp = "2026-04-25 10:00:00 UTC",
      turn = 0L,
      artifact_path = "/tmp/preview.png"
    )
  )
  s <- ggai:::session_record_artifact(
    s,
    list(
      kind = "polish",
      edit_mode = "whole_image_redraw",
      instruction = "camera ready",
      timestamp = "2026-04-25 10:05:00 UTC",
      turn = 0L,
      artifact_path = "/tmp/final.png"
    )
  )

  log <- artifacts(s)
  expect_length(log, 2)
  expect_equal(log[[2]]$artifact_path, "/tmp/final.png")

  latest <- latest_artifact(s)
  expect_equal(latest$kind, "polish")
  expect_equal(latest$artifact_path, "/tmp/final.png")

  latest_polish <- latest_artifact(s, kind = "polish")
  expect_equal(latest_polish$artifact_path, "/tmp/final.png")

  latest_missing <- latest_artifact(s, kind = "nonexistent")
  expect_null(latest_missing)
})

test_that("session tracks turn ancestry and state", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(geom = "text", mapping = list(x = "5.42", y = "12", label = "A"), params = list(colour = "red"), inherit_aes = FALSE)
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  entry <- ggai:::new_session_entry("label", compiled, ggai:::render_spec_compiled(compiled, plot = p), as_code(compiled), "compile")
  s <- ggai:::new_ggai_session(base_plot = p, history = list(entry), history_index = 1L)
  s <- gg_edit(s, "make the label smaller")

  expect_equal(s$history[[2]]$parent_turn, 1L)
  expect_type(s$history[[2]]$turn_context, "list")
  expect_equal(s$state$current_turn, 2L)
})

test_that("plot.ggai_session returns the current ggplot object", {
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))
  p <- plot(s)

  expect_s3_class(p, "ggplot")
})

test_that("gg_edit can patch filled rect into outline only", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "highlight",
      target_layer = "plot",
      layers = list(
        list(geom = "rect", mapping = list(), params = list(xmin = 1.5, xmax = 2.5, ymin = 27, ymax = 35, alpha = 0.1, fill = "#4DAF4A"), inherit_aes = FALSE)
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "highlight"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  entry <- ggai:::new_session_entry("highlight", compiled, ggai:::render_spec_compiled(compiled, plot = p), as_code(compiled), "compile")
  s <- ggai:::new_ggai_session(base_plot = p, history = list(entry), history_index = 1L)
  s <- gg_edit(s, "use outline only, not filled area")

  raw <- inspect_spec(s, raw = TRUE)
  expect_true(is.null(raw$layers[[1]]$params$alpha))
  expect_true(is.na(raw$layers[[1]]$params$fill))
  expect_equal(raw$layers[[1]]$params$colour, "#4DAF4A")
})

test_that("gg_edit can modify text size and position", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(geom = "text", mapping = list(x = "5.42", y = "12", label = "Heavy low-MPG outlier"), params = list(colour = "#E41A1C", size = 5), inherit_aes = FALSE)
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  entry <- ggai:::new_session_entry("label", compiled, ggai:::render_spec_compiled(compiled, plot = p), as_code(compiled), "compile")
  s <- ggai:::new_ggai_session(base_plot = p, history = list(entry), history_index = 1L)
  s <- gg_edit(s, "make the label smaller and move it upward")

  raw <- inspect_spec(s, raw = TRUE)
  expect_true(raw$layers[[1]]$params$size < 5)
  expect_equal(raw$layers[[1]]$mapping$y, "12.8")
})

test_that("undo restores the prior session version", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(geom = "text", mapping = list(x = "5.42", y = "12", label = "A"), params = list(colour = "red"), inherit_aes = FALSE)
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  entry <- ggai:::new_session_entry("label", compiled, ggai:::render_spec_compiled(compiled, plot = p), as_code(compiled), "compile")
  s <- ggai:::new_ggai_session(base_plot = p, history = list(entry), history_index = 1L)
  s <- gg_edit(s, "make the label smaller")
  expect_equal(nrow(spec_history(s)), 2)
  s <- undo(s)
  expect_equal(s$history_index, 1L)
  raw <- inspect_spec(s, raw = TRUE)
  expect_equal(raw$layers[[1]]$params$size %||% NULL, NULL)
})

test_that("session methods delegate to current version", {
  compiled <- ggai:::new_compiled_spec(
    spec = list(
      intent = "annotate",
      action = "label",
      target_layer = "plot",
      layers = list(
        list(geom = "text", mapping = list(x = "5.42", y = "12", label = "A"), params = list(colour = "red"), inherit_aes = FALSE)
      ),
      annotations = list(),
      warnings = list()
    ),
    kind = "layer",
    instruction = "label"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  entry <- ggai:::new_session_entry("label", compiled, ggai:::render_spec_compiled(compiled, plot = p), as_code(compiled), "compile")
  s <- ggai:::new_ggai_session(base_plot = p, history = list(entry), history_index = 1L)

  expect_match(as_code(s), "ggplot2::geom_text")
  expect_equal(inspect_spec(s)$kind, "layer")
  expect_s3_class(ggai:::session_current_plot(s), "ggplot")
})
