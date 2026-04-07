library(ggplot2)
library(ggai)

p <- ggplot(mtcars, aes(wt, mpg)) +
  geom_point_ai(
    prompt = "paper-style neuron icon",
    mapping = aes(wt, mpg),
    size = 8
  )

print(p)
