# 2026-05-17 — P4.b: Capability-aware skill modes

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md) — Phase P4.b
- **Related session:** [2026-05-17 — P4: Smoke test through real LLM calls](2026-05-17-p4-smoke-test.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

P4 surfaced two ambiguities: the agent kept choosing the cheap deterministic code path even when the skill text implied the image-model path. The two skills (`ggai-direct-figure`, `ggai-figure-polish`) implicitly canonized one mode; the agent (correctly) found the cheaper alternative and went with it.

P4.b makes the mode choice **explicit, signal-driven, and capability-aware**.

### New primitive: `ggai_capability_status()`

Lives in `R/ai_bridge.R`. Returns a snapshot of which figure-generation capabilities are configured:

```r
list(
  language_model     = "openai:gpt-5.5",
  language_provider  = "openai",
  language_available = TRUE,           # OPENAI_API_KEY is set in env
  image_model        = "openai:gpt-image-2",
  image_provider     = "openai",
  image_available    = TRUE,           # OPENAI_API_KEY is set in env
  summary            = "- language: openai:gpt-5.5 [configured]\n- image: openai:gpt-image-2 [configured]"
)
```

Config-only — no live API call. A model is reported `available = TRUE` when the identifier resolves AND the provider's API-key env var is set. Provider→env mapping covers openai / anthropic / gemini / deepseek / bailian / aihubmix.

Exposed as a regular exported function, not as a verb tool. The agent calls it from within `ggai_execute_r` when the skill decision tree tells it to. Keeps the tool surface at three.

### Skill rewrites

Both `ggai-direct-figure` and `ggai-figure-polish` now lead with an explicit **Modes** section:

| Skill | Code mode | Image-model mode |
|-------|-----------|------------------|
| `ggai-direct-figure` | grid / ggplot via `ggai_execute_r` | `ggai_generate_image()` |
| `ggai-figure-polish` | rewrite ggplot via `ggai_execute_r` | `polish_figure()` |

Each has a decision tree applied in order:

1. **Capability check** — call `ggai_capability_status()`; if image is unavailable, code mode is the only option.
2. **Explicit user intent wins** — honor "in R / ggplot / vector / reproducible" → code; "BioRender / realistic / cover figure" → image-model.
3. **No cue → judge by task fit** — geometric / schematic / editable → code; naturalistic / textured / single-shot → image-model.
4. **Default to code** when borderline — cheaper, deterministic, vector, reproducible.

Each mode has its own snippet. The code-mode direct-figure snippet now also demonstrates "anchor titles inside the canvas, not at `y = 0.94`" — addressing the title-overflow finding from P4.

## Findings / decisions

### Decision tree works in practice

Three re-smoke runs with different intent signals on the same task:

| Intent signal | Goal | Agent behavior | Match expected? |
|---|---|---|---|
| **None** (ambiguous illustration) | "Draw a clean scientific illustration of a CRISPR-Cas9 knockout..." | Stayed in code mode (default-to-code branch). 72 s, 4 tool calls. | ✅ |
| **Explicit image-model** | "Use the image model to render a BioRender-style illustration..." | Attempted `ggai_generate_image()` first; endpoint returned **404**; fell back to grid mode and disclosed the fallback in the final reply. 95–105 s, 5 tool calls. | ✅ (best-effort honoring of intent) |
| **Explicit code** | "In R using grid graphics, draw a reproducible vector schematic..." | Stayed in code mode without attempting the image model. 145 s, 6 tool calls. | ✅ |

### The 404 finding

The user's `.Renviron` configures `OPENAI_BASE_URL=https://jarodfund.xyz/openai/v1`. This custom proxy serves the `/v1/chat/completions` route (which works for language calls) but not `/v1/images/generations` (returns 404 on image-generation requests).

`ggai_capability_status()` reports `image_available = TRUE` because OPENAI_API_KEY is set. But the actual endpoint isn't serving images. The agent honored explicit user intent (tried the image model first), got the 404 back, fell back, and reported the failure cleanly.

This is the right behavior even though it surfaces a config-vs-reachability gap. The alternative — a live HEAD probe before every figure call — adds latency and isn't worth it for the common case where capabilities are correctly configured. Filed as a TODO for a future opt-in `probe = TRUE` argument.

### Tool surface stays at three

Considered adding `ggai_capability_status` as a fourth verb tool. Rejected — the agent calls it through `ggai_execute_r` as needed, which keeps the tool surface minimal and the primitive callable from any R context (not just the agent).

### Skill-content rule learned

In the rewrites, I deleted the orphaned "Reference snippets" section after adding mode-specific snippets, to avoid duplication. The skill body is now ~30% longer than the P3 version — paying for explicit decision logic. Worth it.

## Verification

```sh
Rscript -e "testthat::test_dir('tests/testthat')"
# [ FAIL 0 | WARN 0 | SKIP 1 | PASS 327 ]  (+13 from new capability tests)

Rscript -e "
suppressMessages(devtools::load_all('.', quiet = TRUE))
cat(ggai_capability_status()\$summary, '\n')
"
# - language: openai:gpt-5.5 [configured]
# - image: openai:gpt-image-2 [configured]
```

Three re-smoke runs preserved under `demo_outputs/p4b_*/`.

## Next

P4 is now fully closed. Two natural next steps:

### P5 — Engine adapter expansion

ComplexHeatmap + circlize adapters. Will exercise the inspect / validate / render dispatchers under new engines. Worth doing soon because `ggai-engine-selection` skill currently *recommends* these engines but ggai can't actually render them yet.

### Skill iteration loop (continuous)

P4 + P4.b established the pattern: real smoke run → observe agent behavior → identify gap → edit skill / primitive → re-smoke. Subsequent improvements (single-cell skill content, reference-figure flow, complex-heatmap skill) follow the same loop. No need for a dedicated phase; this is now ongoing maintenance.

### Gallery seed

The five smoke outputs from P4 + three re-smokes from P4.b are a coherent seed for the eventual `gallery/`. Worth pulling into a dedicated showcase doc whenever appearance time allows.
