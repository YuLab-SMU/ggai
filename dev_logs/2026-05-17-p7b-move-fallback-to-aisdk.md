# 2026-05-17 — P7.b: Move image-gen fallback into aisdk (layer fix)

- **Related session:** [2026-05-17 — P7: Image-model path via Responses API](2026-05-17-p7-image-model-via-responses.md)
- **Related upstream commit (aisdk):** `ad45b1d feat(provider/openai): fall back to Responses API for image generation`
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

P7 fixed the image-generation gap by adding a Responses-API fallback in `ggai_generate_image()`. The user flagged the obvious layer violation: **why is ggai reaching into OpenAI's URL routes? Provider-specific HTTP knowledge belongs in aisdk's `provider_openai`, not in ggai.**

They were right. P7.b moves the fallback into aisdk where it belongs.

### aisdk changes

`R/provider_openai.R::OpenAIImageModel` now has:

```r
public = list(
  do_generate_image = function(params) {
    # Try classic; on specific 404, fall back to Responses API.
    classic <- tryCatch(self$do_generate_image_classic(params), error = function(e) e)
    if (!inherits(classic, "error")) return(classic)
    if (self$looks_like_missing_classic_endpoint(classic)) {
      message("OpenAI image generation: classic /v1/images/generations is unreachable on this endpoint. Falling back to /v1/responses with the `image_generation` tool.")
      return(self$do_generate_image_via_responses(params))
    }
    stop(classic)
  },

  do_generate_image_classic = function(params) {
    # Original /v1/images/generations call body, preserved verbatim.
  },

  do_generate_image_via_responses = function(params) {
    url <- paste0(private$config$base_url, "/responses")
    headers <- c(
      private$get_headers(include_content_type = TRUE),
      list(`Accept-Encoding` = "identity")  # bypass proxy compression bug
    )
    body <- list(
      model = self$model_id,
      input = params$prompt,
      tools = list(list(type = "image_generation"))
    )
    response <- post_to_api(url, headers, body, ...)
    # Decode output[].image_generation_call.result -> finalize_image_artifacts.
    GenerateImageResult$new(images = ..., usage = ..., raw_response = response)
  },

  looks_like_missing_classic_endpoint = function(err) {
    msg <- conditionMessage(err) %||% ""
    isTRUE(grepl("404", msg, fixed = TRUE)) &&
      (grepl("invalid_api_path", msg, fixed = TRUE) ||
       grepl("not available", msg, fixed = TRUE) ||
       grepl("images/generations", msg, fixed = TRUE))
  }
)
```

Three things worth noting:

1. **`Accept-Encoding: identity`** — the user's proxy advertises gzip but emits a malformed Content-Encoding header on the `/responses` route. Forcing identity transfer-encoding makes httr2 parse cleanly.
2. **Methods are in `public = list(...)`** even though they're called via `self$`. R6 lets you mix, and these aren't true API surface — they're internal-but-addressable dispatch helpers. Could be tightened to `private = list(...)` in a future cleanup; functionally equivalent.
3. **Real OpenAI users** (whose `OPENAI_BASE_URL` is `api.openai.com`) keep using the classic path. The fallback never fires.

### ggai changes (revert)

`R/glyph_assets.R::ggai_generate_image()` is back to a thin wrapper:

```r
ggai_generate_image <- function(...) {
  ggai_aisdk("generate_image")(...)
}
```

The internal `responses_image_call()` and all the OpenAI URL knowledge are removed from ggai. The Responses-API probe fallback in `R/ai_bridge.R::probe_capability()` stays (it's about capability discovery, which legitimately needs URL knowledge — ggai owns the `ggai_capability_status` concept).

## Findings / decisions

### Layer hygiene was actually important

The original P7 hack worked but bloated `R/glyph_assets.R` with ~80 lines of provider-specific HTTP code. That code now sits in the right repo (`aisdk`), benefits all aisdk consumers (not just ggai), and ggai's call site is back to one line.

This is a good reminder: when implementing a quick fix, articulate the layer it really belongs in, then plan to migrate. The migration is usually cheap once the implementation exists.

### R6 method placement matters

My initial aisdk patch placed the new methods in `public = list(...)` but called them via `private$`. That silently failed at runtime — `private$method` doesn't resolve to public methods.

Fix: use `self$method` for public, `private$method` for private. R6 enforces visibility scope on the calling syntax.

### One-line install loop

`devtools::install("/Users/xiayh/Projects/aisdk", quick = TRUE, upgrade = "never", quiet = TRUE)` is fast enough (~5s) for an edit-install-test loop on an already-installed local package. Used it twice in this session.

## Verification

After aisdk reinstall:

```r
ggai_generate_image(
  model = ggai_image_model(),
  prompt = "A small green triangle on white background, flat illustration",
  output_dir = "...",
  prefix = "triangle"
)
# Message: "OpenAI image generation: classic /v1/images/generations is
#          unreachable on this endpoint. Falling back to /v1/responses
#          with the `image_generation` tool."
# 29.5 s, 440 KB PNG, GenerateImageResult R6 object returned.
```

Tests: ggai's full suite still passes — **0 FAIL / 1 SKIP / 384 PASS**. The Responses-fallback probe in `ggai_capability_status` test still works because the probe logic stayed in ggai (legitimately, since it's about ggai's own capability concept).

## Commits

- aisdk `ad45b1d feat(provider/openai): fall back to Responses API for image generation`
- ggai (next): revert `R/glyph_assets.R::ggai_generate_image()` to thin wrapper.

## Next

Nothing immediately. The fix is in the right place; ggai is small again; the gallery still has its image-model outputs.

If aisdk wants to publish this as 1.3.2, that's a separate decision.
