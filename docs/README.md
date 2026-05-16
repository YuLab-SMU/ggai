# ggai Documentation

`ggai` is an agent-based R package for turning natural-language figure instructions into publication-ready visualizations.

## Quick Links

- [Quick Start FAQ](ggai-agentic-quickstart-faq.md) - Setup, model configuration, and common issues
- [Architecture](architecture.md) - Multi-agent architecture (Goal, Repair, Spec Committer, Acquisition)
- [Usage Scenarios](usage-scenarios/) - Six runnable examples covering all major workflows
- [Case Studies](cases/) - Real-world examples with full analysis pipelines

## Architecture

ggai uses a **multi-agent architecture** with four specialized agent types:

- **Goal Agent** - Autonomous completion of natural-language visualization goals
- **Repair Agent** - Iterative plot editing with validation loops
- **Spec Committer Agent** - Structured spec generation
- **Acquisition Agent** - Data acquisition and context gathering

All agents use tools to inspect data, generate code, validate outputs, and commit results through bounded execution with decision gates.

## Core Workflows

### 1. Natural Language Plotting

Start from data and a natural language instruction:

```r
library(ggai)
car_data <- mtcars
s <- ggai("@car_data show fuel efficiency vs weight, color by cylinders")
plot(s)
```

### 2. Iterative Editing

Make structured edits while keeping the figure as a ggplot object:

```r
s <- gg_edit(s, "move legend to bottom")
s <- gg_edit(s, "label the most extreme outlier")
plot(s)
```

### 3. Polish Mode

Switch to whole-image redraw for final publication quality:

```r
res <- gg_edit(
  s,
  "turn this into a publication hero figure",
  mode = "polish",
  image_model = image_model
)
```

## Documentation Structure

```
docs/
├── README.md                          # This file
├── ggai-agentic-quickstart-faq.md    # Setup and troubleshooting
├── usage-scenarios/                   # Six Rmd examples
│   ├── 01-natural-language-plotting.Rmd
│   ├── 02-existing-ggplot-augmentation.Rmd
│   ├── 03-iterative-figure-editing.Rmd
│   ├── 04-reference-figure-adaptation.Rmd
│   ├── 05-polish-explainer-graphics.Rmd
│   └── 06-ai-visual-assets.Rmd
├── cases/                             # Real-world case studies
│   ├── brain-dev/                     # Neurobiology enrichment analysis
│   ├── ggplot-grammar-editing/        # Grammar transformation examples
│   └── single-cell-spatial-template/  # Spatial transcriptomics
└── assets/                            # Generated outputs
    └── gallery/                       # Showcase images
```

## Key Concepts

### Session Mode vs Polish Mode

- **Session mode**: Keeps figures as editable ggplot objects, supports iterative refinement
- **Polish mode**: Generates final publication-quality images with AI-enhanced visual design

### Agent-Based Execution

All operations route through agents that:
- Inspect your data structure and content
- Generate and validate ggplot code
- Handle errors and retry with corrections
- Record full execution traces in the session

### Data References

Use `@variable_name` syntax to reference data in your environment:

```r
my_data <- iris
s <- ggai("@my_data show sepal length vs width, color by species")
```

## Case Studies

### Brain Development Analysis

Complete pipeline from differential expression to publication graphics:

- [Case files](cases/brain-dev/)
- Demonstrates: clusterProfiler enrichment, plot-reader explainers, infographic generation
- Source: GSE207092 (mouse brain NSC vs Neuron comparison)

### Grammar Editing Examples

Systematic coverage of ggplot grammar transformations:

- [Case files](cases/ggplot-grammar-editing/)
- Demonstrates: scales, themes, facets, coordinates, annotations

## Running Examples

All usage scenarios are runnable Rmd files:

```r
# Render with local ggplot references (no API calls)
rmarkdown::render("docs/usage-scenarios/01-natural-language-plotting.Rmd")

# Render with live ggai calls
rmarkdown::render(
  "docs/usage-scenarios/01-natural-language-plotting.Rmd",
  params = list(run_live = TRUE)
)
```

## Model Configuration

See [ggai-agentic-quickstart-faq.md](ggai-agentic-quickstart-faq.md) for:
- Setting up OpenAI-compatible endpoints
- Configuring image models for polish mode
- Timeout settings for slow endpoints
- Debugging agent execution

## Contributing

When adding new documentation:
- Usage patterns → add to `usage-scenarios/`
- Real-world examples → add to `cases/`
- Generated outputs → add to `assets/`
- Keep docs focused on current architecture (agent-based, no compiler pipeline)
