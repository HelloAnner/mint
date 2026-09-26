# 热力图 heatmap
#
# 专业热力图的三件事：单元格之间留白（否则相邻色块糊在一起）、
# 数值直接写在格子里（省掉来回对色标）、色标只用一条细竖条。

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
    long$x <- factor(long$x, levels = x_levels)
    long$y <- factor(long$y, levels = rev(y_levels))

    # 深色格子上用白字，浅色格子上用深字 —— 保证任何色阶下都能读
    ramp <- mint_get_ramp(o$ramp %||% "blue", isTRUE(o$reverse))
    scale_fn <- mint_seq_palette(ramp, range(long$value, na.rm = TRUE))
    fill_colors <- scale_fn(long$value)
    luminance <- apply(grDevices::col2rgb(fill_colors), 2, function(rgb) sum(rgb * c(0.299, 0.587, 0.114)) / 255)
    label_colors <- ifelse(luminance > 0.62, "#3D3D3D", "#FFFFFF")

    show_values <- !identical(o$showValues, FALSE) && nrow(long) <= 400

    p <- ggplot2::ggplot(long, ggplot2::aes(x = x, y = y, fill = value)) +
      ggplot2::geom_tile(colour = ctx$background, linewidth = ctx$style$geoms$tile_border)

    if (show_values) {
      p <- p + ggplot2::geom_text(
        ggplot2::aes(label = fmt(value)), colour = label_colors,
        size = ctx$style$type$data_label / ggplot2::.pt, show.legend = FALSE
      )
    }

    rotations <- if (max(nchar(x_levels)) > 6) 45 else 0
    p +
      mint_scale_fill_continuous(o$ramp %||% "blue", isTRUE(o$reverse)) +
      ggplot2::scale_x_discrete(expand = c(0, 0)) +
      ggplot2::scale_y_discrete(expand = c(0, 0)) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "none", legend_position = "right") +
      ggplot2::theme(
        axis.line = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_text(angle = rotations, hjust = if (rotations == 45) 1 else 0.5),
        legend.title = ggplot2::element_blank(),
        legend.position = "right"
      )
  }
))
