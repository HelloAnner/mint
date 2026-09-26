# 柱状图 bar —— 参考实现
#
# 这张图是其余统计类图表的样板，约定：
#   * 数据整形只用 R/data.R 里的 mint_as_rows / mint_infer_index_keys / mint_melt；
#   * 主题一律 mint_theme(style, family, grid = ...)，不在图表里手写 theme() 细节；
#   * 颜色一律 stats::setNames(ctx$colors[...], keys)，保证系列与颜色一一对应；
#   * 返回 ggplot 对象，版心（标题/脚注）由框架统一排版。

mint_register(mint_chart(
  id = "bar",
  name = "柱状图",
  english = "Bar",
  category = "comparison",
  description = "比较不同类别或分组的数值大小，可分组、可堆叠、可横向",
  data_shape = paste(
    "数组，每行一条记录：分类字段 + 若干数值字段",
    "[",
    "  { \"quarter\": \"Q1\", \"华东\": 128, \"华北\": 96 },",
    "  { \"quarter\": \"Q2\", \"华东\": 152, \"华北\": 108 }",
    "]",
    "不传 keys 时自动把数值字段识别为系列，第一个字符串字段识别为分类轴。",
    sep = "\n"
  ),
  variants = c("grouped 分组", "stacked 堆叠", "horizontal 横向"),
  aliases = c("column", "柱状图", "条形图", "直方图", "columns"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("groupMode", "string", "分组方式", default = "grouped", values = c("grouped", "stacked")),
    mint_option("layout", "string", "方向", default = "vertical", values = c("vertical", "horizontal")),
    mint_option("indexBy", "string", "分类轴字段名"),
    mint_option("keys", "array", "参与绘制的数值字段"),
    mint_option("barWidth", "number", "柱子宽度占槽位的比例", default = 0.68),
    mint_option("valueLabel", "boolean", "是否直接标注数值", default = TRUE),
    mint_option("sort", "string", "分类轴排序", default = "none", values = c("none", "asc", "desc")),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(quarter = "Q1", `华东` = 128, `华北` = 96, `华南` = 74),
      list(quarter = "Q2", `华东` = 152, `华北` = 108, `华南` = 88),
      list(quarter = "Q3", `华东` = 141, `华北` = 124, `华南` = 103),
      list(quarter = "Q4", `华东` = 187, `华北` = 139, `华南` = 121)
    ),
    options = list(yLegend = "营收（百万元）", xLegend = "2025 财年")
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- mint_as_rows(ctx$data, "bar")
    ik <- mint_infer_index_keys(rows, o$indexBy, o$keys, "bar")
    long <- mint_melt(rows, ik$indexBy, ik$keys)
    keys <- ik$keys

    fmt <- ctx$formatter
    colors <- stats::setNames(mint_colors(length(keys), ctx$colors), keys)
    stacked <- identical(o$groupMode, "stacked")
    horizontal <- identical(o$layout, "horizontal")
    show_values <- !identical(o$valueLabel, FALSE)
    wide <- !identical(o$legend, FALSE) && length(keys) > 1
    bar_width <- o$barWidth %||% ctx$style$geoms$bar_width
    label_size <- ctx$style$type$data_label / ggplot2::.pt

    # 排序：按各类别的合计值重排分类轴
    if (o$sort %in% c("asc", "desc")) {
      totals <- stats::aggregate(value ~ index, data = long, FUN = sum)
      ord <- order(totals$value, decreasing = identical(o$sort, "desc"))
      long$index <- factor(long$index, levels = as.character(totals$index[ord]))
    }

    position <- if (stacked) ggplot2::position_stack() else ggplot2::position_dodge(width = 0.8)

    # 堆叠图里太小的分段不放标签，否则文字会糊成一团
    label_data <- long
    if (stacked && show_values) {
      totals <- stats::aggregate(value ~ index, data = long, FUN = sum)
      min_value <- 0.05 * max(totals$value)
      label_data <- long[long$value >= min_value, , drop = FALSE]
    }

    if (horizontal) {
      p <- ggplot2::ggplot(long, ggplot2::aes(x = value, y = index, fill = series)) +
        ggplot2::geom_col(width = bar_width, position = position, colour = NA)
      if (show_values) {
        p <- p + ggplot2::geom_text(
          data = label_data, ggplot2::aes(label = fmt(value)),
          position = if (stacked) ggplot2::position_stack(vjust = 0.5) else ggplot2::position_dodge2(width = 0.8),
          hjust = if (stacked) 0.5 else -0.12,
          colour = if (stacked) "#FFFFFF" else ctx$text,
          size = label_size, show.legend = FALSE
        )
      }
      p <- p +
        ggplot2::scale_x_continuous(labels = fmt, breaks = mint_breaks(6),
                                    expand = ggplot2::expansion(mult = c(0, if (show_values && !stacked) 0.14 else 0.02))) +
        ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = 0.45)) +
        ggplot2::labs(x = o$xLegend, y = o$yLegend)
    } else {
      p <- ggplot2::ggplot(long, ggplot2::aes(x = index, y = value, fill = series)) +
        ggplot2::geom_col(width = bar_width, position = position, colour = NA)
      if (show_values) {
        p <- p + ggplot2::geom_text(
          data = label_data, ggplot2::aes(label = fmt(value)),
          position = if (stacked) ggplot2::position_stack(vjust = 0.5) else ggplot2::position_dodge(width = 0.8),
          vjust = if (stacked) 0.5 else -0.42,
          colour = if (stacked) "#FFFFFF" else ctx$text,
          size = label_size, show.legend = FALSE
        )
      }
      p <- p +
        ggplot2::scale_y_continuous(labels = fmt, breaks = mint_breaks(6),
                                    expand = ggplot2::expansion(mult = c(0, if (show_values && !stacked) 0.12 else 0.02))) +
        ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = 0.45)) +
        ggplot2::labs(x = o$xLegend, y = o$yLegend)
    }

    p +
      ggplot2::scale_fill_manual(values = colors, name = NULL, guide = mint_legend_guide(wide)) +
      mint_theme(ctx$style, ctx$family, grid = if (horizontal) "x" else "y")
  }
))
