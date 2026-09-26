# 旭日图 sunburst
#
# 环形分层：每一层一圈，同一角度区间从内到外一路展开，占比直接读圆心角。
# 不用 sunburstR（那是 htmlwidget，要浏览器才能跑），这里自己算角度与半径：
# coord_polar(theta = "y") 下 x 是半径、y 是角度，所以扇形就是一块 geom_rect
# （ggplot2 在非线性坐标系里会把矩形细分成弧，不会画成三角形）。
#
# 排版上的克制：
#   * 同一父色下按序取深浅，顶层用主色，越大的块越饱和 —— 颜色只讲归属，不讲别的；
#   * 扇区之间留白靠角度收缩，层与层之间靠背景色描边，不用深色描边（深边会糊住小扇区）；
#   * 名字先按 mint_text_width 估长宽：环够宽就沿半径写，环窄就顺着弧切向写，
#     两个方向都放不下就不写 —— 宁可少标，也不压线或者截成「三级…」这种没信息的东西。

# 层级数据归一化：兼容 { name, children } / [ { name, value } ] / [ { path, value } ]
mint_sunburst_model <- function(data, root = "总计") {
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
      # 同级按值降序：扇区从大到小排，颜色深浅也跟着面积走
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
mint_sunburst_shade <- function(parent_color, index, siblings, depth) {
  if (depth <= 1L) return(parent_color)
  if (siblings <= 1L) return(parent_color)
  lo <- if (depth <= 2L) 0.35 else 0.52
  rev(mint_ramp(parent_color, siblings, from = lo, to = 0.88))[index]
}

# 底色深浅决定字色：浅底写深字，深底写白字
mint_sunburst_ink <- function(hex) {
  rgb <- grDevices::col2rgb(hex) / 255
  luma <- 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
  if (luma < 0.35) "#FFFFFF" else "#3D3D3D"
}

# 展平成扇区表：每个节点一段角度区间 [start, end]（0~1 圈）与一条半径带 [r0, r1]
mint_sunburst_rings <- function(model, palette, hole = 0.16) {
  depth_max <- 0L
  measure <- function(node, depth) {
    depth_max <<- max(depth_max, depth)
    for (k in node$children) measure(k, depth + 1L)
  }
  measure(model, 0L)
  if (depth_max == 0L) depth_max <- 1L
  ring <- (1 - hole) / depth_max

  out <- list()
  walk <- function(node, depth, start, end, parent_color, index, siblings) {
    if (depth >= 1L) {
      color <- if (depth == 1L) palette[((index - 1L) %% length(palette)) + 1L]
               else mint_sunburst_shade(parent_color, index, siblings, depth)
      out[[length(out) + 1L]] <<- list(
        name = node$name, depth = depth,
        start = start, end = end,
        r0 = hole + (depth - 1L) * ring, r1 = hole + depth * ring,
        value = node$value, color = color
      )
    } else {
      color <- NA_character_
    }
    n <- length(node$children)
    if (n == 0) return(invisible(NULL))
    cursor <- start
    for (i in seq_len(n)) {
      span <- (end - start) * node$children[[i]]$value / node$value
      walk(node$children[[i]], depth + 1L, cursor, cursor + span, color, i, n)
      cursor <- cursor + span
    }
    invisible(NULL)
  }
  walk(model, 0L, 0, 1, NA_character_, 1L, 1L)
  out
}

mint_register(mint_chart(
  id = "sunburst",
  name = "旭日图",
  english = "Sunburst",
  category = "hierarchy",
  description = "用同心环表达多层级的构成，从内到外逐层展开",
  data_shape = paste(
    "与矩形树图一致，同为层级结构：",
    "{ \"name\": \"总计\", \"children\": [{ \"name\": \"线上\", \"children\": [{ \"name\": \"华东\", \"value\": 320 }] }] }",
    "也接受 [{ \"name\": \"华东\", \"value\": 320 }] 或 [{ \"path\": \"线上/华东\", \"value\": 120 }]。",
    sep = "\n"
  ),
  variants = c("sunburst 旭日"),
  aliases = c("旭日图", "sunburst", "环形层级"),
  packages = c("ggplot2"),
  options = list(
    mint_option("cornerRadius", "number", "扇区圆角（R 版为直角扇区，此选项保留兼容）", default = 3),
    mint_option("borderWidth", "number", "扇区描边宽度", default = 1),
    mint_option("root", "string", "自动生成根节点时的名字", default = "总计"),
    mint_option("valueFormat", "string", "数值格式化方式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数，省略则用千分位整数"),
    mint_option("valuePrefix", "string", "数值前缀，如 ¥"),
    mint_option("valueSuffix", "string", "数值后缀，如 万")
  ),
  example = list(
    data = list(
      name = "总支出",
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
    fmt <- ctx$formatter
    model <- mint_sunburst_model(ctx$data, o$root %||% "总计")
    if (is.null(model) || is.null(model$children)) {
      mint_fail("INVALID_DATA", "sunburst 的数据里没有任何正的数值",
                "角度图只接受 value > 0 的叶子节点")
    }

    hole <- 0.16
    rings <- mint_sunburst_rings(model, ctx$colors, hole)
    if (length(rings) == 0) {
      mint_fail("INVALID_DATA", "sunburst 的层级里没有可画的节点", "至少需要一个 value > 0 的叶子")
    }
    font_size <- ctx$style$type$data_label
    # 版心内切圆半径（英寸）：coord_polar 会把圆内切到版心的短边
    radius_in <- max(0.35, min(ctx$width, ctx$height) / 2 * 0.98)
    radius_mm <- radius_in * 25.4

    nodes <- do.call(rbind, lapply(rings, function(n) data.frame(
      name = n$name, depth = n$depth, start = n$start, end = n$end,
      r0 = n$r0, r1 = n$r1, value = n$value, fill = n$color,
      stringsAsFactors = FALSE
    )))
    nodes$id <- paste(nodes$name, nodes$depth, seq_len(nrow(nodes)), sep = "\u001f")

    # 扇区之间留白：按外层弧长折算角度，小扇区最多让出自身三成，免得被吃光
    gap_turns <- 0.35 / (2 * pi * radius_mm)
    span <- nodes$end - nodes$start
    pad <- pmin(gap_turns / pmax(nodes$r1, 0.05), span * 0.3)
    # coord_polar(theta = "y") 里 x 是半径、y 是角度：角度区间必须给 ymin/ymax
    nodes$rlo <- nodes$r0
    nodes$rhi <- nodes$r1
    nodes$tlo <- nodes$start + pad / 2
    nodes$thi <- nodes$end - pad / 2
    nodes$rmid <- (nodes$r0 + nodes$r1) / 2
    nodes$tmid <- (nodes$start + nodes$end) / 2

    nodes$ink <- vapply(nodes$fill, mint_sunburst_ink, character(1))
    ink <- nodes$ink
    ring_pt <- (nodes$r1[1] - nodes$r0[1]) * radius_in * 72
    text_pt <- vapply(nodes$name, mint_text_width, numeric(1), size = font_size)
    # 该节点中半径处的弧长（pt）：切向写字时可用它当宽度
    arc_pt <- (nodes$end - nodes$start) * 2 * pi * nodes$rmid * radius_in * 72
    room <- ring_pt >= font_size * 1.35
    radial_ok <- room & text_pt <= ring_pt * 0.88
    tangent_ok <- room & text_pt <= arc_pt * 0.9
    # 默认沿半径写（旭日图的标准做法）；环太窄放不下就顺着弧切向写；
    # 两个方向都放不下就干脆不写 —— 宁可少标，也不压线或截成「三级…」这种没信息的东西。
    nodes$angle <- 180 - 360 * nodes$tmid
    nodes$angle[!radial_ok & tangent_ok] <- nodes$angle[!radial_ok & tangent_ok] + 90
    nodes$label <- ifelse(radial_ok | tangent_ok, nodes$name, "")
    flip <- nodes$angle > 90 | nodes$angle < -90
    nodes$angle[flip] <- nodes$angle[flip] + ifelse(nodes$angle[flip] > 90, -180, 180)

    labels <- nodes[nzchar(nodes$label), , drop = FALSE]

    # 圆心留白标根节点名与合计：只有确实放得下才标
    center_r_pt <- hole * radius_in * 72
    center_label <- ""
    root_text <- as.character(model$name)
    total_text <- fmt(model$value)
    if (mint_text_width(root_text, font_size) <= center_r_pt * 1.85) {
      center_label <- root_text
      if (mint_text_width(total_text, font_size) <= center_r_pt * 1.6) {
        center_label <- paste0(root_text, "\n", total_text)
      }
    }

    border_mm <- (o$borderWidth %||% 1) * 0.25
    p <- ggplot2::ggplot(nodes) +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = rlo, xmax = rhi, ymin = tlo, ymax = thi, fill = id),
        colour = ctx$background, linewidth = border_mm
      ) +
      ggplot2::scale_fill_manual(values = stats::setNames(nodes$fill, nodes$id), guide = "none")
    if (nrow(labels) > 0) {
      p <- p + ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = rmid, y = tmid, label = label, angle = angle, colour = ink),
        size = font_size / ggplot2::.pt, hjust = 0.5, vjust = 0.5,
        lineheight = 1.05, show.legend = FALSE
      )
    }
    if (nzchar(center_label)) {
      p <- p + ggplot2::geom_text(
        data = data.frame(x = 0, y = 0.5, label = center_label, stringsAsFactors = FALSE),
        ggplot2::aes(x = x, y = y, label = label),
        inherit.aes = FALSE, size = font_size / ggplot2::.pt,
        colour = ctx$foreground, hjust = 0.5, vjust = 0.5, lineheight = 1.15
      )
    }

    p +
      ggplot2::scale_colour_identity() +
      ggplot2::scale_x_continuous(limits = c(0, 1.02), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
      ggplot2::coord_polar(theta = "y", start = -pi / 2, direction = 1) +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        panel.background = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(4, 4, 4, 4)
      )
  }
))
