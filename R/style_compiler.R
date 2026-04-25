extract_quoted_text <- function(instruction) {
  m <- regmatches(instruction, regexpr('"[^"]+"', instruction))
  if (length(m) && nzchar(m[[1]])) {
    return(gsub('^"|"$', '', m[[1]]))
  }
  NULL
}

infer_named_colour <- function(instruction) {
  if (grepl("green", instruction, ignore.case = TRUE)) return("#4DAF4A")
  if (grepl("red", instruction, ignore.case = TRUE)) return("#E41A1C")
  if (grepl("blue", instruction, ignore.case = TRUE)) return("#377EB8")
  if (grepl("teal", instruction, ignore.case = TRUE)) return("#0F766E")
  if (grepl("orange", instruction, ignore.case = TRUE)) return("#FF7F00")
  if (grepl("purple", instruction, ignore.case = TRUE)) return("#984EA3")
  NULL
}

named_palette_values <- function(name) {
  switch(
    tolower(name %||% ""),
    set1 = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#FFFF33", "#A65628", "#F781BF"),
    set2 = c("#66C2A5", "#FC8D62", "#8DA0CB", "#E78AC3", "#A6D854", "#FFD92F", "#E5C494", "#B3B3B3"),
    dark2 = c("#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E", "#E6AB02", "#A6761D", "#666666"),
    tableau = c("#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F", "#EDC948", "#B07AA1", "#FF9DA7"),
    NULL
  )
}

extract_first_number <- function(text) {
  nums <- regmatches(text, gregexpr("-?[0-9]+\\.?[0-9]*", text))[[1]]
  if (!length(nums)) return(NULL)
  as.numeric(nums[[1]])
}

style_ops_from_instruction <- function(instruction) {
  ops <- list()
  text <- trimws(instruction %||% "")
  if (!nzchar(text)) {
    return(ops)
  }

  quoted <- extract_quoted_text(text)

  if (grepl("title", text, ignore.case = TRUE) && !grepl("legend title", text, ignore.case = TRUE)) {
    title <- quoted
    if (is.null(title) && grepl("remove title|no title", text, ignore.case = TRUE)) {
      title <- ""
    }
    if (!is.null(title)) {
      ops[[length(ops) + 1L]] <- list(op = "labels", params = list(title = title))
    }
  }

  if (grepl("subtitle", text, ignore.case = TRUE)) {
    value <- quoted
    if (is.null(value) && grepl("remove subtitle|no subtitle", text, ignore.case = TRUE)) value <- ""
    if (!is.null(value)) {
      ops[[length(ops) + 1L]] <- list(op = "labels", params = list(subtitle = value))
    }
  }

  if (grepl("caption", text, ignore.case = TRUE)) {
    value <- quoted
    if (is.null(value) && grepl("remove caption|no caption", text, ignore.case = TRUE)) value <- ""
    if (!is.null(value)) {
      ops[[length(ops) + 1L]] <- list(op = "labels", params = list(caption = value))
    }
  }

  if (grepl("x axis|x-axis|x label|x-label", text, ignore.case = TRUE)) {
    value <- quoted
    if (is.null(value) && grepl("remove x", text, ignore.case = TRUE)) value <- ""
    if (!is.null(value)) ops[[length(ops) + 1L]] <- list(op = "labels", params = list(x = value))
  }

  if (grepl("y axis|y-axis|y label|y-label", text, ignore.case = TRUE)) {
    value <- quoted
    if (is.null(value) && grepl("remove y", text, ignore.case = TRUE)) value <- ""
    if (!is.null(value)) ops[[length(ops) + 1L]] <- list(op = "labels", params = list(y = value))
  }

  if (grepl("legend", text, ignore.case = TRUE)) {
    position <- NULL
    if (grepl("legend.*bottom|bottom.*legend", text, ignore.case = TRUE)) position <- "bottom"
    if (grepl("legend.*top|top.*legend", text, ignore.case = TRUE)) position <- "top"
    if (grepl("legend.*left|left.*legend", text, ignore.case = TRUE)) position <- "left"
    if (grepl("legend.*right|right.*legend", text, ignore.case = TRUE)) position <- "right"
    if (grepl("hide legend|remove legend|no legend", text, ignore.case = TRUE)) position <- "none"
    if (!is.null(position)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(legend.position = position))
    }

    if (grepl("legend title", text, ignore.case = TRUE)) {
      value <- quoted
      if (is.null(value) && grepl("remove legend title|no legend title", text, ignore.case = TRUE)) value <- ""
      if (!is.null(value)) {
        ops[[length(ops) + 1L]] <- list(op = "labels", params = list(colour = value, fill = value))
      }
    }

    if (grepl("legend key size", text, ignore.case = TRUE)) {
      size <- extract_first_number(text)
      if (!is.null(size)) {
        ops[[length(ops) + 1L]] <- list(op = "theme", params = list(legend.key.size = grid::unit(size, "pt")))
      }
    }

    if (grepl("legend text size", text, ignore.case = TRUE)) {
      size <- extract_first_number(text)
      if (!is.null(size)) {
        ops[[length(ops) + 1L]] <- list(op = "theme", params = list(legend.text = ggplot2::element_text(size = size)))
      }
    }

    if (grepl("legend title size", text, ignore.case = TRUE)) {
      size <- extract_first_number(text)
      if (!is.null(size)) {
        ops[[length(ops) + 1L]] <- list(op = "theme", params = list(legend.title = ggplot2::element_text(size = size)))
      }
    }
  }

  if (grepl("plot title size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(plot.title = ggplot2::element_text(size = size)))
  }

  if (grepl("subtitle size|plot subtitle size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(plot.subtitle = ggplot2::element_text(size = size)))
  }

  if (grepl("caption size|plot caption size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(plot.caption = ggplot2::element_text(size = size)))
  }

  if (grepl("x axis title size|axis title x size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.title.x = ggplot2::element_text(size = size)))
  }

  if (grepl("y axis title size|axis title y size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.title.y = ggplot2::element_text(size = size)))
  }

  if (grepl("x axis text size|axis text x size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.text.x = ggplot2::element_text(size = size)))
  }

  if (grepl("y axis text size|axis text y size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.text.y = ggplot2::element_text(size = size)))
  }

  if (grepl("minimal theme|theme_minimal|minimal style", text, ignore.case = TRUE)) {
    ops[[length(ops) + 1L]] <- list(op = "theme_preset", params = list(name = "minimal"))
  }

  if (grepl("classic theme|theme_classic|classic style", text, ignore.case = TRUE)) {
    ops[[length(ops) + 1L]] <- list(op = "theme_preset", params = list(name = "classic"))
  }

  if (grepl("x axis range|x range|x limits", text, ignore.case = TRUE)) {
    nums <- regmatches(text, gregexpr("-?[0-9]+\\.?[0-9]*", text))[[1]]
    if (length(nums) >= 2) {
      ops[[length(ops) + 1L]] <- list(op = "scale_x", params = list(limits = as.numeric(nums[1:2])))
    }
  }

  if (grepl("x axis breaks|x breaks", text, ignore.case = TRUE)) {
    fragment <- sub(".*?(x axis breaks|x breaks)", "", text, ignore.case = TRUE)
    fragment <- sub("(and|;).*$", "", fragment, ignore.case = TRUE)
    nums <- regmatches(fragment, gregexpr("-?[0-9]+\\.?[0-9]*", fragment))[[1]]
    if (length(nums) >= 1) {
      ops[[length(ops) + 1L]] <- list(op = "scale_x", params = list(breaks = as.numeric(nums)))
    }
  }

  if (grepl("y axis range|y range|y limits", text, ignore.case = TRUE)) {
    nums <- regmatches(text, gregexpr("-?[0-9]+\\.?[0-9]*", text))[[1]]
    if (length(nums) >= 2) {
      ops[[length(ops) + 1L]] <- list(op = "scale_y", params = list(limits = as.numeric(nums[1:2])))
    }
  }

  if (grepl("y axis breaks|y breaks", text, ignore.case = TRUE)) {
    fragment <- sub(".*?(y axis breaks|y breaks)", "", text, ignore.case = TRUE)
    fragment <- sub("(and|;).*$", "", fragment, ignore.case = TRUE)
    nums <- regmatches(fragment, gregexpr("-?[0-9]+\\.?[0-9]*", fragment))[[1]]
    if (length(nums) >= 1) {
      ops[[length(ops) + 1L]] <- list(op = "scale_y", params = list(breaks = as.numeric(nums)))
    }
  }

  if (grepl("log scale|log transform|log10", text, ignore.case = TRUE)) {
    if (grepl("(log scale|log transform|log10).*(x axis|x scale)|(x axis|x scale).*(log scale|log transform|log10)", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "scale_x", params = list(trans = "log10"))
    }
    if (grepl("(log scale|log transform|log10).*(y axis|y scale)|(y axis|y scale).*(log scale|log transform|log10)", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "scale_y", params = list(trans = "log10"))
    }
  }

  if (grepl("sqrt scale|square root", text, ignore.case = TRUE)) {
    if (grepl("(sqrt scale|square root).*(x axis|x scale)|(x axis|x scale).*(sqrt scale|square root)", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "scale_x", params = list(trans = "sqrt"))
    }
    if (grepl("(sqrt scale|square root).*(y axis|y scale)|(y axis|y scale).*(sqrt scale|square root)", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "scale_y", params = list(trans = "sqrt"))
    }
  }

  if (grepl("rotate x axis text|x axis text.*angle|angle.*x axis text", text, ignore.case = TRUE)) {
    angle <- extract_first_number(text) %||% 45
    ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.text.x = ggplot2::element_text(angle = angle, hjust = 1)))
  }

  if (grepl("rotate y axis text|y axis text.*angle|angle.*y axis text", text, ignore.case = TRUE)) {
    angle <- extract_first_number(text) %||% 45
    ops[[length(ops) + 1L]] <- list(op = "theme", params = list(axis.text.y = ggplot2::element_text(angle = angle, hjust = 1)))
  }

  if (grepl("minor grid", text, ignore.case = TRUE)) {
    if (grepl("remove|hide|off|no", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.grid.minor = ggplot2::element_blank()))
    } else if (grepl("show|on|add", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.grid.minor = ggplot2::element_line()))
    }
  }

  if (grepl("major grid", text, ignore.case = TRUE)) {
    if (grepl("remove|hide|off|no", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.grid.major = ggplot2::element_blank()))
    } else if (grepl("show|on|add", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.grid.major = ggplot2::element_line()))
    }
  }

  if (grepl("strip text size|facet strip text size", text, ignore.case = TRUE)) {
    size <- extract_first_number(text)
    if (!is.null(size)) ops[[length(ops) + 1L]] <- list(op = "theme", params = list(strip.text = ggplot2::element_text(size = size)))
  }

  if (grepl("strip background", text, ignore.case = TRUE)) {
    fill <- infer_named_colour(text) %||% if (grepl("remove|hide|none", text, ignore.case = TRUE)) NA else NULL
    if (!is.null(fill) || grepl("remove|hide|none", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(strip.background = ggplot2::element_rect(fill = fill, colour = NA)))
    }
  }

  if (grepl("panel background", text, ignore.case = TRUE)) {
    fill <- infer_named_colour(text) %||% if (grepl("remove|hide|none", text, ignore.case = TRUE)) NA else NULL
    if (!is.null(fill) || grepl("remove|hide|none", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.background = ggplot2::element_rect(fill = fill, colour = NA)))
    }
  }

  if (grepl("plot background", text, ignore.case = TRUE)) {
    fill <- infer_named_colour(text) %||% if (grepl("remove|hide|none", text, ignore.case = TRUE)) NA else NULL
    if (!is.null(fill) || grepl("remove|hide|none", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(plot.background = ggplot2::element_rect(fill = fill, colour = NA)))
    }
  }

  if (grepl("panel border", text, ignore.case = TRUE)) {
    colour <- infer_named_colour(text) %||% "black"
    if (grepl("remove|hide|none", text, ignore.case = TRUE)) {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.border = ggplot2::element_blank()))
    } else {
      ops[[length(ops) + 1L]] <- list(op = "theme", params = list(panel.border = ggplot2::element_rect(fill = NA, colour = colour)))
    }
  }

  colour <- infer_named_colour(text)
  if (!is.null(colour) && grepl("legend|palette|color|colour|points", text, ignore.case = TRUE)) {
    ops[[length(ops) + 1L]] <- list(op = "scale_colour", params = list(values = colour))
  }

  if (grepl("palette", text, ignore.case = TRUE)) {
    palette_name <- NULL
    if (grepl("set1", text, ignore.case = TRUE)) palette_name <- "set1"
    if (grepl("set2", text, ignore.case = TRUE)) palette_name <- "set2"
    if (grepl("dark2", text, ignore.case = TRUE)) palette_name <- "dark2"
    if (grepl("tableau", text, ignore.case = TRUE)) palette_name <- "tableau"
    values <- named_palette_values(palette_name)
    if (!is.null(values)) {
      ops[[length(ops) + 1L]] <- list(op = "scale_colour", params = list(values = values))
      if (grepl("fill", text, ignore.case = TRUE)) {
        ops[[length(ops) + 1L]] <- list(op = "scale_fill", params = list(values = values))
      }
    }
  }

  ops
}

deterministic_style_spec <- function(instruction, context = list()) {
  ops <- style_ops_from_instruction(instruction)
  if (!length(ops)) {
    return(NULL)
  }

  new_compiled_spec(
    spec = normalize_layer_spec_body(list(
      intent = "style",
      action = "style_plot",
      target_layer = "plot",
      layers = list(),
      annotations = list(),
      plot_ops = ops,
      warnings = list()
    )),
    kind = "layer",
    instruction = instruction,
    context = context,
    meta = list(edit_mode = "deterministic_style")
  )
}
