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

plot_op_call <- function(op_name, params) {
  if (identical(op_name, "theme_preset")) {
    preset <- params$name %||% "minimal"
    fun_name <- switch(
      preset,
      minimal = "theme_minimal",
      classic = "theme_classic",
      bw = "theme_bw",
      light = "theme_light",
      gray = "theme_gray",
      grey = "theme_grey",
      NULL
    )
    if (is.null(fun_name) || !exists(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE)) {
      rlang::abort(paste0("Unsupported theme preset: ", preset))
    }
    return(do.call(get(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE), list()))
  }

  fun_name <- switch(
    op_name,
    theme = "theme",
    labels = "labs",
    scale_colour = "scale_colour_manual",
    scale_fill = "scale_fill_manual",
    scale_x = "scale_x_continuous",
    scale_y = "scale_y_continuous",
    guides = "guides",
    NULL
  )

  if (is.null(fun_name) || !exists(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE)) {
    rlang::abort(paste0("Unsupported plot operation: ", op_name))
  }

  fun <- get(fun_name, envir = asNamespace("ggplot2"), inherits = FALSE)
  params <- params %||% list()
  params <- params[!vapply(params, is.null, logical(1))]

  if (op_name %in% c("scale_x", "scale_y") && !is.null(params$trans)) {
    params$transform <- params$trans
    params$trans <- NULL
  }

  do.call(fun, params)
}

apply_plot_ops <- function(plot, spec) {
  ops <- spec$plot_ops %||% list()
  if (!length(ops)) {
    return(plot)
  }

  out <- plot
  for (op in ops) {
    out <- out + plot_op_call(op$op %||% "", op$params %||% list())
  }
  out
}
