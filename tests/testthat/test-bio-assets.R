test_that("bio asset presets resolve known biomedical node types", {
  spec <- bio_asset_spec("tumor_cell")

  expect_s3_class(spec, "ggai_bio_asset_spec")
  expect_match(spec$prompt, "tumor cell")
  expect_true(spec$width > 0)
  expect_true(spec$height > 0)
})

test_that("prepare_hybrid_diagram_spec converts bio nodes into image assets", {
  local_mocked_bindings(
    generate_bio_asset = function(spec, model = NULL, cache = TRUE) {
      structure(
        list(path = "/tmp/mock_tumor.png", source_path = "/tmp/mock_source.png", raw_copy = "/tmp/mock_raw.png", prompt = spec$prompt),
        class = c("ggai_glyph_asset", "list")
      )
    },
    .package = "ggai"
  )

  scene <- list(
    canvas = list(width = 12, height = 8, background = "white", coordinate_system = "cartesian"),
    nodes = list(
      list(
        id = "tumor",
        kind = "box",
        label = "Tumor",
        style = list(),
        bio_asset = list(type = "tumor_cell")
      )
    ),
    edges = list(),
    annotations = list()
  )

  out <- prepare_hybrid_diagram_spec(scene, generate_assets = TRUE)

  expect_equal(out$nodes[[1]]$kind, "image_asset")
  expect_equal(out$nodes[[1]]$asset_ref, "/tmp/mock_tumor.png")
  expect_equal(out$nodes[[1]]$generated_asset$raw_copy, "/tmp/mock_raw.png")
  expect_true(out$nodes[[1]]$width > 0)
  expect_true(out$nodes[[1]]$height > 0)
})

test_that("scene assets can be copied into an output bundle", {
  dir <- tempfile("ggai_assets_")
  dir.create(dir, recursive = TRUE)
  src <- tempfile(fileext = ".png")
  writeBin(as.raw(c(137, 80, 78, 71)), src)

  spec <- list(
    nodes = list(
      list(id = "tumor", label = "Tumor", asset_ref = src, bio_asset = list(type = "tumor_cell"))
    )
  )

  manifest <- ggai:::copy_scene_assets(spec, output_dir = dir, prefix = "demo")

  expect_length(manifest, 1)
  expect_true(file.exists(manifest[[1]]$asset_ref))
})
