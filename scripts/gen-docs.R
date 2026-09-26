#!/usr/bin/env Rscript
# 从图表注册表生成 skills/mint/references/charts.md。
#
# 图表目录必须与代码同步：这份文档是 AI 和用户唯一的数据结构来源，
# 手写一定会漂移，所以由 mint_chart() 的定义直接生成。
#
# 用法：Rscript scripts/gen-docs.R [输出路径]

home <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), ".."))
Sys.setenv(MINT_HOME = home)
lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))

source(file.path(home, "R", "load.R"), encoding = "UTF-8")
mint_load_sources(home)

out_path <- if (length(commandArgs(trailingOnly = TRUE)) > 0) {
  commandArgs(trailingOnly = TRUE)[1]
} else {
  file.path(home, "skills", "mint", "references", "charts.md")
}

charts <- mint_all_charts()
type_names <- MINT_TYPE_LABELS

lines <- c(
  "# mint 图表目录",
  "",
  sprintf("共 %d 种图表。全部由 R + ggplot2 渲染，统一走 mint 的 professional 风格。", length(charts)),
  "",
  "用 `mint info <id>` 查看某张图的完整选项与可运行示例；",
  "本文件由 `Rscript scripts/gen-docs.R` 从代码自动生成，请勿手改。",
  ""
)

categories <- unique(vapply(charts, function(c) c$category, character(1)))
for (category in categories) {
  group <- Filter(function(c) identical(c$category, category), charts)
  lines <- c(lines, sprintf("## %s", MINT_CATEGORY_LABELS[[category]] %||% category), "")
  lines <- c(lines, "| id | 名称 | 一句话 | 形态 |", "|----|------|--------|------|")
  for (chart in group) {
    variants <- if (length(chart$variants) > 0) paste(chart$variants, collapse = " / ") else "—"
    lines <- c(lines, sprintf("| `%s` | %s | %s | %s |", chart$id, chart$name, chart$description, variants))
  }
  lines <- c(lines, "")

  for (chart in group) {
    lines <- c(lines, sprintf("### `%s` — %s（%s）", chart$id, chart$name, chart$english), "")
    lines <- c(lines, chart$description, "")
    if (length(chart$variants) > 0) {
      lines <- c(lines, sprintf("**形态**：%s", paste(chart$variants, collapse = " / ")), "")
    }
    lines <- c(lines, "**数据结构**", "", "```", chart$data_shape, "```", "")

    lines <- c(lines, "**选项**", "", "| 选项 | 类型 | 默认 | 说明 |", "|------|------|------|------|")
    for (opt in mint_chart_options(chart)) {
      default <- if (is.null(opt$default)) "—" else as.character(opt$default)
      desc <- opt$description
      if (length(opt$values) > 0) desc <- sprintf("%s（%s）", desc, paste(opt$values, collapse = " / "))
      lines <- c(lines, sprintf("| `%s` | %s | %s | %s |", opt$key,
                                type_names[[opt$type]] %||% opt$type, default, desc))
    }
    lines <- c(lines, "")

    lines <- c(lines, sprintf("**最小示例**：`mint render %s -o %s.png`（不传 `--data` 时用内置示例数据）",
                              chart$id, chart$id), "")
    if (length(chart$example$options %||% list()) > 0) {
      lines <- c(lines, sprintf("**示例选项**：`%s`",
                                as.character(mint_to_json(chart$example$options, pretty = FALSE))), "")
    }
    if (length(chart$aliases) > 0) {
      lines <- c(lines, sprintf("**别名**：%s", paste(chart$aliases, collapse = "、")))
    }
    lines <- c(lines, "")
  }
}

lines <- c(lines, "## 风格与调色板", "",
           "`mint styles` 看风格，`mint palettes` 看配色：", "",
           "| 用途 | 推荐 |", "|------|------|",
           "| 通用分类 | `npg`（默认）、`aaas`、`lancet`、`jama` |",
           "| 医学/临床 | `nejm` |",
           "| 色盲安全（投稿） | `okabe` |",
           "| 黑白印刷 | `greys` |",
           "| 连续映射（热力图/日历图） | `blue`、`viridis` |",
           "| 有正负/基准的发散映射 | `rdbu` |",
           "")

writeLines(lines, out_path)
cat(sprintf("已生成 %s（%d 张图，%d 行）\n", out_path, length(charts), length(lines)))
