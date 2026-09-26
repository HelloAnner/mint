# spec 归一化：把命令行/JSON 的输入收敛成一份完整、类型正确的渲染请求。
#
# 关键设计：宽度/高度用英寸（期刊排版单位），分辨率用 dpi。
# 老版的「逻辑像素 + scale」在专业排版场景下没意义，
# 7in @300dpi = 2100px 才是论文里真正需要的东西。

mint_spec_defaults <- function(style) {
  list(
    width = style$default_width,
    height = style$default_height,
    dpi = style$default_dpi,
    format = "png",
    style = style$id,
    palette = MINT_DEFAULT_PALETTE,
    theme = "light",
    language = "zh",
    options = list()
  )
}

mint_as_positive_number <- function(value, field, fallback) {
  if (is.null(value) || length(value) == 0) return(fallback)
  num <- suppressWarnings(as.numeric(value[[1]]))
  if (is.na(num) || num <= 0) {
    mint_fail("INVALID_SPEC", sprintf("%s 必须是正数，收到「%s」", field, as.character(value[[1]])))
  }
  num
}

mint_as_choice <- function(value, field, choices, fallback) {
  if (is.null(value) || length(value) == 0) return(fallback)
  text <- tolower(as.character(value[[1]]))
  if (!text %in% choices) {
    mint_fail("INVALID_SPEC", sprintf("%s 只能是 %s，收到「%s」", field, paste(choices, collapse = " / "), text))
  }
  text
}

#' 图表选项默认值
mint_option_defaults <- function(chart) {
  out <- list()
  for (opt in mint_chart_options(chart)) {
    if (!is.null(opt$default)) out[[opt$key]] <- opt$default
  }
  out
}

#' 把用户给的选项按声明类型做容错转换；未声明的键原样透传
mint_normalize_options <- function(chart, raw = NULL) {
  out <- mint_option_defaults(chart)
  if (is.null(raw) || length(raw) == 0) return(out)

  specs <- mint_chart_options(chart)
  names(specs) <- vapply(specs, function(s) s$key, character(1))

  for (key in names(raw)) {
    value <- raw[[key]]
    spec <- specs[[key]]
    if (is.null(spec)) {
      out[[key]] <- value
      next
    }
    out[[key]] <- switch(spec$type,
      boolean = mint_coerce_bool(value, key),
      number = mint_coerce_number(value, key),
      string = mint_coerce_string(value, key),
      array = mint_coerce_array(value, key),
      object = value,
      value
    )
  }
  out
}

mint_coerce_bool <- function(value, key) {
  if (is.logical(value)) return(value[1])
  if (is.numeric(value)) return(value[1] != 0)
  text <- tolower(trimws(as.character(value)[1]))
  if (text %in% c("true", "1", "yes", "y", "on")) return(TRUE)
  if (text %in% c("false", "0", "no", "n", "off")) return(FALSE)
  mint_fail("INVALID_VALUE", sprintf("选项 %s 需要布尔值，收到「%s」", key, as.character(value)[1]))
}

mint_coerce_number <- function(value, key) {
  num <- suppressWarnings(as.numeric(value[[1]]))
  if (is.na(num)) {
    mint_fail("INVALID_VALUE", sprintf("选项 %s 需要数值，收到「%s」", key, as.character(value[[1]])))
  }
  num
}

mint_coerce_string <- function(value, key) {
  if (length(value) > 1) return(as.character(unlist(value)))
  as.character(value)[1]
}

mint_coerce_array <- function(value, key) {
  if (is.list(value)) return(unlist(value, use.names = FALSE))
  if (length(value) > 1) return(as.character(value))
  text <- as.character(value)[1]
  parts <- trimws(strsplit(text, ",", fixed = TRUE)[[1]])
  parts[nzchar(parts)]
}

#' 归一化整份 spec
mint_normalize_spec <- function(chart, raw = list(), base = NULL) {
  style_id <- raw$style %||% base$style %||% MINT_DEFAULT_STYLE
  style <- mint_get_style(style_id)
  defaults <- mint_spec_defaults(style)

  title <- raw$title %||% base$title
  subtitle <- raw$subtitle %||% base$subtitle
  footnote <- raw$footnote %||% base$footnote
  width <- mint_as_positive_number(raw$width, "width", base$width %||% defaults$width)

  # 固定长宽比的图表（饼图、雷达、圆形打包等）在用户没指定高度时，
  # 按 aspect 把画布撑成合适比例，避免把方图塞进宽画布、两侧留一大片空白
  height_raw <- raw$height %||% base$height
  height <- if (is.null(height_raw) && !is.null(chart$aspect)) {
    width / chart$aspect + mint_frame_height_in(style, title, subtitle, footnote)
  } else {
    mint_as_positive_number(height_raw, "height", defaults$height)
  }

  spec <- list(
    chart = chart$id,
    title = title,
    subtitle = subtitle,
    footnote = footnote,
    width = width,
    height = height,
    dpi = mint_as_positive_number(raw$dpi, "dpi", base$dpi %||% defaults$dpi),
    format = mint_as_choice(raw$format, "format", mint_supported_formats(),
                            base$format %||% defaults$format),
    style = style$id,
    palette = raw$palette %||% base$palette %||% defaults$palette,
    font_family = raw$font_family %||% raw$fontFamily %||% base$font_family,
    data = raw$data %||% base$data
  )
  spec$palette_def <- mint_get_palette(spec$palette)
  spec$style_def <- style
  spec$background <- style$tokens$bg
  spec$options_raw <- raw$options %||% base$options %||% list()
  spec$options <- mint_normalize_options(chart, spec$options_raw)
  class(spec) <- c("mint_spec", "list")
  spec
}
