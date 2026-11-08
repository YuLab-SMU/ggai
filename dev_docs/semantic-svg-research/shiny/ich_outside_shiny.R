# Is InteractiveComplexHeatmap's hit-testing reusable outside Shiny?
# Draw on a plain png device, record slice positions, then hit-test given positions.
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(ComplexHeatmap); library(InteractiveComplexHeatmap); library(grid) })
set.seed(42)
nr <- 2000; nc <- 40
m <- matrix(rnorm(nr * nc), nr, dimnames = list(paste0("g", 1:nr), paste0("s", 1:nc)))
grp <- rep(c("A", "B"), length.out = nc)
ha <- HeatmapAnnotation(group = grp, score = anno_points(runif(nc)), name = "top")
ra <- rowAnnotation(len = anno_barplot(runif(nr)))
ht <- Heatmap(m, name = "expr", row_km = 2, column_km = 3, top_annotation = ha,
              right_annotation = ra, show_row_names = FALSE, row_km_repeats = 1)
tf <- tempfile(fileext = ".png")
png(tf, width = 800, height = 600, res = 72)
t0 <- Sys.time()
ht <- draw(ht)
pos <- htPositionsOnDevice(ht, include_annotation = TRUE, calibrate = FALSE)
t_pos <- Sys.time() - t0
cat("cells:", nr * nc, " position table rows:", nrow(pos), " size:", format(object.size(as.data.frame(pos)), units = "Kb"),
    " time:", round(as.numeric(t_pos, units = "secs"), 3), "s\n")
print(as.data.frame(pos)[, c("heatmap", "slice", "row_slice", "column_slice")])

# bbox of slice 1_1 in bigpts (= px at res 72), then click at the center of the cell (r, c) of that slice
p11 <- as.data.frame(pos)[pos$slice == "expr_heatmap_body_1_1", ]
x0 <- convertX(pos$x_min[pos$slice == "expr_heatmap_body_1_1"], "bigpts", TRUE)
x1 <- convertX(pos$x_max[pos$slice == "expr_heatmap_body_1_1"], "bigpts", TRUE)
y0 <- convertY(pos$y_min[pos$slice == "expr_heatmap_body_1_1"], "bigpts", TRUE)
y1 <- convertY(pos$y_max[pos$slice == "expr_heatmap_body_1_1"], "bigpts", TRUE)
ro <- row_order(ht)[[1]]; co <- column_order(ht)[[1]]
k_r <- 5; k_c <- 2   # 5th row from the top, 2nd column from the left of slice 1_1
cx <- x0 + (k_c - 0.5) / length(co) * (x1 - x0)
cy <- y1 - (k_r - 0.5) / length(ro) * (y1 - y0)
sel <- selectPosition(ht, pos = unit(c(cx, cy), "bigpts"), mark = FALSE, verbose = FALSE, ht_pos = pos, calibrate = FALSE)
cat(sprintf("\nclick cell (slice 1_1, row %d, col %d): expected row_index=%d (%s) col_index=%d (%s)\n",
            k_r, k_c, ro[k_r], rownames(m)[ro[k_r]], co[k_c], colnames(m)[co[k_c]]))
print(as.data.frame(sel))

# click above the body, on the top annotation track
sel_anno <- selectPosition(ht, pos = unit(c(cx, y1 + 8), "bigpts"), mark = FALSE, verbose = FALSE, ht_pos = pos, calibrate = FALSE)
cat("\nclick on top annotation track ->", if (is.null(sel_anno)) "NULL (not in any heatmap body)" else "hit", "\n")
# click on the column dendrogram (well above the annotation)
sel_dend <- selectPosition(ht, pos = unit(c(cx, y1 + 40), "bigpts"), mark = FALSE, verbose = FALSE, ht_pos = pos, calibrate = FALSE)
cat("click on column dendrogram ->", if (is.null(sel_dend)) "NULL" else "hit", "\n")

# brush across several slices + the row annotation
xr <- convertX(max(pos$x_max, na.rm = TRUE), "bigpts", TRUE)
sa <- selectArea(ht, pos1 = unit(c(x0 + 5, y0 + 50), "bigpts"), pos2 = unit(c(xr + 30, y1 - 10), "bigpts"),
                 mark = FALSE, verbose = FALSE, ht_pos = pos, include_annotation = TRUE, calibrate = FALSE)
sa_df <- as.data.frame(sa)
cat("\nselectArea across slices + right annotation:\n")
print(data.frame(heatmap = sa$heatmap, slice = sa$slice,
                 n_rows = lengths(sa$row_index), n_cols = lengths(sa$column_index)))
dev.off()
