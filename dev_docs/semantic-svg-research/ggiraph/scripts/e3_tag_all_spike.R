# E3: tag ALL grobs of the spike plot (plain ggplot2, no *_interactive) via dsvg tracer
source("/tmp/ggai_research/ggiraph/scripts/tag_all.R")
suppressPackageStartupMessages(library(ggplot2))
out <- "/tmp/ggai_research/ggiraph/out"
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) +
  annotate("text", x = 4, y = 32, label = "outlier zone")
t0 <- Sys.time()
res <- render_tagged(ggplotGrob(p), file.path(out, "e3_tagged_spike.svg"))
cat("render_tagged seconds:", format(as.numeric(Sys.time() - t0), digits = 3), "\n")
lg <- summarise_tagged(res, "spike")
write.csv(lg, file.path(out, "e3_leaf_log.csv"), row.names = FALSE)
cat("\nLeaves where expected != emitted:\n")
print(lg[!is.na(lg$expected) & lg$expected != lg$emitted, ])
cat("\nLeaf classes:\n"); print(table(lg$class))
cat("\nTop-level paths (first component) of tagged elements:\n")
paths <- xml_attr(res$prim, "data-ggai-path")
top <- sub("^/([^/]+)/([^/]+).*$", "\\2", paths)
print(table(top, useNA = "ifany"))

# L2 check: points leaves in panels vs ggplot_build rows
b <- ggplot_build(p); bd <- b$data[[1]]
pt <- res$prim[grepl("geom_point", paths)]
pp <- xml_attr(pt, "data-ggai-path")
cat("\npoint leaves:\n"); print(table(pp))
for (k in sort(unique(bd$PANEL))) {
  rows <- bd[bd$PANEL == k, ]
  leaf <- grep(sprintf("panel-%s-", k), unique(pp), value = TRUE)
  # panel naming in gtable for facet_wrap is panel-<col>-<row>; locate by order instead
}
up <- unique(pp)
for (j in seq_along(up)) {
  el <- pt[pp == up[j]]
  rows <- bd[bd$PANEL == j, ]
  cx <- as.numeric(xml_attr(el, "cx"))
  cat(sprintf("panel %d: leaf %s emitted %d circles, built rows %d, spearman(cx, x) = %.4f, colour match = %s\n",
              j, up[j], length(el), nrow(rows), cor(cx, rows$x, method = "spearman"),
              identical(toupper(xml_attr(el, "fill")), toupper(rows$colour))))
}
# legend keys separated by path
cat("\nlegend circles:", sum(grepl("guide-box", paths) & xml_name(res$prim) == "circle"),
    " data circles:", sum(grepl("geom_point", paths)), "\n")
# smooth
sm <- grepl("geom_smooth|geom_ribbon|GRID.polyline|smooth", paths)
cat("smooth-related tagged elements (by path match):", sum(grepl("smooth", paths)), "\n")
print(head(unique(paths[grepl("smooth", paths)]), 10))
cat("\nstrip text:\n"); print(unique(paths[grepl("strip", paths)]))
cat("\nannotate text:\n"); print(xml_text(res$prim[grepl("geom_text|annotate", paths)]))
