test_that("live compiler round-trip works when aisdk runtime is available", {
  skip_if_not(Sys.getenv("GGAI_RUN_LIVE_COMPILER", "") %in% c("1", "true", "TRUE"), "Live compiler test disabled")
  skip_if_not(ggai:::ggai_aisdk_runtime_available(), "aisdk runtime is not available")
  skip_if_not(
    nzchar(Sys.getenv("OPENAI_API_KEY", "")) ||
      nzchar(Sys.getenv("GOOGLE_API_KEY", "")) ||
      nzchar(Sys.getenv("GEMINI_API_KEY", "")),
    "No live model credentials detected"
  )

  spec <- tryCatch(
    ggai:::compile_layer_spec(
      "Label a few interesting points",
      plot_context = list(mapped_aes = c("x", "y"), geoms = "point"),
      model = ggai::ggai_default_models()$language
    ),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("status 403|no access to model|Internet connection", msg, ignore.case = TRUE)) {
        safe_msg <- gsub("https?://[^[:space:]]+", "<redacted-url>", msg)
        safe_msg <- gsub("key=[^[:space:]]+", "key=<redacted>", safe_msg)
        skip(paste("Live compiler unavailable in current environment:", safe_msg))
      }
      stop(e)
    }
  )

  expect_true(is.list(spec))
  expect_false(is.null(spec$layers))
})
