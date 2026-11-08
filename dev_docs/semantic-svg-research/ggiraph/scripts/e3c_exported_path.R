# Variant without ':::' - reuse ggiraph's registered S3 drawDetails methods by re-classing leaves.
# Still depends on ggiraph's internal object fields (.interactive/.ipar/.data_attr).
suppressPackageStartupMessages({ library(grid); library(ggiraph); library(ggplot2); library(xml2) })
cls_map <- c(points = "interactive_points_grob", text = "interactive_text_grob", rect = "interactive_rect_grob",
             polyline = "interactive_polyline_grob", polygon = "interactive_polygon_grob", segments = "interactive_segments_grob",
             lines = "interactive_lines_grob", circle = "interactive_circle_grob", pathgrob = "interactive_path_grob",
             rastergrob = "interactive_raster_grob", xspline = "interactive_xspline_grob")
skipped <- character(0)
retag <- function(g, path = "") {
  if (inherits(g, "gTree")) { for (nm in g$childrenOrder) g$children[[nm]] <- retag(g$children[[nm]], paste0(path, "/", nm)); return(g) }
  k <- intersect(class(g), names(cls_map))
  if (length(k)) {
    g$.interactive <- list(data_id = path); g$.ipar <- "data_id"; g$.data_attr <- "data-ggai-path"
    class(g) <- c(cls_map[[k[1]]], class(g))
  } else if (!inherits(g, c("zeroGrob", "null"))) skipped <<- c(skipped, class(g)[1])
  g
}
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) + annotate("text", x = 4, y = 32, label = "outlier zone")
f <- "/tmp/ggai_research/ggiraph/out/e3c_exported_path.svg"
dsvg(f, width = 7, height = 4, canvas_id = "svg_x"); grid.newpage(); suppressWarnings(grid.draw(retag(grid.force(ggplotGrob(p))))); invisible(dev.off())
doc <- read_xml(f)
prim <- xml_find_all(doc, "//*[@id='svg_x_rootg']//*[local-name()='circle' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line' or local-name()='path']")
cat("primitives:", length(prim), " with data-ggai-path:", sum(!is.na(xml_attr(prim, "data-ggai-path"))), " skipped leaf classes:", unique(skipped), "\n")
