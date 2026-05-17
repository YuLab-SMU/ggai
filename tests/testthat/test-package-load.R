test_that("ggai exports the post-P2 prototype entry points", {
  ns <- asNamespace("ggai")

  # Layer 2 — artifact core
  expect_true(exists("ggai_artifact", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_execute_and_capture", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_render_artifact", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_inspect_artifact", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_validate_artifact", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_save_artifact", envir = ns, inherits = FALSE))

  # Layer 3 — agent + verb tools
  expect_true(exists("ggai", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_create_agent", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_run_agent", envir = ns, inherits = FALSE))
  expect_true(exists("ggai_create_verb_tools", envir = ns, inherits = FALSE))

  # Surviving public utilities
  expect_true(exists("ggdiagram", envir = ns, inherits = FALSE))
  expect_true(exists("glyph_ai", envir = ns, inherits = FALSE))
  expect_true(exists("prepare_polish_bundle", envir = ns, inherits = FALSE))
  expect_true(exists("polish_figure", envir = ns, inherits = FALSE))
})

test_that("doomed-in-P2 entry points are gone", {
  ns <- asNamespace("ggai")
  expect_false(exists("geom_ai", envir = ns, inherits = FALSE))
  expect_false(exists("gg_edit", envir = ns, inherits = FALSE))
  expect_false(exists("start_ggai_session", envir = ns, inherits = FALSE))
  expect_false(exists("create_ggai_agent", envir = ns, inherits = FALSE))
  expect_false(exists("ggai_agent_run", envir = ns, inherits = FALSE))
  expect_false(exists("compile_figure_prompt", envir = ns, inherits = FALSE))
  expect_false(exists("generate_final_figure", envir = ns, inherits = FALSE))
})
