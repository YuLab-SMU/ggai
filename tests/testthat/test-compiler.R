test_that("compiler builds layer prompt payload without calling provider", {
  req <- new_layer_ai_request("circle the top 3 points")
  payload <- ggai:::build_layer_compiler_prompt(
    req,
    plot_context = list(mapped_aes = c("x", "y"))
  )

  expect_match(payload$system, "ggplot2")
  expect_match(payload$user, "circle the top 3 points")
  expect_match(payload$user, "Examples:")
})

test_that("compiler can parse mocked structured output", {
  json <- '{"intent":"annotate","action":"highlight","target_layer":"plot","layers":[],"annotations":[],"warnings":[]}'
  spec <- ggai:::parse_layer_compiler_output(json)

  expect_equal(spec$action, "highlight")
})

test_that("compiler parser accepts fenced json output", {
  json <- "```json\n{\"intent\":\"annotate\",\"action\":\"highlight\",\"target_layer\":\"plot\",\"layers\":[],\"annotations\":[],\"warnings\":[]}\n```"
  spec <- ggai:::parse_layer_compiler_output(json)

  expect_equal(spec$action, "highlight")
})

test_that("local exemplar retrieval returns relevant items", {
  exemplars <- ggai:::retrieve_local_exemplars("diagram", "transformer attention block", n = 1)

  expect_true(length(exemplars) >= 1)
  expect_match(exemplars[[1]]$instruction, "transformer")
})

test_that("diagram compiler prompt encourages layout DSL usage", {
  payload <- ggai:::build_diagram_compiler_prompt(
    "Draw a retrieval pipeline with stages and memory below synthesis",
    scene_context = list(width = 12, height = 6)
  )

  expect_match(payload$system, "layout DSL")
  expect_match(payload$user, "Examples:")
  expect_match(payload$user, "after")
  expect_match(payload$system, "center_on")
  expect_match(payload$system, "distribute")
})

test_that("structured compiler helper errors clearly without aisdk runtime", {
  local_mocked_bindings(
    ggai_aisdk_runtime_available = function() FALSE,
    .package = "ggai"
  )

  expect_error(
    ggai:::ggai_generate_structured(
      model = "openai:gpt-5.2",
      prompt = "hello",
      system = "system",
      response_format = z_ggai_layer_spec()
    ),
    "full `aisdk` runtime is not available"
  )
})

test_that("structured compiler helper parses generate_text responses through parser", {
  local_mocked_bindings(
    ggai_aisdk_runtime_available = function() TRUE,
    ggai_aisdk = function(name) {
      if (identical(name, "generate_text")) {
        return(function(...) list(text = '{"value": 1}'))
      }
      stop("unexpected helper")
    },
    .package = "ggai"
  )

  out <- ggai:::ggai_generate_structured(
    model = "openai:gpt-5.2",
    prompt = "hello",
    system = "system",
    response_format = z_ggai_layer_spec(),
    parser = jsonlite::fromJSON
  )

  expect_equal(out$value, 1)
})

test_that("structured compiler helper parses R6-like responses through parser", {
  fake <- new.env(parent = emptyenv())
  fake$text <- '{"value": 2}'

  local_mocked_bindings(
    ggai_aisdk_runtime_available = function() TRUE,
    ggai_aisdk = function(name) {
      if (identical(name, "generate_text")) {
        return(function(...) fake)
      }
      stop("unexpected helper")
    },
    .package = "ggai"
  )

  out <- ggai:::ggai_generate_structured(
    model = "gemini:gemini-3-flash-preview",
    prompt = "hello",
    system = "system",
    response_format = z_ggai_layer_spec(),
    parser = jsonlite::fromJSON
  )

  expect_equal(out$value, 2)
})

test_that("compiler normalizes incomplete layer specs deterministically", {
  spec <- ggai:::normalize_layer_spec_body(list(layers = list(list(geom = "text"))))

  expect_equal(spec$intent, "annotate")
  expect_equal(spec$layers[[1]]$stat, "identity")
  expect_true(is.list(spec$layers[[1]]$mapping))
})

test_that("compiler review helper can run a second pass when enabled", {
  local_mocked_bindings(
    ggai_generate_structured = function(model, prompt, system, response_format, registry = NULL, parser = NULL) {
      if (grepl("Candidate spec", prompt, fixed = TRUE)) {
        return(list(prompt = "fixed", width = 128, height = 128, transparent_background = TRUE))
      }
      list(prompt = "raw")
    },
    .package = "ggai"
  )

  out <- ggai:::compile_with_kind(
    kind = "glyph",
    instruction = "neuron icon",
    prompt = list(system = "sys", user = "user"),
    review = TRUE
  )

  expect_equal(out$width, 128)
  expect_true(isTRUE(out$transparent_background))
})

test_that("compiler retries when validation issues are returned", {
  calls <- 0
  local_mocked_bindings(
    ggai_generate_structured = function(model, prompt, system, response_format, registry = NULL, parser = NULL) {
      calls <<- calls + 1
      if (calls == 1) {
        return(list(layers = list()))
      }
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(list(geom = "text", mapping = list(x = "wt"), params = list(), inherit_aes = FALSE)),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  out <- ggai:::compile_with_kind(
    kind = "layer",
    instruction = "label a point",
    prompt = list(system = "sys", user = "user"),
    review = FALSE
  )

  expect_equal(calls, 2)
  expect_equal(out$layers[[1]]$geom, "text")
})
