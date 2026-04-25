# Brain Development Explainer Showcase

This is the strongest end-to-end communication case in `ggai` right now.

It uses a real mouse brain-development dataset and shows four layers of figure-making as separate but connected products:

1. data and differential expression
2. statistical enrichment figures
3. grounded whole-image redraw
4. higher-level explanation graphics driven by `baoyu-*` visual grammar

## Data and contrast

- GEO accession: [GSE207092](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE207092)
- Study citation: [PMID 36889368](https://pubmed.ncbi.nlm.nih.gov/36889368/)
- Contrast: `NSC vs Neuron`

The statistical core is unchanged across all downstream figures:

- expression matrix from the public dataset
- `limma` linear model
- empirical Bayes moderation
- GO Biological Process enrichment with `clusterProfiler`

That matters because there are only two replicates per condition. The `limma + eBayes` layer is not decorative detail. It is the reason the contrast is statistically defensible.

## Figure stack

### 1. Ground truth statistical figures

- [brain_dev_clusterprofiler_dotplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_dotplot.png)
- [brain_dev_clusterprofiler_emapplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_emapplot.png)
- [brain_dev_clusterprofiler_cnetplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_cnetplot.png)

These remain the evidence base.

### 2. Grounded redraw

![Brain Development Grounded Redraw](../demo_outputs/brain_dev_clusterprofiler_polish_best.png)

This is still fundamentally a statistical figure. It keeps the dotplot backbone and makes it more readable and more editorial.

### 3. High-density explainer board

![Brain Development Infographic](../demo_outputs/brain_dev_infographic_best.png)

This layer reorganizes the same case into:

- dataset and comparison
- statistical design
- differential-expression counts
- NSC-side enrichment programs
- neuron-side enrichment programs
- a compact biological conclusion

The governing visual grammar is `dense-modules + pop-laboratory`.

Related files:

- [brain_dev_infographic_prompt.json](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_infographic_prompt.json)
- [brain_dev_infographic_prompt.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_infographic_prompt.md)
- [brain_dev_infographic_explanation.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_infographic_explanation.md)

### 4. Narrative explanation page

![Brain Development Story Figure](../demo_outputs/brain_dev_story_best.png)

This layer goes one level higher than redraw. It is not trying to be a chart. It is trying to teach the conceptual transition:

- unstable small-sample measurements need moderation
- NSC is dominated by proliferation programs
- neuron is dominated by connection and signaling programs
- brain development here is a transition from copying to communication

The governing visual grammar comes from `baoyu-comic`'s concept-story logic, but the rendering still runs through `ggai`/`aisdk`.

Related files:

- [brain_dev_story_prompt.json](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_story_prompt.json)
- [brain_dev_story_prompt.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_story_prompt.md)
- [brain_dev_story_explanation.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_story_explanation.md)

## What this showcase proves

The important point is not that an image model can decorate a chart.

The stronger claim is that one grounded analysis can support multiple communication layers:

- a raw statistical figure for specialists
- a polished redraw for presentation
- an information-dense explainer for cross-disciplinary readers
- a narrative concept figure for higher-level understanding

That is closer to a real scientific communication system than a plotting wrapper.

## Reproduce

Run the statistical case first:

```bash
Rscript demo/brain_dev_clusterprofiler_case.R
```

Then generate the higher-level explainer figures:

```bash
Rscript demo/brain_dev_story_figure_demo.R
```
