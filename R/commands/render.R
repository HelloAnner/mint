# mint render <chart>

MINT_RENDER_FLAGS <- list(
  mint_flag("data", "d", "string", "数据 JSON 文件，- 表示从 stdin 读", "<file|->"),
  mint_flag("out", "o", "string", "输出路径（不带扩展名会自动补）", "<file>"),
  mint_flag("title", "t", "string", "标题"),
  mint_flag("subtitle", "S", "string", "副标题"),
  mint_flag("footnote", NULL, "string", "脚注"),
  mint_flag("width", "W", "string", "画布宽度，英寸", "<in>"),
  mint_flag("height", "H", "string", "画布高度，英寸", "<in>"),
  mint_flag("dpi", NULL, "string", "分辨率，默认 300", "<n>"),
  mint_flag("format", "f", "string", "输出格式 png / svg / both", "<fmt>"),
  mint_flag("palette", "p", "string", "调色板 id，见 mint palettes", "<id>"),
  mint_flag("style", NULL, "string", "风格 id，见 mint styles", "<id>"),
  mint_flag("font-family", NULL, "string", "字体家族名（默认自动探测中文字体）", "<name>"),
  mint_flag("set", NULL, "list", "图表选项 key=value，可重复", "<k=v>"),
  mint_flag("options", NULL, "string", "图表选项的 JSON 对象", "<json>"),
  mint_flag("json", NULL, "boolean", "输出机器可读结果"),
  mint_flag("quiet", "q", "boolean", "静默模式")
)

mint_render_help <- function() {
  paste0(
    "用法：mint render <chart> [选项]\n\n",
    paste(mint_flag_table(MINT_RENDER_FLAGS), collapse = "\n"), "\n\n",
    "示例：\n",
    "  mint render bar --data revenue.json --title \"各区域季度营收\" -o revenue.png\n",
    "  mint render scatter -d points.json --set trend=true --set xLabel=\"浓度\" -o fit.svg\n",
    "  cat data.json | mint render line -d - -o - --format svg > line.svg\n\n",
    "画布尺寸用英寸：期刊单栏 3.5in、双栏 7in（默认）。\n"
  )
}

mint_cmd_render <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, MINT_RENDER_FLAGS)
  chart_id <- parsed$positionals[[1]]
  if (is.null(chart_id)) {
    mint_fail("MISSING_ARGUMENT", "mint render 需要一个图表 id",
              sprintf("例如 mint render bar -o bar.png。可用图表：%s", paste(mint_chart_ids(), collapse = ", ")))
  }
  chart <- mint_require_chart(chart_id)

  loaded <- mint_load_data(mint_arg(parsed, "data"))
  out <- mint_arg(parsed, "out") %||% paste0(chart$id, ".png")
  format <- mint_arg(parsed, "format") %||% mint_format_from_path(out)

  options <- c(
    mint_parse_options_json(mint_arg(parsed, "options")),
    mint_parse_set_flags(mint_arg(parsed, "set"))
  )

  spec <- mint_normalize_spec(chart, list(
    title = mint_arg(parsed, "title"),
    subtitle = mint_arg(parsed, "subtitle"),
    footnote = mint_arg(parsed, "footnote"),
    width = mint_arg(parsed, "width"),
    height = mint_arg(parsed, "height"),
    dpi = mint_arg(parsed, "dpi"),
    format = mint_arg(parsed, "format"),
    style = mint_arg(parsed, "style"),
    palette = mint_arg(parsed, "palette"),
    font_family = mint_arg(parsed, "font-family"),
    options = options
  ))

  if (identical(out, "-")) {
    return(mint_render_stdout(chart, spec, loaded, parsed))
  }

  result <- mint_render_command(chart, spec, loaded$data, out_path = out, format = format,
                                json = isTRUE(mint_arg(parsed, "json")),
                                quiet = isTRUE(mint_arg(parsed, "quiet")))
  0L
}

#' 按输出扩展名推断格式（用户显式传 --format 时不走这里）
mint_format_from_path <- function(path) {
  if (grepl("\\.svg$", path, ignore.case = TRUE)) return("svg")
  "png"
}

#' -o - ：把 SVG 打到 stdout（PNG 是二进制，不支持）
mint_render_stdout <- function(chart, spec, loaded, parsed) {
  if (!identical(spec$format, "svg")) {
    mint_fail("INVALID_VALUE", "只有 SVG 能输出到 stdout", "用 -o 指定文件路径输出 PNG")
  }
  tmp <- tempfile(fileext = ".svg")
  on.exit(unlink(tmp), add = TRUE)
  mint_render(chart, spec, data = loaded$data, out_path = tmp, format = "svg")
  cat(paste(readLines(tmp, warn = FALSE), collapse = "\n"), "\n", sep = "")
  0L
}
