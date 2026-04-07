# ggplot + ggai Feature Coverage

This page exists to answer one predictable question from technical listeners:

> “Does ggai only mean `geom_ai()`?”

The answer is no. The current `ggplot` integration path already demonstrates several capabilities.

## Covered Features

### 1. Base ggplot stays intact

The analytical plot is still a normal `ggplot2` object.

Output:

- `demo_outputs/ggplot_feature_01_base.png`

### 2. `geom_ai()` additive augmentation

Natural-language instruction compiles into additive communication layers.

Outputs:

- `demo_outputs/ggplot_feature_02_geom_ai.png`
- `demo_outputs/ggplot_feature_02_geom_ai_code.R`

### 3. `inspect_spec()`

The compiled layer spec can be inspected in summary or raw form.

### 4. `as_code()`

The AI-added communication logic can be exported back into plain R code.

### 5. `spec_history()`

The plot keeps versioned ggai sidecar history for later review and export.

### 6. `update_spec()`

Patch the compiled spec and rerender.

Outputs:

- `demo_outputs/ggplot_feature_03_update_spec.png`
- `demo_outputs/ggplot_feature_03_update_spec_code.R`

### 7. `edit_spec()`

Edit the compiled spec with a function and rerender.

Output:

- `demo_outputs/ggplot_feature_04_edit_spec.png`

### 8. `geom_point_ai()`

Use generated visual marks as a ggplot layer.

Output:

- `demo_outputs/ggplot_feature_05_geom_point_ai.png`

## Demo Script

Use:

[`demo/ggplot_integration_demo.R`](/Users/xiayh/Projects/ggai/demo/ggplot_integration_demo.R)
