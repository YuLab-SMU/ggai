suppressPackageStartupMessages({library(grid); library(ComplexHeatmap)})
m <- scale(as.matrix(mtcars[1:8, 1:5]))
hg <- grid.grabExpr(draw(Heatmap(m, name = "z", right_annotation = rowAnnotation(cyl = factor(mtcars$cyl[1:8])))), width = 7, height = 4)
kids <- hg$children[hg$childrenOrder]
info <- do.call(rbind, lapply(kids, function(k) data.frame(name = k$name, class = class(k)[1],
  vp = if (is.null(k$vp)) NA else paste(as.character(k$vp), collapse = ""), n = if (!is.null(k$x)) length(k$x) else NA)))
print(head(info, 20)); cat("children:", length(kids), "\n")
