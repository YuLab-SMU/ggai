# ggai Case Studies

Real-world examples demonstrating complete analysis pipelines with ggai.

## Available Cases

### 1. Brain Development Analysis

**Location**: [brain-dev/](brain-dev/)

Complete pipeline from differential expression to publication graphics.

**Dataset**: GSE207092 - Mouse brain development (NSC vs Neuron)  
**Citation**: [PMID 36889368](https://pubmed.ncbi.nlm.nih.gov/36889368/)

**Pipeline stages:**
1. Differential expression analysis
2. clusterProfiler enrichment
3. Standard enrichment plots
4. Grounded redraw (polish mode)
5. Plot-reader explainer
6. High-density infographic
7. Narrative explanation graphic

**Key outputs:**
- `brain_dev_clusterprofiler_polish_best.png` - Polished enrichment figure
- `brain_dev_plot_reader_best.png` - Annotated plot-reader guide
- `brain_dev_infographic_best.png` - High-density explainer board
- `brain_dev_story_best.png` - Narrative explanation page

**Biological findings:**
- NSC-up genes: cell cycle, DNA replication, developmental patterning
- Neuron-up genes: synapse assembly, postsynaptic organization, vesicle cycling
- Developmental transition from proliferation to connectivity

**Demonstrates:**
- Research discovery workflow
- Multiple communication layers from one analysis
- Plot-reader pedagogy
- Infographic generation
- Story-page narrative design

### 2. ggplot Grammar Editing

**Location**: [ggplot-grammar-editing/](ggplot-grammar-editing/)

Systematic coverage of ggplot grammar transformations via natural language.

**Demonstrates:**
- Scale transformations (log, sqrt, reverse)
- Theme modifications (minimal, classic, custom)
- Faceting (wrap, grid, free scales)
- Coordinate systems (flip, polar, fixed ratio)
- Annotation layers (text, segments, shapes)
- Guide customization (legend position, labels)

**Use case**: Understanding what ggplot operations ggai can handle through agents.

### 3. ggplot Grammar Editing (Live)

**Location**: [ggplot-grammar-editing-live/](ggplot-grammar-editing-live/)

Live execution version of grammar editing examples with actual API calls.

**Demonstrates:**
- Real-time agent execution
- Error handling and retry
- Validation traces

### 4. Single-Cell Spatial Template

**Location**: [single-cell-spatial-template/](single-cell-spatial-template/)

Spatial transcriptomics visualization templates.

**Demonstrates:**
- Spatial coordinate plotting
- Cell-type overlays
- Expression heatmaps on tissue sections
- Multi-panel spatial layouts

## Running Case Studies

Each case directory contains:
- Source R scripts
- Generated outputs
- Prompts used for polish/explainer steps
- Analysis summaries

### Example: Brain Development Case

```r
# Run the full pipeline
source("demo/brain_dev_clusterprofiler_case.R")

# Generate plot-reader explainer
source("demo/brain_dev_plot_reader_demo.R")

# Generate infographic
source("demo/brain_dev_infographic_demo.R")

# Generate story figure
source("demo/brain_dev_story_figure_demo.R")
```

## Case Study Structure

Each case typically includes:

```
case-name/
├── *_summary.md              # Analysis summary
├── *_explanation.md          # Figure explanation
├── *_prompt.md              # Prompts used
├── *_analysis.md            # Detailed analysis
├── *_best.png               # Best output
├── *_candidate_*.png        # Alternative candidates
└── *_bundle.json            # Polish bundle metadata
```

## Adding New Cases

When contributing new case studies:

1. Create a new directory under `docs/cases/`
2. Include source data or reference to public datasets
3. Provide complete R scripts for reproducibility
4. Document biological/scientific context
5. Include generated outputs and prompts
6. Write a summary explaining key findings

## Model Requirements

Cases using polish mode require:
- OpenAI-compatible image editing endpoint
- Sufficient timeout settings for image generation
- See [../ggai-agentic-quickstart-faq.md](../ggai-agentic-quickstart-faq.md) for configuration

## Architecture Notes

All cases use the **agent-based architecture**:
- Agents generate and validate ggplot code
- Polish mode bundles references for image models
- Session state tracks full execution history

For architecture details, see [../architecture.md](../architecture.md).
