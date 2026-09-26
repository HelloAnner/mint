# 箱线图 boxplot
#
# 期刊里箱线图的读法：中位线是主角，箱体次之，须线最轻。
# 所以线宽要分层 —— 中位线 0.6pt、箱体与须线 0.4pt，一眼就能看出中位数在哪。
#
# 颜色上刻意不按组换色：同一张图里比较的是同一个变量的分布，
# 颜色在这里不携带信息，用一组调色板的浅色即可，避免变成彩虹图。
# 但为了和其余图表保持一致的「分组色」惯例，仍然按组从调色板取色，
# 浅色填充 + 深色描边，黑白打印后也还能靠箱体位置区分。

MINT_BOXPLOT_VALUE_KEYS <- c("value", "x", "y", "v", "count", "score", "amount", "n", "num")
MINT_BOXPLOT_GROUP_KEYS <- c("group", "category", "series", "label", "name", "id")

mint_register(mint_chart(
  id = "boxplot",
  name = "箱线图",
  english = "Boxplot",
  category = "distribution",
  description = "比较若干组数据的分布：中位数、四分位距、离群点",
  data_shape = paste(
    "三种写法都支持：",
    "1) 长表（推荐）：[ { \"group\": \"对照组\", \"value\": 12 } ]",
    "2) 行式多样本：[ { \"group\": \"对照组\", \"x\": 12, \"y\": 15 } ]，该行所有数值列都算这组的观测值",
    "3) 只有数值列：[ { \"x\": 12, \"y\": 15 } ]，每列一个箱体",
    "字段名可用 groupKey / valueKey 改写。",
    sep = "\n"
  ),
  variants = c("box 箱线", "strip 带散点", "notch 带凹槽"),
  aliases = c("箱线图", "盒须图", "箱形图", "boxplot", "box", "分布对比"),
  packages = c("ggplot2", "scales", "ggbeeswarm"),
  options = list(
    mint_option("groupKey", "string", "分组字段名，省略则用第一个文本字段"),
    mint_option("valueKey", "string", "数值字段名，省略则把所有数值列都当作观测值"),
    mint_option("showPoints", "boolean", "是否叠加蜂群散点", default = FALSE),
    mint_option("showOutliers", "boolean", "是否画出离群点", default = FALSE),
    mint_option("notch", "boolean", "是否使用凹槽（中位数置信区间）", default = FALSE),
    mint_option("sort", "string", "按中位数排序", default = "desc", values = c("desc", "asc", "none")),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = local({
      # 固定分位数形状：四个组的中心与离散程度各不相同，形态像真实测量值
      shape <- c(-1.8, -1.4, -1.15, -1, -0.85, -0.7, -0.55, -0.45, -0.35, -0.25, -0.15,
                 -0.05, 0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.7, 0.85, 1, 1.15, 1.4, 1.8)
      spec <- list(
        list(name = "对照组", mean = 12, sd = 2.4),
        list(name = "低剂量", mean = 13.6, sd = 3),
        list(name = "中剂量", mean = 16.2, sd = 3.6),
        list(name = "高剂量", mean = 18.4, sd = 5.2)
      )
      unlist(lapply(spec, function(s) {
        lapply(round(s$mean + shape * s$sd, 1), function(v) list(group = s$name, value = v))
      }), recursive = FALSE)
    }),
    options = list(yLegend = "响应值（mg/L）")
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- ctx$data
    if (!is.list(rows) || length(rows) == 0) {
      mint_fail("INVALID_DATA", "boxplot 的数据为空", "至少给一组观测值")
    }
    if (is.null(names(rows[[1]]))) {
      # 纯数值数组当作一组观测值
      if (!all(vapply(rows, function(v) is.numeric(v) && length(v) == 1, logical(1)))) {
        mint_fail("INVALID_DATA", "boxplot 需要对象数组或数值数组",
                  "形如 [{ \"group\": \"对照组\", \"value\": 12 }]")
      }
      data <- data.frame(group = "全部", value = as.numeric(unlist(rows)), stringsAsFactors = FALSE)
    } else {
      frame <- mint_as_rows(rows, "boxplot")
      fields <- names(frame)

      group_key <- o$groupKey %||% NULL
      if (!is.null(group_key) && !group_key %in% fields) {
        mint_fail("INVALID_DATA", sprintf("数据里没有分组字段「%s」", group_key),
                  sprintf("可用字段：%s", paste(fields, collapse = ", ")))
      }
      if (is.null(group_key)) {
        chr <- fields[vapply(frame[fields], function(col) is.character(col) || is.factor(col), logical(1))]
        group_key <- if (length(chr) > 0) chr[1] else NULL
      }

      value_key <- o$valueKey %||% NULL
      if (!is.null(value_key) && !value_key %in% fields) {
        mint_fail("INVALID_DATA", sprintf("数据里没有数值字段「%s」", value_key),
                  sprintf("可用字段：%s", paste(fields, collapse = ", ")))
      }
      numeric_fields <- fields[vapply(frame[fields], is.numeric, logical(1))]
      value_cols <- if (!is.null(value_key)) value_key else setdiff(numeric_fields, group_key)
      if (length(value_cols) == 0) {
        mint_fail("INVALID_DATA", "boxplot 里没有数值字段",
                  "形如 [{ \"group\": \"对照组\", \"value\": 12 }]")
      }

      if (is.null(group_key)) {
        # 只有数值列：每列一个箱体，比较不同变量的分布
        parts <- lapply(value_cols, function(col) {
          data.frame(group = col, value = as.numeric(frame[[col]]), stringsAsFactors = FALSE)
        })
      } else {
        # 有分组列：把该行的每个数值列都算作这组的观测值
        parts <- lapply(value_cols, function(col) {
          data.frame(group = as.character(frame[[group_key]]),
                     value = as.numeric(frame[[col]]), stringsAsFactors = FALSE)
        })
      }
      data <- do.call(rbind, parts)
    }

    data <- data[!is.na(data$value), , drop = FALSE]
    if (nrow(data) == 0) {
      mint_fail("INVALID_DATA", "boxplot 里没有可用的数值", "检查 value 字段是否为数值")
    }

    ids <- unique(data$group)
    data$group <- factor(data$group, levels = ids)

    # 默认按中位数排序：读者不用自己来回找哪组高哪组低
    if (o$sort %in% c("desc", "asc")) {
      medians <- vapply(ids, function(g) stats::median(data$value[data$group == g]), numeric(1))
      ord <- order(medians, decreasing = identical(o$sort, "desc"))
      data$group <- factor(data$group, levels = ids[ord])
    }

    colors <- stats::setNames(mint_colors(length(ids), ctx$colors), ids)
    fills <- stats::setNames(vapply(colors, function(c) mint_tint(c, 0.5), character(1)), ids)
    fmt <- ctx$formatter
    point_colour <- mint_tint(ctx$colors[1], 0.85)

    p <- ggplot2::ggplot(data, ggplot2::aes(x = group, y = value, fill = group))

    # 散点先画：叠在箱体上时点才不会被箱体压住
    if (isTRUE(o$showPoints)) {
      p <- p + ggbeeswarm::geom_quasirandom(
        width = 0.3, size = 0.8, alpha = 0.5, colour = point_colour,
        stroke = 0, show.legend = FALSE
      )
    }

    # 中位线要比箱体粗：ggplot2 4.0 起用 median.linewidth 单独给值，
    # 3.x 只能靠 fatten 倍数放大（4.0 里 fatten 已弃用，会打警告）
    median_args <- if ("median.linewidth" %in% names(formals(ggplot2::geom_boxplot))) {
      list(median.linewidth = 0.6)
    } else {
      list(fatten = 1.5)
    }

    p <- p + do.call(ggplot2::geom_boxplot, c(
      list(mapping = ggplot2::aes(colour = group),
           width = 0.62,
           notch = isTRUE(o$notch),
           notchwidth = 0.5,
           linewidth = ctx$style$geoms$axis_width,
           outlier.shape = if (isTRUE(o$showOutliers)) 1 else NA,
           outlier.size = 0.9,
           outlier.stroke = 0.3,
           outlier.colour = point_colour,
           show.legend = FALSE),
      median_args
    ))

    p +
      ggplot2::scale_fill_manual(values = fills, guide = "none") +
      ggplot2::scale_colour_manual(values = colors, guide = "none") +
      ggplot2::scale_y_continuous(labels = fmt, breaks = mint_breaks(6),
                                  expand = ggplot2::expansion(mult = c(0.05, 0.06))) +
      ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = 0.55)) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "y", legend_position = "none")
  }
))