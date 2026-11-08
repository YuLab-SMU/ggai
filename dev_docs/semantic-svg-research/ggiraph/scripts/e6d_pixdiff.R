suppressPackageStartupMessages(library(magick))
out <- "/tmp/ggai_research/ggiraph/out"
rd <- function(f) as.integer(image_data(image_flatten(image_read_svg(f, width = 1008)), "rgb"))
a <- rd(file.path(out, "e6_ref_svglite.svg")); b <- rd(file.path(out, "e6_gridsvg.svg"))
d <- apply(abs(a - b), c(1, 2), max)
cat("gridSVG vs svglite: pixels with max channel diff > 25:", sum(d > 25), "of", length(d), sprintf("(%.3f%%)\n", 100 * mean(d > 25)))
c3 <- rd(file.path(out, "e3_tagged_spike.svg"))
d2 <- apply(abs(a - c3), c(1, 2), max)
cat("dsvg tagged vs svglite: pixels with max channel diff > 25:", sum(d2 > 25), sprintf("(%.3f%%)\n", 100 * mean(d2 > 25)))
