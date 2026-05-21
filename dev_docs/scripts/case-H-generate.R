#!/usr/bin/env Rscript
# Case H · paper figure -> 中文社交媒体封面
#
# Source: dev_docs/figures/case-ferroptosis.png (ferroptosis aged liver schematic)
# Goal: turn it into 3 social-media covers (WeChat / Xiaohongshu / Douyin)
# Each cover is a separate ggai_edit_image() call with its own prompt.

suppressPackageStartupMessages({
  library(ggai)
})

src_image   <- "dev_docs/figures/case-H/H-before.png"
out_dir     <- "dev_docs/figures/case-H"
img_model   <- ggai_image_model()

stopifnot(file.exists(src_image))
message("Source: ", src_image)
message("Model:  ", img_model)

# ---- Variant 1 · WeChat public-account cover ----------------------------
wechat_prompt <- "
Redesign the input figure into a vertical 1024x1536 portrait cover
for a Chinese WeChat (公众号) feature article.

PRESERVE the scientific spirit of the input:
  - young healthy hepatocyte (left) vs aged hepatocyte with ferroptosis (right)
  - red Fe iron dots and red peroxidized lipid spikes on the aged cell
  - membrane rupture indicators
  - an arrow leading to a damaged liver labelled MASLD

LAYOUT (top to bottom, vertical portrait):
  1. TOP THIRD: bold simplified Chinese title, two stacked lines,
     line 1: 衰老的肝脏
     line 2: 铁的诅咒
     Below the title, a smaller line of simplified Chinese subtitle:
     一篇 Nature Aging 的快速解读
     All Chinese text must be rendered as clean simplified Chinese characters,
     NOT pinyin, NOT mojibake, NOT pseudo-glyphs.
  2. MIDDLE HALF: the ferroptosis mechanism scene (young cell vs aged cell
     with rupturing membrane and Fe dots, arrow to MASLD liver). Keep it
     visually simplified but scientifically recognizable. Use the same warm
     pink/peach/coral cellular palette as the source. Slightly darker
     background so the title pops on top.
  3. BOTTOM STRIP:
     - LEFT corner: small white tag with text 'Nature Aging | 2024'
     - RIGHT corner: a white 200x200 square block representing a QR-code
       placeholder. Inside the square, draw a simple grid pattern resembling
       a QR code, and below the square print the Chinese caption '扫码看全文'.

STYLE:
  - dark deep-navy background overall, so white Chinese title has high contrast
  - the title font should be heavy/bold sans-serif (think 思源黑体 Heavy)
  - professional editorial look, like a Nature-style feature opener but
     translated into Chinese social-media aesthetic
  - no English in the headline, only the small attribution tag may stay English

CRITICAL:
  - Render ALL Chinese characters as proper simplified Chinese glyphs.
  - Title must be the most prominent visual element.
  - Aspect ratio strictly 1024x1536 portrait.
"

# ---- Variant 2 · Xiaohongshu (red book) cover ---------------------------
xhs_prompt <- "
Redesign the input figure into a vertical 1024x1536 portrait cover
in the style of a Chinese Xiaohongshu (小红书) lifestyle health post.

PRESERVE: the same ferroptosis story (young vs aged hepatocyte, red iron
dots, peroxidized lipids, liver damage arrow) but render it cuter,
flatter, slightly cartoon-like. NOT clinical, NOT scary.

LAYOUT:
  - Bright cheerful background: pastel coral pink fading to warm yellow.
  - TOP: a huge attention-grabbing simplified Chinese headline in
    Xiaohongshu hand-drawn bold style:
        🚨 你的肝在变铁锈！
    The emoji at the start MUST be the red siren 🚨. Make the headline
    occupy roughly the top quarter and be the loudest element.
  - Just below the headline, a smaller hand-written-feel subtitle:
        衰老 + 铁 = 肝细胞慢慢坏掉
  - MIDDLE: a simplified, cartoon-friendly redraw of the ferroptosis
    mechanism (young cell smiling, aged cell with little red dots and
    cracks), arrow to a small worried liver icon. Use rounded shapes,
    thick outlines, candy palette.
  - BOTTOM: a soft white rounded card with the simplified Chinese mini-tip
    title '3 个生活习惯保护肝' followed by three short bullet lines, each
    starting with a small icon emoji:
        🥦 多吃绿叶菜
        🏃 每天动一动
        😴 睡满 7 小时
  - Bottom-right corner: a tiny grey tag '参考 Nature Aging 2024'.

STYLE:
  - vibe is friendly, optimistic, soft, like a 小红书 health blogger.
  - thick rounded sans-serif simplified Chinese characters
  - NO heavy scientific jargon visible on the page
  - playful but tidy

CRITICAL:
  - All Chinese text must be proper simplified Chinese characters, no
    mojibake, no English substitution.
  - 1024x1536 portrait aspect.
  - Emojis should look like real emojis, not redrawn glyphs.
"

# ---- Variant 3 · Douyin (TikTok) video thumbnail ------------------------
douyin_prompt <- "
Redesign the input figure into a vertical 1024x1536 portrait
thumbnail/cover for a Chinese Douyin (抖音) short science video.

PRESERVE the ferroptosis story (aged hepatocyte with iron Fe dots and
peroxidized lipid spikes, membrane rupturing, leading to damaged liver)
but treat it dramatically, like a clickbait thumbnail.

LAYOUT:
  - Background: dramatic dark gradient (deep red to black), with a subtle
    glow behind the cell.
  - TOP-LEFT: a bright red exclamation-mark callout box (like a Douyin
    sticker), rotated slightly, containing a giant white '!' and the
    simplified Chinese text '震惊'.
  - CENTER HEADLINE: enormous bold simplified Chinese title, three stacked
    lines, each line slightly wider/larger than the previous, neon-yellow
    fill with thick black outline:
        肝脏正在
        生锈
        看完震惊了！
    This headline must dominate the upper half of the image.
  - MIDDLE-LOWER: the ferroptosis hepatocyte image, with heavy red glow
    around the iron dots and a glowing arrow pointing to a damaged liver.
    Treat it like a movie still, not a textbook illustration.
  - BOTTOM: a yellow ribbon banner across the bottom with simplified
    Chinese text '一张图看懂衰老和铁的关系' in bold black sans-serif.
  - BOTTOM-RIGHT: small white tag 'Nature Aging 2024'.

STYLE:
  - high contrast, neon, dramatic
  - Douyin/抖音 thumbnail aesthetic: thick outlines, saturated colors,
    obvious 'click me' energy
  - cinematic, slightly chaotic, but readable

CRITICAL:
  - Every Chinese phrase must be proper simplified Chinese, not pinyin and
    not garbled glyphs.
  - 1024x1536 portrait aspect.
  - Title is the MOST prominent element.
"

write_artifact <- function(result, out_path) {
  # aisdk returns a list with $images[[1]]$base64 typically; handle several shapes
  if (is.null(result)) stop("Empty result for ", out_path)
  imgs <- result$images %||% result$data %||% NULL
  if (is.null(imgs) || length(imgs) == 0L) {
    # maybe direct file
    if (!is.null(result$path) && file.exists(result$path)) {
      file.copy(result$path, out_path, overwrite = TRUE)
      return(invisible(out_path))
    }
    stop("Result has no images: ", paste(names(result), collapse = ", "))
  }
  first <- imgs[[1]]
  b64 <- first$base64 %||% first$b64_json %||% first$data %||% NULL
  if (!is.null(b64) && is.character(b64) && nzchar(b64)) {
    raw <- base64enc::base64decode(b64)
    writeBin(raw, out_path)
    return(invisible(out_path))
  }
  if (!is.null(first$path) && file.exists(first$path)) {
    file.copy(first$path, out_path, overwrite = TRUE)
    return(invisible(out_path))
  }
  stop("Could not extract image bytes for ", out_path,
       " (keys: ", paste(names(first), collapse = ", "), ")")
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

run_variant <- function(label, prompt, out_path, attempts = 3L) {
  message("\n--- Variant: ", label, " ---")
  last_err <- NULL
  for (i in seq_len(attempts)) {
    message(sprintf("  attempt %d/%d", i, attempts))
    t0 <- Sys.time()
    res <- tryCatch(
      ggai_edit_image(
        model                       = img_model,
        prompt                      = prompt,
        image                       = src_image,
        size                        = "1024x1536",
        quality                     = "high",
        total_timeout_seconds       = 600,
        first_byte_timeout_seconds  = 240,
        connect_timeout_seconds     = 30,
        idle_timeout_seconds        = 240
      ),
      error = function(e) {
        message("  attempt ", i, " failed: ", conditionMessage(e))
        last_err <<- e
        NULL
      }
    )
    if (!is.null(res)) {
      dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
      message(sprintf("  api time: %.1f s", dt))
      write_artifact(res, out_path)
      message("  wrote: ", out_path)
      return(invisible(list(path = out_path, seconds = dt, attempts = i)))
    }
  }
  if (!is.null(last_err)) stop(last_err)
  stop("Variant ", label, " failed without error info")
}

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

variants <- list(
  wechat       = list(prompt = wechat_prompt,  out = file.path(out_dir, "H-cover-wechat.png")),
  xiaohongshu  = list(prompt = xhs_prompt,     out = file.path(out_dir, "H-cover-xiaohongshu.png")),
  douyin       = list(prompt = douyin_prompt,  out = file.path(out_dir, "H-cover-douyin.png"))
)

results <- list()
total_calls <- 0L
t_start <- Sys.time()
for (nm in names(variants)) {
  v <- variants[[nm]]
  results[[nm]] <- run_variant(nm, v$prompt, v$out)
  total_calls <- total_calls + 1L
}
t_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

cat("\n==== Case H summary ====\n")
cat(sprintf("Total API calls: %d\n", total_calls))
cat(sprintf("Total wall time: %.1f s\n", t_total))
for (nm in names(results)) {
  cat(sprintf("  %-12s -> %s (%.1f s)\n", nm, results[[nm]]$path, results[[nm]]$seconds))
}
