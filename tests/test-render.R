# 渲染管线测试：一张图的端到端行为（尺寸、格式、stdout、错误）。

#' 直接读 PNG 头，拿到真实像素尺寸（不依赖 png 包）
png_header <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  sig <- readBin(con, "raw", 8)
  len <- readBin(con, "integer", 1, size = 4, endian = "big")
  type <- rawToChar(readBin(con, "raw", 4))
  width <- readBin(con, "integer", 1, size = 4, endian = "big")
  height <- readBin(con, "integer", 1, size = 4, endian = "big")
  list(signature = paste(as.integer(sig), collapse = ","), chunk = type, width = width, height = height)
}

tmp <- file.path(tempdir(), "mint-render-test")
dir.create(tmp, showWarnings = FALSE)

chart <- mint_require_chart("bar")
spec <- mint_normalize_spec(chart, list(title = "测试标题", subtitle = "副标题", width = 3.5, dpi = 96))

## PNG：像素尺寸必须等于 英寸 × dpi
result <- mint_render(chart, spec, out_path = file.path(tmp, "bar.png"), format = "png")
ok(length(result$files) == 1 && file.exists(result$files[1]), "PNG 渲染产出文件")
header <- png_header(result$files[1])
ok(identical(header$chunk, "IHDR"), "PNG 头合法")
ok(header$width == round(3.5 * 96), sprintf("PNG 宽度 = 英寸×dpi（%d）", header$width))
ok(abs(header$height - round(spec$height * 96)) <= 1, sprintf("PNG 高度 = 英寸×dpi（%d）", header$height))

## SVG：矢量输出保留文字
spec_svg <- mint_normalize_spec(chart, list(title = "矢量", width = 3.5, dpi = 96, format = "svg"))
result_svg <- mint_render(chart, spec_svg, out_path = file.path(tmp, "bar.svg"), format = "svg")
svg <- paste(readLines(result_svg$files[1], warn = FALSE), collapse = "")
ok(grepl("<svg", svg, fixed = TRUE), "SVG 根节点存在")
ok(grepl("矢量", svg, fixed = TRUE), "SVG 里标题是可选中文字（不是路径）")
ok(!grepl("resvg|wasm", svg), "SVG 不含光栅化残留")

## both：一次产出两份
spec_both <- mint_normalize_spec(chart, list(width = 3.5, dpi = 96, format = "both"))
result_both <- mint_render(chart, spec_both, out_path = file.path(tmp, "both.png"), format = "both")
ok(length(result_both$files) == 2 &&
     all(file.exists(file.path(tmp, c("both.png", "both.svg")))), "both 同时产出 PNG 与 SVG")

## 扩展名推断格式
ok(identical(mint_format_from_path("x.svg"), "svg"), "按 .svg 推断格式")
ok(identical(mint_format_from_path("x.png"), "png"), "按 .png 推断格式")

## 画布太小
fails_with(mint_render(chart, mint_normalize_spec(chart, list(width = 7, height = 0.6)),
                       out_path = file.path(tmp, "small.png")),
           "CANVAS_TOO_SMALL", "画布太小报 CANVAS_TOO_SMALL")

## 标题/副标题/脚注都要出现在 SVG 里
spec_full <- mint_normalize_spec(chart, list(title = "标题", subtitle = "副标题", footnote = "脚注",
                                             width = 4, dpi = 96, format = "svg"))
res <- mint_render(chart, spec_full, out_path = file.path(tmp, "full.svg"), format = "svg")
full_svg <- paste(readLines(res$files[1], warn = FALSE), collapse = "")
ok(grepl("标题", full_svg, fixed = TRUE) && grepl("副标题", full_svg, fixed = TRUE) &&
     grepl("脚注", full_svg, fixed = TRUE), "标题/副标题/脚注都进入输出")

## 数据覆盖：传自定义数据时不再套用示例选项
custom <- list(list(quarter = "Q1", A = 5, B = 3), list(quarter = "Q2", A = 7, B = 4))
spec_custom <- mint_normalize_spec(chart, list(width = 3.5, dpi = 96, format = "svg"))
res_custom <- mint_render(chart, spec_custom, data = custom, out_path = file.path(tmp, "custom.svg"), format = "svg")
custom_svg <- paste(readLines(res_custom$files[1], warn = FALSE), collapse = "")
ok(grepl("Q1", custom_svg, fixed = TRUE), "自定义数据进入图表")

## 环境自检能跑通并全部通过
doctor <- tryCatch(mint_cmd_doctor(character(0)), error = function(e) 1L)
ok(identical(as.integer(doctor), 0L), "mint doctor 全部通过")

## ── 命令行端到端：走真正的 bin/mint 入口 ──────────────────
mint_bin <- file.path(MINT_TEST_HOME, "bin", "mint")
cli_dir <- file.path(tempdir(), "mint-cli-test")
dir.create(cli_dir, showWarnings = FALSE)
env_prefix <- sprintf("MINT_HOME=%s MINT_LIB=%s", MINT_TEST_HOME, Sys.getenv("MINT_LIB", lib))
run_cli <- function(args) {
  system2("/bin/sh", c("-c", shQuote(sprintf("%s %s %s", env_prefix, mint_bin, args))),
          stdout = TRUE, stderr = TRUE)
}

cli_png <- file.path(cli_dir, "cli.png")
out <- run_cli(sprintf("render bar -o %s -q --dpi 72", cli_png))
ok(file.exists(cli_png) && is.null(attr(out, "status")), "命令行 bin/mint 能出一张图")

out <- run_cli("render bar --set groupMode=stacked --set valueLabel=false -o /dev/null --dpi 72 -q")
ok(is.null(attr(out, "status")), "--set 选项在命令行里生效")

list_json <- run_cli("list --json")
ok(any(grepl("\"id\"", list_json)), "mint list --json 输出机器可读结果")

unknown <- run_cli("render nope -o /tmp/mint-nope.png")
ok(any(grepl("UNKNOWN_CHART", unknown)), "未知图表在命令行里给出错误码")

bad_data <- file.path(cli_dir, "bad.json")
writeLines('{"not":"an array"}', bad_data)
bad <- run_cli(sprintf("render bar -d %s -o /dev/null --dpi 72", bad_data))
ok(any(grepl("INVALID_DATA", bad)), "非法数据在命令行里给出错误码")

unlink(cli_dir, recursive = TRUE)

unlink(tmp, recursive = TRUE)
