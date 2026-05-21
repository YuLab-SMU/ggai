#!/usr/bin/env Rscript
# Case E · Step 1: vision LLM extracts a structured style spec from the reference dotplot.

suppressPackageStartupMessages({
  library(aisdk)
  library(jsonlite)
})

`%||%` <- function(x, y) if (is.null(x) || (is.atomic(x) && !length(x))) y else x

ref_path <- "dev_docs/figures/orig-paper14-masld-kegg.png"
out_json <- "dev_docs/figures/case-E/style-spec.json"

stopifnot(file.exists(ref_path))

# Vision-capable model. gpt-5.5 (default) is the strongest vision LLM available
# through the jarodfund proxy.
model_id <- Sys.getenv("GGAI_CASE_E_MODEL", "openai:gpt-5.5")

# Schema: structured style spec the R side will consume.
spec_schema <- list(
  type = "object",
  properties = list(
    palette = list(
      type = "object",
      description = "Diverging color ramp for the continuous fill/colour aesthetic (p.adjust).",
      properties = list(
        low  = list(type = "string", description = "Hex code for the LOW end of the colour scale (small p.adjust)."),
        high = list(type = "string", description = "Hex code for the HIGH end of the colour scale (large p.adjust).")
      ),
      required = c("low", "high")
    ),
    background = list(type = "string", description = "Hex code for the panel background."),
    plot_background = list(type = "string", description = "Hex code for the outer plot background."),
    fontface_axis = list(type = "string", enum = c("serif", "sans", "mono"),
                         description = "Font family family hint for axis text."),
    fontsize_axis_y = list(type = "integer", description = "Y-axis text size in pt."),
    fontsize_axis_x = list(type = "integer", description = "X-axis text size in pt."),
    gridlines = list(
      type = "object",
      properties = list(
        horizontal = list(type = "string", enum = c("solid", "dotted", "dashed", "none")),
        vertical   = list(type = "string", enum = c("solid", "dotted", "dashed", "none"))
      ),
      required = c("horizontal", "vertical")
    ),
    legend_position = list(type = "string", enum = c("right", "left", "top", "bottom", "none")),
    facet_strip = list(
      type = "object",
      description = "Strip styling when the plot uses facets at the top of each column.",
      properties = list(
        fill   = list(type = "string", description = "Hex fill for strip background."),
        colour = list(type = "string", description = "Hex text colour for strip labels."),
        bold   = list(type = "boolean")
      ),
      required = c("fill", "colour", "bold")
    ),
    point_shape = list(type = "string",
                       description = "Geom_point shape hint, e.g. 'filled-circle', 'open-circle'."),
    title = list(type = "string", description = "Plot title shown in the reference, verbatim if visible."),
    x_axis = list(type = "string", description = "X axis label as visible in the reference."),
    y_axis = list(type = "string", description = "Y axis label or empty string if hidden."),
    notes = list(type = "string",
                 description = "One-paragraph free-text description of any extra stylistic touches that don't fit the structured fields.")
  ),
  required = c("palette", "background", "fontsize_axis_y", "gridlines",
               "legend_position", "facet_strip", "title")
)

prompt <- paste(
  "You are reading a publication-quality ggplot2 'enrichment dotplot' from a Nature Aging paper.",
  "Extract the visual style — NOT the data — into the schema.",
  "Focus on: colour scale endpoints (for the p.adjust gradient), panel background, gridline style,",
  "axis text font family hint, facet strip styling, legend placement, and overall aesthetic notes.",
  "Pick hex codes that match what you see (do not say 'red'/'blue').",
  "If the y-axis title is hidden (only tick labels visible), return an empty string for y_axis.",
  sep = " "
)

cat("[case-E] Calling vision model:", model_id, "\n")
t0 <- Sys.time()
result <- tryCatch(
  extract_from_image(
    model  = model_id,
    image  = ref_path,  # extract_from_image internally wraps with input_image()
    schema = spec_schema,
    prompt = prompt
  ),
  error = function(e) {
    cat("[case-E] extract_from_image failed:", conditionMessage(e), "\n")
    NULL
  }
)
t1 <- Sys.time()
cat("[case-E] elapsed:", round(as.numeric(difftime(t1, t0, units = "secs")), 1), "s\n")

if (is.null(result)) {
  quit(status = 1)
}

# aisdk returns an R6 GenerateTextResult; structured JSON lives in $text.
spec_text <- tryCatch(result$text, error = function(e) NULL)
if (is.null(spec_text)) {
  for (field in c("output", "value", "object", "raw_response")) {
    cand <- tryCatch(result[[field]], error = function(e) NULL)
    if (is.character(cand) && length(cand) == 1L && nzchar(cand)) {
      spec_text <- cand; break
    }
  }
}
stopifnot(is.character(spec_text), nzchar(spec_text))

# Strip ```json fences if any
spec_text <- sub("^```(json)?\\s*", "", spec_text)
spec_text <- sub("```\\s*$", "", spec_text)

spec <- jsonlite::fromJSON(spec_text, simplifyVector = TRUE)
cat("[case-E] Spec keys:", paste(names(spec), collapse = ", "), "\n")

writeLines(jsonlite::toJSON(spec, auto_unbox = TRUE, pretty = TRUE), out_json)
cat("[case-E] Wrote", out_json, "\n")

# Also persist token usage for the report
usage <- tryCatch(result$usage, error = function(e) NULL)
if (!is.null(usage)) {
  cat("[case-E] Tokens — prompt:", usage$promptTokens %||% usage$prompt_tokens,
      "completion:", usage$completionTokens %||% usage$completion_tokens, "\n")
}
