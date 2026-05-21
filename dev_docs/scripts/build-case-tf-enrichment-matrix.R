suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

set.seed(20260518)

families <- c("BES1", "HSF", "bZIP", "CAMTA", "Dof", "ERF", "MYB", "NAC", "TCP", "WRKY")
family_palette <- c(
  BES1 = "#c7d9b7",
  HSF = "#46614f",
  bZIP = "#efb39e",
  CAMTA = "#c85d4b",
  Dof = "#e7b274",
  ERF = "#a8c9bf",
  MYB = "#0f6370",
  NAC = "#8a93bc",
  TCP = "#4b43b9",
  WRKY = "#8a4a3d"
)

genes_per_family <- c(4, 4, 5, 4, 4, 5, 5, 4, 4, 5)
family_tbl <- data.frame(
  family = rep(families, genes_per_family),
  gene_index = ave(rep(1L, sum(genes_per_family)), rep(families, genes_per_family), FUN = seq_along),
  stringsAsFactors = FALSE
)
family_tbl$gene <- sprintf("TF%02d", seq_len(nrow(family_tbl)))
family_tbl$x <- seq_len(nrow(family_tbl))

terms <- rev(c(
  "Response to red light",
  "Nucleosome assembly",
  "Protein heterodimerization",
  "Response to water deprivation",
  "Amino acid binding",
  "Histone binding",
  "Lignin biosynthesis",
  "Protein dimerization",
  "Trehalose biosynthesis",
  "Sequence-specific DNA binding",
  "Copper ion binding",
  "ATP biosynthesis",
  "Response to auxin",
  "Microtubule-based process"
))

term_family_map <- list(
  "Response to red light" = c("BES1"),
  "Nucleosome assembly" = c("bZIP"),
  "Protein heterodimerization" = c("bZIP"),
  "Response to water deprivation" = c("bZIP", "MYB"),
  "Amino acid binding" = c("BES1", "MYB"),
  "Histone binding" = c("TCP", "NAC"),
  "Lignin biosynthesis" = c("ERF"),
  "Protein dimerization" = c("ERF", "NAC"),
  "Trehalose biosynthesis" = c("TCP"),
  "Sequence-specific DNA binding" = c("WRKY"),
  "Copper ion binding" = c("WRKY"),
  "ATP biosynthesis" = c("NAC"),
  "Response to auxin" = c("NAC"),
  "Microtubule-based process" = c("ERF", "NAC")
)

dot_rows <- lapply(names(term_family_map), function(term) {
  target_families <- term_family_map[[term]]
  target_genes <- family_tbl[family_tbl$family %in% target_families, , drop = FALSE]
  keep_n <- max(1L, min(nrow(target_genes), sample(2:5, 1)))
  picked <- target_genes[sample(seq_len(nrow(target_genes)), keep_n), , drop = FALSE]
  data.frame(
    gene = picked$gene,
    x = picked$x,
    term = term,
    q_value = runif(nrow(picked), 0.004, 0.045),
    count = sample(4:12, nrow(picked), replace = TRUE),
    stringsAsFactors = FALSE
  )
})
dot_tbl <- do.call(rbind, dot_rows)
dot_tbl$term <- factor(dot_tbl$term, levels = terms)

time_points <- c("2 h vs 0 h", "24 h vs 0 h", "168 h vs 0 h")
time_tbl <- expand.grid(
  gene = family_tbl$gene,
  time_point = factor(time_points, levels = rev(time_points)),
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
time_tbl <- merge(time_tbl, family_tbl[, c("gene", "x", "family")], by = "gene", sort = FALSE)
time_tbl$padj <- NA_real_
for (family in families) {
  family_rows <- which(time_tbl$family == family)
  active_n <- sample(4:8, 1)
  active_rows <- sample(family_rows, active_n)
  time_tbl$padj[active_rows] <- runif(length(active_rows), 0.006, 0.045)
}

family_strip <- family_tbl
family_strip$y <- "Family"

base_theme <- theme_minimal(base_size = 11) +
  theme(
    panel.grid = element_blank(),
    axis.title = element_blank(),
    axis.text.x = element_text(angle = 42, hjust = 1, vjust = 1),
    plot.margin = margin(0, 8, 0, 8)
  )

top_plot <- ggplot(time_tbl, aes(x = x, y = time_point)) +
  geom_tile(
    aes(fill = padj),
    width = 0.72,
    height = 0.72,
    color = "#1f2937",
    linewidth = 0.18,
    na.rm = FALSE
  ) +
  scale_fill_gradient(
    low = "#d9c7a2",
    high = "#537f92",
    na.value = "transparent",
    name = "P adjusted",
    limits = c(0.005, 0.045),
    breaks = c(0.01, 0.02, 0.03, 0.04),
    guide = guide_colorbar(barheight = unit(38, "pt"))
  ) +
  scale_x_continuous(
    limits = c(0.5, max(family_tbl$x) + 0.5),
    breaks = family_tbl$x,
    labels = NULL,
    expand = expansion(mult = 0)
  ) +
  scale_y_discrete(expand = expansion(add = c(0.2, 0.2))) +
  base_theme +
  theme(
    axis.text.x = element_blank(),
    legend.position = "right"
  )

family_plot <- ggplot(family_strip, aes(x = x, y = y, fill = family)) +
  geom_tile(width = 1, height = 0.7) +
  scale_fill_manual(values = family_palette, name = "Family") +
  scale_x_continuous(
    limits = c(0.5, max(family_tbl$x) + 0.5),
    breaks = family_tbl$x,
    labels = NULL,
    expand = expansion(mult = 0)
  ) +
  scale_y_discrete(expand = expansion(add = c(0, 0))) +
  base_theme +
  theme(
    axis.text = element_blank(),
    legend.position = "right"
  )

dot_plot <- ggplot(dot_tbl, aes(x = x, y = term)) +
  geom_point(aes(size = count, color = q_value), alpha = 0.95, stroke = 0.25) +
  scale_color_gradient(
    low = "#d65d59",
    high = "#3f77a8",
    name = "q-value",
    limits = c(0.004, 0.045),
    breaks = c(0.01, 0.02, 0.03, 0.04),
    guide = guide_colorbar(barheight = unit(38, "pt"))
  ) +
  scale_size_continuous(
    name = "Count",
    range = c(2.3, 6.5),
    breaks = c(5, 8, 11)
  ) +
  scale_x_continuous(
    limits = c(0.5, max(family_tbl$x) + 0.5),
    breaks = family_tbl$x,
    labels = family_tbl$gene,
    expand = expansion(mult = 0)
  ) +
  scale_y_discrete(drop = FALSE) +
  base_theme +
  theme(
    legend.position = "right",
    plot.margin = margin(4, 8, 8, 8)
  )

combined_plot <- top_plot / family_plot / dot_plot +
  plot_layout(heights = c(1.2, 0.28, 4.2), guides = "collect") &
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.margin = margin(0, 0, 0, 8)
  )

ggsave(
  filename = "dev_docs/figures/case-tf-enrichment-matrix.png",
  plot = combined_plot,
  width = 15,
  height = 8.7,
  dpi = 180,
  bg = "white"
)
