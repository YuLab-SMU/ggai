# Case G — stitch the 4 before / 4 after PNGs into 2x2 contact sheets.

suppressPackageStartupMessages({
  library(magick)
})

out_dir <- "dev_docs/figures/case-G"

stitch_2x2 <- function(paths, out_path, cell_w = 1024, gap = 24,
                       bg = "white", label_h = 0L, labels = NULL) {
  stopifnot(length(paths) == 4L)
  imgs <- lapply(paths, function(p) {
    img <- image_read(p)
    image_scale(img, as.character(cell_w))
  })
  # pad cell heights to be uniform within a row
  row_heights <- function(pair) {
    h <- max(sapply(pair, function(img) image_info(img)$height))
    lapply(pair, function(img) image_extent(img, geometry = paste0(cell_w, "x", h),
                                            color = bg, gravity = "center"))
  }
  pair1 <- row_heights(imgs[1:2])
  pair2 <- row_heights(imgs[3:4])
  row1 <- image_append(image_join(pair1[[1]], pair1[[2]]))
  row2 <- image_append(image_join(pair2[[1]], pair2[[2]]))
  out  <- image_append(image_join(row1, row2), stack = TRUE)
  image_write(out, out_path)
  invisible(out_path)
}

before_paths <- c(
  file.path(out_dir, "G-before-volcano.png"),
  file.path(out_dir, "G-before-dotplot.png"),
  file.path(out_dir, "G-before-heatmap.png"),
  file.path(out_dir, "G-before-bar.png")
)
after_paths <- c(
  file.path(out_dir, "G-after-volcano.png"),
  file.path(out_dir, "G-after-dotplot.png"),
  file.path(out_dir, "G-after-heatmap.png"),
  file.path(out_dir, "G-after-bar.png")
)

stitch_2x2(before_paths, file.path(out_dir, "G-before-grid.png"))
cat("Wrote G-before-grid.png\n")

stitch_2x2(after_paths, file.path(out_dir, "G-after-grid.png"))
cat("Wrote G-after-grid.png\n")
