infer_column_roles <- function(data) {
  nms <- names(data)
  is_num <- vapply(data, is.numeric, logical(1))
  numeric_cols <- nms[is_num]
  discrete_cols <- nms[!is_num]
  first_or_null <- function(x) if (length(x)) x[[1]] else NULL

  list(
    x = first_or_null(numeric_cols) %||% nms[[1]],
    y = (if (length(numeric_cols) >= 2) numeric_cols[[2]] else NULL) %||% first_or_null(numeric_cols) %||% nms[[min(2, length(nms))]],
    colour = first_or_null(discrete_cols)
  )
}

summarize_data_context <- function(data) {
  list(
    nrow = nrow(data),
    ncol = ncol(data),
    names = names(data),
    classes = stats::setNames(vapply(data, function(x) class(x)[1], character(1)), names(data))
  )
}

infer_plot_instruction <- function(data, instruction = NULL) {
  roles <- infer_column_roles(data)
  if (!is.null(instruction) && nzchar(instruction)) {
    return(list(instruction = instruction, roles = roles))
  }

  geom <- if (!is.null(roles$colour)) "scatter" else "scatter"
  inferred <- paste(
    geom,
    roles$x,
    "vs",
    roles$y,
    if (!is.null(roles$colour)) paste(", color by", roles$colour) else ""
  )
  list(instruction = inferred, roles = roles)
}

infer_chart_type <- function(data, instruction = NULL, roles = infer_column_roles(data)) {
  text <- tolower(trimws(instruction %||% ""))

  if (grepl("histogram|distribution|hist", text)) return("histogram")
  if (grepl("boxplot|box plot|compare .* across|grouped distribution", text)) return("boxplot")
  if (grepl("bar chart|bar plot|count of|counts by|frequency of", text)) return("bar")
  if (grepl("line chart|line plot|trend|over time|timeseries|time series", text)) return("line")
  if (grepl("scatter|vs|relationship|correlation", text)) return("scatter")

  if (!is.null(roles$colour)) return("scatter")
  if (!is.null(roles$x) && !is.null(roles$y)) return("scatter")
  "histogram"
}

build_initial_ggplot <- function(data, chart_type, roles) {
  if (identical(chart_type, "histogram")) {
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = !!rlang::sym(roles$x))) +
        ggplot2::geom_histogram(bins = 30)
    )
  }

  if (identical(chart_type, "boxplot")) {
    x_col <- roles$colour %||% roles$x
    y_col <- roles$y %||% roles$x
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = factor(!!rlang::sym(x_col)), y = !!rlang::sym(y_col), fill = factor(!!rlang::sym(x_col)))) +
        ggplot2::geom_boxplot()
    )
  }

  if (identical(chart_type, "bar")) {
    x_col <- roles$colour %||% roles$x
    return(
      ggplot2::ggplot(data, ggplot2::aes(x = factor(!!rlang::sym(x_col)), fill = factor(!!rlang::sym(x_col)))) +
        ggplot2::geom_bar()
    )
  }

  if (identical(chart_type, "line")) {
    mapping <- ggplot2::aes(x = !!rlang::sym(roles$x), y = !!rlang::sym(roles$y))
    return(ggplot2::ggplot(data, mapping) + ggplot2::geom_line())
  }

  mapping <- list(x = rlang::sym(roles$x), y = rlang::sym(roles$y))
  if (!is.null(roles$colour)) {
    mapping$colour <- rlang::expr(factor(!!rlang::sym(roles$colour)))
  }
  ggplot2::ggplot(data, do.call(ggplot2::aes, mapping)) + ggplot2::geom_point()
}

build_initial_plot <- function(data, instruction = NULL) {
  inferred <- infer_plot_instruction(data, instruction = instruction)
  roles <- inferred$roles
  chart_type <- infer_chart_type(data, instruction = instruction, roles = roles)
  plot <- build_initial_ggplot(data, chart_type = chart_type, roles = roles)
  list(plot = plot, inferred_instruction = inferred$instruction, roles = roles)
}

read_supported_data_file <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(
    ext,
    csv = utils::read.csv(path, stringsAsFactors = FALSE),
    tsv = utils::read.delim(path, stringsAsFactors = FALSE),
    txt = utils::read.delim(path, stringsAsFactors = FALSE),
    rds = readRDS(path),
    rlang::abort(paste0("Unsupported data file type: .", ext))
  )
}

#' Unified ggai entrypoint
#'
#' @param x A data frame, file path, ggplot object, or ggai session.
#' @param instruction Optional natural-language instruction.
#' @param mode Either `"session"` for the editable ggplot workflow or
#'   `"polish"` to enter the whole-image redraw path.
#' @param image_model Optional image model override used when `mode = "polish"`.
#' @param polish_instruction Optional polish direction for the final redraw. For
#'   `ggplot` and `ggai_session` inputs this defaults to `instruction` when
#'   omitted.
#' @param ... Passed through to [polish_figure()] when `mode = "polish"`.
#'
#' @return Either a `ggai_session` or a `ggai_polished_figure_result`.
#' @export
ggai <- function(x,
                 instruction = NULL,
                 mode = c("session", "polish"),
                 image_model = NULL,
                 polish_instruction = NULL,
                 ...) {
  mode <- match.arg(mode)
  UseMethod("ggai")
}

#' @export
ggai.data.frame <- function(x,
                            instruction = NULL,
                            mode = c("session", "polish"),
                            image_model = NULL,
                            polish_instruction = NULL,
                            ...) {
  mode <- match.arg(mode)
  built <- build_initial_plot(x, instruction = instruction)
  session <- start_ggai_session(built$plot)
  session <- session_record_turn_note(
    session,
    type = "ggai_init",
    value = list(
      source = "data.frame",
      instruction = built$inferred_instruction,
      data_context = summarize_data_context(x)
    )
  )
  session <- session_touch_state(session, instruction = built$inferred_instruction)

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction,
      image_model = image_model,
      ...
    ))
  }

  session
}

#' @export
ggai.character <- function(x,
                           instruction = NULL,
                           mode = c("session", "polish"),
                           image_model = NULL,
                           polish_instruction = NULL,
                           ...) {
  mode <- match.arg(mode)
  if (length(x) != 1 || !nzchar(x)) {
    rlang::abort("`x` must be a single file path string.")
  }
  data <- read_supported_data_file(x)
  session <- ggai(
    as.data.frame(data),
    instruction = instruction,
    mode = "session"
  )
  session <- session_record_turn_note(
    session,
    type = "ggai_source",
    value = list(source = "file", path = x)
  )

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction,
      image_model = image_model,
      ...
    ))
  }

  session
}

#' @export
ggai.ggplot <- function(x,
                        instruction = NULL,
                        mode = c("session", "polish"),
                        image_model = NULL,
                        polish_instruction = NULL,
                        ...) {
  mode <- match.arg(mode)
  session <- start_ggai_session(x)

  if (identical(mode, "polish")) {
    return(polish_figure(
      session,
      instruction = polish_instruction %||% instruction,
      image_model = image_model,
      ...
    ))
  }

  if (!is.null(instruction) && nzchar(instruction)) {
    return(gg_edit(session, instruction))
  }
  session
}

#' @export
ggai.ggai_session <- function(x,
                              instruction = NULL,
                              mode = c("session", "polish"),
                              image_model = NULL,
                              polish_instruction = NULL,
                              ...) {
  mode <- match.arg(mode)
  if (identical(mode, "polish")) {
    return(polish_figure(
      x,
      instruction = polish_instruction %||% instruction,
      image_model = image_model,
      ...
    ))
  }

  if (!is.null(instruction) && nzchar(instruction)) {
    return(gg_edit(x, instruction))
  }
  x
}

#' @export
ggai.default <- function(x,
                         instruction = NULL,
                         mode = c("session", "polish"),
                         image_model = NULL,
                         polish_instruction = NULL,
                         ...) {
  rlang::abort("`ggai()` currently supports data.frame, file path, ggplot, and ggai_session inputs.")
}
