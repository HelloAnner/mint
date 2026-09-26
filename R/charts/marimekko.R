# 马赛克图 marimekko
#
# 一张图读两级比例：列宽 = 一级分类（组）占比，列内每块高度 = 二级分类在组内的占比。
# 因此这里不用 ggplot 的坐标轴来排布分类，而是手工把两级比例换算成 [0,1] 的矩形坐标：
#   * 组宽 = 组权重 / 总权重，再扣掉组间缝；
#   * 组内块高 = 该维度值 / 组内合计，再扣掉块间缝；
#   * 列宽与块高都落在 0..1，于是 y 轴的刻度天然就是「组内占比」的百分比。
#
# 标注直接写在块里（子类 + 组内占比），放不下时先退成只写百分比，再放不下才省略 ——
# 这比统一缩小字号更干净，也不会出现谁也读不清的 3pt 小字。

mint_register(mint_chart(
  id = "marimekko",
  name = "马赛克图",
  english = "Marimekko",
  category = "composition",
  description = "条形宽度表示组间占比、堆叠高度表示组内构成，一张图同时读两级比例",
  data_shape = paste(
    "两种写法：",
    "1) 宽表（推荐）：[ { \"id\": \"华东\", \"value\": 320, \"新客\": 120, \"老客\": 200 } ]",
    "2) 长表：[ { \"类别\": \"华东\", \"子类\": \"新客\", \"value\": 120 } ]",
    "value 决定该组的宽度，其余数值字段构成组内堆叠，会自动识别为 dimensions。",
    sep = "\n"
  ),
  variants = c("marimekko 马赛克"),
  aliases = c("马赛克图", "marimekko", "mosiac", "mosaic"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("idBy", "string", "分组字段名", default = "id"),
    mint_option("valueBy", "string", "决定宽度的字段名", default = "value"),
    mint_option("dimensions", "array", "组内堆叠字段，省略则自动识别"),
    mint_option("innerPadding", "number", "组内间距（磅）", default = 2),
    mint_option("outerPadding", "number", "组间间距（磅）", default = 6),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("legend", "boolean", "是否显示颜色图例", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "华东", value = 320, `新客` = 120, `老客` = 200),
      list(id = "华北", value = 240, `新客` = 110, `老客` = 130),
      list(id = "华南", value = 180, `新客` = 90, `老客` = 90),
      list(id = "西南", value = 96, `新客` = 58, `老客` = 38)
    ),
    options = list(yLegend = "组内构成", xLegend = "区域规模")
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_marimekko_model(ctx$data, o)
    groups <- model$groups
    dims <- model$dims
    g <- length(groups)
    m <- length(dims)

    row_sums <- rowSums(model$mat)
    if (any(row_sums <= 0)) {
      bad <- groups[row_sums <= 0][1]
      mint_fail("INVALID_DATA", sprintf("marimekko 的分组「%s」组内构成全为 0", bad),
                sprintf("每个组的 %s 至少要有一个正值", paste(dims, collapse = " / ")))
    }
    if (any(model$totals <= 0)) {
      mint_fail("INVALID_DATA", "marimekko 的组宽度必须为正",
                sprintf("检查字段「%s」的取值", o$valueBy %||% "value"))
    }

    # 版心里真正能画图的部分（扣掉 y 轴刻度、轴标题的大致占地）
    plot_w_in <- max(1, ctx$width - 0.45)
    plot_h_in <- max(1, ctx$height - 0.30)

    # 列底标签的文字（先算好：图例宽度和两端留白都要用到它的宽度）
    total_share <- model$totals / sum(model$totals)
    share_text <- vapply(total_share, mint_marimekko_pct, character(1))
    label_one <- paste0(groups, "  ", share_text)
    label_two <- paste0(groups, "\n", share_text)
    label_size <- ctx$style$type$data_label
    wide_in <- vapply(label_two, function(text) {
      max(vapply(strsplit(text, "\n", fixed = TRUE)[[1]], mint_text_width, numeric(1), size = label_size))
    }, numeric(1)) / 72
    key_text_in <- max(vapply(groups, mint_text_width, numeric(1), size = label_size)) / 72

    # 四个量互相依赖：x 轴单位长度 ← 列宽 ← 标签是否折行/溢出 ← 图例区宽度 ← x 轴单位长度。
    # 迭代几轮让它收敛，比硬编码一套边距稳。
    show_legend <- !identical(o$legend, FALSE)
    legend_units <- if (show_legend) 0.3 else 0
    pad_left <- 0
    pad_right <- 0
    widths <- rep(1 / g, g)
    left <- seq(0, 1 - 1 / g, length.out = g)
    stacked <- rep(FALSE, g)
    for (iter in 1:4) {
      x_unit_in <- plot_w_in / (1 + legend_units + pad_left + pad_right)
      outer_gap <- (o$outerPadding %||% 6) / 72 / x_unit_in
      widths <- model$totals / sum(model$totals) * (1 - (g - 1) * outer_gap)
      left <- numeric(g)
      acc <- 0
      for (i in seq_len(g)) {
        left[i] <- acc
        acc <- acc + widths[i] + outer_gap
      }
      one_line_in <- vapply(label_one, mint_text_width, numeric(1), size = label_size) / 72
      stacked <- one_line_in > widths * x_unit_in * 0.98
      # 首尾列的标签可能比列本身还宽，给 x 轴两端留余量，别顶到 y 轴刻度或图例上
      half <- wide_in / x_unit_in / 2
      pad_left <- max(0, half[1] - (left[1] + widths[1] / 2))
      pad_right <- max(0, (left[g] + widths[g] / 2) + half[g] - 1)
      legend_units <- if (show_legend) pad_right + 0.09 + key_text_in / x_unit_in + 0.03 else 0
    }
    if (any(widths <= 0)) {
      mint_fail("INVALID_DATA", "marimekko 的组太多，间距吃掉了列宽",
                "调小 outerPadding，或减少一级分类的数量")
    }
    stagger <- sum(stacked) >= 2

    y_unit_in <- plot_h_in # y 轴范围就是 0..1
    inner_gap <- (o$innerPadding %||% 2) / 72 / y_unit_in

    # 同组用同色不同深浅：先给每组一个主色，组内维度按由浅到深铺开
    group_colors <- mint_colors(g, ctx$colors)
    shades <- lapply(seq_len(g), function(i) mint_ramp(group_colors[i], m, from = 0.5, to = 1))

    rects <- vector("list", g * m)
    labels <- vector("list", g * m)
    rect_i <- 0L
    label_i <- 0L
    for (i in seq_len(g)) {
      heights <- model$mat[i, ] / row_sums[i] * (1 - (m - 1) * inner_gap)
      y_top <- 1
      for (j in seq_len(m)) {
        y_min <- y_top - heights[j]
        y_max <- y_top
        rect_i <- rect_i + 1L
        rects[[rect_i]] <- data.frame(
          xmin = left[i], xmax = left[i] + widths[i], ymin = y_min, ymax = y_max,
          fill = shades[[i]][j], stringsAsFactors = FALSE
        )

        share <- model$mat[i, j] / row_sums[i]
        fit <- mint_marimekko_label(
          dims[j], mint_marimekko_pct(share),
          box_w_in = widths[i] * x_unit_in,
          box_h_in = heights[j] * y_unit_in,
          max_size = ctx$style$type$data_label
        )
        if (!is.null(fit)) {
          label_i <- label_i + 1L
          labels[[label_i]] <- data.frame(
            x = left[i] + widths[i] / 2, y = (y_min + y_max) / 2,
            label = fit$text, size = fit$size / ggplot2::.pt, fill = shades[[i]][j],
            stringsAsFactors = FALSE
          )
        }
        y_top <- y_min - inner_gap
      }
    }
    rects <- do.call(rbind, rects)

    p <- ggplot2::ggplot(rects, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill)) +
      ggplot2::geom_rect(colour = ctx$background, linewidth = 0.4) +
      ggplot2::scale_fill_identity(guide = "none")

    if (label_i > 0) {
      labels <- do.call(rbind, labels[seq_len(label_i)])
      # 浅色块上用深色字（带一点该块的色相），深色块上用白字 —— 保证任何配色下都能读
      luminance <- apply(grDevices::col2rgb(labels$fill), 2, function(rgb) {
        sum(rgb * c(0.299, 0.587, 0.114)) / 255
      })
      labels$ink <- ifelse(
        luminance > 0.58,
        vapply(labels$fill, function(f) mint_mix(f, "#2B2B2B", 0.8), character(1)),
        "#FFFFFF"
      )
      # size 作为 aes 才能让不同大小的块各自取到合适的字号；不出图例
      p <- p + ggplot2::geom_text(
        data = labels, ggplot2::aes(x = x, y = y, label = label, size = size, colour = ink),
        lineheight = 1.15, show.legend = FALSE, inherit.aes = FALSE
      ) +
        ggplot2::scale_size_identity(guide = "none") +
        ggplot2::scale_colour_identity(guide = "none")
    }

    # 组色图例放在右侧：色相就是一级分类
    key_x <- 1 + pad_right + 0.045
    if (show_legend) {
      step <- min(0.1, 0.9 / max(1, g))
      top <- 0.94
      key <- data.frame(
        x = key_x,
        y = top - (seq_len(g) - 1) * step,
        fill = group_colors,
        label = groups,
        stringsAsFactors = FALSE
      )
      p <- p +
        ggplot2::geom_tile(data = key, ggplot2::aes(x = x, y = y, fill = fill),
                           width = 0.03, height = step * 0.6, colour = NA, inherit.aes = FALSE) +
        ggplot2::geom_text(data = key, ggplot2::aes(x = x + 0.045, y = y, label = label),
                           hjust = 0, vjust = 0.5, colour = ctx$text, inherit.aes = FALSE,
                           size = label_size / ggplot2::.pt)
    }

    p +
      ggplot2::scale_x_continuous(
        # 一级分类名 + 总占比直接做成 x 轴的刻度标签：位置天然对得上列心，
        # 纵向空间由 ggplot 自己让（不会和 x 轴标题打架）；窄列多时用 n.dodge 错开两行
        limits = c(-pad_left, 1 + pad_right + legend_units),
        breaks = left + widths / 2,
        labels = ifelse(stacked, label_two, label_one),
        guide = ggplot2::guide_axis(n.dodge = if (stagger) 2L else 1L),
        expand = c(0, 0)
      ) +
      ggplot2::scale_y_continuous(
        limits = c(0, 1), breaks = seq(0, 1, 0.25),
        labels = function(v) sprintf("%.0f%%", v * 100),
        expand = c(0, 0)
      ) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "none") +
      ggplot2::theme(
        axis.line.x = ggplot2::element_blank(),
        axis.ticks.x = ggplot2::element_blank()
      )
  }
))

#' 把两种常见输入归一成「分组 / 组宽 / 组内维度 / 数值矩阵」
mint_marimekko_model <- function(data, o) {
  rows <- mint_as_rows(data, "marimekko")
  fields <- names(rows)
  id_by <- o$idBy %||% "id"
  value_by <- o$valueBy %||% "value"

  if (id_by %in% fields && value_by %in% fields) {
    dims <- o$dimensions
    if (is.null(dims) || length(dims) == 0) {
      dims <- fields[vapply(rows, is.numeric, logical(1))]
      dims <- setdiff(dims, value_by)
    }
    dims <- as.character(dims)
    missing <- setdiff(dims, fields)
    if (length(missing) > 0) {
      mint_fail("INVALID_DATA", sprintf("marimekko 里没有字段 %s", paste(missing, collapse = ", ")),
                sprintf("可用字段：%s", paste(fields, collapse = ", ")))
    }
    if (length(dims) == 0) {
      mint_fail("INVALID_DATA", "marimekko 找不到组内构成字段",
                sprintf("除 %s / %s 之外还需要至少一个数值字段，例如 { \"id\": \"华东\", \"value\": 320, \"新客\": 120 }",
                        id_by, value_by))
    }
    groups <- as.character(rows[[id_by]])
    totals <- mint_numeric_column(rows, value_by, "marimekko", "宽度字段")
    mat <- vapply(dims, function(d) suppressWarnings(as.numeric(rows[[d]])), numeric(nrow(rows)))
    mat <- matrix(mat, nrow = nrow(rows))
    mat[is.na(mat)] <- 0
    return(list(groups = groups, totals = totals, dims = dims, mat = mat))
  }

  # 长表：[{ 类别, 子类, value }]，组宽由组内合计推出
  chr <- fields[vapply(rows, is.character, logical(1))]
  num <- fields[vapply(rows, is.numeric, logical(1))]
  if (length(chr) < 2 || length(num) < 1) {
    mint_fail("INVALID_DATA", "marimekko 无法识别数据形状",
              paste0("宽表形如 { \"id\": \"华东\", \"value\": 320, \"新客\": 120 }；",
                     "长表形如 { \"类别\": \"华东\", \"子类\": \"新客\", \"value\": 120 }"))
  }
  group_value <- as.character(rows[[chr[1]]])
  sub_value <- as.character(rows[[chr[2]]])
  values <- as.numeric(rows[[num[1]]])
  if (any(!is.finite(values))) {
    mint_fail("INVALID_DATA", sprintf("marimekko 的字段「%s」必须是数值", num[1]))
  }
  groups <- unique(group_value)
  dims <- unique(sub_value)
  mat <- matrix(0, length(groups), length(dims))
  for (k in seq_along(group_value)) {
    i <- match(group_value[k], groups)
    j <- match(sub_value[k], dims)
    mat[i, j] <- mat[i, j] + values[k]
  }
  list(groups = groups, totals = rowSums(mat), dims = dims, mat = mat)
}

#' 估算一块矩形里能放下什么：先试「子类 + 占比」两行，再退成只写占比，都放不下就省略
mint_marimekko_label <- function(name, pct, box_w_in, box_h_in, max_size = 6.5) {
  pad <- 0.06
  candidates <- list(paste0(name, "\n", pct), pct)
  for (text in candidates) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
    units <- max(vapply(lines, mint_text_width, numeric(1), size = 1))
    size_w <- (box_w_in - 2 * pad) * 72 / max(units, 1e-6)
    size_h <- (box_h_in - 2 * pad) * 72 / (length(lines) * 1.25)
    size <- min(max_size, size_w, size_h)
    if (size >= 5) return(list(text = text, size = size))
  }
  NULL
}

#' 占比文本：整数就省掉小数位
mint_marimekko_pct <- function(share) {
  value <- share * 100
  if (abs(value - round(value)) < 0.05) sprintf("%.0f%%", round(value)) else sprintf("%.1f%%", value)
}
