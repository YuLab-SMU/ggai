source(testthat::test_path("..", "..", "docs", "assets", "cases", "single-cell-spatial-template", "template_cases.R"))

ggai_expect_template_plot_ok <- function(plot) {
  expect_s3_class(plot, "ggplot")
  validation <- ggai:::ggai_agent_validate_plot(plot)
  expect_equal(validation$status, "ok")
  expect_equal(validation$warnings, character())
}

ggai_expect_equal_aspect <- function(plot) {
  expect_equal(plot$coordinates$ratio, 1)
}

test_that("single-cell and spatial template data covers old user test requirements", {
  cases <- ggai_single_cell_spatial_template_data()

  expect_named(
    cases,
    c(
      "umap_df", "marker_summary", "gene_heatmap_df", "gene_boxplot_df",
      "spatial_df", "spatial_gene_df", "spatial_marker_long",
      "spatial_marker_summary", "spatial_umap_df"
    )
  )
  expect_true(all(c("UMAP_1", "UMAP_2", "cell_type", "MS4A1") %in% names(cases$umap_df)))
  expect_true(all(c("cell_type", "gene", "avg_expression", "pct_expression") %in% names(cases$marker_summary)))
  expect_true(all(c("spatial_x", "spatial_y_plot", "cluster") %in% names(cases$spatial_df)))
  expect_true(all(c("gene", "expression", "spatial_x", "spatial_y_plot") %in% names(cases$spatial_marker_long)))
  expect_gte(length(levels(cases$umap_df$cell_type)), 7)
  expect_gte(length(unique(cases$spatial_marker_long$gene)), 6)
})

test_that("single-cell template plots render and preserve core semantics", {
  cases <- ggai_single_cell_spatial_template_data()

  umap <- ggai_single_cell_umap_template(cases$umap_df)
  ggai_expect_template_plot_ok(umap)
  expect_equal(rlang::as_label(umap$mapping$x), "UMAP_1")
  expect_equal(rlang::as_label(umap$mapping$y), "UMAP_2")
  expect_equal(rlang::as_label(umap$mapping$colour), "cell_type")
  ggai_expect_equal_aspect(umap)

  polished <- ggai_single_cell_umap_polished_template(cases$umap_df)
  ggai_expect_template_plot_ok(polished)
  scale <- polished$scales$get_scales("colour")
  expect_false(is.null(scale))
  scale$train(cases$umap_df$cell_type)
  scale$map(levels(cases$umap_df$cell_type))
  expect_setequal(names(scale$palette.cache), levels(cases$umap_df$cell_type))

  feature <- ggai_single_cell_feature_template(cases$umap_df, gene = "MS4A1")
  ggai_expect_template_plot_ok(feature)
  expect_equal(rlang::as_label(feature$mapping$colour), "MS4A1")

  dot <- ggai_single_cell_marker_dot_template(cases$marker_summary)
  ggai_expect_template_plot_ok(dot)
  dot_mapping <- dot$layers[[1]]$mapping
  expect_equal(rlang::as_label(dot_mapping$size), "pct_expression")
  expect_equal(rlang::as_label(dot_mapping$colour), "avg_expression")

  heatmap <- ggai_single_cell_heatmap_template(cases$gene_heatmap_df)
  ggai_expect_template_plot_ok(heatmap)
  expect_equal(class(heatmap$layers[[1]]$geom)[[1]], "GeomTile")

  boxplot <- ggai_single_cell_boxplot_template(cases$gene_boxplot_df)
  ggai_expect_template_plot_ok(boxplot)
  expect_equal(class(boxplot$layers[[1]]$geom)[[1]], "GeomBoxplot")
  expect_equal(class(boxplot$layers[[2]]$geom)[[1]], "GeomPoint")
})

test_that("spatial template plots render and preserve tissue coordinate semantics", {
  cases <- ggai_single_cell_spatial_template_data()

  cluster <- ggai_spatial_cluster_template(cases$spatial_df)
  ggai_expect_template_plot_ok(cluster)
  expect_equal(rlang::as_label(cluster$mapping$x), "spatial_x")
  expect_equal(rlang::as_label(cluster$mapping$y), "spatial_y_plot")
  expect_equal(rlang::as_label(cluster$mapping$colour), "cluster")
  ggai_expect_equal_aspect(cluster)

  expression <- ggai_spatial_expression_template(cases$spatial_gene_df)
  ggai_expect_template_plot_ok(expression)
  expect_equal(rlang::as_label(expression$mapping$colour), "expression")

  polished <- ggai_spatial_expression_polished_template(cases$spatial_gene_df)
  ggai_expect_template_plot_ok(polished)
  expect_gte(length(polished$layers), 5)

  faceted <- ggai_spatial_faceted_expression_template(cases$spatial_marker_long)
  ggai_expect_template_plot_ok(faceted)
  expect_true(inherits(faceted$facet, "FacetWrap"))
  expect_equal(rlang::as_label(faceted$facet$params$facets[[1]]), "gene")

  dot <- ggai_spatial_marker_dot_template(cases$spatial_marker_summary)
  ggai_expect_template_plot_ok(dot)
  dot_mapping <- dot$layers[[1]]$mapping
  expect_equal(rlang::as_label(dot_mapping$size), "pct_expression")
  expect_equal(rlang::as_label(dot_mapping$colour), "avg_expression")

  umap <- ggai_spatial_umap_template(cases$spatial_umap_df)
  ggai_expect_template_plot_ok(umap)
  expect_equal(rlang::as_label(umap$mapping$x), "UMAP_1")
  expect_equal(rlang::as_label(umap$mapping$y), "UMAP_2")
})

test_that("single-cell spatial skill is part of default Agent skill paths", {
  paths <- ggai:::ggai_agent_skill_paths(
    skills = NULL,
    query = "single-cell UMAP marker dot plot spatial transcriptomics",
    skill_path = tempfile(),
    builtin_skills = c("ggai-plot-agent", "ggai-single-cell-spatial")
  )

  expect_true(any(basename(paths) == "ggai-single-cell-spatial"))
})
