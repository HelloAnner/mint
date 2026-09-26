# 全图表端到端测试：每张图都要能用内置示例数据渲染出 PNG 与 SVG。
#
# 这是防回归的主力：任何一张图的 render() 写坏了、示例数据的形状对不上、
# 或者主题/版心改动导致布局异常，这里都会立刻暴露。

tmp <- file.path(tempdir(), "mint-charts-test")
dir.create(tmp, showWarnings = FALSE)

#' 读 PNG 头拿尺寸
png_size <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  readBin(con, "raw", 8)
  readBin(con, "integer", 1, size = 4, endian = "big")
  readBin(con, "raw", 4)
  c(readBin(con, "integer", 1, size = 4, endian = "big"),
    readBin(con, "integer", 1, size = 4, endian = "big"))
}

charts <- mint_all_charts()
ok(length(charts) >= 20, sprintf("已注册 %d 张图表", length(charts)))

for (chart in charts) {
  label <- sprintf("%-22s", chart$id)
  outcome <- tryCatch({
    spec <- mint_normalize_spec(chart, list(width = 5, dpi = 72, format = "both"))
    result <- mint_render(chart, spec, out_path = file.path(tmp, chart$id), format = "both")

    png <- file.path(tmp, paste0(chart$id, ".png"))
    svg <- file.path(tmp, paste0(chart$id, ".svg"))
    size <- png_size(png)
    svg_text <- paste(readLines(svg, warn = FALSE), collapse = "")

    problems <- character(0)
    if (!file.exists(png) || !file.exists(svg)) problems <- c(problems, "缺输出文件")
    expected <- as.integer(round(c(spec$width, spec$height) * 72))
    if (!identical(as.integer(size), expected)) {
      problems <- c(problems, sprintf("尺寸 %s 与预期 %s 不符",
                                      paste(size, collapse = "x"), paste(expected, collapse = "x")))
    }
    if (file.info(png)$size < 3000) problems <- c(problems, sprintf("PNG 只有 %d 字节", file.info(png)$size))
    if (!grepl("<svg", svg_text, fixed = TRUE)) problems <- c(problems, "SVG 内容异常")
    if (grepl(">NA<|NaN|Inf", svg_text)) problems <- c(problems, "输出里出现 NA/NaN（大概率是数据整形漏了）")

    if (length(problems) == 0) {
      ok(TRUE, sprintf("%s 渲染通过（%dx%d px）", label, size[1], size[2]))
    } else {
      ok(FALSE, sprintf("%s %s", label, paste(problems, collapse = "；")))
    }
  }, error = function(e) {
    ok(FALSE, sprintf("%s 渲染报错：%s", label, conditionMessage(e)))
  })
}

## 示例数据用完即弃，不应该改变注册表状态
ok(length(mint_all_charts()) == length(charts), "渲染不改变注册表")

unlink(tmp, recursive = TRUE)
