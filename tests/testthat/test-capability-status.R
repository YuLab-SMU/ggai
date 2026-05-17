# Capability probe used by skills to choose code-mode vs image-model-mode.

test_that("ggai_capability_status returns the expected shape", {
  cap <- ggai_capability_status()
  expect_named(
    cap,
    c("language_model", "language_provider", "language_available",
      "image_model", "image_provider", "image_available", "summary"),
    ignore.order = TRUE
  )
  expect_type(cap$summary, "character")
  expect_length(cap$summary, 1L)
  expect_true(grepl("^- language:", cap$summary))
  expect_true(grepl("\n- image:", cap$summary))
})

test_that("availability reflects the API-key env state", {
  cap <- ggai_capability_status()
  expect_type(cap$language_available, "logical")
  expect_type(cap$image_available, "logical")

  # If image_available is TRUE, the configured provider's env key must be set
  if (isTRUE(cap$image_available)) {
    env_name <- ggai:::provider_env_key(cap$image_provider)
    expect_false(is.na(env_name))
    expect_true(nzchar(Sys.getenv(env_name)))
  }
})

test_that("image_available reports FALSE when its env key is cleared", {
  cap <- ggai_capability_status()
  skip_if(is.null(cap$image_provider))
  env_name <- ggai:::provider_env_key(cap$image_provider)
  skip_if(is.na(env_name))

  withr::with_envvar(stats::setNames(list(""), env_name), {
    cap2 <- ggai_capability_status()
    expect_false(cap2$image_available)
    expect_true(grepl("not set", cap2$summary, fixed = TRUE))
  })
})

test_that("language and image identifiers match ggai_default_models()", {
  cap <- ggai_capability_status()
  defaults <- ggai_default_models()
  expect_identical(cap$language_model, defaults$language)
  expect_identical(cap$image_model, defaults$image)
})
