# 环形图 / 饼图 pie
#
# 饼图在期刊里能用，但必须克制：按占比排序、扇区之间留细白缝、名字直接写在扇区外，
# 不用图例。占比过小的类别自动并入「其他」，避免一堆看不见的细条。
#
# 实现要点：coord_polar(theta = "y") 下，x 轴是半径、y 轴是角度，
# 所以「挖空」是靠 x 轴下限实现，而不是叠一个白色圆。

mint_register(mint_chart(
  id = "pie",
  name = "环形图",
  english = "Pie",
  category = "composition",
  description = "展示整体中各部分的占比，可实心可环形",
  data_shape = paste(
    "数组或对象都行：",
    "[ { \"id\": \"搜索\", \"value\": 348 }, { \"id\": \"社交\", \"value\": 266 } ]",
    "{ \"搜索\": 348, \"社交\": 266 }",
    "[ [\"搜索\", 348], [\"社交\", 266] ]",
    sep = "\n"
  ),
  variants = c("donut 环形", "pie 实心"),
  aspect = 1,
  aliases = c("饼图", "环形图", "甜甜圈", "donut", "piechart", "占比图"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("donut", "boolean", "是否挖空成环形", default = TRUE),
    mint_option("innerRatio", "number", "环形内径占外径的比例", default = 0.58),
    mint_option("showPercent", "boolean", "标签是否显示百分比", default = TRUE),
    mint_option("showValue", "boolean", "标签是否显示绝对值", default = FALSE),
    mint_option("sort", "string", "排序方式", default = "desc", values = c("desc", "asc", "none")),
    mint_option("minShare", "number", "占比低于该值并入「其他」", default = 0.015),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "搜索", value = 348), list(id = "社交", value = 266),
      list(id = "直邮", value = 174), list(id = "联盟", value = 122),
      list(id = "视频", value = 96)
    ),
    options = list(showPercent = TRUE, showValue = TRUE)
  ),
  render = function(ctx) {
    o <- ctx$options
    pairs <- mint_as_pairs(ctx$data, "pie")
    fmt <- ctx$formatter

    total <- sum(pairs$value)
    min_share <- o$minShare %||% 0
    if (min_share > 0 && total > 0 && nrow(pairs) > 2) {
      small <- pairs$value / total < min_share
      if (any(small) && !all(small)) {
        pairs <- rbind(
          pairs[!small, , drop = FALSE],
          data.frame(id = "其他", label = "其他", value = sum(pairs$value[small]), stringsAsFactors = FALSE)
        )
      }
    }

    if (identical(o$sort, "desc")) pairs <- pairs[order(-pairs$value), , drop = FALSE]
    if (identical(o$sort, "asc")) pairs <- pairs[order(pairs$value), , drop = FALSE]

    share <- pairs$value / sum(pairs$value)
    n <- nrow(pairs)
    end <- cumsum(share)
    start <- c(0, end[-n])
    mid <- (start + end) / 2

    df <- data.frame(
      label = factor(pairs$label, levels = pairs$label),
      share = share, mid = mid, stringsAsFactors = FALSE
    )
    colors <- stats::setNames(mint_colors(n, ctx$colors), levels(df$label))

    donut <- !identical(o$donut, FALSE)
    ratio <- if (donut) min(0.9, max(0, o$innerRatio %||% 0.58)) else 0
    ring_width <- 1 - ratio          # 环宽（半径单位），外径固定为 1
    bar_x <- ratio + ring_width / 2  # geom_col 的 x 是中心
    outer_limit <- 1.34              # 留出外侧标签的空间
    label_x <- 1.17

    label_text <- vapply(seq_len(n), function(i) {
      parts <- character(0)
      if (!identical(o$showPercent, FALSE)) parts <- c(parts, sprintf("%.1f%%", share[i] * 100))
      if (isTRUE(o$showValue)) parts <- c(parts, fmt(pairs$value[i]))
      paste(parts, collapse = "  ")
    }, character(1))

    # 外侧标签：x 定在圆环外一点，角度取扇区中线。
    # hjust 管左右、vjust 管上下，两个方向都朝「远离圆心」的一侧生长，
    # 这样多行标签永远是向外扩展，不会有一行压回扇区上。
    angle <- mid * 2 * pi
    horizontal <- sin(angle)
    vertical <- cos(angle)
    labels <- data.frame(
      x = label_x,
      y = mid,
      label = paste0(pairs$label, ifelse(nzchar(label_text), paste0("\n", label_text), "")),
      hjust = ifelse(horizontal > 0.08, 0, ifelse(horizontal < -0.08, 1, 0.5)),
      vjust = ifelse(vertical > 0.08, 1, ifelse(vertical < -0.08, 0, 0.5)),
      stringsAsFactors = FALSE
    )

    ggplot2::ggplot(df, ggplot2::aes(x = bar_x, y = share, fill = label)) +
      ggplot2::geom_col(width = ring_width, colour = ctx$background, linewidth = 0.35) +
      ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust),
        inherit.aes = FALSE,
        size = ctx$style$type$data_label / ggplot2::.pt,
        colour = ctx$text, lineheight = 1.25
      ) +
      ggplot2::scale_fill_manual(values = colors, name = NULL, guide = "none") +
      ggplot2::scale_x_continuous(limits = c(0, outer_limit), expand = c(0, 0)) +
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
