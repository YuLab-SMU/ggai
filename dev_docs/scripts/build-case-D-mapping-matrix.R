# Case D - paper x stage mapping matrix (ggplot table)
suppressPackageStartupMessages({
  library(ggplot2)
})

out_dir <- "dev_docs/figures/case-D"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

papers <- c(
  "#14 MASLD\n(Du et al. 2024)",
  "#16 Sarcopenia\n(Zuo et al. 2025)",
  "#20 Parkinson\n(Gan et al. 2025)",
  "#21 Blood / HSC\n(Zeng et al. 2024)",
  "#37 Mouse brain\n(Qin et al. 2025)"
)
papers <- factor(papers, levels = rev(papers))

stages <- c("Aging stressor", "Molecular trigger", "Pathway", "Phenotype")
stages <- factor(stages, levels = stages)

cells <- tibble::tibble(
  paper = rep(papers, each = 4L),
  stage = factor(rep(stages, times = 5L), levels = stages),
  text  = c(
    # Paper #14 MASLD
    "Chronological aging\n+ metabolic stress",
    "Iron overload\n+ lipid peroxidation",
    "Ferroptosis\n(GPX4 / ACSL4)",
    "Liver degeneration\n(MASLD / fibrosis)",
    # Paper #16 Sarcopenia
    "Chronological aging\nin skeletal muscle",
    "BCAA accumulation\n(PPM1K loss)",
    "mTOR dysregulation\n+ BCAA catabolism",
    "Sarcopenia / frailty\n(muscle mass loss)",
    # Paper #20 Parkinson
    "15-year prodromal\naging window",
    "Plasma protein drift\n(ITGAV, BAG3, HPGDS)",
    "Integrin / lipid /\nimmune signalling",
    "Parkinson's disease\nonset",
    # Paper #21 Blood / HSC
    "HSC self-renewal\nloss with age",
    "Uridine deficit\n+ glutamate shift",
    "FoxO signalling\n+ inflammation",
    "Myeloid skew\n+ HSC exhaustion",
    # Paper #37 Mouse brain
    "Region-specific\nbrain aging trajectory",
    "Spatiotemporal\nimmune drift",
    "PRC2 / H3K27me3\n+ inflammaging",
    "Cognitive decline\n+ neurodegeneration"
  ),
  category = rep(c("stressor", "trigger", "pathway", "phenotype"), times = 5L)
)

category_palette <- c(
  stressor  = "#fde7d3",
  trigger   = "#f3c8b8",
  pathway   = "#cdd9e8",
  phenotype = "#c1d6c2"
)

p <- ggplot(cells, aes(stage, paper)) +
  geom_tile(aes(fill = category), color = "white", linewidth = 1.6) +
  geom_text(aes(label = text), size = 3.35, lineheight = 1.05, family = "Helvetica") +
  scale_fill_manual(values = category_palette, guide = "none") +
  scale_x_discrete(position = "top", expand = expansion(add = c(0.02, 0.02))) +
  scale_y_discrete(expand = expansion(add = c(0.05, 0.05))) +
  labs(
    title    = "Aging stressor -> molecular trigger -> tissue dysfunction",
    subtitle = "Common theme: metabolic-immune-cell-death axis",
    caption  = "Five Nature Aging studies mapped onto a shared four-stage scaffold"
  ) +
  theme_minimal(base_size = 12, base_family = "Helvetica") +
  theme(
    panel.grid       = element_blank(),
    axis.title       = element_blank(),
    axis.text.x      = element_text(face = "bold", size = 12, color = "#1f2937", margin = margin(b = 6)),
    axis.text.y      = element_text(face = "bold", size = 11, color = "#1f2937", lineheight = 1.05),
    plot.title       = element_text(face = "bold", size = 15, color = "#1f2937", margin = margin(b = 2)),
    plot.subtitle    = element_text(size = 12, color = "#c25e2a", margin = margin(b = 14)),
    plot.caption     = element_text(size = 9.5, color = "#6b7280", hjust = 0, margin = margin(t = 10)),
    plot.margin      = margin(18, 22, 14, 18),
    plot.background  = element_rect(fill = "white", color = NA)
  )

ggsave(
  filename = file.path(out_dir, "paper-mapping-matrix.png"),
  plot     = p,
  width    = 13.5,
  height   = 7.0,
  dpi      = 200,
  bg       = "white"
)

cat("[case-D] mapping matrix saved\n")
