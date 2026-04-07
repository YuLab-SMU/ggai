# DeepWiki Q&A with Code Context for Repository: tidyverse/ggplot2
## Q1
手把手告诉我，如果创建一个自定义图层？
### Answer
# 手把手创建 ggplot2 自定义图层

在 ggplot2 中，一个图层（Layer）由三个核心组件组成：**Geom（几何对象）**、**Stat（统计变换）** 和 **Position（位置调整）**。下面分步骤讲解如何创建自定义图层。

---

## 第一步：理解图层的组成

`layer()` 函数是图层的核心，所有 `geom_*()` 和 `stat_*()` 本质上都是对它的封装。一个图层由 `geom`、`stat`、`position`、`data`、`mapping` 等参数组合而成。 ggplot2:1-46 

---

## 第二步：使用 `ggproto()` 创建自定义 Geom 类

ggplot2 使用 `ggproto()` 实现面向对象系统。创建自定义 Geom 需要继承基类 `Geom`，并覆写以下关键字段和方法：

- `required_aes`：必须提供的美学映射（如 `x`, `y`）
- `default_aes`：默认美学属性值
- `draw_key`：图例中的图标绘制函数
- `draw_panel()` 或 `draw_group()`：**核心绘图方法**，返回 grid grob 对象

代码文档里有一个最简单的 `GeomSimplePoint` 示例，展示了完整流程： ggplot2:5-76 

`GeomPoint` 是一个真实实现的好范例，展示了如何调用 `coord$transform()` 变换坐标，再用 `grid::pointsGrob()` 绘图： ggplot2:5-37 

---

## 第三步：为 Geom 编写构造函数

构造函数是用户调用的 `geom_xxx()` 函数，它内部调用 `layer()` 并传入自定义的 Geom 类： ggplot2:62-76 

或者，你可以使用 `make_constructor()` 自动生成构造函数（**推荐方式**），它会自动从 `draw_panel()`/`draw_group()` 的参数中推断出用户参数： ggplot2:59-146 

---

## 第四步（可选）：创建自定义 Stat 类

如果你的图层需要对数据做统计变换，可以创建自定义 `Stat`。核心是覆写 `compute_panel()` 或 `compute_group()` 方法： ggplot2:42-73 

`Stat` 基类的 `compute_layer()` 方法会自动按面板（panel）拆分数据并调用你的 `compute_panel()`： ggplot2:188-223 

---

## 第五步：了解数据在图层中的流转

整个图层的数据处理流程如下：

```mermaid
flowchart TD
    "layer(data)" --> "Layer$layer_data()"
    "Layer$layer_data()" --> "Layer$setup_layer()"
    "Layer$setup_layer()" --> "Layer$compute_aesthetics()"
    "Layer$compute_aesthetics()" --> "Scale transform"
    "Scale transform" --> "Layer$compute_statistic()"
    "Layer$compute_statistic()" --> "Stat$compute_layer()"
    "Stat$compute_layer()" --> "Layer$map_statistic()"
    "Layer$map_statistic()" --> "Layer$compute_geom_1()"
    "Layer$compute_geom_1()" --> "Geom$setup_data()"
    "Geom$setup_data()" --> "Layer$compute_position()"
    "Layer$compute_position()" --> "Layer$compute_geom_2()"
    "Layer$compute_geom_2()" --> "Geom$use_defaults()"
    "Geom$use_defaults()" --> "Layer$draw_geom()"
    "Layer$draw_geom()" --> "Geom$draw_layer()"
    "Geom$draw_layer()" --> "Geom$draw_panel() / draw_group()"
``` ggplot2:196-326 

---

## 第六步：Geom 的核心字段一览

| 字段/方法 | 作用 |
|---|---|
| `required_aes` | 必须提供的美学映射 |
| `non_missing_aes` | 缺失时会移除该行的美学属性 |
| `optional_aes` | 可选的美学映射 |
| `default_aes` | 默认美学属性 |
| `extra_params` | `draw_panel()` 之外的额外参数（默认含 `"na.rm"`） |
| `draw_key` | 图例图标绘制函数 |
| `setup_params()` | 在绘图前处理参数 |
| `setup_data()` | 在绘图前处理数据 |
| `draw_panel()` | 按面板绘制，返回 grob |
| `draw_group()` | 按分组绘制，返回 grob | ggplot2:77-112 

图例绘制函数（`draw_key_*`）可以在 `draw_key` 字段中指定： ggplot2:1-39 

---

## Notes

1. **命名规范**：Geom 类名使用 `UpperCamelCase` 并以 `Geom` 前缀开头（如 `GeomMyCustom`），对应构造函数使用 `snake_case`（如 `geom_my_custom()`）。 ggplot2:29-38 
2. **Stat 同理**：Stat 类名以 `Stat` 开头（如 `StatMyCustom`），构造函数为 `stat_my_custom()`。 ggplot2:23-33 
3. `draw_panel()` 中必须通过 `coord$transform(data, panel_params)` 将坐标转换为 [0, 1] 的 viewport 坐标，才能正确适配各种坐标系。 ggplot2:374-393 
4. `Layer` 类本身**不建议扩展**，自定义能力主要通过扩展 `Geom`、`Stat`、`Position` 三个类来实现。 ggplot2:176-193
### Citations
**File:** R/layer.R (L1-46)
```r
#' Create a new layer
#'
#' A layer is a combination of data, stat and geom with a potential position
#' adjustment. Usually layers are created using `geom_*` or `stat_*`
#' calls but it can also be created directly using this function.
#'
#' @export
#' @inheritParams shared_layer_parameters
#' @param check.aes,check.param If `TRUE`, the default, will check that
#'   supplied parameters and aesthetics are understood by the `geom` or
#'   `stat`. Use `FALSE` to suppress the checks.
#' @param params Additional parameters to the `geom` and `stat`.
#' @param key_glyph A legend key drawing function or a string providing the
#'   function name minus the `draw_key_` prefix. See [draw_key] for details.
#' @param layout Argument to control layout at the layer level. Consult the
#'   faceting documentation to view appropriate values.
#' @param layer_class The type of layer object to be constructed. This is
#'   intended for ggplot2 internal use only.
#' @keywords internal
#' @seealso
#' The `r link_book(c("plot building chapter", "geoms chapter"), c("layers", "individual-geoms"))`
#' @family layer documentation
#' @examples
#' # geom calls are just a short cut for layer
#' ggplot(mpg, aes(displ, hwy)) + geom_point()
#' # shortcut for
#' ggplot(mpg, aes(displ, hwy)) +
#'   layer(
#'     geom = "point", stat = "identity", position = "identity",
#'     params = list(na.rm = FALSE)
#'   )
#'
#' # use a function as data to plot a subset of global data
#' ggplot(mpg, aes(displ, hwy)) +
#'   layer(
#'     geom = "point", stat = "identity", position = "identity",
#'     data = head, params = list(na.rm = FALSE)
#'   )
#'
layer <- function(geom = NULL, stat = NULL,
                  data = NULL, mapping = NULL,
                  position = NULL, params = list(),
                  inherit.aes = TRUE, check.aes = TRUE, check.param = TRUE,
                  show.legend = NA, key_glyph = NULL, layout = NULL, layer_class = Layer) {
  call_env <- caller_env()
  user_env <- caller_env(2)
```
**File:** R/layer.R (L176-193)
```r
#' Layers
#' @name Layer-class
#'
#' @description
#' The Layer class is a chaperone class not available for extension. The class
#' fulfils the following tasks. The class houses the Geom, Stat and Position
#' trinity and tracks their stateful parameters. Furthermore, its methods are
#' responsible for managing the layer data and exposing it to other components
#' of the plot at the right time.
#'
#' @details
#' The Layer class is an internal class that is not exported because the class
#' is not intended for extension. The `layer()` function instantiates the
#' LayerInstance class, which inherits from Layer, but has relevant fields
#' populated.
#'
#' The class is mostly used in `ggplot_build()`, with the notable exception
#' of the `draw_geom()` method, which is used in `ggplot_gtable()` instead.
```
**File:** R/layer.R (L196-326)
```r
#'
#' As the Layer class is a chaparone for the data, it makes sense to give a
#' small overview of how layer data flows through a plot. In the diagram below
#' we following the `layer(data)` argument over the course of plot building
#' through Layer class methods. When an outside class acts on the data without
#' the Layer class, this is indicated with the left arrow `<-`. Subcomponents
#' of a method that touch data are indicated with the right arrow `->`.
#'
#' ```r
#' # Inside `ggplot_build()`
#'  |
#' layer(data)
#'  |
#'  |
#'  | # Inherit plot data
#'  |
#' Layer$layer_data()
#'  |
#'  |
#'  | # Finalise mapping
#'  |
#' Layer$setup_layer()
#'  |
#'  |
#'  | # Append PANEL variable for facets
#'  |
#'  |<- Layout$setup()
#'  |    |
#'  |    +-> Facet$setup_data()
#'  |    |
#'  |    +-> Coord$setup_data()
#'  |
#'  |
#'  | # Evaluate mappings to new data and infer group
#'  |
#' Layer$compute_aesthetics()
#'  |
#'  |
#'  | # Scale-transform all aesthetics
#'  |
#'  |<- ScalesList$transform_df()
#'  |    |
#'  |    +-> Scale$transform_df()
#'  |
#'  |
#'  | # Map x/y aesthetics with initial scale
#'  |
#'  |<- Layout$map_position()
#'  |    |
#'  |    +-> Scale$map()
#'  |
#'  |
#'  | # Compute stat part of layer
#'  |
#' Layer$compute_statistic()
#'  | |
#'  | +-> Stat$setup_data()
#'  | |
#'  | +-> Stat$compute_layer()
#'  |
#'  |
#'  | # Add `after_stat()` stage
#'  | # Scale transform computed variables
#'  |
#' Layer$map_statistic()
#'  |
#'  |
#'  | # Setup geom part of layer
#'  |
#' Layer$compute_geom_1()
#'  | |
#'  | +-> Geom$setup_data()
#'  |
#'  |
#'  | # Apply position adjustments
#'  |
#' Layer$compute_position()
#'  | |
#'  | +-> Position$use_defaults()
#'  | |
#'  | +-> Position$setup_data()
#'  | |
#'  | +-> Position$compute_layer()
#'  |
#'  |
#'  | # Map x/y aesthetics with final scales
#'  |
#'  |<- Layout$map_position()
#'  |    |
#'  |    +-> Scale$map()
#'  |
#'  | # Map non-position aesthetics
#'  |
#'  |<- ScalesList$map_df()
#'  |    |
#'  |    +-> Scale$map()
#'  |
#'  |
#'  | # Fill in defaults and fixed aesthetics
#'  |
#' Layer$compute_geom_2()
#'  | |
#'  | +-> Geom$use_defaults()
#'  |
#'  |
#'  | # Apply final Stat hook
#'  |
#' Layer$finish_statistics()
#'  | |
#'  | +-> Stat$finish_layer()
#'  |
#'  |
#'  | # Apply final Facet hook
#'  |
#'  |<- Layout$finish_data()
#'  |    |
#'  |    +-> Facet$finish_data()
#'  |
#'  V
#' # `ggplot_build()` is finished
#' # Hand off to `ggplot_gtable()`
#'  |
#'  |
#'  | # Draw the geom part
#'  |
#' Layer$draw_geom()
#'  |
#'  +-> Geom$handle_na()
#'  |
#'  +-> Geom$draw_layer()
#' ```
```
**File:** R/geom-.R (L5-76)
```r
#' Geoms
#'
#' @description
#' All `geom_*()` functions (like `geom_point()`) return a layer that
#' contains a `Geom*` object (like `GeomPoint`). The `Geom*`
#' object is responsible for rendering the data in the plot.
#'
#' @details
#' Each of the `Geom*` objects is a [ggproto()] object, descended
#' from the top-level `Geom`, and each implements various methods and
#' fields. The object and its parameters are chaperoned by the [Layer] class.
#'
#' Compared to `Stat` and `Position`, `Geom` is a little
#' different because the execution of the setup and compute functions is
#' split up. `setup_data` runs before position adjustments, and
#' `draw_layer()` is not run until render time, much later.
#'
#' When creating a new Geom class, you may want to consider override one or
#' more of the following:
#' * The `required_aes` and `default_aes` fields.
#' * The `setup_data()` and `setup_params()` functions.
#' * Either the `draw_panel()` or `draw_group()` function.
#' * The `draw_key` field.
#'
#' @section Conventions:
#'
#' The object name that a new class is assigned to is typically the same as
#' the class name. Geom class names are in UpperCamelCase and start with the
#' `Geom*` prefix, like `GeomNew`.
#'
#' A constructor function is usually paired with a Geom class. The constructor
#' wraps a call to `layer()`, where e.g. `layer(geom = GeomNew)`. The constructor
#' function name is formatted by taking the Geom class name and formatting it
#' with snake_case, so that `GeomNew` becomes `geom_new()`.
#'
#' @export
#' @format NULL
#' @usage NULL
#' @family Layer components
#' @keywords internal
#' @seealso The `r link_book("new geoms section", "extensions#sec-new-geoms")`
#' @seealso Run `vignette("extending-ggplot2")`, in particular the "Creating a
#' new geom" section.
#' @examples
#' # Extending the class
#' GeomSimplePoint <- ggproto(
#'   "GeomSimplePoint", Geom,
#'   # Fields
#'   required_aes = c("x", "y"),
#'   draw_key     = draw_key_point,
#'   # Methods
#'   draw_panel = function(data, panel_params, coord) {
#'     data <- coord$transform(data, panel_params)
#'     grid::pointsGrob(data$x, data$y)
#'   }
#' )
#'
#' # Building a constructor
#' geom_simple_point <- function(mapping = NULL, data = NULL, stat = "identity",
#'                               position = "identity", ..., na.rm = FALSE,
#'                               show.legend = NA, inherit.aes = TRUE) {
#'   layer(
#'     mapping = mapping, data = data,
#'     geom = GeomSimplePoint, stat = stat, position = position,
#'     show.legend = show.legend, inherit.aes = inherit.aes,
#'     params = list(na.rm = na.rm, ...)
#'   )
#' }
#'
#' # Use new geom in plot
#' ggplot(mpg, aes(displ, hwy)) +
#'   geom_simple_point()
```
**File:** R/geom-.R (L77-112)
```r
Geom <- ggproto(
  "Geom",

  # Fields ------------------------------------------------------------------

  #' @field required_aes A character vector naming aesthetics that are necessary
  #' to render the geom.
  required_aes = character(),

  #' @field non_missing_aes A character vector naming aesthetics that will cause
  #' removal if they have missing values.
  non_missing_aes = character(),

  #' @field optional_aes A character vector naming aesthetics that will be
  #' accepted by `layer()`, but are not required or described in the
  #' `default_aes` field.
  optional_aes = character(),

  #' @field default_aes A [mapping][aes()] of default values for aesthetics.
  #' Aesthetics can be set to `NULL` to be included as optional aesthetic.
  default_aes = aes(),

  #' @field rename_size
  #' A scalar boolean: whether to rename `size` aesthetics to `linewidth`.
  rename_size = FALSE,

  #' @field extra_params A character vector of parameter names in addition to
  #' those imputed from the `draw_panel()` or `draw_groups()` methods. This
  #' field can be set to include parameters for `setup_data()` or `handle_na()`
  #' methods. By default, this only contains `"na.rm"`.
  extra_params = c("na.rm"),

  #' @field draw_key A function generating a single legend glyph for the geom.
  #' Typically one of the functions prefixed by [`draw_key_`][draw_key].
  draw_key = draw_key_point,

```
**File:** R/geom-.R (L374-393)
```r
  #' \describe{
  #'   \item{`data`}{A data frame with the layer's data.}
  #'   \item{`panel_params`}{A list of per-panel parameters constructed by
  #'   `Coord$setup_panel_params()`. This should be considered an opaque data
  #'   structure that is just passed along when calling coord methods.}
  #'   \item{`coord`}{A `<Coord>` ggproto object. To correctly scale the
  #'   position data, one should always call
  #'   `coord$transform(data, panel_params)`. When working with non-linear
  #'   coordinate systems, data should be converted to fit a primitive geom
  #'   (e.g. point, path or polygon) and passed on to the corresponding draw
  #'   method for [munching][coord_munch()].}
  #'   \item{`...`}{Reserved for extensions. By default, this is passed on to
  #'   the `draw_group()` method.}
  #' }
  #'
  #' **Value**
  #'
  #' A single grob or [`zeroGrob()`] when there is nothing to draw. For
  #' `draw_panel()` this can be a [gTree][grid::grob] holding individual grobs
  #' from the `draw_group()` method.
```
**File:** R/geom-point.R (L5-37)
```r
GeomPoint <- ggproto(
  "GeomPoint", Geom,
  required_aes = c("x", "y"),
  non_missing_aes = c("size", "shape", "colour"),
  default_aes = aes(
    shape = from_theme(pointshape),
    colour = from_theme(colour %||% ink),
    fill = from_theme(fill %||% NA),
    size = from_theme(pointsize),
    alpha = NA,
    stroke = from_theme(borderwidth)
  ),

  draw_panel = function(self, data, panel_params, coord, na.rm = FALSE) {
    data$shape <- translate_shape_string(data$shape)
    coords <- coord$transform(data, panel_params)
    ggname(
      "geom_point",
      pointsGrob(
        coords$x, coords$y,
        pch = coords$shape,
        gp = gg_par(
          col = alpha(coords$colour, coords$alpha),
          fill = fill_alpha(coords$fill, coords$alpha),
          pointsize = coords$size,
          stroke = coords$stroke
        )
      )
    )
  },

  draw_key = draw_key_point
)
```
**File:** R/make-constructor.R (L59-146)
```r
make_constructor <- function(x, ...) {
  UseMethod("make_constructor")
}

#' @export
#' @rdname make_constructor
make_constructor.Geom <- function(x, ..., checks = exprs(), omit = character(),
                                  env = caller_env()) {

  # Check that we can independently find the geom
  geom <- gsub("^geom_", "", snake_class(x))
  validate_subclass(geom, "Geom", env = env)

  # Split additional arguments into required and extra ones
  args <- enexprs(...)
  fixed_fmls_names <- c("mapping", "data", "stat", "position", "...",
                        "na.rm", "show.legend", "inherit.aes")
  extra_args <- setdiff(names(args), fixed_fmls_names)
  if ("geom" %in% extra_args) {
    cli::cli_abort("{.arg geom} is a reserved argument.")
  }

  # Fill in values for parameters from draw functions
  known_params <-
    unique(c(names(args), fixed_fmls_names, "flipped_aes", x$aesthetics(), omit))
  missing_params <- setdiff(x$parameters(), known_params)
  if (length(missing_params) > 0) {
    draw_args <- ggproto_formals(x$draw_panel)
    if ("..." %in% names(draw_args)) {
      draw_args <- ggproto_formals(x$draw_group)
    }
    params <- intersect(missing_params, names(draw_args))
    extra_args <- c(extra_args, params)
    for (param in params) {
      if (!identical(draw_args[[param]], quote(expr = ))) {
        args[param] <- draw_args[param]
      }
    }
    extra_args <- intersect(extra_args, names(args))
    missing_params <- setdiff(missing_params, names(args))
    if (length(missing_params) > 0) {
      cli::cli_warn(
        "In {.fn geom_{geom}}: please consider providing default values for: \\
        {missing_params}."
      )
    }
  }

  # Build function formals
  fmls <- pairlist2(
    mapping  = args$mapping,
    data     = args$data,
    stat     = args$stat %||% "identity",
    position = args$position %||% "identity",
    `...` = missing_arg(),
    !!!args[extra_args],
    na.rm    = args$na.rm %||% FALSE,
    show.legend = args$show.legend %||% NA,
    inherit.aes = args$inherit.aes %||% TRUE
  )

  # Construct call for the 'layer(params)' argument
  params <- exprs(!!!syms(c("na.rm", extra_args)), .named = TRUE)
  params <- call2("list2", !!!params, quote(...))

  # Construct rest of 'layer()' call
  layer_args <- syms(setdiff(fixed_fmls_names, c("...", "na.rm")))
  layer_args <- append(layer_args, list(geom = geom), after = 2)
  layer_args <- exprs(!!!layer_args, params = !!params, .named = TRUE)
  body <- call2("layer", !!!layer_args)

  # Prepend any checks
  if (length(exprs) > 0) {
    lang <- vapply(checks, is_call, logical(1))
    if (!all(lang)) {
      cli::cli_abort(
        "{.arg checks} must be a list of calls, such as one constructed \\
        with {.fn rlang::exprs}."
      )
    }
  }
  body <- call2("{", !!!checks, body)

  # We encapsulate rlang::list2
  new_env <- new_environment(list(list2 = list2), env)

  new_function(fmls, body, new_env)
}
```
**File:** R/stat-.R (L23-33)
```r
#' @section Conventions:
#'
#' The object name that a new class is assigned to is typically the same as the
#' class name. Stat class names are in UpperCamelCase and start with the `Stat*`
#' prefix, like `StatNew`.
#'
#' A constructor function is usually paired wih a Stat class. The constructor
#' wraps a call to `layer()`, where e.g. `layer(stat = StatNew)`. The
#' constructor function name is formatted by taking the Stat class name and
#' formatting it with snake_case, so that `StatNew` becomes `stat_new()`.
#'
```
**File:** R/stat-.R (L42-73)
```r
#' @examples
#' # Extending the class
#' StatKmeans <- ggproto(
#'   "StatKmeans", Stat,
#'   # Fields
#'   required_aes = c("x", "y"),
#'   # You can relate computed variables to aesthetics using `after_stat()`
#'   # in defaults
#'   default_aes = aes(colour = after_stat(cluster)),
#'   # Methods
#'   compute_panel = function(data, scales, k = 2L) {
#'     km <- kmeans(cbind(scale(data$x), scale(data$y)), centers = k)
#'     data$cluster <- factor(km$cluster)
#'     data
#'   }
#' )
#'
#' # Building a constructor
#' stat_kmeans <- function(mapping = NULL, data = NULL, geom = "point",
#'                         position = "identity", ..., k = 2L, na.rm = FALSE,
#'                         show.legend = NA, inherit.aes = TRUE) {
#'   layer(
#'     mapping = mapping, data = data,
#'     geom = geom, stat = StatKmeans, position = position,
#'     show.legend = show.legend, inherit.aes = inherit.aes,
#'     params = list(na.rm = na.rm, k = k, ...)
#'   )
#' }
#'
#' # Use new stat in plot
#' ggplot(mpg, aes(displ, hwy)) +
#'   stat_kmeans(k = 3)
```
**File:** R/stat-.R (L188-223)
```r
  compute_layer = function(self, data, params, layout) {
    check_required_aesthetics(
      self$required_aes,
      c(names(data), names(params)),
      snake_class(self)
    )

    # TODO: for symmetry with Geom, should Stat have separate `handle_na()` method?
    # Make sure required_aes consists of the used set of aesthetics in case of
    # "|" notation in self$required_aes
    required_aes <- intersect(
      names(data),
      unlist(strsplit(self$required_aes, "|", fixed = TRUE))
    )

    data <- remove_missing(data, params$na.rm,
      c(required_aes, self$non_missing_aes),
      snake_class(self),
      finite = TRUE
    )

    # Trim off extra parameters
    params <- params[intersect(names(params), self$parameters())]

    args <- c(list(data = quote(data), scales = quote(scales)), params)
    dapply(data, "PANEL", function(data) {
      scales <- layout$get_scales(data$PANEL[1])
      try_fetch(
        inject(self$compute_panel(data = data, scales = scales, !!!params)),
        error = function(cnd) {
          cli::cli_warn("Computation failed in {.fn {snake_class(self)}}.", parent = cnd)
          data_frame0()
        }
      )
    })
  },
```
**File:** R/legend-draw.R (L1-39)
```r
#' Key glyphs for legends
#'
#' Each geom has an associated function that draws the key when the geom needs
#' to be displayed in a legend. These functions are called `draw_key_*()`, where
#' `*` stands for the name of the respective key glyph. The key glyphs can be
#' customized for individual geoms by providing a geom with the `key_glyph`
#' argument (see [`layer()`] or examples below.)
#'
#' @return A grid grob.
#' @param data A single row data frame containing the scaled aesthetics to
#'   display in this key
#' @param params A list of additional parameters supplied to the geom.
#' @param size Width and height of key in mm.
#' @examples
#' p <- ggplot(economics, aes(date, psavert, color = "savings rate"))
#' # key glyphs can be specified by their name
#' p + geom_line(key_glyph = "timeseries")
#'
#' # key glyphs can be specified via their drawing function
#' p + geom_line(key_glyph = draw_key_rect)
#' @name draw_key
NULL

#' @export
#' @rdname draw_key
draw_key_point <- function(data, params, size) {
  data$shape <- translate_shape_string(data$shape %||% 19)

  # NULL means the default stroke size, and NA means no stroke.
  pointsGrob(0.5, 0.5,
    pch = data$shape,
    gp = gg_par(
      col = alpha(data$colour %||% "black", data$alpha),
      fill = fill_alpha(data$fill %||% "black", data$alpha),
      pointsize = data$size %||% 1.5,
      stroke = data$stroke %||% 0.5
    )
  )
}
```