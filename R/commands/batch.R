# mint batch <spec.json>
#
# 一个 R 进程出多张图 —— R 的启动与包加载成本不低，
# 批量场景下集中在一个进程里渲染比逐张调 CLI 快一个数量级。

BATCH_FLAGS <- list(
  mint_flag("outdir", NULL, "string", "所有输出的根目录", "<dir>"),
  mint_flag("json", NULL, "boolean", "输出机器可读结果"),
  mint_flag("stop-on-error", NULL, "boolean", "遇到第一个错误就停止"),
  mint_flag("quiet", "q", "boolean", "静默模式")
)

mint_cmd_batch <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, BATCH_FLAGS)
  spec_path <- parsed$positionals[[1]]
  if (is.null(spec_path)) {
    mint_fail("MISSING_ARGUMENT", "mint batch 需要一个 spec 文件", "例如 mint batch report.json")
  }
  if (!file.exists(spec_path)) {
    mint_fail("DATA_NOT_FOUND", sprintf("找不到 spec 文件：%s", spec_path))
  }

  raw <- mint_read_json_file(spec_path)
  spec_dir <- dirname(normalizePath(spec_path))
  outdir <- mint_arg(parsed, "outdir")
  quiet <- isTRUE(mint_arg(parsed, "quiet"))
  stop_on_error <- isTRUE(mint_arg(parsed, "stop-on-error"))

  defaults <- list()
  items <- NULL
  if (is.list(raw) && is.null(names(raw))) {
    items <- raw
  } else if (is.list(raw) && !is.null(raw$charts)) {
    defaults <- raw$defaults %||% list()
    items <- raw$charts
  } else if (is.list(raw)) {
    items <- list(raw)
  }
  if (is.null(items) || length(items) == 0) {
    mint_fail("INVALID_SPEC", "spec 文件里没有要渲染的图表",
              "形如 {\"charts\": [{\"chart\": \"bar\", \"out\": \"bar.png\"}]}")
  }

  results <- list()
  failures <- 0L
  for (i in seq_along(items)) {
    item <- items[[i]]
    label <- item$out %||% sprintf("#%d", i)
    outcome <- tryCatch({
      mint_render_batch_item(item, defaults, spec_dir, outdir, quiet)
    }, error = function(e) {
      list(ok = FALSE, chart = item$chart %||% "?", out = label,
           error = mint_error_code(e), message = conditionMessage(e))
    })
    results[[length(results) + 1L]] <- outcome
    if (!isTRUE(outcome$ok)) {
      failures <- failures + 1L
      if (!quiet) cat(sprintf("[FAILED] %s: %s\n", label, outcome$message %||% outcome$error), file = stderr())
      if (stop_on_error) break
    }
  }

  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(list(
      ok = failures == 0L, total = length(results), failed = failures, results = results
    ), pretty = TRUE)), "\n", sep = "")
  } else if (!quiet) {
    cat(sprintf("\n完成 %d/%d 张%s\n", length(results) - failures, length(results),
                if (failures > 0) sprintf("，失败 %d 张", failures) else ""))
  }

  if (failures > 0) 1L else 0L
}

mint_render_batch_item <- function(item, defaults, spec_dir, outdir, quiet) {
  chart_id <- item$chart
  if (is.null(chart_id)) mint_fail("INVALID_SPEC", "spec 里的每一项都需要 chart 字段")
  chart <- mint_require_chart(chart_id)

  data <- item$data
  if (is.null(data) && !is.null(item$data_file)) {
    path <- item$data_file
    if (!grepl("^(/|\\.)", path)) path <- file.path(spec_dir, path)
    data <- mint_read_json_file(path)
  }

  merged <- function(field) item[[field]] %||% defaults[[field]]
  out <- item$out %||% paste0(chart$id, if (length(defaults$format %||% item$format %||% "png") > 0 &&
                                            identical(item$format %||% defaults$format %||% "png", "svg")) ".svg" else ".png")
  if (!is.null(outdir)) out <- file.path(outdir, basename(out))

  spec <- mint_normalize_spec(chart, list(
    title = merged("title"), subtitle = merged("subtitle"), footnote = merged("footnote"),
    width = merged("width"), height = merged("height"), dpi = merged("dpi"),
    format = merged("format"), style = merged("style"), palette = merged("palette"),
    font_family = merged("font_family"),
    options = c(defaults$options %||% list(), item$options %||% list())
  ))

  started <- Sys.time()
  result <- mint_render(chart, spec, data = data, out_path = out, format = spec$format)
  elapsed <- round(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000)

  if (!quiet) cat(sprintf("%s  %s  %.0f ms\n", paste(result$files, collapse = " "), chart$id, elapsed))
  list(ok = TRUE, chart = chart$id, out = result$files[[1]], files = as.list(result$files),
       elapsed_ms = elapsed)
}
