# ggai Agentic Quickstart FAQ

This note covers the first questions users usually hit when trying the
model-backed ggai workflow.

## Set the default model

For one call, pass `model` directly:

```r
car_data <- ggplot2::mpg
s <- ggai(
  "@car_data show highway mpg vs engine displacement, grouped by vehicle class",
  model = "deepseek:deepseek-v4-flash"
)
```

For the current R session, set an option:

```r
options(ggai.language_model = "deepseek:deepseek-v4-flash")
ggai_default_models()
```

Or use the console-style helper:

```r
ggai_set_model("deepseek:deepseek-v4-flash")
ggai_get_model()
```

This mirrors the language model into aisdk's session default, so
`aisdk::set_model("deepseek:deepseek-v4-flash")` also works when no
`ggai.language_model` option is set.

For long-term defaults, add this to `~/.Renviron`, restart R, then check
`ggai_default_models()`:

```r
GGAI_LANGUAGE_MODEL=deepseek:deepseek-v4-flash
DEEPSEEK_API_KEY=your-key
```

Model precedence is:

```text
model argument > ggai_set_model()/options(ggai.language_model=...) > aisdk::set_model()/options(aisdk.default_model=...) > OPENAI_MODEL > GGAI_LANGUAGE_MODEL > openai:gpt-5.2
```

If an unexpected model is being called, check `OPENAI_MODEL` first because it
currently wins over `GGAI_LANGUAGE_MODEL` when no ggai or aisdk session default
has been set.

To clear the current ggai session override and return to the next fallback:

```r
ggai_set_model(NULL)
```

Image defaults use the same helper with `type = "image"`:

```r
ggai_set_model("gpt-image-2", type = "image")
ggai_get_model("image")
```

## Create a first agentic plot

```r
library(ggai)

options(
  ggai.language_model = "deepseek:deepseek-v4-flash",
  ggai.agentic_tool_log_mode = "quiet"
)

car_data <- ggplot2::mpg
s <- ggai(
  "@car_data How can ggplot show several color systems for distinguishing groups? Make a clear example figure using class groups."
)

s
plot(s)
```

The printed object is a session summary. Use `plot(s)` to draw the current
ggplot.

## Use compact `@` mentions

For quick interactive work, mention data objects and reference paths directly
inside the prompt. ggai resolves those mentions before the Agent runs, then the
Agent and skills decide how to use them.

```r
your_data <- ggplot2::mpg
paper_figure <- "/path/to/paper_pca.png"

s <- ggai(
  "@your_data 用我的数据画出类似这张图的效果 @paper_figure"
)
```

`@your_data` should name a data frame in your current R environment.
`@paper_figure` can be a character variable containing a local path. Literal
paths also work when written as `@/path/to/file.png`.

This does not add fixed `reference_image` or `reference_mode` arguments. The
reference-figure skill tells the Agent whether to treat the file as style,
structure, method, data-remake, or polish context.

## Use a local image as a visual reference

For multimodal language models, put the image path directly in the prompt.
ggai passes the image to the Agent as vision input rather than making the Agent
reverse-engineer pixels through R:

```r
ggai_set_model("openai:gpt-5.5")

s <- ggai(
  "/Users/me/Downloads/paper-figure.jpeg 用这种风格做一张可编辑的 ggplot"
)

plot(s)
```

This is still prompt-inferred behavior. You do not need a fixed
`reference_image=` parameter. If you also mention a data frame, ggai uses your
data as the factual source and the image as style/structure guidance.

If the active language model does not explicitly advertise vision input support
such as many text-only DeepSeek chat models, ggai does not send image blocks to
the provider. It keeps the local image path in the text prompt so the Agent can
try R-side inspection or make an honest style-template fallback instead of
failing at the provider request boundary.

## Improve a plot you do not like

Use `gg_edit()` on the existing session. Keep the request concrete enough for
the Agent to judge whether a candidate is better:

```r
s2 <- gg_edit(
  s,
  "Improve this as a tutorial figure: shorter panel titles, clearer grouping colors, less overlap, cleaner legend, and a final look suitable for documentation."
)

plot(s2)
```

If `s` was created with a model-backed `ggai()` call, follow-up `gg_edit()`
calls inherit that session model. You only need to pass `model=` again when you
want to switch models.

You can continue editing:

```r
s3 <- gg_edit(
  s2,
  "Further improve readability: make the panels easier to compare, reduce visual noise, and keep the class groups easy to distinguish."
)

plot(s3)
```

## Fix Chinese or other non-ASCII text showing as square boxes

Square boxes usually mean the selected graphics font does not contain the
glyphs, or the active graphics device cannot resolve the font.

Ask ggai to treat it as a font problem:

```r
s3 <- gg_edit(
  s2,
  "Further improve the figure, but first fix the Chinese text showing as square boxes. Use a font/device-safe approach for Chinese labels."
)

plot(s3)
```

When exporting CJK-heavy plots, prefer a device/font path that supports the
target language. Common choices are:

```r
# PNG export, when ragg is installed
ggplot2::ggsave(
  "plot.png",
  plot(s3),
  device = ragg::agg_png,
  width = 8,
  height = 5,
  dpi = 300
)
```

For Chinese labels, replace the family with a font installed on your machine,
for example `PingFang SC` on macOS, `Microsoft YaHei` on Windows, or
`Noto Sans CJK SC` on Linux:

```r
p <- plot(s3) +
  ggplot2::theme(
    text = ggplot2::element_text(family = "PingFang SC")
  )

print(p)
```

The built-in `ggai-r-fonts` skill gives the Agent this font guidance by
default.

## Show more or less Agent process in the console

Quiet output is the default. It hides low-level tool plumbing such as
`Running ggai_execute_goal_code` and lets ggai show higher-level Agent progress
when available:

```r
options(ggai.agentic_tool_log_mode = "quiet")
```

The high-level process renderer has two display styles. Console style uses the
`cli` package and is best for an interactive terminal:

```r
options(ggai.agentic_process_output = "console")
```

Markdown style avoids ANSI terminal codes and is best inside Rmarkdown or
Quarto chunks:

```r
options(ggai.agentic_process_output = "markdown")
```

Compact output shows aisdk's tool-level status lines:

```r
options(ggai.agentic_tool_log_mode = "compact")
```

For debugging, show detailed tool calls:

```r
options(ggai.agentic_tool_log_mode = "detailed")
```

To inherit aisdk's raw display behavior:

```r
options(ggai.agentic_tool_log_mode = "inherit")
```

## Prevent long candidate churn

ggai lets the aisdk Agent decide what to do, but it enforces candidate budgets
so the Agent cannot keep generating similar plot candidates forever.

Useful defaults:

```r
options(
  ggai.agentic_valid_candidate_budget = 4,
  ggai.agentic_candidate_attempt_budget = 16,
  ggai.agentic_edit_max_steps = 100
)
```

For quick interactive testing, tighten them:

```r
options(
  ggai.agentic_valid_candidate_budget = 3,
  ggai.agentic_candidate_attempt_budget = 10
)
```

When the budget is reached, candidate-generation tools return
`status = "decision_required"`, and the Agent should commit an existing valid
candidate, inspect attempts, or declare a blocker.

## Inspect what happened

```r
spec_history(s3)
session_context(s3)
```

For a lower-level look, inspect the current compiled spec:

```r
inspect_spec(s3)
as_code(s3)
```

## Common failure modes

- `object 'image_model' not found`: only polish/image workflows need
  `image_model`. For ggplot editing, use `model`, not `image_model`.
- API 403 for a model: the key or provider endpoint does not have access to
  that model. Set `model` or `options(ggai.language_model=...)` to a model your
  key can use.
- DeepSeek `response_format` error: ggai has fallback handling for providers
  without structured response support; update/reload the package and retry.
- Plot does not display after printing `s`: call `plot(s)`.
- Non-English text renders as boxes: use a font with glyph coverage and a
  suitable graphics device.
