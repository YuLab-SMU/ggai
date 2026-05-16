ggai_split_skill_paths <- function(paths) {
  if (is.null(paths) || !length(paths)) {
    return(character())
  }
  paths <- paths[!is.na(paths) & nzchar(paths)]
  if (!length(paths)) {
    return(character())
  }
  unique(unlist(strsplit(paths, .Platform$path.sep, fixed = TRUE), use.names = FALSE))
}

ggai_default_skill_paths <- function(project_root = getwd(),
                                     include_system = TRUE,
                                     system_path = path.expand("~/.agents/skills")) {
  configured <- c(
    getOption("ggai.skill_path", character()),
    Sys.getenv("GGAI_SKILL_PATH", unset = NA_character_)
  )
  package_skills <- tryCatch(system.file("skills", package = "ggai"), error = function(...) "")
  defaults <- c(
    file.path(project_root, "skills"),
    file.path(project_root, ".agents", "skills"),
    file.path(project_root, "inst", "skills"),
    package_skills
  )
  if (isTRUE(include_system)) {
    defaults <- c(defaults, system_path)
  }
  unique(c(ggai_split_skill_paths(configured), defaults))
}

ggai_existing_skill_paths <- function(paths) {
  paths <- ggai_split_skill_paths(paths)
  paths <- paths[dir.exists(paths)]
  if (!length(paths)) {
    return(character())
  }
  unique(normalizePath(paths, mustWork = TRUE))
}

ggai_builtin_skill_paths <- function(skill_names,
                                     project_root = getwd()) {
  if (is.null(skill_names) || !length(skill_names)) {
    return(character())
  }
  skill_names <- skill_names[!is.na(skill_names) & nzchar(skill_names)]
  if (!length(skill_names)) {
    return(character())
  }

  roots <- ggai_existing_skill_paths(c(
    file.path(project_root, "inst", "skills"),
    tryCatch(system.file("skills", package = "ggai"), error = function(...) "")
  ))
  if (!length(roots)) {
    return(character())
  }

  paths <- unlist(lapply(roots, function(root) file.path(root, skill_names)), use.names = FALSE)
  ggai_existing_skill_paths(paths)
}

ggai_skill_registry <- function(path = NULL,
                                recursive = TRUE,
                                project_root = getwd(),
                                include_system = TRUE) {
  paths <- if (is.null(path)) {
    ggai_default_skill_paths(project_root = project_root, include_system = include_system)
  } else {
    path
  }
  paths <- ggai_existing_skill_paths(paths)
  if (!length(paths)) {
    return(NULL)
  }

  registries <- lapply(paths, function(skill_path) {
    ggai_aisdk("create_skill_registry")(path = skill_path, recursive = recursive)
  })
  if (length(registries) == 1L) {
    return(registries[[1]])
  }
  structure(registries, class = c("ggai_skill_registries", "list"))
}

ggai_skill_from_path <- function(path) {
  skill_path <- if (basename(path) == "SKILL.md") dirname(path) else path
  if (!dir.exists(skill_path)) {
    return(NULL)
  }
  registry <- ggai_aisdk("create_skill_registry")(path = dirname(skill_path), recursive = FALSE)
  registry$get_skill(basename(skill_path))
}

ggai_resolve_skill <- function(skill, registry = NULL) {
  if (inherits(skill, "Skill")) {
    return(skill)
  }
  if (is.list(skill) && !is.null(skill$name) && !is.null(skill$content)) {
    return(skill)
  }
  if (!is.character(skill) || length(skill) != 1L || !nzchar(skill)) {
    return(NULL)
  }
  if (file.exists(skill) || dir.exists(skill)) {
    return(ggai_skill_from_path(skill))
  }
  if (!is.null(registry)) {
    if (inherits(registry, "ggai_skill_registries")) {
      for (item in registry) {
        if (item$has_skill(skill)) {
          return(item$get_skill(skill))
        }
      }
    } else if (registry$has_skill(skill)) {
      return(registry$get_skill(skill))
    }
  }
  NULL
}

ggai_relevant_skills <- function(query, registry = NULL, max_skills = 3L) {
  if (is.null(registry)) {
    return(list())
  }

  registries <- if (inherits(registry, "ggai_skill_registries")) registry else list(registry)
  rows <- list()
  for (i in seq_along(registries)) {
    table <- registries[[i]]$find_relevant_skills(query = query %||% "")
    if (nrow(table)) {
      table$.registry_index <- i
      rows[[length(rows) + 1L]] <- table
    }
  }
  if (!length(rows)) {
    return(list())
  }
  table <- do.call(rbind, rows)
  table <- table[order(table$score, decreasing = TRUE), , drop = FALSE]
  table <- utils::head(table, max_skills)

  Filter(Negate(is.null), lapply(seq_len(nrow(table)), function(i) {
    registries[[table$.registry_index[[i]]]]$get_skill(table$name[[i]])
  }))
}

ggai_skill_body <- function(skill, max_chars = 3000L) {
  if (inherits(skill, "Skill")) {
    return(substr(skill$load(), 1L, max_chars))
  }
  if (is.list(skill) && !is.null(skill$content)) {
    return(substr(as.character(skill$content), 1L, max_chars))
  }
  NULL
}

ggai_skill_name <- function(skill) {
  if (inherits(skill, "Skill")) {
    return(skill$name)
  }
  if (is.list(skill) && !is.null(skill$name)) {
    return(as.character(skill$name)[[1]])
  }
  "inline-skill"
}

ggai_skill_path_value <- function(skill) {
  path <- NULL
  if (inherits(skill, "Skill")) {
    path <- skill$path
  } else if (is.list(skill) && !is.null(skill$path)) {
    path <- as.character(skill$path)[[1]]
  } else if (is.character(skill) && length(skill) == 1L && nzchar(skill)) {
    path <- skill
  }
  if (is.null(path) || !nzchar(path)) {
    return(NULL)
  }
  path <- path.expand(path)
  if (basename(path) == "SKILL.md") {
    path <- dirname(path)
  }
  if (!dir.exists(path)) {
    return(NULL)
  }
  normalizePath(path, mustWork = TRUE)
}

ggai_agent_skill_paths <- function(skills = NULL,
                                   query = NULL,
                                   skill_registry = NULL,
                                   skill_path = NULL,
                                   max_skills = getOption("ggai.agent_max_skills", 6L),
                                   builtin_skills = character()) {
  if (identical(skills, FALSE)) {
    return(NULL)
  }

  builtin_paths <- ggai_builtin_skill_paths(builtin_skills)

  if (identical(skills, "auto")) {
    paths <- ggai_existing_skill_paths(skill_path %||% ggai_default_skill_paths())
    paths <- unique(c(builtin_paths, paths))
    return(if (length(paths)) paths else NULL)
  }

  registry <- skill_registry %||% ggai_skill_registry(skill_path)
  resolved <- list()

  if (is.null(skills)) {
    resolved <- ggai_relevant_skills(query, registry = registry, max_skills = max_skills)
  } else {
    resolved <- lapply(as.list(skills), function(skill) {
      path <- ggai_skill_path_value(skill)
      if (!is.null(path)) {
        return(list(path = path))
      }
      ggai_resolve_skill(skill, registry = registry)
    })
  }

  paths <- Filter(Negate(is.null), lapply(resolved, ggai_skill_path_value))
  paths <- unique(c(builtin_paths, unlist(paths, use.names = FALSE)))
  paths <- paths[nzchar(paths)]
  if (!length(paths)) {
    return(NULL)
  }
  paths
}

#' Build a prompt section from ggai skills
#'
#' @param skills Optional skill names, paths, Skill objects, or inline skill lists.
#' @param query User instruction used to select relevant skills from a registry.
#' @param skill_registry Optional aisdk SkillRegistry.
#' @param skill_path Optional path scanned into an aisdk SkillRegistry.
#' @param max_skills Maximum skills to inject.
#' @param max_chars Maximum characters per skill body.
#'
#' @return A prompt section string or `NULL`.
#' @export
ggai_skill_prompt_section <- function(skills = NULL,
                                      query = NULL,
                                      skill_registry = NULL,
                                      skill_path = NULL,
                                      max_skills = 3L,
                                      max_chars = 3000L) {
  registry <- skill_registry %||% ggai_skill_registry(skill_path)

  resolved <- list()
  if (!is.null(skills)) {
    resolved <- Filter(Negate(is.null), lapply(as.list(skills), ggai_resolve_skill, registry = registry))
  } else {
    resolved <- ggai_relevant_skills(query, registry = registry, max_skills = max_skills)
  }
  if (!length(resolved)) {
    return(NULL)
  }
  resolved <- utils::head(resolved, max_skills)

  blocks <- lapply(resolved, function(skill) {
    body <- ggai_skill_body(skill, max_chars = max_chars)
    if (is.null(body) || !nzchar(body)) {
      return(NULL)
    }
    paste0("### ", ggai_skill_name(skill), "\n", body)
  })
  blocks <- Filter(Negate(is.null), blocks)
  if (!length(blocks)) {
    return(NULL)
  }

  paste(
    "Skill guidance:",
    "Use the following skill instructions when they are relevant to the requested visualization.",
    paste(blocks, collapse = "\n\n"),
    sep = "\n"
  )
}
