test_that("prepare_polish_bundle writes reference images and manifest", {
  outdir <- tempfile("ggai_polish_bundle_")
  dir.create(outdir, recursive = TRUE)

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::labs(
      title = "Fuel efficiency",
      subtitle = "mtcars demo",
      x = "Weight",
      y = "MPG",
      colour = "Cylinders"
    )

  bundle <- prepare_polish_bundle(
    p,
    instruction = "make it feel like a flagship product graphic",
    output_dir = outdir,
    prefix = "bundle_test",
    width = 640,
    height = 480
  )

  expect_s3_class(bundle, "ggai_figure_polish_bundle")
  expect_true(file.exists(bundle$base_plot_path))
  expect_true(file.exists(bundle$geometry_overlay_path))
  expect_true(file.exists(bundle$layout_overlay_path))
  expect_true(file.exists(bundle$manifest_path))
  expect_true(file.exists(bundle$prompt_path))
  expect_length(bundle$reference_images, 3)

  manifest <- jsonlite::read_json(bundle$manifest_path, simplifyVector = FALSE)
  expect_equal(manifest$mode, "whole_image_redraw")
  expect_equal(manifest$layer_mode, "ggplot_layered_redraw")
  expect_equal(manifest$render$width_px, 640)
  expect_equal(manifest$layer_manifest$ordering, "bottom_to_top")
  expect_equal(length(manifest$layer_manifest$ggplot_reference_layers), 3)
  expect_equal(length(manifest$layer_manifest$ggplot_output_roles), 5)
  expect_equal(manifest$layer_manifest$ggplot_reference_layers[[1]]$role, "ggplot_composite")
  expect_equal(manifest$layer_manifest$ggplot_reference_layers[[2]]$role, "ggplot_data_layer_anchor")
  expect_equal(manifest$layer_manifest$ggplot_reference_layers[[3]]$role, "ggplot_layout_anchor")
  expect_true(all(vapply(manifest$layer_manifest$ggplot_reference_layers, function(layer) file.exists(layer$file), logical(1))))
  expect_true(length(manifest$layout_regions) >= 1)
  expect_true(length(manifest$semantic_constraints) >= 3)

  prompt <- paste(readLines(bundle$prompt_path, warn = FALSE), collapse = "\n")
  expect_match(prompt, "Layer contract", fixed = TRUE)
  expect_match(prompt, "ggplot-native mental model", fixed = TRUE)
  expect_match(prompt, "ggplot_output_roles", fixed = TRUE)
})

test_that("polish_figure sends all reference images to the image editor", {
  outdir <- tempfile("ggai_polish_run_")
  dir.create(outdir, recursive = TRUE)

  candidate_a <- tempfile(tmpdir = outdir, fileext = ".png")
  candidate_b <- tempfile(tmpdir = outdir, fileext = ".png")
  png::writePNG(array(0.9, dim = c(10, 10, 4)), target = candidate_a)
  png::writePNG(array(0.3, dim = c(10, 10, 4)), target = candidate_b)

  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    ggai_edit_image = function(model,
                               image,
                               prompt,
                               output_dir,
                               registry = NULL,
                               n = NULL,
                               quality = NULL,
                               background = NULL,
                               output_format = NULL,
                               ...) {
      captured$model <- model
      captured$image <- image
      captured$prompt <- prompt
      captured$n <- n
      captured$quality <- quality
      captured$background <- background
      captured$output_format <- output_format
      list(
        images = list(
          list(path = candidate_a, media_type = "image/png"),
          list(path = candidate_b, media_type = "image/png")
        ),
        raw_response = list(id = "stub")
      )
    },
    evaluate_figure_candidate = function(path, prompt_spec = NULL) {
      list(score = if (identical(path, candidate_b)) 10 else 1)
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Base plot")

  res <- polish_figure(
    p,
    instruction = "turn this into a premium scientific figure",
    output_dir = outdir,
    prefix = "polish_test",
    candidate_count = 2,
    width = 512,
    height = 384
  )

  expect_s3_class(res, "ggai_polished_figure_result")
  expect_length(captured$image, 3)
  expect_true(all(file.exists(unlist(captured$image))))
  expect_equal(captured$n, 2)
  expect_equal(captured$output_format, "png")
  expect_match(captured$prompt, "Reference image 1")
  expect_match(captured$prompt, "Layer contract", fixed = TRUE)
  expect_true(file.exists(res$best$path))
  expect_true(file.exists(res$bundle_manifest_path))
  expect_true(file.exists(res$candidate_manifest_path))
})

test_that("polish_figure forwards timeout controls to the image editor", {
  outdir <- tempfile("ggai_polish_timeout_")
  dir.create(outdir, recursive = TRUE)

  candidate <- tempfile(tmpdir = outdir, fileext = ".png")
  png::writePNG(array(0.8, dim = c(10, 10, 4)), target = candidate)

  captured <- new.env(parent = emptyenv())

  local_mocked_bindings(
    ggai_edit_image = function(...,
                               timeout_seconds = NULL,
                               total_timeout_seconds = NULL,
                               first_byte_timeout_seconds = NULL,
                               connect_timeout_seconds = NULL,
                               idle_timeout_seconds = NULL) {
      captured$timeout_seconds <- timeout_seconds
      captured$total_timeout_seconds <- total_timeout_seconds
      captured$first_byte_timeout_seconds <- first_byte_timeout_seconds
      captured$connect_timeout_seconds <- connect_timeout_seconds
      captured$idle_timeout_seconds <- idle_timeout_seconds
      list(
        images = list(list(path = candidate, media_type = "image/png")),
        raw_response = list(id = "stub")
      )
    },
    evaluate_figure_candidate = function(path, prompt_spec = NULL) {
      list(score = 7)
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()

  res <- polish_figure(
    p,
    instruction = "make it look premium",
    output_dir = outdir,
    prefix = "timeout_test",
    timeout_seconds = 30,
    total_timeout_seconds = 90,
    first_byte_timeout_seconds = 40,
    connect_timeout_seconds = 6,
    idle_timeout_seconds = 15
  )

  expect_s3_class(res, "ggai_polished_figure_result")
  expect_equal(captured$timeout_seconds, 30)
  expect_equal(captured$total_timeout_seconds, 90)
  expect_equal(captured$first_byte_timeout_seconds, 40)
  expect_equal(captured$connect_timeout_seconds, 6)
  expect_equal(captured$idle_timeout_seconds, 15)
})

test_that("polish_figure records artifact history when source is a session", {
  outdir <- tempfile("ggai_polish_session_")
  dir.create(outdir, recursive = TRUE)

  candidate <- tempfile(tmpdir = outdir, fileext = ".png")
  png::writePNG(array(0.6, dim = c(10, 10, 4)), target = candidate)

  local_mocked_bindings(
    ggai_edit_image = function(...) {
      list(
        images = list(list(path = candidate, media_type = "image/png")),
        raw_response = list(id = "stub")
      )
    },
    evaluate_figure_candidate = function(path, prompt_spec = NULL) {
      list(score = 5)
    },
    .package = "ggai"
  )

  s <- start_ggai_session(
    ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
      ggplot2::geom_point() +
      ggplot2::labs(title = "Base plot")
  )

  res <- polish_figure(
    s,
    instruction = "make this look like a cover figure",
    output_dir = outdir,
    prefix = "session_polish_test",
    width = 512,
    height = 384
  )

  expect_s3_class(res$session, "ggai_session")
  hist <- spec_history(res$session)
  expect_true(any(hist$kind == "polish"))
  expect_true(any(hist$edit_mode == "whole_image_redraw"))
  expect_true(any(hist$artifact_path == res$best$path))
  ctx <- session_context(res$session)
  expect_true(length(ctx$recent_artifacts) >= 1)
})

test_that("print.ggai_polished_figure_result shows a concise summary", {
  result <- structure(
    list(
      bundle = list(large = paste(rep("bundle", 20), collapse = "")),
      prompt = paste(rep("prompt", 20), collapse = ""),
      prompt_path = "/tmp/figure_prompt.txt",
      bundle_manifest_path = "/tmp/figure_bundle.json",
      candidate_manifest_path = "/tmp/figure_candidates.json",
      candidates = list(
        list(index = 1, path = "/tmp/candidate.png", score = 3, b64_json = paste(rep("base64", 20), collapse = ""))
      ),
      best = list(path = "/tmp/best.png", score = 3),
      raw_response = list(b64_json = paste(rep("raw-base64", 20), collapse = ""))
    ),
    class = c("ggai_polished_figure_result", "list")
  )

  text <- capture.output(print(result))
  joined <- paste(text, collapse = "\n")

  expect_match(joined, "<ggai_polished_figure_result>", fixed = TRUE)
  expect_match(joined, "Best image: /tmp/best.png", fixed = TRUE)
  expect_match(joined, "Candidates: 1", fixed = TRUE)
  expect_false(grepl("raw-base64", joined, fixed = TRUE))
  expect_false(grepl("b64_json", joined, fixed = TRUE))
  expect_false(grepl("promptprompt", joined, fixed = TRUE))
})
