.libPaths(c("/tmp/ggai_research/rlib", .libPaths()))
library(shiny); library(ggplot2); library(patchwork)
mt <- mtcars; mt$car <- rownames(mt)

ui <- fluidPage(
  h4("facet_wrap(~cyl) + geom_point + geom_smooth"),
  plotOutput("facet", width = "720px", height = "360px",
             click = "facet_click", dblclick = "facet_dblclick",
             hover = hoverOpts("facet_hover", delay = 100),
             brush = brushOpts("facet_brush", delay = 100)),
  h5("click"), verbatimTextOutput("click_info"),
  h5("brush"), verbatimTextOutput("brush_info"),
  h4("base par(mfrow = c(1, 2))"),
  plotOutput("base", width = "600px", height = "300px", click = "base_click"),
  h4("patchwork"),
  plotOutput("pw", width = "600px", height = "300px", click = "pw_click"),
  verbatimTextOutput("other_info")
)

server <- function(input, output, session) {
  output$facet <- renderPlot({
    ggplot(mt, aes(wt, mpg)) + geom_point(aes(colour = factor(gear))) +
      geom_smooth(method = "lm", formula = y ~ x) + facet_wrap(~cyl)
  }, res = 96)
  output$click_info <- renderPrint({
    req(input$facet_click)
    cat("input$facet_click:\n"); str(input$facet_click)
    cat("\nnearPoints():\n")
    print(nearPoints(mt, input$facet_click, threshold = 10, maxpoints = 3, addDist = TRUE)[, c("car", "wt", "mpg", "cyl", "dist_")])
  })
  output$brush_info <- renderPrint({
    req(input$facet_brush)
    cat("input$facet_brush:\n"); str(input$facet_brush)
    cat("\nbrushedPoints():\n")
    print(brushedPoints(mt, input$facet_brush)[, c("car", "wt", "mpg", "cyl")])
  })
  output$base <- renderPlot({ par(mfrow = c(1, 2)); plot(mt$wt, mt$mpg); plot(mt$hp, mt$qsec) })
  output$pw <- renderPlot({
    (ggplot(mt, aes(wt, mpg)) + geom_point()) + (ggplot(mt, aes(hp, qsec)) + geom_point())
  })
  output$other_info <- renderPrint({ str(list(base_click = input$base_click, pw_click = input$pw_click)) })
}

shinyApp(ui, server)
