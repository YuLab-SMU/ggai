# 2026-05-17 — P7: Image-model path via Responses API

- **Related session:** [2026-05-17 — P6.b: Polish loose ends](2026-05-17-p6b-polish.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

The user asked: "why isn't there a single example produced by the image model?" — and they were right. Across P4 / P4.b / P5.b every image-model attempt fell back to code-mode because the user's proxy (`jarodfund.xyz/openai/v1`) returns `404 invalid_api_path` on the classic `/v1/images/generations` endpoint. Even after P4.b's live probe and P6's adapter work, no real image-model output had ever been produced.

P7 diagnosed and fixed this:

### Investigation

1. Listed available models on the proxy via `GET /v1/models`. Confirmed `gpt-image-1`, `gpt-image-1.5`, `gpt-image-2` are advertised.
2. Probed alternative routes:
   - `/v1/images/generations` → 404 `invalid_api_path`
   - `/v1/images/edits` → 404 `invalid_api_path`
   - `/v1/images/variations` → 404 `invalid_api_path`
   - `/v1/responses` with empty body → 400 `upstream_rejected` (route exists)
3. Confirmed the proxy serves image generation via the new **OpenAI Responses API** with the `image_generation` tool:
   ```json
   POST /v1/responses
   { "model": "gpt-image-2",
     "input": "<prompt>",
     "tools": [{ "type": "image_generation" }] }
   ```
   First call: 200 OK in 19 s, returned a base64-encoded PNG in `output[].result`.

### Fix (in two places)

**`R/glyph_assets.R`** — `ggai_generate_image()` now wraps `aisdk::generate_image()` with automatic fallback:

```r
ggai_generate_image <- function(...) {
  args <- list(...)
  classic <- tryCatch(ggai_aisdk("generate_image")(...), error = function(e) e)
  if (!inherits(classic, "error")) {
    classic$via <- classic$via %||% "classic"
    return(classic)
  }
  msg <- conditionMessage(classic)
  endpoint_404 <- grepl("404", msg) &&
    (grepl("invalid_api_path", msg, fixed = TRUE) ||
     grepl("not available", msg, fixed = TRUE) ||
     grepl("images/generations", msg, fixed = TRUE))
  provider <- ggai_model_provider(args$model %||% ggai_image_model()) %||% "openai"
  if (isTRUE(endpoint_404) && identical(provider, "openai")) {
    return(do.call(responses_image_call, args))
  }
  stop(classic)
}
```

The new internal `responses_image_call()` POSTs to `<base>/responses`, decodes the `image_generation_call.result` base64 payload to a PNG file, and returns the aisdk-shaped `list(images = ..., raw_response, via = "responses_api")`. Existing callers (`polish_figure`, `glyph_ai`, the agent verb tool path) don't need to change.

**`R/ai_bridge.R`** — `probe_capability()` now mirrors the fallback. When openai-image classic returns non-reachable (404), the probe also tries `<base>/responses`. If that route exists (any status other than 404), image is reported reachable via `responses_api`. Summary lines now read:

```
- image: openai:gpt-image-2 [configured; reachable (HTTP 401; via responses_api)]
```

This keeps the live probe (used by the `ggai-direct-figure` skill's Modes decision tree) in sync with the actual call path.

## Verification

### Direct primitive call

```r
res <- ggai_generate_image(
  model = "openai:gpt-image-2",
  prompt = "Clean scientific illustration of a neuron ...",
  output_dir = ...,
  prefix = "neuron"
)
# Message: "ggai_generate_image: classic /v1/images/generations is unreachable
#           on this endpoint. Falling back to /v1/responses with `image_generation` tool."
# 131 s, 1.27 MB PNG, via = "responses_api"
```

### Capability probe

```r
ggai:::ggai_probe_cache_clear()
ggai_capability_status(probe = TRUE)$summary
# - language: openai:gpt-5.5 [configured; reachable (HTTP 401)]
# - image: openai:gpt-image-2 [configured; reachable (HTTP 401; via responses_api)]
```

### Agent end-to-end

`ggai("Use the image model to render a BioRender-style scientific illustration of an antibody binding to a viral surface protein. Label antibody and antigen clearly. Save to <out> as antibody2.")`

Result: 383 s, the agent loaded `ggai-direct-figure`, called `ggai_generate_image()` (which fell back to Responses API via the new path), and saved the rendered PNG. `antibody2.png` shows a Y-shaped antibody binding antigens on a viral membrane — **the first real image-model output through this proxy.**

### Tests

`tests/testthat/test-capability-status.R` updated:
- "classic 404 + Responses-API 401 falls back to responses_api" — new positive test.
- "both classic AND Responses unreachable → image_available = FALSE" — new negative test.

Full suite: **0 FAIL / 1 SKIP / 384 PASS**.

## Findings / decisions

### Two parallel layers of fallback

The fix lives in two places that must agree:

1. **Probe layer** — `probe_capability()`: tells the *skill* (and thus the agent's mode decision) whether image is reachable. Probes classic, then Responses.
2. **Call layer** — `ggai_generate_image()`: tries classic, falls back to Responses on 404. The *actual* call path.

Both layers prefer classic when available (lower latency, well-understood semantics) and degrade to Responses when forced. Decisions are cached per-call: probe results are TTL-cached for 60 s; call-layer fallback re-discovers on every call (acceptable cost given image-gen latency is already 30–200 s).

### Responses API contract observations

- Model identifier `gpt-image-2` is accepted on input. The proxy internally routes to a `gpt-5.x-mini` orchestrator that uses the `image_generation` tool.
- Response shape:
  ```json
  { "output": [
      { "type": "image_generation_call",
        "id": "ig_...",
        "status": "generating",   // appears even though completed
        "result": "<base64-png>",
        "revised_prompt": "<model rephrasing>",
        "size": "...",
        "background": "..."
      }
    ],
    "model": "<actual orchestrator model id>",
    "usage": {...},
    ...
  }
  ```
- `revised_prompt` is the model's expanded version of the input prompt. Often clearer than the original; worth surfacing in skill output.
- Latency ranges from 19 s (simple prompts) to 170 s (richly described scenes). Probably similar to direct OpenAI gpt-image-1 timings.

### Gallery images produced

The first batch of real image-model outputs under `demo_outputs/gallery/`:

- `crispr_illustration.png` — Cas9 / sgRNA / DNA with labeled cut site.
- `tcell_tumor.png` — T-cell / tumor-cell immunological synapse with TCR–MHC–peptide.
- `neuron.png` — Labeled neuron (dendrites / soma / axon / synapse).
- `first_image_model.png` — The smoke-test red circle that proved the route works.

Plus the agent-driven `demo_outputs/p7_agent_image2/antibody2.png` (Y-antibody + viral membrane).

These five are the first images the gallery can show as "image-model output via ggai".

## Next

### Skill iteration

- The agent took **383 s** on the antibody goal. That's two cold image-model calls — the agent generated multiple candidates without being asked. The `ggai-direct-figure` skill should be tightened to say "default candidate_count = 1" more explicitly.
- The plotly toolbar issue from P6.b still stands: agents producing PNG htmlwidget output should pass `config(displayModeBar = FALSE)`.

### Provider expansion

- The fallback specifically targets `openai/image`. Gemini's `imagen` and Aliyun's `wanx` use different REST shapes; not addressed here.
- A future `provider_route()` could expose `responses_image` as a first-class route alongside `language` and `image` to make probing more granular.

### Real OpenAI users still get the classic path

For users whose `OPENAI_BASE_URL` points to `api.openai.com` directly, the classic call always succeeds and the Responses-API fallback never fires. The fallback is invisible to them.
