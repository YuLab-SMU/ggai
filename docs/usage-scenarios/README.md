# ggai Usage Scenarios

This directory contains six runnable R Markdown examples covering all major ggai workflows.

## Overview

Each scenario is self-contained and demonstrates a specific usage pattern. All files default to `run_live: false`, which renders with local ggplot references and setup checks. Set `run_live: true` to exercise model-backed ggai calls.

## Scenarios

### 1. [Natural Language Plotting](01-natural-language-plotting.Rmd)

Start from data and natural language instructions.

**Key concepts:**
- Data references with `@variable_name`
- Session initialization
- Basic plotting from scratch

**Example:**
```r
car_data <- mtcars
s <- ggai("@car_data show fuel efficiency vs weight, color by cylinders")
```

### 2. [Existing ggplot Augmentation](02-existing-ggplot-augmentation.Rmd)

Enhance existing ggplot objects with AI-powered additions.

**Key concepts:**
- Starting from existing plots
- Adding layers via natural language
- Preserving manual ggplot code

**Example:**
```r
base_plot <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
s <- ggai(base_plot, "add a smooth trend line and label outliers")
```

### 3. [Iterative Figure Editing](03-iterative-figure-editing.Rmd)

Multi-turn editing sessions with full history tracking.

**Key concepts:**
- `gg_edit()` for iterative refinement
- Session state and history
- Inspecting edit traces

**Example:**
```r
s <- ggai("@data show distribution")
s <- gg_edit(s, "move legend to bottom")
s <- gg_edit(s, "use a minimal theme")
spec_history(s)
```

### 4. [Reference Figure Adaptation](04-reference-figure-adaptation.Rmd)

Adapt existing figures to new data or contexts.

**Key concepts:**
- Using reference images
- Style transfer
- Context-aware redrawing

**Example:**
```r
s <- ggai("@new_data recreate this style", reference_image = "template.png")
```

### 5. [Polish and Explainer Graphics](05-polish-explainer-graphics.Rmd)

Generate publication-quality figures with enhanced visual design.

**Key concepts:**
- Polish mode for final outputs
- Whole-image redraw
- Plot-reader explainers
- Infographic generation

**Example:**
```r
res <- gg_edit(
  s,
  "turn this into a publication hero figure",
  mode = "polish",
  image_model = image_model
)
```

### 6. [AI Visual Assets](06-ai-visual-assets.Rmd)

Generate diagrams, icons, and visual elements.

**Key concepts:**
- Diagram generation
- Custom glyphs and icons
- Visual asset integration

**Example:**
```r
diagram <- ggai_diagram("show the central dogma of molecular biology")
```

## Running Examples

### Render with local references (no API calls)

```r
rmarkdown::render("docs/usage-scenarios/01-natural-language-plotting.Rmd")
```

### Render with live ggai calls

```r
rmarkdown::render(
  "docs/usage-scenarios/01-natural-language-plotting.Rmd",
  params = list(run_live = TRUE)
)
```

### Batch render all scenarios

```r
scenarios <- list.files("docs/usage-scenarios", pattern = "^\\d+.*\\.Rmd$", full.names = TRUE)
lapply(scenarios, rmarkdown::render)
```

## Model Configuration

Before running with `run_live = TRUE`, configure your API endpoint:

```r
Sys.setenv(
  OPENAI_BASE_URL = "https://your-endpoint/v1",
  OPENAI_API_KEY = "your-key",
  OPENAI_MODEL = "gpt-5.5",
  OPENAI_IMAGE_MODEL = "gpt-image-2"
)
```

See [../ggai-agentic-quickstart-faq.md](../ggai-agentic-quickstart-faq.md) for detailed setup instructions.

## Architecture Notes

All scenarios use the **agent-based architecture**:
- Agents inspect data and generate validated ggplot code
- Session state tracks full edit history
- No separate compiler pipeline - agents handle all transformations

For architecture details, see [../architecture.md](../architecture.md).
