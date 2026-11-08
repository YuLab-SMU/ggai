suppressPackageStartupMessages({library(ggplot2); library(ggiraph); library(htmlwidgets)})
d <- mtcars; d$car <- rownames(mtcars); d$cyl <- factor(d$cyl)
p <- ggplot(d, aes(wt, mpg, colour = cyl)) +
  geom_point_interactive(aes(tooltip = car, data_id = car), size = 3) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE) + facet_wrap(~am) +
  scale_colour_discrete_interactive(data_id = c("4" = "cyl4", "6" = "cyl6", "8" = "cyl8"),
    tooltip = c("4" = "4 cylinders", "6" = "6 cylinders", "8" = "8 cylinders"))
g <- girafe(ggobj = p, width_svg = 7, height_svg = 4, canvas_id = "svg_mtcars",
  options = list(opts_selection(type = "multiple", only_shiny = FALSE), opts_selection_key(type = "single", only_shiny = FALSE), opts_hover(css = "fill:red;")))
dir.create("/tmp/ggai_research/ggiraph/serve/nsc", showWarnings = FALSE)
saveWidget(g, "/tmp/ggai_research/ggiraph/serve/nsc/index.html", selfcontained = FALSE, libdir = "lib", title = "ggiraph mtcars nsc")
