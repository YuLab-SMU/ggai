# 手把手教你创建一个像 ggtree 一样的 ggplot2 扩展包

ggtree 的核心架构可以用以下图来概括：

```mermaid
graph TD
    "用户自定义数据对象\n(如 phylo, treedata)" --> "Step 1: fortify() 方法\n将对象转为 data.frame"
    "Step 1: fortify() 方法\n将对象转为 data.frame" --> "Step 2: ggplot() 调用\n（使用转化后的 data.frame）"
    "Step 2: ggplot() 调用\n（使用转化后的 data.frame）" --> "Step 3: 自定义 Stat (ggproto)\n对数据进行统计变换"
    "Step 3: 自定义 Stat (ggproto)\n对数据进行统计变换" --> "Step 4: 自定义 Geom (ggproto)\n绘制几何图层"
    "Step 2: ggplot() 调用\n（使用转化后的 data.frame）" --> "Step 5: 主入口函数\n(如 ggtree())"
    "Step 5: 主入口函数\n(如 ggtree())" --> "Step 6: 自定义 geom_xxx() 函数\n返回带 class 的 list 对象"
    "Step 6: 自定义 geom_xxx() 函数\n返回带 class 的 list 对象" --> "Step 7: ggplot_add() S3 方法\n响应 + 操作符"
    "Step 8: 自定义主题 theme_xxx()" --> "Step 5: 主入口函数\n(如 ggtree())"
    "Step 9: 自定义操作符\n(如 %<+%, %+>%)" --> "附加数据到图对象"
```

---

## 第一步：建立包结构与 DESCRIPTION 文件

首先，用 `usethis::create_package("mypkg")` 建立包骨架，然后编辑 `DESCRIPTION`，声明对 `ggplot2` 的依赖：

ggtree 的 `DESCRIPTION` 如下声明依赖关系： [1](#0-0) 

**关键点：**
- `Imports` 中必须有 `ggplot2`
- `ggplot2 (> 3.3.6)` 这样指定最低版本

---

## 第二步：为自定义数据对象实现 `fortify()` 方法

`fortify()` 是 ggplot2 扩展的**第一个关键接口**。它负责把你的自定义对象（如 `phylo`）转换成 ggplot2 可以理解的 `data.frame`。ggtree 为 `phylo` 对象实现了 `fortify.phylo`： [2](#0-1) 

**关键点：**
- 方法命名规则：`fortify.你的类名`
- 必须在 `NAMESPACE` 中注册：`S3method(fortify, phylo)`
- 返回的 `data.frame` 里必须包含 `x`, `y` 列，供 ggplot2 的 `aes()` 使用
- 可以用 `attr(res, "layout") <- layout` 把元信息挂到 data.frame 上 [3](#0-2) 

对于其他类型（如 `hclust`, `dendrogram`），只需复用同一个内部函数： [4](#0-3) 

---

## 第三步：用 `ggproto` 创建自定义 Stat

`Stat` 负责在绘图时对数据做变换（比如计算树枝的起止坐标）。这是 ggplot2 扩展的**第二个关键接口**。

ggtree 为矩形布局的树定义了 `StatTreeHorizontal` 和 `StatTreeVertical`： [5](#0-4) 

**关键点：**
- 用 `ggproto("MyStatName", Stat, ...)` 创建
- 必须声明 `required_aes`，指定哪些 aesthetic 是必须的
- 主要重写 `compute_panel` 方法（作用于整个面板）或 `compute_group`（作用于每个分组）
- `compute_panel` 接收 `data`, `scales`, `params`，返回变换后的 `data.frame`

---

## 第四步：用 `ggproto` 创建自定义 Geom（可选）

如果标准 `Geom`（如 `GeomSegment`）满足不了需求，就自定义一个。ggtree 定义了 `GeomHilightRect`： [6](#0-5) 

**关键点：**
- 用 `ggproto("MyGeomName", Geom, ...)` 创建
- 需要定义 `default_aes`、`draw_panel` 或 `draw_group` 方法
- 很多时候直接用现有的 `GeomSegment`、`GeomPoint` 传给 `layer()` 的 `geom=` 参数即可，**不必总是新建 Geom**

---

## 第五步：创建包的主入口函数

主入口函数（如 `ggtree()`）是用户最直接调用的函数。它的核心逻辑是：
1. 调用 `ggplot(你的对象, ...)` → 内部会自动触发 `fortify()` 方法
2. 叠加自定义 geom 图层
3. 叠加默认主题
4. **给返回的对象打上自定义类名**，以便后续 S3 方法分发 [7](#0-6) 

尤其注意最后给对象打上类名这一步： [8](#0-7) 

---

## 第六步：创建"惰性"geom 函数 + `ggplot_add` 方法

这是 ggtree 最精妙的设计。它让 `geom_tiplab()`, `geom_hilight()` 这类函数**不直接返回 ggplot2 图层**，而是返回一个带自定义 `class` 的 `list`：

以 `geom_tiplab` 为例： [9](#0-8) 

以 `geom_hilight` 为例： [10](#0-9) 

然后，为这些自定义类实现 `ggplot_add` S3 方法。当用户写 `p + geom_tiplab()` 时，ggplot2 会调用 `ggplot_add.tiplab()`，在这里你可以拿到**当前的 plot 对象**（`plot` 参数），读取它的数据、layout 等信息，再动态决定添加什么样的图层： [11](#0-10) 

类似地，布局切换函数也用这个机制： [12](#0-11) 

**这些 S3 方法都必须在 `NAMESPACE` 中注册**： [13](#0-12) 

---

## 第七步：创建"布局对象"模式

ggtree 中的 `layout_circular()`, `layout_fan()` 等函数都遵循同一个模式：返回一个带 `class = 'layout_ggtree'` 的 `structure`，然后用 `ggplot_add.layout_ggtree` 统一处理： [14](#0-13) 

这样设计的好处是：**所有布局控制都是 `+` 可组合的**，完全符合 ggplot2 语法习惯。

---

## 第八步：创建自定义 Theme

主题只需用 `theme_bw()` 或 `theme_void()` 作为基础，用 `+` 叠加 `theme()` 调整细节： [15](#0-14) 

**关键点：** 主题函数可以直接返回一个 `list`（包含多个 ggplot2 对象），ggplot2 会自动逐一添加它们。

---

## 第九步：创建自定义操作符（可选）

ggtree 定义了 `%<+%`（附加注释数据）、`%+>%`（附加数据并同步树信息）等自定义中缀操作符： [16](#0-15) [17](#0-16) 

---

## 第十步：管理 NAMESPACE 和 re-exports

通过 `reexports.R` 把常用的 ggplot2 函数重新导出，让用户只需 `library(你的包)` 就能直接用 `aes()`, `ggplot()` 等： [18](#0-17) 

---

## 完整架构总结

| 步骤 | 文件/函数 | ggplot2 接口 |
|------|-----------|-------------|
| 1 | `DESCRIPTION` | `Imports: ggplot2` |
| 2 | `method-fortify.R` → `fortify.phylo` | `ggplot2::fortify` S3 方法 |
| 3 | `geom_tree.R` → `StatTreeHorizontal` | `ggproto("...", Stat)` |
| 4 | `geom_hilight.R` → `GeomHilightRect` | `ggproto("...", Geom)` |
| 5 | `ggtree.R` → `ggtree()` | `ggplot()` + 赋 `class` |
| 6 | `geom_tiplab.R` → 返回 `class="tiplab"` list | 惰性对象 |
| 7 | `method-ggplot-add.R` → `ggplot_add.tiplab` | `ggplot2::ggplot_add` S3 方法 |
| 8 | `layout.R` → `layout_ggtree()` | 同上，`class="layout_ggtree"` |
| 9 | `theme.R` → `theme_tree()` | `ggplot2::theme` 组合 |
| 10 | `operator.R` → `%<+%` | 自定义中缀操作符 |
| 11 | `reexports.R` | `@importFrom` + `@export` |

---

## Notes

1. **最核心的设计模式** 是"惰性对象 + `ggplot_add`"（第六、七步）。普通 ggplot2 扩展只需返回 `layer()`，但 ggtree 需要在 `+` 的时候读取当前图的 layout 等状态，因此改为返回带 class 的 list，再用 `ggplot_add` 方法处理。这是与普通 ggplot2 扩展的最大区别。

2. **`fortify()` 方法** 是让 `ggplot(你的对象)` 能工作的关键。ggplot2 在处理非 data.frame 数据时，会自动调用 `fortify()`。

3. **`ggproto` 的继承机制**：子类可以通过 `inherit = ParentStat` 复用父类逻辑，如 `StatTreeEllipse` 就在内部调用了 `StatTree$compute_panel`。 [19](#0-18) 

4. **`plot_env`（plot 环境变量）**：ggtree 把 `layout`、`mrsd` 等状态存储在 `plot$plot_env` 里，这是一种在多次 `+` 操作间传递状态的技巧，不属于标准 ggplot2 接口，属于 ggtree 的特有设计。 [20](#0-19)

### Citations

**File:** DESCRIPTION (L22-43)
```text
Depends:
    R (>= 3.5.0)
Imports:
    ape,
    aplot,
    dplyr,
    ggplot2 (> 3.3.6),
    grid,
    magrittr,
    methods,
    purrr,
    rlang,
    ggfun (>= 0.1.7),
    yulab.utils (>= 0.1.6),
    tidyr,
    tidytree (>= 0.4.5),
    treeio (>= 1.8.0),
    utils,
    scales,
    stats,
    cli
Suggests:
```

**File:** R/method-fortify.R (L7-75)
```r
##' @method fortify phylo
##' @export
fortify.phylo <- function(model, data,
                          layout        = "rectangular",
                          ladderize     = TRUE,
                          right         = FALSE,
                          branch.length = "branch.length",
                          mrsd          = NULL,
                          as.Date       = FALSE,
                          yscale        = "none",
                          root.position = 0,
                          ...) {

    x <- as.phylo(model) ## reorder.phylo(get.tree(model), "postorder")
    if (ladderize == TRUE) {
        x <- ladderize(x, right=right)
    }

    if (! is.null(x$edge.length)) {
        if (anyNA(x$edge.length)) {
            warning("'edge.length' contains NA values...\n## setting 'edge.length' to NULL automatically when plotting the tree...")
            x$edge.length <- NULL
        }
    }

    if (layout %in% c("equal_angle", "daylight", "ape")) {
        res <- layout.unrooted(model, layout.method = layout, branch.length = branch.length, ...)
    } else {
        ypos <- getYcoord(x)
        N <- Nnode(x, internal.only=FALSE)
        if (is.null(x$edge.length) || branch.length == "none") {
            if (layout == 'slanted'){
                sbp <- .convert_tips2ancestors_sbp(x, include.root = TRUE)
                xpos <- getXcoord_no_length_slanted(sbp)
                ypos <- getYcoord_no_length_slanted(sbp)  
            }else{
                xpos <- getXcoord_no_length(x)
            }
        } else {
            xpos <- getXcoord(x)
        }

        xypos <- tibble::tibble(node=1:N, x=xpos + root.position, y=ypos)

        df <- as_tibble(model) %>%
            mutate(isTip = ! .data$node %in% .data$parent)

        res <- full_join(df, xypos, by = "node")
    }

    ## add branch mid position
    res <- calculate_branch_mid(res, layout=layout)

    if (!is.null(mrsd)) {
        res <- scaleX_by_time_from_mrsd(res, mrsd, as.Date)
    }

    if (layout == "slanted") {
        res <- add_angle_slanted(res)
    } else {
        ## angle for all layout, if 'rectangular', user use coord_polar, can still use angle
        res <- calculate_angle(res)
    }
    res <- scaleY(as.phylo(model), res, yscale, layout, ...)
    res <- adjust_hclust_tip.edge.len(res, x, layout, branch.length)
    class(res) <- c("tbl_tree", class(res))
    attr(res, "layout") <- layout
    return(res)
}
```

**File:** R/method-fortify.R (L157-166)
```r
##' @method fortify hclust
##' @export
fortify.hclust <- fortify.phylo4

## `phylogram::as.phylo` (for `dendrogram`).

##' @method fortify dendrogram
##' @export
fortify.dendrogram <- fortify.phylo4

```

**File:** R/geom_tree.R (L157-228)
```r
StatTreeHorizontal <- ggproto("StatTreeHorizontal", Stat,
                              required_aes = c("node", "parent", "x", "y"),
                              compute_group = function(data, params) {
                                data
                              },
                              compute_panel = function(self, data, scales, params, layout, lineend,
                                                       continuous = "none", rootnode = TRUE, 
                                                       nsplit = 100, extend=0.002) {
                                  data <- rename_linewidth(data)
                                  .fun <- function(data) {
                                      df <- setup_tree_data(data)
                                      x <- df$x
                                      y <- df$y
                                      df$xend <- x
                                      df$yend <- y
                                      ii <- with(df, match(parent, node))
                                      df$x <- x[ii]

                                      if (!rootnode) {
                                          ## introduce this paramete in v=1.7.4
                                          ## rootnode = TRUE which behave as previous versions.
                                          ## and has advantage of the number of line segments is consistent with tree nodes.
                                          ## i.e. every node has its own line segment, even for root.
                                          ## if rootnode = FALSE, the root to itself line segment will be removed.

                                          df <- dplyr::filter(df, .data$node != .rootnode.tbl_tree(df)$node)
                                      }
                                      if (continuous != "none") {
                                          # using ggnewscale new_scale("color") for multiple color scales
                                          if (length(grep("colour_new", names(df)))==1 && !"colour" %in% names(df)){
                                              names(df)[grep("colour_new", names(df))] <- "colour"
                                          }
                                          if (!is.null(df$colour)){
                                              if (any(is.na(df$colour))){
                                                  df$colour[is.na(df$colour)] <- 0
                                              }
                                              df$col2 <- df$colour
                                              df$col <- df$col2[ii]
                                          }
                                          # using ggnewscale new_scale("size") for multiple size scales
                                          if (length(grep("size_new", names(df)))==1 && !"size" %in% names(df)){
                                              names(df)[grep("size_new", names(df))] <- "size"
                                          }
                                          if (!is.null(df$size)){
                                              if (any(is.na(df$size))){
                                                  df$size[is.na(df$size)] <- 0
                                              }
                                              df$size2 <- df$size
                                              df$size1 <- df$size2[ii]
                                          }
                                          setup_data_continuous_color_size_tree(df, nsplit = nsplit, extend = extend, continuous = continuous)
                                      } else {
                                          return(df)
                                      }
                                  }
                                  if ('.id' %in% names(data)) {
                                      ldf <- split(data, data$.id)
                                      df <- do.call(rbind, lapply(ldf, .fun))
                                  } else {
                                      df <- .fun(data)
                                  }
                                  # using ggnewscale new_scale for multiple color or size scales
                                  if (length(grep("colour_new", names(data)))==1 && continuous != "none"){
                                      names(df)[match("colour", names(df))] <- names(data)[grep("colour_new", names(data))] 
                                  }
                                  if (length(grep("size_new", names(data)))==1 && continuous != "none"){
                                      names(df)[match("size", names(df))] <- names(data)[grep("size_new", names(data))]
                                  }
                                  df <- rename_size(df)
                                  return(df)
                              }
                              )
```

**File:** R/geom_tree.R (L380-385)
```r
                               }
                               df <- StatTree$compute_panel(data = data, scales = scales, 
                                                            params = params, layout = layout, lineend = lineend,
                                                            continuous = continuous, nsplit = nsplit, 
                                                            extend = extend, rootnode = rootnode)
                               df <- df[!(df$x==df$xend & df$y==df$yend),]
```

**File:** R/geom_hilight.R (L84-98)
```r
geom_hilight <- function(data=NULL,
                         mapping=NULL,
                         node=NULL,
                         type="auto",
                         to.bottom=FALSE,
                          ...){
    params <- list(...)
    structure(list(data    = data,
                   mapping = mapping,
                   node    = node,
                   type    = type,
                   to.bottom = to.bottom,
                   params  = params),
              class = 'hilight')
}
```

**File:** R/geom_hilight.R (L125-123)
```r

```

**File:** R/ggtree.R (L54-162)
```r
ggtree <- function(tr,
                   mapping        = NULL,
                   layout         = "rectangular",
                   open.angle     = 0,
                   mrsd           = NULL,
                   as.Date        = FALSE,
                   yscale         = "none",
                   yscale_mapping = NULL,
                   ladderize      = TRUE,
                   right          = FALSE,
                   branch.length  = "branch.length",
                   root.position  = 0,
                   xlim = NULL,
                   layout.params = list(as.graph = TRUE),
                   hang = .1,
                   ...) {

    # Check if layout string is valid.
    trash <- try(silent = TRUE,
                 expr = {
                   layout %<>% match.arg(c("rectangular", "slanted", "fan", "circular", 'inward_circular',
                            "radial", "unrooted", "equal_angle", "daylight", "dendrogram",
                            "ape", "ellipse", "roundrect"))
                  }
             )

    dd <- .check.graph.layout(tr, trash, layout, layout.params)
    if (inherits(trash, "try-error") && !is.null(dd)){
        layout <- "rectangular"
    }

    if (layout == "unrooted") {
        layout <- "daylight"
        message('"daylight" method was used as default layout for unrooted tree.')
    }

    if(yscale != "none") {
        ## for 2d tree
        layout <- "slanted"
    }

    if (is.null(mapping)) {
        mapping <- aes_(~x, ~y)
    } else {
        mapping <- modifyList(aes_(~x, ~y), mapping)
    }

    p <- ggplot(tr,
                mapping       = mapping,
                layout        = layout,
                mrsd          = mrsd,
                as.Date       = as.Date,
                yscale        = yscale,
                yscale_mapping= yscale_mapping,
                ladderize     = ladderize,
                right         = right,
                branch.length = branch.length,
                root.position = root.position,
                hang          = hang,
                ...)

    if (!is.null(dd)){
        message_wrap("The tree object will be displayed with external layout function
                     since layout argument was specified the graph layout or other layout
                     function.")
        p$data <- dplyr::left_join(
                    p$data %>% select(-c("x", "y")), 
                    dd, 
                    by = "node"
        )
        layout <- "equal_angle"
    }

    if (is(tr, "multiPhylo")) {
        multiPhylo <- TRUE
    } else {
        multiPhylo <- FALSE
    }

    p <- p + geom_tree(layout=layout, multiPhylo=multiPhylo, ...)


    p <- p + theme_tree()

    if (layout == "circular" || layout == "radial") {
        p <- p + layout_circular()
    } else if (layout == 'inward_circular') {
        p <- p + layout_inward_circular(xlim = xlim)
    } else if (layout == "fan") {
        p <- p + layout_fan(open.angle)
    } else if (layout == "dendrogram") {
        p <- p + layout_dendrogram()
    } else if (layout %in% c("daylight", "equal_angle", "ape")) {
        p <- p + ggplot2::coord_fixed()
        d <- p$data
        pn <- d[d$parent, ]
        dy <- pn$y - d$y
        dx <- pn$x - d$x
        angle <- atan2(dy, dx) * 180 / pi + 180
        p$data$angle <- angle
    } else if (yscale == "none") {
        p <- p +
            scale_y_continuous(expand = expansion(0, 0.6))
    }

    class(p) <- c("ggtree", class(p))

    return(p)
}
```

**File:** R/geom_tiplab.R (L106-119)
```r
geom_tiplab <- function(mapping=NULL, hjust = 0,  align = FALSE, linetype = "dotted",
                        linesize=0.5, geom="text",  offset=0, as_ylab = FALSE, ...) {
    structure(list(mapping = mapping,
                   hjust = hjust,
                   align = align,
                   linetype = linetype,
                   linesize = linesize,
                   geom = geom,
                   offset = offset,
                   as_ylab = as_ylab,
				   node = "external",
                   ...),
              class = "tiplab")
}
```

**File:** R/method-ggplot-add.R (L93-122)
```r
##' @method ggplot_add layout_ggtree
##' @importFrom ggplot2 expansion
##' @export
ggplot_add.layout_ggtree <- function(object, plot, object_name) {
    if(object$layout == 'fan') {
        return(open_tree(plot, object$angle))
    }

    if (object$layout == 'dendrogram') {
        plot <- revts(plot)
        obj <- list(scale_x_reverse(labels = function(x){-x}),
                    coord_flip(clip = 'off')
                    )
    } else if (object$layout == 'circular' || object$layout == "inward_circular") {
        ## refer to: https://github.com/GuangchuangYu/ggtree/issues/6
        ## and also have some space for tree scale (legend)
        obj <- list(coord_polar(theta='y', start=-pi/2, -1, clip = 'off'),
                    scale_y_continuous(limits = c(0, NA), expand = expansion(0, 0.6))
                    )
        if (object$layout == 'inward_circular') {
            obj[[3]] <- scale_x_reverse(limits = object$xlim)
        }
    } else { ## rectangular
        obj <- coord_cartesian(clip = 'off')
    }
    plot <- ggplot_add(obj, plot, object_name)
    plot$plot_env <- build_new_plot_env(plot$plot_env)
    assign("layout", object$layout, envir = plot$plot_env)
    return(plot)
}
```

**File:** R/method-ggplot-add.R (L197-243)
```r
##' @method ggplot_add tiplab
##' @export
ggplot_add.tiplab <- function(object, plot, object_name) {
    layout <- get_layout(plot)
    if (layout == 'dendrogram'){
        if( object$hjust == 0 ){
            object$hjust = 1
        }
        if (!'vjust' %in% names(object)){
            object$vjust = .5
        }
        if (!'angle' %in% names(object)){
            object$angle = 90
        }
    }
    if (object$as_ylab) {
        if (layout != "rectangular" && layout != "dendrogram") {
            stop("displaying tiplab as y labels only supports rectangular layout")
        }
        ## remove parameters that are not useful
        fontsize <- object$size
        object$size <- 0
        object$as_ylab <- NULL
        ly <- do.call(geom_tiplab_rectangular, object)
        plot <- ggplot_add(ly, plot, object_name)
        object$size <- fontsize
        #object$mapping <- NULL
        object$align <- NULL
        object$linetype <- NULL
        object$linesize <- NULL
        #object$geom <- NULL
        object$offset <- NULL
        object$nodelab <- NULL
        res <- ggplot_add.tiplab_ylab(object, plot, object_name)
        return(res)
    }

    object$as_ylab <- NULL
    if (layout %in% c('circular', 'fan', "unrooted", 
                      "equal_angle", "daylight", "ape", "inward_circular")){
        ly <- do.call(geom_tiplab_circular, object)
    } else {
        #object$nodelab <- NULL
        ly <- do.call(geom_tiplab_rectangular, object)
    }
    ggplot_add(ly, plot, object_name)
}
```

**File:** NAMESPACE (L23-39)
```text
S3method(ggplot_add,cladelab)
S3method(ggplot_add,cladelabel)
S3method(ggplot_add,facet_plot)
S3method(ggplot_add,facet_xlim)
S3method(ggplot_add,geom_range)
S3method(ggplot_add,ggexpand)
S3method(ggplot_add,hilight)
S3method(ggplot_add,layout_ggtree)
S3method(ggplot_add,range_xaxis)
S3method(ggplot_add,scale_ggtree)
S3method(ggplot_add,striplab)
S3method(ggplot_add,striplabel)
S3method(ggplot_add,taxalink)
S3method(ggplot_add,tiplab)
S3method(ggplot_add,tiplab_ylab)
S3method(ggplot_add,tree_inset)
S3method(ggplot_add,zoom_clade)
```

**File:** R/layout.R (L130-133)
```r
layout_ggtree <- function(layout = 'rectangular', angle = 180, xlim = NULL) {
    structure(list(layout = layout, angle = angle, xlim = xlim),
              class = 'layout_ggtree')
}
```

**File:** R/theme.R (L20-35)
```r
theme_tree <- function(bgcolor="white", ...) {

    list(xlab(NULL),
         ylab(NULL),
         theme_tree2_internal() +
         theme(panel.background=element_rect(fill=bgcolor, colour=bgcolor),
               axis.line.x = element_blank(),
               axis.text.x = element_blank(),
               axis.ticks.x = element_blank(),
               ...)
         )
    
    ## theme_void() +
    ##     theme(panel.background=element_rect(fill=bgcolor, colour=bgcolor),
    ##           ...)
}
```

**File:** R/reexports.R (L1-12)
```r
#' @importFrom ggfun %<+%
#' @export
#' @examples
#' nwk <- system.file("extdata", "sample.nwk", package="treeio")
#' tree <- read.tree(nwk)
#' p <- ggtree(tree)
#' dd <- data.frame(taxa=LETTERS[1:13],
#'                    place=c(rep("GZ", 5), rep("HK", 3), rep("CZ", 4), NA),
#'              value=round(abs(rnorm(13, mean=70, sd=10)), digits=1))
#' row.names(dd) <- NULL
#' p %<+% dd + geom_text(aes(color=place, label=label), hjust=-0.5)
ggfun::`%<+%`
```

**File:** R/reexports.R (L63-86)
```r
#' @importFrom ggplot2 fortify
#' @export
ggplot2::fortify

#' @importFrom ggplot2 ggplot
#' @export
ggplot2::ggplot

##' @importFrom ggplot2 xlim
##' @export
ggplot2::xlim

##' @importFrom ggplot2 theme
##' @export
ggplot2::theme

##' @importFrom ggplot2 ggsave
##' @export
ggplot2::ggsave

##' @importFrom ggplot2 aes
##' @export
ggplot2::aes

```

**File:** R/operator.R (L117-145)
```r
`%+>%` <- function(p, .data) {
    df <- p$data
    lv <- levels(df$.panel)
    if (inherits(.data, "GRanges") || inherits(.data, "GRangesList")) {
        names(.data) <- df$y[match(names(.data), df$label)]
        res <- .data[order(as.numeric(names(.data)))]
        mcols <- get_fun_from_pkg("GenomicRanges", "mcols")
        `mcols<-` <- get_fun_from_pkg("GenomicRanges", "`mcols<-`")
        mcols(res)$.panel <- factor(lv[length(lv)], levels=lv)
    } else if (is(.data, "data.frame") || is(.data, "tbl_df")) {
        .data <- as.data.frame(.data)
        ## res <- merge(df[, c('label', 'y')], data, by.x='label', by.y=1) ## , all.x=TRUE)
        res <- merge(df[, !names(df) %in% c('node', 'parent', 'x', 'branch', 'angle')], .data, by.x='label', by.y=1)
        res[[".panel"]] <- factor(lv[length(lv)], levels=lv)
        res <- res[order(res$y),]
    } else if (is.function(.data)){
        res <- .data(df)
        if (!is.data.frame(res)){
            rlang::abort("Data function must return a data.frame")
        }
        res[[".panel"]] <- factor(lv[length(lv)], levels=lv)
        res %<>% dplyr::filter(.data$isTip)
        res <- res[order(res$y),]
    } else {
        stop("input 'data' is not supported...")
    }

    return(res)
}
```

**File:** R/utilities.R (L10-17)
```r
get_layout <- function(tree_view = NULL) {
    plot <- get_tree_view(tree_view)
    layout <- get("layout", envir = plot$plot_env)
    if (!is(layout, "character")) {
        layout <- attr(plot$data, "layout")
    }
    return(layout)
}
```
