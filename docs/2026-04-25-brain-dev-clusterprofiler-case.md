# Brain Development clusterProfiler Case

This case study demonstrates the higher-level `ggai` workflow on a real brain-development dataset:

1.  start from public expression data
2.  run differential expression
3.  run `clusterProfiler` enrichment
4.  render standard statistical figures
5.  reinterpret the result as a more explanatory polished figure

## Data source

- GEO accession: [GSE207092](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE207092)
- Study citation: [PMID 36889368](https://pubmed.ncbi.nlm.nih.gov/36889368/)
- Input file used here:
  - `data/GSE207092_BrainDev_RNAseq_TPM_anno.csv.gz`

The case uses the contrast:

- `NSC vs Neuron`

## Why this case is useful

This dataset is a good first case because it naturally supports all four layers of explanation:

- statistics
- enrichment biology
- graph-based pathway relations
- final visual storytelling

It also gives a clean developmental contrast:

- neural stem/progenitor behavior on one side
- neuronal maturation and synaptic function on the other

## Statistical setup

Implemented in:

- [demo/brain_dev_clusterprofiler_case.R](/Users/xiayh/Projects/ggai/demo/brain_dev_clusterprofiler_case.R)

Main analysis choices:

- retain protein-coding genes with non-missing symbols
- compare `NSC` and `Neuron` replicates
- use `limma` with empirical Bayes moderation
- define significance as adjusted p-value `< 0.05` and `|logFC| > 1`
- run GO Biological Process enrichment with `clusterProfiler`

This is important because the dataset has only two replicates per condition. The moderated `limma` approach is much more defensible here than naive per-gene t-tests.

## Main findings

The resulting contrast separates two developmental regimes.

### Genes elevated in NSC

These are dominated by proliferative programs:

- mitotic cell cycle phase transition
- regulation of cell cycle phase transition
- chromosome segregation
- DNA replication
- nuclear division

This is exactly what you would expect from neural stem and progenitor-like cells that are still actively cycling.

### Genes elevated in neurons

These are dominated by maturation and functional signaling programs:

- regulation of synapse structure or activity
- regulation of synapse organization
- synapse assembly
- vesicle-mediated transport in synapse
- synaptic vesicle cycle
- postsynapse organization
- neurotransmitter transport
- learning or memory

This gives a very legible developmental story: the system is moving from proliferation toward neuronal connectivity and synaptic function.

## Generated outputs

Raw differential and enrichment tables:

- [brain_dev_clusterprofiler_de_table.csv](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_de_table.csv)
- [brain_dev_clusterprofiler_go_nsc.csv](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_go_nsc.csv)
- [brain_dev_clusterprofiler_go_neuron.csv](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_go_neuron.csv)

Standard enrichment figures:

- [brain_dev_clusterprofiler_dotplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_dotplot.png)
- [brain_dev_clusterprofiler_emapplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_emapplot.png)
- [brain_dev_clusterprofiler_cnetplot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_cnetplot.png)

Grounded redraw bundle:

- [brain_dev_clusterprofiler_polish_base_plot.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_polish_base_plot.png)
- [brain_dev_clusterprofiler_polish_geometry_overlay.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_polish_geometry_overlay.png)
- [brain_dev_clusterprofiler_polish_layout_overlay.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_polish_layout_overlay.png)
- [brain_dev_clusterprofiler_polish_bundle.json](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_polish_bundle.json)

Final polished result:

- [brain_dev_clusterprofiler_polish_best.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_polish_best.png)

Auto-generated summary:

- [brain_dev_clusterprofiler_summary.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_clusterprofiler_summary.md)

Higher-level explainer layer:

- [brain_dev_infographic_best.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_infographic_best.png)
- [brain_dev_story_best.png](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_story_best.png)
- [brain_dev_infographic_explanation.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_infographic_explanation.md)
- [brain_dev_story_explanation.md](/Users/xiayh/Projects/ggai/demo_outputs/brain_dev_story_explanation.md)
- [Brain Development Explainer Showcase](/Users/xiayh/Projects/ggai/docs/2026-04-25-brain-dev-explainer-showcase.md)

## What this case proves

This is the first example in the repo that really closes the loop:

- not only plot the data
- not only show the statistical enrichment
- not only beautify the figure
- but also preserve and communicate the biological meaning of the result

That is the more ambitious direction for `ggai`:

- data-faithful
- statistically grounded
- biologically interpretable
- visually reconstructed for communication

In short: not just plotting, but explanation through figures.
