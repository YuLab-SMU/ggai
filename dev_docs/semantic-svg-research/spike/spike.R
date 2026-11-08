suppressPackageStartupMessages({library(ggplot2); library(grid); library(xml2)})
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) +
  annotate("text", x = 4, y = 32, label = "outlier zone")
out <- "/tmp/ggai_svg_spike/p.svg"
svglite::svglite(out, width = 7, height = 4); print(p); invisible(dev.off())
doc <- read_xml(out); ns <- xml_ns(doc)
els <- xml_find_all(doc, "//*[local-name()='circle' or local-name()='path' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line']")
cat("svg primitive elements:", length(els), "\n")
print(table(xml_name(els)))
cat("any id / data attrs on primitives:", sum(!is.na(xml_attr(els, "id"))), "\n")
# grob tree side
g <- ggplotGrob(p); grid.newpage(); pushViewport(viewport()); 
gf <- grid.force(g)
nm <- grid.ls(gf, print = FALSE)$name
pts <- grep("^geom_point", nm, value = TRUE); cat("point grobs:", paste(pts, collapse=", "), "\n")
b <- ggplot_build(p)
cat("built rows layer1 by PANEL:", paste(table(b$data[[1]]$PANEL), collapse = "/"), " total", nrow(mtcars), "\n")
circ <- xml_find_all(doc, "//*[local-name()='circle']")
cat("circles in svg:", length(circ), "\n")
# order check: within panel 1, svg circle order vs built data order (x monotone mapping)
bx <- b$data[[1]]; p1 <- bx[bx$PANEL == 1, ]
cx <- as.numeric(xml_attr(circ, "cx"))[seq_len(nrow(p1))]
cat("panel-1 rank correlation (svg cx vs built x, draw order):", round(cor(cx, p1$x, method = "spearman"), 4), "\n")
