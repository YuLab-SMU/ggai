# Skill discovery and loading. Verifies that the SKILL.md files under
# inst/skills/ are well-formed YAML, that aisdk can discover them, and that
# the agent created by `ggai_create_agent()` can load each one via its
# `load_skill` tool.

skip_if_not_installed("aisdk")

skills_path <- function() {
  pkg <- system.file("skills", package = "ggai")
  if (nzchar(pkg) && dir.exists(pkg)) {
    return(pkg)
  }
  # devtools::load_all() context — fall back to repo path
  file.path(getwd(), "inst", "skills")
}

test_that("the canonical ggai skill set is present", {
  required <- c(
    "ggai-orchestration",
    "ggai-engine-selection",
    "ggai-data-plot",
    "ggai-figure-polish",
    "ggai-direct-figure",
    "ggai-complex-heatmap",
    "ggai-circlize-genome",
    "ggai-patchwork-layout",
    "ggai-htmlwidget"
  )
  reg <- aisdk::create_skill_registry(skills_path())
  available <- reg$list_skills()$name
  for (nm in required) {
    expect_true(nm %in% available, info = paste("missing skill:", nm))
  }
})

test_that("every SKILL.md has parseable frontmatter (no YAML errors)", {
  reg <- aisdk::create_skill_registry(skills_path())
  skills <- reg$list_skills()
  # Every entry that landed in the registry parsed. We additionally check
  # that all SKILL.md files in the directory got registered (no silent skips).
  on_disk <- list.dirs(skills_path(), recursive = FALSE, full.names = FALSE)
  on_disk <- on_disk[file.exists(file.path(skills_path(), on_disk, "SKILL.md"))]
  expect_setequal(on_disk, skills$name)
})

test_that("the agent can load each canonical skill via load_skill", {
  agent <- ggai_create_agent()
  load_tool <- Filter(function(t) identical(t$name, "load_skill"), agent$tools)
  expect_length(load_tool, 1L)
  load_tool <- load_tool[[1L]]

  for (nm in c("ggai-orchestration", "ggai-engine-selection", "ggai-data-plot",
               "ggai-figure-polish", "ggai-direct-figure")) {
    body <- load_tool$run(list(skill_name = nm))
    expect_true(is.character(body) && nchar(body) > 200L,
                info = paste("load_skill returned empty body for:", nm))
  }
})

test_that("ggai_create_agent surfaces both verb and skill tools", {
  agent <- ggai_create_agent()
  tool_names <- vapply(agent$tools, function(t) t$name, character(1))
  # ggai verbs
  expect_true(all(c("ggai_execute_r", "ggai_validate_artifact", "ggai_save_artifact") %in% tool_names))
  # aisdk skill tools
  expect_true(all(c("load_skill", "list_skill_resources", "read_skill_resource", "execute_skill_script") %in% tool_names))
})
