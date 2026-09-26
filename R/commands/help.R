# mint help / version

mint_cmd_version <- function() {
  cat(sprintf("mint %s  (R %s)\n", MINT_VERSION, paste(R.version$major, R.version$minor, sep = ".")))
  0L
}

mint_cmd_help <- function(argv = character(0)) {
  topic <- if (length(argv) > 0) argv[[1]] else NULL

  if (!is.null(topic) && identical(topic, "render")) {
    cat(mint_render_help())
    return(0L)
  }

  cat(sprintf("mint %s —— 把数据变成期刊级图表\n\n", MINT_VERSION))
  cat("用法：\n")
  cat("  mint render <chart> [选项]      渲染一张图\n")
  cat("  mint batch <spec.json>          按 spec 批量渲染（一个进程出多张图）\n")
  cat("  mint list                       列出全部图表\n")
  cat("  mint info <chart>               数据结构、选项与示例\n")
  cat("  mint palettes                   列出调色板\n")
  cat("  mint styles                     列出风格\n")
  cat("  mint doctor                     环境自检（R / 依赖 / 字体 / skill）\n")
  cat("  mint install skill              安装 skill 软链\n")
  cat("  mint uninstall skill            移除 skill 软链\n")
  cat("  mint skill [status|path|list]   查看 skill 状态\n")
  cat("  mint version | help             版本与帮助\n\n")
  cat("渲染参数（mint help render 查看全部）：\n")
  for (line in mint_flag_table(MINT_RENDER_FLAGS)) cat(line, "\n")
  cat("\n默认画布 7 × 4.35 英寸 / 300 dpi —— 期刊双栏满宽尺寸。\n")
  cat("示例：\n")
  cat("  mint render bar --data revenue.json --title \"各区域季度营收\" -o revenue.png\n")
  cat("  mint render line --data trend.json --palette okabe --format both -o trend\n")
  0L
}
