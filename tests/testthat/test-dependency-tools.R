test_that("package check reports installed base packages and records trace", {
  s <- start_ggai_session(ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)))

  result <- ggai_check_package("stats", session = s)

  expect_true(result$installed)
  expect_equal(result$status, "available")
  ctx <- session_context(result$session)
  expect_equal(ctx$recent_agent_traces[[1]]$task_id, "package:stats")
})

test_that("install policy blocks or asks before installing", {
  blocked <- ggai_install_cran_package("definitely_missing_pkg_ggai", policy = "never")
  asked <- ggai_install_cran_package("definitely_missing_pkg_ggai", policy = "ask")

  expect_equal(blocked$status, "blocked")
  expect_equal(blocked$reason, "policy_never")
  expect_equal(asked$status, "approval_required")
  expect_equal(asked$reason, "policy_ask")
})

test_that("auto_cran calls installer for missing packages", {
  called <- new.env(parent = emptyenv())
  called$package <- NULL

  result <- ggai_install_cran_package(
    "definitely_missing_pkg_ggai",
    policy = "auto_cran",
    installer = function(pkgs, lib = NULL, repos = NULL) {
      called$package <- pkgs
      invisible(TRUE)
    }
  )

  expect_equal(called$package, "definitely_missing_pkg_ggai")
  expect_equal(result$status, "install_attempted")
})

test_that("local help, examples, and vignette tools return structured records", {
  help <- ggai_inspect_help("stats", "lm", max_lines = 12)
  examples <- ggai_inspect_examples("stats", "lm")
  vignettes <- ggai_vignette_index("stats")

  expect_equal(help$status, "ok")
  expect_match(help$text, "Linear Models")
  expect_equal(examples$status, "ok")
  expect_type(examples$output, "character")
  expect_equal(vignettes$status, "ok")
  expect_type(vignettes$vignettes, "list")
})
