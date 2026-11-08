## Baseline for the "never redraw" path: same figures via svglite, viewed in the browser
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({library(ggplot2); library(patchwork); library(ggrepel); library(svglite); library(ComplexHeatmap)})
out <- "/tmp/ggai_research/translate/exp"; W <- 700; H <- 500
mt <- mtcars; mt$car <- rownames(mtcars); mt$cyl_f <- factor(mt$cyl)
figs <- list(
  a_facet = ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~am) + annotate("text", x = 4.5, y = 32, label = "heavier = thirstier") + labs(colour = "cyl"),
  b_patchwork = (ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + labs(colour = "cyl")) + (ggplot(mt, aes(cyl_f, mpg, fill = cyl_f)) + geom_boxplot() + labs(x = "cyl", fill = "cyl")),
  c_repel = ggplot(mt, aes(wt, mpg, label = car)) + geom_point(colour = "red") + geom_text_repel(size = 3, seed = 42, max.overlaps = Inf),
  e_pointrange = ggplot(data.frame(term = c("age","sex","bmi","smoker"), est = c(0.2,-0.4,0.6,1.1), lo = c(0.05,-0.8,0.3,0.7), hi = c(0.35,0,0.9,1.5)), aes(est, term, xmin = lo, xmax = hi)) + geom_vline(xintercept = 0, linetype = 2) + geom_pointrange()
)
wrap <- function(svgfile, html) writeLines(c("<!doctype html><html><head><meta charset='utf-8'><style>html,body{margin:0;padding:0;background:#fff}img{display:block}</style></head><body>",
  sprintf("<img src='%s' width='%d' height='%d'>", basename(svgfile), W, H), "</body></html>"), html)
for (nm in names(figs)) {
  f <- file.path(out, paste0(nm, "_svglite.svg"))
  ggsave(f, figs[[nm]], device = svglite::svglite, width = W / 96, height = H / 96, bg = "white")
  wrap(f, file.path(out, paste0(nm, "_svglite.html")))
}
set.seed(1)
m <- matrix(rnorm(60), 10, dimnames = list(paste0("g", 1:10), paste0("s", 1:6)))
ht <- Heatmap(m, name = "z", top_annotation = HeatmapAnnotation(grp = rep(c("A", "B"), 3)))
f <- file.path(out, "d_heatmap_svglite.svg"); svglite(f, width = W / 96, height = H / 96, bg = "white"); draw(ht); dev.off()
wrap(f, file.path(out, "d_heatmap_svglite.html"))
## blank calibration page
writeLines("<!doctype html><html><body style='margin:0;background:#fff'></body></html>", file.path(out, "blank.html"))
cat("ok\n")
