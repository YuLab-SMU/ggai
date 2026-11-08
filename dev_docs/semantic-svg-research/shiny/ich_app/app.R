.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
suppressPackageStartupMessages({ library(shiny); library(ComplexHeatmap); library(InteractiveComplexHeatmap) })
set.seed(1)
m <- matrix(rnorm(40 * 12), 40, dimnames = list(paste0("g", 1:40), paste0("s", 1:12)))
ht <- draw(Heatmap(m, name = "expr", row_km = 2, column_km = 2,
  top_annotation = HeatmapAnnotation(score = anno_points(runif(12)))))
ui <- fluidPage(InteractiveComplexHeatmapOutput("ht", width1 = 500, height1 = 400))
server <- function(input, output, session) makeInteractiveComplexHeatmap(input, output, session, ht, "ht")
shinyApp(ui, server)
