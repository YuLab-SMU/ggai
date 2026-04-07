library(ggai)

p <- ggdiagram(width = 12, height = 7, background = "#FCFCF8", theme = "paper") +
  geom_ai("画一个 transformer block，左边输入 token，经过 embedding、attention、mlp，右边输出 logits；如果没有明确坐标，请自动布局，并尽量使用统一主题风格")

print(p)
