test_that("ggai resolves default language and image models", {
  old_image_env <- Sys.getenv("GGAI_IMAGE_MODEL", unset = NA_character_)
  old_image_opt <- getOption("ggai.image_model")
  on.exit({
    if (is.na(old_image_env)) {
      Sys.unsetenv("GGAI_IMAGE_MODEL")
    } else {
      Sys.setenv(GGAI_IMAGE_MODEL = old_image_env)
    }
    options(ggai.image_model = old_image_opt)
  }, add = TRUE)

  Sys.setenv(GGAI_IMAGE_MODEL = "openai:gpt-image-2")
  options(ggai.image_model = NULL)

  cfg <- ggai_default_models()

  expect_named(cfg, c("language", "image"))
  expect_true(is.character(cfg$language))
  expect_true(is.character(cfg$image))
  expect_equal(cfg$image, "openai:gpt-image-2")
})

test_that("ggai default models read project and user env files before stale process env", {
  root <- tempfile()
  home <- tempfile()
  dir.create(root)
  dir.create(home)
  writeLines(
    c(
      "OPENAI_BASE_URL=https://example.test/v1",
      "OPENAI_API_KEY=sk-project",
      "OPENAI_IMAGE_MODEL=gpt-image-2"
    ),
    file.path(root, ".env")
  )
  writeLines(
    c(
      "GGAI_LANGUAGE_MODEL=gemini:gemini-2.5-flash",
      "GGAI_IMAGE_MODEL=gemini:gemini-3.1-flash-image-preview"
    ),
    file.path(root, ".Renviron")
  )
  writeLines("OPENAI_MODEL=gpt-5.5", file.path(home, ".Renviron"))

  old <- list(
    wd = getwd(),
    home = Sys.getenv("HOME", unset = NA_character_),
    lang = Sys.getenv("GGAI_LANGUAGE_MODEL", unset = NA_character_),
    image = Sys.getenv("GGAI_IMAGE_MODEL", unset = NA_character_),
    openai_base = Sys.getenv("OPENAI_BASE_URL", unset = NA_character_),
    openai_key = Sys.getenv("OPENAI_API_KEY", unset = NA_character_),
    lang_opt = getOption("ggai.language_model"),
    image_opt = getOption("ggai.image_model")
  )
  on.exit({
    setwd(old$wd)
    if (is.na(old$home)) Sys.unsetenv("HOME") else Sys.setenv(HOME = old$home)
    if (is.na(old$lang)) Sys.unsetenv("GGAI_LANGUAGE_MODEL") else Sys.setenv(GGAI_LANGUAGE_MODEL = old$lang)
    if (is.na(old$image)) Sys.unsetenv("GGAI_IMAGE_MODEL") else Sys.setenv(GGAI_IMAGE_MODEL = old$image)
    if (is.na(old$openai_base)) Sys.unsetenv("OPENAI_BASE_URL") else Sys.setenv(OPENAI_BASE_URL = old$openai_base)
    if (is.na(old$openai_key)) Sys.unsetenv("OPENAI_API_KEY") else Sys.setenv(OPENAI_API_KEY = old$openai_key)
    options(ggai.language_model = old$lang_opt)
    options(ggai.image_model = old$image_opt)
  }, add = TRUE)

  setwd(root)
  Sys.setenv(
    HOME = home,
    GGAI_LANGUAGE_MODEL = "gemini:gemini-2.5-flash",
    GGAI_IMAGE_MODEL = "gemini:gemini-3.1-flash-image-preview"
  )
  Sys.unsetenv("OPENAI_BASE_URL")
  Sys.unsetenv("OPENAI_API_KEY")
  options(ggai.language_model = NULL, ggai.image_model = NULL)

  cfg <- ggai_default_models()
  loaded <- ggai_load_env()

  expect_equal(cfg$language, "openai:gpt-5.5")
  expect_equal(cfg$image, "openai:gpt-image-2")
  expect_true("OPENAI_BASE_URL" %in% loaded)
  expect_equal(Sys.getenv("OPENAI_BASE_URL"), "https://example.test/v1")
})

test_that("ggai default language model honors aisdk default model", {
  root <- tempfile()
  home <- tempfile()
  dir.create(root)
  dir.create(home)

  old <- list(
    wd = getwd(),
    home = Sys.getenv("HOME", unset = NA_character_),
    openai_model = Sys.getenv("OPENAI_MODEL", unset = NA_character_),
    ggai_language_model = Sys.getenv("GGAI_LANGUAGE_MODEL", unset = NA_character_),
    lang_opt = getOption("ggai.language_model"),
    image_opt = getOption("ggai.image_model"),
    aisdk_opt = getOption("aisdk.default_model"),
    aisdk_model = if (requireNamespace("aisdk", quietly = TRUE)) {
      get("get_model", envir = asNamespace("aisdk"), inherits = FALSE)(default = NULL)
    } else {
      NULL
    }
  )
  on.exit({
    setwd(old$wd)
    if (is.na(old$home)) Sys.unsetenv("HOME") else Sys.setenv(HOME = old$home)
    if (is.na(old$openai_model)) Sys.unsetenv("OPENAI_MODEL") else Sys.setenv(OPENAI_MODEL = old$openai_model)
    if (is.na(old$ggai_language_model)) Sys.unsetenv("GGAI_LANGUAGE_MODEL") else Sys.setenv(GGAI_LANGUAGE_MODEL = old$ggai_language_model)
    options(
      ggai.language_model = old$lang_opt,
      ggai.image_model = old$image_opt,
      aisdk.default_model = old$aisdk_opt
    )
    if (requireNamespace("aisdk", quietly = TRUE)) {
      get("set_model", envir = asNamespace("aisdk"), inherits = FALSE)(old$aisdk_model)
    }
  }, add = TRUE)

  setwd(root)
  Sys.setenv(HOME = home)
  Sys.unsetenv("OPENAI_MODEL")
  Sys.unsetenv("GGAI_LANGUAGE_MODEL")
  options(ggai.language_model = NULL, ggai.image_model = NULL, aisdk.default_model = NULL)
  if (requireNamespace("aisdk", quietly = TRUE)) {
    get("set_model", envir = asNamespace("aisdk"), inherits = FALSE)("deepseek:deepseek-v4-flash")
  } else {
    options(aisdk.default_model = "deepseek:deepseek-v4-flash")
  }

  expect_equal(ggai_default_models()$language, "deepseek:deepseek-v4-flash")
})

test_that("ggai_set_model switches and clears current session defaults", {
  root <- tempfile()
  home <- tempfile()
  dir.create(root)
  dir.create(home)

  old <- list(
    wd = getwd(),
    home = Sys.getenv("HOME", unset = NA_character_),
    openai_model = Sys.getenv("OPENAI_MODEL", unset = NA_character_),
    ggai_language_model = Sys.getenv("GGAI_LANGUAGE_MODEL", unset = NA_character_),
    ggai_image_model = Sys.getenv("GGAI_IMAGE_MODEL", unset = NA_character_),
    lang_opt = getOption("ggai.language_model"),
    image_opt = getOption("ggai.image_model"),
    aisdk_opt = getOption("aisdk.default_model"),
    aisdk_model = if (requireNamespace("aisdk", quietly = TRUE)) {
      get("get_model", envir = asNamespace("aisdk"), inherits = FALSE)(default = NULL)
    } else {
      NULL
    }
  )
  on.exit({
    setwd(old$wd)
    if (is.na(old$home)) Sys.unsetenv("HOME") else Sys.setenv(HOME = old$home)
    if (is.na(old$openai_model)) Sys.unsetenv("OPENAI_MODEL") else Sys.setenv(OPENAI_MODEL = old$openai_model)
    if (is.na(old$ggai_language_model)) Sys.unsetenv("GGAI_LANGUAGE_MODEL") else Sys.setenv(GGAI_LANGUAGE_MODEL = old$ggai_language_model)
    if (is.na(old$ggai_image_model)) Sys.unsetenv("GGAI_IMAGE_MODEL") else Sys.setenv(GGAI_IMAGE_MODEL = old$ggai_image_model)
    options(
      ggai.language_model = old$lang_opt,
      ggai.image_model = old$image_opt,
      aisdk.default_model = old$aisdk_opt
    )
    if (requireNamespace("aisdk", quietly = TRUE)) {
      get("set_model", envir = asNamespace("aisdk"), inherits = FALSE)(old$aisdk_model)
    }
  }, add = TRUE)

  setwd(root)
  Sys.setenv(HOME = home)
  Sys.unsetenv("OPENAI_MODEL")
  Sys.unsetenv("GGAI_LANGUAGE_MODEL")
  Sys.unsetenv("GGAI_IMAGE_MODEL")
  options(ggai.language_model = NULL, ggai.image_model = NULL, aisdk.default_model = NULL)
  if (requireNamespace("aisdk", quietly = TRUE)) {
    get("set_model", envir = asNamespace("aisdk"), inherits = FALSE)(NULL)
  }

  expect_equal(ggai_get_model(), "openai:gpt-5.2")

  old_language <- ggai_set_model("gpt-5.5")
  expect_equal(old_language, "openai:gpt-5.2")
  expect_equal(ggai_get_model(), "openai:gpt-5.5")
  expect_equal(getOption("ggai.language_model"), "openai:gpt-5.5")
  if (requireNamespace("aisdk", quietly = TRUE)) {
    current_aisdk <- get("get_model", envir = asNamespace("aisdk"), inherits = FALSE)(default = NULL)
    expect_equal(current_aisdk, "openai:gpt-5.5")
  }

  old_image <- ggai_set_model("gpt-image-2", type = "image")
  expect_equal(old_image, "openai:gpt-image-2")
  expect_equal(ggai_get_model("image"), "openai:gpt-image-2")

  expect_equal(ggai_set_model(NULL), "openai:gpt-5.5")
  expect_equal(ggai_get_model(), "openai:gpt-5.2")
})

test_that("bare provider-native model names are normalized to provider:model", {
  expect_equal(ggai:::normalize_model_id("gemini-3-flash-preview", type = "language"), "gemini:gemini-3-flash-preview")
  expect_equal(ggai:::normalize_model_id("gpt-image-2", type = "image"), "openai:gpt-image-2")
  expect_equal(ggai:::normalize_model_id("gpt-image-1.5", type = "image"), "openai:gpt-image-1.5")
  expect_equal(ggai:::normalize_model_id("gemini:gemini-2.5-flash", type = "language"), "gemini:gemini-2.5-flash")
})
