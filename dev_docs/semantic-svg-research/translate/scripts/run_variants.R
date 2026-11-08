## Diagnostic variants of figure (a) for canvasXpress
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({library(ggplot2); library(canvasXpress); library(plotly); library(htmlwidgets)})
out <- "/tmp/ggai_research/translate/exp"; W <- 700; H <- 500; DPI <- 96
mt <- mtcars; mt$cyl_f <- factor(mt$cyl)
v <- list(
  a1_no_annotate = ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~am) + labs(colour = "cyl"),
  a2_no_facet    = ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) + labs(colour = "cyl"),
  a3_points_facet_annot = ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + facet_wrap(~am) + annotate("text", x = 4.5, y = 32, label = "heavier = thirstier") + labs(colour = "cyl")
)
zp <- function(w) { w$sizingPolicy$padding <- 0; w$sizingPolicy$browser$padding <- 0; w$sizingPolicy$browser$fill <- FALSE; w }
for (nm in names(v)) {
  ggsave(file.path(out, paste0(nm, "_gg.png")), v[[nm]], width = W/DPI, height = H/DPI, dpi = DPI, bg = "white")
  cx <- canvasXpress(v[[nm]], width = W, height = H)
  saveWidget(zp(cx), file.path(out, paste0(nm, "_cx.html")), selfcontained = FALSE, libdir = "lib", background = "white")
  pl <- ggplotly(v[[nm]], width = W, height = H)
  saveWidget(zp(pl), file.path(out, paste0(nm, "_plotly.html")), selfcontained = FALSE, libdir = "lib", background = "white")
}
## also dump the R-side reconstruction canvasXpress attaches (ggplot.decompiled) for figure (a)
p <- ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~am) + annotate("text", x = 4.5, y = 32, label = "heavier = thirstier")
writeLines(as.character(ggplot.decompiled(p)), file.path(out, "a_facet_cx_decompiled.txt"))
cat("ok\n")
