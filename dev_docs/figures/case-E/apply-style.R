#!/usr/bin/env Rscript
# Case E · Step 2: apply the vision-extracted style spec to a ggplot built from
# user GO-enrichment data, then render before / after PNGs.

suppressPackageStartupMessages({
  library(ggplot2)
  library(jsonlite)
  library(scales)
  library(dplyr)
  library(forcats)
  library(tibble)
  library(grid)
})

# --- Inputs ------------------------------------------------------------------
spec_path <- "dev_docs/figures/case-E/style-spec.json"
csv_path  <- "dev_docs/figures/advanced/user-go-enrichment.csv"
out_before <- "dev_docs/figures/case-E/E-before.png"
out_after  <- "dev_docs/figures/case-E/E-after-via-code.png"

stopifnot(file.exists(spec_path), file.exists(csv_path))

spec <- jsonlite::fromJSON(spec_path, simplifyVector = TRUE)
dat  <- readr::read_csv(csv_path, show_col_types = FALSE)

# Sort & lock factor order so the dotplot reads top→bottom by Count.
dat <- dat |>
  mutate(Description = fct_reorder(Description, Count, .desc = FALSE))

# --- Base ggplot — same data for both panels --------------------------------
base_plot <- function(d) {
  ggplot(d, aes(x = GeneRatio, y = Description)) +
    geom_point(aes(size = Count, colour = p.adjust)) +
    scale_size_continuous(range = c(2, 8), name = "Count") +
    labs(x = "GeneRatio", y = NULL, title = "Enriched Pathways")
}

# --- BEFORE: ggplot2 default grey theme -------------------------------------
p_before <- base_plot(dat)
ggsave(out_before, p_before, width = 6.5, height = 5.2, dpi = 220, bg = "white")
cat("[case-E] wrote", out_before, "\n")

# --- apply_style_spec --------------------------------------------------------
#' Apply a vision-extracted style spec to a ggplot.
#'
#' The spec is tolerant: keys may be either the prompt-defined names
#' (palette/background/gridlines/...) OR the alternate names gpt-5.5 returned
#' (p_adjust_gradient/panel_background/gridline_style/...). We unify both.
apply_style_spec <- function(plot, spec) {
  # Tolerant key access — try multiple aliases, return default if none.
  pick <- function(...) {
    keys <- c(...)
    for (k in keys) {
      if (!is.null(spec[[k]])) return(spec[[k]])
    }
    NULL
  }

  palette         <- pick("palette", "p_adjust_gradient", "colour_gradient")
  bg_panel        <- pick("background", "panel_background") %||% "#FFFFFF"
  bg_plot         <- pick("plot_background") %||% bg_panel
  font_axis_hint  <- pick("fontface_axis", "axis_text_font_family_hint") %||% "sans"
  fs_x            <- pick("fontsize_axis_x") %||% 10
  fs_y            <- pick("fontsize_axis_y") %||% 9

  grid_spec       <- pick("gridlines", "gridline_style")
  legend_pos_raw  <- pick("legend_position", "legend_placement") %||% "right"
  facet_strip     <- pick("facet_strip", "facet_strip_styling")

  # --- 1. Continuous colour scale for p.adjust ------------------------------
  if (!is.null(palette) && all(c("low", "high") %in% names(palette))) {
    plot <- plot + scale_colour_gradient(
      low = palette$low, high = palette$high,
      name = "p.adjust",
      labels = scales::label_scientific(digits = 2)
    )
  }

  # --- 2. Theme axes / panel ------------------------------------------------
  # Map textual font hints to one of the three R-portable families.
  family <- if (grepl("serif", font_axis_hint, ignore.case = TRUE) &&
                !grepl("sans", font_axis_hint, ignore.case = TRUE)) {
    "serif"
  } else if (grepl("mono", font_axis_hint, ignore.case = TRUE)) {
    "mono"
  } else {
    "sans"
  }

  # Gridlines — accept both flat ("dotted") and nested ({color,type,size}) forms.
  resolve_grid <- function(g) {
    if (is.null(g)) return(element_line(colour = "#E5E5E5", linewidth = 0.25))
    if (is.character(g) && length(g) == 1L) {
      if (identical(g, "none")) return(element_blank())
      lt <- switch(g, dotted = "dotted", dashed = "dashed", solid = "solid", "solid")
      return(element_line(colour = "#D8D8D8", linewidth = 0.3, linetype = lt))
    }
    if (is.list(g)) {
      colour <- g$color %||% g$colour %||% "#E0E0E0"
      lt     <- g$type  %||% "solid"
      sz     <- switch(g$size %||% "thin",
                       "very thin" = 0.18, "thin" = 0.28, "medium" = 0.45, "thick" = 0.7, 0.3)
      if (identical(lt, "none")) return(element_blank())
      return(element_line(colour = colour, linewidth = sz, linetype = lt))
    }
    element_line(colour = "#E5E5E5", linewidth = 0.25)
  }

  if (is.list(grid_spec) && (any(c("horizontal", "vertical") %in% names(grid_spec)))) {
    grid_major_x <- resolve_grid(grid_spec$vertical)
    grid_major_y <- resolve_grid(grid_spec$horizontal)
    grid_minor   <- element_blank()
  } else if (is.list(grid_spec) && any(c("major", "minor") %in% names(grid_spec))) {
    grid_major_x <- resolve_grid(grid_spec$major)
    grid_major_y <- resolve_grid(grid_spec$major)
    grid_minor   <- resolve_grid(grid_spec$minor)
  } else {
    grid_major_x <- resolve_grid(NULL); grid_major_y <- grid_major_x
    grid_minor   <- element_blank()
  }

  # Legend position
  legend_pos <- if (grepl("right", legend_pos_raw, ignore.case = TRUE)) "right"
                else if (grepl("left",  legend_pos_raw, ignore.case = TRUE)) "left"
                else if (grepl("top",   legend_pos_raw, ignore.case = TRUE)) "top"
                else if (grepl("bottom",legend_pos_raw, ignore.case = TRUE)) "bottom"
                else if (grepl("none",  legend_pos_raw, ignore.case = TRUE)) "none"
                else "right"

  plot <- plot + theme_bw(base_family = family) + theme(
    plot.background  = element_rect(fill = bg_plot,  colour = NA),
    panel.background = element_rect(fill = bg_panel, colour = "#444444", linewidth = 0.4),
    panel.grid.major.x = grid_major_x,
    panel.grid.major.y = grid_major_y,
    panel.grid.minor   = grid_minor,
    axis.text.x  = element_text(size = fs_x, family = family, colour = "#222222"),
    axis.text.y  = element_text(size = fs_y, family = family, colour = "#222222"),
    axis.title.x = element_text(size = fs_x + 1, family = family, colour = "#222222"),
    plot.title   = element_text(size = fs_x + 3, hjust = 0.5, face = "plain",
                                family = family, colour = "#111111"),
    legend.position = legend_pos,
    legend.background = element_rect(fill = bg_panel, colour = NA),
    legend.key        = element_rect(fill = bg_panel, colour = NA),
    strip.background  = if (is.list(facet_strip)) {
      element_rect(fill = facet_strip$fill %||% "#D9D9D9",
                   colour = facet_strip$border_color %||% "#888888",
                   linewidth = 0.3)
    } else element_rect(fill = "#EFEFEF", colour = NA),
    strip.text = if (is.list(facet_strip)) {
      element_text(colour = facet_strip$text_color %||% facet_strip$colour %||% "#111",
                   face = ifelse(isTRUE(facet_strip$bold), "bold", "plain"),
                   family = family)
    } else element_text(family = family),
    plot.margin = margin(8, 12, 8, 8)
  )

  plot
}

`%||%` <- function(x, y) if (is.null(x) || (is.atomic(x) && !length(x))) y else x

# --- AFTER: apply the spec ---------------------------------------------------
p_after <- apply_style_spec(base_plot(dat), spec)
ggsave(out_after, p_after, width = 6.5, height = 5.2, dpi = 220, bg = "white")
cat("[case-E] wrote", out_after, "\n")

# Persist the function so the qmd report can echo it.
saveRDS(p_after, file.path(dirname(out_after), "p_after.rds"))
cat("[case-E] done.\n")
