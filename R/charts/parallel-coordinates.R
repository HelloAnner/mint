# 平行坐标图 parallel-coordinates
#
# 有意不用 GGally：GGally 把每个维度都压到同一条 y 轴上，
# 一个 0–100 的维度和一个 0–1 的维度会被压成一条水平线，什么也看不出来。
# 这里每个维度**独立归一化**到各自的 min–max，再把该维度的真实刻度写在轴线旁，
# 于是「同一个对象在哪个维度高、哪个维度低」才是可读的。
#
# 视觉语言：轴线用浅灰细线（只是坐标参考），对象用半透明细折线；
# 高亮时其余线条降为 0.25 透明度的浅灰 —— 用「变淡」而不是「变颜色」来突出，
# 这样即使黑白打印，层级的差别也还在。

# 每个维度给几个刻度合适：期刊图里 3~5 个，多了会和邻近轴线的数字挤在一起
MINT_PARCOORDS_TICKS <- 4

mint_register(mint_chart(
  id = "parallel-coordinates",
  name = "平行坐标图",
  english = "ParallelCoordinates",
  category = "relation",
  description = "把多个数值维度并排放置，每个对象一条折线，观察多维聚类与离群",
  data_shape = paste(
    "每一行一条记录，第一列是对象名，其余数值字段作为维度：",
    "[",
    "  { \"name\": \"城市A\", \"房价\": 82, \"通勤\": 34, \"绿化\": 61 },",
    "  { \"name\": \"城市B\", \"房价\": 65, \"通勤\": 48, \"绿化\": 73 }",
    "]",
    "可用 variables 选项指定参与绘制的维度，逗号分隔。",
    sep = "\n"
  ),
  variants = c("parallel 平行坐标", "highlight 高亮对比"),
  aliases = c("平行坐标", "parallel", "多维图"),
  packages = c("ggplot2"),
  options = list(
    mint_option("variables", "array", "参与绘制的字段，逗号分隔；省略则用全部数值字段"),
    mint_option("highlight", "string", "高亮的对象名（逗号分隔可高亮多个），其余线条降为浅灰"),
    mint_option("band", "string", "背景参考带：均值±标准差，或其余对象的取值范围", default = "none", values = c("none", "mean", "minmax")),
    mint_option("lineWidth", "number", "线宽（pt），省略则用风格线宽"),
    mint_option("opacity", "number", "线条不透明度", default = 0.55),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(name = "城市A", `房价` = 82, `通勤` = 34, `绿化` = 61, `教育` = 78),
      list(name = "城市B", `房价` = 65, `通勤` = 48, `绿化` = 73, `教育` = 66),
      list(name = "城市C", `房价` = 91, `通勤` = 26, `绿化` = 44, `教育` = 88),
      list(name = "城市D", `房价` = 48, `通勤` = 62, `绿化` = 82, `教育` = 57)
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    rows <- mint_as_rows(ctx$data, "parallel-coordinates")
    fields <- names(rows)

    # --- 对象名：优先 name/id/label，否则退回第一个文本列 ---
    name_field <- intersect(c("name", "id", "label"), fields)
    if (length(name_field) > 0) {
      name_field <- name_field[1]
    } else {
      chr <- fields[vapply(rows[fields], function(col) is.character(col) || is.factor(col), logical(1))]
      name_field <- if (length(chr) > 0) chr[1] else NULL
    }
    labels <- if (!is.null(name_field)) as.character(rows[[name_field]]) else as.character(seq_len(nrow(rows)))

    # --- 维度：variables 显式指定，否则用全部数值字段 ---
    numeric_fields <- fields[vapply(rows[fields], is.numeric, logical(1))]
    numeric_fields <- setdiff(numeric_fields, name_field)
    vars <- o$variables
    if (is.null(vars) || length(vars) == 0) vars <- numeric_fields
    vars <- as.character(vars)
    if (length(vars) < 2) {
      mint_fail("INVALID_DATA", "parallel-coordinates 至少需要 2 个数值维度",
                "例如 [{ \"name\": \"城市A\", \"房价\": 82, \"通勤\": 34 }]")
    }
    absent <- setdiff(vars, fields)
    if (length(absent) > 0) {
      mint_fail("INVALID_DATA", sprintf("数据里没有维度 %s", paste(absent, collapse = ", ")),
                sprintf("可用字段：%s", paste(fields, collapse = ", ")))
    }
    non_numeric <- vars[!vapply(rows[vars], is.numeric, logical(1))]
    if (length(non_numeric) > 0) {
      mint_fail("INVALID_DATA", sprintf("维度 %s 不是数值字段", paste(non_numeric, collapse = ", ")),
                "平行坐标的每个维度都必须是数值")
    }

    k <- length(vars)
    raw <- matrix(unlist(lapply(vars, function(v) as.numeric(rows[[v]]))), nrow = nrow(rows))

    # 缺了一个维度的对象无法连成折线：整行丢掉；全丢完就报错，不给空图
    keep <- stats::complete.cases(raw)
    if (!any(keep)) {
      mint_fail("INVALID_DATA", "每一行都缺少部分维度的取值，无法连成折线",
                "确认每一行都给出全部参与绘制的维度")
    }
    raw <- raw[keep, , drop = FALSE]
    labels <- labels[keep]
    n <- nrow(raw)

    # 逐维独立归一化；整个维度取值相同的对象落在轴中线，避免除零
    norm <- matrix(0, n, k)
    for (j in seq_len(k)) {
      rng <- range(raw[, j])
      norm[, j] <- if (diff(rng) < 1e-12) 0.5 else (raw[, j] - rng[1]) / diff(rng)
    }

    long <- data.frame(
      x = rep(seq_len(k), each = n),
      y = as.vector(norm),
      series = rep(labels, times = k),
      stringsAsFactors = FALSE
    )

    ids <- unique(labels)
    colors <- stats::setNames(mint_colors(length(ids), ctx$colors), ids)

    # --- 高亮：给名字就切分成「前景 / 背景」两层，没给就全部当前景 ---
    hl <- if (is.null(o$highlight)) character(0) else as.character(o$highlight)
    hl <- hl[nzchar(hl)]
    matched <- intersect(ids, hl)
    if (length(hl) > 0 && length(matched) == 0) {
      mint_fail("INVALID_DATA", sprintf("highlight 指定的对象不存在：%s", paste(hl, collapse = ", ")),
                sprintf("数据里的对象：%s", paste(ids, collapse = ", ")))
    }
    has_hl <- length(matched) > 0

    fmt <- ctx$formatter
    lw <- o$lineWidth %||% ctx$style$geoms$line_width

    # 高亮时线条颜色只认被高亮的对象，其余一律浅灰
    if (has_hl) {
      fg <- long[long$series %in% matched, , drop = FALSE]
      bg <- long[!long$series %in% matched, , drop = FALSE]
      fg_colors <- stats::setNames(mint_colors(length(matched), ctx$colors), unique(fg$series))
      bg_colour <- mint_tint(ctx$muted, 0.35)
    } else {
      fg <- long
      bg <- long[0, , drop = FALSE]
      fg_colors <- colors
    }
    # 图例只在「没有直标」时才出场：<=4 个对象直接贴名字，比图例快得多
    end_labels <- has_hl || (length(ids) <= 4 && !identical(o$legend, FALSE))
    show_legend <- !has_hl && !identical(o$legend, FALSE) && !end_labels

    axis_colour <- mint_tint(ctx$muted, 0.5)
    axis_df <- data.frame(x = seq_len(k), xend = seq_len(k), y = 0, yend = 1)

    p <- ggplot2::ggplot()

    # --- 背景参考带（画在最底层，只在被要求时出现）---
    band <- o$band %||% "none"
    if (!identical(band, "none") && n >= 2) {
      ref <- if (has_hl) norm[!(labels %in% matched), , drop = FALSE] else norm
      if (nrow(ref) >= 1) {
        if (identical(band, "mean")) {
          centre <- colMeans(ref)
          spread <- if (nrow(ref) > 1) apply(ref, 2, stats::sd) else rep(0, k)
          # 均值±标准差会超出轴线的 0–1 区间，夹住才不会画出轴线之外
          hi <- pmin(1, centre + spread)
          lo <- pmax(0, centre - spread)
        } else {
          centre <- NULL
          hi <- apply(ref, 2, max)
          lo <- apply(ref, 2, min)
        }
        band_df <- data.frame(x = c(seq_len(k), rev(seq_len(k))), y = c(hi, rev(lo)))
        p <- p + ggplot2::geom_polygon(data = band_df, ggplot2::aes(x = x, y = y),
                                       fill = mint_tint(ctx$muted, 0.16), colour = NA)
        if (!is.null(centre)) {
          p <- p + ggplot2::geom_line(data = data.frame(x = seq_len(k), y = centre),
                                      ggplot2::aes(x = x, y = y),
                                      colour = mint_tint(ctx$muted, 0.75), linewidth = 0.3)
        }
      }
    }

    # 轴线压在参考带之上、数据线之下：它只是刻度参考，不能盖住数据
    p <- p + ggplot2::geom_segment(data = axis_df,
                                   ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
                                   colour = axis_colour, linewidth = 0.3)

    if (nrow(bg) > 0) {
      p <- p + ggplot2::geom_line(data = bg, ggplot2::aes(x = x, y = y, group = series),
                                  colour = bg_colour, linewidth = lw, alpha = 0.25)
    }
    p <- p + ggplot2::geom_line(data = fg, ggplot2::aes(x = x, y = y, colour = series, group = series),
                                linewidth = lw, alpha = if (has_hl) 1 else (o$opacity %||% 0.55))

    # --- 刻度：每个维度自己的真实数值，写在轴线左侧 ---
    # 逐维算刻度的位置（归一化坐标）和文本（真实量纲），拼成一张文本表
    tick_rows <- lapply(seq_len(k), function(j) {
      rng <- range(raw[, j])
      if (diff(rng) < 1e-12) return(NULL)
      bk <- pretty(rng, n = MINT_PARCOORDS_TICKS)
      bk <- bk[bk >= rng[1] & bk <= rng[2]]
      if (length(bk) < 2) bk <- rng
      data.frame(x = j - 0.035, y = (bk - rng[1]) / diff(rng), label = fmt(bk),
                 stringsAsFactors = FALSE)
    })
    ticks <- do.call(rbind, tick_rows)
    if (!is.null(ticks)) {
      # 用无边框的白底标签而不是纯文字：折线穿过刻度数字时会被白底压住，
      # 数字始终可读（纯文字会被折线从中间划过去）
      p <- p + ggplot2::geom_label(
        data = ticks, ggplot2::aes(x = x, y = y, label = label),
        hjust = 1, size = ctx$style$type$axis_text * 0.9 / ggplot2::.pt,
        colour = ctx$muted, fill = ctx$background, linewidth = 0,
        label.padding = grid::unit(0.4, "pt"), show.legend = FALSE
      )
    }

    # --- 维度名：压在每根轴线正上方，按列宽截断，避免相邻维度名叠在一起 ---
    per_axis_pt <- (ctx$width * 72) / (k - 0.5)
    name_labels <- mint_ellipsize(vars, per_axis_pt * 0.95, ctx$style$type$axis_title)
    p <- p + ggplot2::geom_text(
      data = data.frame(x = seq_len(k), y = 1.045, label = name_labels),
      ggplot2::aes(x = x, y = y, label = label), vjust = 0, size = ctx$style$type$axis_title / ggplot2::.pt,
      colour = ctx$foreground
    )

    # --- 末端直标：图例的替代品；高亮时只标被高亮的对象 ---
    if (end_labels) {
      mark <- if (has_hl) matched else ids
      mark_labels <- labels[labels %in% mark]
      # 右边留多宽取决于对象名有多长、以及维度有多少（维度多了每单位的英寸数变小）
      unit_in <- ctx$width / max(1, k - 0.3)
      max_label_in <- max(mint_text_width(mark_labels, ctx$style$type$data_label)) / 72
      right_pad <- max(0.3, max_label_in / unit_in + 0.14)
      mark_labels <- mint_ellipsize(mark_labels, right_pad * unit_in * 72, ctx$style$type$data_label)
      last <- data.frame(
        x = k + 0.07,
        y = norm[labels %in% mark, k],
        series = labels[labels %in% mark],
        label = mark_labels,
        stringsAsFactors = FALSE
      )
      p <- p + ggplot2::geom_text(
        data = last, ggplot2::aes(x = x, y = y, label = label, colour = series),
        hjust = 0, size = ctx$style$type$data_label / ggplot2::.pt, show.legend = FALSE
      )
    } else {
      right_pad <- 0.22
    }

    p +
      ggplot2::scale_colour_manual(values = fg_colors, name = NULL,
                                   guide = mint_legend_guide(show_legend)) +
      ggplot2::scale_x_continuous(limits = c(0.72, k + right_pad), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(-0.04, 1.16), expand = c(0, 0)) +
      ggplot2::labs(x = o$xLegend, y = o$yLegend) +
      mint_theme(ctx$style, ctx$family, grid = "none",
                 legend_position = if (show_legend) "top" else "none") +
      # 这张图的坐标轴是自绘的（每根轴线有各自的量纲），所以把主题自带的
      # 轴线/刻度/刻度文本关掉，只留字体与配色 token
      ggplot2::theme(
        axis.line = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.text = ggplot2::element_blank(),
        axis.title = ggplot2::element_blank()
      )
  }
))
