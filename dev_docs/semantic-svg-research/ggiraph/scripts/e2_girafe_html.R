# E2: build a real girafe widget (mtcars) and inspect its SVG attributes
suppressPackageStartupMessages({
  library(ggplot2); library(ggiraph); library(xml2); library(htmlwidgets)
})
out <- "/tmp/ggai_research/ggiraph/out"
d <- mtcars; d$car <- rownames(mtcars); d$cyl <- factor(d$cyl)
p <- ggplot(d, aes(wt, mpg, colour = cyl)) +
  geom_point_interactive(aes(tooltip = car, data_id = car), size = 3) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE) +
  facet_wrap(~am) +
  scale_colour_discrete_interactive(
    data_id = c("4" = "cyl4", "6" = "cyl6", "8" = "cyl8"),
    tooltip = c("4" = "4 cylinders", "6" = "6 cylinders", "8" = "8 cylinders")
  )
t0 <- Sys.time()
g <- girafe(ggobj = p, width_svg = 7, height_svg = 4, canvas_id = "svg_mtcars",
            options = list(opts_selection(type = "multiple"),
                           opts_selection_key(type = "single"),
                           opts_hover(css = "fill:red;")))
cat("girafe() seconds:", format(as.numeric(Sys.time() - t0), digits = 3), "\n")
svg_txt <- g$x$html
writeLines(svg_txt, file.path(out, "e2_girafe.svg"))
saveWidget(g, file.path(out, "e2_girafe.html"), selfcontained = TRUE, title = "ggiraph mtcars")
doc <- read_xml(svg_txt)
prim <- xml_find_all(doc, "//*[local-name()='circle' or local-name()='path' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line']")
cat("primitives:", length(prim), "\n"); print(table(xml_name(prim)))
has <- function(a) !is.na(xml_attr(prim, a))
tab <- data.frame(tag = xml_name(prim), id = has("id"), data_id = has("data-id"),
                  key_id = has("key-id"), theme_id = has("theme-id"), title = has("title"))
cat("elements with id attr:", sum(tab$id), "\n")
cat("with data-id:", sum(tab$data_id), " key-id:", sum(tab$key_id), " theme-id:", sum(tab$theme_id), " title:", sum(tab$title), "\n")
print(aggregate(cbind(id, data_id, key_id, title) ~ tag, data = tab, FUN = sum))
# which elements carry data-id: by tag
cat("\nSample of data-id circles:\n")
ci <- xml_find_all(doc, "//*[local-name()='circle'][@data-id]")
print(head(xml_attrs(ci), 3))
cat("\nkey-id elements:\n"); print(xml_attrs(xml_find_all(doc, "//*[@key-id]")))
cat("\nall attribute names on any element:\n")
allel <- xml_find_all(doc, "//*")
print(sort(table(unlist(lapply(xml_attrs(allel), names))), decreasing = TRUE))
# smooth path: polyline without data-id?
pl <- xml_find_all(doc, "//*[local-name()='polyline']")
cat("\npolylines:", length(pl), " with id:", sum(!is.na(xml_attr(pl, "id"))), "\n")
# order check: do data circles follow built row order within panel?
b <- ggplot_build(p)
bd <- b$data[[1]]
cat("built layer1 data_id order (first 5):", paste(head(bd$data_id, 5), collapse = ", "), "\n")
cat("svg circle data-id order (first 5):", paste(head(xml_attr(ci, "data-id"), 5), collapse = ", "), "\n")
cat("identical order:", identical(as.character(bd$data_id), xml_attr(ci, "data-id")), "\n")
cat("girafe dependencies:\n"); print(vapply(g$dependencies, function(x) paste(x$name, x$version), ""))
cat("html size bytes:", file.size(file.path(out, "e2_girafe.html")), "\n")
