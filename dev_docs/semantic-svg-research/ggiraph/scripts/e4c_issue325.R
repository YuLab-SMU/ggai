suppressPackageStartupMessages({library(ggplot2); library(ggiraph); library(xml2)})
df <- data.frame(id = rep(c("A", "B"), each = 5), time = rep(1:5, 2), value = c(5,5,5,7,9, 1,5,NA,6,8))
g <- withCallingHandlers(girafe(ggobj = ggplot(df, aes(time, value, group = id)) + geom_line_interactive(aes(data_id = id, tooltip = id))),
  warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
doc <- read_xml(g$x$html)
pl <- xml_find_all(doc, "//*[local-name()='g' and contains(@class,'rootg')]//*[local-name()='polyline']")
cat("polylines:", length(pl), " with data-id:", sum(!is.na(xml_attr(pl, "data-id"))), "\n")
