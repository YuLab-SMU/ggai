# Case G — apply ONE shared style spec to 4 different chart types in parallel.
# This is the demonstration: one style spec, four chart types, four parallel
# calls, four visually-consistent panels you could ship as one Figure 1.

suppressPackageStartupMessages({
  library(ggai)
  library(parallel)
})

out_dir <- "dev_docs/figures/case-G"
stopifnot(dir.exists(out_dir))

# ----------------------------------------------------------------------------
# THE SHARED STYLE SPEC.
#
# Written once. Plugged into every call. Intentionally chart-type-agnostic:
# describes the *visual language* (palette, typography, gridlines, whitespace),
# leaving chart geometry and data untouched.
# ----------------------------------------------------------------------------
shared_style_spec <- "
Restyle this scientific figure into a unified Nature Aging publication look,
preserving all data, all axes ticks, all labels, all numeric values.

CHANGE only the visual styling:

CANVAS
- White background, no grey panel.
- Thin light-grey HORIZONTAL dotted gridlines only; no vertical gridlines.
- Thin black panel border, 0.5pt.
- Generous internal whitespace; figure breathes.

TYPOGRAPHY
- Clean serif typeface throughout (think Charter / Source Serif).
- Base font size around 10pt; axis tick labels slightly smaller (~8.5pt).
- NO plot title at the top.
- Axis labels: italic-sentence-case, kept short.

PALETTE
- For continuous numeric variables (p-value, z-score, counts):
  viridis sequential palette, deep purple low to bright yellow high.
- For two-tone categorical (up vs down, hot vs cold):
  red #D7263D for up / hot, blue #1B98E0 for down / cold,
  light grey #BFBFBF for non-significant or neutral.
- For ordered single-hue categorical (10 pathways):
  a single muted blue-grey gradient from light to dark.

LEGEND
- Single, right side, right-aligned, vertical layout.
- Legend text in matching serif, ~9pt.
- No boxed legend frame; no drop shadow.

GEOMETRY
- Preserve every data point and every label. DO NOT invent new data.
- DO NOT reorder categories, DO NOT change axis ranges.
- For points: keep the same positions; only restyle stroke/fill/size mapping.
- For bars: keep the same lengths; only restyle fill.
- For tiles: keep the same grid; only restyle the fill ramp.

OVERALL: panels A-D from this figure must read as the SAME figure.
Reader should think 'same paper, same Figure 1, four panels'.
"

jobs <- list(
  list(
    in_path  = file.path(out_dir, "G-before-volcano.png"),
    out_path = file.path(out_dir, "G-after-volcano.png"),
    hint     = "volcano plot. Up = red, Down = blue, NS = light grey."
  ),
  list(
    in_path  = file.path(out_dir, "G-before-dotplot.png"),
    out_path = file.path(out_dir, "G-after-dotplot.png"),
    hint     = paste(
      "dotplot of pathway enrichment.",
      "Dot color encodes -log10(p.adjust) on viridis.",
      "Dot size encodes Count (range 3-12pt).",
      "Pathway labels on the left in serif."
    )
  ),
  list(
    in_path  = file.path(out_dir, "G-before-heatmap.png"),
    out_path = file.path(out_dir, "G-after-heatmap.png"),
    hint     = paste(
      "expression heatmap, genes on y-axis, samples on x-axis.",
      "Replace red-blue diverging fill with a viridis sequential ramp on z-score;",
      "keep white grid lines between cells thin."
    )
  ),
  list(
    in_path  = file.path(out_dir, "G-before-bar.png"),
    out_path = file.path(out_dir, "G-after-bar.png"),
    hint     = paste(
      "horizontal bar chart of top 10 pathways.",
      "Bars filled with a muted blue-grey single-hue gradient;",
      "pathway labels right-aligned in serif on the left side."
    )
  )
)

# ----------------------------------------------------------------------------
# Run the 4 calls in parallel via PSOCK workers (separate R processes — safe
# on macOS, unlike mclapply forks which segfault when curl/openssl reinit).
# ----------------------------------------------------------------------------
run_one <- function(job, style_text) {
  suppressPackageStartupMessages(library(ggai))
  t0 <- Sys.time()
  result <- ggai_edit_image(
    model      = ggai_image_model(),
    image      = job$in_path,
    prompt     = paste0(style_text, "\nCHART TYPE: ", job$hint, "\n"),
    quality    = "high",
    output_dir = tempdir()
  )
  out <- result$images[[1]]$path
  file.copy(out, job$out_path, overwrite = TRUE)
  t1 <- Sys.time()
  list(
    in_path  = job$in_path,
    out_path = job$out_path,
    seconds  = as.numeric(difftime(t1, t0, units = "secs")),
    ok       = file.exists(job$out_path)
  )
}

cat("Starting 4 parallel ggai_edit_image calls (PSOCK workers)...\n")
t0 <- Sys.time()

cl <- makeCluster(min(4L, length(jobs)), type = "PSOCK")
# Forward env vars (API key, base URL) into workers.
env_vars <- c("OPENAI_API_KEY", "OPENAI_BASE_URL", "OPENAI_MODEL",
              "AISDK_CUSTOM_BASE_URL", "AISDK_CUSTOM_MODEL",
              "AISDK_CUSTOM_API_FORMAT", "AISDK_CUSTOM_API_KEY")
for (v in env_vars) {
  val <- Sys.getenv(v, unset = NA)
  if (!is.na(val) && nzchar(val)) {
    pair <- setNames(val, v)
    clusterCall(cl, function(p) do.call(Sys.setenv, as.list(p)), pair)
  }
}
clusterExport(cl, c("run_one", "shared_style_spec"))

results <- parLapply(cl, jobs, function(job) {
  tryCatch(run_one(job, style_text = shared_style_spec),
           error = function(e) {
             list(in_path = job$in_path, out_path = job$out_path,
                  seconds = NA_real_, ok = FALSE, error = conditionMessage(e))
           })
})

stopCluster(cl)
t1 <- Sys.time()
total <- as.numeric(difftime(t1, t0, units = "secs"))

for (r in results) {
  err_msg <- if (!is.null(r$error)) paste0(" ERROR: ", r$error) else ""
  secs <- if (is.null(r$seconds) || is.na(r$seconds)) NA_real_ else r$seconds
  cat(sprintf("  %s -> %s : ok=%s, %.1fs%s\n",
              basename(r$in_path), basename(r$out_path), r$ok,
              secs, err_msg))
}
cat(sprintf("Total wall-clock (parallel): %.1fs\n", total))

# Save a small log for the qmd to pick up.
saveRDS(list(results = results, total_seconds = total),
        file.path(out_dir, "build-case-G-after.rds"))

cat("\nAll done.\n")
