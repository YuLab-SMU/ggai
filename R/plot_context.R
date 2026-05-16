mapping_names <- function(mapping) {
  if (is.null(mapping)) {
    return(character(0))
  }

  names(mapping)
}

ggai_mapping_labels <- function(mapping) {
  if (is.null(mapping) || !length(mapping)) {
    return(list())
  }

  out <- vector("list", length(mapping))
  nms <- names(mapping)
  for (i in seq_along(mapping)) {
    out[[i]] <- tryCatch(
      rlang::as_label(mapping[[i]]),
      error = function(...) safe_scalar_text(mapping[[i]])
    )
  }
  stats::setNames(out, nms)
}

safe_scalar_text <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }

  if (is.atomic(x) && length(x) == 1) {
    return(as.character(x))
  }

  tryCatch(
    paste(deparse(x), collapse = ""),
    error = function(...) NULL
  )
}

safe_plot_labels <- function(plot) {
  labels <- tryCatch(ggplot2::get_labs(plot), error = function(...) NULL)
  if (is.null(labels)) {
    return(list())
  }

  out <- list()
  for (nm in names(labels)) {
    value <- safe_scalar_text(labels[[nm]])
    if (!is.null(value) && nzchar(value)) {
      out[[nm]] <- value
    }
  }
  out
}

geom_name_from_layer <- function(layer) {
  if (is.null(layer$geom)) {
    return(NA_character_)
  }

  cls <- class(layer$geom)[1]
  tolower(sub("^Geom", "", cls))
}

ggai_layer_context <- function(layer) {
  list(
    geom = geom_name_from_layer(layer),
    stat = tolower(sub("^Stat", "", class(layer$stat)[1] %||% "")),
    position = tolower(sub("^Position", "", class(layer$position)[1] %||% "")),
    mapping = ggai_mapping_labels(layer$mapping)
  )
}

build_plot_context <- function(plot) {
  layer_geoms <- vapply(plot$layers, geom_name_from_layer, character(1))

  list(
    mapped_aes = mapping_names(plot$mapping),
    mapping = ggai_mapping_labels(plot$mapping),
    geoms = unique(stats::na.omit(layer_geoms)),
    layers = lapply(plot$layers %||% list(), ggai_layer_context),
    labels = safe_plot_labels(plot),
    facet = class(plot$facet)[1],
    coord = class(plot$coordinates)[1]
  )
}
