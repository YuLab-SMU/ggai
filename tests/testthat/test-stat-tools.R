test_that("stat profile records missingness and distributions", {
  dat <- data.frame(
    value = c(1, 2, NA, 4),
    group = c("a", "a", "b", "b")
  )

  profile <- ggai_stat_profile(dat, goal = "compare value across group")

  expect_equal(profile$column_types$value, "numeric")
  expect_equal(profile$column_types$group, "categorical")
  expect_equal(profile$missingness$value$missing, 1)
  expect_true(length(profile$distributions) >= 2)
})

test_that("method selection covers two-group comparison", {
  dat <- data.frame(
    value = c(1, 2, 3, 6, 7, 8),
    group = rep(c("a", "b"), each = 3)
  )

  selected <- ggai_select_stat_method(dat, "compare value between group")

  expect_equal(selected$family, "two_group_comparison")
  expect_equal(selected$method, "two_sample_t_test")
  expect_equal(selected$variables$response, "value")
  expect_equal(selected$result$status, "ok")
  expect_true(is.numeric(selected$result$p_value))
})

test_that("method selection covers multi-group comparison", {
  dat <- data.frame(
    value = c(1, 2, 3, 4, 5, 6),
    group = rep(c("a", "b", "c"), each = 2)
  )

  selected <- ggai_select_stat_method(dat, "compare value across group")

  expect_equal(selected$family, "multi_group_comparison")
  expect_equal(selected$method, "one_way_anova")
  expect_equal(selected$result$status, "ok")
})

test_that("method selection covers correlation and linear model", {
  dat <- data.frame(x = 1:10, y = (1:10) * 2 + c(0, 1, -1, 2, -2, 1, 0, -1, 2, -2))

  corr <- ggai_select_stat_method(dat, "relationship between x and y")
  lm <- ggai_select_stat_method(dat, "linear model y by x")

  expect_equal(corr$family, "correlation")
  expect_equal(corr$method, "pearson_correlation")
  expect_equal(corr$result$status, "ok")

  expect_equal(lm$family, "linear_model")
  expect_equal(lm$method, "linear_model")
  expect_equal(lm$result$status, "ok")
  expect_true(lm$result$r_squared > 0.9)
})

test_that("method selection covers categorical association", {
  dat <- data.frame(
    treatment = rep(c("a", "b"), each = 10),
    outcome = rep(c("yes", "no"), times = 10)
  )

  selected <- ggai_select_stat_method(dat, "association between treatment and outcome")

  expect_equal(selected$family, "categorical_association")
  expect_equal(selected$method, "chi_squared_test")
  expect_equal(selected$result$status, "ok")
})
