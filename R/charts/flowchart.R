# 流程图 flowchart
#
# 自己排版的原因：mint 的图表区尺寸是已知的（英寸），因此可以在「真实英寸坐标系」里
# 做分层布局（rank = 最长路径分层，层内用重心法排序），再用 coord_fixed 精确铺满画布。
# 这样出来的图不会被外部布局引擎的默认边距糊掉，也不会出现节点被裁切。
#
# 布局参数全部以英寸为单位，字号以 pt 为单位 —— 和最终输出的物理尺寸一一对应。

MINT_FLOW_SHAPES <- c("rect", "round", "stadium", "diamond")

mint_register(mint_chart(
  id = "flowchart",
  name = "流程图",
  english = "Flowchart",
  category = "flow",
  description = "按分层自动排版的流程/状态流转图，支持矩形、圆角、胶囊与判断菱形",
  data_shape = paste(
    "{",
    "  \"nodes\": [",
    "    { \"id\": \"start\", \"label\": \"开始\", \"shape\": \"stadium\" },",
    "    { \"id\": \"check\", \"label\": \"风控通过？\", \"shape\": \"diamond\" },",
    "    { \"id\": \"pay\", \"label\": \"发起支付\" }",
    "  ],",
    "  \"edges\": [",
    "    { \"from\": \"start\", \"to\": \"check\" },",
    "    { \"from\": \"check\", \"to\": \"pay\", \"label\": \"是\" }",
    "  ]",
    "}",
    "shape 可取 rect（默认）/ round / stadium（开始结束）/ diamond（判断）。",
    sep = "\n"
  ),
  variants = c("layered 分层自动排版", "orthogonal 直角连线"),
  aliases = c("流程图", "流程", "状态图", "flow", "diagram"),
  packages = c("ggplot2", "ggforce", "scales"),
  # 布局是按英寸算的，limits 与画布尺寸一一对应：让 panel 铺满版心才是 1:1
  respect = FALSE,
  options = list(
    mint_option("direction", "string", "排版方向", default = "TB", values = c("TB", "LR")),
    mint_option("nodeHeight", "number", "节点高度（英寸）", default = 0.34),
    mint_option("rankGap", "number", "层间距（英寸）", default = 0.62),
    mint_option("siblingGap", "number", "同层节点间距（英寸）", default = 0.24),
    mint_option("edgeLabels", "boolean", "是否显示连线标签", default = TRUE),
    mint_option("labelWrap", "number", "节点文字折行宽度（字符，0 表示自动）", default = 0)
  ),
  example = list(
    data = list(
      nodes = list(
        list(id = "start", label = "提交申请", shape = "stadium"),
        list(id = "check", label = "资料齐全？", shape = "diamond"),
        list(id = "review", label = "人工复核"),
        list(id = "auto", label = "自动审批"),
        list(id = "done", label = "审批完成", shape = "stadium")
      ),
      edges = list(
        list(from = "start", to = "check"),
        list(from = "check", to = "review", label = "否"),
        list(from = "check", to = "auto", label = "是"),
        list(from = "review", to = "done"),
        list(from = "auto", to = "done")
      )
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_flow_model(ctx$data)
    font_size <- ctx$style$type$data_label
    layout <- mint_flow_layout(
      model,
      width = ctx$width,
      height = ctx$height,
      font_size = font_size,
      direction = o$direction %||% "TB",
      node_height = o$nodeHeight %||% 0.34,
      rank_gap = o$rankGap %||% 0.62,
      sibling_gap = o$siblingGap %||% 0.24,
      wrap_chars = o$labelWrap %||% 0
    )

    nodes <- layout$nodes
    edges <- layout$edges
    token <- ctx$style$tokens

    p <- ggplot2::ggplot()

    # 连线画在节点下面
    if (nrow(edges) > 0) {
      p <- p + ggplot2::geom_path(
        data = edges, ggplot2::aes(x = x, y = y, group = id),
        colour = "#7A7A7A", linewidth = 0.4, lineend = "round",
        arrow = ggplot2::arrow(length = grid::unit(1.7, "pt"), type = "closed"),
        show.legend = FALSE
      )
      if (!identical(o$edgeLabels, FALSE)) {
        labels <- edges[edges$has_label, , drop = FALSE]
        if (nrow(labels) > 0) {
          p <- p + ggplot2::geom_label(
            data = labels, ggplot2::aes(x = label_x, y = label_y, label = label),
            size = ctx$style$type$data_label / ggplot2::.pt,
            colour = token$text, fill = ctx$background, linewidth = 0,
            label.padding = grid::unit(0.06, "lines"), show.legend = FALSE
          )
        }
      }
    }

    # 节点
    rects <- nodes[nodes$shape %in% c("rect", "round", "stadium"), , drop = FALSE]
    if (nrow(rects) > 0) {
      p <- p + ggplot2::geom_rect(
        data = rects,
        ggplot2::aes(xmin = x - w / 2, xmax = x + w / 2, ymin = y - h / 2, ymax = y + h / 2),
        fill = "#F7F7F7", colour = token$axis, linewidth = 0.4
      )
    }
    diamonds <- nodes[nodes$shape == "diamond", , drop = FALSE]
    if (nrow(diamonds) > 0) {
      poly <- do.call(rbind, lapply(seq_len(nrow(diamonds)), function(i) {
        d <- diamonds[i, ]
        data.frame(
          id = d$id,
          x = c(d$x, d$x + d$w / 2, d$x, d$x - d$w / 2),
          y = c(d$y + d$h / 2, d$y, d$y - d$h / 2, d$y),
          stringsAsFactors = FALSE
        )
      }))
      p <- p + ggplot2::geom_polygon(
        data = poly, ggplot2::aes(x = x, y = y, group = id),
        fill = "#FFFFFF", colour = token$axis, linewidth = 0.4
      )
    }

    p <- p + ggplot2::geom_text(
      data = nodes, ggplot2::aes(x = x, y = y, label = label),
      size = font_size / ggplot2::.pt, colour = token$fg, lineheight = 1.12
    )

    p +
      ggplot2::scale_x_continuous(limits = c(0, ctx$width), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, ctx$height), expand = c(0, 0)) +
      ggplot2::coord_fixed(ratio = 1, clip = "off") +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
))

#' 归一化流程图数据
mint_flow_model <- function(data) {
  if (!is.list(data) || is.null(names(data))) {
    mint_fail("INVALID_DATA", "flowchart 需要对象数据，收到数组",
              "形如 { \"nodes\": [...], \"edges\": [...] }")
  }
  raw_nodes <- data$nodes
  if (is.null(raw_nodes) || length(raw_nodes) == 0) {
    mint_fail("INVALID_DATA", "flowchart 需要非空的 nodes 数组",
              "形如 { \"nodes\": [{ \"id\": \"start\", \"label\": \"开始\" }] }")
  }

  aliases <- c(box = "rect", process = "rect", rounded = "round", pill = "stadium",
               start = "stadium", end = "stadium", terminator = "stadium",
               decision = "diamond", condition = "diamond", branch = "diamond")

  ids <- character(0); labels <- character(0); shapes <- character(0)
  for (i in seq_along(raw_nodes)) {
    raw <- raw_nodes[[i]]
    if (is.character(raw) || is.numeric(raw)) {
      id <- as.character(raw); label <- id; shape <- "rect"
    } else if (is.list(raw)) {
      id <- as.character(raw$id %||% raw$name %||% raw$label %||% "")
      if (!nzchar(id)) mint_fail("INVALID_DATA", sprintf("nodes 第 %d 项缺少 id", i))
      label <- as.character(raw$label %||% raw$name %||% id)
      raw_shape <- tolower(as.character(raw$shape %||% raw$type %||% "rect"))
      shape <- if (raw_shape %in% MINT_FLOW_SHAPES) raw_shape else (aliases[[raw_shape]] %||% "rect")
    } else {
      mint_fail("INVALID_DATA", sprintf("nodes 第 %d 项必须是字符串或对象", i))
    }
    if (id %in% ids) mint_fail("INVALID_DATA", sprintf("节点 id 重复：%s", id), "每个节点需要唯一 id")
    ids <- c(ids, id); labels <- c(labels, label); shapes <- c(shapes, shape)
  }

  raw_edges <- data$edges %||% data$links %||% list()
  from <- character(0); to <- character(0); elabel <- character(0)
  for (i in seq_along(raw_edges)) {
    raw <- raw_edges[[i]]
    if (!is.list(raw)) mint_fail("INVALID_DATA", sprintf("edges 第 %d 项必须是对象", i))
    f <- raw$from %||% raw$source %||% raw$start
    t <- raw$to %||% raw$target %||% raw$end
    if (is.null(f) || is.null(t)) {
      mint_fail("INVALID_DATA", sprintf("edges 第 %d 项缺少 from / to", i),
                "形如 { \"from\": \"a\", \"to\": \"b\", \"label\": \"是\" }")
    }
    if (!as.character(f) %in% ids || !as.character(t) %in% ids) {
      mint_fail("INVALID_DATA",
                sprintf("edges 第 %d 项指向不存在的节点：%s → %s", i, as.character(f), as.character(t)),
                sprintf("可用节点：%s", paste(ids, collapse = ", ")))
    }
    from <- c(from, as.character(f)); to <- c(to, as.character(t))
    elabel <- c(elabel, if (is.null(raw$label)) "" else as.character(raw$label))
  }

  list(
    nodes = data.frame(id = ids, label = labels, shape = shapes, stringsAsFactors = FALSE),
    edges = data.frame(from = from, to = to, label = elabel, stringsAsFactors = FALSE)
  )
}

#' 分层 + 层内排序 + 英寸坐标
mint_flow_layout <- function(model, width, height, font_size,
                             direction = "TB", node_height = 0.34,
                             rank_gap = 0.62, sibling_gap = 0.24, wrap_chars = 0) {
  nodes <- model$nodes
  edges <- model$edges
  n <- nrow(nodes)
  index <- stats::setNames(seq_len(n), nodes$id)
  horizontal <- identical(direction, "LR")

  # ── 分层：最长路径。有环时最多迭代 n 轮，保证能停下来
  rank <- rep(0L, n)
  if (nrow(edges) > 0) {
    for (iter in seq_len(n)) {
      changed <- FALSE
      for (k in seq_len(nrow(edges))) {
        i <- index[[edges$from[k]]]; j <- index[[edges$to[k]]]
        if (rank[i] < n && rank[j] < rank[i] + 1L) {
          rank[j] <- rank[i] + 1L
          changed <- TRUE
        }
      }
      if (!changed) break
    }
  }
  nodes$rank <- rank

  # ── 宽度预算 → 标签折行 → 节点尺寸
  max_per_rank <- max(table(rank))
  cross_span <- if (horizontal) height else width
  budget <- max(0.5, (cross_span - (max_per_rank - 1) * sibling_gap) / max_per_rank)
  chars <- if (wrap_chars > 0) wrap_chars else max(4, floor(budget * 72 / (font_size * 1.05)))

  labels <- vapply(nodes$label, function(text) {
    mint_wrap(text, max_width = chars * font_size, size = font_size)
  }, character(1), USE.NAMES = FALSE)
  lines <- strsplit(labels, "\n", fixed = TRUE)
  text_pt <- vapply(lines, function(part) max(mint_text_width(part, font_size)), numeric(1))

  nodes$label <- labels
  base_w <- pmin(budget, pmax(0.5, text_pt / 72 + 0.2))
  base_h <- pmax(node_height, 0.16 + vapply(lines, length, integer(1)) * font_size * 1.2 / 72)
  is_diamond <- nodes$shape == "diamond"
  nodes$w <- ifelse(is_diamond, pmax(base_w * 1.3, base_h * 1.7), base_w)
  nodes$h <- ifelse(is_diamond, pmax(base_h, base_w * 0.66), base_h)

  # ── 层内排序：重心法，减少连线交叉
  nodes$pos <- 0L
  for (r in unique(rank)) nodes$pos[nodes$rank == r] <- seq_len(sum(nodes$rank == r))
  if (nrow(edges) > 0) {
    for (pass in seq_len(4)) {
      for (r in sort(unique(nodes$rank))) {
        members <- which(nodes$rank == r)
        if (length(members) <= 1) next
        bary <- vapply(members, function(i) {
          id <- nodes$id[i]
          neighbours <- c(edges$from[edges$to == id], edges$to[edges$from == id])
          if (length(neighbours) == 0) return(nodes$pos[i])
          mean(nodes$pos[match(neighbours, nodes$id)], na.rm = TRUE)
        }, numeric(1))
        nodes$pos[members[order(bary, members)]] <- seq_along(members)
      }
    }
  }
  nodes <- nodes[order(nodes$rank, nodes$pos), , drop = FALSE]
  rownames(nodes) <- NULL

  # ── 主方向（分层）坐标：整体在画布中居中，溢出版心时给出可操作提示
  rank_ids <- sort(unique(nodes$rank))
  rank_extent <- vapply(rank_ids, function(r) {
    members <- nodes$rank == r
    if (horizontal) max(nodes$w[members]) else max(nodes$h[members])
  }, numeric(1))
  main_span <- if (horizontal) width else height
  content_main <- sum(rank_extent) + (length(rank_ids) - 1) * rank_gap

  if (content_main > main_span + 1e-6) {
    mint_fail("CANVAS_TOO_SMALL",
              sprintf("流程图在%s方向需要 %.2f in，画布只有 %.2f in",
                      if (horizontal) "横向" else "纵向", content_main, main_span),
              if (horizontal) "调大 --width，或减少流程图的层数" else "调大 --height，或减少流程图的层数")
  }
  main_offset <- (main_span - content_main) / 2

  # ── 次方向：把富余宽度摊进同层节点的间距（有上限），避免宽画布上两头空
  widest <- max(vapply(rank_ids, function(r) {
    members <- nodes$rank == r
    sum(if (horizontal) nodes$h[members] else nodes$w[members]) + (length(members) - 1) * sibling_gap
  }, numeric(1)))
  spare <- cross_span - widest
  pair_gap <- sibling_gap + if (max_per_rank > 1) min(max(0, spare) / (max_per_rank - 1), 0.9) else 0

  nodes$x <- 0; nodes$y <- 0
  cursor <- main_offset
  for (k in seq_along(rank_ids)) {
    r <- rank_ids[[k]]
    members <- which(nodes$rank == r)
    sizes <- if (horizontal) nodes$h[members] else nodes$w[members]
    total <- sum(sizes) + (length(members) - 1) * pair_gap
    across <- max(0, (cross_span - total) / 2)
    for (m in members) {
      size <- if (horizontal) nodes$h[m] else nodes$w[m]
      center_across <- across + size / 2
      center_main <- cursor + rank_extent[k] / 2
      if (horizontal) {
        nodes$x[m] <- center_main
        nodes$y[m] <- cross_span - center_across
      } else {
        nodes$x[m] <- center_across
        nodes$y[m] <- main_span - center_main
      }
      across <- across + size + pair_gap
    }
    cursor <- cursor + rank_extent[k] + rank_gap
  }

  list(nodes = nodes, edges = mint_flow_edge_paths(nodes, edges, horizontal))
}

#' 直角连线：源节点 → 中继 → 目标节点，三段折线
mint_flow_edge_paths <- function(nodes, edges, horizontal) {
  if (nrow(edges) == 0) {
    return(data.frame(x = numeric(0), y = numeric(0), id = character(0),
                      label = character(0), label_x = numeric(0), label_y = numeric(0),
                      has_label = logical(0), stringsAsFactors = FALSE))
  }
  index <- stats::setNames(seq_len(nrow(nodes)), nodes$id)
  out <- list()
  for (k in seq_len(nrow(edges))) {
    i <- index[[edges$from[k]]]; j <- index[[edges$to[k]]]
    a <- nodes[i, ]; b <- nodes[j, ]
    offset <- 0.06 * ((k - 1) %% 3)

    if (horizontal) {
      x0 <- a$x + a$w / 2; y0 <- a$y
      x1 <- b$x - b$w / 2; y1 <- b$y
      mid <- (x0 + x1) / 2 + offset
      xs <- c(x0, mid, mid, x1)
      ys <- c(y0, y0, y1, y1)
      label_x <- mid; label_y <- (y0 + y1) / 2
    } else {
      x0 <- a$x; y0 <- a$y - a$h / 2
      x1 <- b$x; y1 <- b$y + b$h / 2
      if (identical(a$id, b$id)) {
        # 自环：从右侧绕一圈
        xs <- c(x0 + a$w / 2, x0 + a$w / 2 + 0.22, x0 + a$w / 2 + 0.22, x0 + a$w / 2)
        ys <- c(y0, y0, y0 - 0.18, y0 - 0.18)
        label_x <- x0 + a$w / 2 + 0.24; label_y <- y0 - 0.09
      } else {
        mid <- (y0 + y1) / 2 + offset
        xs <- c(x0, x0, x1, x1)
        ys <- c(y0, mid, mid, y1)
        label_x <- (x0 + x1) / 2
        label_y <- mid
      }
    }

    out[[length(out) + 1L]] <- data.frame(
      x = xs, y = ys, id = sprintf("edge-%d", k),
      label = edges$label[k], label_x = label_x, label_y = label_y,
      has_label = nzchar(edges$label[k]), stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}
