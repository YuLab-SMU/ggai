ggai_package_root <- function() {
  pkg_path <- tryCatch(
    {
      pkgload::pkg_path()
    },
    error = function(...) NULL
  )

  if (!is.null(pkg_path)) {
    return(pkg_path)
  }

  "."
}

ggai_prompt_path <- function(name) {
  installed <- system.file("prompts", name, package = "ggai")
  if (nzchar(installed)) {
    return(installed)
  }

  local <- file.path(ggai_package_root(), "inst", "prompts", name)
  if (file.exists(local)) {
    return(local)
  }

  rlang::abort(paste0("Prompt file not found: ", name))
}

read_ggai_prompt <- function(name) {
  paste(readLines(ggai_prompt_path(name), warn = FALSE), collapse = "\n")
}

