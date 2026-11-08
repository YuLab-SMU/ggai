.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(ggplot2); library(grid); library(gridSVG); library(xml2) })
out <- "/tmp/ggai_research/ggiraph/out"
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) +
  annotate("text", x = 4, y = 32, label = "outlier zone")
pdf(NULL, width = 7, height = 4); suppressWarnings(print(p))
cat("before force, geom_point names:", length(grep("^geom_point", grid.ls(print = FALSE)$name)), "\n")
grid.force()
pts <- grep("^geom_point", grid.ls(print = FALSE)$name, value = TRUE)
cat("after force:", pts, "\n")
b <- ggplot_build(p)$data[[1]]
for (k in seq_along(pts)) grid.garnish(pts[k], `data-row` = as.character(which(b$PANEL == k)), group = FALSE)
# also garnish ALL grobs generically with group-level attribute = grob name
allg <- unique(grid.ls(print = FALSE)$name)
withCallingHandlers(grid.export(file.path(out, "e6b_gridsvg_garnished.svg"), strict = FALSE), warning = function(w) { if (!grepl("qt|max", conditionMessage(w))) cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
dev.off()
doc <- read_xml(file.path(out, "e6b_gridsvg_garnished.svg"))
u <- xml_find_all(doc, "//*[local-name()='use'][@data-row]")
cat("<use> with data-row:", length(u), "\n")
print(head(data.frame(id = xml_attr(u, "id"), row = xml_attr(u, "data-row"), x = xml_attr(u, "x")), 4))
prim <- xml_find_all(doc, "//*[local-name()='polyline' or local-name()='polygon' or local-name()='text' or local-name()='rect' or local-name()='use']")
ids <- xml_attr(prim, "id")
cat("\nsmooth ids:\n"); print(grep("smooth|GRID.polygon|GRID.polyline", ids, value = TRUE)[1:6])
cat("\ntext ids + content:\n"); tx <- xml_find_all(doc, "//*[local-name()='text']")
print(head(data.frame(id = xml_attr(tx, "id"), txt = xml_text(tx)), 8))
cat("\nvp-group ids (strip/legend):\n"); g <- xml_attr(xml_find_all(doc, "//*[local-name()='g']"), "id")
print(head(grep("strip|guide|legend|key", g, value = TRUE), 10))
cat("\nall element ids unique?", !anyDuplicated(na.omit(c(g, ids))), "\n")
