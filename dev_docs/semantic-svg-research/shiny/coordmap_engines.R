# Run shiny's real drawPlot() pipeline (as renderPlot does) on a MockShinySession
# for several engines, and record the coordmap each one produces.
.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({
  library(shiny); library(ggplot2); library(patchwork); library(lattice)
  library(ComplexHeatmap)
})
outdir <- "/tmp/ggai_research/shiny/coordmaps"
dir.create(outdir, showWarnings = FALSE)

sess <- MockShinySession$new()
W <- 600; H <- 400

run <- function(name, expr_fun) {
  res <- tryCatch(
    shiny:::drawPlot(name, sess, expr_fun, W, H, alt = NA, pixelratio = 1, res = 72),
    error = function(e) list(error = conditionMessage(e))
  )
  cm <- res$coordmap
  info <- list(
    plotResult_class = class(res$plotResult),
    n_panels = length(cm$panels),
    coordmap = cm,
    coordmap_error = attr(cm, "error", exact = TRUE),
    error = res$error
  )
  jsonlite::write_json(info, file.path(outdir, paste0(name, ".json")),
                       auto_unbox = TRUE, pretty = TRUE, null = "null", digits = 6)
  cat(sprintf("%-22s class=%-35s panels=%s err=%s\n", name,
              paste(class(res$plotResult), collapse = "/"), length(cm$panels),
              paste(c(attr(cm, "error", exact = TRUE), res$error), collapse = ";")))
  invisible(info)
}

mt <- mtcars; mt$car <- rownames(mt)
base_gg <- ggplot(mt, aes(wt, mpg, colour = factor(gear))) + geom_point()

run("gg_simple",       function() base_gg)
run("gg_facet_wrap",   function() base_gg + facet_wrap(~cyl))
run("gg_facet_grid",   function() base_gg + facet_grid(am ~ cyl))
run("gg_facet_free",   function() base_gg + facet_wrap(~cyl, scales = "free"))
run("gg_coord_flip",   function() base_gg + coord_flip())
run("gg_log_scale",    function() base_gg + scale_y_log10())
run("gg_coord_trans",  function() base_gg + coord_trans(y = "log10"))
run("gg_reverse",      function() base_gg + scale_x_reverse())
run("gg_discrete_x",   function() ggplot(mt, aes(factor(cyl), mpg)) + geom_boxplot() + geom_jitter())
run("gg_layer_mapping",function() ggplot(mt) + geom_point(aes(wt, mpg)) + geom_point(aes(hp/50, qsec), colour = "red"))
run("gg_expr_mapping", function() ggplot(mt, aes(wt * 1000, mpg)) + geom_point())
run("gg_bar_stat",     function() ggplot(mt, aes(factor(cyl))) + geom_bar())
run("gg_coord_polar",  function() ggplot(mt, aes(wt, mpg)) + geom_point() + coord_polar())
run("gg_coord_fixed",  function() base_gg + coord_fixed())
run("gg_coord_sf_like_cartesian_limits", function() base_gg + coord_cartesian(xlim = c(2, 4)))
run("patchwork_2",     function() base_gg + (ggplot(mt, aes(hp, qsec)) + geom_point()))
run("base_single",     function() plot(mt$wt, mt$mpg))
run("base_mfrow",      function() { par(mfrow = c(1, 2)); plot(mt$wt, mt$mpg); plot(mt$hp, mt$qsec) })
run("base_log",        function() plot(mt$wt, mt$mpg, log = "y"))
run("lattice_xyplot",  function() xyplot(mpg ~ wt | factor(cyl), data = mt))
run("grid_only",       function() { grid::grid.newpage(); grid::grid.points(grid::unit(mt$wt/6,"npc"), grid::unit(mt$mpg/40,"npc")) })
m <- as.matrix(scale(mtcars))
run("complexheatmap",  function() draw(Heatmap(m, name = "z")))
run("complexheatmap_obj", function() Heatmap(m, name = "z"))
