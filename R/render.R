# 渲染管线：spec + data -> 成品图（PNG / SVG）
#
#   normalize -> 组装 ctx -> 图表 render() 返回 ggplot/grob -> 版心排版 -> 输出设备
#
# 图表拿到的是「图表区」的英寸尺寸（已扣掉标题/副标题/脚注占用的固定高度），
# 这样每个图表只需要关心自己的绘图区。

mint_build_figure <- function(chart, spec, data = NULL) {
  style <- spec$style_def
  family <- mint_resolve_family(style, spec$font_family)

  header_in <- mint_frame_height_in(style, spec$title, spec$subtitle, spec$footnote)
  chart_height <- spec$height - header_in
  if (chart_height < 0.8 || spec$width < 1) {
    mint_fail("CANVAS_TOO_SMALL",
              sprintf("画布太小：图表区只剩 %.2f×%.2f in", spec$width, chart_height),
              "调大 --width / --height，或去掉标题/脚注")
  }

  payload <- data %||% chart$example$data
  if (is.null(payload)) {
    mint_fail("INVALID_DATA", sprintf("图表 %s 没有内置示例数据，请用 --data 指定", chart$id))
  }

  # 用内置示例数据演示时，把示例自带的选项（轴标题等）也带上，
  # 这样 `mint render bar` 出来的就是一张完整的成品图
  options <- spec$options
  if (is.null(data) && length(chart$example$options %||% list()) > 0) {
    options <- mint_normalize_options(chart, utils::modifyList(chart$example$options, spec$options_raw %||% list()))
  }

  ctx <- list(
    data = payload,
    options = options,
    width = spec$width,
    height = chart_height,
    family = family,
    style = style,
    palette = spec$palette_def,
    colors = mint_colors(24, spec$palette_def$colors),
    background = style$tokens$bg,
    foreground = style$tokens$fg,
    text = style$tokens$text,
    muted = style$tokens$muted,
    grid = style$tokens$grid,
    ref = style$tokens$ref,
    formatter = mint_formatter(spec$options)
  )

  mint_load_packages(chart)
  plot <- chart$render(ctx)
  if (is.null(plot)) {
    mint_fail("INTERNAL", sprintf("图表 %s 没有返回任何图形对象", chart$id))
  }

  list(plot = plot, style = style, family = family, spec = spec, ctx = ctx)
}

mint_render <- function(chart, spec, data = NULL, out_path, format = NULL, quiet = FALSE) {
  format <- format %||% spec$format
  figure <- mint_build_figure(chart, spec, data = data)
  style <- figure$style

  draw <- function() {
    mint_draw_figure(figure$plot, style, figure$family, spec$title, spec$subtitle, spec$footnote,
                     respect = chart$respect)
  }
  files <- mint_write_outputs(spec, draw, out_path, format)

  list(
    chart = chart$id,
    files = files,
    width = spec$width,
    height = spec$height,
    dpi = spec$dpi,
    pixel_width = round(spec$width * spec$dpi),
    pixel_height = round(spec$height * spec$dpi),
    chart_width = spec$width,
    chart_height = figure$ctx$height,
    format = format,
    palette = spec$palette,
    style = style$id,
    family = figure$family
  )
}

#' 渲染并给出统一的终端输出
mint_render_command <- function(chart, spec, data, out_path, format, json = FALSE, quiet = FALSE) {
  started <- Sys.time()
  result <- mint_render(chart, spec, data = data, out_path = out_path, format = format, quiet = quiet)
  result$elapsed_ms <- round(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000)

  if (json) {
    cat(as.character(mint_to_json(result, pretty = TRUE)), "\n", sep = "")
  } else if (!quiet) {
    for (file in result$files) {
      size <- file.info(file)$size
      cat(sprintf("%s  %s  %.1f KB  %.0f×%.0f @%ddpi  %s\n",
                  file, result$chart, size / 1024,
                  result$pixel_width, result$pixel_height, result$dpi, result$family))
    }
  }
  invisible(result)
}
