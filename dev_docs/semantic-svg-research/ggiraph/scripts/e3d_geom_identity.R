suppressPackageStartupMessages({ library(grid); library(ggiraph); library(ggplot2); library(xml2) })
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) + annotate("text", x = 4, y = 32, label = "outlier zone")
f0 <- tempfile(fileext = ".svg")
dsvg(f0, width = 7, height = 4, canvas_id = "svg_ggai"); suppressWarnings(print(p)); invisible(dev.off())
strip <- function(f) {
  d <- read_xml(f); els <- xml_find_all(d, "//*[@id='svg_ggai_rootg']//*")
  for (a in c("id", "data-ggai-path", "data-ggai-i", "data-ggai-class")) xml_set_attr(els, a, NULL)
  vapply(els, function(e) if (xml_name(e) == "g") "g" else as.character(e), "")
}
a <- strip(f0); b <- strip("/tmp/ggai_research/ggiraph/out/e3_tagged_spike.svg")
a <- a[a != "g"]; b <- b[b != "g"]
cat("untagged print(p) primitives:", length(a), " tagged grid.force tree primitives:", length(b), " identical sequence:", identical(a, b), "\n")
if (!identical(a, b)) { i <- which(a[seq_len(min(length(a), length(b)))] != b[seq_len(min(length(a), length(b)))])[1]; cat("first diff at", i, "\n", substr(a[i], 1, 150), "\n", substr(b[i], 1, 150), "\n") }
