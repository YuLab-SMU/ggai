# ggai_artifact: the engine-agnostic unit ggai operates on.
#
# `code` is canonical: it is the full R code that reproduces the figure.
# `object` is a cache: it may be a `ggplot`, a `recordedplot`, a grob tree, a
# Heatmap, or NULL. Callers should not rely on `object` surviving across
# sessions or process boundaries; if you need to re-render, fall back to `code`.

#' Construct a `ggai_artifact`
#'
#' The universal unit `ggai` operates on. `code` is canonical (always present
#' and complete); `object` is a non-canonical cache that may be NULL or
#' session-bound depending on the engine.
#'
#' @param code Character scalar of R code that reproduces the figure.
#' @param engine Engine string. One of `"ggplot"`, `"grid"`, `"base"`,
#'   `"complex_heatmap"`, `"circlize"`, `"htmlwidget"`, `"composite"`, or
#'   `"unknown"`.
#' @param object Optional R object cache (e.g. a `ggplot` or `recordedplot`).
#' @param rendered Optional named list of paths to rendered files, keyed by
#'   format (e.g. `list(png = "...", svg = "...")`).
#' @param data_refs Optional list describing data inputs the code consumed.
#' @param packages Optional character vector of packages used at execution.
#' @param inspect Optional engine-specific introspection list.
#' @param provenance Optional list describing how this artifact was produced.
#' @param id Optional id string; auto-generated when `NULL`.
#'
#' @return A `ggai_artifact` object.
#' @export
ggai_artifact <- function(code,
                          engine = "unknown",
                          object = NULL,
                          rendered = list(),
                          data_refs = list(),
                          packages = character(),
                          inspect = list(),
                          provenance = list(),
                          id = NULL) {
  if (!is.character(code) || length(code) != 1L) {
    rlang::abort("`code` must be a single character string.")
  }
  if (!is.character(engine) || length(engine) != 1L || !nzchar(engine)) {
    rlang::abort("`engine` must be a single non-empty character string.")
  }

  structure(
    list(
      id = id %||% generate_artifact_id(),
      code = code,
      engine = engine,
      object = object,
      rendered = as.list(rendered),
      data_refs = as.list(data_refs),
      packages = as.character(packages),
      inspect = as.list(inspect),
      provenance = as.list(provenance)
    ),
    class = "ggai_artifact"
  )
}

#' Test if an object is a `ggai_artifact`
#'
#' @param x Object to test.
#' @return Logical.
#' @export
is_ggai_artifact <- function(x) inherits(x, "ggai_artifact")

#' @export
print.ggai_artifact <- function(x, ...) {
  cat("<ggai_artifact>\n")
  cat("  id:       ", x$id, "\n", sep = "")
  cat("  engine:   ", x$engine, "\n", sep = "")
  pkgs <- if (length(x$packages)) {
    paste(x$packages, collapse = ", ")
  } else {
    "(none recorded)"
  }
  cat("  packages: ", pkgs, "\n", sep = "")
  rend <- x$rendered[lengths(x$rendered) > 0L]
  cat("  rendered: ", if (length(rend)) paste(names(rend), collapse = ", ") else "(none)", "\n", sep = "")
  obj_class <- if (is.null(x$object)) "NULL" else paste(class(x$object), collapse = "/")
  cat("  object:   ", obj_class, "\n", sep = "")
  code_lines <- strsplit(x$code, "\n", fixed = TRUE)[[1]]
  preview <- utils::head(code_lines, 4L)
  cat("  code:\n")
  for (line in preview) cat("    | ", line, "\n", sep = "")
  if (length(code_lines) > 4L) {
    cat("    | ... (", length(code_lines), " lines total)\n", sep = "")
  }
  invisible(x)
}

generate_artifact_id <- function() {
  ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
  rnd <- sprintf("%05x", sample.int(.Machine$integer.max, 1L) %% 0xFFFFFL)
  paste0("fig_", ts, "_", rnd)
}

# Allowed engine identifiers. Unknown engines are accepted but flagged.
ggai_known_engines <- function() {
  c("ggplot", "grid", "base", "complex_heatmap", "circlize",
    "htmlwidget", "composite", "unknown")
}

#' Persist a `ggai_artifact` to disk
#'
#' Writes the artifact's reproducer code (`<prefix>.R`), all entries in its
#' `rendered` list (one file per format), and a JSON manifest
#' (`<prefix>.json`) into `output_dir`.
#'
#' Pure side-effecting verb. Returns a named list of the paths written so the
#' caller (typically the agent) can reference them later.
#'
#' @param artifact A `ggai_artifact`.
#' @param output_dir Directory to write into. Created if missing.
#' @param prefix Filename prefix. Defaults to `artifact$id`.
#' @param overwrite If `FALSE` (default), error if any target file already
#'   exists. Set `TRUE` to clobber.
#'
#' @return A named list of saved paths (`code`, `manifest`, plus one entry per
#'   rendered format).
#' @export
ggai_save_artifact <- function(artifact,
                               output_dir,
                               prefix = NULL,
                               overwrite = FALSE) {
  if (!is_ggai_artifact(artifact)) {
    rlang::abort("`artifact` must be a ggai_artifact.")
  }
  if (!is.character(output_dir) || length(output_dir) != 1L) {
    rlang::abort("`output_dir` must be a single character string.")
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  prefix <- prefix %||% artifact$id
  saved <- list()

  code_path <- file.path(output_dir, paste0(prefix, ".R"))
  if (!isTRUE(overwrite) && file.exists(code_path)) {
    rlang::abort(paste0(
      "File exists: ", code_path,
      " (set overwrite = TRUE to replace)"
    ))
  }
  writeLines(enc2utf8(artifact$code), code_path, useBytes = TRUE)
  saved$code <- code_path

  for (fmt in names(artifact$rendered)) {
    src <- artifact$rendered[[fmt]]
    if (is.null(src) || !is.character(src) || !file.exists(src)) next
    dst <- file.path(output_dir, paste0(prefix, ".", fmt))
    if (!isTRUE(overwrite) && file.exists(dst)) {
      rlang::abort(paste0(
        "File exists: ", dst,
        " (set overwrite = TRUE to replace)"
      ))
    }
    file.copy(src, dst, overwrite = TRUE)
    saved[[fmt]] <- dst
  }

  manifest_path <- file.path(output_dir, paste0(prefix, ".json"))
  rendered_paths <- saved[setdiff(names(saved), "code")]
  manifest <- list(
    id = artifact$id,
    engine = artifact$engine,
    code_file = saved$code,
    rendered = rendered_paths,
    packages = artifact$packages,
    data_refs = artifact$data_refs,
    provenance = artifact$provenance
  )
  jsonlite::write_json(
    manifest, manifest_path,
    auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  saved$manifest <- manifest_path

  saved
}
