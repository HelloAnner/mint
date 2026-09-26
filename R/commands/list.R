# mint list / mint info / mint styles

mint_cmd_list <- function(argv) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  charts <- mint_all_charts()
  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(lapply(charts, function(c) {
      list(id = c$id, name = c$name, english = c$english, category = c$category,
           description = c$description, variants = as.list(c$variants),
           aliases = as.list(c$aliases))
    }), pretty = TRUE)), "\n", sep = "")
    return(0L)
  }

  cat(sprintf("mint 内置 %d 种图表\n", length(charts)))
  cats <- unique(vapply(charts, function(c) c$category, character(1)))
  for (cat in cats) {
    group <- Filter(function(c) identical(c$category, cat), charts)
    cat(sprintf("\n%s\n", MINT_CATEGORY_LABELS[[cat]] %||% cat))
    for (c in group) {
      variant <- if (length(c$variants) > 0) sprintf("  [%s]", paste(c$variants, collapse = " / ")) else ""
      cat(sprintf("  %-22s %s%s\n", c$id, c$description, variant))
    }
  }
  cat("\n用 mint info <chart> 查看数据结构、选项与示例。\n")
  0L
}

MINT_CATEGORY_LABELS <- list(
  comparison = "比较", trend = "趋势", composition = "构成",
  distribution = "分布", hierarchy = "层级", flow = "流向", relation = "关系",
  model = "模型评估"
)

MINT_TYPE_LABELS <- c(string = "字符串", number = "数值", boolean = "布尔", array = "数组", object = "对象")

mint_cmd_styles <- function(argv) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  styles <- mint_styles()
  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(lapply(styles, function(s) {
      list(id = s$id, name = s$name, description = s$description,
           default_width = s$default_width, default_height = s$default_height, default_dpi = s$default_dpi)
    }), pretty = TRUE)), "\n", sep = "")
    return(0L)
  }
  cat("可用风格：\n")
  for (s in styles) {
    cat(sprintf("  %-14s %s\n", s$id, s$name))
    cat(sprintf("  %-14s %s\n", "", s$description))
    cat(sprintf("  %-14s 默认画布 %.2f × %.2f in @ %d dpi\n\n",
                "", s$default_width, s$default_height, s$default_dpi))
  }
  0L
}

mint_cmd_info <- function(argv) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  id <- parsed$positionals[[1]]
  if (is.null(id)) mint_fail("MISSING_ARGUMENT", "mint info 需要一个图表 id")
  chart <- mint_require_chart(id)

  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(list(
      id = chart$id, name = chart$name, english = chart$english, category = chart$category,
      description = chart$description, data_shape = chart$data_shape,
      variants = as.list(chart$variants), aliases = as.list(chart$aliases),
      packages = as.list(chart$packages),
      options = lapply(mint_chart_options(chart), function(o) {
        list(key = o$key, type = o$type, description = o$description,
             default = o$default, values = as.list(o$values))
      }),
      example = chart$example
    ), pretty = TRUE)), "\n", sep = "")
    return(0L)
  }

  cat(sprintf("%s（%s · %s）\n", chart$name, chart$id, chart$english))
  cat(sprintf("%s\n\n", chart$description))
  if (length(chart$variants) > 0) cat(sprintf("形态：%s\n\n", paste(chart$variants, collapse = " / ")))
  cat("数据结构：\n")
  cat(paste0("  ", strsplit(chart$data_shape, "\n")[[1]], collapse = "\n"), "\n\n")

  cat("选项：\n")
  for (opt in mint_chart_options(chart)) {
    values <- if (length(opt$values) > 0) sprintf("（%s）", paste(opt$values, collapse = " / ")) else ""
    default <- if (is.null(opt$default)) "" else sprintf("，默认 %s", paste(as.character(opt$default), collapse = ","))
    cat(sprintf("  %-16s %-8s %s%s%s\n", opt$key, MINT_TYPE_LABELS[[opt$type]] %||% opt$type, opt$description, values, default))
  }

  if (!is.null(chart$example)) {
    cat("\n最小示例：\n")
    if (!is.null(chart$example$data)) {
      example_data <- chart$example$data
      total <- if (is.list(example_data)) length(example_data) else 1
      shown <- example_data
      truncated <- FALSE
      if (is.list(example_data) && is.null(names(example_data)) && total > 8) {
        shown <- example_data[1:8]
        truncated <- TRUE
      }
      example_json <- as.character(mint_to_json(shown, pretty = TRUE))
      cat(paste0("  ", strsplit(example_json, "\n")[[1]], collapse = "\n"), "\n")
      if (truncated) cat(sprintf("  …（示例共 %d 条，这里只展示前 8 条）\n", total))
    }
    if (length(chart$example$options %||% list()) > 0) {
      cat(sprintf("  选项：%s\n", as.character(mint_to_json(chart$example$options, pretty = FALSE))))
    }
  }
  cat(sprintf("\n运行：mint render %s -o %s.png\n", chart$id, chart$id))
  cat(sprintf("别名：%s\n", paste(c(chart$aliases, chart$id), collapse = "、")))
  0L
}
