suppressPackageStartupMessages({library(grid); library(ComplexHeatmap); library(ggplot2)})
rec <- new.env(); rec$log <- list()
probe <- function(id) gTree(name = paste0("semsvg.probe.", id), cl = "semsvg_probe", id = id)
drawDetails.semsvg_probe <- function(x, recording) {
  ll <- deviceLoc(unit(0, "npc"), unit(0, "npc")); ur <- deviceLoc(unit(1, "npc"), unit(1, "npc"))
  rec$log[[x$id]] <- list(vp = as.character(current.vpPath() %||% "ROOT"),
    box_in = c(x0 = convertX(ll$x, "in", TRUE), y0 = convertY(ll$y, "in", TRUE), x1 = convertX(ur$x, "in", TRUE), y1 = convertY(ur$y, "in", TRUE)))
}
`%||%` <- function(a, b) if (is.null(a)) b else a
wrap <- function(x, path, env) {
  if (inherits(x, "gTree")) { x$children <- do.call(gList, lapply(x$children, function(ch) wrap(ch, paste0(path, "/", ch$name), env))); x$childrenOrder <- names(x$children); return(x) }
  if (inherits(x, "zeroGrob")) return(x)
  env$n <- env$n + 1L; id <- sprintf("leaf%03d", env$n); env$path[id] <- path
  v <- x$vp; x$vp <- NULL
  gTree(children = gList(probe(id), groupGrob(x)), vp = v, name = paste0("semsvg.wrap.", id))
}
set.seed(1); m <- matrix(rnorm(80), 10, dimnames = list(paste0("g", 1:10), paste0("s", 1:8)))
ha <- HeatmapAnnotation(cyl = sample(c("a","b"), 8, TRUE))
ht <- Heatmap(m, top_annotation = ha, name = "z")
f <- tempfile(fileext = ".svg"); svglite::svglite(f, 7, 5); grid.newpage()
sc <- grid.force(grid.grabExpr(draw(ht), wrap.grobs = FALSE)); env <- new.env(); env$n <- 0L; env$path <- character()
w <- wrap(sc, "", env); grid.newpage(); grid.draw(w); invisible(dev.off())
tab <- data.frame(id = names(env$path), grob = basename(env$path),
  vp = vapply(names(env$path), function(i) rec$log[[i]]$vp %||% NA_character_, ""),
  t(vapply(names(env$path), function(i) round(rec$log[[i]]$box_in %||% rep(NA, 4), 2), numeric(4))))
tab$vp <- sub("^global::global_layout::", "", tab$vp); options(width = 220); print(tab[, c("id","grob","vp")], row.names = FALSE)
cat("svg contains probe output? ", any(grepl("probe", readLines(f))), "\n")
