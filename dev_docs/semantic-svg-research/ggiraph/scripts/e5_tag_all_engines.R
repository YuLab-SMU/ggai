# E5: tag-all on other engines: patchwork, base (via gridGraphics), ComplexHeatmap, ggiraph-girafe interplay
source("/tmp/ggai_research/ggiraph/scripts/tag_all.R")
suppressPackageStartupMessages({ library(ggplot2); library(patchwork); library(ComplexHeatmap); library(gridGraphics) })
out <- "/tmp/ggai_research/ggiraph/out"
d <- mtcars; d$cyl <- factor(d$cyl)
run <- function(grob, label, w = 7, h = 4) {
  t0 <- Sys.time()
  res <- withCallingHandlers(render_tagged(grob, file.path(out, paste0("e5_", label, ".svg")), w, h),
    warning = function(w) invokeRestart("muffleWarning"))
  cat(sprintf("--- %s (%.2fs)\n", label, as.numeric(Sys.time() - t0, units = "secs")))
  lg <- summarise_tagged(res, label)
  mm <- lg[!is.na(lg$expected) & lg$expected != lg$emitted, ]
  if (nrow(mm)) { cat("mismatched leaves (first 6):\n"); print(head(transform(mm, path = substr(path, nchar(path) - 60, nchar(path))), 6)) }
  na <- lg[is.na(lg$expected), ]
  if (nrow(na)) { cat("leaf classes without expected-count rule:\n"); print(table(na$class)) }
  invisible(res)
}

p1 <- ggplot(d, aes(wt, mpg, colour = cyl)) + geom_point()
p2 <- ggplot(d, aes(cyl, mpg)) + geom_boxplot()
run(patchworkGrob(p1 + p2), "patchwork")

# base graphics via gridGraphics::echoGrob
bg <- echoGrob(function() { plot(mtcars$wt, mtcars$mpg, col = mtcars$cyl, pch = 19); abline(lm(mpg ~ wt, mtcars)); legend("topright", legend = c(4, 6, 8), col = c(4, 6, 8), pch = 19) })
res_b <- run(bg, "base_echo")
# base data points: which leaf holds them, and do they bind 1:1 to rows?
pp <- xml_attr(res_b$prim, "data-ggai-path")
circ <- res_b$prim[xml_name(res_b$prim) == "circle"]
cat("base circles:", length(circ), " leaves:\n"); print(table(xml_attr(circ, "data-ggai-path")))
pts <- circ[grepl("points", xml_attr(circ, "data-ggai-path"))]
first <- xml_attr(pts, "data-ggai-path") == xml_attr(pts, "data-ggai-path")[1]
cat("spearman cx vs mtcars$wt for first points leaf:", cor(as.numeric(xml_attr(pts[first], "cx")), mtcars$wt, method = "spearman"), "\n")

# ComplexHeatmap
m <- scale(as.matrix(mtcars[1:8, 1:5]))
ha <- rowAnnotation(cyl = factor(mtcars$cyl[1:8]))
hg <- grid.grabExpr(draw(Heatmap(m, name = "z", right_annotation = ha)), width = 7, height = 4)
res_h <- run(hg, "complexheatmap")
pp <- xml_attr(res_h$prim, "data-ggai-path")
cat("heatmap body rect leaves (names containing 'heatmap_body' or 'rect'):\n")
print(head(sort(table(sub(".*/", "", pp[xml_name(res_h$prim) == "rect"])), decreasing = TRUE), 8))
cat("example heatmap paths:\n"); print(head(unique(pp), 12))
