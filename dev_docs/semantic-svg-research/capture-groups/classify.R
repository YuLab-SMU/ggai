suppressPackageStartupMessages({library(ggplot2); library(grid); library(xml2); library(ComplexHeatmap)})
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
## ---- capture: group + probe (as verified earlier) -------------------------
capture <- function(draw_grob, W = 7, H = 5) {
  rec <- new.env(); rec$p <- list()
  drawDetails.semprobe <- function(x, recording) rec$p[[x$id]] <- as.character(current.vpPath() %||% "")
  registerS3method("drawDetails", "semprobe", drawDetails.semprobe)
  n <- 0L; leaves <- list()
  wrap <- function(x, path) {
    if (inherits(x, "gTree")) { x$children <- do.call(gList, lapply(x$children, function(ch) wrap(ch, c(path, ch$name)))); x$childrenOrder <- names(x$children); return(x) }
    if (inherits(x, "zeroGrob")) return(x)
    n <<- n + 1L; id <- sprintf("L%03d", n); leaves[[id]] <<- list(path = path, cls = class(x)[1])
    v <- x$vp; x$vp <- NULL
    gTree(children = gList(gTree(cl = "semprobe", id = id), groupGrob(x)), vp = v)
  }
  s <- svglite::svgstring(W, H); grid.newpage(); g <- grid.force(draw_grob()); grid.draw(wrap(g, character())); invisible(dev.off()); svg <- s()
  d <- read_xml(as.character(svg)); xml_ns_strip(d)
  grp <- xml_find_all(d, "//defs/g[starts-with(@id,'group-')]")
  nel <- setNames(vapply(grp, function(g) length(xml_find_all(g, ".//*[self::circle or self::rect or self::polyline or self::polygon or self::text or self::line or self::path]")), 1L), xml_attr(grp, "id"))
  data.frame(id = names(leaves), path = vapply(leaves, function(l) paste(l$path, collapse = "/"), ""),
             cls = vapply(leaves, `[[`, "", "cls"), vp = unlist(rec$p[names(leaves)]) %||% NA,
             n = unname(nel[paste0("group-", seq_along(leaves) - 1L)]), stringsAsFactors = FALSE)
}
## ---- deterministic classification rules ---------------------------------
rule <- function(pat, role, kind) list(pat = pat, role = role, kind = kind)
rules_gg <- list(
  rule("^background|plot\\.background", "decoration", "plot background"),
  rule("panel\\.background|panel\\.border", "decoration", "panel background"),
  rule("panel\\.grid", "reference", "gridline"),
  rule("^axis-[lrtb]", "guide", "axis"),
  rule("^strip-", "guide", "facet strip"),
  rule("^xlab|^ylab", "guide", "axis title"),
  rule("^title|^subtitle|^caption", "text", "plot title"),
  rule("guide-box.*key", "guide", "legend key"),
  rule("guide-box.*label", "guide", "legend label"),
  rule("guide-box.*title", "guide", "legend title"),
  rule("guide-box.*background", "decoration", "legend background"),
  rule("geom_", "data", "layer mark"))
rules_ch <- list(
  rule("heatmap_body", "data", "heatmap cells"), rule("dend_row|dend_column", "data", "dendrogram"),
  rule("row_names|column_names", "guide", "dimension labels"), rule("annotation_.*_\\d+$|annotation_[^:]+::GRID", "data", "annotation track"),
  rule("heatmap_legend|annotation_legend", "guide", "legend"), rule("^global$", "decoration", "background"))
rules_base <- list(
  rule("points|lines|polygon|abline|rect|segments", "data", "layer mark"), rule("axis", "guide", "axis"),
  rule("box", "decoration", "plot box"), rule("xlab|ylab|title|main", "guide", "titles"), rule("legend", "guide", "legend"),
  rule("background|plot\\.new|window", "decoration", "background"))
classify <- function(tab, rules, key = c("path", "vp")) {
  s <- if (identical(key, "vp")) tab$vp else tab$path
  tab$role <- NA; tab$kind <- NA
  for (r in rules) { hit <- is.na(tab$role) & grepl(r$pat, s); tab$role[hit] <- r$role; tab$kind[hit] <- r$kind }
  tab
}
report <- function(label, tab) {
  cat(sprintf("\n== %s: %d leaves, %d elements | classified leaves %d/%d, elements %d/%d\n", label, nrow(tab), sum(tab$n),
      sum(!is.na(tab$role)), nrow(tab), sum(tab$n[!is.na(tab$role)]), sum(tab$n)))
  agg <- aggregate(n ~ role + kind, data = transform(tab, role = ifelse(is.na(role), "UNCLASSIFIED", role), kind = ifelse(is.na(kind), cls, kind)), FUN = sum)
  print(agg[order(agg$role, -agg$n), ], row.names = FALSE)
  if (any(is.na(tab$role))) { cat("unclassified leaves:\n"); print(head(tab[is.na(tab$role), c("path","cls","n")], 8), row.names = FALSE) }
  invisible(tab)
}
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) +
  facet_wrap(~am) + annotate("text", x = 4, y = 32, label = "heavier = thirstier") + labs(title = "Weight vs fuel use")
tg <- report("ggplot", classify(capture(function() ggplotGrob(p)), rules_gg)); saveRDS(tg, "tab_gg.rds")
set.seed(1); m <- matrix(rnorm(80), 10, dimnames = list(paste0("g", 1:10), paste0("s", 1:8)))
ht <- Heatmap(m, top_annotation = HeatmapAnnotation(grp = sample(c("a","b"), 8, TRUE)), name = "z")
report("ComplexHeatmap", classify(capture(function() grid.grabExpr(draw(ht), wrap.grobs = FALSE)), rules_ch, "vp"))
bf <- function() { plot(mtcars$wt, mtcars$mpg, pch = 19, main = "base"); abline(lm(mpg ~ wt, mtcars)); legend("topright", "fit", lty = 1) }
tb <- capture(function() gridGraphics::echoGrob(bf)); report("base", classify(tb, rules_base))
