spec_mapping_to_aes <- function(mapping) {
  if (is.null(mapping) || !length(mapping)) {
    return(NULL)
  }

  exprs <- lapply(mapping, function(value) {
    value <- as.character(value)
    tryCatch(
      rlang::parse_expr(value),
      error = function(...) value
    )
  })
  do.call(ggplot2::aes, exprs)
}

geom_constructor <- function(name) {
  fun_name <- paste0("geom_", name)
  if (!exists(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE)) {
    rlang::abort(paste0("Unsupported ggplot2 geom in prototype compiler: ", name))
  }

  get(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE)
}

compile_single_layer <- function(spec, data = NULL) {
  geom_fun <- geom_constructor(spec$geom)
  mapping <- spec_mapping_to_aes(spec$mapping)

  args <- c(
    list(
      mapping = mapping,
      data = if (!is.null(spec$data)) spec$data else data,
      inherit.aes = isTRUE(spec$inherit_aes %||% TRUE)
    ),
    spec$params %||% list()
  )

  args <- args[!vapply(args, is.null, logical(1))]
  do.call(geom_fun, args)
}

compile_layer_spec_to_layers <- function(spec, data = NULL) {
  if (is.null(spec$layers) || !length(spec$layers)) {
    return(list())
  }

  lapply(spec$layers, compile_single_layer, data = data)
}
