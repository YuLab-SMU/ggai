test_that("glyph cache key is stable for same prompt and style", {
  a <- ggai:::glyph_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)
  b <- ggai:::glyph_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)

  expect_equal(a, b)
})

test_that("glyph_ai returns a cached descriptor with mocked image generation", {
  tmp <- tempfile(fileext = ".png")
  writeBin(as.raw(c(137, 80, 78, 71)), tmp)

  old <- options(ggai.cache_dir = tempdir())
  on.exit(options(old), add = TRUE)
  local_mocked_bindings(
    ggai_generate_image = function(...) {
      list(images = list(list(path = tmp, media_type = "image/png")))
    },
    .package = "ggai"
  )

  asset <- glyph_ai("cell icon", cache = TRUE)

  expect_true(file.exists(asset$path))
  expect_s3_class(asset, "ggai_glyph_asset")
})
