suppressPackageStartupMessages({library(ggplot2); library(grid); library(xml2)})
prims <- c("circle","polyline","polygon","rect","text","line","path")
is_prim <- function(n) xml_name(n) %in% prims
sig <- function(n) paste(xml_name(n), paste(sprintf("%s=%s", names(xml_attrs(n)), xml_attrs(n)), collapse=" "), xml_text(n))
drawn <- function(doc) { a <- xml_find_all(doc, "//*"); Filter(function(n) is_prim(n) && !length(xml_find_all(n, "ancestor::defs")), a) }
wrap_leaves <- function(x, path = "", env) {
  if (inherits(x, "gTree")) {
    x$children <- do.call(gList, lapply(x$children, function(ch) wrap_leaves(ch, paste0(path, "/", ch$name), env)))
    x$childrenOrder <- names(x$children); return(x) }
  if (inherits(x, "zeroGrob")) return(x)
  env$n <- env$n + 1L; env$leaves[env$n] <- path; v <- x$vp; x$vp <- NULL; groupGrob(x, vp = v)
}
check <- function(label, draw_fun, W = 7, H = 5, grob_fun = NULL) {
  f0 <- tempfile(fileext = ".svg"); svglite::svglite(f0, W, H); draw_fun(); dev.off()
  svglite::svglite(tempfile(fileext=".svg"), W, H); grid.newpage()
  sc <- if (is.null(grob_fun)) { draw_fun(); grid.force(grid.grab(wrap = TRUE)) } else grid.force(grob_fun()); dev.off()
  env <- new.env(); env$n <- 0L; env$leaves <- character()
  wrapped <- wrap_leaves(sc, "", env)
  f1 <- tempfile(fileext = ".svg"); svglite::svglite(f1, W, H); grid.newpage(); grid.draw(wrapped); dev.off()
  d0 <- read_xml(f0); xml_ns_strip(d0); d1 <- read_xml(f1); xml_ns_strip(d1)
  gp <- xml_find_all(d1, "//defs/g[starts-with(@id,'group-')]")
  gpr <- setNames(lapply(gp, function(g) Filter(is_prim, xml_find_all(g, ".//*"))), xml_attr(gp, "id"))
  s <- character(); own <- character()
  for (nd in xml_find_all(d1, "//*")) {
    if (xml_name(nd) == "use") { ps <- gpr[[sub("^#","",xml_attr(nd,"href"))]]; s <- c(s, vapply(ps, sig, "")); own <- c(own, rep("g", length(ps))) }
    else if (is_prim(nd) && !length(xml_find_all(nd, "ancestor::defs"))) { s <- c(s, sig(nd)); own <- c(own, "none") } }
  p0 <- vapply(drawn(d0), sig, "")
  cat(sprintf("%-16s leaves=%3d drawn=%4d grouped=%4d identical=%-5s unowned=%d\n", label, env$n, length(p0), length(s), identical(unname(s), unname(p0)), sum(own=="none")))
}
p1 <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point() + geom_smooth(method="lm", formula=y~x) + facet_wrap(~am)
check("ggplot facet", function() print(p1))
if (requireNamespace("patchwork", quietly=TRUE) || requireNamespace("patchwork", lib.loc="/tmp/ggai_research/rlib", quietly=TRUE)) {
  .libPaths(c("/tmp/ggai_research/rlib", .libPaths())); library(patchwork)
  p2 <- ggplot(mtcars, aes(factor(cyl), mpg)) + geom_boxplot()
  check("patchwork", function() print(p1 / p2)) }
bf <- function() { plot(mtcars$wt, mtcars$mpg, pch = 19); abline(lm(mpg ~ wt, mtcars)); legend("topright", "fit", lty = 1) }
check("base via echo", function() grid.draw(gridGraphics::echoGrob(bf)), grob_fun = function() gridGraphics::echoGrob(bf))
suppressPackageStartupMessages(library(ComplexHeatmap))
set.seed(1); m <- matrix(rnorm(80), 10); ha <- HeatmapAnnotation(cyl = sample(c("a","b"), 8, TRUE))
ht <- Heatmap(m, top_annotation = ha, name = "z")
check("ComplexHeatmap", function() draw(ht), grob_fun = function() grid.grabExpr(draw(ht), wrap.grobs = FALSE))
if (requireNamespace("ggrepel", quietly=TRUE)) check("ggrepel", function() print(ggplot(mtcars, aes(wt, mpg, label = rownames(mtcars))) + geom_point() + ggrepel::geom_text_repel(seed = 1)))
big <- data.frame(x = rnorm(1e4), y = rnorm(1e4)); t0 <- Sys.time()
check("1e4 points", function() print(ggplot(big, aes(x, y)) + geom_point(size = .3))); cat("1e4 total secs:", round(as.numeric(Sys.time()-t0),1), "\n")
