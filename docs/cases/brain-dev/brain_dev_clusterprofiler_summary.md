# Brain Development clusterProfiler Case

Dataset: GSE207092
Comparison: NSC vs Neuron

## Statistical design

- Expression matrix: processed TPM table from GEO
- Genes retained: protein-coding genes with non-missing symbols
- Contrast: NSC - Neuron
- Method: limma moderated linear model with empirical Bayes shrinkage
- Significance threshold: adjusted p-value < 0.05 and |logFC| > 1

## Key counts

- Significant genes (padj < 0.05): 11052
- Significant genes (padj < 0.05, |logFC| > 1): 6181
- Up in NSC: 3179
- Up in Neuron: 3002

## Top GO biological process terms among genes elevated in NSC

1. mitotic cell cycle phase transition | GeneRatio=167/2901 | Count=167 | padj=1.16e-50
2. regulation of cell cycle phase transition | GeneRatio=170/2901 | Count=170 | padj=3.21e-50
3. chromosome segregation | GeneRatio=162/2901 | Count=162 | padj=1.83e-49
4. negative regulation of cell cycle | GeneRatio=155/2901 | Count=155 | padj=3.66e-49
5. positive regulation of cell cycle | GeneRatio=142/2901 | Count=142 | padj=8.04e-47
6. regulation of mitotic cell cycle phase transition | GeneRatio=136/2901 | Count=136 | padj=2.45e-44

## Top GO biological process terms among genes elevated in neurons

1. regulation of synapse structure or activity | GeneRatio=183/2707 | Count=183 | padj=1.8e-77
2. regulation of synapse organization | GeneRatio=177/2707 | Count=177 | padj=5.77e-74
3. synapse assembly | GeneRatio=154/2707 | Count=154 | padj=5.58e-73
4. vesicle-mediated transport in synapse | GeneRatio=155/2707 | Count=155 | padj=9.03e-71
5. synaptic vesicle cycle | GeneRatio=129/2707 | Count=129 | padj=1.78e-59
6. cognition | GeneRatio=158/2707 | Count=158 | padj=6.28e-56
7. learning or memory | GeneRatio=147/2707 | Count=147 | padj=3.38e-55
8. postsynapse organization | GeneRatio=136/2707 | Count=136 | padj=2.26e-54
9. regulation of postsynaptic membrane potential | GeneRatio=96/2707 | Count=96 | padj=7.93e-52
10. neurotransmitter transport | GeneRatio=116/2707 | Count=116 | padj=9.58e-52

## Biological reading

This contrast cleanly separates two developmental programs. Genes elevated in NSC are dominated by cell-cycle, DNA-replication, and nuclear-division terms, which is the expected signature of proliferative neural stem and progenitor cells.

Genes elevated in neurons are dominated by synapse assembly, postsynaptic organization, synaptic vesicle cycling, neurotransmitter transport, and cognition-related terms, which matches the transition toward functional neuronal maturation.

Statistically, the limma moderated t-test is important here because there are only two replicates per condition. Empirical Bayes shrinkage stabilizes variance estimates and makes the ranking more reliable than naive per-gene t-tests.

## Output files

- Differential expression table: brain_dev_clusterprofiler_de_table.csv
- GO enrichment table (NSC): brain_dev_clusterprofiler_go_nsc.csv
- GO enrichment table (Neuron): brain_dev_clusterprofiler_go_neuron.csv
- Dotplot: brain_dev_clusterprofiler_dotplot.png
- Emapplot: brain_dev_clusterprofiler_emapplot.png
- Cnetplot: brain_dev_clusterprofiler_cnetplot.png
