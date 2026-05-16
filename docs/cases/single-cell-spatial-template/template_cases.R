ggai_domain_named_palette <- function(values, palette = "Dark 3") {
  values <- unique(as.character(values))
  values <- values[nzchar(values)]
  if (!length(values)) {
    return(stats::setNames(character(), character()))
  }
  stats::setNames(grDevices::hcl.colors(length(values), palette = palette), values)
}

ggai_restore_seed <- function(seed_state) {
  if (is.null(seed_state)) {
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  } else {
    assign(".Random.seed", seed_state, envir = .GlobalEnv)
  }
}

ggai_single_cell_spatial_template_data <- function(seed = 430) {
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv)
  } else {
    NULL
  }
  on.exit(ggai_restore_seed(old_seed), add = TRUE)
  set.seed(seed)

  cell_types <- c(
    "Naive CD4 T", "Memory CD4 T", "CD8 T", "NK", "B",
    "CD14+ Mono", "FCGR3A+ Mono", "DC", "Platelet"
  )
  centers <- data.frame(
    cell_type = cell_types,
    cx = c(-5.0, -2.8, -3.2, -0.2, 2.7, 4.8, 5.8, 1.6, -6.1),
    cy = c(3.4, 1.4, 4.9, 5.1, 3.0, -0.7, -3.1, -4.4, -2.5),
    stringsAsFactors = FALSE
  )
  cells_per_type <- 40L
  umap_df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      cell = sprintf("cell_%03d", ((i - 1L) * cells_per_type + seq_len(cells_per_type))),
      UMAP_1 = stats::rnorm(cells_per_type, centers$cx[[i]], 0.58),
      UMAP_2 = stats::rnorm(cells_per_type, centers$cy[[i]], 0.50),
      cell_type = centers$cell_type[[i]],
      nCount_RNA = round(stats::rlnorm(cells_per_type, meanlog = 8.0, sdlog = 0.24)),
      nFeature_RNA = round(stats::rnorm(cells_per_type, mean = 1150, sd = 240)),
      percent.mt = pmax(0, pmin(8, stats::rnorm(cells_per_type, mean = 2.7, sd = 1.1))),
      stringsAsFactors = FALSE
    )
  }))
  umap_df$cell_type <- factor(umap_df$cell_type, levels = cell_types)

  marker_genes <- c("MS4A1", "GNLY", "CD3E", "CD14", "FCER1A", "FCGR3A", "LYZ", "PPBP", "CD8A", "NKG7")
  marker_targets <- list(
    "Naive CD4 T" = c("CD3E"),
    "Memory CD4 T" = c("CD3E"),
    "CD8 T" = c("CD3E", "CD8A"),
    NK = c("GNLY", "NKG7"),
    B = c("MS4A1"),
    "CD14+ Mono" = c("CD14", "LYZ"),
    "FCGR3A+ Mono" = c("FCGR3A", "LYZ"),
    DC = c("FCER1A", "LYZ"),
    Platelet = c("PPBP")
  )
  for (gene in marker_genes) {
    target <- vapply(
      as.character(umap_df$cell_type),
      function(cell_type) gene %in% marker_targets[[cell_type]],
      logical(1)
    )
    low_detected <- stats::runif(nrow(umap_df)) < 0.12
    values <- numeric(nrow(umap_df))
    values[target] <- stats::rgamma(sum(target), shape = 2.8, scale = 0.75)
    values[!target & low_detected] <- stats::rgamma(sum(!target & low_detected), shape = 1.2, scale = 0.22)
    umap_df[[gene]] <- values
  }

  marker_summary <- do.call(rbind, lapply(cell_types, function(cell_type) {
    rows <- umap_df$cell_type == cell_type
    data.frame(
      cell_type = factor(cell_type, levels = cell_types),
      gene = marker_genes,
      avg_expression = vapply(marker_genes, function(gene) mean(umap_df[[gene]][rows]), numeric(1)),
      pct_expression = vapply(marker_genes, function(gene) 100 * mean(umap_df[[gene]][rows] > 0), numeric(1)),
      stringsAsFactors = FALSE
    )
  }))
  marker_summary$gene <- factor(marker_summary$gene, levels = marker_genes)
  marker_summary$cell_type <- factor(marker_summary$cell_type, levels = cell_types)

  gene_boxplot_df <- data.frame(
    cell = umap_df$cell,
    cell_type = umap_df$cell_type,
    expression = umap_df$MS4A1,
    stringsAsFactors = FALSE
  )

  clusters <- as.character(0:7)
  spots_per_cluster <- 36L
  spatial_centers <- data.frame(
    cluster = clusters,
    cx = c(900, 1450, 2020, 2550, 1260, 1850, 2360, 2850),
    cy = c(900, 720, 1040, 890, 1480, 1720, 1480, 1840),
    stringsAsFactors = FALSE
  )
  spatial_df <- do.call(rbind, lapply(seq_len(nrow(spatial_centers)), function(i) {
    data.frame(
      cell = sprintf("spot_%03d", ((i - 1L) * spots_per_cluster + seq_len(spots_per_cluster))),
      spatial_x = stats::rnorm(spots_per_cluster, spatial_centers$cx[[i]], 95),
      spatial_y = stats::rnorm(spots_per_cluster, spatial_centers$cy[[i]], 90),
      cluster = spatial_centers$cluster[[i]],
      nCount_Spatial = round(stats::rlnorm(spots_per_cluster, meanlog = 9.2, sdlog = 0.25)),
      nFeature_Spatial = round(stats::rnorm(spots_per_cluster, mean = 5600, sd = 900)),
      percent.mt = pmax(0, pmin(18, stats::rnorm(spots_per_cluster, mean = 8.5, sd = 2.4))),
      stringsAsFactors = FALSE
    )
  }))
  spatial_df$cluster <- factor(spatial_df$cluster, levels = clusters)
  spatial_df$spatial_y_plot <- -spatial_df$spatial_y

  spatial_genes <- c("Hpca", "Ttr", "Mbp", "Plp1", "Snap25", "Gad1")
  spatial_targets <- list(
    Hpca = c("0", "1"),
    Ttr = c("2"),
    Mbp = c("3", "4"),
    Plp1 = c("4", "5"),
    Snap25 = c("0", "6", "7"),
    Gad1 = c("1", "7")
  )
  for (gene in spatial_genes) {
    target <- as.character(spatial_df$cluster) %in% spatial_targets[[gene]]
    spatial_df[[gene]] <- ifelse(
      target,
      stats::rgamma(nrow(spatial_df), shape = 3.5, scale = 0.65),
      stats::rgamma(nrow(spatial_df), shape = 1.0, scale = 0.18)
    )
  }

  feature_gene <- "Hpca"
  spatial_gene_df <- data.frame(
    cell = spatial_df$cell,
    cluster = spatial_df$cluster,
    spatial_x = spatial_df$spatial_x,
    spatial_y_plot = spatial_df$spatial_y_plot,
    gene = feature_gene,
    expression = spatial_df[[feature_gene]],
    stringsAsFactors = FALSE
  )

  spatial_marker_long <- do.call(rbind, lapply(spatial_genes, function(gene) {
    data.frame(
      cell = spatial_df$cell,
      cluster = spatial_df$cluster,
      spatial_x = spatial_df$spatial_x,
      spatial_y_plot = spatial_df$spatial_y_plot,
      gene = gene,
      expression = spatial_df[[gene]],
      stringsAsFactors = FALSE
    )
  }))
  spatial_marker_long$gene <- factor(spatial_marker_long$gene, levels = spatial_genes)

  spatial_marker_summary <- do.call(rbind, lapply(clusters, function(cluster) {
    rows <- spatial_df$cluster == cluster
    data.frame(
      cluster = factor(cluster, levels = clusters),
      gene = factor(spatial_genes, levels = spatial_genes),
      avg_expression = vapply(spatial_genes, function(gene) mean(spatial_df[[gene]][rows]), numeric(1)),
      pct_expression = vapply(spatial_genes, function(gene) 100 * mean(spatial_df[[gene]][rows] > 0.35), numeric(1)),
      stringsAsFactors = FALSE
    )
  }))

  spatial_umap_df <- data.frame(
    cell = spatial_df$cell,
    UMAP_1 = as.numeric(spatial_df$cluster) * 0.65 + stats::rnorm(nrow(spatial_df), 0, 0.35),
    UMAP_2 = sin(as.numeric(spatial_df$cluster)) * 2 + stats::rnorm(nrow(spatial_df), 0, 0.45),
    cluster = spatial_df$cluster,
    stringsAsFactors = FALSE
  )

  list(
    umap_df = umap_df,
    marker_summary = marker_summary,
    gene_heatmap_df = marker_summary,
    gene_boxplot_df = gene_boxplot_df,
    spatial_df = spatial_df,
    spatial_gene_df = spatial_gene_df,
    spatial_marker_long = spatial_marker_long,
    spatial_marker_summary = spatial_marker_summary,
    spatial_umap_df = spatial_umap_df
  )
}

ggai_single_cell_umap_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = UMAP_1, y = UMAP_2, colour = cell_type)) +
    ggplot2::geom_point(size = 0.9, alpha = 0.72, stroke = 0) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "UMAP 1", y = "UMAP 2", colour = "Cell type") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "right"
    )
}

ggai_single_cell_umap_polished_template <- function(data) {
  palette <- ggai_domain_named_palette(levels(data$cell_type))
  centers <- stats::aggregate(
    data[, c("UMAP_1", "UMAP_2")],
    by = list(cell_type = data$cell_type),
    FUN = stats::median
  )
  xr <- range(data$UMAP_1, na.rm = TRUE)
  yr <- range(data$UMAP_2, na.rm = TRUE)
  x0 <- xr[[1]] + 0.06 * diff(xr)
  y0 <- yr[[1]] + 0.08 * diff(yr)
  ax <- 0.16 * diff(xr)
  ay <- 0.16 * diff(yr)

  ggplot2::ggplot(data, ggplot2::aes(x = UMAP_1, y = UMAP_2, colour = cell_type)) +
    ggplot2::geom_point(size = 0.78, alpha = 0.82, stroke = 0) +
    ggplot2::geom_text(
      data = centers,
      ggplot2::aes(x = UMAP_1, y = UMAP_2, label = cell_type),
      inherit.aes = FALSE,
      size = 2.8,
      colour = "#111827"
    ) +
    ggplot2::scale_colour_manual(values = palette) +
    ggplot2::coord_equal() +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(legend.position = "none") +
    ggplot2::annotate(
      "segment",
      x = x0, xend = x0 + ax, y = y0, yend = y0,
      arrow = grid::arrow(length = grid::unit(0.09, "inches"), type = "closed"),
      linewidth = 0.35,
      colour = "#374151"
    ) +
    ggplot2::annotate(
      "segment",
      x = x0, xend = x0, y = y0, yend = y0 + ay,
      arrow = grid::arrow(length = grid::unit(0.09, "inches"), type = "closed"),
      linewidth = 0.35,
      colour = "#374151"
    ) +
    ggplot2::annotate("text", x = x0 + ax / 2, y = y0 - 0.08 * diff(yr), label = "UMAP 1", size = 2.8, colour = "#374151") +
    ggplot2::annotate("text", x = x0 - 0.06 * diff(xr), y = y0 + ay / 2, label = "UMAP 2", size = 2.8, angle = 90, colour = "#374151")
}

ggai_single_cell_feature_template <- function(data, gene = "MS4A1") {
  ggplot2::ggplot(data, ggplot2::aes(x = UMAP_1, y = UMAP_2, colour = .data[[gene]])) +
    ggplot2::geom_point(size = 0.82, alpha = 0.84, stroke = 0) +
    ggplot2::scale_colour_gradient(low = "#D1D5DB", high = "#B91C1C", name = paste(gene, "expression")) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "UMAP 1", y = "UMAP 2") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_single_cell_marker_dot_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = gene, y = cell_type)) +
    ggplot2::geom_point(ggplot2::aes(size = pct_expression, colour = avg_expression), alpha = 0.92) +
    ggplot2::scale_size_continuous(range = c(1.2, 7.5), name = "% expressing") +
    ggplot2::scale_colour_gradient(low = "#F3F4F6", high = "#7F1D1D", name = "Avg expression") +
    ggplot2::labs(x = "Marker gene", y = "Cell type") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, face = "italic"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

ggai_single_cell_heatmap_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = gene, y = cell_type, fill = avg_expression)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.35) +
    ggplot2::scale_fill_gradient(low = "#F8FAFC", high = "#1D4ED8", name = "Avg expression") +
    ggplot2::labs(x = "Marker gene", y = "Cell type") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, face = "italic"),
      panel.grid = ggplot2::element_blank()
    )
}

ggai_single_cell_boxplot_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = cell_type, y = expression)) +
    ggplot2::geom_boxplot(outlier.shape = NA, fill = "#E5E7EB", colour = "#111827", linewidth = 0.35) +
    ggplot2::geom_jitter(width = 0.18, size = 0.55, alpha = 0.25, colour = "#2563EB") +
    ggplot2::labs(x = "Cell type", y = "MS4A1 expression") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 35, hjust = 1),
      panel.grid.minor = ggplot2::element_blank()
    )
}

ggai_spatial_cluster_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = spatial_x, y = spatial_y_plot, colour = cluster)) +
    ggplot2::geom_point(size = 1.05, alpha = 0.82, stroke = 0) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "Tissue x", y = "Tissue y", colour = "Cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_spatial_expression_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = spatial_x, y = spatial_y_plot, colour = expression)) +
    ggplot2::geom_point(size = 1.25, alpha = 0.86, stroke = 0) +
    ggplot2::scale_colour_gradient(low = "#E5E7EB", high = "#DC2626", name = "Expression") +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "Tissue x", y = "Tissue y") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_spatial_expression_polished_template <- function(data) {
  base <- ggai_spatial_expression_template(data)
  xr <- range(data$spatial_x, na.rm = TRUE)
  yr <- range(data$spatial_y_plot, na.rm = TRUE)
  x0 <- xr[[1]] + 0.05 * diff(xr)
  y0 <- yr[[1]] + 0.06 * diff(yr)
  ax <- 0.15 * diff(xr)
  ay <- 0.15 * diff(yr)

  base +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(legend.position = "right") +
    ggplot2::annotate(
      "segment",
      x = x0, xend = x0 + ax, y = y0, yend = y0,
      arrow = grid::arrow(length = grid::unit(0.08, "inches"), type = "closed"),
      linewidth = 0.35,
      colour = "#374151"
    ) +
    ggplot2::annotate(
      "segment",
      x = x0, xend = x0, y = y0, yend = y0 + ay,
      arrow = grid::arrow(length = grid::unit(0.08, "inches"), type = "closed"),
      linewidth = 0.35,
      colour = "#374151"
    ) +
    ggplot2::annotate("text", x = x0 + ax / 2, y = y0 - 0.08 * diff(yr), label = "tissue x", size = 2.8, colour = "#374151") +
    ggplot2::annotate("text", x = x0 - 0.06 * diff(xr), y = y0 + ay / 2, label = "tissue y", size = 2.8, angle = 90, colour = "#374151")
}

ggai_spatial_faceted_expression_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = spatial_x, y = spatial_y_plot, colour = expression)) +
    ggplot2::geom_point(size = 0.72, alpha = 0.84, stroke = 0) +
    ggplot2::facet_wrap(~gene, ncol = 3) +
    ggplot2::scale_colour_gradient(low = "#E5E7EB", high = "#7F1D1D", name = "Expression") +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "Tissue x", y = "Tissue y") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(face = "italic"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

ggai_spatial_marker_dot_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = gene, y = cluster)) +
    ggplot2::geom_point(ggplot2::aes(size = pct_expression, colour = avg_expression), alpha = 0.92) +
    ggplot2::scale_size_continuous(range = c(1.2, 7.2), name = "% expressing") +
    ggplot2::scale_colour_gradient(low = "#F3F4F6", high = "#7C2D12", name = "Avg expression") +
    ggplot2::labs(x = "Marker gene", y = "Spatial cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 35, hjust = 1, face = "italic"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

ggai_spatial_umap_template <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = UMAP_1, y = UMAP_2, colour = cluster)) +
    ggplot2::geom_point(size = 0.85, alpha = 0.7, stroke = 0) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "UMAP 1", y = "UMAP 2", colour = "Cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_case_package_status <- function(packages) {
  data.frame(
    package = packages,
    available = vapply(packages, requireNamespace, logical(1), quietly = TRUE),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

ggai_case_provider_keys <- function(model) {
  provider <- sub(":.*$", "", as.character(model %||% ""))
  switch(
    tolower(provider),
    openai = "OPENAI_API_KEY",
    deepseek = "DEEPSEEK_API_KEY",
    gemini = c("GEMINI_API_KEY", "GOOGLE_API_KEY"),
    google = c("GOOGLE_API_KEY", "GEMINI_API_KEY"),
    anthropic = "ANTHROPIC_API_KEY",
    character()
  )
}

ggai_case_api_status <- function(model) {
  keys <- ggai_case_provider_keys(model)
  data.frame(
    model = as.character(model %||% ""),
    provider = sub(":.*$", "", as.character(model %||% "")),
    required_env = if (length(keys)) paste(keys, collapse = " or ") else "",
    key_available = if (length(keys)) any(nzchar(Sys.getenv(keys, ""))) else NA,
    stringsAsFactors = FALSE
  )
}

ggai_case_text_plot <- function(title, message, colour = "#6B7280") {
  text <- paste(strwrap(as.character(message %||% ""), width = 54), collapse = "\n")
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text",
      x = 0,
      y = 1,
      label = paste(title, text, sep = "\n\n"),
      hjust = 0,
      vjust = 1,
      size = 3.3,
      colour = colour,
      lineheight = 1.08
    ) +
    ggplot2::xlim(0, 1) +
    ggplot2::ylim(0, 1) +
    ggplot2::theme_void()
}

ggai_case_compare_plots <- function(reference_plot,
                                    live_result,
                                    reference_title = "Reference",
                                    live_title = "ggai live result") {
  candidate <- NULL
  if (inherits(live_result, "ggai_case_result") && identical(live_result$status, "ok")) {
    candidate <- tryCatch(plot(live_result$result), error = function(e) e)
  }
  if (inherits(candidate, "error") || is.null(candidate)) {
    message <- if (inherits(live_result, "ggai_case_result")) {
      live_result$message %||% ""
    } else {
      "Live result was not available."
    }
    candidate <- ggai_case_text_plot(live_title, message, colour = "#B91C1C")
  }

  if (requireNamespace("patchwork", quietly = TRUE)) {
    return(
      (reference_plot + ggplot2::ggtitle(reference_title)) |
        (candidate + ggplot2::ggtitle(live_title))
    )
  }

  reference_plot + ggplot2::ggtitle(reference_title)
}

ggai_seurat_pbmc_case <- function() {
  required <- c("Seurat", "SeuratObject", "SingleCellExperiment")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages for PBMC case: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  data("pbmc_small", package = "SeuratObject", envir = environment())
  marker_genes <- c("MS4A1", "GNLY", "CD3E", "CD14", "FCER1A", "FCGR3A", "LYZ", "PPBP", "CD8A")
  marker_genes <- marker_genes[marker_genes %in% rownames(pbmc_small)]

  emb <- as.data.frame(Seurat::Embeddings(pbmc_small, reduction = "tsne"))
  names(emb) <- c("tSNE_1", "tSNE_2")
  meta <- pbmc_small@meta.data
  expr <- Seurat::FetchData(pbmc_small, vars = marker_genes)
  cell_df <- data.frame(
    cell = rownames(emb),
    emb,
    cluster = factor(as.character(meta$RNA_snn_res.0.8), levels = levels(meta$RNA_snn_res.0.8)),
    groups = factor(meta$groups),
    expr,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  marker_summary <- do.call(rbind, lapply(levels(cell_df$cluster), function(cluster) {
    rows <- cell_df$cluster == cluster
    data.frame(
      cluster = factor(cluster, levels = levels(cell_df$cluster)),
      gene = factor(marker_genes, levels = marker_genes),
      avg_expression = vapply(marker_genes, function(gene) mean(cell_df[[gene]][rows]), numeric(1)),
      pct_expression = vapply(marker_genes, function(gene) 100 * mean(cell_df[[gene]][rows] > 0), numeric(1)),
      stringsAsFactors = FALSE
    )
  }))
  boxplot_df <- data.frame(
    cell = cell_df$cell,
    cluster = cell_df$cluster,
    expression = cell_df$MS4A1,
    stringsAsFactors = FALSE
  )

  list(
    seurat = pbmc_small,
    sce = Seurat::as.SingleCellExperiment(pbmc_small),
    cell_df = cell_df,
    marker_summary = marker_summary,
    boxplot_df = boxplot_df,
    marker_genes = marker_genes
  )
}

ggai_pbmc_reference_tsne <- function(pbmc_case) {
  Seurat::DimPlot(
    pbmc_case$seurat,
    reduction = "tsne",
    group.by = "RNA_snn_res.0.8",
    pt.size = 1.5
  ) +
    ggplot2::labs(colour = "Cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_pbmc_reference_feature <- function(pbmc_case, gene = "MS4A1") {
  Seurat::FeaturePlot(
    pbmc_case$seurat,
    features = gene,
    reduction = "tsne",
    pt.size = 1.5
  ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_pbmc_reference_dotplot <- function(pbmc_case) {
  Seurat::DotPlot(
    pbmc_case$seurat,
    features = pbmc_case$marker_genes,
    group.by = "RNA_snn_res.0.8"
  ) +
    ggplot2::labs(x = "Marker gene", y = "Cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, face = "italic"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

ggai_pbmc_extracted_tsne <- function(pbmc_case) {
  ggplot2::ggplot(pbmc_case$cell_df, ggplot2::aes(tSNE_1, tSNE_2, colour = cluster)) +
    ggplot2::geom_point(size = 1.35, alpha = 0.82, stroke = 0) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "tSNE 1", y = "tSNE 2", colour = "Cluster") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_pbmc_extracted_feature <- function(pbmc_case, gene = "MS4A1") {
  ggplot2::ggplot(pbmc_case$cell_df, ggplot2::aes(tSNE_1, tSNE_2, colour = .data[[gene]])) +
    ggplot2::geom_point(size = 1.35, alpha = 0.86, stroke = 0) +
    ggplot2::scale_colour_gradient(low = "#D1D5DB", high = "#B91C1C", name = paste(gene, "expression")) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "tSNE 1", y = "tSNE 2") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

ggai_spatialexperiment_visium_case <- function(section = "section1") {
  required <- c("SpatialExperiment", "SingleCellExperiment", "SummarizedExperiment", "S4Vectors", "Matrix", "jsonlite", "png")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages for SpatialExperiment Visium case: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  outs_dir <- system.file(file.path("extdata", "10xVisium", section, "outs"), package = "SpatialExperiment")
  if (!nzchar(outs_dir) || !dir.exists(outs_dir)) {
    stop("SpatialExperiment extdata 10xVisium sample was not found.", call. = FALSE)
  }

  matrix_dir <- file.path(outs_dir, "raw_feature_bc_matrix")
  spatial_dir <- file.path(outs_dir, "spatial")
  counts <- Matrix::readMM(file.path(matrix_dir, "matrix.mtx"))
  features <- utils::read.delim(
    file.path(matrix_dir, "features.tsv"),
    header = FALSE,
    stringsAsFactors = FALSE
  )
  barcodes <- readLines(file.path(matrix_dir, "barcodes.tsv"), warn = FALSE)
  rownames(counts) <- make.unique(features[[2]])
  colnames(counts) <- barcodes

  positions <- utils::read.csv(
    file.path(spatial_dir, "tissue_positions_list.csv"),
    header = FALSE,
    stringsAsFactors = FALSE
  )
  names(positions) <- c("barcode", "in_tissue", "array_row", "array_col", "pxl_col_in_fullres", "pxl_row_in_fullres")
  positions <- positions[match(barcodes, positions$barcode), ]

  scale_factors <- jsonlite::fromJSON(file.path(spatial_dir, "scalefactors_json.json"))
  image_path <- file.path(spatial_dir, "tissue_lowres_image.png")
  scale_factor <- scale_factors$tissue_lowres_scalef

  spe <- SpatialExperiment::SpatialExperiment(
    assays = list(counts = counts),
    rowData = S4Vectors::DataFrame(
      gene_id = features[[1]],
      gene_name = features[[2]],
      feature_type = features[[3]]
    ),
    colData = S4Vectors::DataFrame(
      sample_id = section,
      in_tissue = positions$in_tissue,
      array_row = positions$array_row,
      array_col = positions$array_col
    ),
    spatialCoords = as.matrix(positions[, c("pxl_col_in_fullres", "pxl_row_in_fullres")])
  )
  spe <- SpatialExperiment::addImg(
    spe,
    sample_id = section,
    image_id = "lowres",
    imageSource = image_path,
    scaleFactor = scale_factor,
    load = FALSE
  )

  image <- png::readPNG(image_path)
  image_height <- dim(image)[[1]]
  image_width <- dim(image)[[2]]
  coords <- SpatialExperiment::spatialCoords(spe)
  totals <- Matrix::rowSums(counts)
  top_gene <- rownames(counts)[order(totals, decreasing = TRUE)][[1]]
  expression <- as.numeric(counts[top_gene, ])
  spatial_df <- data.frame(
    barcode = colnames(counts),
    sample_id = section,
    in_tissue = factor(ifelse(positions$in_tissue == 1, "in tissue", "off tissue"), levels = c("in tissue", "off tissue")),
    array_row = positions$array_row,
    array_col = positions$array_col,
    fullres_x = coords[, 1],
    fullres_y = coords[, 2],
    image_x = coords[, 1] * scale_factor,
    image_y = image_height - coords[, 2] * scale_factor,
    gene = top_gene,
    expression = log1p(expression),
    raw_count = expression,
    stringsAsFactors = FALSE
  )

  list(
    spe = spe,
    spatial_df = spatial_df,
    image = image,
    image_path = image_path,
    image_width = image_width,
    image_height = image_height,
    scale_factor = scale_factor,
    top_gene = top_gene,
    scale_factors = scale_factors
  )
}

ggai_spatial_reference_spots <- function(spatial_case) {
  ggplot2::ggplot(spatial_case$spatial_df, ggplot2::aes(image_x, image_y)) +
    ggplot2::annotation_raster(
      spatial_case$image,
      xmin = 0,
      xmax = spatial_case$image_width,
      ymin = 0,
      ymax = spatial_case$image_height
    ) +
    ggplot2::geom_point(ggplot2::aes(colour = in_tissue), size = 1.35, alpha = 0.78, stroke = 0) +
    ggplot2::coord_equal(xlim = c(0, spatial_case$image_width), ylim = c(0, spatial_case$image_height), expand = FALSE) +
    ggplot2::labs(x = "lowres image x", y = "lowres image y", colour = "Spot") +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(legend.position = "right")
}

ggai_spatial_reference_feature <- function(spatial_case) {
  ggplot2::ggplot(spatial_case$spatial_df, ggplot2::aes(image_x, image_y)) +
    ggplot2::annotation_raster(
      spatial_case$image,
      xmin = 0,
      xmax = spatial_case$image_width,
      ymin = 0,
      ymax = spatial_case$image_height
    ) +
    ggplot2::geom_point(ggplot2::aes(colour = expression), size = 1.6, alpha = 0.88, stroke = 0) +
    ggplot2::scale_colour_gradient(low = "#D1D5DB", high = "#DC2626", name = paste0(spatial_case$top_gene, " log1p")) +
    ggplot2::coord_equal(xlim = c(0, spatial_case$image_width), ylim = c(0, spatial_case$image_height), expand = FALSE) +
    ggplot2::labs(x = "lowres image x", y = "lowres image y") +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(legend.position = "right")
}

ggai_spatial_extracted_feature <- function(spatial_case) {
  ggplot2::ggplot(spatial_case$spatial_df, ggplot2::aes(image_x, image_y, colour = expression)) +
    ggplot2::geom_point(size = 1.6, alpha = 0.88, stroke = 0) +
    ggplot2::scale_colour_gradient(low = "#D1D5DB", high = "#DC2626", name = paste0(spatial_case$top_gene, " log1p")) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "lowres image x", y = "lowres image y") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}
