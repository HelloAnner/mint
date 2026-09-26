# 子弹图 bullet
#
# 一根横条同时表达「实际 / 目标 / 达标区间」：
#   · 区间是同一色系里几档很浅的灰底，越往外越深 —— 只给个定性的「档位感」，不用渐变；
#   · 实际值是行高约 1/3 的深色窄条（比区间窄、比区间醒目，视线第一眼落在这里）；
#   · 目标是压在条上的一条短竖线 —— 三种信息各占一个视觉通道（面积 / 位置 / 线），互不遮挡。
#
# 行高紧凑：y 轴用数值刻度（每行正好一格），行与行之间不留大空白，一屏能罗列很多 KPI。
# 类别名靠 y 轴文字给出，实际值/目标值直标在条右侧，不依赖图例。

#' 归一化子弹图数据
#'
#' 新写法：{ "label": "营收", "value": 128, "target": 150, "ranges": [100, 200] }
#' 旧写法：{ "id": "营收", "title": "营收", "ranges": [150, 200, 260],
#'           "measures": [187], "markers": [200] }（measures/markers 取第一个值）
mint_bullet_rows <- function(data) {
  if (!is.list(data) || !is.null(names(data)) || length(data) == 0) {
    mint_fail("INVALID_DATA", sprintf("bullet 需要非空的数组数据，收到 %s", mint_type_name(data)),
              "形如 [{ \"label\": \"营收\", \"value\": 128, \"target\": 150, \"ranges\": [100, 200] }]")
  }
  n <- length(data)
  label <- character(n)
  value <- numeric(n)
  target <- rep(NA_real_, n)
  ranges <- vector("list", n)

  scalar <- function(raw, what, where) {
    if (is.list(raw)) raw <- raw[[1]]
    if (is.null(raw) || !is.numeric(raw) || length(raw) != 1) {
      mint_fail("INVALID_DATA", sprintf("bullet 第 %d 项的 %s 必须是数值", where, what))
    }
    as.numeric(raw)
  }

  for (i in seq_len(n)) {
    row <- data[[i]]
    if (!is.list(row) || is.null(names(row))) {
      mint_fail("INVALID_DATA", sprintf("bullet 第 %d 项不是对象", i),
                "每一行都形如 { \"label\": \"营收\", \"value\": 128, \"target\": 150 }")
    }
    lab <- mint_field(row, c("label", "title", "name", "id"))
    if (is.null(lab)) {
      mint_fail("INVALID_DATA", sprintf("bullet 第 %d 项缺少 label", i), "例如 \"label\": \"营收\"")
    }
    label[i] <- as.character(lab)[1]

    raw_value <- mint_field(row, c("value", "measure", "measures", "actual"))
    if (is.null(raw_value)) {
      mint_fail("INVALID_DATA", sprintf("「%s」缺少实际值 value", label[i]), "例如 \"value\": 128")
    }
    value[i] <- scalar(raw_value, "value", i)

    raw_target <- mint_field(row, c("target", "marker", "markers", "goal"))
    if (!is.null(raw_target)) target[i] <- scalar(raw_target, "target", i)

    raw_ranges <- mint_field(row, c("ranges", "range", "bands"))
    if (is.null(raw_ranges)) {
      ranges[[i]] <- numeric(0)
    } else {
      nums <- suppressWarnings(as.numeric(unlist(raw_ranges, use.names = FALSE)))
      nums <- nums[is.finite(nums)]
      # 区间必须由小到大，否则「档位」的深浅就反了
      if (is.unsorted(nums)) {
        mint_fail("INVALID_DATA", sprintf("「%s」的 ranges 必须由小到大", label[i]),
                  "例如 [100, 200]：内圈 0~100、外圈 100~200")
      }
      ranges[[i]] <- nums
    }
  }

  list(label = label, value = value, target = target, ranges = ranges)
}

mint_register(mint_chart(
  id = "bullet",
  name = "子弹图",
  english = "Bullet",
  category = "comparison",
  description = "一根横条里同时呈现实际值、目标值与达成区间，适合 KPI 罗列",
  data_shape = paste(
    "数组，每行一个指标：",
    "[",
    "  { \"label\": \"营收\", \"value\": 128, \"target\": 150, \"ranges\": [100, 200] },",
    "  { \"label\": \"新增用户\", \"value\": 142, \"target\": 150, \"ranges\": [80, 120, 170] }",
    "]",
    "ranges 是定性区间（由小到大，从 0 起算的档位边界，可省略）。",
    "也兼容旧写法 measures / markers（取第一个值）。",
    sep = "\n"
  ),
  variants = c("bullet 子弹"),
  aliases = c("子弹图", "bullet", "kpi图", "目标对比"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("titleAlign", "string", "类别名对齐", default = "end", values = c("start", "middle", "end")),
    mint_option("valueLabel", "boolean", "是否直标实际值与目标值", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(label = "营收", value = 128, target = 150, ranges = list(100, 200)),
      list(label = "新增用户", value = 142, target = 150, ranges = list(80, 120, 170)),
      list(label = "留存率", value = 62, target = 65, ranges = list(40, 55, 70)),
      list(label = "客单价", value = 218, target = 200, ranges = list(150, 220, 280)),
      list(label = "毛利率", value = 41, target = 45, ranges = list(30, 45, 60))
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_bullet_rows(ctx$data)
    fmt <- ctx$formatter
    ty <- ctx$style$type
    gm <- ctx$style$geoms
    n <- length(model$label)

    # 每行一格，行 y 从上往下排（第 1 条在最上面，读者的阅读顺序）
    row_y <- rev(seq_len(n))
    band_h <- 0.33    # 区间底色占行高约 2/3，行间留出缝隙，一屏能罗列很多指标
    bar_h <- 0.175    # 实际值窄条：行高的 0.35，比区间窄但更实

    # 区间：ranges 是从 0 起算的档位边界，展开成 [0,r1] [r1,r2] ... 若干段
    max_bands <- max(vapply(model$ranges, length, integer(1)))
    # 同一色系的浅色档位：越靠外越深一点点，靠色阶区分档位而不是靠数字
    band_amount <- if (max_bands <= 1) 0.26 else seq(0.18, 0.38, length.out = max_bands)
    band_cols <- vapply(band_amount, function(a) mint_tint("#8C8C8C", a), character(1))

    band_rects <- list()
    for (i in seq_len(n)) {
      edges <- c(0, model$ranges[[i]])
      if (length(edges) < 2) next
      for (k in seq_len(length(edges) - 1)) {
        band_rects[[length(band_rects) + 1L]] <- data.frame(
          ymin = row_y[i] - band_h, ymax = row_y[i] + band_h,
          xmin = edges[k], xmax = edges[k + 1], fill = band_cols[k]
        )
      }
    }

    values <- model$value
    targets <- model$target
    span <- c(values, targets[!is.na(targets)], unlist(model$ranges), 0)
    lo <- min(span, na.rm = TRUE)
    hi <- max(span, na.rm = TRUE)
    lo <- min(0, lo)
    if (hi <= lo) hi <- lo + 1
    # 右侧留出数字的位置：条太短时实际值的数字会从条内挪到条右侧
    label_pad <- 0.13 * (hi - lo)

    show_values <- !identical(o$valueLabel, FALSE)
    sides <- c(start = 0, middle = 0.5, end = 1)

    rows <- data.frame(
      y = row_y, label = model$label, value = values, target = targets,
      stringsAsFactors = FALSE
    )
    bars <- data.frame(
      ymin = row_y - bar_h, ymax = row_y + bar_h,
      xmin = pmin(0, values), xmax = pmax(0, values)
    )

    p <- ggplot2::ggplot()
    if (length(band_rects) > 0) {
      bands <- do.call(rbind, band_rects)
      p <- p + ggplot2::scale_fill_identity() +
        ggplot2::geom_rect(
          data = bands,
          ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill),
          colour = NA
        )
    }

    p <- p + ggplot2::geom_rect(
      data = bars, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
      fill = ctx$colors[1], colour = NA
    )

    # 目标值：压在实际值条上的一条短竖线，比条更「瘦」也更靠外，视线扫过去就是差多少
    if (any(!is.na(targets))) {
      marks <- data.frame(
        x = targets[!is.na(targets)],
        ymin = row_y[!is.na(targets)] - 0.22,
        ymax = row_y[!is.na(targets)] + 0.22
      )
      p <- p + ggplot2::geom_segment(
        data = marks, ggplot2::aes(x = x, xend = x, y = ymin, yend = ymax),
        colour = ctx$foreground, linewidth = gm$axis_width * 2
      )
    }

    if (show_values) {
      # 实际值的数字写在条内靠条端的位置（白字深底最稳），条太短塞不下时才挪到条右侧，
      # 这样目标值那条竖线永远不会从数字中间穿过
      unit_in <- (ctx$width * 0.86) / (hi + label_pad - lo)
      value_txt <- fmt(values)
      room_pt <- abs(values) * unit_in * 72
      inner <- room_pt >= mint_text_width(value_txt, ty$data_label) + 8
      bar_lum <- sum(grDevices::col2rgb(ctx$colors[1]) * c(0.299, 0.587, 0.114)) / 255
      value_labels <- data.frame(
        x = values, y = row_y, label = value_txt,
        hjust = ifelse(values >= 0, ifelse(inner, 1.15, -0.2), ifelse(inner, -0.15, 1.2)),
        colour = ifelse(inner, ifelse(bar_lum > 0.62, "#3D3D3D", "#FFFFFF"), ctx$text),
        stringsAsFactors = FALSE
      )
      p <- p + ggplot2::geom_text(
        data = value_labels,
        ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
        colour = value_labels$colour, size = ty$data_label / ggplot2::.pt
      )
      if (any(!is.na(targets))) {
        # 目标数字挂在竖线上方、区间底色里：和实际值的数字错开，也不会压在纸条上
        targets_df <- rows[!is.na(rows$target), , drop = FALSE]
        p <- p + ggplot2::geom_text(
          data = targets_df, ggplot2::aes(x = target, y = y + 0.24, label = fmt(target)),
          hjust = 0.5, vjust = -1, size = ty$data_label / ggplot2::.pt, colour = ctx$muted
        )
      }
    }

    p +
      ggplot2::scale_x_continuous(
        breaks = mint_breaks(6), labels = fmt,
        limits = c(lo, hi + label_pad), expand = c(0, 0)
      ) +
      ggplot2::scale_y_continuous(
        breaks = row_y, labels = model$label,
        limits = c(0.5, n + 0.5), expand = c(0, 0)
      ) +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::coord_cartesian(clip = "off") +
      mint_theme(ctx$style, ctx$family, grid = "x") +
      ggplot2::theme(
        axis.text.y = ggplot2::element_text(hjust = sides[[o$titleAlign %||% "end"]]),
        axis.ticks.y = ggplot2::element_blank()
      )
  }
))
