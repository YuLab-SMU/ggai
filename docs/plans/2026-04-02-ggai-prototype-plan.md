# ggai Prototype Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an `aisdk`-powered R prototype of `ggai` that turns natural language into reproducible visualization layers, diagram scenes, and generated glyph assets.

**Architecture:** `ggai` is a compiler-first R package. Natural language is first compiled into structured JSON specs using `aisdk` structured outputs, then those specs are compiled into ordinary `ggplot2` layers, grid grobs, or cached image/SVG glyph assets. The prototype deliberately avoids whole-image black-box rendering for normal plots; generation models are only used for bounded local assets such as glyphs and diagram node artwork.

**Tech Stack:** R, `ggplot2`, `grid`, `gtable`, `rlang`, `cli`, `jsonlite`, `digest`, `glue`, `aisdk`, `testthat`, `vdiffr`

---

## Product Decision

Use the following product split for the prototype:

1. **Data-viz augmentation path**: `geom_ai()` translates a natural-language instruction into one or more `ggplot2` layers or annotations.
2. **Diagram path**: `ggdiagram()` provides a blank scene/canvas; `geom_ai()` can also target that canvas via a diagram spec.
3. **Generative glyph path**: `glyph_ai()` and `geom_point_ai()` generate reusable local assets through `aisdk::generate_image()` and place them deterministically.

Do **not** make `paperbanana/` a runtime dependency in v1. Treat it as a reference corpus for prompts, examples, and evaluation only.

## Repository Direction

Turn the repository root into the new `ggai` R package and keep `paperbanana/` as a research/reference subtree. The package should depend on the local/development `aisdk` package rather than re-implementing provider, schema, and image model layers.

## Milestones

1. **M0 package foundation**: package skeleton, `aisdk` bridge, settings, tests.
2. **M1 layer compiler**: `geom_ai()` for data-viz augmentations that compile to ordinary `ggplot2` layers.
3. **M2 diagram scene**: `ggdiagram()` plus scene spec -> grob rendering.
4. **M3 generative glyphs**: cached AI-generated assets and `geom_point_ai()`.
5. **M4 demos and evaluation**: examples, snapshots, and prompt regression tests.

## Package Layout

Expected top-level package structure after bootstrap:

- `DESCRIPTION`
- `NAMESPACE`
- `R/`
- `tests/testthat/`
- `man/`
- `inst/prompts/`
- `inst/extdata/examples/`
- `docs/plans/`
- `paperbanana/` (reference only; no package hooks)

### Task 1: Bootstrap The R Package At Repo Root

**Files:**
- Create: `DESCRIPTION`
- Create: `NAMESPACE`
- Create: `R/ggai-package.R`
- Create: `tests/testthat.R`
- Create: `tests/testthat/test-package-load.R`
- Create: `.Rbuildignore`

**Step 1: Write the failing test**

Create `tests/testthat/test-package-load.R`:

```r
test_that("ggai exports the prototype entry points", {
  ns <- asNamespace("ggai")
  expect_true(exists("geom_ai", envir = ns, inherits = FALSE))
  expect_true(exists("ggdiagram", envir = ns, inherits = FALSE))
  expect_true(exists("glyph_ai", envir = ns, inherits = FALSE))
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-package-load.R')"
```

Expected: FAIL because package files and exported functions do not yet exist.

**Step 3: Write minimal implementation**

- Add `DESCRIPTION` with `Package: ggai` and `Imports` at least:
  - `ggplot2`
  - `grid`
  - `gtable`
  - `rlang`
  - `cli`
  - `jsonlite`
  - `digest`
  - `glue`
  - `aisdk`
- Add `R/ggai-package.R` with minimal roxygen package block.
- Add placeholder exported stubs:
  - `geom_ai <- function(...) rlang::abort("Not implemented yet.")`
  - `ggdiagram <- function(...) rlang::abort("Not implemented yet.")`
  - `glyph_ai <- function(...) rlang::abort("Not implemented yet.")`

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::document(); testthat::test_file('tests/testthat/test-package-load.R')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add DESCRIPTION NAMESPACE R/ggai-package.R tests/testthat.R tests/testthat/test-package-load.R .Rbuildignore
git commit -m "chore: bootstrap ggai package skeleton"
```

### Task 2: Add The `aisdk` Bridge And Runtime Configuration

**Files:**
- Create: `R/ai_bridge.R`
- Create: `R/options.R`
- Create: `tests/testthat/test-ai-bridge.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-ai-bridge.R`:

```r
test_that("ggai resolves default language and image models", {
  cfg <- ggai_default_models()
  expect_named(cfg, c("language", "image"))
  expect_true(is.character(cfg$language))
  expect_true(is.character(cfg$image))
})

test_that("ggai can build an instruction compiler request object", {
  req <- new_layer_ai_request("highlight top outliers")
  expect_equal(req$instruction, "highlight top outliers")
  expect_equal(req$target, "layer")
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-ai-bridge.R')"
```

Expected: FAIL because bridge helpers do not exist.

**Step 3: Write minimal implementation**

In `R/ai_bridge.R`:

- Implement `ggai_default_models()` returning:
  - `language = getOption('ggai.language_model', 'openai:gpt-5.2')`
  - `image = getOption('ggai.image_model', 'openai:gpt-image-1.5')`
- Implement thin wrappers:
  - `ggai_language_model(model = NULL)`
  - `ggai_image_model(model = NULL)`
  - these should delegate to `aisdk::resolve_model(..., type = 'language'/'image')` or keep string IDs until first call
- Implement `new_layer_ai_request(instruction, target = 'layer', context = list())`

In `R/options.R`:

- Add option helpers for:
  - `ggai.language_model`
  - `ggai.image_model`
  - `ggai.cache_dir`
  - `ggai.verbose`

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'ai-bridge')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/ai_bridge.R R/options.R tests/testthat/test-ai-bridge.R
git commit -m "feat: add aisdk model bridge and ggai runtime options"
```

### Task 3: Define Structured Specs For Layer, Diagram, And Glyph Requests

**Files:**
- Create: `R/spec_layer.R`
- Create: `R/spec_diagram.R`
- Create: `R/spec_glyph.R`
- Create: `tests/testthat/test-specs.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-specs.R`:

```r
test_that("layer spec schema is a z_schema object", {
  schema <- z_ggai_layer_request()
  expect_s3_class(schema, "z_schema")
})

test_that("diagram spec enumerates node and edge collections", {
  schema <- z_ggai_diagram_spec()
  props <- names(schema$properties)
  expect_true(all(c("nodes", "edges", "canvas") %in% props))
})

test_that("glyph spec supports asset generation metadata", {
  schema <- z_ggai_glyph_spec()
  props <- names(schema$properties)
  expect_true(all(c("prompt", "style", "width", "height") %in% props))
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-specs.R')"
```

Expected: FAIL because the schemas do not exist.

**Step 3: Write minimal implementation**

Build all schemas on top of `aisdk::z_*` primitives and reuse `aisdk` ideas from `R/ggplot_schema.R`.

In `R/spec_layer.R` create:

- `z_ggai_layer_request()`
- `z_ggai_layer_spec()`
- fields:
  - `intent`
  - `action`
  - `target_layer`
  - `layers` (array of layer specs)
  - `annotations`
  - `warnings`

In `R/spec_diagram.R` create:

- `z_ggai_diagram_spec()`
- node fields:
  - `id`, `kind`, `label`, `x`, `y`, `width`, `height`, `style`, `asset_ref`
- edge fields:
  - `from`, `to`, `label`, `arrow`, `style`, `route`
- canvas fields:
  - `width`, `height`, `background`, `coordinate_system`

In `R/spec_glyph.R` create:

- `z_ggai_glyph_spec()`
- fields:
  - `prompt`, `style`, `negative_prompt`, `width`, `height`, `transparent_background`, `seed`, `asset_role`

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'specs')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/spec_layer.R R/spec_diagram.R R/spec_glyph.R tests/testthat/test-specs.R
git commit -m "feat: add structured ggai schemas for layer diagram and glyph specs"
```

### Task 4: Build Prompt Templates And The NL -> Spec Compiler

**Files:**
- Create: `R/compiler.R`
- Create: `R/prompts.R`
- Create: `inst/prompts/layer_system.txt`
- Create: `inst/prompts/diagram_system.txt`
- Create: `inst/prompts/glyph_system.txt`
- Create: `tests/testthat/test-compiler.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-compiler.R`:

```r
test_that("compiler builds layer prompt payload without calling provider", {
  req <- new_layer_ai_request("circle the top 3 points")
  payload <- build_layer_compiler_prompt(req, plot_context = list(mapped_aes = c("x", "y")))
  expect_match(payload$system, "ggplot2")
  expect_match(payload$user, "circle the top 3 points")
})

test_that("compiler can parse mocked structured output", {
  json <- '{"intent":"annotate","action":"highlight","target_layer":"plot","layers":[],"annotations":[],"warnings":[]}'
  spec <- parse_layer_compiler_output(json)
  expect_equal(spec$action, "highlight")
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-compiler.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

In `R/prompts.R`:

- add `ggai_prompt_path(name)`
- add `read_ggai_prompt(name)`

In `R/compiler.R`:

- add `build_layer_compiler_prompt()`
- add `build_diagram_compiler_prompt()`
- add `build_glyph_compiler_prompt()`
- add `parse_layer_compiler_output()`
- add `compile_layer_spec()` that calls `aisdk::generate_text(response_format = z_ggai_layer_spec())`
- add `compile_diagram_spec()` that calls `aisdk::generate_text(response_format = z_ggai_diagram_spec())`
- add `compile_glyph_spec()` that calls `aisdk::generate_text(response_format = z_ggai_glyph_spec())`

Prompt rules for v1:

- the model must output only valid JSON matching the supplied schema
- default to ordinary ggplot geoms first
- avoid custom geoms unless explicitly requested
- generated glyphs are references, not inline binary

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'compiler')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/compiler.R R/prompts.R inst/prompts/layer_system.txt inst/prompts/diagram_system.txt inst/prompts/glyph_system.txt tests/testthat/test-compiler.R
git commit -m "feat: add prompt templates and natural-language spec compiler"
```

### Task 5: Extract Plot Context And Compile Layer Specs To Ordinary ggplot Layers

**Files:**
- Create: `R/plot_context.R`
- Create: `R/compile_layers.R`
- Create: `tests/testthat/test-compile-layers.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-compile-layers.R`:

```r
test_that("plot context extracts mapped aesthetics and layer types", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  ctx <- build_plot_context(p)
  expect_true("x" %in% ctx$mapped_aes)
  expect_true("y" %in% ctx$mapped_aes)
  expect_true("point" %in% ctx$geoms)
})

test_that("layer compiler turns a simple annotation spec into ggplot layers", {
  spec <- list(
    intent = "annotate",
    action = "label",
    target_layer = "plot",
    layers = list(
      list(
        geom = "text",
        stat = "identity",
        mapping = list(x = "wt", y = "mpg", label = "carb"),
        params = list(colour = "red"),
        inherit_aes = FALSE
      )
    ),
    annotations = list(),
    warnings = list()
  )
  layers <- compile_layer_spec_to_layers(spec, data = mtcars)
  expect_true(length(layers) == 1)
  expect_s3_class(layers[[1]], "Layer")
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-compile-layers.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

In `R/plot_context.R`:

- implement `build_plot_context(plot)`
- collect:
  - global mappings
  - current geoms
  - labels
  - facet state
  - coordinate system

In `R/compile_layers.R`:

- implement `compile_layer_spec_to_layers(spec, data = NULL)`
- map spec geoms to `ggplot2::geom_*`
- support v1 geoms only:
  - `point`
  - `text`
  - `label`
  - `segment`
  - `curve`
  - `rect`
  - `smooth`
- reject unsupported geoms with a clear error

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'compile-layers')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/plot_context.R R/compile_layers.R tests/testthat/test-compile-layers.R
git commit -m "feat: add plot context extraction and layer spec compilation"
```

### Task 6: Implement `geom_ai()` For Existing ggplot Objects

**Files:**
- Create: `R/geom_ai.R`
- Create: `tests/testthat/test-geom-ai.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-geom-ai.R`:

```r
test_that("geom_ai returns a lazy ggplot-add object", {
  x <- geom_ai("highlight top 3 outliers")
  expect_true(is.list(x))
  expect_s3_class(x, "ggai_layer_request")
})

test_that("geom_ai can be added to an existing plot with mocked compiler", {
  local_mocked_bindings(
    compile_layer_spec = function(...) {
      list(
        intent = "annotate",
        action = "label",
        target_layer = "plot",
        layers = list(
          list(
            geom = "text",
            stat = "identity",
            mapping = list(x = "wt", y = "mpg", label = "carb"),
            params = list(colour = "red"),
            inherit_aes = FALSE
          )
        ),
        annotations = list(),
        warnings = list()
      )
    },
    .package = "ggai"
  )

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg))
  q <- p + geom_ai("label a few points")
  expect_s3_class(q, "ggplot")
  expect_true(length(q$layers) == 1)
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-geom-ai.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

In `R/geom_ai.R`:

- define constructor `geom_ai(instruction, model = NULL, image_model = NULL, data = NULL, cache = TRUE, mode = c('layer', 'diagram'))`
- return a lazy list with class `c('ggai_layer_request', 'ggplot_add')`
- implement `ggplot_add.ggai_layer_request(object, plot, object_name)`
- in `ggplot_add`:
  - build plot context
  - compile spec
  - compile returned layers
  - append layers to plot

Important v1 decision:

- `geom_ai()` is additive only in prototype phase
- do not mutate or rewrite existing layers
- if instruction implies rewrite, return warning in spec

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'geom-ai')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/geom_ai.R tests/testthat/test-geom-ai.R
git commit -m "feat: add additive geom_ai compiler entry point"
```

### Task 7: Implement `ggdiagram()` And Scene Rendering

**Files:**
- Create: `R/ggdiagram.R`
- Create: `R/render_diagram.R`
- Create: `tests/testthat/test-ggdiagram.R`
- Create: `tests/testthat/test-render-diagram.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-ggdiagram.R`:

```r
test_that("ggdiagram creates a diagram canvas object", {
  p <- ggdiagram()
  expect_s3_class(p, "ggplot")
  expect_equal(attr(p, "ggai_canvas"), "diagram")
})
```

Create `tests/testthat/test-render-diagram.R`:

```r
test_that("diagram renderer creates grobs for nodes and edges", {
  spec <- list(
    canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
    nodes = list(
      list(id = "a", kind = "box", label = "Encoder", x = 2, y = 3, width = 2, height = 1, style = list(fill = "#DDEEFF"))
    ),
    edges = list(),
    annotations = list()
  )
  grob <- render_diagram_spec(spec)
  expect_s3_class(grob, "grob")
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-ggdiagram.R'); testthat::test_file('tests/testthat/test-render-diagram.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

In `R/ggdiagram.R`:

- create `ggdiagram(width = 10, height = 6)`
- return a blank `ggplot2` object with a fixed Cartesian canvas and attribute `ggai_canvas = 'diagram'`

In `R/render_diagram.R`:

- create `render_diagram_spec(spec)`
- support v1 node kinds:
  - `box`
  - `rounded_box`
  - `text`
  - `image_asset`
- support v1 edge kinds:
  - straight segment
  - elbow route
  - curved route
- output a `grid` grob tree inserted via `annotation_custom()` or a custom layer

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'ggdiagram|render-diagram')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/ggdiagram.R R/render_diagram.R tests/testthat/test-ggdiagram.R tests/testthat/test-render-diagram.R
git commit -m "feat: add diagram canvas and scene renderer"
```

### Task 8: Add Generated Glyph Assets And `geom_point_ai()`

**Files:**
- Create: `R/glyph_assets.R`
- Create: `R/geom_point_ai.R`
- Create: `R/cache.R`
- Create: `tests/testthat/test-glyph-assets.R`
- Create: `tests/testthat/test-geom-point-ai.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-glyph-assets.R`:

```r
test_that("glyph cache key is stable for same prompt and style", {
  a <- glyph_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)
  b <- glyph_cache_key(prompt = "neuron icon", style = "paper", width = 256, height = 256)
  expect_equal(a, b)
})
```

Create `tests/testthat/test-geom-point-ai.R`:

```r
test_that("geom_point_ai returns a layer object", {
  layer <- geom_point_ai(prompt = "cell icon")
  expect_s3_class(layer, "Layer")
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-glyph-assets.R'); testthat::test_file('tests/testthat/test-geom-point-ai.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

In `R/cache.R`:

- implement:
  - `ggai_cache_dir()`
  - `glyph_cache_key()`
  - `glyph_cache_path()`

In `R/glyph_assets.R`:

- implement `glyph_ai(prompt, style = NULL, width = 256, height = 256, model = NULL, cache = TRUE, transparent_background = TRUE)`
- compile prompt/spec if needed
- call `aisdk::generate_image()`
- persist output under cache dir
- return a small descriptor:
  - `path`
  - `prompt`
  - `width`
  - `height`
  - `media_type`

In `R/geom_point_ai.R`:

- implement `geom_point_ai(prompt, style = NULL, ...)`
- for prototype:
  - generate one glyph asset per layer, not per row
  - place it with a custom grob draw function
- postpone category-to-asset mappings to later milestone

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'glyph-assets|geom-point-ai')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add R/glyph_assets.R R/geom_point_ai.R R/cache.R tests/testthat/test-glyph-assets.R tests/testthat/test-geom-point-ai.R
git commit -m "feat: add cached glyph generation and point-ai layer"
```

### Task 9: Add End-To-End Prototype Examples And Prompt Fixtures

**Files:**
- Create: `inst/extdata/examples/scatter_outlier_labels.R`
- Create: `inst/extdata/examples/transformer_diagram.R`
- Create: `inst/extdata/examples/generated_point_glyphs.R`
- Create: `tests/testthat/test-examples-smoke.R`

**Step 1: Write the failing test**

Create `tests/testthat/test-examples-smoke.R`:

```r
test_that("example scripts parse without syntax errors", {
  files <- c(
    "inst/extdata/examples/scatter_outlier_labels.R",
    "inst/extdata/examples/transformer_diagram.R",
    "inst/extdata/examples/generated_point_glyphs.R"
  )
  for (f in files) {
    expect_no_error(parse(file = f))
  }
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-examples-smoke.R')"
```

Expected: FAIL.

**Step 3: Write minimal implementation**

Create three example scripts showing:

- `geom_ai("圈出右上角的异常点并标标签")`
- `ggdiagram() + geom_ai("画一个 transformer block，左边输入 token，右边输出 logits")`
- `geom_point_ai(prompt = "paper-style neuron icon")`

Keep all examples runnable with mocked compiler functions when keys are unavailable.

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'examples-smoke')"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add inst/extdata/examples/ tests/testthat/test-examples-smoke.R
git commit -m "docs: add runnable prototype examples"
```

### Task 10: Add Snapshot And Visual Regression Coverage

**Files:**
- Create: `tests/testthat/test-visual-regression.R`
- Create: `tests/testthat/_snaps/`

**Step 1: Write the failing test**

Create `tests/testthat/test-visual-regression.R`:

```r
test_that("diagram renderer stays visually stable", {
  skip_if_not_installed("vdiffr")
  p <- ggdiagram()
  spec <- list(
    canvas = list(width = 10, height = 6, background = "white", coordinate_system = "cartesian"),
    nodes = list(
      list(id = "input", kind = "box", label = "Input", x = 2, y = 3, width = 1.8, height = 0.8, style = list(fill = "#E8F3FF")),
      list(id = "model", kind = "rounded_box", label = "Model", x = 5, y = 3, width = 2.2, height = 1, style = list(fill = "#FFF1D6"))
    ),
    edges = list(
      list(from = "input", to = "model", label = NULL, arrow = TRUE, style = list(colour = "#334455"), route = "straight")
    ),
    annotations = list()
  )
  q <- add_diagram_spec(p, spec)
  vdiffr::expect_doppelganger("basic-diagram-scene", q)
})
```

**Step 2: Run test to verify it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-visual-regression.R')"
```

Expected: FAIL until `add_diagram_spec()` and rendering are stable enough.

**Step 3: Write minimal implementation**

- add `add_diagram_spec(plot, spec)` helper if it does not yet exist
- make rendering deterministic:
  - fixed fonts where possible
  - fixed line widths
  - explicit coordinate scales
- register the first `vdiffr` snapshot

**Step 4: Run test to verify it passes**

Run:

```bash
Rscript -e "devtools::test(filter = 'visual-regression')"
```

Expected: PASS on local machine after accepting snapshot.

**Step 5: Commit**

```bash
git add tests/testthat/test-visual-regression.R tests/testthat/_snaps
git commit -m "test: add visual regression coverage for ggai scenes"
```

## Custom Design Notes For This Prototype

### 1. Why `aisdk` Is The Right Base

Use `aisdk` directly for four jobs already solved there:

- structured JSON schema output via `z_*` schema builders
- provider/model abstraction via `provider:model` identifiers
- image generation via `ImageModelV1` and `generate_image()`
- agent/tool expansion later if `geom_ai()` becomes planner + repair + critic

The specific reusable pieces are:

- `aisdk/R/schema.R`
- `aisdk/R/spec_model.R`
- `aisdk/R/image_api.R`
- `aisdk/R/utils_registry.R`
- `aisdk/R/ggplot_schema.R`

### 2. What To Reuse From `aisdk::ggplot_schema`

Do not copy the file blindly. Reuse its ideas selectively:

- known aesthetics registry
- dynamic geom parameter extraction
- generic layer schema shape

Wrap or mirror only the pieces needed for `ggai` request/response specs. The `ggai` compiler schema should stay smaller than the frontend editor schema in `aisdk`.

### 3. What Not To Do In Prototype Phase

Avoid these until after M3:

- no full-plot image synthesis for data plots
- no per-point unique image generation by default
- no arbitrary geom rewriting of the existing plot
- no dependence on Python or `paperbanana` runtime services
- no Shiny or studio UI before the compiler and renderer are stable

### 4. Prototype Success Criteria

The prototype is successful when all of the following are true:

1. `geom_ai()` can add at least three useful augmentation types to an ordinary scatter plot:
   - labels
   - highlighted subsets
   - arrows/boxes/callouts
2. `ggdiagram()` can render at least one transformer-style architecture diagram from a structured scene spec.
3. `glyph_ai()` can generate and cache a transparent asset through `aisdk`.
4. `geom_point_ai()` can place a generated glyph deterministically for an entire layer.
5. At least one visual regression test passes locally.

## Recommended Execution Order Across Sessions

1. Task 1-2 in one short foundation pass.
2. Task 3-6 as the first usable product slice for `geom_ai()`.
3. Task 7 after the layer path is stable.
4. Task 8 last, because generative glyphs depend on both caching and renderer hooks.
5. Task 9-10 only after APIs stop changing daily.

## Stretch Goals After Prototype

- `aes(asset = category)` for category-to-generated-glyph mapping
- `stat_ai()` for AI-generated derived summaries before plotting
- diagram style transfer using prompt presets learned from `paperbanana`
- review/repair loop with planner + critic agents inside `aisdk`
- export compiled spec to plain R code via `as_code()`

## Handoff Notes

- Treat this as an R-first package, not a Python wrapper.
- Prefer deterministic compilation over black-box image generation.
- Keep generated artifacts local and cache-addressable.
- Preserve ordinary `ggplot2` composability whenever possible.

Plan complete and saved to `docs/plans/2026-04-02-ggai-prototype-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
