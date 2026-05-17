# Capability probe used by skills to choose code-mode vs image-model-mode.

test_that("ggai_capability_status returns the expected shape", {
  cap <- ggai_capability_status()
  expect_named(
    cap,
    c("language_model", "language_provider", "language_available",
      "image_model", "image_provider", "image_available",
      "probed", "probe_results", "summary"),
    ignore.order = TRUE
  )
  expect_type(cap$summary, "character")
  expect_length(cap$summary, 1L)
  expect_true(grepl("^- language:", cap$summary))
  expect_true(grepl("\n- image:", cap$summary))
  expect_false(cap$probed)
  expect_identical(cap$probe_results, list())
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

# ---- live probe (mocked HTTP) --------------------------------------------

test_that("probe = TRUE marks routes reachable when probe returns non-404", {
  ggai:::ggai_probe_cache_clear()
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      list(status = 401L, reachable = TRUE, route = route, error = NULL)
    },
    .package = "ggai"
  )
  cap <- ggai_capability_status(probe = TRUE)
  expect_true(cap$probed)
  expect_true(cap$language_available)
  expect_true(cap$image_available)
  expect_identical(cap$probe_results$image$status, 401L)
  expect_match(cap$summary, "reachable")
})

test_that("classic 404 + Responses-API 401 falls back to responses_api (image available)", {
  ggai:::ggai_probe_cache_clear()
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      # Mimic a proxy that drops /v1/images/generations (404) but serves
      # /v1/responses (401 without auth, which the probe interprets as
      # "route exists"). ggai_generate_image() has the same fallback.
      status <- if (grepl("images/generations", route)) 404L else 401L
      list(status = status, reachable = status != 404L, route = route, error = NULL)
    },
    .package = "ggai"
  )
  cap <- ggai_capability_status(probe = TRUE)
  expect_true(cap$language_available)
  expect_true(cap$image_available)
  expect_identical(cap$probe_results$image$via, "responses_api")
  expect_match(cap$summary, "via responses_api", fixed = TRUE)
})

test_that("both classic AND Responses unreachable → image_available = FALSE", {
  ggai:::ggai_probe_cache_clear()
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      # Language route works (401 = exists, auth needed); image routes all 404.
      if (grepl("chat/completions", route, fixed = TRUE)) {
        return(list(status = 401L, reachable = TRUE, route = route, error = NULL))
      }
      list(status = 404L, reachable = FALSE, route = route, error = NULL)
    },
    .package = "ggai"
  )
  cap <- ggai_capability_status(probe = TRUE)
  expect_true(cap$language_available)
  expect_false(cap$image_available)
  expect_match(cap$summary, "UNREACHABLE")
})

test_that("probe cache reuses results within TTL", {
  ggai:::ggai_probe_cache_clear()
  call_count <- 0L
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      call_count <<- call_count + 1L
      list(status = 401L, reachable = TRUE, route = route, error = NULL)
    },
    .package = "ggai"
  )
  cap1 <- ggai_capability_status(probe = TRUE, ttl = 60L)
  first_count <- call_count
  cap2 <- ggai_capability_status(probe = TRUE, ttl = 60L)
  expect_equal(call_count, first_count, info = "cache should serve second call")
  expect_true(isTRUE(cap2$probe_results$language$cached))
})

test_that("refresh = TRUE busts the cache", {
  ggai:::ggai_probe_cache_clear()
  call_count <- 0L
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      call_count <<- call_count + 1L
      list(status = 401L, reachable = TRUE, route = route, error = NULL)
    },
    .package = "ggai"
  )
  ggai_capability_status(probe = TRUE)
  before <- call_count
  ggai_capability_status(probe = TRUE, refresh = TRUE)
  expect_gt(call_count, before)
})

test_that("probe skipped for providers without a route mapping", {
  ggai:::ggai_probe_cache_clear()
  # Force a gemini image model + key, so config check passes but the probe
  # finds no route mapping and reports reachable = NA.
  withr::with_envvar(
    list(GEMINI_API_KEY = "sk-fake"),
    withr::with_options(list(ggai.image_model = "gemini:gemini-vision-1"), {
      cap <- ggai_capability_status(probe = TRUE)
      expect_true("image" %in% names(cap$probe_results))
      expect_identical(cap$probe_results$image$reachable, NA)
      expect_match(cap$probe_results$image$error, "no route mapped")
      # availability falls back to the config-only result (TRUE)
      expect_true(cap$image_available)
    })
  )
})

test_that("network errors collapse to reachable = FALSE with the error string", {
  ggai:::ggai_probe_cache_clear()
  local_mocked_bindings(
    probe_http_route = function(route, timeout = 5L, max_tries = 2L) {
      list(status = NA_integer_, reachable = FALSE, route = route,
           error = "SSL connect error [host]")
    },
    .package = "ggai"
  )
  cap <- ggai_capability_status(probe = TRUE)
  expect_false(cap$image_available)
  expect_match(cap$summary, "SSL connect error")
})

test_that("probe = FALSE preserves the original config-only behaviour", {
  ggai:::ggai_probe_cache_clear()
  cap <- ggai_capability_status()
  expect_false(cap$probed)
  expect_identical(cap$probe_results, list())
  expect_false(grepl("reachable|UNREACHABLE", cap$summary))
})
