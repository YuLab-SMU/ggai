test_that("source URL detection parses GitHub repositories", {
  detected <- ggai_detect_source_urls("Diagram https://github.com/org/repo/tree/main/R and https://example.com/page")

  expect_length(detected$urls, 2)
  expect_length(detected$github, 1)
  expect_equal(detected$github[[1]]$owner, "org")
  expect_equal(detected$github[[1]]$repo, "repo")
  expect_true(length(detected$evidence) >= 2)
})

test_that("GitHub inspection records parse evidence without network access", {
  info <- ggai_inspect_github_url("https://github.com/org/repo")

  expect_equal(info$repository$owner, "org")
  expect_equal(info$repository$repo, "repo")
  expect_match(info$evidence[[1]]$summary, "Parsed GitHub repository")
  expect_true(length(info$evidence[[1]]$assumptions) >= 1)
})

test_that("local file listing and reading are bounded to root", {
  root <- tempdir()
  path <- file.path(root, "source.R")
  writeLines(c("a <- 1", "b <- 2"), path)

  listing <- ggai_list_local_files(root = root, pattern = "source", max_files = 5)
  read <- ggai_read_local_file("source.R", root = root, max_lines = 1)

  expect_true("source.R" %in% unlist(listing$files))
  expect_equal(read$lines[[1]], "a <- 1")
  expect_true(read$truncated)
  expect_error(ggai_read_local_file("../not_allowed", root = root), class = "ggai_source_error")
})

test_that("source summary compacts evidence records", {
  evidence <- list(
    list(kind = "url", source = "https://example.com", summary = "Example URL"),
    list(kind = "local_file", source = "R/a.R", summary = "Local file")
  )

  summary <- ggai_summarize_sources(evidence)

  expect_equal(summary$evidence_count, 2)
  expect_true("url" %in% unlist(summary$kinds))
  expect_match(summary$summary, "Local file")
})
