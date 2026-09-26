# 河流图 / 堆叠面积图 stream
#
# 这张图的难点在「对称河流」：每一层的上下边界都要自己按累积偏移算出来，
# 不能交给 position_stack() —— 它只会把东西从 0 往上堆。所以这里手工构造每层的
# [ymin, ymax] 区间，再用 geom_ribbon 逐层画。
#
# 描边单独一层、不用 ribbon 自带的 colour：相邻层共享一条边，若各自描边，
# 后画的填充会把先画的描边盖掉一半，线条就会半明半暗。分成「填充层 + 描边层」最干净。
#
# 配色有意降饱和（mint_tint(·, 0.8)）：河流图是大色块，全饱和色叠在一起会压过数据本身。

mint_register(mint_chart(
  id = "stream",
  name = "河流图",
  english = "Stream",
  category = "trend",
  description = "按时间把多个系列堆叠起来，同时读总量走势与内部结构占比的漂移",
  data_shape = paste(
    "两种写法都支持：",
    "1) 行式（推荐）：[ { \"month\": \"1月\", \"自然搜索\": 320, \"社交媒体\": 180 } ]",
    "2) 系列式：[ { \"id\": \"自然搜索\", \"data\": [ { \"x\": \"1月\", \"y\": 320 } ] } ]",
    "除第一个字符串字段外，其余数值字段都会按顺序堆叠。",
    sep = "\n"
  ),
  variants = c("stacked 堆叠", "symmetric 对称河流", "expand 百分比堆叠"),
  aliases = c("堆叠面积图", "面积图", "河流图", "streamgraph", "stacked area", "areachart"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("offsetType", "string", "堆叠方式", default = "none", values = c("none", "expand", "silhouette", "wiggle")),
    mint_option("baseline", "string", "基线", default = "zero", values = c("zero", "symmetric")),
    mint_option("indexBy", "string", "时间/分类字段名"),
    mint_option("keys", "array", "参与堆叠的数值字段"),
    mint_option("fillOpacity", "number", "填充不透明度", default = 0.88),
    mint_option("labelSeries", "string", "系列名标注方式", default = "auto", values = c("auto", "end", "legend", "none")),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(month = "1月", `自然搜索` = 320, `社交媒体` = 180, `直接访问` = 140),
      list(month = "2月", `自然搜索` = 345, `社交媒体` = 205, `直接访问` = 152),
      list(month = "3月", `自然搜索` = 372, `社交媒体` = 236, `直接访问` = 168),
      list(month = "4月", `自然搜索` = 410, `社交媒体` = 268, `直接访问` = 175),
      list(month = "5月", `自然搜索` = 448, `社交媒体` = 305, `直接访问` = 192)
    ),
    options = list(yLegend = "访问量（万次）", xLegend = "2025 年")
  ),
  render = function(ctx) {
    o <- ctx$options
    series <- mint_as_series(ctx$data, "stream", o$indexBy, o$keys)
    ids <- vapply(series, function(s) s$id, character(1))
    x_levels <- unique(unlist(lapply(series, function(s) s$x)))
    n <- length(x_levels)
    m <- length(ids)
    if (n == 0 || m == 0) {
      mint_fail("INVALID_DATA", "stream 至少需要一个时间点和一个数值系列",
                "形如 [{ \"month\": \"1月\", \"系列A\": 100, \"系列B\": 60 }]")
    }
    if (n < 2) {
      mint_fail("INVALID_DATA", "河流图至少需要两个时间点",
                "面积/河流图靠两点之间连成带状；只有一个时间点时请改用柱状图或饼图")
    }

    # 把每个系列对齐到统一的时间轴；某系列缺某个时间点时按 0 计（堆叠图里等价于缺席）
    mat <- matrix(0, nrow = n, ncol = m)
    for (j in seq_len(m)) {
      v <- series[[j]]$y[match(x_levels, series[[j]]$x)]
      v[is.na(v)] <- 0
      mat[, j] <- v
    }
    if (any(mat < 0)) {
      mint_fail("INVALID_DATA", "河流图要求所有数值非负",
                "堆叠面积图只能从基线往一侧累加；含负值时请改用折线图，或先取绝对值")
    }
    if (max(mat) <= 0) {
      mint_fail("INVALID_DATA", "河流图的所有数值都是 0",
                "堆叠面积图需要有正的数值，否则画出来没有任何信息")
    }

    offset <- o$offsetType %||% "none"
    expand <- identical(offset, "expand")
    if (expand) {
      totals0 <- rowSums(mat)
      mat <- mat / ifelse(totals0 > 0, totals0, 1)
    }
    totals <- rowSums(mat)
    symmetric <- identical(o$baseline, "symmetric") || offset %in% c("silhouette", "wiggle")
    base <- if (symmetric) mint_stream_baseline(totals, offset) else rep(0, n)

    long <- do.call(rbind, lapply(seq_len(m), function(j) {
      below <- if (j == 1) rep(0, n) else rowSums(mat[, seq_len(j - 1), drop = FALSE])
      ymin <- base + below
      data.frame(x = seq_len(n), series = ids[j], ymin = ymin, ymax = ymin + mat[, j],
                 stringsAsFactors = FALSE)
    }))
    long$series <- factor(long$series, levels = ids)

    fmt <- ctx$formatter
    base_colors <- stats::setNames(mint_colors(m, ctx$colors), ids)
    fill_colors <- stats::setNames(vapply(base_colors, mint_tint, character(1), amount = 0.8), ids)

    label_mode <- o$labelSeries %||% "auto"
    if (identical(label_mode, "auto")) label_mode <- if (m <= 6) "end" else "legend"
    show_legend <- !identical(o$legend, FALSE) && identical(label_mode, "legend")

    p <- ggplot2::ggplot(long, ggplot2::aes(x = x, ymin = ymin, ymax = ymax)) +
      ggplot2::geom_ribbon(ggplot2::aes(fill = series), colour = NA,
                           alpha = o$fillOpacity %||% 0.88) +
      # 描边层要显式 show.legend：填充层的图例被 guide="none" 关掉了，
      # 若这里也关，颜色色标就再也没有图例键可画（会退化成空图例）
      ggplot2::geom_ribbon(ggplot2::aes(colour = series), fill = NA, linewidth = 0.35,
                           show.legend = TRUE)

    # 对称河流围绕 0 展开，画一条 0 基线帮助读数
    if (symmetric) {
      p <- p + ggplot2::geom_hline(yintercept = 0, colour = ctx$ref, linewidth = 0.3,
                                   inherit.aes = FALSE)
    }

    # 末端直标：层太多时标签会挤在一起，超过 6 个系列就退回图例
    if (identical(label_mode, "end")) {
      last <- long[long$x == n, , drop = FALSE]
      labels <- data.frame(x = n, y = (last$ymin + last$ymax) / 2, series = last$series,
                           stringsAsFactors = FALSE)
      p <- p + ggplot2::geom_text(
        data = labels, ggplot2::aes(x = x, y = y, label = series, colour = series),
        hjust = 0, nudge_x = 0.16, inherit.aes = FALSE,
        size = ctx$style$type$data_label / ggplot2::.pt, show.legend = FALSE
      )
    }

    # 时间标签太长时「抽稀刻度」而不是旋转：旋转后的文字会把整个图表区撑爆
    # （mint 的版心高度是固定的，超出的部分会被裁掉）
    x_label_size <- ctx$style$type$axis_text
    label_pt <- vapply(x_levels, mint_text_width, numeric(1), size = x_label_size)
    slot_pt <- max(1, (ctx$width - 0.6) * 72 / n)
    step <- max(1L, as.integer(ceiling(max(label_pt) / slot_pt)))
    tick_idx <- seq(1L, n, by = step)

    # 首尾刻度的标签有一半探出面板，用数据单位的留白把它接住；只有刻度正好落在
    # 两端时才需要留白，中间刻度不会溢出
    plot_w_in <- max(1, ctx$width - 0.55)
    x_unit_in <- plot_w_in / max(1, n - 1)
    widest_in <- max(label_pt[tick_idx]) / 72
    half_units <- max(0.08, min(0.3 * (n - 1), 0.5 * widest_in / x_unit_in))
    pad_units <- if (tick_idx[1] == 1L) half_units else 0.08
    right_units <- if (tick_idx[length(tick_idx)] == n) half_units else 0.08
    if (identical(label_mode, "end")) right_units <- max(right_units, 0.14 * (n - 1))

    p <- p +
      ggplot2::scale_fill_manual(values = fill_colors, guide = "none") +
      ggplot2::scale_colour_manual(values = base_colors, name = NULL,
                                   guide = mint_legend_guide(show_legend)) +
      ggplot2::scale_x_continuous(
        breaks = tick_idx, labels = x_levels[tick_idx],
        expand = ggplot2::expansion(add = c(pad_units, right_units))
      ) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "y",
                 legend_position = if (show_legend) "top" else "none")

    if (expand) {
      # 百分比堆叠：每列合计恒为 1，纵轴直接按百分比读数
      p <- p + ggplot2::scale_y_continuous(
        limits = c(0, 1), breaks = seq(0, 1, 0.25),
        labels = function(v) sprintf("%.0f%%", v * 100),
        expand = ggplot2::expansion(mult = c(0, 0.02))
      )
    } else {
      p <- p + ggplot2::scale_y_continuous(labels = fmt, breaks = mint_breaks(6),
                                           expand = ggplot2::expansion(mult = c(0.02, 0.06)))
    }
    p
  }
))

#' 对称河流的基线
#'
#' silhouette 就是「围绕每列合计的中点」铺开；wiggle 在此基础上把基线做一次
#' 三点平滑（并保持总面积不变），让整条河流更少上下抖动 —— 这是 streamgraph 的经典形态。
mint_stream_baseline <- function(totals, offset = "silhouette") {
  n <- length(totals)
  centered <- -totals / 2
  if (n < 3 || !identical(offset, "wiggle")) return(centered)
  smoothed <- centered
  for (i in 2:(n - 1)) smoothed[i] <- mean(centered[(i - 1):(i + 1)])
  # 平滑会改变总面积，这里整体平移回去，避免河流漂离原来的位置
  smoothed - mean(smoothed) + mean(centered)
}
