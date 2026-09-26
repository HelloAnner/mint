# 华夫图 waffle
#
# 华夫图的价值在于「数格子」：每一格代表一个等量的单位，读者可以直接把比例数出来。
# 因此这里不用图例，而是在右侧用小色块 + 类别名 + 百分比做对照 —— 眼睛不用在图和
# 图例之间来回跳。
#
# 两个容易画错的点：
#   1) 格子数必须「恰好」等于总格数。round() 之后合计会有偏差，余数补给占比最大的类别；
#   2) 格子必须是正方形，所以用 coord_fixed()；右侧说明文字按英寸估算宽度预留空间。

mint_register(mint_chart(
  id = "waffle",
  name = "华夫图",
  english = "Waffle",
  category = "composition",
  description = "用等量方格表示比例，比饼图更容易读出「几比几」的量级感",
  data_shape = paste(
    "支持三种写法：",
    "[ { \"id\": \"已完成\", \"label\": \"已完成\", \"value\": 62 } ]",
    "{ \"已完成\": 62, \"进行中\": 23 }",
    "[ [\"已完成\", 62], [\"进行中\", 23] ]",
    "value 是权重，total 是格子总数（默认取权重之和，上限 100）。",
    sep = "\n"
  ),
  variants = c("waffle 华夫"),
  aliases = c("华夫图", "方格图", "点阵图", "waffle"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("rows", "number", "行数，省略则按总格数自动推导"),
    mint_option("columns", "number", "列数，省略则按总格数自动推导"),
    mint_option("total", "number", "格子总数，省略则取权重之和（上限 100）"),
    mint_option("fillDirection", "string", "填充方向", default = "top", values = c("top", "right", "bottom", "left")),
    mint_option("emptyColor", "string", "空格子的颜色", default = "#f1f5f9"),
    mint_option("legend", "boolean", "是否在右侧显示类别说明", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "已完成", label = "已完成", value = 62),
      list(id = "进行中", label = "进行中", value = 23),
      list(id = "未开始", label = "未开始", value = 15)
    ),
    options = list(rows = 10, columns = 10, total = 100)
  ),
  render = function(ctx) {
    o <- ctx$options
    pairs <- mint_as_pairs(ctx$data, "waffle")
    if (nrow(pairs) == 0) mint_fail("INVALID_DATA", "waffle 的数据为空", "至少提供一个类别")
    values <- pairs$value
    if (any(!is.finite(values))) {
      mint_fail("INVALID_DATA", "waffle 的权重必须是有限数值",
                "形如 { \"id\": \"已完成\", \"value\": 62 }")
    }
    if (any(values < 0)) {
      mint_fail("INVALID_DATA", "waffle 的权重不能为负",
                "每一格代表一个正的单位；负值请先取绝对值或改用其它图表")
    }
    sum_values <- sum(values)
    if (sum_values <= 0) {
      mint_fail("INVALID_DATA", "waffle 的所有权重都是 0", "至少一个类别需要有正值")
    }

    total_opt <- o$total
    total <- if (is.numeric(total_opt) && length(total_opt) == 1 && is.finite(total_opt) && total_opt > 0) {
      as.integer(round(total_opt))
    } else {
      max(1L, min(100L, as.integer(round(sum_values))))
    }
    total <- max(1L, total)

    columns_opt <- o$columns
    rows_opt <- o$rows
    columns <- if (is.numeric(columns_opt) && length(columns_opt) == 1 && columns_opt >= 1) {
      as.integer(round(columns_opt))
    } else {
      max(1L, as.integer(ceiling(sqrt(total))))
    }
    rows <- if (is.numeric(rows_opt) && length(rows_opt) == 1 && rows_opt >= 1) {
      as.integer(round(rows_opt))
    } else {
      max(1L, as.integer(ceiling(total / columns)))
    }
    if (rows * columns < total) rows <- as.integer(ceiling(total / columns))
    capacity <- rows * columns

    counts <- round(values / sum_values * total)
    # 四舍五入的余数按「相对缺口最大」逐格补给，保证格子数恰好等于 total
    diff <- total - sum(counts)
    guard <- 0L
    while (diff != 0 && guard < 10000L) {
      guard <- guard + 1L
      if (diff > 0) {
        i <- which.max(values / (counts + 0.5))
        counts[i] <- counts[i] + 1L
        diff <- diff - 1L
      } else {
        cand <- which(counts > 0)
        if (length(cand) == 0) break
        i <- cand[which.max(values[cand] / counts[cand])]
        counts[i] <- counts[i] - 1L
        diff <- diff + 1L
      }
    }

    direction <- o$fillDirection %||% "top"
    if (direction %in% c("top", "bottom")) {
      row_order <- if (identical(direction, "bottom")) rev(seq_len(rows)) else seq_len(rows)
      cells <- do.call(rbind, lapply(row_order, function(r) {
        data.frame(col = seq_len(columns), row = r)
      }))
    } else {
      col_order <- if (identical(direction, "right")) rev(seq_len(columns)) else seq_len(columns)
      cells <- do.call(rbind, lapply(col_order, function(cc) {
        data.frame(col = cc, row = seq_len(rows))
      }))
    }

    cats <- rep(NA_character_, capacity)
    cursor <- 0L
    for (j in seq_len(nrow(pairs))) {
      if (counts[j] > 0) cats[(cursor + 1L):(cursor + counts[j])] <- pairs$label[j]
      cursor <- cursor + counts[j]
    }

    # row 1 在最上面，所以 y 要翻转
    df <- data.frame(x = cells$col, y = rows - cells$row + 1, cat = cats,
                     stringsAsFactors = FALSE)
    palette <- stats::setNames(mint_colors(nrow(pairs), ctx$colors), pairs$label)
    empty_color <- o$emptyColor %||% "#f1f5f9"
    df$fill <- ifelse(is.na(df$cat), empty_color, unname(palette[df$cat]))

    share <- values / sum_values
    pct_text <- vapply(share, mint_waffle_pct, character(1))
    legend_labels <- paste0(pairs$label, "  ", pct_text)

    # ── 坐标直接用「英寸」：mint 的版心会把 panel 拉满整个图表区，
    #    所以 coord_fixed 不起作用，格子要方就必须让 x/y 的单位长度同为 1 英寸。
    #    （与 flowchart.R 的做法一致。）
    canvas_w <- ctx$width
    canvas_h <- ctx$height
    label_size <- ctx$style$type$data_label
    show_legend <- !identical(o$legend, FALSE)

    legend_gap <- 0.25
    swatch_in <- 0.13
    text_gap <- 0.07
    text_in <- 0
    if (show_legend) text_in <- max(vapply(legend_labels, mint_text_width, numeric(1), size = label_size)) / 72

    legend_w <- if (show_legend) legend_gap + swatch_in + text_gap + text_in else 0
    # 留 0.08in 的内边距：不留的话格子会正好顶到画布边缘，看起来像被裁掉了
    cell <- min((canvas_h - 0.16) / rows, (canvas_w - legend_w - 0.16) / columns)
    if (!is.finite(cell) || cell <= 0.02) {
      mint_fail("INVALID_DATA", "画布太小，放不下这么多格子",
                "减少 rows / columns / total，或调大 --width / --height")
    }

    content_w <- columns * cell
    if (show_legend) content_w <- content_w + legend_gap + swatch_in + text_gap + text_in
    pad_left <- max(0, (canvas_w - content_w) / 2)
    pad_bottom <- max(0, (canvas_h - rows * cell) / 2)

    # row 1 在最上面，所以 y 从下往上数要翻转
    df$x <- pad_left + (cells$col - 0.5) * cell
    df$y <- pad_bottom + (rows - cells$row + 0.5) * cell

    p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill)) +
      ggplot2::geom_tile(width = cell, height = cell, colour = ctx$background, linewidth = 0.4) +
      ggplot2::scale_fill_identity(guide = "none")

    if (show_legend) {
      key_x <- pad_left + columns * cell + legend_gap
      step <- min(0.26, (canvas_h * 0.92) / max(1, nrow(pairs)))
      top <- canvas_h / 2 + step * (nrow(pairs) - 1) / 2
      size <- min(swatch_in, step * 0.6)
      key <- data.frame(
        y = top - (seq_len(nrow(pairs)) - 1) * step,
        fill = unname(palette),
        label = legend_labels,
        stringsAsFactors = FALSE
      )
      p <- p +
        ggplot2::geom_tile(data = key, ggplot2::aes(x = key_x + size / 2, y = y, fill = fill),
                           width = size, height = size, colour = NA, inherit.aes = FALSE) +
        ggplot2::geom_text(data = key,
                           ggplot2::aes(x = key_x + size + text_gap, y = y, label = label),
                           hjust = 0, vjust = 0.5, colour = ctx$text, inherit.aes = FALSE,
                           size = label_size / ggplot2::.pt)
    }

    p +
      ggplot2::scale_x_continuous(limits = c(0, canvas_w), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, canvas_h), expand = c(0, 0)) +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        panel.background = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
))

#' 占比文本：整数就省掉小数位，避免「62.0%」这种噪音
mint_waffle_pct <- function(share) {
  value <- share * 100
  if (abs(value - round(value)) < 0.05) sprintf("%.0f%%", round(value)) else sprintf("%.1f%%", value)
}
