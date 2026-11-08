# For each ggplot variant: take the actual drawn point grobs (npc within each panel),
# convert to image pixels with the coordmap panel range, simulate a click there,
# and test whether nearPoints() returns the row that was drawn at that pixel.
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(shiny); library(ggplot2); library(grid) })
sess <- MockShinySession$new(); W <- 700; H <- 450
mt <- mtcars; mt$car <- rownames(mt); mt$id <- seq_len(nrow(mt))

click_at <- function(cm, px, py) {
  for (p in cm$panels) {
    r <- p$range
    if (px >= r$left && px <= r$right && py >= r$top && py <= r$bottom) {
      d <- shiny:::scaleInvCoords(px, py, p)
      return(c(list(x = d$x, y = d$y, coords_img = list(x = px, y = py),
                    img_css_ratio = list(x = 1, y = 1)), p$panel_vars,
               list(mapping = p$mapping, domain = p$domain, range = p$range, log = p$log)))
    }
  }
  NULL
}

check <- function(label, plot, df = mt, xvar = NULL, yvar = NULL, layer = 1) {
  r <- shiny:::drawPlot("p", sess, function() plot, W, H, alt = NA, pixelratio = 1, res = 72)
  cm <- r$coordmap; b <- r$plotResult$build; gt <- r$plotResult$gtable
  lay <- gt$layout; pidx <- which(grepl("^panel", lay$name)); pidx <- pidx[order(lay$t[pidx], lay$l[pidx])]
  ok <- 0; n <- 0
  for (pn in seq_along(pidx)) {
    panel <- gt$grobs[[pidx[pn]]]
    pts <- grid::getGrob(panel, "geom_point", grep = TRUE, global = TRUE)
    if (is.list(pts) && !inherits(pts, "grob")) pts <- pts[[layer]]
    if (is.null(pts)) next
    bd <- b$data[[layer]]; bd <- bd[bd$PANEL == pn, ]
    rows <- if ("label" %in% names(bd)) bd$label else NULL
    rg <- cm$panels[[pn]]$range
    xs <- as.numeric(pts$x); ys <- as.numeric(pts$y)
    for (k in seq_along(xs)) {
      px <- rg$left + xs[k] * (rg$right - rg$left); py <- rg$bottom - ys[k] * (rg$bottom - rg$top)
      ck <- click_at(cm, px, py); n <- n + 1
      if (is.null(ck)) next
      got <- tryCatch(nearPoints(df, ck, xvar = xvar, yvar = yvar, threshold = 2, maxpoints = 1),
                      error = function(e) NULL)
      truth <- bd$group_id[k]
      if (!is.null(got) && nrow(got) && got$id == truth) ok <- ok + 1
    }
  }
  cat(sprintf("%-34s %3d/%3d drawn points recovered by nearPoints()\n", label, ok, n))
}

# carry the true row id through the build via an unused aesthetic (group_id)
add_id <- function(p) p + aes(group_id = id)
suppressWarnings({
check("plain",                 add_id(ggplot(mt, aes(wt, mpg)) + geom_point()))
check("facet_wrap(~cyl)",      add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + facet_wrap(~cyl)))
check("facet_grid(am~cyl)",    add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + facet_grid(am ~ cyl)))
check("facet_wrap free scales",add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + facet_wrap(~cyl, scales = "free")))
check("coord_flip",            add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + coord_flip()))
check("scale_y_log10",         add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + scale_y_log10()))
check("scale_x_reverse",       add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + scale_x_reverse()))
check("coord_fixed",           add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + coord_fixed()))
check("discrete x (xvar=cyl)", add_id(ggplot(mt, aes(factor(cyl), mpg)) + geom_point()), xvar = "cyl")
check("geom_jitter (xvar=cyl)",add_id(ggplot(mt, aes(factor(cyl), mpg)) + geom_jitter(width = .3, height = 0)), xvar = "cyl")
check("coord_polar",           add_id(ggplot(mt, aes(wt, mpg)) + geom_point() + coord_polar()))
check("layer 2: aes(hp/50,qsec)", add_id(ggplot(mt) + geom_point(aes(wt, mpg)) + geom_point(aes(hp / 50, qsec))), layer = 2)
})
