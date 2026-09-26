# 圆形打包图 circle-packing
#
# 用圆的面积表达占比：叶子圆的半径按 sqrt(value)（面积与数值成正比），
# 同一组的叶子先自己排好，再算出包围圆当作父圆，逐层往上叠 —— 这才是真正的嵌套打包，
# 比「把所有叶子一次性铺开再画圈」紧凑得多。
#
# 排版上的克制：
#   * 叶子圆填充同色系深浅（组内最大最饱和），父圆只描一道细线、不填充；
#   * 圆之间、圆与父圆之间的缝来自打包时按比例放大的半径，越大的圆缝越宽，视觉才匀；
#   * 名字只写在放得下的小圆里（按 mint_text_width 判断矩形能不能内接进圆），放不下就不写。

# 层级数据归一化：兼容 { name, children } / [ { name, value } ] / [ { path, value } ]
mint_cp_model <- function(data, root = "总计") {
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
mint_cp_shade <- function(parent_color, index, siblings, depth) {
  if (depth <= 1L) return(parent_color)
  if (siblings <= 1L) return(parent_color)
  lo <- if (depth <= 2L) 0.35 else 0.52
  rev(mint_ramp(parent_color, siblings, from = lo, to = 0.88))[index]
}

# 底色深浅决定字色：浅底写深字，深底写白字
mint_cp_ink <- function(hex) {
  rgb <- grDevices::col2rgb(hex) / 255
  luma <- 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
  if (luma < 0.35) "#FFFFFF" else "#3D3D3D"
}

# 一组圆的最小包围圆。
# 目标函数 f(c) = max_i(|c_i - c| + r_i) 是凸的，用 Franke-Wolfe 逐步挪向「最远的那个圆」，
# 几百次迭代就收敛到最优解 —— 比自己推两圆/三圆相切的解析解可靠得多。
mint_cp_enclosing <- function(x, y, r, iter = 400L) {
  cx <- mean(x); cy <- mean(y)
  for (k in seq_len(iter)) {
    dist <- sqrt((x - cx)^2 + (y - cy)^2) + r
    i <- which.max(dist)
    gamma <- 2 / (k + 2)
    cx <- cx + gamma * (x[i] - cx)
    cy <- cy + gamma * (y[i] - cy)
  }
  list(x = cx, y = cy, r = max(sqrt((x - cx)^2 + (y - cy)^2) + r))
}

# 递归打包：叶子半径 = sqrt(value)，内部节点的半径 = 子节点布局的包围圆
mint_cp_pack <- function(node, eps) {
  if (is.null(node$children)) {
    return(list(name = node$name, value = node$value, depth = node$depth,
                x = 0, y = 0, r = sqrt(node$value), color = NA_character_, leaf = TRUE, children = NULL))
  }
  kids <- lapply(node$children, mint_cp_pack, eps = eps)
  true_r <- vapply(kids, function(k) k$r, numeric(1))
  # 打包时把半径放大 (1+eps)、但只取它的位置，圆的半径仍按真实值画：
  # 相切的圆之间就腾出了与半径成正比的缝（大圆缝宽、小圆缝窄，视觉才均匀）。
  layout <- packcircles::circleProgressiveLayout(true_r * (1 + eps), sizetype = "radius")
  enc <- mint_cp_enclosing(layout$x, layout$y, true_r)
  kids <- lapply(seq_along(kids), function(i) {
    k <- kids[[i]]
    k$x <- layout$x[i] - enc$x
    k$y <- layout$y[i] - enc$y
    k
  })
  # 父圆 = 子节点的最小包围圆再放大一圈，父圆才不会贴着子圆
  list(name = node$name, value = node$value, depth = node$depth,
       x = 0, y = 0, r = enc$r * (1 + eps), color = NA_character_, leaf = FALSE, children = kids)
}

# 给打包好的树染色并展平成圆表。
# 打包时每层只记相对于父圆的局部坐标，这里沿着树把祖先的偏移累加上去才是绝对位置。
mint_cp_circles <- function(packed, palette) {
  out <- list()
  walk <- function(node, depth, ox, oy, parent_color, index, siblings) {
    color <- if (depth == 0L) NA_character_
             else if (depth == 1L) palette[((index - 1L) %% length(palette)) + 1L]
             else mint_cp_shade(parent_color, index, siblings, depth)
    x <- ox + (node$x %||% 0)
    y <- oy + (node$y %||% 0)
    if (!is.null(node$r) && depth >= 1L) {
      out[[length(out) + 1L]] <<- list(
        name = node$name, value = node$value, depth = depth,
        x = x, y = y, r = node$r, color = color, leaf = isTRUE(node$leaf)
      )
    }
    n <- length(node$children)
    if (n == 0) return(invisible(NULL))
    for (i in seq_len(n)) walk(node$children[[i]], depth + 1L, x, y, color, i, n)
    invisible(NULL)
  }
  walk(packed, 0L, 0, 0, NA_character_, 1L, 1L)
  out
}

# 把名字尽量均衡地折成两行：按显示宽度挑断点，且两侧各留至少两个字。
# 直接用按宽度贪心折行会出现「三级A1 / a」这种尾巴，比不标还难看。
mint_cp_wrap2 <- function(text, max_width, size) {
  chars <- strsplit(text, "")[[1]]
  if (length(chars) < 4) return("")
  best <- ""
  best_gap <- Inf
  for (k in 2:(length(chars) - 2L)) {
    head <- paste(chars[seq_len(k)], collapse = "")
    tail <- paste(chars[(k + 1L):length(chars)], collapse = "")
    w_head <- mint_text_width(head, size)
    w_tail <- mint_text_width(tail, size)
    if (max(w_head, w_tail) > max_width) next
    gap <- abs(w_head - w_tail)
    if (gap < best_gap) {
      best_gap <- gap
      best <- paste(head, tail, sep = "\n")
    }
  }
  best
}

mint_register(mint_chart(
  id = "circle-packing",
  name = "圆形打包图",
  english = "CirclePacking",
  category = "hierarchy",
  description = "用嵌套圆的面积表达层级占比，视觉柔和，适合摘要与封面",
  data_shape = paste(
    "与矩形树图一致：",
    "{ \"name\": \"总计\", \"children\": [{ \"name\": \"线上\", \"children\": [{ \"name\": \"华东\", \"value\": 320 }] }] }",
    "也接受 [{ \"name\": \"华东\", \"value\": 320 }] 或 [{ \"path\": \"线上/华东\", \"value\": 120 }]。",
    sep = "\n"
  ),
  variants = c("packed 打包"),
  aliases = c("圆打包", "气泡图", "气泡树", "bubble tree"),
  packages = c("ggplot2", "ggforce", "packcircles"),
  options = list(
    mint_option("padding", "number", "圆之间的间距", default = 4),
    mint_option("labelSkipRadius", "number", "半径小于该值的圆不显示标签", default = 12),
    mint_option("root", "string", "自动生成根节点时的名字", default = "总计"),
    mint_option("valueFormat", "string", "数值格式化方式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数，省略则用千分位整数"),
    mint_option("valuePrefix", "string", "数值前缀，如 ¥"),
    mint_option("valueSuffix", "string", "数值后缀，如 万")
  ),
  example = list(
    data = list(
      name = "获客",
      children = list(
        list(name = "线上", children = list(
          list(name = "搜索广告", value = 348), list(name = "社交媒体", value = 266),
          list(name = "内容营销", value = 143), list(name = "联盟推广", value = 96)
        )),
        list(name = "线下", children = list(
          list(name = "门店活动", value = 184), list(name = "展会", value = 112),
          list(name = "地推", value = 74)
        )),
        list(name = "合作", children = list(
          list(name = "渠道分销", value = 158), list(name = "生态伙伴", value = 88)
        ))
      )
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    fmt <- ctx$formatter
    model <- mint_cp_model(ctx$data, o$root %||% "总计")
    if (is.null(model) || length(model$children) == 0) {
      mint_fail("INVALID_DATA", "circle-packing 的数据里没有任何正的数值",
                "圆面积与 value 成正比，只接受 value > 0 的叶子节点")
    }

    eps <- max(0, (o$padding %||% 4) / 100)
    packed <- mint_cp_pack(model, eps)
    circles <- mint_cp_circles(packed, ctx$colors)
    nodes <- do.call(rbind, lapply(circles, function(c) data.frame(
      name = c$name, depth = c$depth, x = c$x, y = c$y, r = c$r,
      value = c$value, fill = c$color, leaf = c$leaf, stringsAsFactors = FALSE
    )))
    root_r <- packed$r

    # 1 个原始单位映射到多少英寸：让整包图占满版心短边的 94%
    scale_in <- min(ctx$width, ctx$height) * 0.94 / (2 * root_r)
    half <- root_r / 0.94
    nodes$ink <- vapply(nodes$fill, mint_cp_ink, character(1))
    font_size <- ctx$style$type$data_label
    min_r <- (o$labelSkipRadius %||% 12) * 0.75
    leaves <- nodes[nodes$leaf, , drop = FALSE]
    leaves$r_pt <- leaves$r * scale_in * 72
    # 文字是个矩形，要能内接进圆：(宽/2)^2 + (高/2)^2 <= (0.9r)^2。
    # 圆的半径就是可用半宽，所以先试「名字+数值」两行，再试名字一行，最后把名字折两行。
    inner_r <- 0.9 * leaves$r_pt
    max_w <- function(lines) 2 * pmax(0, sqrt(pmax(0, inner_r^2 - (font_size * 1.25 * lines / 2)^2)))
    fits <- function(text, lines) {
      width <- vapply(text, function(item) {
        parts <- strsplit(item, "\n", fixed = TRUE)[[1]]
        if (length(parts) == 0) return(0)
        max(vapply(parts, mint_text_width, numeric(1), size = font_size))
      }, numeric(1))
      leaves$r_pt >= min_r & width <= max_w(lines)
    }
    with_value <- paste0(leaves$name, "\n", fmt(leaves$value))
    wrapped <- vapply(seq_along(leaves$name), function(i) {
      mint_cp_wrap2(leaves$name[i], max_w(2)[i], font_size)
    }, character(1))
    leaves$label <- ifelse(fits(with_value, 2), with_value,
                    ifelse(fits(leaves$name, 1), leaves$name,
                    ifelse(nzchar(wrapped) & fits(wrapped, 2), wrapped, "")))
    # 圆必须全画（面积才是真的占比），放不下的只是不写名字
    labelled <- leaves[nzchar(leaves$label), , drop = FALSE]

    parents <- nodes[!nodes$leaf, , drop = FALSE]

    p <- ggplot2::ggplot() +
      ggforce::geom_circle(
        data = parents,
        ggplot2::aes(x0 = x, y0 = y, r = r, colour = fill),
        fill = NA, linewidth = 0.3, show.legend = FALSE
      ) +
      ggplot2::scale_colour_identity()
    if (nrow(leaves) > 0) {
      p <- p + ggforce::geom_circle(
        data = leaves,
        ggplot2::aes(x0 = x, y0 = y, r = r, fill = fill),
        colour = ctx$background, linewidth = 0.25, show.legend = FALSE
      ) +
        ggplot2::scale_fill_identity()
    }
    if (nrow(labelled) > 0) {
      p <- p + ggplot2::geom_text(
        data = labelled,
        ggplot2::aes(x = x, y = y, label = label, colour = ink),
        size = font_size / ggplot2::.pt, lineheight = 1.1, hjust = 0.5, vjust = 0.5,
        show.legend = FALSE
      )
    }

    p +
      # 坐标必须是等比的：coord_fixed 下 mint 把 panel 摆成由短边决定的正方形，
      # 所以 x/y 用同样的数据跨度，圆画出来才是圆而不是椭圆。
      ggplot2::scale_x_continuous(limits = c(-half, half), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(-half, half), expand = c(0, 0)) +
      ggplot2::coord_fixed(ratio = 1) +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        panel.background = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(2, 2, 2, 2)
      )
  }
))
