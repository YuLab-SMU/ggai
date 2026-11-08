# E4: ggiraph coverage + failure modes (clipping, NA, multi-primitive shapes, composition, base)
suppressPackageStartupMessages({
  library(ggplot2); library(ggiraph); library(xml2); library(grid)
})
out <- "/tmp/ggai_research/ggiraph/out"
d <- mtcars; d$car <- rownames(mtcars); d$cyl <- factor(d$cyl)

count_attrs <- function(svg, label) {
  doc <- read_xml(svg)
  root <- xml_find_first(doc, "//*[local-name()='g' and contains(@class,'ggiraph-svg-rootg')]")
  prim <- xml_find_all(root, ".//*[local-name()='circle' or local-name()='path' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line' or local-name()='image']")
  a <- function(n) sum(!is.na(xml_attr(prim, n)))
  cat(sprintf("%-38s prim=%4d id=%4d data-id=%4d key-id=%3d theme-id=%3d title=%4d\n",
              label, length(prim), a("id"), a("data-id"), a("key-id"), a("theme-id"), a("title")))
  invisible(prim)
}
gsvg <- function(expr_or_gg, label, ...) {
  f <- file.path(out, paste0("e4_", gsub("[^A-Za-z0-9]+", "_", label), ".svg"))
  w <- withCallingHandlers(
    {
      g <- if (inherits(expr_or_gg, "ggplot")) girafe(ggobj = expr_or_gg, width_svg = 7, height_svg = 4, ...)
           else girafe(code = eval(expr_or_gg), width_svg = 7, height_svg = 4, ...)
      writeLines(g$x$html, f)
    },
    warning = function(w) {
      if (!grepl("qt\\(|max\\(ids", conditionMessage(w))) cat("  WARNING [", label, "]: ", conditionMessage(w), "\n", sep = "")
      invokeRestart("muffleWarning")
    })
  count_attrs(f, label)
}

cat("== baseline\n")
base_gg <- ggplot(d, aes(wt, mpg, colour = cyl)) + geom_point(size = 3) + geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~am)
gsvg(base_gg, "plain ggplot via girafe")

cat("== F1 clipping: coord_cartesian(xlim = c(2, 4)) cuts some points\n")
p_clip <- ggplot(d, aes(wt, mpg)) + geom_point_interactive(aes(data_id = car, tooltip = car), size = 3) +
  coord_cartesian(xlim = c(2, 4), ylim = c(15, 30))
pr <- gsvg(p_clip, "clip coord_cartesian")
cat("  rows in data:", nrow(d), " inside window:", sum(d$wt >= 2 & d$wt <= 4 & d$mpg >= 15 & d$mpg <= 30), "\n")

cat("== F1b clipping, points far outside device (huge expand)\n")
p_clip2 <- ggplot(d, aes(wt, mpg)) + geom_point_interactive(aes(data_id = car), size = 3) +
  coord_cartesian(xlim = c(3, 3.5), ylim = c(15, 20), expand = FALSE)
gsvg(p_clip2, "clip tight window")

cat("== F2 NA in path (geom_line_interactive with NA y)\n")
dl <- data.frame(x = 1:10, y = c(1:4, NA, 6:10), id = "s1")
p_na <- ggplot(dl, aes(x, y)) + geom_line_interactive(aes(data_id = id, tooltip = id))
gsvg(p_na, "line with NA")
dl2 <- data.frame(x = 1:10, y = c(1:4, NA, 6:10), id = paste0("pt", 1:10))
p_na2 <- ggplot(dl2, aes(x, y)) + geom_point_interactive(aes(data_id = id))
gsvg(p_na2, "points with NA (removed by ggplot)")

cat("== F3 shapes with lines (pch 3/8) -> several primitives per datum\n")
p_pch <- ggplot(d, aes(wt, mpg, shape = cyl)) + geom_point_interactive(aes(data_id = car), size = 3) +
  scale_shape_manual(values = c(16, 3, 8))
pr <- gsvg(p_pch, "mixed pch 16/3/8")
cat("  distinct data-id:", length(unique(na.omit(xml_attr(pr, "data-id")))), "\n")

cat("== F4 multi-line text label\n")
p_txt <- ggplot(head(d, 3), aes(wt, mpg)) + geom_text_interactive(aes(label = paste0(car, "\nline2"), data_id = car))
pr <- gsvg(p_txt, "multiline text")

cat("== C1 element_*_interactive + labeller_interactive + facet_wrap_interactive\n")
p_theme <- ggplot(d, aes(wt, mpg)) + geom_point_interactive(aes(data_id = car)) +
  facet_wrap_interactive(~am, labeller = labeller_interactive(aes(tooltip = paste("am =", am), data_id = paste0("am", am)))) +
  labs(title = label_interactive("Title", data_id = "title", tooltip = "plot title")) +
  theme(axis.text.x = element_text_interactive(data_id = "axis_x_text", tooltip = "x ticks"),
        panel.background = element_rect_interactive(data_id = "panel_bg"),
        axis.line = element_line_interactive(data_id = "axis_line"))
gsvg(p_theme, "theme+strip interactive")

cat("== C2 patchwork composition\n")
library(patchwork)
p1 <- ggplot(d, aes(wt, mpg)) + geom_point_interactive(aes(data_id = car, tooltip = car))
p2 <- ggplot(d, aes(cyl, mpg)) + geom_boxplot_interactive(aes(data_id = cyl, tooltip = cyl))
gsvg(p1 + p2, "patchwork p1+p2")

cat("== C3 cowplot composition\n")
gsvg(cowplot::plot_grid(p1, p2), "cowplot plot_grid")

cat("== C4 base graphics via girafe(code=)\n")
gsvg(quote(plot(mtcars$wt, mtcars$mpg)), "base plot()")

cat("== C5 plain grid via interactive_*_grob\n")
gsvg(quote({grid.newpage(); grid.draw(interactive_points_grob(x = runif(5), y = runif(5), data_id = letters[1:5], pch = 19))}), "grid interactive_points_grob")

cat("== C6 ComplexHeatmap via girafe(code=)\n")
suppressPackageStartupMessages(library(ComplexHeatmap))
m <- as.matrix(mtcars[1:8, 1:5]); m <- scale(m)
gsvg(quote(draw(Heatmap(m, name = "z"))), "ComplexHeatmap draw()")

cat("== C7 stat geoms: boxplot/histogram/smooth interactive\n")
gsvg(ggplot(d, aes(cyl, mpg)) + geom_boxplot_interactive(aes(data_id = cyl, tooltip = after_stat(paste("n =", width)))), "boxplot_interactive")
gsvg(ggplot(d, aes(wt, mpg)) + geom_smooth_interactive(aes(data_id = "fit", tooltip = "lm fit"), method = "lm", formula = y ~ x), "smooth_interactive")
gsvg(ggplot(d, aes(mpg)) + geom_histogram_interactive(aes(data_id = after_stat(x), tooltip = after_stat(count)), bins = 8), "histogram_interactive")
