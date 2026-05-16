---
name: ggai-single-cell-spatial
description: Single-cell and spatial transcriptomics plotting guidance for ggai Agents.
when_to_use: Use for single-cell RNA-seq, Seurat, SingleCellExperiment, UMAP/t-SNE/PCA, marker genes, FeaturePlot, DotPlot, heatmap, violin/boxplot, or spatial transcriptomics plotting requests.
---

# ggai-single-cell-spatial

## Goal

Help ggai produce biologically honest, editable ggplot figures for common
single-cell and spatial transcriptomics tasks. Treat this as domain guidance,
not a source-specific data collector.

## Input Boundary

- If the runtime provides a data frame, use it as the factual source.
- If the user provides a Seurat, SingleCellExperiment, AnnData, or spatial
  object but no extracted data frame is available, inspect the object only with
  available safe R capabilities. Do not invent columns.
- If required data is missing, ask for or derive a defensible plotting data
  frame instead of fabricating biology.
- Preserve source notes: object type, assay/layer, reduction name,
  coordinate columns, marker genes, and any filtering assumptions.

## Common Data Shapes

UMAP or t-SNE cell embedding:

- coordinate columns such as `UMAP_1`, `UMAP_2`, `tSNE_1`, `tSNE_2`,
  `PC_1`, `PC_2`;
- group metadata such as `cell_type`, `cluster`, `seurat_clusters`,
  `sample`, `condition`;
- optional QC columns such as `nCount_RNA`, `nFeature_RNA`, `percent.mt`.

Feature expression map:

- embedding coordinates;
- one numeric expression column for the requested gene;
- optional group or sample metadata.

Marker dot plot:

- group column such as `cell_type` or `cluster`;
- marker column such as `gene`;
- average expression column;
- percent-expressing column.

Spatial spot map:

- tissue coordinate columns such as `spatial_x`, `spatial_y`,
  `spatial_y_plot`, `imagecol`, `imagerow`;
- group or expression columns;
- optional tissue image metadata. If no tissue image is available, label the
  output as a spot-coordinate map rather than a full SpatialFeaturePlot
  remake.

## Plotting Rules

- Preserve coordinates exactly unless the user explicitly asks for a new
  reduction or transformation.
- Use `coord_equal()` or `coord_fixed()` for embedding and tissue coordinate
  maps.
- For cluster/cell-type maps, map color to the group variable. Prefer a
  palette generated from the actual levels.
- Do not hardcode manual scale names unless every data level is covered. If
  names are uncertain, let ggplot choose the scale or build a named palette
  from `levels()` / `unique()`.
- For expression maps, use a continuous color scale. Do not use discrete
  palettes for numeric expression.
- For marker dot plots, map size to percent expressing and color/fill to
  average expression. Do not swap these mappings.
- For marker heatmaps, use tiles with fill mapped to average expression.
- For box/violin plots, keep individual observations visible when the user
  asks to show cells; use low alpha jitter to avoid overplotting.
- For spatial plots, use the tissue x/y coordinates and preserve y-axis
  orientation if the data already provides a plotting y column such as
  `spatial_y_plot`.

## Semantic Checks

Before committing, check the following:

- requested genes exist as columns or are otherwise available;
- requested metadata/group columns exist;
- coordinate columns exist and are numeric;
- expression columns used for color are numeric;
- group variables used for discrete color are factors or character values;
- manual color/fill scales cover all levels when used;
- `pct_expression` remains the size encoding in dot plots;
- `avg_expression` remains the color/fill encoding in dot plots;
- no QC cutoff, assay/layer, or coordinate transformation is silently changed.

## Style Defaults

- Prefer no title unless the user asks for one or the plot needs disclosure.
- Keep axis labels short: `UMAP 1`, `UMAP 2`, `Tissue x`, `Tissue y`,
  `Expression`, `Cell type`, `Cluster`.
- Use minimal or void themes for embedding and spatial maps.
- Use small semi-transparent points for dense cell plots.
- If labels are added at cluster centers, compute centers from the current data
  and keep label text regular-weight.
- For CJK or other non-ASCII text, follow the `ggai-r-fonts` skill before
  adding font-specific code.

## Completion Standard

Commit when the ggplot validates and the visual encodings match the biological
intent. If the plot is only a flattened data-frame approximation of a richer
Seurat/SpatialFeaturePlot output, state that limitation in the source note or
subtitle.

## Failure Standard

Declare a blocker or limitation when:

- the required gene, metadata, reduction, or spatial coordinate data is absent;
- the task requires tissue image background or assay extraction that is not
  available in the current R context;
- the object type requires a package or method that is unavailable and cannot
  be safely loaded.
