library(ggplot2)
library(grid)

out_dir <- file.path("docs", "assets", "cases", "ggplot-grammar-editing")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

save_case <- function(plot, filename, width = 8.4, height = 5.4) {
  path <- file.path(out_dir, filename)
  ggsave(path, plot, width = width, height = height, dpi = 160, bg = "white")
  message("wrote ", path)
  invisible(path)
}

theme_case <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title.position = "plot",
      plot.title = element_text(face = "bold", size = rel(1.25)),
      plot.subtitle = element_text(color = "#4B5563"),
      plot.caption = element_text(color = "#6B7280"),
      panel.grid.minor = element_blank(),
      legend.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold"),
      strip.background = element_rect(fill = "#F3F4F6", color = NA)
    )
}

car_data <- ggplot2::mpg
car_data$class <- factor(car_data$class)
car_data$drv <- factor(
  car_data$drv,
  levels = c("f", "4", "r"),
  labels = c("front-wheel", "4-wheel", "rear-wheel")
)
car_data$transmission <- ifelse(grepl("^auto", car_data$trans), "automatic", "manual")
car_data$transmission <- factor(car_data$transmission)

base <- ggplot(car_data, aes(displ, hwy, colour = class)) +
  geom_point(size = 2.5, alpha = 0.76) +
  labs(
    title = "Highway Efficiency by Engine Size",
    subtitle = "Base plot: one point per vehicle model",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Vehicle class",
    caption = "Data: ggplot2::mpg"
  ) +
  theme_case()

save_case(base, "01-base-scatter.png")

mapping_edit <- ggplot(car_data, aes(displ, hwy)) +
  geom_point(aes(colour = drv, size = cty), alpha = 0.72) +
  scale_size_continuous(range = c(1.8, 6), breaks = c(12, 18, 24, 30)) +
  labs(
    title = "Remap Encodings to Reveal Drive Train and City Efficiency",
    subtitle = "Aesthetic mapping edit: colour = drive train, size = city mpg",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Drive train",
    size = "City mpg"
  ) +
  theme_case()

save_case(mapping_edit, "02-aesthetic-remap.png")

layer_edit <- ggplot(car_data, aes(displ, hwy, colour = class)) +
  geom_point(size = 2.2, alpha = 0.45) +
  geom_smooth(
    aes(group = 1),
    method = "loess",
    se = TRUE,
    linewidth = 1.1,
    colour = "#111827",
    fill = "#CBD5E1"
  ) +
  labs(
    title = "Add a Trend Layer Without Losing the Raw Data",
    subtitle = "Layer edit: retain points, add a smooth summary with uncertainty",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Vehicle class"
  ) +
  theme_case()

save_case(layer_edit, "03-layer-trend.png")

stat_summary_edit <- ggplot(car_data, aes(class, hwy, fill = class)) +
  stat_summary(
    fun = mean,
    geom = "col",
    width = 0.66,
    alpha = 0.92,
    colour = "white",
    linewidth = 0.4
  ) +
  stat_summary(
    fun.data = mean_se,
    geom = "errorbar",
    width = 0.18,
    linewidth = 0.65,
    colour = "#111827"
  ) +
  labs(
    title = "Summarise Categories With Mean and Standard Error",
    subtitle = "Stat edit: replace raw points with stat_summary layers",
    x = NULL,
    y = "Mean highway fuel efficiency (mpg)",
    fill = "Vehicle class"
  ) +
  guides(fill = "none") +
  coord_flip() +
  theme_case()

save_case(stat_summary_edit, "04-stat-summary.png")

scale_edit <- ggplot(car_data, aes(displ, hwy, colour = drv)) +
  geom_point(size = 2.8, alpha = 0.82) +
  scale_colour_manual(
    values = c(
      "front-wheel" = "#2563EB",
      "4-wheel" = "#059669",
      "rear-wheel" = "#DC2626"
    )
  ) +
  scale_x_continuous(breaks = seq(1, 7, by = 1), limits = c(1, 7)) +
  scale_y_continuous(breaks = seq(10, 45, by = 5), limits = c(10, 45)) +
  labs(
    title = "Control Scales, Breaks, Limits, and Palette",
    subtitle = "Scale edit: explicit colour palette plus readable axis breaks",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Drive train"
  ) +
  theme_case()

save_case(scale_edit, "05-scale-controls.png")

coord_edit <- ggplot(car_data, aes(displ, hwy, colour = class)) +
  geom_point(size = 2.6, alpha = 0.82) +
  coord_cartesian(xlim = c(1.5, 4.5), ylim = c(18, 45), expand = FALSE) +
  labs(
    title = "Zoom the Coordinate System Without Dropping Data",
    subtitle = "Coordinate edit: coord_cartesian focuses the dense efficiency region",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Vehicle class"
  ) +
  theme_case()

save_case(coord_edit, "06-coordinate-zoom.png")

facet_edit <- ggplot(car_data, aes(displ, hwy, colour = class)) +
  geom_point(size = 2.3, alpha = 0.78) +
  geom_smooth(aes(group = 1), method = "lm", se = FALSE, linewidth = 0.9, colour = "#111827") +
  facet_wrap(vars(drv), nrow = 1) +
  labs(
    title = "Split the Same Relationship Into Comparable Panels",
    subtitle = "Facet edit: compare the displacement-efficiency relationship by drive train",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Vehicle class"
  ) +
  theme_case(base_size = 11) +
  theme(legend.position = "bottom")

save_case(facet_edit, "07-facet-panels.png", width = 10, height = 4.8)

theme_edit <- ggplot(car_data, aes(displ, hwy, colour = drv)) +
  geom_point(size = 2.8, alpha = 0.78) +
  scale_colour_brewer(type = "qual", palette = "Dark2") +
  labs(
    title = "Polish Theme, Typography, and Legend Placement",
    subtitle = "Theme edit: cleaner grid, larger title, legend below plot",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Drive train"
  ) +
  theme_case(base_size = 14) +
  theme(
    legend.position = "bottom",
    legend.box = "horizontal",
    panel.grid.major.x = element_blank(),
    axis.title = element_text(face = "bold")
  )

save_case(theme_edit, "08-theme-polish.png")

annotation_data <- car_data[car_data$hwy == max(car_data$hwy), ][1, ]
annotation_edit <- ggplot(car_data, aes(displ, hwy)) +
  geom_point(aes(colour = class), size = 2.4, alpha = 0.58) +
  geom_point(
    data = annotation_data,
    aes(displ, hwy),
    inherit.aes = FALSE,
    size = 5.2,
    shape = 21,
    stroke = 1.2,
    colour = "#B91C1C",
    fill = "#FEE2E2"
  ) +
  annotate(
    "curve",
    x = annotation_data$displ + 1.05,
    y = annotation_data$hwy - 2.4,
    xend = annotation_data$displ + 0.08,
    yend = annotation_data$hwy - 0.2,
    curvature = 0.22,
    arrow = arrow(length = unit(0.03, "npc")),
    colour = "#B91C1C",
    linewidth = 0.7
  ) +
  annotate(
    "label",
    x = annotation_data$displ + 1.25,
    y = annotation_data$hwy - 2.6,
    label = "Highest highway mpg",
    hjust = 0,
    fill = "#FEF2F2",
    colour = "#7F1D1D",
    size = 4
  ) +
  labs(
    title = "Add a Callout While Preserving the Base Evidence",
    subtitle = "Annotation edit: highlight one record with point, arrow, and label",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Vehicle class"
  ) +
  theme_case()

save_case(annotation_edit, "09-annotation-callout.png")

guide_edit <- ggplot(car_data, aes(displ, hwy)) +
  geom_point(aes(colour = drv, shape = transmission), size = 2.7, alpha = 0.78) +
  scale_colour_brewer(type = "qual", palette = "Set1") +
  scale_shape_manual(values = c("automatic" = 16, "manual" = 17)) +
  guides(
    colour = guide_legend(order = 1, override.aes = list(size = 4, alpha = 1)),
    shape = guide_legend(order = 2, override.aes = list(size = 4, alpha = 1))
  ) +
  labs(
    title = "Separate and Order Multiple Guides",
    subtitle = "Guide edit: drive train and transmission get readable legend keys",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Drive train",
    shape = "Transmission"
  ) +
  theme_case() +
  theme(legend.position = "right")

save_case(guide_edit, "10-guide-control.png")

position_data <- subset(car_data, class %in% c("compact", "midsize", "suv"))
position_edit <- ggplot(position_data, aes(class, hwy, fill = transmission)) +
  geom_boxplot(
    width = 0.58,
    outlier.shape = NA,
    alpha = 0.72,
    position = position_dodge(width = 0.72)
  ) +
  geom_point(
    aes(colour = transmission),
    position = position_jitterdodge(jitter.width = 0.12, dodge.width = 0.72),
    size = 1.8,
    alpha = 0.52,
    show.legend = FALSE
  ) +
  scale_fill_manual(values = c("automatic" = "#93C5FD", "manual" = "#FCA5A5")) +
  scale_colour_manual(values = c("automatic" = "#1D4ED8", "manual" = "#B91C1C")) +
  labs(
    title = "Control Position Adjustments for Overlapping Groups",
    subtitle = "Position edit: dodge boxplots and jitter raw observations",
    x = NULL,
    y = "Highway fuel efficiency (mpg)",
    fill = "Transmission"
  ) +
  theme_case()

save_case(position_edit, "11-position-adjustments.png")

composition_edit <- ggplot(car_data, aes(displ, hwy)) +
  geom_point(aes(colour = drv), size = 2.6, alpha = 0.62) +
  geom_smooth(
    aes(group = drv, colour = drv, fill = drv),
    method = "loess",
    se = TRUE,
    linewidth = 0.9,
    alpha = 0.12
  ) +
  facet_wrap(vars(transmission)) +
  scale_colour_brewer(type = "qual", palette = "Dark2") +
  scale_fill_brewer(type = "qual", palette = "Dark2") +
  labs(
    title = "Compose Several Grammar Edits Into One Review Figure",
    subtitle = "Layer + scale + facet + theme edits in a single requested revision",
    x = "Engine displacement (L)",
    y = "Highway fuel efficiency (mpg)",
    colour = "Drive train",
    fill = "Drive train"
  ) +
  guides(fill = "none") +
  theme_case(base_size = 12) +
  theme(legend.position = "bottom")

save_case(composition_edit, "12-composed-edit.png", width = 9, height = 5.4)
