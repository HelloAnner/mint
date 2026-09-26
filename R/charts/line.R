# 折线图 line
#
# 期刊里折线图的标准做法：细线、只标必要的点、系列名直接贴在右端而不是靠图例来回找。
# 系列数 <= 4 时默认用「末端直标」，更多系列才回退到图例。

mint_register(mint_chart(
  id = "line",
  name = "折线图",
  english = "Line",
  category = "trend",
  description = "展示数值随时间的走势，可多系列对比、可填充面积",
  data_shape = paste(
    "两种写法都支持：",
    "1) 行式（推荐）：[ { \"month\": \"1月\", \"本期\": 12, \"上期\": 9 } ]",
    "2) 系列式：[ { \"id\": \"本期\", \"data\": [ { \"x\": \"1月\", \"y\": 12 } ] } ]",
    sep = "\n"
  ),
  variants = c("line 折线", "area 面积", "step 阶梯"),
  aliases = c("line", "折线图", "曲线图", "走势图", "趋势图", "area", "面积图"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("indexBy", "string", "X 轴字段名"),
    mint_option("keys", "array", "参与绘制的数值字段"),
    mint_option("area", "boolean", "是否填充面积", default = FALSE),
    mint_option("points", "boolean", "是否画数据点", default = FALSE),
    mint_option("curve", "string", "线型", default = "linear", values = c("linear", "step")),
    mint_option("labelSeries", "string", "系列名标注方式", default = "auto", values = c("auto", "end", "legend", "none")),
    mint_option("yZero", "boolean", "Y 轴是否从 0 开始", default = FALSE),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(month = "1月", `本期` = 328, `上期` = 296),
      list(month = "2月", `本期` = 300, `上期` = 268),
      list(month = "3月", `本期` = 365, `上期` = 312),
      list(month = "4月", `本期` = 402, `上期` = 340),
      list(month = "5月", `本期` = 388, `上期` = 356),
      list(month = "6月", `本期` = 445, `上期` = 372)
    ),
    options = list(yLegend = "活跃用户（万）", xLegend = "2025 年", points = TRUE)
  ),
  render = function(ctx) {
    o <- ctx$options
    series <- mint_as_series(ctx$data, "line", o$indexBy, o$keys)
    ids <- vapply(series, function(s) s$id, character(1))
    x_values <- unique(unlist(lapply(series, function(s) s$x)))

    x_numeric <- suppressWarnings(as.numeric(x_values))
    numeric_axis <- !any(is.na(x_numeric)) && length(unique(x_numeric)) == length(x_numeric)

    long <- do.call(rbind, lapply(series, function(s) {
      data.frame(
        x = if (numeric_axis) as.numeric(s$x) else as.character(s$x),
        series = s$id, value = s$y, stringsAsFactors = FALSE
      )
    }))
    if (!numeric_axis) long$x <- factor(long$x, levels = x_values)

    fmt <- ctx$formatter
    colors <- stats::setNames(mint_colors(length(ids), ctx$colors), ids)
    label_mode <- o$labelSeries %||% "auto"
    if (identical(label_mode, "auto")) label_mode <- if (length(ids) <= 4) "end" else "legend"
    show_legend <- !identical(o$legend, FALSE) && !identical(label_mode, "none") && identical(label_mode, "legend")
    fill <- identical(o$area, TRUE)
    step <- identical(o$curve, "step")

    p <- ggplot2::ggplot(long, ggplot2::aes(x = x, y = value, colour = series, group = series))

    if (fill) {
      p <- p + ggplot2::geom_area(ggplot2::aes(fill = series), alpha = ctx$style$geoms$area_alpha,
                                  colour = NA, show.legend = FALSE, position = "identity")
    }
    p <- if (step) {
      p + ggplot2::geom_step(linewidth = ctx$style$geoms$line_width)
    } else {
      p + ggplot2::geom_line(linewidth = ctx$style$geoms$line_width)
    }
    if (isTRUE(o$points) || (!numeric_axis && length(x_values) <= 12)) {
      p <- p + ggplot2::geom_point(size = ctx$style$geoms$point_size, stroke = 0,
                                   show.legend = FALSE)
    }

    # 末端直标：把系列名贴在最后一点右侧，省掉图例
    if (identical(label_mode, "end")) {
      last <- do.call(rbind, lapply(series, function(s) {
        data.frame(
          x = if (numeric_axis) as.numeric(s$x[length(s$x)]) else factor(s$x[length(s$x)], levels = x_values),
          value = s$y[length(s$y)], series = s$id, stringsAsFactors = FALSE
        )
      }))
      p <- p + ggplot2::geom_text(
        data = last, ggplot2::aes(x = x, y = value, label = series, colour = series),
        hjust = 0,
        nudge_x = if (numeric_axis) diff(range(long$x)) * 0.02 else 0.18,
        size = ctx$style$type$data_label / ggplot2::.pt, show.legend = FALSE
      )
    }

    if (numeric_axis) {
      span <- diff(range(long$x))
      p <- p + ggplot2::scale_x_continuous(
        expand = ggplot2::expansion(mult = c(0.02, if (identical(label_mode, "end")) 0.16 else 0.02))
      )
    } else {
      p <- p + ggplot2::scale_x_discrete(
        expand = ggplot2::expansion(mult = c(0.02, if (identical(label_mode, "end")) 0.12 else 0.02))
      )
    }

    # Y 轴：按专业习惯留一点余量；yZero 时强制含 0
    y_range <- range(long$value, na.rm = TRUE)
    if (isTRUE(o$yZero)) {
      p <- p + ggplot2::scale_y_continuous(
        labels = fmt, breaks = mint_breaks(6),
        limits = c(min(0, y_range[1]), y_range[2]),
        expand = ggplot2::expansion(mult = c(0, 0.06))
      )
    } else {
      p <- p + ggplot2::scale_y_continuous(
        labels = fmt, breaks = mint_breaks(6),
        expand = ggplot2::expansion(mult = c(0.06, 0.08))
      )
    }

    if (fill) {
      p <- p + ggplot2::scale_fill_manual(values = colors, guide = "none")
    }

    p +
      ggplot2::scale_colour_manual(values = colors, name = NULL, guide = mint_legend_guide(show_legend)) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "y",
                 legend_position = if (show_legend) "top" else "none")
  }
))
