test_that("ggai resolves default language and image models", {
  cfg <- ggai_default_models()

  expect_named(cfg, c("language", "image"))
  expect_true(is.character(cfg$language))
  expect_true(is.character(cfg$image))
})

test_that("ggai can build an instruction compiler request object", {
  req <- new_layer_ai_request("highlight top outliers")

  expect_equal(req$instruction, "highlight top outliers")
  expect_equal(req$target, "layer")
})

test_that("bare provider-native model names are normalized to provider:model", {
  expect_equal(ggai:::normalize_model_id("gemini-3-flash-preview", type = "language"), "gemini:gemini-3-flash-preview")
  expect_equal(ggai:::normalize_model_id("gpt-image-1.5", type = "image"), "openai:gpt-image-1.5")
  expect_equal(ggai:::normalize_model_id("gemini:gemini-2.5-flash", type = "language"), "gemini:gemini-2.5-flash")
})
