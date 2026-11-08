# E6: gridSVG 1.7-7 on the spike plot with ggplot2 4.x: id pattern, fidelity, speed
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(ggplot2); library(grid); library(gridSVG); library(xml2) })
cat("gridSVG", as.character(packageVersion("gridSVG")), " ggplot2", as.character(packageVersion("ggplot2")), "\n")
out <- "/tmp/ggai_research/ggiraph/out"
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) +
  annotate("text", x = 4, y = 32, label = "outlier zone")

# reference render with svglite
svglite::svglite(file.path(out, "e6_ref_svglite.svg"), width = 7, height = 4); print(p); invisible(dev.off())

# gridSVG: draw on a (null) pdf device, then export
pdf(NULL, width = 7, height = 4)
suppressWarnings(print(p))
# garnish data points with a row-index attribute BEFORE export (per-element vector)
nm <- grid.ls(print = FALSE)$name
pts <- grep("^geom_point", nm, value = TRUE)
b <- ggplot_build(p)$data[[1]]
for (k in seq_along(pts)) {
  rows <- which(b$PANEL == k)
  grid.garnish(pts[k], `data-row` = as.character(rows), group = FALSE, grep = FALSE, global = FALSE)
}
t0 <- Sys.time()
res <- withCallingHandlers(grid.export(file.path(out, "e6_gridsvg.svg"), exportMappings = "file", exportCoords = "none"),
  warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
cat("grid.export seconds:", format(as.numeric(Sys.time() - t0, units = "secs"), digits = 3), "\n")
invisible(dev.off())

doc <- read_xml(file.path(out, "e6_gridsvg.svg"))
prim <- xml_find_all(doc, "//*[local-name()='circle' or local-name()='path' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line' or local-name()='use']")
cat("primitives (incl <use>):", length(prim), " with id:", sum(!is.na(xml_attr(prim, "id"))), "\n")
print(table(xml_name(prim)))
g <- xml_find_all(doc, "//*[local-name()='g']")
cat("<g> groups:", length(g), " with id:", sum(!is.na(xml_attr(g, "id"))), "\n")
cat("\nsample ids (primitives):\n"); print(head(na.omit(xml_attr(prim, "id")), 12))
cat("\npoint elements:\n")
pe <- prim[grepl("geom_point", xml_attr(prim, "id"))]
print(head(data.frame(tag = xml_name(pe), id = xml_attr(pe, "id"), data_row = xml_attr(pe, "data-row")), 5))
cat("points with data-row:", sum(!is.na(xml_attr(pe, "data-row"))), "of", length(pe), "\n")
cat("\nsmooth/ribbon ids:\n"); print(head(grep("smooth|ribbon|polyline|polygon", na.omit(xml_attr(prim, "id")), value = TRUE), 8))
cat("\nlegend ids:\n"); print(head(grep("guide|key", na.omit(xml_attr(g, "id")), value = TRUE), 8))
cat("\nstrip text ids:\n"); print(grep("strip", na.omit(xml_attr(g, "id")), value = TRUE)[1:6])
# mapping file
mf <- list.files(out, pattern = "e6_gridsvg.*mappings", full.names = TRUE)
cat("\nmapping files:", mf, "\n")
if (length(mf)) { js <- paste(readLines(mf[1]), collapse = ""); js <- sub("^var gridSVGMappings = ", "", js); js <- sub(";\\s*$", "", js); m <- jsonlite::fromJSON(js); cat("mapping keys:", names(m), "\n"); str(m$grobs[grep("geom_point", names(m$grobs))], max.level = 2) }
cat("file sizes: svglite", file.size(file.path(out, "e6_ref_svglite.svg")), " gridSVG", file.size(file.path(out, "e6_gridsvg.svg")), "\n")
# time a second export without garnish to get a clean timing
pdf(NULL, width = 7, height = 4); suppressWarnings(print(p))
t1 <- Sys.time(); invisible(suppressWarnings(grid.export(NULL))); cat("grid.export (to string) seconds:", format(as.numeric(Sys.time() - t1, units = "secs"), digits = 3), "\n")
invisible(dev.off())
# time svglite and dsvg for comparison
t2 <- Sys.time(); svglite::svglite(tempfile(fileext = ".svg"), width = 7, height = 4); suppressWarnings(print(p)); invisible(dev.off()); cat("svglite seconds:", format(as.numeric(Sys.time() - t2, units = "secs"), digits = 3), "\n")
t3 <- Sys.time(); ggiraph::dsvg(tempfile(fileext = ".svg"), width = 7, height = 4); suppressWarnings(print(p)); invisible(dev.off()); cat("dsvg seconds:", format(as.numeric(Sys.time() - t3, units = "secs"), digits = 3), "\n")
# fidelity: rasterize both and diff
library(magick)
a <- image_read_svg(file.path(out, "e6_ref_svglite.svg"), width = 1008)
bimg <- image_read_svg(file.path(out, "e6_gridsvg.svg"), width = 1008)
cat("raster sizes:", paste(image_info(a)[, c("width", "height")], collapse = "x"), "vs", paste(image_info(bimg)[, c("width", "height")], collapse = "x"), "\n")
bimg <- image_resize(bimg, paste0(image_info(a)$width, "x", image_info(a)$height, "!"))
cmp <- image_compare(image_flatten(a), image_flatten(bimg), metric = "AE", fuzz = 10)
cat("pixels differing (fuzz 10%):", attr(cmp, "distortion"), "of", image_info(a)$width * image_info(a)$height, "\n")
image_write(image_append(c(a, bimg)), file.path(out, "e6_svglite_vs_gridsvg.png"))
