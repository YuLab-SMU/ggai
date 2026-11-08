# Tag-every-leaf-grob helper on top of ggiraph's dsvg tracer (uses ggiraph INTERNALS:
# set_tracer_on / collect_id / set_tracer_off / add_attribute; not exported API).
suppressPackageStartupMessages({ library(grid); library(ggiraph); library(xml2) })

.ggai <- new.env()
.ggai$log <- list()

# expected primitive count for a leaf grob (what we'd have to *guess* without tracing)
expected_n <- function(x) {
  n_id <- function(id, idl, default = 1L) {
    if (!is.null(id)) length(unique(id)) else if (!is.null(idl)) length(idl) else default
  }
  if (inherits(x, "points")) return(length(x$x))
  if (inherits(x, "text")) return(length(x$label))
  if (inherits(x, "rect")) return(max(length(x$x), length(x$y), length(x$width), length(x$height)))
  if (inherits(x, "segments")) return(max(length(x$x0), length(x$y0), length(x$x1), length(x$y1)))
  if (inherits(x, "polyline") || inherits(x, "polygon")) return(n_id(x$id, x$id.lengths))
  if (inherits(x, "pathgrob")) return(if (!is.null(x$pathId)) length(unique(x$pathId)) else 1L)
  if (inherits(x, "circle")) return(max(length(x$x), length(x$y), length(x$r)))
  NA_integer_
}

drawDetails.ggai_tagged <- function(x, recording) {
  dn <- as.integer(dev.cur() - 1L)
  on <- .Device == "dsvg_device"
  if (on) ggiraph:::set_tracer_on(dn)
  NextMethod()
  ids <- integer(0)
  if (on) {
    ids <- ggiraph:::collect_id(dn)
    ggiraph:::set_tracer_off(dn)
    if (length(ids)) {
      ggiraph:::add_attribute(dn, "data-ggai-path", ids, rep(x$.ggai_path, length(ids)))
      ggiraph:::add_attribute(dn, "data-ggai-i", ids, as.character(seq_along(ids)))
      ggiraph:::add_attribute(dn, "data-ggai-class", ids, rep(class(x)[2], length(ids)))
      vpp <- current.vpPath(); vps <- if (is.null(vpp)) "ROOT" else as.character(vpp)
      ggiraph:::add_attribute(dn, "data-ggai-vp", ids, rep(vps, length(ids)))
    }
  }
  .ggai$log[[length(.ggai$log) + 1]] <- data.frame(
    path = x$.ggai_path, class = class(x)[2], expected = expected_n(x),
    emitted = length(ids), stringsAsFactors = FALSE)
  invisible()
}
registerS3method("drawDetails", "ggai_tagged", drawDetails.ggai_tagged, envir = asNamespace("grid"))

# walk a *forced* grob tree; tag every non-gTree grob with its child-index path
tag_tree <- function(g, path = "") {
  if (inherits(g, "gTree")) {
    ord <- g$childrenOrder
    for (i in seq_along(ord)) {
      nm <- ord[i]
      g$children[[nm]] <- tag_tree(g$children[[nm]], paste0(path, "/", nm))
    }
    return(g)
  }
  if (is.grob(g) && !inherits(g, c("zeroGrob", "null"))) {
    g$.ggai_path <- path
    class(g) <- c("ggai_tagged", class(g))
  }
  g
}

# render a grob (or plotting code) to dsvg with everything tagged
render_tagged <- function(grob, file, width = 7, height = 4) {
  .ggai$log <- list()
  dsvg(file, width = width, height = height, canvas_id = "svg_ggai")
  grid.newpage()
  f <- grid.force(grob)
  tagged <- tag_tree(f)
  grid.draw(tagged)
  dev.off()
  log <- do.call(rbind, .ggai$log)
  doc <- read_xml(file)
  prim <- xml_find_all(doc, "//*[local-name()='g' and @id='svg_ggai_rootg']//*[local-name()='circle' or local-name()='path' or local-name()='polyline' or local-name()='polygon' or local-name()='rect' or local-name()='text' or local-name()='line' or local-name()='image']")
  list(doc = doc, prim = prim, log = log)
}

summarise_tagged <- function(res, label) {
  prim <- res$prim
  tagged <- !is.na(xml_attr(prim, "data-ggai-path"))
  cat(sprintf("[%s] primitives in rootg: %d; with data-ggai-path: %d; with id: %d\n",
              label, length(prim), sum(tagged), sum(!is.na(xml_attr(prim, "id")))))
  print(table(tag = xml_name(prim), tagged = tagged))
  lg <- res$log
  cat(sprintf("[%s] leaf grobs drawn: %d; leaves emitting 0 elements: %d; expected!=emitted: %d\n",
              label, nrow(lg), sum(lg$emitted == 0), sum(!is.na(lg$expected) & lg$expected != lg$emitted)))
  invisible(lg)
}
