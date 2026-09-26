# 山脊图 ridgeline
#
# 每组的核密度曲线沿 y 轴一层层叠起来，同一屏里比较几十个分布的形状。
#
# 配色上刻意避开「一堆撞色」：所有组用同一个色相的不同深浅（mint_ramp），
# 由深到浅对应从下到上 —— 后面（上面）的组颜色淡、前面（下面）的组颜色实，
# 叠在一起时像远山，不会因为撞色而把重叠区域搅成一团。
#
# 组名直接就是 y 轴刻度标签（左侧直标），所以不画图例、也不画 y 方向网格。

MINT_RIDGE_VALUE_KEYS <- c("value", "x", "y", "v", "count", "score", "amount", "n", "num")
MINT_RIDGE_GROUP_KEYS <- c("group", "category", "series", "label", "name", "id")

mint_register(mint_chart(
  id = "ridgeline",
  name = "山脊图",
  english = "Ridgeline",
  category = "distribution",
  description = "把多组核密度曲线叠成山脊，一眼比较多组分布的形状差异",
  data_shape = paste(
    "长表（推荐）：[ { \"group\": \"对照组\", \"value\": 12 } ]",
    "也支持行式多样本 [ { \"group\": \"A\", \"x\": 12, \"y\": 15 } ]（该行数值列都算 A 的观测值）",
    "和只有数值列的 [ { \"x\": 12, \"y\": 15 } ]（每列一组）。",
    "字段名可用 groupKey / valueKey 改写。",
    sep = "\n"
  ),
  variants = c("ridge 山脊", "quantiles 带分位线"),
  aliases = c("山脊图", "脊线图", "峰峦图", "ridgeline", "ridge", "joyplot", "密度分布"),
  packages = c("ggplot2", "ggridges", "scales"),
  options = list(
    mint_option("groupKey", "string", "分组字段名，省略则用第一个文本字段"),
    mint_option("valueKey", "string", "数值字段名，省略则把所有数值列都当作观测值"),
    mint_option("scale", "number", "山脊的重叠高度倍率，越大越互相重叠", default = 1.4),
    mint_option("alpha", "number", "填充透明度", default = 0.7),
    mint_option("showQuantiles", "boolean", "是否标注每组的中位线", default = FALSE),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = local({
      # 固定的近似分位数形状（带一点确定性抖动），造出五条中心逐步右移的分布
      shape <- c(-2.1, -1.9, -1.75, -1.6, -1.5, -1.4, -1.3, -1.2, -1.1, -1, -0.9, -0.8,
                 -0.7, -0.6, -0.5, -0.4, -0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3, 0.4, 0.5,
                 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.75, 1.9, 2.1)
      wobble <- ((seq_along(shape) * 7919) %% 11 - 5) / 40
      spec <- list(
        list(name = "安慰剂", mean = 9, sd = 1.5),
        list(name = "低剂量", mean = 10.4, sd = 1.9),
        list(name = "中剂量", mean = 12.1, sd = 2.3),
        list(name = "高剂量", mean = 14, sd = 3),
        list(name = "极高剂量", mean = 16.6, sd = 3.8)
      )
      unlist(lapply(spec, function(s) {
        lapply(round(s$mean + (shape + wobble) * s$sd, 2), function(v) list(group = s$name, value = v))
      }), recursive = FALSE)
    }),
    options = list(xLegend = "血药浓度（μg/mL）")
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- ctx$data
    if (!is.list(rows) || length(rows) == 0) {
      mint_fail("INVALID_DATA", "ridgeline 的数据为空", "至少给一组观测值")
    }

    if (is.null(names(rows[[1]]))) {
      if (!all(vapply(rows, function(v) is.numeric(v) && length(v) == 1, logical(1)))) {
        mint_fail("INVALID_DATA", "ridgeline 需要对象数组或数值数组",
                  "形如 [{ \"group\": \"对照组\", \"value\": 12 }]")
      }
      data <- data.frame(group = "全部", value = as.numeric(unlist(rows)), stringsAsFactors = FALSE)
    } else {
      frame <- mint_as_rows(rows, "ridgeline")
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
        mint_fail("INVALID_DATA", "ridgeline 里没有数值字段",
                  "形如 [{ \"group\": \"对照组\", \"value\": 12 }]")
      }

      parts <- lapply(value_cols, function(col) {
        data.frame(group = if (is.null(group_key)) col else as.character(frame[[group_key]]),
                   value = as.numeric(frame[[col]]), stringsAsFactors = FALSE)
      })
      data <- do.call(rbind, parts)
    }

    data <- data[!is.na(data$value), , drop = FALSE]
    data <- data[!is.na(data$group), , drop = FALSE]
    if (nrow(data) == 0) {
      mint_fail("INVALID_DATA", "ridgeline 里没有可用的数值", "检查 value 字段是否为数值")
    }

    ids <- unique(data$group)
    # 密度曲线至少需要两个点；单点分组直接说清楚，别让底层去报 "need at least 2 data points"
    counts <- table(data$group)
    few <- names(counts)[counts < 2]
    if (length(few) > 0) {
      mint_fail("INVALID_DATA",
                sprintf("分组「%s」只有 %d 个观测值，估不出密度曲线", few[1], as.integer(counts[[few[1]]])),
                "每组至少要有 2 个观测值；想看形状建议每组 20 个以上")
    }
    # 峰峦图的 y 轴由下往上读，第一条分组在底部
    data$group <- factor(data$group, levels = ids)

    base <- ctx$colors[1]
    # 越往上的组颜色越淡，叠在一起时有远近层次（最淡的一档不能太白，否则会糊掉）
    amounts <- seq(1, 0.45, length.out = length(ids))
    fills <- stats::setNames(vapply(amounts, function(a) mint_tint(base, a), character(1)), ids)

    fmt <- ctx$formatter
    show_quantiles <- isTRUE(o$showQuantiles)

    # 显式给出联合带宽：ggridges 的默认值就是所有组的 bw.nrd0，
    # 但让它自己去猜会在终端打一行 "Picking joint bandwidth of ..."
    bandwidth <- stats::bw.nrd0(data$value)
    if (!is.finite(bandwidth) || bandwidth <= 0) bandwidth <- max(1e-6, diff(range(data$value)) / 20)

    ridge_args <- list(
      mapping = ggplot2::aes(fill = group),
      scale = o$scale %||% 1.4,
      alpha = o$alpha %||% 0.7,
      bandwidth = bandwidth,
      # 山脊的描边要细，否则一排曲线叠起来后满屏都是黑线
      linewidth = ctx$style$geoms$axis_width,
      colour = mint_tint(base, 1),
      rel_min_height = 0.005,
      show.legend = FALSE
    )
    if (show_quantiles) {
      # 只标中位线：25/50/75 三条线在五组山脊上会变成十五条虚线，反而看不清
      ridge_args$quantile_lines <- TRUE
      ridge_args$quantiles <- 2
      ridge_args$vline_linetype <- "solid"
      ridge_args$vline_width <- 0.35
      ridge_args$vline_colour <- mint_tint(base, 1)
    }

    p <- ggplot2::ggplot(data, ggplot2::aes(x = value, y = group)) +
      do.call(ggridges::geom_density_ridges, ridge_args)

    p +
      ggplot2::scale_fill_manual(values = fills, guide = "none") +
      ggplot2::scale_x_continuous(labels = fmt, breaks = mint_breaks(6),
                                  expand = ggplot2::expansion(mult = c(0.01, 0.02))) +
      ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = c(0.12, 0.85))) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "x", legend_position = "none") +
      # 组名就是 y 轴刻度标签，刻度线本身是多余的
      ggplot2::theme(
        axis.ticks.y = ggplot2::element_blank(),
        axis.line.y = ggplot2::element_blank()
      )
  }
))