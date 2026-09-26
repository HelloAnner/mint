#!/usr/bin/env Rscript
# 把每张图的内置示例渲染到 out/examples（PNG + SVG）。
#
# 用法：Rscript scripts/examples.R [输出目录] [--dpi 300]
# 作用：一是给 README / skill 提供预览图，二是人工过一遍全部图表的观感。

home <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), ".."))
Sys.setenv(MINT_HOME = home)
lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))

source(file.path(home, "R", "load.R"), encoding = "UTF-8")
mint_load_sources(home)

args <- commandArgs(trailingOnly = TRUE)
outdir <- if (length(args) > 0 && !grepl("^--", args[1])) args[1] else file.path(home, "out", "examples")
dpi <- as.numeric(sub("^--dpi=", "", grep("^--dpi=", args, value = TRUE)[1] %||% 150))
if (is.na(dpi)) dpi <- 150

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# 预览图用固定尺寸，保证 README 里一排图看起来一致
sizes <- list(
  bar = c(7, 4.35), line = c(7, 4.35), scatter = c(7, 4.35), heatmap = c(7, 4.35),
  pie = c(5, 5), radar = c(5.5, 5.5), system = c(7, 4.35)
)

started <- Sys.time()
failures <- 0L
for (chart in mint_all_charts()) {
  # 固定长宽比的图（饼图/雷达等）按内容撑高，避免预览图两侧一大片空白
  aspect <- chart$aspect %||% 1.6
  size <- sizes[[chart$id]] %||% c(7, if (aspect >= 1) 7 / aspect + 0.49 else 4.35)
  # 预览图带上图表名与一句话说明，和 README 的排布一致
  spec <- mint_normalize_spec(chart, list(
    width = size[1], height = size[2], dpi = dpi, format = "both",
    title = chart$name, subtitle = chart$description
  ))
  out <- file.path(outdir, chart$id)
  result <- tryCatch(
    mint_render(chart, spec, out_path = out, format = "both"),
    error = function(e) {
      failures <<- failures + 1L
      cat(sprintf("[FAILED] %-22s %s\n", chart$id, conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(result)) {
    cat(sprintf("%-22s %s  %.0f KB\n", chart$id, paste(basename(result$files), collapse = " + "),
                sum(file.info(result$files)$size) / 1024))
  }
}

cat(sprintf("\n%d 张完成，%d 张失败，耗时 %.1fs → %s\n",
            length(mint_all_charts()) - failures, failures,
            as.numeric(difftime(Sys.time(), started, units = "secs")), outdir))
quit(save = "no", status = if (failures > 0) 1L else 0L)
