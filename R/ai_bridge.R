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

