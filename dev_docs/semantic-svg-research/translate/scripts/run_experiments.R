## Translation-approach experiment: ggsave PNG (ground truth) vs ggplotly vs canvasXpress
## Run: Rscript /tmp/ggai_research/translate/scripts/run_experiments.R
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({
  library(ggplot2); library(plotly); library(canvasXpress); library(patchwork)
  library(ggrepel); library(htmlwidgets); library(jsonlite)
})
out <- "/tmp/ggai_research/translate/exp"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
W <- 700; H <- 500; DPI <- 96

mt <- mtcars
mt$car <- rownames(mtcars)
mt$cyl_f <- factor(mt$cyl)

figs <- list()
## (a) scatter + lm smooth + facet + annotate
figs$a_facet <- ggplot(mt, aes(wt, mpg, colour = cyl_f)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x) +
  facet_wrap(~am) +
  annotate("text", x = 4.5, y = 32, label = "heavier = thirstier") +
  labs(colour = "cyl")
## (b) patchwork composite
p1 <- ggplot(mt, aes(wt, mpg, colour = cyl_f)) + geom_point() + labs(colour = "cyl")
p2 <- ggplot(mt, aes(cyl_f, mpg, fill = cyl_f)) + geom_boxplot() + labs(x = "cyl", fill = "cyl")
figs$b_patchwork <- p1 + p2
## (c) extension geom: ggrepel
figs$c_repel <- ggplot(mt, aes(wt, mpg, label = car)) +
  geom_point(colour = "red") +
  geom_text_repel(size = 3, seed = 42, max.overlaps = Inf)
## (e) core geoms outside canvasXpress' JS table (pointrange / linerange forest plot)
fp <- data.frame(term = c("age", "sex", "bmi", "smoker"), est = c(0.2, -0.4, 0.6, 1.1),
                 lo = c(0.05, -0.8, 0.3, 0.7), hi = c(0.35, 0.0, 0.9, 1.5))
figs$e_pointrange <- ggplot(fp, aes(est, term, xmin = lo, xmax = hi)) +
  geom_vline(xintercept = 0, linetype = 2) +
  geom_pointrange()

## helpers -------------------------------------------------------------
capture_all <- function(expr) {
  warns <- character(); msgs <- character()
  val <- withCallingHandlers(
    tryCatch(expr, error = function(e) structure(conditionMessage(e), class = "conv_error")),
    warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") },
    message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
  list(value = val, warnings = unique(warns), messages = unique(msgs),
       error = if (inherits(val, "conv_error")) unclass(val) else NULL)
}
zero_pad <- function(w) {  # make the widget fill the viewport exactly (no body padding)
  w$sizingPolicy$padding <- 0
  w$sizingPolicy$browser$padding <- 0
  w$sizingPolicy$browser$fill <- FALSE
  w
}
save_w <- function(w, file) {
  htmlwidgets::saveWidget(w, file.path(out, file), selfcontained = FALSE, libdir = "lib",
                          background = "white")
}

log <- list()
for (nm in names(figs)) {
  p <- figs[[nm]]
  rec <- list(figure = nm)
  ## ground truth
  ggsave(file.path(out, paste0(nm, "_gg.png")), p, width = W / DPI, height = H / DPI, dpi = DPI, bg = "white")
  ## plotly
  r <- capture_all({
    w <- ggplotly(p, width = W, height = H)
    b <- plotly_build(w)  # force conversion so warnings surface here
    b
  })
  rec$plotly <- list(ok = is.null(r$error), error = r$error, warnings = r$warnings, messages = r$messages)
  if (is.null(r$error)) {
    b <- r$value
    tr <- b$x$data
    rec$plotly$n_traces <- length(tr)
    rec$plotly$trace_types <- vapply(tr, function(t) paste(t$type %||% "?", t$mode %||% "", sep = ":"), "")
    rec$plotly$trace_names <- vapply(tr, function(t) as.character(t$name %||% ""), "")
    rec$plotly$has_key <- vapply(tr, function(t) !is.null(t$key), NA)
    rec$plotly$text_sample <- lapply(tr[seq_len(min(3, length(tr)))], function(t) head(t$text, 2))
    rec$plotly$n_annotations <- length(b$x$layout$annotations)
    rec$plotly$annotation_text <- vapply(b$x$layout$annotations, function(a) as.character(a$text %||% ""), "")
    writeLines(plotly_json(b, jsonedit = FALSE, pretty = TRUE), file.path(out, paste0(nm, "_plotly.json")))
    save_w(zero_pad(r$value), paste0(nm, "_plotly.html"))
  }
  ## canvasXpress
  r2 <- capture_all({
    cx <- canvasXpress(p, width = W, height = H)
    cx
  })
  rec$cx <- list(ok = is.null(r2$error), error = r2$error, warnings = r2$warnings, messages = r2$messages)
  if (is.null(r2$error)) {
    spec <- r2$value$x
    writeLines(as.character(spec), file.path(out, paste0(nm, "_cx_spec.json")))
    s <- tryCatch(fromJSON(as.character(spec), simplifyVector = FALSE), error = function(e) NULL)
    if (!is.null(s)) {
      if (isTRUE(s$isPatchwork)) {
        rec$cx$patchwork_n <- length(s$datasets)
        rec$cx$geoms <- lapply(s$datasets, function(d) unlist(d$geoms))
      } else {
        rec$cx$geoms <- unlist(s$geoms)
        rec$cx$data_rows <- length(s$data) - 1
        rec$cx$data_header <- unlist(s$data[[1]])
        rec$cx$facet <- s$facet
        rec$cx$has_decompiled <- !is.null(s$decompiled)
      }
    }
    save_w(zero_pad(r2$value), paste0(nm, "_cx.html"))
  }
  log[[nm]] <- rec
}

## (d) ComplexHeatmap: neither translator accepts it
if (requireNamespace("ComplexHeatmap", quietly = TRUE)) {
  suppressPackageStartupMessages(library(ComplexHeatmap))
  set.seed(1)
  m <- matrix(rnorm(60), 10, dimnames = list(paste0("g", 1:10), paste0("s", 1:6)))
  ht <- Heatmap(m, name = "z", top_annotation = HeatmapAnnotation(grp = rep(c("A", "B"), 3)))
  png(file.path(out, "d_heatmap_gg.png"), width = W, height = H, res = DPI); draw(ht); dev.off()
  rd <- capture_all(ggplotly(ht))
  rc <- capture_all(canvasXpress(ht))
  ## also try the grob route: ggplotify-free, wrap as a ggplot via annotation_custom
  g <- grid::grid.grabExpr(draw(ht))
  pg <- ggplot() + annotation_custom(g) + theme_void()
  rg <- capture_all(plotly_build(ggplotly(pg)))
  rcg <- capture_all(canvasXpress(pg))
  if (is.null(rg$error)) save_w(zero_pad(rg$value), "d_heatmap_grob_plotly.html")
  if (is.null(rcg$error)) save_w(zero_pad(rcg$value), "d_heatmap_grob_cx.html")
  log$d_heatmap <- list(
    figure = "d_heatmap",
    plotly = list(ok = is.null(rd$error), error = rd$error, warnings = rd$warnings),
    cx = list(ok = is.null(rc$error), error = rc$error, warnings = rc$warnings),
    plotly_grob_wrapped = list(ok = is.null(rg$error), error = rg$error, warnings = rg$warnings,
                               n_traces = if (is.null(rg$error)) length(rg$value$x$data) else NA,
                               visible = if (is.null(rg$error)) vapply(rg$value$x$data, function(t) !identical(t$visible, FALSE), NA) else NA),
    cx_grob_wrapped = list(ok = is.null(rcg$error), error = rcg$error, warnings = rcg$warnings)
  )
}

## highlight_key / crosstalk on figure (a)
hk <- highlight_key(mt, ~car)
pa_hk <- ggplot(hk, aes(wt, mpg, colour = cyl_f)) + geom_point() +
  geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~am)
rh <- capture_all(plotly_build(highlight(ggplotly(pa_hk, width = W, height = H), on = "plotly_click")))
if (is.null(rh$error)) {
  tr <- rh$value$x$data
  log$a_highlight_key <- list(
    warnings = rh$warnings,
    traces = lapply(tr, function(t) list(type = t$type, mode = t$mode %||% "", name = t$name %||% "",
                                         n_key = length(t$key), key_head = head(unlist(t$key), 3),
                                         set = t$set %||% NA, xaxis = t$xaxis)),
    highlight = rh$value$x$highlight[c("on", "off", "opacityDim")])
  save_w(zero_pad(rh$value), "a_highlight_plotly.html")
} else log$a_highlight_key <- list(error = rh$error)

writeLines(toJSON(log, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"),
           file.path(out, "conversion_log.json"))
cat("done\n")
