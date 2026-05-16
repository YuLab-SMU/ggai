test_that("figure prompt compiler normalizes direct-image prompt specs", {
  spec <- ggai:::normalize_figure_prompt_spec(list(
    scene_summary = "Tumor microenvironment immunotherapy figure",
    objects = list("tumor mass", "T cell"),
    relations = list("T cell approaches tumor"),
    visual_style = "clean biomedical illustration",
    composition = "wide figure",
    prompt = "draw the final figure"
  ))

  expect_true(nzchar(spec$negative_prompt))
  expect_true(nzchar(spec$prompt))
})

test_that("figure candidate evaluator scores existing files", {
  tmp <- tempfile(fileext = ".png")
  png::writePNG(array(1, dim = c(10, 10, 4)), target = tmp)

  score <- evaluate_figure_candidate(tmp)

  expect_true(is.finite(score$score))
  expect_true(score$file_size > 0)
  expect_true("sharpness" %in% names(score))
  expect_true("clutter" %in% names(score))
})

test_that("generate_final_figure writes prompt and candidate manifests", {
  tmp <- tempfile(fileext = ".png")
  png::writePNG(array(1, dim = c(10, 10, 4)), target = tmp)
  outdir <- tempfile("ggai_direct_")
  dir.create(outdir, recursive = TRUE)

  local_mocked_bindings(
    compile_figure_prompt = function(...) {
      list(
        scene_summary = "Tumor figure",
        objects = list("tumor", "T cell"),
        relations = list("T cell targets tumor"),
        visual_style = "clean biomedical illustration",
        composition = "wide figure",
        negative_prompt = "watermark",
        prompt = "final prompt"
      )
    },
    ggai_generate_image = function(...) {
      list(images = list(list(path = tmp, media_type = "image/png")))
    },
    .package = "ggai"
  )

  res <- generate_final_figure(
    instruction = "draw a tumor figure",
    candidate_count = 2,
    output_dir = outdir,
    prefix = "demo_direct"
  )

  expect_true(file.exists(res$best$path))
  expect_true(file.exists(res$prompt_path))
  expect_true(file.exists(res$manifest_path))
  expect_length(res$candidates, 2)
})

test_that("figure resolution option is honored", {
  tmp <- tempfile(fileext = ".png")
  png::writePNG(array(1, dim = c(10, 10, 4)), target = tmp)
  outdir <- tempfile("ggai_direct_res_")
  dir.create(outdir, recursive = TRUE)

  old <- options(ggai.figure_resolution = "1600x900")
  on.exit(options(old), add = TRUE)
  seen <- new.env(parent = emptyenv())
  local_mocked_bindings(
    compile_figure_prompt = function(...) {
      list(
        scene_summary = "Tumor figure",
        objects = list("tumor"),
        relations = list("tumor on left"),
        visual_style = "clean biomedical illustration",
        composition = "wide figure",
        negative_prompt = "watermark",
        prompt = "final prompt"
      )
    },
    ggai_generate_image = function(model, prompt, output_dir, width, height, transparent_background = FALSE) {
      seen$width <- width
      seen$height <- height
      list(images = list(list(path = tmp, media_type = "image/png")))
    },
    .package = "ggai"
  )

  generate_final_figure(
    instruction = "draw",
    candidate_count = 1,
    output_dir = outdir,
    prefix = "res_test"
  )

  expect_equal(seen$width, 1600L)
  expect_equal(seen$height, 900L)
})
