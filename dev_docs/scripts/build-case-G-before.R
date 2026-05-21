# Case G — build 4 deliberately ugly default ggplot2 figures.
# Synthetic data only (no external files), saved to dev_docs/figures/case-G/.

suppressPackageStartupMessages({
  library(ggplot2)
})

set.seed(20260518)

out_dir <- "dev_docs/figures/case-G"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Common bad theme: theme_grey() defaults, dense title, default sans font, no
# polish. This mimics a researcher's first-pass output from cluster/DESeq2.

# ----------------------------------------------------------------------------
# 1. Volcano plot ~ 220 points (small RNA-seq DEG result)
# ----------------------------------------------------------------------------
n_volcano <- 220L
volcano <- data.frame(
  gene      = sprintf("g%03d", seq_len(n_volcano)),
  log2FC    = c(
    rnorm(170, mean = 0,    sd = 0.6),  # bulk null
    rnorm(25,  mean = 2.2,  sd = 0.7),  # up regulated
    rnorm(25,  mean = -2.2, sd = 0.7)   # down regulated
  ),
  neglog10p = c(
    rexp(170, rate = 0.7),
    runif(25, 3, 8),
    runif(25, 3, 8)
  )
)
volcano$category <- ifelse(volcano$log2FC > 1  & volcano$neglog10p > 1.3, "Up",
                    ifelse(volcano$log2FC < -1 & volcano$neglog10p > 1.3, "Down",
                                                                          "NS"))
volcano$category <- factor(volcano$category, levels = c("Up", "Down", "NS"))

p_volcano <- ggplot(volcano, aes(log2FC, neglog10p, color = category)) +
  geom_point(alpha = 0.7, size = 1.8) +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed") +
  geom_hline(yintercept = 1.3, linetype = "dashed") +
  labs(
    title = "Volcano plot of DEG",
    x = "log2 fold change",
    y = "-log10 p-value",
    color = "category"
  )
ggsave(file.path(out_dir, "G-before-volcano.png"), p_volcano,
       width = 6, height = 4.5, dpi = 150, bg = "white")

# ----------------------------------------------------------------------------
# 2. Dotplot ~ GO/KEGG enrichment (10 terms)
# ----------------------------------------------------------------------------
dotplot_terms <- c(
  "Oxidative phosphorylation",
  "Fatty acid metabolism",
  "Glutathione metabolism",
  "Ferroptosis",
  "Cell cycle",
  "DNA replication",
  "p53 signaling",
  "MAPK signaling",
  "PI3K-Akt signaling",
  "Cytokine receptor"
)
dot_df <- data.frame(
  Description = factor(dotplot_terms, levels = rev(dotplot_terms)),
  Count       = sample(15:65, length(dotplot_terms), replace = TRUE),
  GeneRatio   = round(runif(length(dotplot_terms), 0.06, 0.25), 3),
  p.adjust    = 10 ^ (-runif(length(dotplot_terms), 3, 14))
)
p_dot <- ggplot(dot_df,
                aes(GeneRatio, Description,
                    size = Count, color = -log10(p.adjust))) +
  geom_point() +
  scale_size(range = c(2, 8)) +
  labs(
    title = "GO enrichment results",
    x = "GeneRatio", y = "",
    size = "Count", color = "-log10(p.adjust)"
  )
ggsave(file.path(out_dir, "G-before-dotplot.png"), p_dot,
       width = 6.5, height = 4.5, dpi = 150, bg = "white")

# ----------------------------------------------------------------------------
# 3. Heatmap ~ 15 genes x 8 samples expression Z-score
# ----------------------------------------------------------------------------
heat_genes <- c("HMOX1", "GPX4", "FTL", "TFRC", "ACSL4",
                "TP53", "MYC",  "EGFR", "BAX",  "BCL2",
                "MDM2", "CDK4", "RB1",  "PTEN", "AKT1")
heat_samples <- paste0("S", 1:8)
heat_mat <- matrix(rnorm(length(heat_genes) * length(heat_samples), 0, 1.2),
                   nrow = length(heat_genes),
                   dimnames = list(heat_genes, heat_samples))
# Make 5 genes look up-regulated in samples 5-8 to give visible pattern.
heat_mat[1:5, 5:8] <- heat_mat[1:5, 5:8] + 2.0
heat_mat[11:15, 1:4] <- heat_mat[11:15, 1:4] + 1.5

heat_df <- as.data.frame.table(heat_mat, stringsAsFactors = FALSE)
names(heat_df) <- c("gene", "sample", "z")
heat_df$gene   <- factor(heat_df$gene,   levels = rev(heat_genes))
heat_df$sample <- factor(heat_df$sample, levels = heat_samples)

p_heat <- ggplot(heat_df, aes(sample, gene, fill = z)) +
  geom_tile(color = "white", size = 0.2) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0) +
  labs(title = "Expression heatmap", x = "Sample", y = "Gene", fill = "z")
ggsave(file.path(out_dir, "G-before-heatmap.png"), p_heat,
       width = 6, height = 5.5, dpi = 150, bg = "white")

# ----------------------------------------------------------------------------
# 4. Horizontal bar plot ~ top 10 pathways by -log10(p.adjust)
# ----------------------------------------------------------------------------
bar_terms <- c(
  "Oxidative phosphorylation",
  "Fatty acid metabolism",
  "Glutathione metabolism",
  "Ferroptosis",
  "Cell cycle",
  "DNA replication",
  "p53 signaling",
  "MAPK signaling",
  "PI3K-Akt signaling",
  "Cytokine receptor"
)
bar_df <- data.frame(
  pathway = factor(bar_terms, levels = rev(bar_terms)),
  value   = sort(round(runif(length(bar_terms), 3, 16), 2), decreasing = TRUE)
)
p_bar <- ggplot(bar_df, aes(value, pathway)) +
  geom_col() +
  labs(
    title = "Top 10 enriched pathways",
    x = "-log10(p.adjust)", y = ""
  )
ggsave(file.path(out_dir, "G-before-bar.png"), p_bar,
       width = 6.5, height = 4.5, dpi = 150, bg = "white")

cat("Wrote 4 before-figures to ", out_dir, "\n", sep = "")
