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
    ns <- ggai_local_aisdk_env()
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

  fallback <- ggai_local_aisdk_env()
  exists(name, envir = fallback, inherits = FALSE)
}

ggai_aisdk_runtime_available <- function() {
  ggai_aisdk_has("generate_text")
}

ggai_generate_structured <- function(model,
                                     prompt,
                                     system,
                                     response_format,
                                     registry = NULL,
                                     parser = NULL) {
  if (!ggai_aisdk_runtime_available()) {
    rlang::abort(c(
      "The full `aisdk` runtime is not available for compiler execution.",
      i = "Install `aisdk` with its runtime dependencies to run real model-backed compilation."
    ))
  }

  generate_text <- ggai_aisdk("generate_text")
  response <- generate_text(
    model = model,
    prompt = prompt,
    system = system,
    response_format = response_format,
    registry = registry
  )

  response_text <- NULL
  if (is.function(parser)) {
    response_text <- tryCatch(
      response$text,
      error = function(...) NULL
    )
  }

  if (!is.null(response_text) && is.character(response_text) && nzchar(trimws(response_text)) && is.function(parser)) {
    return(parser(response_text))
  }

  response
}

#' Get the default language and image model identifiers
#'
#' @return A named list with `language` and `image`.
#' @export
ggai_default_models <- function() {
  list(
    language = normalize_model_id(
      getOption("ggai.language_model", Sys.getenv("GGAI_LANGUAGE_MODEL", "openai:gpt-5.2")),
      type = "language"
    ),
    image = normalize_model_id(
      getOption("ggai.image_model", Sys.getenv("GGAI_IMAGE_MODEL", "openai:gpt-image-1.5")),
      type = "image"
    )
  )
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

#' Build a new layer AI request
#'
#' @param instruction Natural-language visualization instruction.
#' @param target Compilation target. Defaults to `"layer"`.
#' @param context Optional list carrying plot context.
#'
#' @return A request list with class `ggai_layer_request`.
#' @export
new_layer_ai_request <- function(instruction, target = "layer", context = list()) {
  if (!is.character(instruction) || length(instruction) != 1 || !nzchar(instruction)) {
    rlang::abort("`instruction` must be a non-empty string.")
  }

  structure(
    list(
      instruction = instruction,
      target = target,
      context = context
    ),
    class = "ggai_layer_request"
  )
}
