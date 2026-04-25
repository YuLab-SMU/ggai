test_that("ggai resolves default language and image models", {
  old_image_env <- Sys.getenv("GGAI_IMAGE_MODEL", unset = NA_character_)
  old_image_opt <- getOption("ggai.image_model")
  on.exit({
    if (is.na(old_image_env)) {
      Sys.unsetenv("GGAI_IMAGE_MODEL")
    } else {
      Sys.setenv(GGAI_IMAGE_MODEL = old_image_env)
    }
    options(ggai.image_model = old_image_opt)
  }, add = TRUE)

  Sys.setenv(GGAI_IMAGE_MODEL = "openai:gpt-image-2")
  options(ggai.image_model = NULL)

  cfg <- ggai_default_models()

  expect_named(cfg, c("language", "image"))
  expect_true(is.character(cfg$language))
  expect_true(is.character(cfg$image))
  expect_equal(cfg$image, "openai:gpt-image-2")
})

test_that("ggai can build an instruction compiler request object", {
  req <- new_layer_ai_request("highlight top outliers")

  expect_equal(req$instruction, "highlight top outliers")
  expect_equal(req$target, "layer")
  expect_true(is.list(req$context))
  expect_true(inherits(req$runtime_request, "ggai_runtime_request"))
})

test_that("runtime request captures plot and session context", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  s <- start_ggai_session(p)

  req <- new_layer_ai_request(
    "label outliers",
    plot = p,
    session = s,
    context = list(source = "test")
  )

  expect_equal(req$context$extras$source, "test")
  expect_true("mapped_aes" %in% names(req$context$plot))
  expect_equal(req$context$session$current_turn, 0L)
})

test_that("layer compiler prompt includes session spine when available", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  s <- start_ggai_session(p)
  req <- new_layer_ai_request("highlight top outliers", plot = p, session = s)

  prompt <- ggai:::build_layer_compiler_prompt(req)

  expect_match(prompt$user, "Plot context:")
  expect_match(prompt$user, "Session context:")
  expect_match(prompt$user, "current_turn")
})

test_that("compile_layer_spec returns compiled spec wrapper", {
  local_mocked_bindings(
    compile_with_kind = function(...) {
      list(
        intent = "annotate",
        action = "highlight",
        target_layer = "plot",
        layers = list(),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  out <- ggai:::compile_layer_spec("highlight points")
  expect_s3_class(out, "ggai_compiled_spec")
  expect_equal(out$kind, "layer")
})

test_that("bare provider-native model names are normalized to provider:model", {
  expect_equal(ggai:::normalize_model_id("gemini-3-flash-preview", type = "language"), "gemini:gemini-3-flash-preview")
  expect_equal(ggai:::normalize_model_id("gpt-image-2", type = "image"), "openai:gpt-image-2")
  expect_equal(ggai:::normalize_model_id("gpt-image-1.5", type = "image"), "openai:gpt-image-1.5")
  expect_equal(ggai:::normalize_model_id("gemini:gemini-2.5-flash", type = "language"), "gemini:gemini-2.5-flash")
})
