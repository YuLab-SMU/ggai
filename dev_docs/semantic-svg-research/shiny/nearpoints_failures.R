# Simulate client click payloads (exactly as initCoordmap.ts mouseCoordinateSender
# builds them) at the true drawn pixel position of a mark, then ask nearPoints()
# which data row it is. Tests where data-space hit-testing breaks.
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(shiny); library(ggplot2); library(patchwork) })
sess <- MockShinySession$new(); W <- 600; H <- 400
mt <- mtcars; mt$car <- rownames(mt)

draw <- function(f) shiny:::drawPlot("p", sess, f, W, H, alt = NA, pixelratio = 1, res = 72)

# Build a click payload at image pixel (px, py) the way the JS does.
click_at <- function(cm, px, py) {
  inside <- vapply(cm$panels, function(p) {
    r <- p$range; px >= r$left && px <= r$right && py >= r$top && py <= r$bottom
  }, logical(1))
  if (!any(inside)) return(NULL)  # clip=TRUE: click outside every panel sends nothing
  p <- cm$panels[[which(inside)[1]]]
  d <- shiny:::scaleInvCoords(px, py, p)
  c(list(x = d$x, y = d$y, coords_css = list(x = px, y = py),
         coords_img = list(x = px, y = py), img_css_ratio = list(x = 1, y = 1)),
    p$panel_vars, list(mapping = p$mapping, domain = p$domain, range = p$range, log = p$log))
}

# Pixel position of the k-th point of layer `li` in panel `pan`, from the built data
# and the panel range (only valid for Cartesian coords).
px_of <- function(cm, built, li, k, pan = 1) {
  d <- built$data[[li]]; d <- d[d$PANEL == pan, ][k, ]
  p <- cm$panels[[pan]]
  s <- shiny:::scaleCoords(d$x, d$y, p)
  c(s$x, s$y)
}

report <- function(label, got, truth) {
  cat(sprintf("%-46s truth=%-20s nearPoints-> %s\n", label, truth,
              if (nrow(got)) paste(got$car, collapse = ", ") else "<none>"))
}

## 1. facet_wrap: click exactly on Mazda RX4 (cyl 6, panel 2)
p1 <- ggplot(mt, aes(wt, mpg)) + geom_point() + facet_wrap(~cyl)
r <- draw(function() p1); cm <- r$coordmap; b <- r$plotResult$build
row <- which(mt$car == "Mazda RX4")
s <- shiny:::scaleCoords(mt$wt[row], mt$mpg[row], cm$panels[[2]])
ck <- click_at(cm, s$x, s$y)
report("facet_wrap, click on Mazda RX4", nearPoints(mt, ck, threshold = 3), "Mazda RX4")
cat("  payload panelvar1 =", ck$panelvar1, " mapping =", paste(names(ck$mapping), unlist(ck$mapping), sep = ":", collapse = " "), "\n")

## 2. jitter: click on the drawn (jittered) position of a point
set.seed(1)
p2 <- ggplot(mt, aes(factor(cyl), mpg)) + geom_jitter(width = 0.35, height = 0)
r <- draw(function() p2); cm <- r$coordmap; b <- r$plotResult$build
bd <- b$data[[1]]
# jittered points in built data are in original row order for a single panel
k <- which.max(abs(bd$x - round(bd$x)))   # the most-jittered point
xy <- px_of(cm, b, 1, k)
ck <- click_at(cm, xy[1], xy[2])
cat("  auto-infer with aes(factor(cyl)):", tryCatch({ nearPoints(mt, ck); "ok" }, error = function(e) conditionMessage(e)), "\n")
report(sprintf("geom_jitter, click on drawn point (row %d), xvar='cyl'", k),
       nearPoints(mt, ck, xvar = "cyl", threshold = 5), mt$car[k])
cat(sprintf("  drawn x=%.3f (jittered) vs data x=%s; click mapped to x=%.3f\n", bd$x[k], match(mt$cyl[k], c(4,6,8)), ck$x))

## 3. second layer with a different mapping: click on a red point (hp/50, qsec)
p3 <- ggplot(mt) + geom_point(aes(wt, mpg)) + geom_point(aes(hp / 50, qsec), colour = "red")
r <- draw(function() p3); cm <- r$coordmap; b <- r$plotResult$build
xy <- px_of(cm, b, 2, 1)   # first row of layer 2 = Mazda RX4
got <- nearPoints(mt, click_at(cm, xy[1], xy[2]), threshold = 5)
report("2nd layer (hp/50, qsec), click on Mazda RX4", got, "Mazda RX4")
cat("  coordmap mapping used:", paste(unlist(cm$panels[[1]]$mapping), collapse = ","), "\n")

## 4. coord_polar: click on a drawn point
p4 <- ggplot(mt, aes(wt, mpg)) + geom_point() + coord_polar()
r <- draw(function() p4); cm <- r$coordmap; b <- r$plotResult$build
pg <- ggplot_gtable(b)
panel <- pg$grobs[[which(grepl("^panel", pg$layout$name))[1]]]
pts <- Filter(function(g) inherits(g, "points"), grid::getGrob(panel, grid::gPath(".*"), grep = TRUE, global = TRUE))
if (!length(pts)) pts <- list(panel$children[[grep("geom_point", names(panel$children))]])
g <- pts[[1]]
rg <- cm$panels[[1]]$range
npx <- as.numeric(g$x); npy <- as.numeric(g$y)
i <- which(mt$car == "Cadillac Fleetwood")
px <- rg$left + npx[i] * (rg$right - rg$left); py <- rg$bottom - npy[i] * (rg$bottom - rg$top)
ck <- click_at(cm, px, py)
report("coord_polar, click on Cadillac Fleetwood", nearPoints(mt, ck, threshold = 5), "Cadillac Fleetwood")
cat(sprintf("  click mapped to data x=%.2f y=%.2f; true wt=%.2f mpg=%.2f\n", ck$x, ck$y, mt$wt[i], mt$mpg[i]))

## 5. patchwork: coordmap falls back to base par('usr') of a blank plot.new()
p5 <- (ggplot(mt, aes(wt, mpg)) + geom_point()) + (ggplot(mt, aes(hp, qsec)) + geom_point())
r <- draw(function() p5); cm <- r$coordmap
ck <- click_at(cm, 150, 200)
cat(sprintf("%-46s x=%.3f y=%.3f mapping=%s\n", "patchwork, click at (150,200)", ck$x, ck$y,
            if (length(ck$mapping)) "set" else "empty"))
cat("  nearPoints():", tryCatch({ nearPoints(mt, ck); "ok" }, error = function(e) conditionMessage(e)), "\n")

## 6. base par(mfrow=c(1,2)): only the LAST panel is in the coordmap
r <- draw(function() { par(mfrow = c(1, 2)); plot(mt$wt, mt$mpg); plot(mt$hp, mt$qsec) })
cm <- r$coordmap
cat(sprintf("%-46s panels=%d range.left=%.0f (image width %d)\n", "base mfrow(1,2)", length(cm$panels), cm$panels[[1]]$range$left, W))
cat("  click in left panel ->", if (is.null(click_at(cm, 150, 200))) "NULL (outside only panel)" else "mapped", "\n")
cat("  nearPoints w/o xvar:", tryCatch({ nearPoints(mt, click_at(cm, 450, 200)); "ok" }, error = function(e) conditionMessage(e)), "\n")

## 7. legend key click: outside all panels -> nothing is sent (clip = TRUE)
p7 <- ggplot(mt, aes(wt, mpg, colour = factor(cyl))) + geom_point()
r <- draw(function() p7); cm <- r$coordmap
cat(sprintf("%-46s panel right edge=%.0f; click at x=%d -> %s\n", "legend area click", cm$panels[[1]]$range$right, W - 20,
            if (is.null(click_at(cm, W - 20, 200))) "NULL (not in any panel)" else "mapped"))

## 8. overlapping layers: point + smooth line; click on the smooth line far from points
p8 <- ggplot(mt, aes(wt, mpg)) + geom_point() + geom_smooth(method = "lm", formula = y ~ x)
r <- draw(function() p8); cm <- r$coordmap; b <- r$plotResult$build
sm <- b$data[[2]]; j <- 40
s <- shiny:::scaleCoords(sm$x[j], sm$y[j], cm$panels[[1]])
got <- nearPoints(mt, click_at(cm, s$x, s$y), threshold = 5, addDist = TRUE)
cat(sprintf("%-46s rows within 5px: %d (%s) -- the line itself has no row\n", "click on geom_smooth line", nrow(got), paste(got$car, collapse = ", ")))

## 9. brushedPoints with a 2-var x expression mapping
p9 <- ggplot(mt, aes(wt * 1000, mpg)) + geom_point()
r <- draw(function() p9); cm <- r$coordmap
br <- c(list(xmin = 2000, xmax = 3000, ymin = 10, ymax = 40, direction = "xy"),
        list(mapping = cm$panels[[1]]$mapping, domain = cm$panels[[1]]$domain))
cat(sprintf("%-46s %s\n", "aes(wt*1000, mpg) brushedPoints():",
            tryCatch({ nrow(brushedPoints(mt, br)) }, error = function(e) conditionMessage(e))))
