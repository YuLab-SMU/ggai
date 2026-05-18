test_that("asset cache key is stable for the same inputs", {
  a <- ggai:::ggai_asset_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)
  b <- ggai:::ggai_asset_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)

  expect_equal(a, b)
})

test_that("asset cache round-trip writes and reads the same image asset", {
  old <- options(ggai.cache_dir = tempfile("ggai_cache_"))
  on.exit(options(old), add = TRUE)

  src <- tempfile(fileext = ".png")
  writeBin(as.raw(c(137, 80, 78, 71)), src)

  key <- ggai:::ggai_asset_cache_key(prompt = "round-trip", style = "paper")
  put <- ggai:::ggai_asset_cache_put(src, key, metadata = list(prompt = "round-trip"))

  expect_s3_class(put, "ggai_image_asset")
  expect_true(file.exists(put$path))

  got <- ggai:::ggai_asset_cache_get(key)
  expect_s3_class(got, "ggai_image_asset")
  expect_equal(got$path, put$path)
  expect_equal(got$prompt, "round-trip")
})

test_that("geom_point_ai glyph helper caches the generated image", {
  tmp <- tempfile(fileext = ".png")
  writeBin(as.raw(c(137, 80, 78, 71)), tmp)

  old <- options(ggai.cache_dir = tempfile("ggai_cache_"))
  on.exit(options(old), add = TRUE)
  local_mocked_bindings(
    ggai_generate_image = function(...) {
      list(images = list(list(path = tmp, media_type = "image/png")))
    },
    # Mock chroma-key removal too so we don't try to parse a fake PNG.
    ggai_remove_background = function(path, ...) path,
    .package = "ggai"
  )

  asset <- ggai:::generate_glyph_for_geom("cell icon", cache = TRUE)

  expect_true(file.exists(asset$path))
  expect_s3_class(asset, "ggai_image_asset")
  expect_true(isTRUE(asset$chroma_keyed))
})

test_that("geom_point_ai glyph helper skips chroma-key when transparent_background = FALSE", {
  tmp <- tempfile(fileext = ".png")
  writeBin(as.raw(c(137, 80, 78, 71)), tmp)

  old <- options(ggai.cache_dir = tempfile("ggai_cache_"))
  on.exit(options(old), add = TRUE)

  remove_called <- FALSE
  local_mocked_bindings(
    ggai_generate_image = function(...) {
      list(images = list(list(path = tmp, media_type = "image/png")))
    },
    ggai_remove_background = function(path, ...) {
      remove_called <<- TRUE
      path
    },
    .package = "ggai"
  )

  asset <- ggai:::generate_glyph_for_geom("cell icon", cache = TRUE, transparent_background = FALSE)

  expect_false(remove_called)
  expect_false(isTRUE(asset$chroma_keyed))
})
