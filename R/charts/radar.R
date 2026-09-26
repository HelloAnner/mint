# 雷达图 radar —— 在多个维度上对标若干对象
#
# 为什么不用 ggradar：它的默认样式（粗描边、网格花纹、每维都标一遍刻度、大字号）
# 和 mint 的期刊风格正面冲突，逐项覆盖的成本比自己画还高。这里自绘几何：
#   · 同心网格圈与放射轴都是最浅的灰、最细的线 —— 网格只负责读数，不参与表达；
#   · 只有一条竖直轴标数值刻度，一圈都标数字会把图形本身淹掉；
#   · 填充透明度低（默认 0.15，0 即纯描边）、描边细、顶点用小圆点，图形不抢数据。
#
# 为什么不用 coord_polar：极坐标下 y（角度）会被缩放成一个区间，多边形收边时
# 「最后一点 → 第一点」要跨过 0/1 边界，ggplot 的默认插值会绕整圈倒着走，
# 画出来的多边形是错的。这里直接把每个维度算成直角坐标，用 coord_fixed(1:1)
# 保证圆不被拉成椭圆，几何完全可控。

#' 数值轴上限取「好看」的整数，刻度才会落在 20 / 40 / 60 这种读数舒服的位置
mint_radar_axis_max <- function(span, levels) {
  if (!is.finite(span) || span <= 0) return(levels)
  raw <- span / levels
  mag <- 10^floor(log10(raw))
  candidates <- mag * c(1, 2, 2.5, 5, 10)
  candidates[which(candidates >= raw)[1]] * levels
}

mint_register(local({
  chart <- mint_chart(
    id = "radar",
    name = "雷达图",
    english = "Radar",
    category = "comparison",
    description = "在多个维度上同时比较若干对象，适合能力评估、产品对标",
    data_shape = paste(
      "数组，每行一个维度：",
      "[",
      "  { \"dimension\": \"性能\", \"本产品\": 82, \"竞品A\": 68 },",
      "  { \"dimension\": \"易用性\", \"本产品\": 74, \"竞品A\": 88 }",
      "]",
      "除维度字段外的数值字段都会被当成一个比较对象；维度建议 3~8 个。",
      sep = "\n"
    ),
    variants = c("filled 填充", "outline 描边"),
    aliases = c("雷达", "蜘蛛图", "spider", "能力图"),
    packages = c("ggplot2"),
    options = list(
      mint_option("indexBy", "string", "维度字段名"),
      mint_option("keys", "array", "参与比较的对象字段"),
      mint_option("fillOpacity", "number", "填充不透明度，0 为纯描边", default = 0.15),
      mint_option("gridLevels", "number", "网格圈数（数值轴刻度数）", default = 5),
      mint_option("xLegend", "string", "X 轴标题（雷达图没有坐标轴，仅为兼容保留）"),
      mint_option("yLegend", "string", "Y 轴标题（雷达图没有坐标轴，仅为兼容保留）"),
      mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
      mint_option("decimals", "number", "小数位数"),
      mint_option("valuePrefix", "string", "数值前缀"),
      mint_option("valueSuffix", "string", "数值后缀")
    ),
    example = list(
      data = list(
        list(dimension = "性能", `本产品` = 82, `竞品A` = 68),
        list(dimension = "易用性", `本产品` = 74, `竞品A` = 88),
        list(dimension = "价格", `本产品` = 65, `竞品A` = 72),
        list(dimension = "生态", `本产品` = 90, `竞品A` = 60),
        list(dimension = "服务", `本产品` = 78, `竞品A` = 70),
        list(dimension = "口碑", `本产品` = 84, `竞品A` = 75)
      ),
      options = list(fillOpacity = 0.15)
    ),
    render = function(ctx) {
      o <- ctx$options
      rows <- mint_as_rows(ctx$data, "radar")
      ik <- mint_infer_index_keys(rows, o$indexBy, o$keys, "radar")
      long <- mint_melt(rows, ik$indexBy, ik$keys)
      keys <- ik$keys
      dims <- levels(long$index)
      n_dim <- length(dims)
      if (n_dim < 3) {
        mint_fail("INVALID_DATA", sprintf("雷达图至少需要 3 个维度，收到 %d 个", n_dim),
                  "维度太少连不成多边形，这种情况用 bar 更清楚")
      }
      if (anyNA(long$value)) {
        miss <- long[which(is.na(long$value))[1], , drop = FALSE]
        mint_fail("INVALID_DATA", sprintf("「%s」在维度「%s」上没有数值", miss$series, miss$index),
                  "雷达图的多边形必须闭合，每个维度都要有值")
      }

      fmt <- ctx$formatter
      ty <- ctx$style$type
      gm <- ctx$style$geoms

      # 负数（例如同比增速）没法直接用半径表达：把整条数值轴平移到最低值，
      # 半径表示「相对最低值」的高低，刻度数字仍然标原始值，读者不会读错。
      offset <- min(0, min(long$value))
      levels_n <- max(2L, min(10L, as.integer(round(o$gridLevels %||% 5))))
      step <- mint_radar_axis_max(max(long$value) - offset, levels_n) / levels_n
      rmax <- step * levels_n

      # 第一维在正上方，顺时针排（和旧版 nivo 一致，用户对照旧图不会看错）
      sigma <- pi / 2 - 2 * pi * (seq_len(n_dim) - 1) / n_dim
      radius <- long$value - offset
      vertex <- data.frame(
        series = long$series,
        x = radius * cos(sigma[match(long$index, dims)]),
        y = radius * sin(sigma[match(long$index, dims)]),
        stringsAsFactors = FALSE
      )

      # 标签按角度决定朝哪边伸展：cos 决定横向（0=向右排、1=向左排）、
      # sin 决定上下 —— 这样标签框的内角始终落在圈外，不会压到网格和图形。
      # 注意这一版 ggplot2 的 vjust 是「相对锚点的偏移」：
      # -1 表示整块文字落在锚点上方、1 表示落在下方、0 表示居中。
      hjust <- ifelse(cos(sigma) > 0.2, 0, ifelse(cos(sigma) < -0.2, 1, 0.5))
      vjust <- ifelse(sin(sigma) > 0.2, -1, ifelse(sin(sigma) < -0.2, 1, 0))

      outer <- rmax * 1.30     # 外圈之外留出维度标签的位置
      label_r <- rmax * 1.01   # 标签贴着外圈放，留出尽可能多的折行宽度
      # 正上方那条轴要留出刻度数字的位置，这上的维度标签再多让一点
      label_r_vec <- ifelse(sin(sigma) > 0.9, rmax * 1.06, label_r)
      room_in <- (outer - label_r) / outer * 0.5 * min(ctx$width, ctx$height)
      wrap_pt <- max(30, room_in * 72)

      show_legend <- !identical(o$legend, FALSE) && length(keys) > 1
      colors <- stats::setNames(mint_colors(length(keys), ctx$colors), keys)
      fill_alpha <- max(0, min(1, o$fillOpacity %||% 0.15))

      # 网格圈：采样成折线，点数够多时肉眼就是圆
      theta <- seq(0, 2 * pi, length.out = 181)
      ring_r <- step * seq_len(levels_n)
      rings <- do.call(rbind, lapply(ring_r, function(r) {
        data.frame(ring = r, x = r * cos(theta), y = r * sin(theta))
      }))
      spokes <- data.frame(
        x = 0, y = 0,
        xend = rmax * cos(sigma), yend = rmax * sin(sigma)
      )
      dim_labels <- data.frame(
        x = label_r_vec * cos(sigma), y = label_r_vec * sin(sigma),
        label = mint_wrap(dims, wrap_pt, size = ty$data_label),
        hjust = hjust, vjust = vjust, stringsAsFactors = FALSE
      )
      # 刻度只沿正上方那条竖直轴排：统一往右挪一点、文字挂在刻度下方，
      # 既不压住轴上的顶点圆点，也不会和顶部的维度标签挤在一起
      tick_labels <- data.frame(x = rmax * 0.035, y = ring_r, label = fmt(offset + ring_r))

      # 图例色块用实色：填充图层带透明度，不覆盖的话图例淡到看不见
      guide <- if (show_legend) ggplot2::guide_legend(override.aes = list(alpha = 1)) else "none"

      ggplot2::ggplot(vertex) +
        ggplot2::geom_path(
          data = rings, ggplot2::aes(x = x, y = y, group = ring),
          colour = ctx$grid, linewidth = gm$grid_width
        ) +
        ggplot2::geom_segment(
          data = spokes, ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
          colour = ctx$grid, linewidth = gm$grid_width
        ) +
        # 填充与描边分成两层：填充带透明度，描边保持实色，线才立得住
        ggplot2::geom_polygon(
          ggplot2::aes(x = x, y = y, group = series, fill = series),
          alpha = fill_alpha, colour = NA
        ) +
        ggplot2::geom_polygon(
          ggplot2::aes(x = x, y = y, group = series, colour = series),
          fill = NA, linewidth = gm$line_width, show.legend = FALSE
        ) +
        ggplot2::geom_point(
          ggplot2::aes(x = x, y = y, colour = series),
          size = gm$point_size, stroke = 0, show.legend = FALSE
        ) +
        ggplot2::geom_text(
          data = dim_labels,
          ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust),
          size = ty$data_label / ggplot2::.pt, colour = ctx$text, lineheight = 1.15
        ) +
        ggplot2::geom_text(
          data = tick_labels, ggplot2::aes(x = x, y = y, label = label),
          hjust = 0, vjust = 1, size = ty$axis_text / ggplot2::.pt, colour = ctx$muted
        ) +
        ggplot2::scale_fill_manual(values = colors, name = NULL, guide = guide) +
        ggplot2::scale_colour_manual(values = colors, guide = "none") +
        ggplot2::scale_x_continuous(limits = c(-outer, outer), expand = c(0, 0)) +
        ggplot2::scale_y_continuous(limits = c(-outer, outer), expand = c(0, 0)) +
        ggplot2::coord_fixed(ratio = 1, clip = "off") +
        mint_theme(ctx$style, ctx$family, grid = "none",
                   legend_position = if (show_legend) "top" else "none") +
        ggplot2::theme(
          axis.line = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          axis.text = ggplot2::element_blank(),
          axis.title = ggplot2::element_blank()
        )
    }
  )
  # 圆形图：默认的 7×4.35 画布会把雷达挤成小圆、两侧留一大片空白。
  # spec.R 对声明了 aspect 的图表按宽度换算画布高度（它的注释里举的例子正是雷达）。
  chart$aspect <- 1.12
  chart
}))
