ggai_exemplar_dir <- function() {
  installed <- system.file("extdata", "exemplars", package = "ggai")
  if (nzchar(installed)) {
    return(installed)
  }

  file.path(ggai_package_root(), "inst", "extdata", "exemplars")
}

read_exemplar <- function(path) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

tokenize_instruction <- function(text) {
  x <- tolower(gsub("[^[:alnum:] ]+", " ", text %||% ""))
  stats::na.omit(strsplit(x, "\\s+")[[1]])
}

instruction_overlap_score <- function(query, candidate) {
  q <- unique(tokenize_instruction(query))
  c <- unique(tokenize_instruction(candidate))
  length(intersect(q, c))
}

retrieve_local_exemplars <- function(kind = c("layer", "diagram", "glyph"),
                                     instruction,
                                     n = 2) {
  kind <- match.arg(kind)
  dir <- ggai_exemplar_dir()
  if (!dir.exists(dir)) {
    return(list())
  }

  paths <- list.files(dir, pattern = paste0("^", kind, "_.*\\.json$"), full.names = TRUE)
  if (!length(paths)) {
    return(list())
  }

  exemplars <- lapply(paths, read_exemplar)
  scores <- vapply(exemplars, function(x) instruction_overlap_score(instruction, x$instruction %||% ""), numeric(1))
  ord <- order(scores, decreasing = TRUE)
  exemplars[ord][seq_len(min(n, length(exemplars)))]
}

format_exemplars_for_prompt <- function(exemplars) {
  if (!length(exemplars)) {
    return(NULL)
  }

  parts <- unlist(lapply(seq_along(exemplars), function(i) {
    ex <- exemplars[[i]]
    c(
      paste0("Example ", i, " instruction: ", ex$instruction %||% ""),
      paste0("Example ", i, " output:"),
      jsonlite::toJSON(ex$output %||% list(), auto_unbox = TRUE, pretty = TRUE, null = "null")
    )
  }))

  paste(parts, collapse = "\n")
}
