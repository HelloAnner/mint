# 画面排版：把「图表」放进一张带标题、副标题、脚注的版心里。
#
# 老版 mint 是在 SVG 里手写文字坐标；这里改用 grid 版心，
# 好处是标题/脚注/图表三者的对齐由布局系统保证，R 端的文字度量也和最终输出一致
# （避免「量出来的宽度」和「画出来的宽度」不一致导致的错位）。
#
# 版心结构（自上而下，单位 pt，除图表行吃掉剩余空间外都是固定高度）：
#   pad_top / title / title_gap / subtitle / subtitle_gap / [chart 弹性] / footnote_gap / footnote / pad_bottom
# 标题、副标题、脚注全部左对齐到画布左边缘 0 处，与图表的 y 轴标题同一条竖线。

#' 计算版心各行的固定高度（单位：pt）
mint_fixed_rows <- function(style, title = NULL, subtitle = NULL, footnote = NULL) {
  f <- style$frame
  rows <- list()
  add <- function(height, kind, text = NULL) {
    rows[[length(rows) + 1L]] <<- list(height = height, kind = kind, text = text)
  }

  add(f$pad_top, "blank")
  if (mint_has_text(title)) add(f$title_line * mint_line_count(title), "title", title)
  if (mint_has_text(subtitle)) {
    if (mint_has_text(title)) add(f$title_gap, "blank")
    add(f$subtitle_line * mint_line_count(subtitle), "subtitle", subtitle)
  }
  if (mint_has_text(title) || mint_has_text(subtitle)) add(f$subtitle_gap, "blank")
  add(NA, "chart")
  if (mint_has_text(footnote)) {
    add(f$footnote_gap, "blank")
    add(f$footnote_line * mint_line_count(footnote), "footnote", footnote)
  }
  add(f$pad_bottom, "blank")
  rows
}

mint_has_text <- function(x) !is.null(x) && length(x) > 0 && nzchar(trimws(as.character(x)[1])) && !is.na(x[1])

mint_line_count <- function(x) {
  if (!mint_has_text(x)) return(1)
  max(1L, length(strsplit(as.character(x)[1], "\n", fixed = TRUE)[[1]]))
}

#' 固定部分占用的高度（英寸），用于提前判断画布是否够大
mint_frame_height_in <- function(style, title = NULL, subtitle = NULL, footnote = NULL) {
  rows <- mint_fixed_rows(style, title, subtitle, footnote)
  total <- sum(vapply(rows, function(r) if (is.na(r$height)) 0 else r$height, numeric(1)))
  total / 72
}

#' 把 ggplot / gtable 的 panel 设成弹性，使其精确填满给定版心
#'
#' @param respect NULL 保持 ggplot 自己的宽高比约束（coord_fixed / coord_polar 会把 panel
#'   压成正方形，适合饼图、雷达、圆形打包这类必须等比的图）；
#'   FALSE 则让 panel 铺满版心 —— 图表自己用「与画布英寸等比例的 limits」保证 1:1
#'   （流程图、架构图、漏斗、桑基都是这么画的）。
mint_as_grob <- function(x, respect = NULL) {
  if (inherits(x, "ggplot")) return(mint_flex_gtable(ggplot2::ggplotGrob(x), respect))
  if (inherits(x, "gtable")) return(mint_flex_gtable(x, respect))
  if (inherits(x, "grob")) return(x)
  mint_fail("INTERNAL", sprintf("图表渲染函数返回了不支持的对象：%s", paste(class(x), collapse = "/")))
}

mint_flex_gtable <- function(g, respect = NULL) {
  panels <- g$layout[g$layout$name == "panel", , drop = FALSE]
  if (nrow(panels) > 0) {
    g$heights[unique(panels$t)] <- grid::unit(1, "null")
    g$widths[unique(panels$l)] <- grid::unit(1, "null")
  }
  if (isFALSE(respect)) g$respect <- FALSE
  g
}

#' 绘制整张成品图（在当前设备上）
mint_draw_figure <- function(plot, style, family, title = NULL, subtitle = NULL, footnote = NULL,
                             respect = NULL) {
  grob <- mint_as_grob(plot, respect)
  rows <- mint_fixed_rows(style, title, subtitle, footnote)
  ty <- style$type
  tok <- style$tokens

  heights <- vapply(rows, function(r) if (is.na(r$height)) 1 else r$height, numeric(1))
  units <- vapply(rows, function(r) if (is.na(r$height)) "null" else "pt", character(1))

  grid::grid.newpage()
  layout <- grid::grid.layout(nrow = length(rows), ncol = 1,
                              heights = grid::unit(heights, units))
  grid::pushViewport(grid::viewport(layout = layout))

  for (i in seq_along(rows)) {
    row <- rows[[i]]
    if (identical(row$kind, "blank")) next

    grid::pushViewport(grid::viewport(layout.pos.row = i, layout.pos.col = 1,
                                      x = 0, y = 0, just = c("left", "bottom"),
                                      width = grid::unit(1, "npc"), height = grid::unit(1, "npc")))
    if (identical(row$kind, "chart")) {
      grid::grid.draw(grob)
    } else {
      spec <- switch(row$kind,
        title = list(size = ty$title, colour = tok$fg, face = "bold"),
        subtitle = list(size = ty$subtitle, colour = tok$muted, face = "plain"),
        footnote = list(size = ty$footnote, colour = tok$muted, face = "plain"),
        list(size = ty$axis_text, colour = tok$text, face = "plain")
      )
      grid::grid.text(
        row$text,
        x = grid::unit(0, "npc"), y = grid::unit(0.5, "npc"),
        just = c("left", "centre"),
        gp = grid::gpar(fontsize = spec$size, col = spec$colour,
                        fontfamily = family, fontface = spec$face, lineheight = 1.15)
      )
    }
    grid::popViewport()
  }

  grid::popViewport()
  invisible(NULL)
}
