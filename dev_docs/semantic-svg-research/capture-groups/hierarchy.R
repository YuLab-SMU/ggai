suppressPackageStartupMessages({library(ggplot2)})
tab <- readRDS("tab_gg.rds")
p <- ggplot(mtcars, aes(wt, mpg, colour = factor(cyl))) + geom_point() + geom_smooth(method = "lm", formula = y ~ x) +
  facet_wrap(~am) + annotate("text", x = 4, y = 32, label = "heavier = thirstier") + labs(title = "Weight vs fuel use")
b <- suppressWarnings(ggplot_build(p)); lay <- b$layout$layout
## panel -> facet values
tab$panel <- as.integer(sub("^panel-(\\d+)-.*", "\\1", ifelse(grepl("^panel-", tab$path), tab$path, NA)))
## layer index = order of non-grill children inside each panel gTree (deterministic: ggplot draws layers in order)
inpanel <- !is.na(tab$panel) & !grepl("grill|panel\\.border|panel\\.background", tab$path)
top_child <- sub("^[^/]+/[^/]+/([^/]+).*", "\\1", tab$path)
for (pn in unique(tab$panel[inpanel])) {
  kids <- unique(top_child[inpanel & tab$panel == pn]); tab$layer[inpanel & tab$panel == pn] <- match(top_child[inpanel & tab$panel == pn], kids) }
layer_geom <- vapply(p$layers, function(l) class(l$geom)[1], "")
layer_is_annot <- vapply(p$layers, function(l) isFALSE(l$inherit.aes) && is.data.frame(l$data) && !isTRUE(l$show.legend), TRUE)
tab$kind[inpanel] <- paste0(layer_geom[tab$layer[inpanel]], ifelse(layer_is_annot[tab$layer[inpanel]], " (annotate layer)", ""))
tab$role[inpanel & layer_is_annot[tab$layer]] <- "annotation?"
## legend keys -> series, from the guide data (deterministic)
gd <- get_guide_data(p, "colour"); keys <- tab[grepl("guide-box.*key", tab$path), ]
key_idx <- as.integer(sub(".*key-(\\d+)-.*", "\\1", keys$path)); kidx <- sort(unique(key_idx))
## ---- print tree ----
cat("figure:", p$labels$title, "\n")
for (pn in sort(unique(tab$panel[!is.na(tab$panel)]))) {
  cat(sprintf(" ├─ panel %d  [am=%s]\n", pn, lay$am[lay$PANEL == pn]))
  sub <- tab[which(tab$panel == pn), ]
  cat(sprintf(" │   ├─ background + gridlines: %d elements\n", sum(sub$n[grepl("grill", sub$path)])))
  for (li in sort(unique(sub$layer[!is.na(sub$layer)]))) {
    s2 <- sub[which(sub$layer == li), ]; bd <- b$data[[li]][b$data[[li]]$PANEL == pn, ]
    cat(sprintf(" │   ├─ layer %d %-28s %3d elements | built rows %2d | groups %s\n", li, s2$kind[1], sum(s2$n), nrow(bd), paste(sort(unique(bd$group)), collapse = ",")))
  }
}
cat(sprintf(" ├─ guide: legend '%s'  (%d elements)\n", p$labels$colour %||% "colour", sum(tab$n[grepl("guide-box", tab$path)])))
for (i in seq_along(kidx)) cat(sprintf(" │   ├─ key %d -> series %s=%s  (%d elements; colour %s)\n", i, "factor(cyl)", gd$.label[i], sum(keys$n[key_idx == kidx[i]]), gd$colour[i]))
ax <- tab[grepl("^axis-", tab$path), ]; cat(sprintf(" ├─ guides: axes %d elements, strips %d, axis titles %d\n", sum(ax$n), sum(tab$n[grepl("^strip", tab$path)]), sum(tab$n[grepl("^xlab|^ylab", tab$path)])))
cat(" └─ open questions for the agent: layer 3 is an annotate() text -> what does it claim, and which layer(s) does it describe?\n")
