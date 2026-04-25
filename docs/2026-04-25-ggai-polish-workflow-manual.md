# ggai Polish Workflow Manual

This manual documents the current high-level workflow for `ggai` after adding the data-grounded whole-image redraw path.

The system now has two modes:

- `session` mode: build and edit a structured `ggplot` / `ggai_session`
- `polish` mode: turn the current grounded figure state into a final redrawn image using an image model

The intended product flow is:

1. Start from real data.
2. Build a correct chart or editable session.
3. Make structural edits while the figure is still a `ggplot`.
4. Switch into `polish` mode for whole-image redraw.
5. Inspect recorded artifacts and final outputs from the session.

## 1. Quick Start

### Start from data and stay in session mode

```r
library(ggai)

s <- ggai(
  mtcars,
  "show fuel efficiency vs weight, color by cylinders"
)

plot(s)
spec_history(s)
session_context(s)
```

This returns a `ggai_session`.

### Make structured edits first

```r
s <- gg_edit(s, "move legend to bottom")
s <- gg_edit(s, 'set title to "Fuel efficiency vs weight"')

plot(s)
as_code(s)
inspect_spec(s)
```

At this point the figure is still in the structured edit loop.

### Switch to whole-image redraw

```r
res <- gg_edit(
  s,
  "turn this into a publication hero figure with stronger hierarchy and cleaner typography",
  mode = "polish",
  image_model = "openai:gpt-image-2"
)
```

This returns a `ggai_polished_figure_result`.

The polished result contains:

- `res$best$path`: best final image
- `res$bundle_manifest_path`: structured bundle manifest
- `res$candidate_manifest_path`: candidate summary
- `res$prompt_path`: prompt sent to the image model
- `res$session`: updated session with artifact history

## 2. High-Level Entry Points

### `ggai()`

`ggai()` is now the top-level router.

#### Editable session path

```r
s <- ggai(
  mtcars,
  "show distribution of mpg",
  mode = "session"
)
```

This is equivalent to the default behavior.

#### Direct polish path

```r
res <- ggai(
  mtcars,
  "show fuel efficiency vs weight, color by cylinders",
  mode = "polish",
  polish_instruction = "make it feel like a flagship scientific product figure",
  image_model = "openai:gpt-image-2"
)
```

In this path, `ggai()` first builds the grounded figure state, then immediately runs whole-image redraw.

### `gg_edit()`

`gg_edit()` now supports two modes on a session:

#### Continue structured editing

```r
s <- gg_edit(s, "label the most extreme outlier")
```

#### Enter final redraw mode

```r
res <- gg_edit(
  s,
  "make this look camera-ready",
  mode = "polish"
)
```

Use `gg_edit(..., mode = "polish")` when the plot structure is good enough and the task becomes final visual finishing.

## 3. What Happens During `polish`

When `polish_figure()` runs, `ggai` prepares a multi-reference bundle:

- `base_plot.png`: factual ggplot render
- `geometry_overlay.png`: geometry anchors for points, lines, bars, etc.
- `layout_overlay.png`: title, panel, legend, axis, caption zones
- `bundle.json`: structured semantic contract
- `prompt.txt`: whole-image redraw prompt

All three images are sent together as reference images to the image editing model.

The model is told to:

- redraw the entire figure
- preserve chart semantics and relative data relationships
- respect layout zones and geometry anchors
- improve finish, spacing, typography, hierarchy, and polish

This is not a light retouch path. It is a controlled whole-image redraw path.

## 4. Inspecting Session Artifacts

After running a polish pass from a session, the result is recorded back into the session.

### See full mixed history

```r
hist <- spec_history(res$session)
hist
```

`spec_history()` now includes:

- ordinary structured edit turns
- artifact rows such as `kind = "polish"`

### Read the artifact log directly

```r
artifacts(res$session)
```

This returns the raw artifact records stored on the session.

### Get the most recent artifact

```r
latest_artifact(res$session)
```

### Get the most recent polish result

```r
latest_artifact(res$session, kind = "polish")
```

Typical fields include:

- `kind`
- `edit_mode`
- `instruction`
- `timestamp`
- `turn`
- `artifact_path`
- `bundle_manifest_path`
- `candidate_manifest_path`
- `prompt_path`

## 5. Recommended Workflow

For most cases, use this sequence:

```r
s <- ggai(
  mtcars,
  "show fuel efficiency vs weight, color by cylinders"
)

s <- gg_edit(s, "move legend to bottom")
s <- gg_edit(s, "label the most extreme outlier")

res <- gg_edit(
  s,
  "turn this into a polished publication figure with stronger hierarchy",
  mode = "polish",
  image_model = "openai:gpt-image-2"
)

plot(s)
spec_history(res$session)
latest_artifact(res$session, kind = "polish")
```

Use `session` mode while decisions are still structural.

Use `polish` mode only after:

- the chart type is right
- major annotations are in place
- the figure semantics are stable

That keeps the system honest: structure first, redraw second.

## 6. Notes

- Default image model resolution comes from `ggai_figure_resolution()`.
- Default image model now resolves through `ggai_default_models()$image`.
- `polish_figure()` can also be called directly if you want explicit control over the redraw stage.
- Artifact recording currently augments session history without changing the session’s active structured turn pointer.

That last point is intentional: the session still points at the latest structured plot state, while final redraw outputs are tracked as artifacts layered on top.
