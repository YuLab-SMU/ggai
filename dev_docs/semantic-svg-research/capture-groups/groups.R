suppressPackageStartupMessages({library(ggplot2); library(grid); library(xml2)})
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point(size = 3) +
  geom_smooth(method = "lm", se = TRUE, formula = y ~ x) + facet_wrap(~am) +
  annotate("text", x = 4, y = 32, label = "heavier = thirstier")
W <- 7; H <- 4
f <- "/tmp/semsvg_spike/plain.svg"; svglite::svglite(f, W, H); print(p); invisible(dev.off())
svglite::svglite(tempfile(fileext=".svg"), W, H); cat("groups capability:", deparse(dev.capabilities()$groups), "\n")
g <- ggplotGrob(p); grid.newpage(); gf <- grid.force(g); invisible(dev.off())
leaves <- character(); n <- 0L
wrap <- function(x, path = "") {
  if (inherits(x, "gTree")) {
    x$children <- do.call(gList, lapply(x$children, function(ch) wrap(ch, paste0(path, "/", ch$name))))
    x$childrenOrder <- names(x$children); return(x)
  }
  if (inherits(x, c("zeroGrob", "null"))) return(x)
  n <<- n + 1L; leaves[n] <<- path
  groupGrob(x, name = paste0("sem.leaf.", n))
}
gw <- wrap(gf)
f2 <- "/tmp/semsvg_spike/grouped.svg"; svglite::svglite(f2, W, H); grid.newpage(); grid.draw(gw); invisible(dev.off())
cat("leaves wrapped:", n, "\n")
d <- read_xml(f2); xml_ns_strip(d)
gs <- xml_find_all(d, "//defs//g | //g[starts-with(@id,'')]"); 
cat("element names in grouped svg:\n"); print(table(xml_name(xml_find_all(d, "//*"))))
uses <- xml_find_all(d, "//use"); cat("use elements:", length(uses), "\n")
defs_g <- xml_find_all(d, "//defs/*"); cat("defs children:", length(defs_g), " sample:", head(xml_attr(defs_g, "id")), "\n")
prim <- "circle|polyline|polygon|rect|text|line|path"
d0 <- read_xml(f); xml_ns_strip(d0)
p0 <- xml_find_all(d0, sprintf("//*[%s]", paste0("self::", strsplit(prim, "\\|")[[1]], collapse=" or ")))
cat("plain primitives:", length(p0), "\n")
cat(substr(paste(readLines(f2, n = 40), collapse = "\n"), 1, 2500), "\n")

## --- verification -------------------------------------------------------
prims <- c("circle","polyline","polygon","rect","text","line","path")
is_prim <- function(n) xml_name(n) %in% prims
sig <- function(n) paste(xml_name(n), paste(sprintf("%s=%s", names(xml_attrs(n)), xml_attrs(n)), collapse = " "), xml_text(n))
# plain: primitives in document order
plain_sig <- vapply(xml_find_all(d0, "//*")[is_prim(xml_find_all(d0, "//*"))], sig, "")
# grouped: walk document order; when hitting <use>, expand its group's primitives
defs_groups <- xml_find_all(d, "//defs/g[starts-with(@id,'group-')]")
grp_prims <- setNames(lapply(defs_groups, function(g) Filter(is_prim, xml_find_all(g, ".//*"))), xml_attr(defs_groups, "id"))
seq_sig <- character(); owner <- character()
for (nd in xml_find_all(d, "//*")) {
  inside_defs <- length(xml_find_all(nd, "ancestor::defs")) > 0
  if (xml_name(nd) == "use") {
    gid <- sub("^#", "", xml_attr(nd, "href")); ps <- grp_prims[[gid]]
    seq_sig <- c(seq_sig, vapply(ps, sig, "")); owner <- c(owner, rep(gid, length(ps)))
  } else if (is_prim(nd) && !inside_defs) { seq_sig <- c(seq_sig, sig(nd)); owner <- c(owner, "<none>") }
}
cat("\nexpanded primitives:", length(seq_sig), " plain:", length(plain_sig), "\n")
cat("identical sequence (tag+attrs+text):", identical(unname(seq_sig), unname(plain_sig)), "\n")
if (!identical(unname(seq_sig), unname(plain_sig))) { i <- which(seq_sig != plain_sig)[1]; cat("first diff at", i, "\n", seq_sig[i], "\n", plain_sig[i], "\n") }
cat("primitives without a group owner:", sum(owner == "<none>"), "\n")
# group k <-> leaf k mapping, and per-leaf counts
gid_num <- as.integer(sub("group-", "", names(grp_prims)))
cnt <- data.frame(group = gid_num, n = lengths(grp_prims))
cnt$leaf <- leaves[cnt$group + 1L]
pts <- cnt[grepl("geom_point", cnt$leaf), ]; print(pts)
cat("leaves with 0 primitives:", sum(cnt$n == 0), "\n")
b <- ggplot_build(p); cat("built rows per panel (layer 1):", paste(table(b$data[[1]]$PANEL), collapse="/"), "\n")

## --- fair comparison: drawn primitives only (exclude anything inside <defs>) ---
all0 <- xml_find_all(d0, "//*"); drawn0 <- Filter(function(n) is_prim(n) && length(xml_find_all(n, "ancestor::defs")) == 0, all0)
plain_drawn <- vapply(drawn0, sig, "")
cat("\nplain drawn primitives:", length(plain_drawn), " | clipPath rects in plain:", length(xml_find_all(d0, "//clipPath/rect")), "\n")
strip_style_dup <- function(s) s
same <- identical(unname(seq_sig), unname(plain_drawn)); cat("identical drawn sequence:", same, "\n")
if (!same) { k <- min(length(seq_sig), length(plain_drawn)); i <- which(seq_sig[1:k] != plain_drawn[1:k]); cat("n diffs:", length(i), "\n"); for (j in head(i, 3)) cat(" [", j, "]\n  grouped:", substr(seq_sig[j],1,160), "\n  plain:  ", substr(plain_drawn[j],1,160), "\n") }
