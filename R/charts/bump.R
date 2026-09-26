# 排名变化图 bump
#
# 排名图的读法：谁在什么时候超过了谁。因此
#   * y 轴按名次反向（1 在顶部），而不是按值正向；
#   * 每个对象一条折线 + 每个时间点一个实心圆点；
#   * 名字直接贴在末端（必要时两端都贴），不用图例 —— 排名的关键信息就是「哪条线是谁」。
#
# 自己用 geom_line + geom_point + geom_text 画，不依赖 ggbump：
# ggbump 会引入自己的主题与间距，反而不好对齐 mint 的版心。

mint_register(mint_chart(
  id = "bump",
  name = "排名变化图",
  english = "Bump",
  category = "trend",
  description = "用交叉的线条展示多个对象在名次上的此消彼长，比折线更适合看排名",
  data_shape = paste(
    "两种写法都支持：",
    "1) 系列式（推荐）：[ { \"id\": \"产品A\", \"data\": [ { \"x\": \"1月\", \"y\": 3 } ] } ]",
    "2) 行式：[ { \"period\": \"2023\", \"产品A\": 3, \"产品B\": 1 } ]",
    "y 是名次，数字越小越靠上；若传的是分数而非名次，打开 reverseRank。",
    sep = "\n"
  ),
  variants = c("bump 折线排名", "area 面积排名"),
  aliases = c("排名图", "排名变化图", "名次变化", "bump", "ranking"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("variant", "string", "形态", default = "bump", values = c("bump", "area")),
    mint_option("reverseRank", "boolean", "值为分数而非名次：打开后数值越大越靠上", default = FALSE),
    mint_option("indexBy", "string", "时间字段名"),
    mint_option("keys", "array", "参与绘制的对象字段"),
    mint_option("pointSize", "number", "数据点大小", default = 8),
    mint_option("labelSeries", "string", "对象名标注方式", default = "auto", values = c("auto", "end", "both", "legend", "none")),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "产品A", data = list(list(x = "1月", y = 3), list(x = "2月", y = 2), list(x = "3月", y = 1), list(x = "4月", y = 1))),
      list(id = "产品B", data = list(list(x = "1月", y = 1), list(x = "2月", y = 1), list(x = "3月", y = 3), list(x = "4月", y = 4))),
      list(id = "产品C", data = list(list(x = "1月", y = 2), list(x = "2月", y = 3), list(x = "3月", y = 2), list(x = "4月", y = 2))),
      list(id = "产品D", data = list(list(x = "1月", y = 4), list(x = "2月", y = 4), list(x = "3月", y = 4), list(x = "4月", y = 3)))
    ),
    options = list(xLegend = "2025 年", yLegend = "名次")
  ),
  render = function(ctx) {
    o <- ctx$options
    series <- mint_as_series(ctx$data, "bump", o$indexBy, o$keys)
    ids <- vapply(series, function(s) s$id, character(1))
    x_levels <- unique(unlist(lapply(series, function(s) s$x)))
    n <- length(x_levels)
    m <- length(ids)
    if (n == 0 || m == 0) {
      mint_fail("INVALID_DATA", "bump 至少需要一个时间点和一个对象",
                "形如 [{ \"id\": \"产品A\", \"data\": [{ \"x\": \"1月\", \"y\": 3 }] }]")
    }
    if (n < 2) {
      mint_fail("INVALID_DATA", "排名变化图至少需要两个时间点",
                "只有一个时间点时没有「变化」可看，请改用柱状图直接比较名次")
    }

    # x 统一成整数位置，末端直标才好按坐标右移；缺点的对象只连自己有的时间点
    rows <- lapply(seq_len(m), function(j) {
      pos <- match(series[[j]]$x, x_levels)
      keep <- !is.na(pos) & !is.na(series[[j]]$y)
      if (!any(keep)) return(NULL)
      data.frame(x = pos[keep], series = ids[j], value = series[[j]]$y[keep], stringsAsFactors = FALSE)
    })
    long <- do.call(rbind, rows)
    if (is.null(long) || nrow(long) == 0) {
      mint_fail("INVALID_DATA", "bump 没有可用的数值点", "每个系列至少要有一个 { \"x\": ..., \"y\": ... } 点")
    }
    long$series <- factor(long$series, levels = ids)

    fmt <- ctx$formatter
    colors <- stats::setNames(mint_colors(m, ctx$colors), ids)
    band_fill <- stats::setNames(vapply(colors, mint_tint, character(1), amount = 0.45), ids)
    reverse_rank <- isTRUE(o$reverseRank)
    draw_area <- identical(o$variant, "area")

    # 面积形态：每个时间点先按名次排序，用相邻名次的「中点」当带子边界。
    # 这样同一列里各带子严丝合缝、互不重叠，两条线交叉时带子会自然收成细腰 ——
    # 这正是 area-bump 的经典形态。（等厚带子会又重叠又冲出坐标轴范围。）
    band_low <- rep(NA_real_, nrow(long))
    band_high <- rep(NA_real_, nrow(long))
    if (draw_area) {
      distinct <- sort(unique(long$value))
      gaps <- diff(distinct)
      gaps <- gaps[gaps > 1e-9]
      pitch <- if (length(gaps) > 0) min(gaps) else max(diff(range(long$value)), 1) / max(m - 1, 1)
      if (!is.finite(pitch) || pitch <= 0) pitch <- 0.5
      for (k in seq_len(n)) {
        rows_k <- which(long$x == k)
        v <- long$value[rows_k]
        km <- length(v)
        if (km == 1) {
          lo <- v - pitch / 2
          hi <- v + pitch / 2
        } else {
          sv <- sort(v)
          d <- diff(sv)
          d[d <= 1e-9] <- pitch # 名次并列时用最小间距顶开，避免带子被压成 0 高
          edges <- c(sv[1] - d[1] / 2, (sv[-km] + sv[-1]) / 2, sv[km] + d[km - 1] / 2)
          rk <- rank(v, ties.method = "first")
          lo <- edges[rk]
          hi <- edges[rk + 1L]
        }
        # 带子之间留一点缝，否则相邻带子糊成一片
        mid <- (lo + hi) / 2
        half <- (hi - lo) / 2 * 0.92
        band_low[rows_k] <- mid - half
        band_high[rows_k] <- mid + half
      }
    }

    point_size <- ctx$style$geoms$point_size * ((o$pointSize %||% 8) / 8)
    label_size <- ctx$style$type$data_label / ggplot2::.pt

    p <- ggplot2::ggplot(long, ggplot2::aes(x = x, y = value, group = series))
    if (draw_area) {
      p <- p + ggplot2::geom_ribbon(
        ggplot2::aes(ymin = band_low, ymax = band_high, fill = series),
        colour = NA, show.legend = FALSE
      )
    }
    # 点用「白圈 + 实心点」两层画：这样 fill 色标可以留给面积带子，不会和点抢
    p <- p +
      ggplot2::geom_line(ggplot2::aes(colour = series), linewidth = ctx$style$geoms$line_width) +
      ggplot2::geom_point(colour = ctx$background, size = point_size * 1.7) +
      ggplot2::geom_point(ggplot2::aes(colour = series), size = point_size, show.legend = FALSE)

    label_mode <- o$labelSeries %||% "auto"
    if (identical(label_mode, "auto")) label_mode <- if (m <= 8) "end" else "legend"
    show_legend <- !identical(o$legend, FALSE) && identical(label_mode, "legend")

    ordered <- long[order(long$series, long$x), , drop = FALSE]
    if (label_mode %in% c("end", "both")) {
      last <- ordered[!duplicated(ordered$series, fromLast = TRUE), , drop = FALSE]
      p <- p + ggplot2::geom_text(
        data = last, ggplot2::aes(x = x, y = value, label = series, colour = series),
        hjust = 0, nudge_x = 0.14, size = label_size, show.legend = FALSE
      )
    }
    if (identical(label_mode, "both")) {
      first <- ordered[!duplicated(ordered$series), , drop = FALSE]
      p <- p + ggplot2::geom_text(
        data = first, ggplot2::aes(x = x, y = value, label = series, colour = series),
        hjust = 1, nudge_x = -0.14, size = label_size, show.legend = FALSE
      )
    }

    vals <- long$value
    is_rank <- all(abs(vals - round(vals)) < 1e-9) && length(unique(vals)) <= 12
    y_labels <- if (is_rank) function(v) as.character(round(v)) else fmt
    y_breaks <- if (is_rank) sort(unique(round(vals))) else mint_breaks(6)

    # 时间标签太长时抽稀刻度，而不是旋转（旋转会撑爆固定高度的版心）
    x_label_size <- ctx$style$type$axis_text
    label_pt <- vapply(x_levels, mint_text_width, numeric(1), size = x_label_size)
    slot_pt <- max(1, (ctx$width - 0.9) * 72 / n)
    x_step <- max(1L, as.integer(ceiling(max(label_pt) / slot_pt)))
    tick_idx <- seq(1L, n, by = x_step)

    # 首尾刻度的标签有一半探出面板，用数据单位的留白把它接住
    plot_w_in <- max(1, ctx$width - 0.85)
    x_unit_in <- plot_w_in / max(1, n - 1)
    widest_in <- max(label_pt[tick_idx]) / 72
    half_units <- max(0.1, min(0.3 * (n - 1), 0.5 * widest_in / x_unit_in))
    pad_units <- if (tick_idx[1] == 1L) half_units else 0.1
    right_units <- if (tick_idx[length(tick_idx)] == n) half_units else 0.1
    if (label_mode %in% c("end", "both")) right_units <- max(right_units, 0.13 * (n - 1))

    p <- p +
      ggplot2::scale_fill_manual(values = band_fill, guide = "none") +
      ggplot2::scale_colour_manual(values = colors, name = NULL,
                                   guide = mint_legend_guide(show_legend)) +
      ggplot2::scale_x_continuous(
        breaks = tick_idx, labels = x_levels[tick_idx],
        expand = ggplot2::expansion(add = c(pad_units, right_units))
      ) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "y",
                 legend_position = if (show_legend) "top" else "none")

    # 面积形态的带子会超出名次的数值范围（首尾带子各向外探 half），纵轴要跟着放宽，
    # 否则带子会被面板裁掉
    if (draw_area) {
      low_pad <- max(0, min(long$value) - min(band_low, na.rm = TRUE)) + pitch * 0.05
      high_pad <- max(0, max(band_high, na.rm = TRUE) - max(long$value)) + pitch * 0.05
      y_expand <- ggplot2::expansion(add = c(low_pad, high_pad))
    } else {
      y_expand <- ggplot2::expansion(mult = c(0.08, 0.08))
    }

    if (reverse_rank) {
      p + ggplot2::scale_y_continuous(labels = y_labels, breaks = y_breaks, expand = y_expand)
    } else {
      p + ggplot2::scale_y_reverse(labels = y_labels, breaks = y_breaks, expand = y_expand)
    }
  }
))
