# 漏斗图 funnel
#
# 自绘的原因：漏斗图的两条硬约束——「层宽正比于数值」和「层高完全相同」——只有在已知
# 画布英寸尺寸的真实坐标系里才能精确满足；交给通用绘图库还得反过来对抗它的默认间距。
# 宽度传达量级，等高传达流程节奏，两者缺一不可。
#
# 配色用同一主色的深浅序（而不是每层一个撞色）：层与层是同一条流程的不同阶段，
# 颜色只用来提示「越往下越少」，不该引入额外的语义。

mint_funnel_text_w <- function(text, size) {
  if (length(text) == 0) return(numeric(0))
  mint_text_width(text, size) / 72
}

mint_register(mint_chart(
  id = "funnel",
  name = "漏斗图",
  english = "Funnel",
  category = "flow",
  description = "展示多级流程中每一步的留存与流失，适合转化率分析",
  data_shape = paste(
    "按流程顺序排列：",
    "[",
    "  { \"id\": \"访问\", \"label\": \"访问落地页\", \"value\": 12000 },",
    "  { \"id\": \"注册\", \"label\": \"注册账号\", \"value\": 4800 }",
    "]",
    "也支持 { \"访问\": 12000, \"注册\": 4800 } 或 [[\"访问\", 12000], [\"注册\", 4800]]。",
    sep = "\n"
  ),
  variants = c("funnel 漏斗"),
  aliases = c("漏斗", "转化", "funnel", "转化率"),
  packages = c("ggplot2"),
  options = list(
    mint_option("spacing", "number", "层与层之间的缝隙（pt）", default = 4),
    mint_option("shapeBlending", "number", "层内斜面的融合程度：0 为上下贯通的连续斜面，1 为纯台阶", default = 0.66),
    mint_option("valueLabel", "boolean", "是否直接标注数值与转化率", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      list(id = "visit", label = "访问落地页", value = 12000),
      list(id = "signup", label = "注册账号", value = 4800),
      list(id = "active", label = "完成激活", value = 2600),
      list(id = "order", label = "首次下单", value = 1900),
      list(id = "repeat", label = "复购", value = 860)
    ),
    options = list(valueFormat = "number")
  ),
  render = function(ctx) {
    o <- ctx$options
    pairs <- mint_as_pairs(ctx$data, "funnel")
    fmt <- ctx$formatter
    n <- nrow(pairs)
    width <- ctx$width
    height <- ctx$height

    if (any(pairs$value < 0)) {
      bad <- which(pairs$value < 0)[1]
      mint_fail("INVALID_DATA",
                sprintf("漏斗图的数值不能为负：第 %d 层「%s」是 %s", bad, pairs$label[bad], fmt(pairs$value[bad])),
                "层宽是按数值占比折算的，负值没有对应的宽度")
    }
    if (max(pairs$value) <= 0) {
      mint_fail("INVALID_DATA", "漏斗图所有层的数值都是 0，画不出宽度",
                "至少让第一层的 value 大于 0")
    }

    blend <- min(1, max(0, o$shapeBlending %||% 0.66))
    gap <- max(0, o$spacing %||% 4) / 72
    show_value <- !identical(o$valueLabel, FALSE)
    name_size <- ctx$style$type$axis_text
    detail_size <- ctx$style$type$footnote

    # 文字先量好：右侧标签列要多宽，决定了漏斗本体能占多宽
    text_w <- mint_funnel_text_w
    # 两行：第一行阶段名（粗体），第二行「数值 · 转化率 · 整体占比」。
    # 数值不另起一列：中英混排的实际字宽和度量值差得远，单行排下来才不会出现
    # 「名字这头、数字那头」的断裂感
    first_value <- pairs$value[1]
    value_text <- if (show_value) fmt(pairs$value) else rep("", n)
    detail <- rep("", n)
    if (show_value) {
      detail <- vapply(seq_len(n), function(i) {
        share <- if (first_value > 0) sprintf("%.1f%%", 100 * pairs$value[i] / first_value) else "—"
        if (i == 1) return(sprintf("%s · 整体 %s", value_text[i], share))
        conv <- if (pairs$value[i - 1] > 0) sprintf("%.1f%%", 100 * pairs$value[i] / pairs$value[i - 1]) else "—"
        sprintf("%s · 转化 %s · 整体 %s", value_text[i], conv, share)
      }, character(1))
    }
    label_w <- max(text_w(pairs$label, name_size), text_w(detail, detail_size))

    pad <- 0.10
    tick <- 0.10
    funnel_w <- width - pad - tick - label_w - 0.06
    if (funnel_w < 0.8) {
      mint_fail("CANVAS_TOO_SMALL",
                sprintf("漏斗图需要至少 %.2f in 画布宽度（标签列 %.2f in），当前只有 %.2f in",
                        0.8 + pad + tick + label_w + 0.06, label_w, width),
                "调大 --width，或缩短阶段名称 / 数值前后缀")
    }
    band_raw <- (height - 2 * pad - (n - 1) * gap) / n
    if (band_raw < 0.14) {
      mint_fail("CANVAS_TOO_SMALL",
                sprintf("%d 层漏斗每层只剩 %.2f in 高，文字放不下", n, band_raw),
                sprintf("调大 --height（至少 %.2f in），或减少阶段数", 2 * pad + n * 0.14 + (n - 1) * gap))
    }
    # 层太高会让 3 层漏斗被拉成两根大柱子，超过阀值就整体竖向居中，保持图形比例
    band_h <- min(band_raw, 1.1)
    top <- pad + (height - 2 * pad - (n * band_h + (n - 1) * gap)) / 2
    cx <- pad + funnel_w / 2

    # 层宽：按占最大值的比例，零值层保留一根细缝而不是消失
    rel <- pairs$value / max(pairs$value)
    own <- pmax(rel * funnel_w, 1.5 / 72)
    prev_w <- c(own[1], own[-n])
    next_w <- c(own[-1], own[n])
    w_top <- own + (prev_w - own) * (1 - blend)
    w_bot <- own + (next_w - own) * (1 - blend)

    # 坐标一律先按「从上往下」算，最后翻成 ggplot 的 y 轴方向，读代码时顺序不乱
    y0 <- top + (seq_len(n) - 1) * (band_h + gap)
    y1 <- y0 + band_h
    polys <- do.call(rbind, lapply(seq_len(n), function(i) {
      data.frame(
        group = i,
        x = cx + c(-w_top[i], w_top[i], w_bot[i], -w_bot[i]) / 2,
        y = height - c(y0[i], y0[i], y1[i], y1[i])
      )
    }))
    fills <- mint_ramp(ctx$colors[1], n, from = 1, to = 0.34)
    polys$fill <- fills[polys$group]

    yc <- (y0 + y1) / 2
    label_x <- pad + funnel_w + tick
    # 细引线把层和右侧标签钉在一起：漏斗右缘随层宽变化，没有引线读者要靠猜
    ticks <- data.frame(
      x = cx + (w_top + w_bot) / 4 + 0.012,
      xend = label_x - 0.03,
      y = height - yc
    )

    texts <- list(data.frame(
      x = label_x, y = height - yc + if (show_value) 0.05 else 0, label = pairs$label,
      size = name_size, colour = ctx$foreground, face = "bold", hjust = 0
    ))
    if (show_value) {
      texts[[2]] <- data.frame(
        x = label_x, y = height - yc - 0.06, label = detail,
        size = detail_size, colour = ctx$text, face = "plain", hjust = 0
      )
    }
    text_df <- do.call(rbind, texts)

    p <- ggplot2::ggplot() +
      ggplot2::geom_polygon(
        data = polys, ggplot2::aes(x = x, y = y, group = group),
        fill = polys$fill, colour = NA
      ) +
      ggplot2::geom_segment(
        data = ticks, ggplot2::aes(x = x, xend = xend, y = y, yend = y),
        colour = ctx$grid, linewidth = ctx$style$geoms$grid_width
      ) +
      ggplot2::geom_text(
        data = text_df,
        ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
        size = text_df$size / ggplot2::.pt, colour = text_df$colour,
        fontface = text_df$face, lineheight = 1.15
      ) +
      ggplot2::scale_x_continuous(limits = c(0, width), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, height), expand = c(0, 0)) +
      # 不用 coord_fixed：本仓的版心把 panel 的 null 宽高强行归一，coord_fixed 会把
      # panel 压成正方形，x 方向被压缩；改用精确 limits 的 coord_cartesian，
      # 数据单位与画布英寸才是 1:1（已用探针图逐像素核对）
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )

    p
  }
))
