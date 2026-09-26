# 输出设备：PNG 走 ragg，SVG 走 svglite。
# 两者都是 grid 设备，因此同一套绘图代码可以原样输出位图与可编辑矢量图。

mint_supported_formats <- function() c("png", "svg", "both")

#' 在指定设备上绘制
#'
#' @param format "png" | "svg"
#' @param path 输出路径
#' @param draw 无参函数，负责把图 draw 到当前设备
mint_with_device <- function(format, path, width, height, dpi, bg, draw) {
  dir <- dirname(path)
  if (nzchar(dir) && !dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  if (identical(format, "png")) {
    ragg::agg_png(
      filename = path, width = width, height = height, units = "in",
      res = dpi, background = bg, scaling = 1
    )
  } else if (identical(format, "svg")) {
    # svglite 各版本的参数名有差异，只传它确实支持的参数
    supported <- names(formals(svglite::svglite))
    args <- list(filename = path, width = width, height = height, bg = bg, standalone = TRUE)
    args <- args[names(args) %in% supported]
    do.call(svglite::svglite, args)
  } else {
    mint_fail("INVALID_FORMAT", sprintf("不支持的输出格式：%s", format))
  }

  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  invisible(path)
}

#' 按 spec 输出 png（必要时同时输出 svg），返回写出的文件列表
mint_write_outputs <- function(spec, draw, out_path, format) {
  base <- sub("\\.(png|svg)$", "", out_path)
  written <- character(0)

  if (format %in% c("png", "both")) {
    png_path <- paste0(base, ".png")
    mint_with_device("png", png_path, spec$width, spec$height, spec$dpi, spec$background, draw)
    written <- c(written, png_path)
  }
  if (format %in% c("svg", "both")) {
    svg_path <- paste0(base, ".svg")
    mint_with_device("svg", svg_path, spec$width, spec$height, spec$dpi, spec$background, draw)
    written <- c(written, svg_path)
  }
  written
}
