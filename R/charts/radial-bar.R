# 径向条形图 radial-bar
#
# 把排名弯成一圈，适合在有限宽度里塞下很多类别。这里的做法：
#   · 柱子在「内孔边缘 → 满值半径」这条环带里量长度：柱子占满整个扇区角度（所以厚实），
#     径向空间全给数据，柱外的圆周方向全是留白；
#   · 底轨不再是「铺满整条环带的浅灰盘」——那样柱子一短，整张图就变成一个大灰圆盘。
#     这里只在满值半径上画一小段浅灰刻度弧（tracks），柱子离满值差多少一眼可读，
#     又不抢画面；
#   · 类别名贴在外圈、按角度朝外伸展，数值写在环带内的柱子中间：
#     读者不用在「色块 → 图例 → 名字」之间来回找，所以不出图例；
#   · 排序默认按数值降序 —— 排名图不排序等于让读者自己做排序。
#
# 为什么不用 coord_polar：极坐标下 geom_text 的对齐方向会跟着角度转，
# 圆形四周的标签没法稳定地「朝外伸展」。这里把扇环算成多边形、
# 用 coord_fixed(1:1) 保证是正圆，位置和对齐都完全可控（radar 同理）。

#' 归一化数据：新的 [{id, value}] 走 mint_as_pairs；
#' 旧版「一个环一个系列」的 [{id, data:[{x,y}]}] 摊平成 (类别, 数值) 对，老数据不会直接报错。
mint_radial_pairs <- function(data, chart) {
  is_series <- is.list(data) && length(data) > 0 && is.null(names(data)) &&
    all(vapply(data, function(d) {
      is.list(d) && !is.null(names(d)) && !is.null(d$data) && is.null(names(d$data))
    }, logical(1)))
  if (is_series) {
    ids <- character(0)
    values <- numeric(0)
    multi <- length(data) > 1
    for (d in data) {
      for (p in d$data) {
        x <- if (is.list(p)) (p$x %||% p$label %||% p$name) else NULL
        y <- if (is.list(p)) (p$y %||% p$value) else NULL
        if (is.null(x) || !is.numeric(y)) {
          mint_fail("INVALID_DATA", sprintf("系列「%s」里有非法数据点", as.character(d$id)),
                    "每个点形如 { \"x\": \"Q1\", \"y\": 128 }")
        }
        # 多系列摊平到一个环上时带上系列名前缀，否则同名类目会撞在一起
        ids <- c(ids, if (multi) paste(as.character(d$id), as.character(x)) else as.character(x))
        values <- c(values, as.numeric(y))
      }
    }
    return(data.frame(id = ids, label = ids, value = values, stringsAsFactors = FALSE))
  }
  mint_as_pairs(data, chart)
}

#' 一个扇环的多边形（外弧 + 内弧反向拼成闭合路径），用来自绘环形的柱段
mint_radial_sector <- function(r0, r1, phi_from, phi_to, per_degree = 2) {
  span <- abs(phi_from - phi_to)
  k <- max(4L, as.integer(ceiling(span * 180 / pi * per_degree)) + 1L)
  th <- seq(phi_from, phi_to, length.out = k)
  data.frame(
    x = c(r1 * cos(th), r0 * cos(rev(th))),
    y = c(r1 * sin(th), r0 * sin(rev(th)))
  )
}

mint_register(local({
  chart <- mint_chart(
    id = "radial-bar",
    name = "径向条形图",
    english = "RadialBar",
    category = "comparison",
    description = "把条形沿圆周排布，省横向空间，适合类别很多的排名对比",
    data_shape = paste(
      "数组，每项一个类别：",
      "[",
      "  { \"id\": \"华东\", \"value\": 187 },",
      "  { \"id\": \"华北\", \"value\": 139 }",
      "]",
      "也兼容旧版「一个环一个系列」的写法 [{ \"id\": \"华东\", \"data\": [{ \"x\": \"Q1\", \"y\": 128 }] }]。",
      sep = "\n"
    ),
    variants = c("circular 环形"),
    aliases = c("径向条形图", "圆形条形", "radial bar", "环形柱状"),
    packages = c("ggplot2"),
    options = list(
      mint_option("innerRadius", "number", "内孔半径占外圈半径的比例", default = 0.3),
      mint_option("innerRatio", "number", "内孔比例的别名，写了就以它为准"),
      mint_option("padAngle", "number", "扇区之间的间隔（角度，单位度）", default = 0.6),
      mint_option("tracks", "boolean", "是否显示底轨（满值刻度弧）", default = TRUE),
      mint_option("tracksColor", "string", "底轨颜色", default = "#e8eef4"),
      mint_option("sort", "string", "排序方式", default = "desc", values = c("desc", "asc", "none")),
      mint_option("valueLabel", "boolean", "是否直接标注数值", default = TRUE),
      mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
      mint_option("decimals", "number", "小数位数"),
      mint_option("valuePrefix", "string", "数值前缀"),
      mint_option("valueSuffix", "string", "数值后缀")
    ),
    example = list(
      data = list(
        list(id = "搜索", value = 348), list(id = "社交", value = 266),
        list(id = "直邮", value = 174), list(id = "联盟", value = 122),
        list(id = "视频", value = 96), list(id = "短信", value = 64),
        list(id = "线下", value = 42)
      ),
      options = list()
    ),
    render = function(ctx) {
      o <- ctx$options
      pairs <- mint_radial_pairs(ctx$data, "radial-bar")
      if (any(!is.finite(pairs$value))) {
        mint_fail("INVALID_DATA", "radial-bar 的数值里有无穷大或缺失值", "每个类别都要有有限数值")
      }
      if (any(pairs$value < 0)) {
        mint_fail("INVALID_DATA", "radial-bar 用半径长度表达数值，负数画不出来",
                  "先取绝对值，或改用 bar / bullet 表达正负对比")
      }
      if (identical(o$sort, "desc")) pairs <- pairs[order(-pairs$value), , drop = FALSE]
      if (identical(o$sort, "asc")) pairs <- pairs[order(pairs$value), , drop = FALSE]
      rownames(pairs) <- NULL

      fmt <- ctx$formatter
      ty <- ctx$style$type
      n <- nrow(pairs)
      value_max <- max(pairs$value)
      frac <- if (value_max > 0) pairs$value / value_max else rep(0, n)

      # 几何（长度单位 = 面板半径）：内孔 + 一条环带；柱长从内孔外缘起算，
      # 最长的那根正好铺满环带，所以环带的径向空间全部由数据占用
      inner_r <- min(0.9, max(0, o$innerRatio %||% o$innerRadius %||% 0.3))
      r_in <- inner_r
      r_band <- (1 - r_in) * 0.62            # 环带厚度占径向空间的 62%
      r_out <- r_in + r_band                 # 满值柱端
      outer <- r_out + 0.30                  # 面板半径：环带之外只留类别名的位置
      label_r <- r_out + 0.07
      r_end <- r_in + frac * r_band          # 每根柱子的柱端半径

      # 第一段从正上方开始、顺时针排（和旧版 nivo 的读数顺序一致）
      slot <- 2 * pi / n
      gap <- min((o$padAngle %||% 0.6) / 360 * 2 * pi, slot * 0.6)
      phi_from <- pi / 2 - (seq_len(n) - 1) * slot - gap / 2
      phi_to <- phi_from - (slot - gap)
      phi_mid <- (phi_from + phi_to) / 2
      bar_span <- slot - gap                 # 柱子占满扇区角度，长度由半径表达
      cap <- r_band * 0.16                   # 底轨（满值刻度弧）的厚度

      # 标签朝外伸展：cos 决定横向、sin 决定纵向 —— 标签框的内角始终落在圆外
      hjust <- ifelse(cos(phi_mid) > 0.2, 0, ifelse(cos(phi_mid) < -0.2, 1, 0.5))
      vjust <- ifelse(sin(phi_mid) > 0.2, -1, ifelse(sin(phi_mid) < -0.2, 1, 0))

      radius_in <- 0.5 * min(ctx$width, ctx$height) / outer   # 数据单位 -> 英寸
      label_pt <- ty$data_label
      # 某半径处一段弧的可用宽度（pt），用来判断文字放不放得下
      arc_pt <- function(span, r) span * r * radius_in * 72
      # 类别名的折行宽度取「径向留白」与「扇区弧宽」里更小的那个
      wrap_pt <- max(24, min((outer - label_r) * radius_in * 72,
                             arc_pt(slot - gap, label_r) * 0.86))

      names_txt <- mint_wrap(pairs$label, wrap_pt, size = label_pt)
      show_values <- !identical(o$valueLabel, FALSE)
      values_txt <- fmt(pairs$value)
      text_pt <- vapply(values_txt, function(t) mint_text_width(t, label_pt), numeric(1))
      # 数字写在柱内靠柱端（短柱就落在柱子中间）：径向、切向都留够余量才标，
      # 否则文字会压出柱子外面，白字落到白底上就读不清了
      value_r <- pmax((r_in + r_end) / 2, r_end - r_band * 0.12)
      room_pt <- function(i) {
        radial <- 2 * min(value_r[i] - r_in, r_end[i] - value_r[i]) * radius_in * 72
        min(arc_pt(slot - gap, value_r[i]), radial)
      }
      keep <- vapply(seq_len(n), function(i) text_pt[i] <= room_pt(i) * 0.92, logical(1))

      # 同名的类目也要各画各的段：键唯一，颜色和分组才不会粘在一起
      keys <- make.unique(as.character(pairs$label))
      colors <- stats::setNames(mint_colors(n, ctx$colors), keys)
      ids <- factor(keys, levels = keys)
      sector <- function(i, r0, r1, span) {
        s <- mint_radial_sector(r0, r1, phi_from[i], phi_from[i] - span)
        s$id <- ids[i]
        s
      }
      bars <- do.call(rbind, lapply(seq_len(n), function(i) {
        sector(i, r_in, r_end[i], bar_span)
      }))

      p <- ggplot2::ggplot()
      # 底轨 = 满值半径上的一小段浅灰刻度弧：只回答「满值在哪」，不铺满整个环带
      if (!identical(o$tracks, FALSE)) {
        tracks <- do.call(rbind, lapply(seq_len(n), function(i) {
          sector(i, r_out - cap, r_out, bar_span)
        }))
        p <- p + ggplot2::geom_polygon(
          data = tracks, ggplot2::aes(x = x, y = y, group = id),
          fill = o$tracksColor %||% "#f1f5f9", colour = NA
        )
      }

      p <- p + ggplot2::geom_polygon(
        data = bars, ggplot2::aes(x = x, y = y, group = id, fill = id), colour = NA
      )

      if (show_values && any(keep)) {
        idx <- which(keep)
        # 深色柱配白字、浅色柱配深字，任何调色板下都读得清
        luminance <- vapply(colors[keys[idx]], function(hex) {
          sum(grDevices::col2rgb(hex) * c(0.299, 0.587, 0.114)) / 255
        }, numeric(1))
        value_labels <- data.frame(
          x = value_r[idx] * cos(phi_mid[idx]),
          y = value_r[idx] * sin(phi_mid[idx]),
          label = values_txt[idx],
          colour = ifelse(luminance > 0.62, "#3D3D3D", "#FFFFFF"),
          stringsAsFactors = FALSE
        )
        p <- p + ggplot2::geom_text(
          data = value_labels, ggplot2::aes(x = x, y = y, label = label),
          colour = value_labels$colour, size = label_pt / ggplot2::.pt
        )
      }

      # 类别名贴在外圈：按角度朝外伸展，一圈名字不会互相压住
      name_labels <- data.frame(
        x = label_r * cos(phi_mid), y = label_r * sin(phi_mid),
        label = names_txt, hjust = hjust, vjust = vjust, stringsAsFactors = FALSE
      )

      p + ggplot2::geom_text(
        data = name_labels,
        ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust),
        size = label_pt / ggplot2::.pt, colour = ctx$text, lineheight = 1.15
      ) +
        ggplot2::scale_fill_manual(values = colors, name = NULL, guide = "none") +
        ggplot2::scale_x_continuous(limits = c(-outer, outer), expand = c(0, 0)) +
        ggplot2::scale_y_continuous(limits = c(-outer, outer), expand = c(0, 0)) +
        ggplot2::coord_fixed(ratio = 1, clip = "off") +
        mint_theme(ctx$style, ctx$family, grid = "none", legend_position = "none") +
        ggplot2::theme(
          axis.line = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          axis.text = ggplot2::element_blank(),
          axis.title = ggplot2::element_blank()
        )
    }
  )
  # 圆形图：默认的宽画布会把圆压小、两侧留一大片空白（spec.R 支持 aspect）
  chart$aspect <- 1.12
  chart
}))
