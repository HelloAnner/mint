# 棒棒糖图 lollipop
#
# 类别很多、又不想让柱子把画面糊满时的替代方案：只留一根细杆 + 一个端点圆点，
# 同样的信息量下留白多得多，读者视线顺着圆点连成的「轮廓线」就能读出排名。
#
# 三条约定：
#   · 杆从 0 基线量起（0 基线是一条浅灰细线），长度读数和柱状图一致，不会因为
#     截断坐标轴放大差异；
#   · 杆用主色的浅色调、端点用实色圆点 —— 数据落在圆点上，杆只负责把点连到基线；
#   · 数值直标在圆点旁，默认按数值降序，单系列所以不出图例。

mint_register(mint_chart(
  id = "lollipop",
  name = "棒棒糖图",
  english = "Lollipop",
  category = "comparison",
  description = "用细杆加圆点替代柱子，类别多时信息密度更高、留白更多",
  data_shape = paste(
    "数组，每项一个类别：",
    "[",
    "  { \"id\": \"A\", \"value\": 12 },",
    "  { \"id\": \"B\", \"value\": 30 }",
    "]",
    "也支持对象写法 { \"A\": 12, \"B\": 30 } 与二元数组 [[\"A\", 12]]。",
    sep = "\n"
  ),
  variants = c("vertical 纵向", "horizontal 横向"),
  aliases = c("棒棒糖图", "lollipop", "棒糖图", "点棒图"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("layout", "string", "方向", default = "vertical", values = c("vertical", "horizontal")),
    mint_option("sort", "string", "排序方式", default = "desc", values = c("desc", "asc", "none")),
    mint_option("valueLabel", "boolean", "是否直接标注数值", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "搜索", value = 348), list(id = "社交", value = 266),
      list(id = "直邮", value = 174), list(id = "联盟", value = 122),
      list(id = "视频", value = 96), list(id = "短信", value = 64)
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    pairs <- mint_as_pairs(ctx$data, "lollipop")
    if (any(!is.finite(pairs$value))) {
      mint_fail("INVALID_DATA", "lollipop 的数值里有无穷大或缺失值", "每个类别都要有有限数值")
    }
    if (identical(o$sort, "desc")) pairs <- pairs[order(-pairs$value), , drop = FALSE]
    if (identical(o$sort, "asc")) pairs <- pairs[order(pairs$value), , drop = FALSE]
    rownames(pairs) <- NULL

    fmt <- ctx$formatter
    ty <- ctx$style$type
    gm <- ctx$style$geoms
    values <- pairs$value
    n <- nrow(pairs)
    horizontal <- identical(o$layout, "horizontal")

    # 纵向时长的类别名要折行，否则相邻刻度会挤成一团；横向时左侧留给标签的空间够
    labels <- if (horizontal) pairs$label else {
      mint_wrap(pairs$label, max(24, ctx$width * 0.88 / n * 72 * 0.9), size = ty$data_label)
    }
    # 横向：数值大的排在上面（离散轴自下而上，所以倒序给 levels）
    levels_ord <- if (horizontal) rev(labels) else labels
    ids <- factor(labels, levels = levels_ord)

    lo <- min(0, min(values))
    hi <- max(0, max(values))
    if (hi <= lo) hi <- lo + 1
    span <- hi - lo
    pad <- 0.10 * span
    # 基线一侧始终留一小截：0 刻度不会和第一个类目名在画布左下角挤在一起
    base_pad <- 0.045 * span
    # 数值直标在圆点外侧，正负两个方向都要留出文字的位置
    limits <- c(lo - (if (any(values < 0)) pad else base_pad),
                hi + (if (any(values > 0)) pad else base_pad))

    stem_colour <- mint_tint(ctx$colors[1], 0.55)
    dot_colour <- ctx$colors[1]
    show_values <- !identical(o$valueLabel, FALSE)
    label_size <- ty$data_label / ggplot2::.pt

    if (horizontal) {
      # hjust 按正负给：正值的文字排在圆点右边，负值排在左边
      label_df <- data.frame(
        y = ids, x = values, label = fmt(values),
        hjust = ifelse(values >= 0, -0.35, 1.35), stringsAsFactors = FALSE
      )
      p <- ggplot2::ggplot(data.frame(x = values, y = ids)) +
        ggplot2::geom_segment(
          ggplot2::aes(x = 0, xend = values, y = y, yend = y),
          colour = stem_colour, linewidth = gm$line_width
        ) +
        ggplot2::geom_point(ggplot2::aes(x = x, y = y), size = gm$point_size, colour = dot_colour) +
        # 0 基线：坐标轴本身在图片边上时它会被轴线盖住，混有负值时才看得见，正好
        ggplot2::geom_vline(xintercept = 0, colour = ctx$grid, linewidth = gm$grid_width) +
        ggplot2::scale_x_continuous(limits = limits, breaks = mint_breaks(6), labels = fmt,
                                    expand = c(0, 0)) +
        ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = 0.6)) +
        ggplot2::labs(x = NULL, y = NULL)
      if (show_values) {
        p <- p + ggplot2::geom_text(
          data = label_df, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
          size = label_size, colour = ctx$text
        )
      }
      return(p + mint_theme(ctx$style, ctx$family, grid = "x"))
    }

    label_df <- data.frame(
      x = ids, y = values, label = fmt(values),
      vjust = ifelse(values >= 0, -1.2, 1.2), stringsAsFactors = FALSE
    )
    p <- ggplot2::ggplot(data.frame(x = ids, y = values)) +
      ggplot2::geom_segment(
        ggplot2::aes(x = x, xend = x, y = 0, yend = values),
        colour = stem_colour, linewidth = gm$line_width
      ) +
      ggplot2::geom_point(ggplot2::aes(x = x, y = y), size = gm$point_size, colour = dot_colour) +
      ggplot2::geom_hline(yintercept = 0, colour = ctx$grid, linewidth = gm$grid_width) +
      ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = 0.6)) +
      ggplot2::scale_y_continuous(limits = limits, breaks = mint_breaks(6), labels = fmt,
                                  expand = c(0, 0)) +
      ggplot2::labs(x = NULL, y = NULL)
    if (show_values) {
      p <- p + ggplot2::geom_text(
        data = label_df, ggplot2::aes(x = x, y = y, label = label, vjust = vjust),
        size = label_size, colour = ctx$text
      )
    }
    p + mint_theme(ctx$style, ctx$family, grid = "y")
  }
))
