ggai_stat_abort <- function(message) {
  rlang::abort(message, class = "ggai_stat_error")
}

ggai_stat_column_types <- function(data) {
  stats::setNames(
    vapply(data, function(x) {
      if (is.numeric(x)) {
        "numeric"
      } else if (is.logical(x) || is.factor(x) || is.character(x)) {
        "categorical"
      } else {
        class(x)[[1]]
      }
    }, character(1)),
    names(data)
  )
}

ggai_stat_mentioned_columns <- function(data, goal = NULL) {
  if (is.null(goal) || !is.character(goal) || length(goal) != 1L || !nzchar(goal)) {
    return(character())
  }

  text <- tolower(goal)
  nms <- names(data)
  nms[vapply(nms, function(name) grepl(paste0("\\b", tolower(name), "\\b"), text), logical(1))]
}

ggai_stat_missingness <- function(data) {
  lapply(data, function(x) {
    missing <- sum(is.na(x))
    list(
      missing = missing,
      missing_rate = if (length(x)) missing / length(x) else NA_real_
    )
  })
}

ggai_stat_group_sizes <- function(data, group) {
  if (is.null(group) || !group %in% names(data)) {
    return(list())
  }

  tab <- table(data[[group]], useNA = "ifany")
  lapply(names(tab), function(level) list(level = level, n = as.integer(tab[[level]])))
}

ggai_stat_distribution <- function(data, variable) {
  if (is.null(variable) || !variable %in% names(data)) {
    return(list())
  }

  x <- data[[variable]]
  if (is.numeric(x)) {
    values <- x[!is.na(x)]
    return(list(
      variable = variable,
      type = "numeric",
      n = length(values),
      mean = if (length(values)) mean(values) else NA_real_,
      sd = if (length(values) > 1L) stats::sd(values) else NA_real_,
      median = if (length(values)) stats::median(values) else NA_real_,
      iqr = if (length(values)) stats::IQR(values) else NA_real_,
      min = if (length(values)) min(values) else NA_real_,
      max = if (length(values)) max(values) else NA_real_
    ))
  }

  tab <- table(x, useNA = "ifany")
  list(
    variable = variable,
    type = "categorical",
    n = length(x),
    levels = lapply(names(tab), function(level) list(level = level, n = as.integer(tab[[level]])))
  )
}

ggai_stat_pick_variables <- function(data, goal = NULL) {
  types <- ggai_stat_column_types(data)
  mentioned <- ggai_stat_mentioned_columns(data, goal = goal)
  numeric_cols <- names(types)[types == "numeric"]
  categorical_cols <- names(types)[types == "categorical"]
  mentioned_numeric <- intersect(mentioned, numeric_cols)
  mentioned_categorical <- intersect(mentioned, categorical_cols)

  list(
    numeric = if (length(mentioned_numeric)) mentioned_numeric else numeric_cols,
    categorical = if (length(mentioned_categorical)) mentioned_categorical else categorical_cols,
    mentioned = mentioned,
    types = types
  )
}

ggai_stat_compact_htest <- function(test, method = NULL) {
  list(
    method = method %||% test$method %||% NULL,
    statistic = unname(test$statistic %||% NA_real_),
    parameter = unname(test$parameter %||% NA_real_),
    p_value = test$p.value %||% NA_real_,
    estimate = unname(test$estimate %||% NA_real_)
  )
}

ggai_stat_correlation <- function(data, x, y) {
  complete <- stats::complete.cases(data[, c(x, y), drop = FALSE])
  if (sum(complete) < 3L) {
    return(list(status = "insufficient_data", n = sum(complete)))
  }
  test <- stats::cor.test(data[[x]][complete], data[[y]][complete], method = "pearson")
  utils::modifyList(
    list(status = "ok", x = x, y = y, n = sum(complete), correlation = unname(test$estimate)),
    ggai_stat_compact_htest(test, method = "pearson_correlation")
  )
}

ggai_stat_two_group <- function(data, response, group) {
  keep <- stats::complete.cases(data[, c(response, group), drop = FALSE])
  dat <- data[keep, c(response, group), drop = FALSE]
  dat[[group]] <- factor(dat[[group]])
  group_sizes <- table(dat[[group]])
  if (length(group_sizes) != 2L || any(group_sizes < 2L)) {
    return(list(status = "insufficient_data", group_sizes = ggai_stat_group_sizes(dat, group)))
  }

  test <- stats::t.test(stats::as.formula(paste(response, "~", group)), data = dat)
  utils::modifyList(
    list(status = "ok", response = response, group = group, group_sizes = ggai_stat_group_sizes(dat, group)),
    ggai_stat_compact_htest(test, method = "two_sample_t_test")
  )
}

ggai_stat_multi_group <- function(data, response, group) {
  keep <- stats::complete.cases(data[, c(response, group), drop = FALSE])
  dat <- data[keep, c(response, group), drop = FALSE]
  dat[[group]] <- factor(dat[[group]])
  group_sizes <- table(dat[[group]])
  if (length(group_sizes) < 3L || any(group_sizes < 2L)) {
    return(list(status = "insufficient_data", group_sizes = ggai_stat_group_sizes(dat, group)))
  }

  fit <- stats::aov(stats::as.formula(paste(response, "~", group)), data = dat)
  tab <- summary(fit)[[1]]
  list(
    status = "ok",
    method = "one_way_anova",
    response = response,
    group = group,
    group_sizes = ggai_stat_group_sizes(dat, group),
    statistic = unname(tab[["F value"]][[1]]),
    p_value = unname(tab[["Pr(>F)"]][[1]])
  )
}

ggai_stat_categorical_association <- function(data, x, y) {
  keep <- stats::complete.cases(data[, c(x, y), drop = FALSE])
  dat <- data[keep, c(x, y), drop = FALSE]
  tab <- table(dat[[x]], dat[[y]])
  if (any(dim(tab) < 2L) || sum(tab) < 2L) {
    return(list(status = "insufficient_data", n = sum(tab)))
  }

  test <- suppressWarnings(stats::chisq.test(tab))
  utils::modifyList(
    list(status = "ok", x = x, y = y, n = sum(tab), table = unclass(tab)),
    ggai_stat_compact_htest(test, method = "chi_squared_test")
  )
}

ggai_stat_linear_model <- function(data, response, predictor) {
  keep <- stats::complete.cases(data[, c(response, predictor), drop = FALSE])
  dat <- data[keep, c(response, predictor), drop = FALSE]
  if (nrow(dat) < 3L) {
    return(list(status = "insufficient_data", n = nrow(dat)))
  }

  fit <- stats::lm(stats::as.formula(paste(response, "~", predictor)), data = dat)
  coefs <- summary(fit)$coefficients
  list(
    status = "ok",
    method = "linear_model",
    response = response,
    predictor = predictor,
    n = nrow(dat),
    r_squared = unname(summary(fit)$r.squared),
    intercept = unname(coefs[1L, "Estimate"]),
    slope = unname(coefs[2L, "Estimate"]),
    p_value = unname(coefs[2L, "Pr(>|t|)"])
  )
}

#' Profile deterministic statistical evidence for local data
#'
#' @param data A data frame.
#' @param goal Optional user goal used to prioritize variables.
#'
#' @return A list of role, missingness, and distribution evidence.
#' @export
ggai_stat_profile <- function(data, goal = NULL) {
  if (!is.data.frame(data)) {
    ggai_stat_abort("`data` must be a data frame.")
  }
  vars <- ggai_stat_pick_variables(data, goal = goal)
  focus <- unique(c(utils::head(vars$numeric, 2), utils::head(vars$categorical, 2)))

  list(
    column_types = as.list(vars$types),
    mentioned_columns = as.list(vars$mentioned),
    missingness = ggai_stat_missingness(data),
    distributions = lapply(focus, function(variable) ggai_stat_distribution(data, variable))
  )
}

#' Select a deterministic statistical method for local data
#'
#' @param data A data frame.
#' @param goal Optional user goal.
#'
#' @return A method-selection record with evidence and a deterministic result.
#' @export
ggai_select_stat_method <- function(data, goal = NULL) {
  if (!is.data.frame(data)) {
    ggai_stat_abort("`data` must be a data frame.")
  }

  vars <- ggai_stat_pick_variables(data, goal = goal)
  text <- tolower(goal %||% "")
  numeric_cols <- vars$numeric
  categorical_cols <- vars$categorical
  wants_compare <- grepl("compare|between|across|group|groups|difference", text)
  wants_model <- grepl("linear|regression|model|trend", text)
  wants_correlation <- grepl("correlation|correlat|relationship|association", text)

  family <- "descriptive_summary"
  method <- "descriptive_summary"
  selected <- list()
  result <- list(status = "ok")

  if (length(numeric_cols) >= 2L && (wants_model || grepl("predict|explain", text))) {
    family <- "linear_model"
    method <- "linear_model"
    selected <- list(response = numeric_cols[[2]], predictor = numeric_cols[[1]])
    result <- ggai_stat_linear_model(data, selected$response, selected$predictor)
  } else if (length(numeric_cols) >= 2L && wants_correlation) {
    family <- "correlation"
    method <- "pearson_correlation"
    selected <- list(x = numeric_cols[[1]], y = numeric_cols[[2]])
    result <- ggai_stat_correlation(data, selected$x, selected$y)
  } else if (length(numeric_cols) >= 1L && length(categorical_cols) >= 1L && wants_compare) {
    response <- numeric_cols[[1]]
    group <- categorical_cols[[1]]
    groups <- unique(data[[group]][!is.na(data[[group]])])
    if (length(groups) == 2L) {
      family <- "two_group_comparison"
      method <- "two_sample_t_test"
      selected <- list(response = response, group = group)
      result <- ggai_stat_two_group(data, response, group)
    } else {
      family <- "multi_group_comparison"
      method <- "one_way_anova"
      selected <- list(response = response, group = group)
      result <- ggai_stat_multi_group(data, response, group)
    }
  } else if (length(categorical_cols) >= 2L) {
    family <- "categorical_association"
    method <- "chi_squared_test"
    selected <- list(x = categorical_cols[[1]], y = categorical_cols[[2]])
    result <- ggai_stat_categorical_association(data, selected$x, selected$y)
  } else if (length(numeric_cols) >= 2L) {
    family <- "correlation"
    method <- "pearson_correlation"
    selected <- list(x = numeric_cols[[1]], y = numeric_cols[[2]])
    result <- ggai_stat_correlation(data, selected$x, selected$y)
  } else if (length(numeric_cols) >= 1L) {
    selected <- list(variable = numeric_cols[[1]])
    result <- ggai_stat_distribution(data, selected$variable)
  }

  list(
    family = family,
    method = method,
    variables = selected,
    evidence = list(
      goal = goal %||% "",
      column_types = as.list(vars$types),
      mentioned_columns = as.list(vars$mentioned),
      missingness = ggai_stat_missingness(data)
    ),
    result = result
  )
}
