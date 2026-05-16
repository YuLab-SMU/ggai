---
name: ggai-r-fonts
description: R graphics font and multilingual text guidance for ggplot output across devices and platforms.
when_to_use: Use when a ggai plot contains non-ASCII labels, CJK text, emoji, font-family requests, PDF/SVG/PNG export concerns, or reports of square-box glyphs.
---

# ggai-r-fonts

## Goal

Make R and ggplot text render legibly across platforms, languages, and output
devices without assuming that a requested font is installed.

## Core Facts

- In ggplot2, only the generic families `sans`, `serif`, and `mono` are
  portable defaults. Named font families depend on the graphics device and the
  user's operating system.
- Square boxes usually mean the selected font does not contain the requested
  glyphs, or the active device cannot resolve the font.
- Device choice matters as much as `theme(text = element_text(family = ...))`.
- Base `pdf()` is fragile for non-standard and multilingual fonts because it
  does not embed fonts by itself.
- Raster devices such as `ragg::agg_png()` plus `systemfonts` are usually more
  reliable for CJK text than legacy screen devices.
- `svglite` plus `systemfonts` is usually a good SVG path.
- `showtext` can make CJK and custom font rendering more portable by drawing
  text through its own rendering path when the package is available.

## Platform Defaults to Consider

Use these only as suggestions. Do not assume they are installed.

- macOS CJK: `PingFang SC`, `Heiti SC`, `Songti SC`, `Hiragino Sans GB`.
- Windows CJK: `Microsoft YaHei`, `SimHei`, `SimSun`, `Microsoft JhengHei`.
- Linux CJK: `Noto Sans CJK SC`, `Noto Sans CJK JP`, `Noto Sans CJK KR`,
  `WenQuanYi Micro Hei`.
- Portable open-source choice when installed: `Noto Sans CJK`.

## Agent Rules

- If the user reports square boxes, tofu, missing Chinese/Japanese/Korean text,
  or broken multilingual labels, treat it as a font/device issue before trying
  unrelated plot redesigns.
- Prefer ASCII-only plot labels when the user did not explicitly ask for
  non-English labels and the environment font support is unknown.
- When preserving Chinese or other CJK labels, prefer a widely available CJK
  family and explicitly set it in the theme, for example:
  `ggplot2::theme(text = ggplot2::element_text(family = "PingFang SC"))`.
- If the target output is PNG, prefer guidance that uses `ragg::agg_png()` when
  available. Do not call it in generated plot code unless the user asked for an
  export file.
- If the target output is SVG, prefer guidance that uses `svglite::svglite()`
  when available.
- If the target output is PDF and CJK text must survive on other machines,
  avoid claiming that base `pdf()` is enough. Prefer `showtext` or a device
  that embeds or outlines text when available.
- Do not install font packages, system fonts, or R packages. If the required
  font/device package is missing, declare the limitation or keep labels in a
  safer language.
- Do not hardcode one OS font unless the user specified the platform or the
  current environment strongly implies it.

## Practical Fix Patterns

For interactive ggplot objects:

```r
p +
  ggplot2::theme_minimal(base_family = "PingFang SC") +
  ggplot2::theme(
    text = ggplot2::element_text(family = "PingFang SC")
  )
```

For uncertain cross-platform CJK output:

```r
font_family <- "Noto Sans CJK SC"
p +
  ggplot2::theme_minimal(base_family = font_family) +
  ggplot2::theme(text = ggplot2::element_text(family = font_family))
```

For user-facing guidance, explain that the user may need to replace
`font_family` with an installed font on their machine.

## Failure Standard

Declare a blocker or limitation when:

- the user requires a specific font that is not known to be installed;
- a requested language requires glyph coverage that no available family can
  guarantee;
- the requested export device is known to be fragile for the requested text;
- solving the problem would require installing fonts or packages.

## References

- R grDevices `pdf()` documentation: base PDF devices do not embed fonts by
  default and only use known family mappings.
- R grDevices `quartz()` documentation: missing glyphs can be shown as empty
  oblongs on macOS.
- R grDevices `windowsFonts()` and X11 font documentation: family mapping is
  platform-specific.
- ggplot2 FAQ on fonts: only `sans`, `serif`, and `mono` are guaranteed.
- ragg and systemfonts documentation: system font discovery/shaping is device
  dependent and strongest with supported devices.
- svglite documentation: SVG text/font handling integrates with systemfonts.
- showtext documentation: renders text through its own path/raster workflow for
  device-independent font output.
