# ggplot + ggai Integration

## Core Message

`ggai` does not replace `ggplot`.

It complements `ggplot` in two ways:

1. `ggplot` remains the right tool for statistical graphics and data mapping.
2. `ggai` adds AI-generated communication layers and AI-native figure generation on top of that workflow.

## The Correct Framing

Use this sentence:

> “`ggplot` is still the data graphics engine.  
> `ggai` adds a figure compiler and communicative figure generation layer.”

## What To Show

### Code Pattern

```r
base_plot <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point() +
  theme_minimal()

augmented <- base_plot + geom_ai(
  "Highlight the most extreme heavy low-MPG outlier, annotate the light high-efficiency cluster, and keep everything additive."
)
```

### Explain

- `ggplot` still controls:
  - data
  - aes mapping
  - statistical layers
  - themes/scales
- `ggai` contributes:
  - AI-compiled annotation layers
  - communicative emphasis
  - inspectable sidecar
  - `as_code()` export for the added layer logic

## Why This Matters

This framing removes a major objection:

- you are not asking analysts to abandon `ggplot`
- you are giving them a way to add figure-level communication and AI-assisted annotation

That makes adoption much easier inside a research group.

## Demo Script

Use:

[`demo/ggplot_integration_demo.R`](/Users/xiayh/Projects/ggai/demo/ggplot_integration_demo.R)

Outputs:

- `demo_outputs/ggplot_integration_base.png`
- `demo_outputs/ggplot_integration_augmented.png`
- `demo_outputs/ggplot_integration_augmented_code.R`
