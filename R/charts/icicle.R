# 冰柱图 icicle
#
# 层级用「宽度」表达占比，一层一条带子：每个节点的矩形横跨它所有子孙的宽度区间，
# 所以越往下越细，一眼能看出是哪一层在吃掉预算。
# 相比旭日图，冰柱图的文字可以水平排（沿带子从左往右写），中文标签的可读性好得多。
#
# 排版上的克制：
#   * 每一层等高，层间只留一道背景色细缝，不画任何刻度线；
#   * 同一父色下按序取深浅，顶层用调色板主色，最大的块最饱和；
#   * 根节点用中性浅灰：它是「整体」，不该跟任何一个分组抢颜色；
#   * 名字写在块左侧，按 mint_text_width 判断放不放得下，放不下就留空。

# 层级数据归一化：兼容 { name, children } / [ { name, value } ] / [ { path, value } ]
mint_icicle_model <- function(data, root = "总计") {
  norm <- function(raw, depth) {
    if (!is.list(raw) || is.null(names(raw))) {
      mint_fail("INVALID_DATA", sprintf("层级结构第 %d 层不是对象", depth),
                "每个节点形如 { \"name\": \"华东\", \"value\": 320 } 或 { \"name\": \"线上\", \"children\": [...] }")
    }
    name <- as.character(mint_field(raw, c("name", "id", "label"), ""))[1]
    if (is.na(name) || !nzchar(name)) name <- sprintf("层级 %d", depth)

    kids_raw <- raw$children
    if (is.list(kids_raw) && length(kids_raw) > 0) {
      kids <- lapply(kids_raw, norm, depth = depth + 1L)
      kids <- Filter(function(k) !is.null(k), kids)
      if (length(kids) == 0) return(NULL)
      total <- sum(vapply(kids, function(k) k$value, numeric(1)))
      if (!is.finite(total) || total <= 0) return(NULL)
      # 同级按值降序：带子从左到右就是从大到小，颜色深浅也跟着面积走
      kids <- kids[order(-vapply(kids, function(k) k$value, numeric(1)))]
      return(list(name = name, value = total, children = kids, depth = depth))
    }

    value <- raw$value
    if (!is.numeric(value) || length(value) != 1 || !is.finite(value) || value <= 0) return(NULL)
    list(name = name, value = as.numeric(value), children = NULL, depth = depth)
  }

  if (is.list(data) && !is.null(names(data))) {
    if (is.list(data$children) && length(data$children) > 0) return(norm(data, 1L))
    if (!is.null(data$name) && is.numeric(data$value)) return(norm(data, 1L))
  }

  if (is.list(data) && is.null(names(data)) && length(data) > 0) {
    rows <- data
    objects <- all(vapply(rows, function(r) is.list(r) && !is.null(names(r)), logical(1)))
    if (objects) {
      has_path <- all(vapply(rows, function(r) is.character(r$path) && length(r$path) == 1, logical(1)))
      has_name <- all(vapply(rows, function(r) is.character(r$name) && length(r$name) == 1, logical(1)))
      if (has_path || has_name) {
        insert <- function(node, segs, value) {
          if (length(segs) == 0) {
            node$value <- value
            return(node)
          }
          idx <- NA_integer_
          for (i in seq_along(node$children)) {
            if (identical(node$children[[i]]$name, segs[1])) { idx <- i; break }
          }
          if (is.na(idx)) {
            node$children[[length(node$children) + 1L]] <- list(name = segs[1], value = 0, children = list())
            idx <- length(node$children)
          }
          node$children[[idx]] <- insert(node$children[[idx]], segs[-1], value)
          node
        }
        tree <- list(name = as.character(root)[1], value = 0, children = list())
        for (row in rows) {
          raw <- as.character(if (has_path) row$path else row$name)[1]
          value <- row$value
          if (!is.numeric(value) || length(value) != 1 || !is.finite(value)) value <- 1
          segs <- trimws(if (has_path) strsplit(raw, "/", fixed = TRUE)[[1]] else raw)
          segs <- segs[nzchar(segs)]
          if (length(segs) == 0) next
          tree <- insert(tree, segs, as.numeric(value))
        }
        return(norm(tree, 1L))
      }
    }
  }

  mint_fail("INVALID_DATA", "无法把数据解析成层级结构",
            "可以是 { \"name\": ..., \"children\": [...] }，或 [{ \"name\"/\"path\": ..., \"value\": ... }]")
}

# 同一父节点下按序取同色系深浅：顶层用主色，组内最大的最接近父色，越小越浅
mint_icicle_shade <- function(parent_color, index, siblings, depth) {
  if (depth <= 1L) return(parent_color)
  if (siblings <= 1L) return(parent_color)
  lo <- if (depth <= 2L) 0.35 else 0.52
  rev(mint_ramp(parent_color, siblings, from = lo, to = 0.88))[index]
}

# 底色深浅决定字色：浅底写深字，深底写白字
mint_icicle_ink <- function(hex) {
  rgb <- grDevices::col2rgb(hex) / 255
  luma <- 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
  if (luma < 0.35) "#FFFFFF" else "#3D3D3D"
}

# 展平成块表：每行一个节点，记下它在「宽度」方向上的区间 [across_lo, across_hi] 与层号
mint_icicle_blocks <- function(model, palette, root_color) {
  out <- list()
  walk <- function(node, depth, lo, hi, parent_color, index, siblings) {
    color <- if (depth == 0L) root_color
             else if (depth == 1L) palette[((index - 1L) %% length(palette)) + 1L]
             else mint_icicle_shade(parent_color, index, siblings, depth)
    out[[length(out) + 1L]] <<- list(
      name = node$name, depth = depth, across_lo = lo, across_hi = hi,
      value = node$value, color = color, leaf = is.null(node$children)
    )
    n <- length(node$children)
    if (n == 0) return(invisible(NULL))
    cursor <- lo
    for (i in seq_len(n)) {
      span <- (hi - lo) * node$children[[i]]$value / node$value
      walk(node$children[[i]], depth + 1L, cursor, cursor + span, color, i, n)
      cursor <- cursor + span
    }
    invisible(NULL)
  }
  walk(model, 0L, 0, 1, root_color, 1L, 1L)
  out
}

mint_register(mint_chart(
  id = "icicle",
  name = "冰柱图",
  english = "Icicle",
  category = "hierarchy",
  description = "横向分层的矩形层级图，每层代表一级，宽度代表占比",
  data_shape = paste(
    "与矩形树图一致：",
    "{ \"name\": \"总计\", \"children\": [{ \"name\": \"线上\", \"children\": [{ \"name\": \"华东\", \"value\": 320 }] }] }",
    "也接受 [{ \"name\": \"华东\", \"value\": 320 }] 或 [{ \"path\": \"线上/华东\", \"value\": 120 }]。",
    sep = "\n"
  ),
  variants = c("vertical 纵向", "horizontal 横向"),
  aliases = c("冰柱图", "icicle", "层级条形"),
  packages = c("ggplot2"),
  options = list(
    mint_option("orientation", "string", "展开方向", default = "vertical", values = c("vertical", "horizontal")),
    mint_option("borderWidth", "number", "矩形描边宽度", default = 1),
    mint_option("labelSkipWidth", "number", "过窄的矩形不显示标签", default = 24),
    mint_option("root", "string", "自动生成根节点时的名字", default = "总计"),
    mint_option("valueFormat", "string", "数值格式化方式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数，省略则用千分位整数"),
    mint_option("valuePrefix", "string", "数值前缀，如 ¥"),
    mint_option("valueSuffix", "string", "数值后缀，如 万")
  ),
  example = list(
    data = list(
      name = "总预算",
      children = list(
        list(name = "研发", children = list(
          list(name = "后端", value = 156), list(name = "前端", value = 128),
          list(name = "算法", value = 92), list(name = "测试", value = 54)
        )),
        list(name = "市场", children = list(
          list(name = "活动", value = 116), list(name = "品牌", value = 88),
          list(name = "渠道", value = 72)
        )),
        list(name = "运营", children = list(
          list(name = "物流", value = 104), list(name = "客服", value = 76),
          list(name = "仓储", value = 58)
        ))
      )
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_icicle_model(ctx$data, o$root %||% "总计")
    if (is.null(model) || length(model$children) == 0) {
      mint_fail("INVALID_DATA", "icicle 的数据里没有任何正的数值",
                "宽度按 value 分配，只接受 value > 0 的叶子节点")
    }

    font_size <- ctx$style$type$data_label
    border_mm <- (o$borderWidth %||% 1) * 0.25
    # 根节点用中性浅灰（它是整体，不该和分组抢颜色）
    blocks <- mint_icicle_blocks(model, ctx$colors, mint_tint(ctx$text, 0.12))
    nodes <- do.call(rbind, lapply(blocks, function(b) data.frame(
      name = b$name, depth = b$depth, lo = b$across_lo, hi = b$across_hi,
      value = b$value, fill = b$color, stringsAsFactors = FALSE
    )))
    nodes$id <- paste(nodes$name, nodes$depth, seq_len(nrow(nodes)), sep = "\u001f")
    levels <- max(nodes$depth) + 1L

    horizontal <- identical(o$orientation, "horizontal")
    if (horizontal) {
      # 根在左、越深越靠右；宽度铺在 y 轴上
      nodes$xmin <- nodes$depth
      nodes$xmax <- nodes$depth + 1
      nodes$ymin <- nodes$lo
      nodes$ymax <- nodes$hi
      w_pt <- rep(ctx$width / levels * 72, nrow(nodes))
      h_pt <- (nodes$hi - nodes$lo) * ctx$height * 72
    } else {
      # 根在上、越深越靠下；宽度铺在 x 轴上
      nodes$xmin <- nodes$lo
      nodes$xmax <- nodes$hi
      nodes$ymin <- levels - nodes$depth - 1
      nodes$ymax <- levels - nodes$depth
      w_pt <- (nodes$hi - nodes$lo) * ctx$width * 72
      h_pt <- rep(ctx$height / levels * 72, nrow(nodes))
    }

    nodes$ink <- vapply(nodes$fill, mint_icicle_ink, character(1))
    # 标签挑块宽够、字也放得下的写；labelSkipWidth 沿用旧版 px 语义（×0.75 折成 pt）
    # 叶子优先写「名字 + 数值」，放不下退回名字，再放不下就留空
    min_w <- (o$labelSkipWidth %||% 24) * 0.75
    fit <- function(text) {
      wide <- vapply(text, mint_text_width, numeric(1), size = font_size)
      w_pt >= min_w & h_pt >= font_size * 1.35 & wide <= w_pt * 0.88
    }
    with_value <- ifelse(nodes$depth == max(nodes$depth),
                         paste0(nodes$name, "  ", ctx$formatter(nodes$value)), nodes$name)
    nodes$label <- ifelse(fit(with_value), with_value, ifelse(fit(nodes$name), nodes$name, ""))
    labels <- nodes[nzchar(nodes$label), , drop = FALSE]

    p <- ggplot2::ggplot(nodes) +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = id),
        colour = ctx$background, linewidth = border_mm
      ) +
      ggplot2::scale_fill_manual(values = stats::setNames(nodes$fill, nodes$id), guide = "none")
    if (nrow(labels) > 0) {
      # 文字一律水平排、贴着块的左缘；纵向时左缘是宽度方向，横向时左缘是本层带子的起点
      pad <- 2.5 / 72 / ctx$width
      labels$x <- if (horizontal) labels$depth + pad else labels$lo + pad
      labels$y <- if (horizontal) (labels$lo + labels$hi) / 2 else levels - labels$depth - 0.5
      p <- p + ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = x, y = y, label = label),
        hjust = 0, vjust = 0.5, colour = labels$ink,
        size = font_size / ggplot2::.pt, show.legend = FALSE
      )
    }

    p +
      ggplot2::scale_x_continuous(
        limits = if (horizontal) c(0, levels) else c(0, 1), expand = c(0, 0)
      ) +
      ggplot2::scale_y_continuous(
        limits = if (horizontal) c(0, 1) else c(0, levels), expand = c(0, 0)
      ) +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        panel.background = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(5, 6, 4, 4)
      )
  }
))
