library(ggplot2)
library(ggai)

p <- ggplot(mtcars, aes(wt, mpg)) +
  geom_point(color = "#355C7D", size = 2.5) +
  geom_ai("圈出右上角的异常点，并给最突出的点加文字标签")

print(p)
