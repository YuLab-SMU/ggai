# Normalize a model identifier into `provider:model` form when possible.
normalize_model_id <- function(model, type = c("language", "image")) {
  type <- match.arg(type)

  if (!is.character(model) || length(model) != 1 || !nzchar(model)) {
    return(model)
  }

  if (grepl("^[A-Za-z0-9_.-]+:.+$", model)) {
    return(model)
  }

  if (grepl("^gemini", model, ignore.case = TRUE)) {
    return(paste0("gemini:", model))
  }
  if (grepl("^gpt-image|^dall-e", model, ignore.case = TRUE)) {
    return(paste0("openai:", model))
  }
  if (grepl("^gpt|^o[0-9]|^o1|^o3", model, ignore.case = TRUE)) {
    return(paste0("openai:", model))
  }
  if (grepl("^claude", model, ignore.case = TRUE)) {
    return(paste0("anthropic:", model))
  }

  model
}

ggai_aisdk_cache <- new.env(parent = emptyenv())

ggai_local_aisdk_env <- function() {
  cached <- ggai_aisdk_cache$env
  if (!is.null(cached)) {
    return(cached)
  }

  path <- ggai_aisdk_path()
  schema_file <- file.path(path, "R", "schema.R")
  if (!file.exists(schema_file)) {
    rlang::abort(c(
      "Unable to load fallback `aisdk` schema helpers.",
      i = paste0("Expected file: ", schema_file)
    ))
  }

  env <- new.env(parent = baseenv())
  sys.source(schema_file, envir = env, keep.source = FALSE)
  ggai_aisdk_cache$env <- env
  env
}

ggai_load_local_aisdk_namespace <- function() {
  path <- ggai_aisdk_path()
  if (!dir.exists(path) || !requireNamespace("pkgload", quietly = TRUE)) {
    return(NULL)
  }

  loaded <- tryCatch(
    {
      pkgload::load_all(path = path, export_all = FALSE, helpers = FALSE, quiet = TRUE)
      TRUE
    },
    error = function(...) FALSE
  )

  if (loaded && "aisdk" %in% loadedNamespaces()) {
    return(asNamespace("aisdk"))
  }

  NULL
}

ggai_aisdk_ns <- function() {
  if (requireNamespace("aisdk", quietly = TRUE)) {
    return(asNamespace("aisdk"))
  }

  path <- ggai_aisdk_path()
  if (!dir.exists(path)) {
    rlang::abort(c(
      "`aisdk` is required for ggai structured specs and compiler support.",
      i = paste0("Install `aisdk` or point `options(ggai.aisdk_path = '...', )` to a local checkout. Missing path: ", path)
    ))
  }

  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(ggai_local_aisdk_env())
  }

  loaded <- tryCatch(
    {
      pkgload::load_all(path = path, export_all = FALSE, helpers = FALSE, quiet = TRUE)
      TRUE
    },
    error = function(...) FALSE
  )

  if (loaded && "aisdk" %in% loadedNamespaces()) {
    return(asNamespace("aisdk"))
  }

  ggai_local_aisdk_env()
}

ggai_aisdk <- function(name) {
  ns <- ggai_aisdk_ns()
  if (!exists(name, envir = ns, inherits = FALSE)) {
    local_ns <- ggai_load_local_aisdk_namespace()
    ns <- local_ns %||% ggai_local_aisdk_env()
  }

  if (!exists(name, envir = ns, inherits = FALSE)) {
    rlang::abort(c(
      paste0("The requested `aisdk` helper is not available: ", name),
      i = "Install `aisdk` as a package for the full runtime bridge, or keep using features that only need the schema fallback."
    ))
  }

  get(name, envir = ns, inherits = FALSE)
}

ggai_aisdk_has <- function(name) {
  ns <- ggai_aisdk_ns()
  if (exists(name, envir = ns, inherits = FALSE)) {
    return(TRUE)
  }

  local_ns <- ggai_load_local_aisdk_namespace()
  if (!is.null(local_ns) && exists(name, envir = local_ns, inherits = FALSE)) {
    return(TRUE)
  }

  fallback <- ggai_local_aisdk_env()
  exists(name, envir = fallback, inherits = FALSE)
}

ggai_aisdk_runtime_available <- function() {
  ggai_aisdk_has("generate_text")
}

ggai_model_provider <- function(model) {
  if (!is.character(model) || length(model) != 1 || !nzchar(model)) {
    return(NULL)
  }

  parts <- strsplit(model, ":", fixed = TRUE)[[1]]
  if (length(parts) < 2) {
    return(NULL)
  }
  tolower(parts[[1]])
}

ggai_aisdk_default_model <- function() {
  model <- NULL
  if (requireNamespace("aisdk", quietly = TRUE)) {
    get_model <- tryCatch(
      get("get_model", envir = asNamespace("aisdk"), inherits = FALSE),
      error = function(...) NULL
    )
    if (is.function(get_model)) {
      model <- tryCatch(get_model(default = NULL), error = function(...) NULL)
    }
  }
  model <- model %||% getOption("aisdk.default_model", NULL)
  if (is.character(model) && length(model) == 1L && nzchar(model)) {
    return(model)
  }
  NULL
}

ggai_model_option_name <- function(type = c("language", "image")) {
  type <- match.arg(type)
  switch(
    type,
    language = "ggai.language_model",
    image = "ggai.image_model"
  )
}

ggai_validate_default_model <- function(model, type = c("language", "image")) {
  type <- match.arg(type)
  if (is.null(model)) {
    return(NULL)
  }
  if (!is.character(model) || length(model) != 1L || !nzchar(model)) {
    rlang::abort("`model` must be NULL or a single non-empty model identifier string.")
  }
  normalize_model_id(model, type = type)
}

ggai_set_aisdk_default_model <- function(model) {
  if (requireNamespace("aisdk", quietly = TRUE)) {
    set_model <- tryCatch(
      get("set_model", envir = asNamespace("aisdk"), inherits = FALSE),
      error = function(...) NULL
    )
    if (is.function(set_model)) {
      set_model(model)
      return(invisible(TRUE))
    }
  }
  options(aisdk.default_model = model)
  invisible(TRUE)
}

#' Get the default language and image model identifiers
#'
#' @return A named list with `language` and `image`.
#' @export
ggai_default_models <- function() {
  language <- getOption(
    "ggai.language_model",
    ggai_aisdk_default_model() %||%
      ggai_env_value(c("OPENAI_MODEL", "GGAI_LANGUAGE_MODEL"), default = "openai:gpt-5.2")
  )
  image <- getOption("ggai.image_model", NULL)
  if (is.null(image)) {
    image <- ggai_env_value("OPENAI_IMAGE_MODEL", default = NULL)
  }
  if (is.null(image) &&
      is.character(language) &&
      grepl("^openai:", normalize_model_id(language, type = "language"))) {
    image <- "openai:gpt-image-2"
  }
  if (is.null(image)) {
    image <- ggai_env_value("GGAI_IMAGE_MODEL", default = "openai:gpt-image-2")
  }

  list(
    language = normalize_model_id(language, type = "language"),
    image = normalize_model_id(image, type = "image")
  )
}

#' Get the current ggai default model
#'
#' @param type Which model default to read: `"language"` or `"image"`.
#'
#' @return A model identifier string.
#' @export
ggai_get_model <- function(type = c("language", "image")) {
  type <- match.arg(type)
  ggai_default_models()[[type]]
}

#' Set the current ggai default model
#'
#' `ggai_set_model()` is the ggai equivalent of `aisdk::set_model()` for the
#' active R session. Language model changes are also mirrored to aisdk's default
#' model option so `aisdk::console_chat()` and ggai can share the same default.
#'
#' @param model A model identifier such as `"deepseek:deepseek-v4-flash"`.
#'   Use `NULL` to clear the current ggai override.
#' @param type Which default to set: `"language"` or `"image"`.
#' @param sync_aisdk If `TRUE`, language model changes are mirrored to
#'   `aisdk::set_model()` or `options(aisdk.default_model=...)`.
#'
#' @return Invisibly returns the previous model identifier for the selected
#'   type.
#' @export
ggai_set_model <- function(model = NULL,
                           type = c("language", "image"),
                           sync_aisdk = TRUE) {
  type <- match.arg(type)
  old <- ggai_get_model(type)
  model <- ggai_validate_default_model(model, type = type)
  option_name <- ggai_model_option_name(type)
  option_update <- stats::setNames(list(model), option_name)
  do.call(options, option_update)

  if (identical(type, "language") && isTRUE(sync_aisdk)) {
    ggai_set_aisdk_default_model(model)
  }

  invisible(old)
}

#' Get the default ggai language model identifier or resolved model
#'
#' @param model Optional `provider:model` identifier or model object.
#' @param resolve If `TRUE`, resolve through `aisdk`.
#' @param registry Optional provider registry passed to `aisdk`.
#'
#' @return A model identifier or resolved model object.
#' @export
ggai_language_model <- function(model = NULL, resolve = FALSE, registry = NULL) {
  model <- normalize_model_id(model %||% ggai_default_models()$language, type = "language")
  if (!resolve) {
    return(model)
  }

  ggai_aisdk("resolve_model")(model = model, registry = registry, type = "language")
}

#' Get the default ggai image model identifier or resolved model
#'
#' @param model Optional `provider:model` identifier or image model object.
#' @param resolve If `TRUE`, resolve through `aisdk`.
#' @param registry Optional provider registry passed to `aisdk`.
#'
#' @return A model identifier or resolved image model object.
#' @export
ggai_image_model <- function(model = NULL, resolve = FALSE, registry = NULL) {
  model <- normalize_model_id(model %||% ggai_default_models()$image, type = "image")
  if (!resolve) {
    return(model)
  }

  ggai_aisdk("resolve_model")(model = model, registry = registry, type = "image")
}

# Map providers to the env var that holds their API key. Returns NA for
# providers that don't take a key (e.g. local Ollama). Used by
# `ggai_capability_status()`.
provider_env_key <- function(provider) {
  if (is.null(provider) || !is.character(provider) || !nzchar(provider)) {
    return(NA_character_)
  }
  switch(
    provider,
    openai    = "OPENAI_API_KEY",
    anthropic = "ANTHROPIC_API_KEY",
    gemini    = "GEMINI_API_KEY",
    deepseek  = "DEEPSEEK_API_KEY",
    bailian   = "DASHSCOPE_API_KEY",
    aihubmix  = "AIHUBMIX_API_KEY",
    NA_character_
  )
}

env_var_set <- function(env) {
  if (is.na(env) || !is.character(env) || !nzchar(env)) {
    return(FALSE)
  }
  nzchar(Sys.getenv(env))
}

#' Report which figure-generation capabilities are configured
#'
#' Returns a snapshot the agent (and skills) consult to decide between
#' **code mode** (write ggplot / grid R via `ggai_execute_r`) and **image-model
#' mode** (call `ggai_generate_image()` / `polish_figure()`).
#'
#' With `probe = FALSE` (the default), the check is config-only — fast,
#' offline, and based on `ggai_default_models()` plus the presence of the
#' provider's API-key env var. A capability is `available = TRUE` when the
#' identifier resolves and the key env is set.
#'
#' With `probe = TRUE`, each configured capability is verified by issuing a
#' lightweight `HEAD` request against the provider's endpoint. A `404` means
#' the route is missing (the configured proxy doesn't serve that capability);
#' any other response (`200`, `401`, `405`, ...) means the route exists and
#' the capability is reachable. Probe results are cached in-process for `ttl`
#' seconds so repeated calls within the same turn don't pay the round-trip.
#' Use `refresh = TRUE` to bust the cache.
#'
#' Fields:
#' \itemize{
#'   \item `language_model`, `language_provider`, `language_available`
#'   \item `image_model`, `image_provider`, `image_available`
#'   \item `probed` — `TRUE` when at least one probe ran this call.
#'   \item `probe_results` — per-capability `list(status, reachable, route, cached, error)` when `probe = TRUE`.
#'   \item `summary` — short human-readable text snippet suitable for the agent to log or reason over.
#' }
#'
#' Edge cases:
#' \itemize{
#'   \item Providers that do not require an API key (e.g. local Ollama) currently report `available = FALSE`.
#'   \item Providers without a known route mapping (`anthropic` for images, `gemini`, `bailian`) are skipped under `probe = TRUE`; the config-only result is used.
#'   \item Network errors or timeouts during probe collapse to `reachable = FALSE`.
#' }
#'
#' @param probe If `TRUE`, perform a live HEAD reachability check per
#'   configured capability. Default `FALSE` (config-only, no network).
#' @param refresh If `TRUE`, bust the probe cache and re-probe.
#' @param ttl Probe cache time-to-live in seconds. Default `60`.
#' @param timeout Per-probe request timeout in seconds. Default `5`.
#'
#' @return A named list as described above.
#' @export
#'
#' @examples
#' \dontrun{
#' status <- ggai_capability_status()
#' if (!status$image_available) message("Image model not configured.")
#'
#' # Verify the endpoint actually serves the image route:
#' status <- ggai_capability_status(probe = TRUE)
#' if (!status$image_available) message("Image route unreachable; using code mode.")
#' }
ggai_capability_status <- function(probe = FALSE,
                                   refresh = FALSE,
                                   ttl = 60L,
                                   timeout = 5L) {
  models <- ggai_default_models()
  lang <- models$language
  img <- models$image

  lang_provider <- if (is.character(lang) && length(lang) == 1L && nzchar(lang)) {
    ggai_model_provider(lang)
  } else {
    NULL
  }
  img_provider <- if (is.character(img) && length(img) == 1L && nzchar(img)) {
    ggai_model_provider(img)
  } else {
    NULL
  }

  lang_key_env <- provider_env_key(lang_provider)
  img_key_env <- provider_env_key(img_provider)

  lang_config <- isTRUE(env_var_set(lang_key_env))
  img_config <- isTRUE(env_var_set(img_key_env))

  lang_available <- lang_config
  img_available <- img_config
  probe_results <- list()
  probed_any <- FALSE

  if (isTRUE(probe)) {
    if (lang_config) {
      probe_results$language <- probe_capability(
        provider = lang_provider, type = "language",
        refresh = refresh, ttl = ttl, timeout = timeout
      )
      if (!is.na(probe_results$language$reachable)) {
        lang_available <- isTRUE(probe_results$language$reachable)
      }
      probed_any <- TRUE
    }
    if (img_config) {
      probe_results$image <- probe_capability(
        provider = img_provider, type = "image",
        refresh = refresh, ttl = ttl, timeout = timeout
      )
      if (!is.na(probe_results$image$reachable)) {
        img_available <- isTRUE(probe_results$image$reachable)
      }
      probed_any <- TRUE
    }
  }

  describe <- function(label, model, config_ok, available, key_env, pres) {
    if (is.null(model) || !nzchar(model)) {
      return(paste0("- ", label, ": (not configured)"))
    }
    status <- if (!isTRUE(config_ok)) {
      if (is.na(key_env)) "no key env mapped" else paste0("key env ", key_env, " not set")
    } else if (is.null(pres)) {
      "configured"
    } else if (is.na(pres$reachable)) {
      paste0("configured; probe skipped (", pres$error %||% "no route mapped", ")")
    } else if (isTRUE(pres$reachable)) {
      paste0("configured; reachable (HTTP ", pres$status %||% "?", ")")
    } else {
      paste0("configured; UNREACHABLE (HTTP ", pres$status %||% "?",
             ifelse(!is.null(pres$error), paste0("; ", pres$error), ""), ")")
    }
    paste0("- ", label, ": ", model, " [", status, "]")
  }

  summary <- paste(
    describe("language", lang, lang_config, lang_available, lang_key_env, probe_results$language),
    describe("image",    img,  img_config,  img_available,  img_key_env,  probe_results$image),
    sep = "\n"
  )

  list(
    language_model = lang,
    language_provider = lang_provider,
    language_available = lang_available,
    image_model = img,
    image_provider = img_provider,
    image_available = img_available,
    probed = probed_any,
    probe_results = probe_results,
    summary = summary
  )
}

# ---- live probe helpers --------------------------------------------------

# Package-local in-process cache for probe results. Keyed by
# "provider|base_url|type"; entries carry the `cached_at` Sys.time() so the
# TTL check can drop stale rows.
ggai_probe_cache <- new.env(parent = emptyenv())

ggai_probe_cache_key <- function(provider, base_url, type) {
  paste(provider %||% "?", base_url %||% "", type, sep = "|")
}

ggai_probe_cache_get <- function(key, ttl) {
  entry <- ggai_probe_cache[[key]]
  if (is.null(entry)) {
    return(NULL)
  }
  age <- as.numeric(difftime(Sys.time(), entry$cached_at, units = "secs"))
  if (age > ttl) {
    rm(list = key, envir = ggai_probe_cache)
    return(NULL)
  }
  entry$cached <- TRUE
  entry$age_seconds <- age
  entry
}

ggai_probe_cache_set <- function(key, value) {
  value$cached_at <- Sys.time()
  assign(key, value, envir = ggai_probe_cache)
  invisible(value)
}

#' @keywords internal
ggai_probe_cache_clear <- function() {
  rm(list = ls(envir = ggai_probe_cache), envir = ggai_probe_cache)
  invisible()
}

# Provider+capability -> base URL + route suffix. Only providers whose API is
# OpenAI-compatible (or has a known route) get a non-NULL return; other
# providers cause the probe to skip with `reachable = NA`.
provider_route <- function(provider, type) {
  if (is.null(provider) || !nzchar(provider)) {
    return(NULL)
  }
  base <- switch(
    provider,
    openai    = Sys.getenv("OPENAI_BASE_URL",   "https://api.openai.com/v1"),
    deepseek  = Sys.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1"),
    aihubmix  = Sys.getenv("AIHUBMIX_BASE_URL", "https://aihubmix.com/v1"),
    anthropic = Sys.getenv("ANTHROPIC_BASE_URL", "https://api.anthropic.com/v1"),
    NULL
  )
  if (is.null(base) || !nzchar(base)) {
    return(NULL)
  }
  base <- sub("/+$", "", base)

  suffix <- switch(
    paste(provider, type, sep = "/"),
    `openai/language`    = "/chat/completions",
    `openai/image`       = "/images/generations",
    `deepseek/language`  = "/chat/completions",
    `aihubmix/language`  = "/chat/completions",
    `aihubmix/image`     = "/images/generations",
    `anthropic/language` = "/messages",
    # anthropic has no image-generation API; gemini/bailian use non-REST routes
    NULL
  )
  if (is.null(suffix)) {
    return(NULL)
  }

  list(base_url = base, route = paste0(base, suffix))
}

# Probe an endpoint by sending a deliberately minimal `POST {}` (no auth).
# Returns list(status, reachable, route, error).
#
# Why POST instead of HEAD: many OpenAI-compatible proxies (including some
# Cloudflare/nginx-fronted ones) return 404 on HEAD even when POST works on
# the same route. POST with `{}` body and no Authorization header costs
# essentially nothing — the server short-circuits with 400/401/422 before
# touching the model — but reliably differentiates "route exists" from "route
# missing":
#
#   - 200 / 2xx       — route exists (rare without auth, but possible)
#   - 400 / 422       — route exists, body was rejected (most common)
#   - 401 / 403       — route exists, auth required (also common)
#   - 405             — route exists, method differs (defensive)
#   - 404             — route MISSING (the case we care about)
#   - network error   — unreachable
#
# `reachable = TRUE` when the response is anything other than 404. `NA` only
# when the probe could not run at all (httr2 missing).
probe_http_route <- function(route, timeout = 5L, max_tries = 2L) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    return(list(status = NA_integer_, reachable = NA, route = route,
                error = "httr2 not available"))
  }
  result <- tryCatch(
    {
      req <- httr2::request(route)
      req <- httr2::req_method(req, "POST")
      req <- httr2::req_headers(req, "Content-Type" = "application/json")
      req <- httr2::req_body_raw(req, charToRaw("{}"))
      req <- httr2::req_timeout(req, timeout)
      # Transient errors (SSL handshake glitches, fresh connection pool) are
      # common on first try against custom proxies. Retry once with a short
      # backoff before giving up.
      req <- httr2::req_retry(req,
        max_tries = max(1L, as.integer(max_tries)),
        backoff = function(n) 0.5
      )
      req <- httr2::req_error(req, is_error = function(resp) FALSE)
      resp <- httr2::req_perform(req)
      list(status = httr2::resp_status(resp), reachable = NA, route = route, error = NULL)
    },
    error = function(e) {
      list(status = NA_integer_, reachable = FALSE, route = route,
           error = conditionMessage(e))
    }
  )
  if (is.na(result$status)) {
    result$reachable <- FALSE
  } else if (identical(result$status, 404L)) {
    result$reachable <- FALSE
  } else {
    result$reachable <- TRUE
  }
  result
}

# High-level: probe a (provider, type) capability, with caching.
probe_capability <- function(provider, type, refresh = FALSE,
                             ttl = 60L, timeout = 5L) {
  route_info <- provider_route(provider, type)
  if (is.null(route_info)) {
    return(list(
      status = NA_integer_, reachable = NA, route = NA_character_,
      error = paste0("no route mapped for ", provider %||% "?", "/", type),
      cached = FALSE
    ))
  }

  key <- ggai_probe_cache_key(provider, route_info$base_url, type)
  if (!isTRUE(refresh)) {
    cached <- ggai_probe_cache_get(key, ttl = ttl)
    if (!is.null(cached)) {
      return(cached)
    }
  }

  result <- probe_http_route(route_info$route, timeout = timeout)
  result$cached <- FALSE
  ggai_probe_cache_set(key, result)
  result
}

