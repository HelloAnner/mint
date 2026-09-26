# 散点图 / 气泡图 scatter
#
# 期刊里散点图的关键是：点小而实、必要时给拟合线与置信带、别让图例抢戏。
# 数据点超过一屏能看清的密度时自动降透明度，避免整块糊成黑饼。

mint_register(mint_chart(
  id = "scatter",
  name = "散点图",
  english = "Scatter",
  category = "relation",
  description = "看两个变量的相关关系，可分组着色、可按第三维调点大小",
  data_shape = paste(
    "数组，每行一个点：",
    "[",
    "  { \"x\": 12.4, \"y\": 88, \"group\": \"对照组\" },",
    "  { \"x\": 18.1, \"y\": 96, \"group\": \"实验组\", \"size\": 3 }",
    "]",
    "字段名可用 xKey / yKey / seriesKey / sizeKey 改写。",
    sep = "\n"
  ),
  variants = c("scatter 散点", "bubble 气泡", "trend 带拟合线"),
  aliases = c("散点图", "气泡图", "scatterplot", "bubble", "相关"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("xKey", "string", "X 数值字段", default = "x"),
    mint_option("yKey", "string", "Y 数值字段", default = "y"),
    mint_option("seriesKey", "string", "分组字段"),
    mint_option("sizeKey", "string", "气泡大小字段"),
    mint_option("labelKey", "string", "点标注字段"),
    mint_option("pointSize", "number", "点大小（mm）"),
    mint_option("alpha", "number", "点透明度"),
    mint_option("trend", "string", "拟合线", default = "none", values = c("none", "linear", "loess")),
    mint_option("trendCI", "boolean", "拟合线是否带置信带", default = TRUE),
    mint_option("labels", "boolean", "是否标注点", default = FALSE),
    mint_option("xZero", "boolean", "X 轴是否包含 0", default = FALSE),
    mint_option("yZero", "boolean", "Y 轴是否包含 0", default = FALSE),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(x = 12.4, y = 88, group = "对照组"), list(x = 15.2, y = 92, group = "对照组"),
      list(x = 18.1, y = 96, group = "对照组"), list(x = 21.5, y = 91, group = "对照组"),
      list(x = 24.9, y = 103, group = "对照组"), list(x = 28.3, y = 99, group = "对照组"),
      list(x = 13.8, y = 74, group = "实验组"), list(x = 17.6, y = 79, group = "实验组"),
      list(x = 20.4, y = 86, group = "实验组"), list(x = 23.1, y = 83, group = "实验组"),
      list(x = 26.7, y = 94, group = "实验组"), list(x = 30.2, y = 97, group = "实验组")
    ),
    options = list(xLegend = "干预强度", yLegend = "效应值", trend = "linear")
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- mint_as_rows(ctx$data, "scatter")
    x <- mint_numeric_column(rows, o$xKey %||% "x", "scatter", "X 字段")
    y <- mint_numeric_column(rows, o$yKey %||% "y", "scatter", "Y 字段")

    series <- if (!is.null(o$seriesKey) && o$seriesKey %in% names(rows)) {
      as.character(rows[[o$seriesKey]])
    } else {
      rep("", nrow(rows))
    }
    ids <- unique(series)
    has_series <- length(ids) > 1 || (length(ids) == 1 && nzchar(ids[1]))
    size_values <- mint_optional_numeric_column(rows, o$sizeKey %||% NULL)
    has_size <- !is.null(o$sizeKey) && any(!is.na(size_values))

    data <- data.frame(x = x, y = y, series = if (has_series) series else "全部", stringsAsFactors = FALSE)
    if (has_size) data$size <- size_values
    if (isTRUE(o$labels)) {
      key <- o$labelKey %||% o$seriesKey
      data$label <- if (!is.null(key) && key %in% names(rows)) as.character(rows[[key]]) else as.character(seq_len(nrow(rows)))
    }

    fmt <- ctx$formatter
    ids_used <- unique(data$series)
    colors <- stats::setNames(mint_colors(length(ids_used), ctx$colors), ids_used)
    wide <- !identical(o$legend, FALSE) && length(ids_used) > 1
    point_size <- o$pointSize %||% ctx$style$geoms$point_size
    alpha <- o$alpha %||% if (nrow(data) > 120) 0.55 else 1

    p <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y))
    if (has_size) {
      p <- p + ggplot2::aes(size = size)
    }

    # 拟合线与置信带画在点下面，避免盖住数据
    if (!identical(o$trend, "none")) {
      method <- if (identical(o$trend, "linear")) "lm" else "loess"
      p <- p + ggplot2::geom_smooth(
        ggplot2::aes(colour = series, group = series),
        method = method, formula = y ~ x, se = isTRUE(o$trendCI),
        level = 0.95, linewidth = ctx$style$geoms$line_width,
        fill = ctx$ref, alpha = 0.18, show.legend = FALSE
      )
    }

    p <- p + ggplot2::geom_point(
      ggplot2::aes(colour = series),
      size = if (has_size) NULL else point_size,
      stroke = ctx$style$geoms$point_stroke, alpha = alpha
    )

    if (isTRUE(o$labels)) {
      p <- p + ggplot2::geom_text(
        ggplot2::aes(label = label), size = ctx$style$type$data_label / ggplot2::.pt,
        vjust = -0.7, colour = ctx$text, show.legend = FALSE, check_overlap = TRUE
      )
    }

    # 坐标轴为 0 的参考线只在这条线真的落在数据范围里时才画
    refs <- list()
    if (min(x) < 0 && max(x) > 0) refs <- c(refs, list(ggplot2::geom_vline(xintercept = 0, colour = ctx$ref, linewidth = 0.3)))
    if (min(y) < 0 && max(y) > 0) refs <- c(refs, list(ggplot2::geom_hline(yintercept = 0, colour = ctx$ref, linewidth = 0.3)))
    for (layer in refs) p <- p + layer

    x_expand <- ggplot2::expansion(mult = 0.06)
    y_expand <- ggplot2::expansion(mult = 0.08)
    p <- p +
      ggplot2::scale_x_continuous(
        labels = fmt, breaks = mint_breaks(6),
        limits = if (isTRUE(o$xZero)) c(min(0, min(x)), NA) else NULL,
        expand = x_expand
      ) +
      ggplot2::scale_y_continuous(
        labels = fmt, breaks = mint_breaks(6),
        limits = if (isTRUE(o$yZero)) c(min(0, min(y)), NA) else NULL,
        expand = y_expand
      ) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend)

    if (has_size) {
      p <- p + ggplot2::scale_size_continuous(
        name = o$sizeKey, range = c(point_size * 0.6, point_size * 3.2),
        guide = ggplot2::guide_legend(order = 2)
      ) +
        ggplot2::guides(colour = if (wide) "legend" else "none")
    }

    p +
      ggplot2::scale_colour_manual(values = colors, name = NULL, guide = mint_legend_guide(wide)) +
      mint_theme(ctx$style, ctx$family, grid = "both",
                 legend_position = if (wide || has_size) "top" else "none")
  }
))
