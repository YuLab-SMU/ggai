build_layer_compiler_prompt <- function(request, plot_context = list()) {
  if (!inherits(request, "ggai_layer_request")) {
    request <- new_layer_ai_request(as.character(request)[1])
  }

  effective_plot_context <- request_plot_context(request$runtime_request %||% NULL)
  if (!length(effective_plot_context)) {
    effective_plot_context <- plot_context
  }
  session_context <- request_session_context(request$runtime_request %||% NULL)

  exemplars <- retrieve_local_exemplars("layer", request$instruction, n = 2)
  exemplar_text <- format_exemplars_for_prompt(exemplars)

  list(
    system = read_ggai_prompt("layer_system.txt"),
    user = paste(
      "Instruction:",
      request$instruction,
      "",
      "Plot context:",
      jsonlite::toJSON(effective_plot_context, auto_unbox = TRUE, null = "null", pretty = TRUE),
      "",
      "Session context:",
      jsonlite::toJSON(session_context, auto_unbox = TRUE, null = "null", pretty = TRUE),
      if (!is.null(exemplar_text)) paste("\nExamples:\n", exemplar_text) else ""
    )
  )
}

build_diagram_compiler_prompt <- function(instruction, scene_context = list()) {
  exemplars <- retrieve_local_exemplars("diagram", instruction, n = 2)
  exemplar_text <- format_exemplars_for_prompt(exemplars)

  list(
    system = read_ggai_prompt("diagram_system.txt"),
    user = paste(
      "Instruction:",
      instruction,
      "",
      "Scene context:",
      jsonlite::toJSON(scene_context, auto_unbox = TRUE, null = "null", pretty = TRUE),
      if (!is.null(exemplar_text)) paste("\nExamples:\n", exemplar_text) else ""
    )
  )
}

build_glyph_compiler_prompt <- function(instruction, glyph_context = list()) {
  exemplars <- retrieve_local_exemplars("glyph", instruction, n = 2)
  exemplar_text <- format_exemplars_for_prompt(exemplars)

  list(
    system = read_ggai_prompt("glyph_system.txt"),
    user = paste(
      "Instruction:",
      instruction,
      "",
      "Glyph context:",
      jsonlite::toJSON(glyph_context, auto_unbox = TRUE, null = "null", pretty = TRUE),
      if (!is.null(exemplar_text)) paste("\nExamples:\n", exemplar_text) else ""
    )
  )
}

strip_json_fences <- function(text) {
  if (!is.character(text) || length(text) != 1) {
    return(text)
  }

  x <- trimws(text)
  x <- sub("^```[A-Za-z0-9_-]*\\s*", "", x)
  x <- sub("\\s*```$", "", x)
  trimws(x)
}

parse_layer_compiler_output <- function(text) {
  jsonlite::fromJSON(strip_json_fences(text), simplifyVector = FALSE)
}

parse_diagram_compiler_output <- function(text) {
  jsonlite::fromJSON(strip_json_fences(text), simplifyVector = FALSE)
}

parse_glyph_compiler_output <- function(text) {
  jsonlite::fromJSON(strip_json_fences(text), simplifyVector = FALSE)
}

build_review_compiler_prompt <- function(kind, instruction, spec) {
  list(
    system = read_ggai_prompt("review_system.txt"),
    user = paste(
      "Kind:",
      kind,
      "",
      "Original instruction:",
      instruction %||% "",
      "",
      "Candidate spec:",
      jsonlite::toJSON(spec, auto_unbox = TRUE, pretty = TRUE, null = "null"),
      "",
      "Repair the spec so it is internally consistent, minimal, and faithful to the instruction."
    )
  )
}

build_retry_compiler_prompt <- function(kind, instruction, prompt, issues) {
  list(
    system = prompt$system,
    user = paste(
      prompt$user,
      "",
      "Previous attempt had these issues:",
      paste(paste0("- ", issues), collapse = "\n"),
      "",
      "Try again and return only corrected JSON."
    )
  )
}

schema_for_kind <- function(kind) {
  switch(
    kind,
    layer = z_ggai_layer_spec(),
    diagram = z_ggai_diagram_spec(),
    glyph = z_ggai_glyph_spec(),
    figure = z_ggai_figure_prompt_spec()
  )
}

parser_for_kind <- function(kind) {
  switch(
    kind,
    layer = parse_layer_compiler_output,
    diagram = parse_diagram_compiler_output,
    glyph = parse_glyph_compiler_output,
    figure = parse_figure_prompt_output
  )
}

review_compiled_spec_body <- function(spec,
                                      kind,
                                      instruction = NULL,
                                      model = NULL,
                                      registry = NULL,
                                      review = FALSE) {
  spec <- normalize_compiled_spec_by_kind(spec, kind)
  if (!isTRUE(review)) {
    return(spec)
  }

  prompt <- build_review_compiler_prompt(kind, instruction, spec)
  reviewed <- ggai_generate_structured(
    model = ggai_language_model(model),
    prompt = prompt$user,
    system = prompt$system,
    response_format = schema_for_kind(kind),
    registry = registry,
    parser = parser_for_kind(kind)
  )

  normalize_compiled_spec_by_kind(reviewed, kind)
}

compile_with_kind <- function(kind,
                              instruction,
                              prompt,
                              model = NULL,
                              registry = NULL,
                              system = NULL,
                              review = ggai_review_compiler_output()) {
  current_prompt <- prompt
  last_issues <- character(0)

  for (attempt in seq_len(ggai_compiler_max_attempts())) {
    raw <- tryCatch(
      ggai_generate_structured(
        model = ggai_language_model(model),
        prompt = current_prompt$user,
        system = system %||% current_prompt$system,
        response_format = schema_for_kind(kind),
        registry = registry,
        parser = parser_for_kind(kind)
      ),
      error = function(e) structure(list(error = e), class = "ggai_compile_error")
    )

    if (inherits(raw, "ggai_compile_error")) {
      if (attempt >= ggai_compiler_max_attempts()) {
        stop(raw$error)
      }
      current_prompt <- build_retry_compiler_prompt(
        kind = kind,
        instruction = instruction,
        prompt = current_prompt,
        issues = conditionMessage(raw$error)
      )
      next
    }

    normalized <- normalize_compiled_spec_by_kind(raw, kind)
    issues <- validate_compiled_spec_by_kind(normalized, kind)
    if (!length(issues)) {
      return(review_compiled_spec_body(
        spec = normalized,
        kind = kind,
        instruction = instruction,
        model = model,
        registry = registry,
        review = review
      ))
    }

    last_issues <- issues
    if (attempt < ggai_compiler_max_attempts()) {
      current_prompt <- build_retry_compiler_prompt(
        kind = kind,
        instruction = instruction,
        prompt = current_prompt,
        issues = issues
      )
    }
  }

  rlang::abort(paste(c("Compiler could not produce a valid spec.", last_issues), collapse = " "))
}

compile_layer_spec <- function(instruction,
                               plot_context = list(),
                               plot = NULL,
                               session = NULL,
                               model = NULL,
                               registry = NULL,
                               system = NULL,
                               review = ggai_review_compiler_output()) {
  request <- if (inherits(instruction, "ggai_layer_request")) {
    instruction
  } else {
    new_layer_ai_request(instruction, plot = plot, session = session, model = model)
  }

  if (!length(plot_context)) {
    plot_context <- request_plot_context(request$runtime_request %||% NULL)
  }

  prompt <- build_layer_compiler_prompt(request, plot_context = plot_context)
  spec <- compile_with_kind(
    kind = "layer",
    instruction = request$instruction,
    prompt = prompt,
    model = model,
    registry = registry,
    system = system,
    review = review
  )

  new_compiled_spec(
    spec = spec,
    kind = "layer",
    instruction = request$instruction,
    context = plot_context,
    meta = list(
      model = model %||% request$model %||% NULL,
      session_turn = request_session_context(request$runtime_request %||% NULL)$current_turn %||% NULL
    )
  )
}

compile_diagram_spec <- function(instruction,
                                 scene_context = list(),
                                 model = NULL,
                                 registry = NULL,
                                 system = NULL,
                                 review = ggai_review_compiler_output()) {
  prompt <- build_diagram_compiler_prompt(instruction, scene_context = scene_context)
  compile_with_kind(
    kind = "diagram",
    instruction = instruction,
    prompt = prompt,
    model = model,
    registry = registry,
    system = system,
    review = review
  )
}

compile_glyph_spec <- function(instruction,
                               glyph_context = list(),
                               model = NULL,
                               registry = NULL,
                               system = NULL,
                               review = ggai_review_compiler_output()) {
  prompt <- build_glyph_compiler_prompt(instruction, glyph_context = glyph_context)
  compile_with_kind(
    kind = "glyph",
    instruction = instruction,
    prompt = prompt,
    model = model,
    registry = registry,
    system = system,
    review = review
  )
}
