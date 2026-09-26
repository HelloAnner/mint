# 风格。
#
# mint 的视觉语言集中在这里：一个风格 = 一套排版尺度 + 一组颜色 token + 一组几何参数。
# 目前实现一种：professional（期刊级、克制、高信息密度）。
# 后续要加风格（例如汇报用的 vivid、暗色 dark），只需往 MINT_STYLES 里加一条。
#
# professional 的设计约束（有意为之，不随手改）：
#   1. 不用渐变、不用圆角、不用阴影 —— 印刷后容易脏，且抢数据本身的信息；
#   2. 只用极浅的实线网格，且只在数值轴方向 —— 网格是辅助读数，不是装饰；
#   3. 轴线细（0.4pt）、刻度短（1.6pt）、字号小（7pt 起）—— 同尺寸下塞进更多信息；
#   4. 默认打数据标签、默认紧凑图例（单系列不出图例）—— 让读者不用来回比对图例；
#   5. 画布默认 7 × 4.35 in / 300 dpi —— 期刊双栏满宽的标准尺寸。

MINT_STYLES <- list(
  professional = list(
    id = "professional",
    name = "专业（期刊级）",
    description = "克制的期刊风格：细轴线、浅网格、小字号、高信息密度，适合论文与正式报告",

    # 字体优先级：优先能同时覆盖中英文的家族，再回退到纯拉丁家族
    font_preferences = c(
      "Inter", "Helvetica Neue", "PingFang SC", "Hiragino Sans GB",
      "Noto Sans CJK SC", "Source Han Sans SC", "Noto Sans SC",
      "Arial Unicode MS", "Helvetica", "Arial", "DejaVu Sans", "sans"
    ),

    default_width = 7,
    default_height = 4.35,
    default_dpi = 300,

    tokens = list(
      bg = "#FFFFFF",
      fg = "#1A1A1A",     # 标题
      text = "#3D3D3D",   # 刻度、图例、数据标签
      muted = "#6E6E6E",  # 轴标题、副标题、脚注
      grid = "#E6E6E6",
      axis = "#333333",
      ref = "#A3A3A3",    # 参考线
      label_light = "#FFFFFF"
    ),

    type = list(
      axis_text = 7,
      axis_title = 7.5,
      legend_text = 7,
      legend_title = 7.5,
      data_label = 6.5,
      strip_text = 7.5,
      title = 11,
      subtitle = 8,
      footnote = 6.5
    ),

    geoms = list(
      grid_width = 0.3,
      axis_width = 0.4,
      tick_length = 1.6,
      bar_width = 0.68,
      line_width = 0.55,
      point_size = 1.1,
      point_stroke = 0.4,
      area_alpha = 0.15,
      ribbon_alpha = 0.22,
      tile_border = 0.12,
      band_alpha = 0.35
    ),

    frame = list(
      pad_x = 0,
      pad_top = 0.5,
      pad_bottom = 0.5,
      title_line = 13,
      subtitle_line = 10,
      footnote_line = 9,
      title_gap = 3,
      subtitle_gap = 8,
      footnote_gap = 6
    ),

    legend = list(position = "top", key_size = 9, spacing = 3)
  )
)

MINT_DEFAULT_STYLE <- "professional"

mint_styles <- function() MINT_STYLES

mint_get_style <- function(id = NULL) {
  id <- id %||% MINT_DEFAULT_STYLE
  style <- MINT_STYLES[[id]]
  if (is.null(style)) {
    mint_fail("UNKNOWN_STYLE", sprintf("没有名为「%s」的风格", id),
              sprintf("可用风格：%s（用 mint styles 查看）", paste(names(MINT_STYLES), collapse = ", ")))
  }
  style
}

#' 构造 ggplot2 主题
#'
#' @param style mint_get_style() 的结果
#' @param family 字体家族名
#' @param grid 网格方向："y"（默认，数值轴在 y）/"x"/"both"/"none"
#' @param legend_position 图例位置，默认取 style$legend$position
mint_theme <- function(style, family, grid = "y", legend_position = NULL) {
  t <- style$tokens
  ty <- style$type
  g <- style$geoms
  lg <- style$legend

  grid_x <- switch(grid, "x" = TRUE, "both" = TRUE, FALSE)
  grid_y <- switch(grid, "y" = TRUE, "both" = TRUE, FALSE)

  theme <- ggplot2::theme_minimal(base_family = family, base_size = ty$axis_text) +
    ggplot2::theme(
      text = ggplot2::element_text(family = family, colour = t$text),
      plot.background = ggplot2::element_rect(fill = t$bg, colour = NA),
      panel.background = ggplot2::element_rect(fill = t$bg, colour = NA),
      plot.margin = ggplot2::margin(0, 0, 0, 0),

      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = if (grid_x) ggplot2::element_line(colour = t$grid, linewidth = g$grid_width) else ggplot2::element_blank(),
      panel.grid.major.y = if (grid_y) ggplot2::element_line(colour = t$grid, linewidth = g$grid_width) else ggplot2::element_blank(),
      panel.border = ggplot2::element_blank(),
      panel.spacing = grid::unit(7, "pt"),

      axis.line = ggplot2::element_line(colour = t$axis, linewidth = g$axis_width),
      axis.line.x.top = ggplot2::element_blank(),
      axis.line.y.right = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_line(colour = t$axis, linewidth = g$axis_width),
      axis.ticks.length = grid::unit(g$tick_length, "pt"),
      axis.ticks.x.top = ggplot2::element_blank(),
      axis.ticks.y.right = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = t$text, size = ty$axis_text),
      axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 2)),
      axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 2)),
      axis.title = ggplot2::element_text(colour = t$muted, size = ty$axis_title),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 4)),
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 4)),

      legend.background = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(colour = t$text, size = ty$legend_text),
      legend.title = ggplot2::element_text(colour = t$muted, size = ty$legend_title),
      legend.key.size = grid::unit(lg$key_size, "pt"),
      legend.spacing.x = grid::unit(lg$spacing, "pt"),
      legend.spacing.y = grid::unit(2, "pt"),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin = ggplot2::margin(0, 0, 0, 0),
      legend.box.spacing = grid::unit(4, "pt"),
      legend.position = legend_position %||% lg$position,
      legend.justification = "left",

      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(colour = t$fg, size = ty$strip_text, face = "bold",
                                         hjust = 0, margin = ggplot2::margin(b = 3)),

      plot.title = ggplot2::element_text(colour = t$fg, size = ty$title, face = "bold",
                                         margin = ggplot2::margin(b = 2), hjust = 0, family = family),
      plot.subtitle = ggplot2::element_text(colour = t$muted, size = ty$subtitle,
                                            margin = ggplot2::margin(b = 6), hjust = 0, family = family),
      plot.caption = ggplot2::element_text(colour = t$muted, size = ty$footnote,
                                           margin = ggplot2::margin(t = 6), hjust = 0, family = family),
      complete = TRUE
    )

  theme
}

#' 分类色标（填充）
mint_scale_fill <- function(colors, values = NULL, name = NULL, labels = NULL) {
  vals <- if (is.null(values)) colors else stats::setNames(colors, values)
  ggplot2::scale_fill_manual(values = vals, name = name, labels = labels, na.value = "#D9D9D9")
}

#' 分类色标（线条/点）
mint_scale_colour <- function(colors, values = NULL, name = NULL, labels = NULL) {
  vals <- if (is.null(values)) colors else stats::setNames(colors, values)
  ggplot2::scale_colour_manual(values = vals, name = name, labels = labels, na.value = "#D9D9D9")
}

#' 连续色标（热力图、日历图等）
#'
#' 尺寸一律走主题里的 legend.key.size —— 这是踩过坑的：
#' ggplot2 3.5 起 guide_colourbar() 的 barwidth / barheight 已废弃，传了会算不出图例尺寸
#' （整条色标被挤没或被画布裁掉）；而显式设置 theme 里的 legend.key.width/height
#' 在 4.0.3 上同样会让色标宽度算错、被右边界裁切。保持默认最稳。
mint_scale_fill_continuous <- function(palette = NULL, reverse = FALSE, name = NULL, labels = NULL) {
  ggplot2::scale_fill_gradientn(
    colours = mint_get_ramp(palette, reverse),
    name = name, labels = labels,
    guide = ggplot2::guide_colourbar(
      frame.colour = NA,
      ticks.colour = "#B5B5B5",
      ticks.linewidth = 0.3
    )
  )
}

#' 数值轴默认断点：密度比 ggplot 默认更高一档
mint_breaks <- function(n = 6) {
  scales::breaks_pretty(n = n)
}

#' 统一的取值格式化闭包（由选项决定）
mint_axis_labels <- function(options = list()) {
  fmt <- mint_formatter(options)
  fmt
}

#' 单系列时不出图例
mint_legend_guide <- function(show) {
  if (isTRUE(show)) "legend" else "none"
}
