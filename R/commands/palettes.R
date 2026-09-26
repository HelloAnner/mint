# mint palettes

mint_cmd_palettes <- function(argv) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  pals <- mint_palettes()

  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(lapply(pals, function(p) {
      list(id = p$id, name = p$name, kind = p$kind, description = p$description,
           colors = as.list(p$colors), source = p$source)
    }), pretty = TRUE)), "\n", sep = "")
    return(0L)
  }

  kind_label <- c(categorical = "分类", sequential = "顺序", diverging = "发散")
  cat(sprintf("共 %d 套调色板（默认 %s）\n", length(pals), MINT_DEFAULT_PALETTE))
  for (p in pals) {
    cat(sprintf("\n%s  %s（%s）%s\n", p$id, p$name, kind_label[[p$kind]] %||% p$kind,
                if (!is.null(p$source)) sprintf("  来源：%s", p$source) else ""))
    cat(sprintf("  %s\n", p$description))
    cat(sprintf("  %s\n", paste(p$colors, collapse = " ")))
  }
  cat("\n用法：mint render bar --palette okabe -o bar.png\n")
  0L
}
