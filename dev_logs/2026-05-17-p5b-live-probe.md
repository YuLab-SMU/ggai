# 2026-05-17 — P5.b: Live capability probe

- **Related plan:** [plan/2026-05-17-agentic-refactor-overview.md](../plan/2026-05-17-agentic-refactor-overview.md) — Phase P5.b
- **Related session:** [2026-05-17 — P4.b: Capability-aware skill modes](2026-05-17-p4b-capability-modes.md)
- **Worked on by:** Yonghe Xia (with Claude Sonnet 4.6)

## What happened

P4.b surfaced a config-vs-reachability gap: `ggai_capability_status()` would happily say `image_available = TRUE` because `OPENAI_API_KEY` is set, but the user's custom OpenAI-compatible proxy (`jarodfund.xyz/openai/v1`) returns 404 on `/v1/images/generations`. The agent had to discover this the hard way — try a real `ggai_generate_image()` call, eat the 404, and fall back.

P5.b adds a `probe = TRUE` argument to `ggai_capability_status()` that does a lightweight reachability check before the agent commits to an expensive code path.

### Design

**API surface:**

```r
ggai_capability_status(probe = FALSE, refresh = FALSE, ttl = 60L, timeout = 5L)
```

- `probe = FALSE` (default): config-only, no network. Same behaviour as before.
- `probe = TRUE`: send a small probe to each configured capability's endpoint. Cache result in-process for `ttl` seconds.
- `refresh = TRUE`: bust the cache.
- `timeout`: per-probe timeout in seconds.

**Returned shape additions:**

- `probed` — boolean, TRUE when at least one probe ran this call.
- `probe_results` — per-capability `list(status, reachable, route, error, cached)`.

When a probe runs, `*_available` tightens: if config check passed but probe says unreachable, `*_available = FALSE`. If probe is skipped (no route mapped, `reachable = NA`), the config-only result is preserved.

**Probe transport:**

First I tried `HEAD` because it's the HTTP-canonical "does this endpoint exist" probe. But the user's proxy returns 404 on HEAD even for routes that work fine on POST. Some Cloudflare/nginx fronts treat HEAD specially.

Switched to `POST {}` (empty body, no Authorization header). Rationale: any server that has the route mapped will at least parse and reject the request (400 / 401 / 405 / 422), while a missing route returns 404. Costs essentially nothing — the server short-circuits before touching the model. Survived its first network blip via `httr2::req_retry(max_tries = 2, backoff = 0.5s)`.

**Route mapping:**

```r
provider/type     => route suffix
openai/language     /chat/completions
openai/image        /images/generations
deepseek/language   /chat/completions
aihubmix/language   /chat/completions
aihubmix/image      /images/generations
anthropic/language  /messages
# others (gemini, bailian, local Ollama) -> NULL; probe skipped
```

Anthropic has no image-generation API today (no entry). Gemini and Bailian use non-REST routes that don't fit this minimal HEAD/POST schema — left for a future expansion.

**Cache:**

Package-local environment `ggai_probe_cache`, keyed by `paste(provider, base_url, type, sep = "|")`. Each entry carries `cached_at` (Sys.time()); reads check against `ttl` and drop stale entries lazily. `ggai_probe_cache_clear()` for tests.

### Skill updates

`ggai-direct-figure` and `ggai-figure-polish` decision trees now read:

> Before reaching for image-model mode, call `ggai_capability_status(probe = TRUE)`. This sends a lightweight POST to the configured image endpoint to confirm the route actually exists — config-only checks can wrongly report "configured" when a custom OpenAI-compatible proxy doesn't serve `/v1/images/generations`. If `image_available` is `FALSE`, code mode is the only option.

So the agent probes only when it's about to commit to image-model — code mode users don't pay the roundtrip.

## Findings / decisions

### POST vs HEAD: the call that surprised me

`HEAD https://jarodfund.xyz/openai/v1/chat/completions` → **404**. Same route, same proxy. But POSTing real chat completions works fine (we ran 8 of them in P4). The proxy/server config explicitly rejects HEAD for the route. So HEAD-probe is a non-starter for some custom OpenAI-compatible deployments.

`POST {}` returned `401` (auth required) for the same route, correctly identifying that the route exists. That's the signal we use.

For the actually-missing `/v1/images/generations`, both HEAD and POST return 404 cleanly.

### Transient SSL errors

First probe attempt against the user's endpoint got `SSL connect error` (TLS handshake glitch on a fresh connection). Three subsequent retries all succeeded. Added `req_retry(max_tries = 2, backoff = 0.5s)` so a single transient error doesn't poison the cache for 60 seconds.

### Cache semantics

Cache is in-process. Per-session, not persistent across R sessions. Default TTL = 60s. The agent typically runs many tool calls within a few seconds; the cache hits virtually every time after the first probe in a session. Trades cross-session probe cost for in-session sanity.

### Mocked tests work cleanly with `local_mocked_bindings`

Initially worried about networking in CI. `local_mocked_bindings(probe_http_route = function(...) ...)` keeps the tests offline and lets us assert on each branch (404 flip, retry, cache reuse, refresh bust, no-route-mapped, network error).

## Verification

### Unit tests

`tests/testthat/test-capability-status.R` now has 11 tests / **40+ assertions**:
- Default shape (config-only path).
- Availability reflects env-key state.
- Image unavailable when key cleared.
- Identifiers match `ggai_default_models()`.
- Probe marks reachable on non-404 (mocked 401).
- Probe flips image_available to FALSE on 404 (mocked, language stays TRUE).
- Cache reuses results within TTL.
- Refresh busts cache.
- Probe skipped for providers without route mapping (gemini); reachable = NA.
- Network errors collapse to reachable = FALSE with error string in summary.
- `probe = FALSE` preserves original behavior.

Full suite: **0 FAIL / 1 SKIP / 358 PASS** (+15 over P5).

### Against the user's actual endpoint

```r
# Config-only (the P4.b behaviour):
ggai_capability_status()$summary
# - language: openai:gpt-5.5 [configured]
# - image: openai:gpt-image-2 [configured]

# Live probe (the P5.b addition):
ggai_capability_status(probe = TRUE)$summary
# - language: openai:gpt-5.5 [configured; reachable (HTTP 401)]
# - image: openai:gpt-image-2 [configured; UNREACHABLE (HTTP 404)]
```

The probe correctly diagnoses what config-check could not: language route works, image route is missing on this proxy.

### End-to-end LLM smoke

Replayed P4.b's B1 case: `ggai("Use the image model to render a BioRender-style illustration of CRISPR-Cas9 cutting DNA. Save to <out> as probe2.")`

Tool sequence (5 calls):
```
[1] load_skill[ggai-direct-figure]
[2] ggai_execute_r        -- code contains BOTH capability_status(probe = TRUE)
                             AND a generate_image branch guarded by the probe result
[3] ggai_validate_artifact
[4] ggai_save_artifact[prefix=probe2]
[5] (final reply)
```

The agent's final reply: *"The image-model route was requested, but the configured image endpoint was not available after probing, so I produced a BioRender-inspired fallback schematic in R/grid instead."*

Compare to P4.b's B1 same-task reply: *"I attempted image-model generation first, but the configured image-generation endpoint returned a 404 API error..."*

**The post-P5.b version saves one wasted real API call and produces a cleaner explanation.** The agent committed to code mode upfront based on the probe, rather than discovering unreachability by failing.

## Next

P5.b closes the config-vs-reachability gap. Two natural follow-ups remain:

### P6 — Composite + htmlwidget adapters

Still the open item from the original plan. Composite needs recursive inspection over `patchwork::wrap_plots` outputs; htmlwidget needs `webshot2` for static export.

### Gemini / Bailian probe routes

Currently fall through to `reachable = NA`. When demand surfaces, add their route patterns and probe logic. Both use non-REST API shapes (Gemini's `models/{model}:generateContent`, Bailian's DashScope routes); the probe helper will need a small per-provider branch.

### Optional: package the probe as a verb tool

Currently the agent calls `ggai_capability_status(probe = TRUE)` from inside `ggai_execute_r`. Cleaner alternative: expose it as a 4th verb tool. Considered and rejected for now — keeps the verb-tool surface minimal (the principle from ADR-0003). Reconsider if observability becomes valuable.
