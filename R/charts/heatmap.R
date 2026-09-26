# 热力图 heatmap
#
# 专业热力图的三件事：单元格之间留白（否则相邻色块糊在一起）、
# 数值直接写在格子里（省掉来回对色标）、色条细而带刻度。
#
# 色条是自己画的，没用 ggplot 的图例：ggplot2 4.0.3 里连续色标的图例列宽会算成
# key 的尺寸，标签被挤出画布（git 历史里试过右侧竖条与底部横条两种位置都会裁切）。
# 自己用 geom_rect 在最后一列右边画一条竖色条 + 刻度数字，位置和尺寸完全可控。

mint_register(mint_chart(
  id = "heatmap",
  name = "热力图",
  english = "Heatmap",
  category = "distribution",
  description = "用颜色深浅表达二维网格上的数值，适合相关矩阵、时段 × 维度的分布",
  data_shape = paste(
    "两种写法：",
    "1) 长表（推荐）：[ { \"x\": \"周一\", \"y\": \"上午\", \"value\": 12 } ]",
    "2) 宽表：[ { \"时段\": \"上午\", \"周一\": 12, \"周二\": 18 } ]（第一个字符串字段作 Y 轴）",
    sep = "\n"
  ),
  variants = c("long 长表", "wide 宽表", "correlation 相关矩阵"),
  aliases = c("热力图", "热图", "相关性矩阵", "相关矩阵", "matrix", "heat"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("xKey", "string", "X 字段（长表）", default = "x"),
    mint_option("yKey", "string", "Y 字段（长表）", default = "y"),
    mint_option("valueKey", "string", "数值字段（长表）", default = "value"),
    mint_option("showValues", "boolean", "是否在格子里写数值", default = TRUE),
    mint_option("showScale", "boolean", "是否画右侧色条", default = TRUE),
    mint_option("ramp", "string", "色阶调色板 id", default = "blue"),
    mint_option("reverse", "boolean", "色阶是否反向", default = FALSE),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(x = "周一", y = "上午", value = 32), list(x = "周二", y = "上午", value = 48),
      list(x = "周三", y = "上午", value = 41), list(x = "周四", y = "上午", value = 55),
      list(x = "周五", y = "上午", value = 62),
      list(x = "周一", y = "下午", value = 44), list(x = "周二", y = "下午", value = 51),
      list(x = "周三", y = "下午", value = 58), list(x = "周四", y = "下午", value = 49),
      list(x = "周五", y = "下午", value = 71),
      list(x = "周一", y = "晚间", value = 26), list(x = "周二", y = "晚间", value = 31),
      list(x = "周三", y = "晚间", value = 37), list(x = "周四", y = "晚间", value = 42),
      list(x = "周五", y = "晚间", value = 68)
    ),
    options = list(xLegend = "日期", yLegend = "时段")
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- mint_as_rows(ctx$data, "heatmap")
    x_key <- o$xKey %||% "x"
    y_key <- o$yKey %||% "y"
    value_key <- o$valueKey %||% "value"

    if (all(c(x_key, y_key, value_key) %in% names(rows))) {
      long <- data.frame(
        x = as.character(rows[[x_key]]),
        y = as.character(rows[[y_key]]),
        value = mint_numeric_column(rows, value_key, "heatmap", "数值字段"),
        stringsAsFactors = FALSE
      )
    } else {
      # 宽表：第一个字符串字段作 Y，其余数值字段作 X
      char_cols <- names(rows)[vapply(rows, is.character, logical(1))]
      y_col <- char_cols[1] %||% names(rows)[1]
      value_cols <- names(rows)[vapply(rows, is.numeric, logical(1))]
      if (length(value_cols) == 0) {
        mint_fail("INVALID_DATA", "heatmap 的宽表里没有数值列",
                  "形如 [{ \"时段\": \"上午\", \"周一\": 12, \"周二\": 18 }]")
      }
      long <- do.call(rbind, lapply(value_cols, function(col) {
        data.frame(x = col, y = as.character(rows[[y_col]]), value = as.numeric(rows[[col]]),
                   stringsAsFactors = FALSE)
      }))
    }

    fmt <- ctx$formatter
    x_levels <- unique(long$x)
    y_levels <- unique(long$y)
    nx <- length(x_levels)
    ny <- length(y_levels)

    # 离散类别映射成连续的格心坐标：y 从上往下排，和表格的阅读方向一致
    long$x_pos <- match(long$x, x_levels)
    long$y_pos <- ny - match(long$y, y_levels) + 1

    values <- long$value
    value_range <- range(values, na.rm = TRUE)

    # 深色格子配白字、浅色格子配深字 —— 任何色阶下都读得清
    ramp <- mint_get_ramp(o$ramp %||% "blue", isTRUE(o$reverse))
    scale_fn <- mint_seq_palette(ramp, value_range)
    fill_colors <- scale_fn(values)
    luminance <- apply(grDevices::col2rgb(fill_colors), 2, function(rgb) {
      sum(rgb * c(0.299, 0.587, 0.114)) / 255
    })

    show_values <- !identical(o$showValues, FALSE) && nrow(long) <= 400
    show_scale <- !identical(o$showScale, FALSE) && !identical(o$legend, FALSE)

    p <- ggplot2::ggplot(long) +
      ggplot2::geom_rect(
        ggplot2::aes(xmin = x_pos - 0.5, xmax = x_pos + 0.5,
                     ymin = y_pos - 0.5, ymax = y_pos + 0.5),
        fill = fill_colors, colour = ctx$background, linewidth = ctx$style$geoms$tile_border
      )

    if (show_values) {
      p <- p + ggplot2::geom_text(
        ggplot2::aes(x = x_pos, y = y_pos, label = fmt(value)),
        colour = ifelse(luminance > 0.62, ctx$text, "#FFFFFF"),
        size = ctx$style$type$data_label / ggplot2::.pt
      )
    }

    # ── 右侧色条：竖条 + 刻度数字，位置用数据坐标算，不依赖 ggplot 图例
    x_max <- nx + 0.5
    if (show_scale) {
      scale_x <- nx + 1.02                     # 色条中心
      bar_width <- 0.16
      bar_height <- ny * 0.44                  # 只占面板高度的一部分，像期刊里的标尺
      bar_top <- ny - 0.35
      bar_bottom <- bar_top - bar_height
      steps <- 48

      band <- data.frame(
        ymin = seq(bar_bottom, bar_top, length.out = steps + 1)[-(steps + 1)],
        ymax = seq(bar_bottom, bar_top, length.out = steps + 1)[-1]
      )
      band$fill <- scale_fn(seq(value_range[1], value_range[2], length.out = steps))
      p <- p + ggplot2::geom_rect(
        data = band,
        ggplot2::aes(xmin = scale_x - bar_width / 2, xmax = scale_x + bar_width / 2,
                     ymin = ymin, ymax = ymax),
        fill = band$fill, colour = NA
      )

      ticks <- pretty(value_range, n = 4)
      ticks <- ticks[ticks >= value_range[1] & ticks <= value_range[2]]
      if (length(ticks) > 0) {
        tick_y <- bar_bottom + (ticks - value_range[1]) / diff(value_range) * bar_height
        p <- p +
          # 刻度短线画在色条右侧，读数更清楚
          ggplot2::geom_segment(
            data = data.frame(y = tick_y, yend = tick_y),
            ggplot2::aes(x = scale_x + bar_width / 2, xend = scale_x + bar_width / 2 + 0.06,
                         y = y, yend = yend),
            colour = ctx$style$tokens$axis, linewidth = 0.3
          ) +
          ggplot2::geom_text(
            data = data.frame(x = scale_x + bar_width / 2 + 0.1, y = tick_y, label = fmt(ticks)),
            ggplot2::aes(x = x, y = y, label = label),
            hjust = 0, colour = ctx$text, size = ctx$style$type$data_label / ggplot2::.pt
          )
      }
      x_max <- scale_x + bar_width / 2 + 0.62   # 给刻度数字留出宽度
    }

    rotations <- if (max(nchar(x_levels)) > 6) 45 else 0

    p +
      ggplot2::scale_x_continuous(
        breaks = seq_len(nx), labels = x_levels,
        limits = c(0.5 - 0.02, x_max), expand = c(0, 0)
      ) +
      ggplot2::scale_y_continuous(
        breaks = ny - seq_len(ny) + 1, labels = y_levels,
        limits = c(0.5 - 0.02, ny + 0.5), expand = c(0, 0)
      ) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "none", legend_position = "none") +
      ggplot2::theme(
        axis.line = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(angle = rotations, hjust = if (rotations == 45) 1 else 0.5)
      )
  }
))
