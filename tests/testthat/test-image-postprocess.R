test_that("ggai_remove_background auto-keys a near-white background and crops to subject", {
  skip_if_not_installed("png")

  # 64x64 image: white background with a small dark subject in the middle.
  rgba <- array(1, dim = c(64L, 64L, 4L))         # all white, alpha = 1
  rgba[28:36, 28:36, 1:3] <- 0.1                  # 9x9 dark subject

  src <- tempfile(fileext = ".png")
  png::writePNG(rgba, src)

  out <- ggai_remove_background(src)
  expect_true(file.exists(out))

  result <- png::readPNG(out)

  expect_true(dim(result)[1] < 64L)
  expect_true(dim(result)[2] < 64L)
  expect_true(any(result[, , 4] > 0.95))  # subject pixels remain opaque
})

test_that("ggai_remove_background returns NULL when the file is unreadable", {
  expect_null(ggai_remove_background(tempfile(fileext = ".png")))
})

test_that("ggai_remove_background honours a custom output_path", {
  skip_if_not_installed("png")

  rgba <- array(1, dim = c(32L, 32L, 4L))
  rgba[14:18, 14:18, 1:3] <- 0.2
  src <- tempfile(fileext = ".png")
  png::writePNG(rgba, src)

  custom <- tempfile(fileext = ".png")
  out <- ggai_remove_background(src, output_path = custom)

  expect_equal(out, custom)
  expect_true(file.exists(custom))
})

test_that("ggai_remove_background keys off an explicit #00ff00 chroma background", {
  skip_if_not_installed("png")

  # 64x64 with pure-green chroma-key background, gray subject in the middle.
  rgba <- array(0, dim = c(64L, 64L, 4L))
  rgba[, , 2] <- 1                                  # all-green background
  rgba[, , 4] <- 1                                  # fully opaque
  rgba[26:38, 26:38, 1:3] <- 0.2                    # 13x13 gray subject

  src <- tempfile(fileext = ".png")
  png::writePNG(rgba, src)

  out <- ggai_remove_background(src, key_color = "#00ff00")
  expect_true(file.exists(out))

  result <- png::readPNG(out)
  expect_true(any(result[, , 4] > 0.95))            # subject still opaque
  expect_true(dim(result)[1] < 64L && dim(result)[2] < 64L)
})

test_that("ggai_remove_background despills the key colour from edge pixels", {
  skip_if_not_installed("png")

  # 32x32 green field with a yellow-green edge band (R=0.5, G=0.9, B=0.3) —
  # which would survive a hard threshold but should be partially-transparent
  # under soft matte + dominance.
  rgba <- array(0, dim = c(32L, 32L, 4L))
  rgba[, , 2] <- 1
  rgba[, , 4] <- 1
  rgba[10:22, 10:22, 1] <- 0.5
  rgba[10:22, 10:22, 2] <- 0.9
  rgba[10:22, 10:22, 3] <- 0.3

  src <- tempfile(fileext = ".png")
  png::writePNG(rgba, src)

  out <- ggai_remove_background(src, key_color = "#00ff00", crop = FALSE)
  result <- png::readPNG(out)

  # Solid green corners → fully transparent.
  expect_equal(result[1, 1, 4], 0)
  # Yellow-green edge pixels → partial (not opaque) due to dominance alpha.
  edge_alpha <- result[15, 15, 4]
  expect_true(edge_alpha > 0 && edge_alpha < 0.95)
})

test_that("ggai_remove_background errors when soft-matte thresholds are inverted", {
  skip_if_not_installed("png")

  rgba <- array(1, dim = c(16L, 16L, 4L))
  src <- tempfile(fileext = ".png")
  png::writePNG(rgba, src)

  expect_error(
    ggai_remove_background(src, transparent_threshold = 0.9, opaque_threshold = 0.1),
    "transparent_threshold must be lower"
  )
})

test_that("parse_hex_color rejects malformed strings", {
  expect_error(ggai:::parse_hex_color("not-a-color"), "hex RGB")
  expect_equal(ggai:::parse_hex_color("#00ff00"), c(0, 1, 0))
  expect_equal(ggai:::parse_hex_color("ff00ff"), c(1, 0, 1))
})
