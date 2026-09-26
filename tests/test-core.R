# 核心层测试：数据整形、格式化、spec 归一化、错误码。

## ── 格式化 ──────────────────────────────────────────────
ok(identical(mint_format_number(c(1234567, 12.5)), c("1,234,567", "12.5")),
   "整数带千分位、小数保留有效位")
ok(identical(mint_format_number(12000, compact = TRUE), "12k"), "compact 压缩计数")
ok(identical(mint_format_number(0.1234, decimals = 1, prefix = "¥"), "¥0.1"), "小数位与前缀")

fmt <- mint_formatter(list(valueFormat = "percent"))
ok(identical(fmt(0.1234), "12.3%"), "percent 预设")

fmt2 <- mint_formatter(list(valueSuffix = " 万", decimals = 0))
ok(identical(fmt2(128), "128 万"), "后缀与小数位")

## ── 文本宽度与折行 ───────────────────────────────────────
ok(mint_text_width("中文") > mint_text_width("ab"), "CJK 按双宽计算")
ok(all(abs(mint_text_width(c("ab", "abcd"), 7) - c(7.28, 14.56)) < 1e-9), "文本宽度按元素向量化")
ok(mint_text_width("中文", 7) == 14, "全角按 1.0 em 估算")
wrapped <- mint_wrap("这是一个需要折行的很长的中文标题", max_width = 40, size = 7)
ok(grepl("\n", wrapped, fixed = TRUE), "超长文本会折行")
ok(!grepl("\n", mint_wrap("短", max_width = 100, size = 7), fixed = TRUE), "短文本不折行")

## ── 数据整形 ─────────────────────────────────────────────
rows <- mint_as_rows(list(list(a = "x", b = 1), list(a = "y", b = 2)), "bar")
ok(nrow(rows) == 2 && identical(rows$a, c("x", "y")), "数组转 data.frame")
fails_with(mint_as_rows(list(), "bar"), "INVALID_DATA", "空数组报 INVALID_DATA")
fails_with(mint_as_rows(list(1, 2), "bar"), "INVALID_DATA", "非对象行报 INVALID_DATA")

ik <- mint_infer_index_keys(rows, NULL, NULL, "bar")
ok(identical(ik$indexBy, "a") && identical(ik$keys, "b"), "推断分类轴与数值系列")
fails_with(mint_infer_index_keys(data.frame(a = "x"), NULL, NULL, "bar"),
           "INVALID_DATA", "没有数值字段时报错")

melted <- mint_melt(rows, "a", "b")
ok(identical(levels(melted$index), c("x", "y")) && nrow(melted) == 2, "长表保持原始顺序")

pairs <- mint_as_pairs(list(list(id = "A", value = 3), list(id = "B", value = 5)), "pie")
ok(identical(pairs$label, c("A", "B")) && identical(pairs$value, c(3, 5)), "id/value 数组")
pairs2 <- mint_as_pairs(list(A = 3, B = 5), "pie")
ok(identical(pairs2$id, c("A", "B")), "对象映射形式")
pairs3 <- mint_as_pairs(list(list("A", 3), list("B", 5)), "pie")
ok(identical(pairs3$value, c(3, 5)), "二元数组形式")
fails_with(mint_as_pairs(list(list(id = "A")), "pie"), "INVALID_DATA", "缺 value 报错")

series <- mint_as_series(list(list(x = "1月", A = 1, B = 2), list(x = "2月", A = 3, B = 4)), "line")
ok(length(series) == 2 && identical(series[[1]]$id, "A") && identical(series[[1]]$y, c(1, 3)),
   "行式数据转多系列")

## ── 数值工具 ─────────────────────────────────────────────
ok(identical(mint_tint("#000000", 0), "#FFFFFF"), "tint(0) 为白")
ok(identical(mint_tint("#000000", 1), "#000000"), "tint(1) 为原色")
ramp <- mint_ramp("#0d9488", 5)
ok(length(ramp) == 5 && ramp[1] != ramp[5], "顺序色阶两端不同")
ok(length(unique(mint_ramp("#E64B35", 3, from = 0.4, to = 1))) == 3, "顺序色阶每一级都不一样")
ok(identical(mint_tint("#000000", c(0.5, 1)), c("#808080", "#000000")), "tint 支持按元素循环")

seq_fn <- mint_seq_palette(c("#FFFFFF", "#000000"), domain = c(0, 10))
ok(identical(seq_fn(c(0, 10)), c("#FFFFFF", "#000000")), "连续色阶端点映射")
ok(identical(seq_fn(5), "#808080"), "连续色阶中点插值")

## ── spec 归一化 ──────────────────────────────────────────
chart <- mint_require_chart("bar")
spec <- mint_normalize_spec(chart, list(width = 3.5, dpi = 150, palette = "okabe"))
ok(spec$width == 3.5 && spec$dpi == 150 && spec$palette == "okabe", "spec 覆盖默认值")
ok(spec$background == "#FFFFFF", "spec 带背景色")

spec_example <- mint_normalize_spec(chart, list())
ok(spec_example$height > spec_example$width * 0.5, "默认画布高度取风格默认值")

fails_with(mint_normalize_spec(chart, list(width = -1)), "INVALID_SPEC", "负宽度报错")
fails_with(mint_normalize_spec(chart, list(format = "pdf")), "INVALID_SPEC", "非法格式报错")
fails_with(mint_get_palette("nope"), "UNKNOWN_PALETTE", "未知调色板报错")
fails_with(mint_get_style("nope"), "UNKNOWN_STYLE", "未知风格报错")
fails_with(mint_require_chart("nope"), "UNKNOWN_CHART", "未知图表报错")

## ── 选项容错 ─────────────────────────────────────────────
opts <- mint_normalize_options(chart, list(valueLabel = "false", barWidth = "0.5", keys = "华东,华北"))
ok(identical(opts$valueLabel, FALSE), "布尔字符串转逻辑值")
ok(identical(opts$barWidth, 0.5), "数值字符串转数值")
ok(identical(opts$keys, c("华东", "华北")), "逗号分隔转数组")
ok(identical(opts$groupMode, "grouped"), "未传的选项取默认值")
fails_with(mint_normalize_options(chart, list(valueLabel = "maybe")), "INVALID_VALUE", "非法布尔报错")

## ── 参数解析 ─────────────────────────────────────────────
flags <- list(mint_flag("data", "d", "string", ""), mint_flag("json", NULL, "boolean", ""),
              mint_flag("set", NULL, "list", ""))
parsed <- mint_parse_args(c("bar", "-d", "a.json", "--set", "x=1", "--set", "y=true", "--json"), flags)
ok(identical(parsed$positionals, "bar"), "位置参数")
ok(identical(parsed$values$data, "a.json"), "短参数取值")
ok(identical(parsed$values$set, c("x=1", "y=true")), "可重复参数")
ok(isTRUE(parsed$values$json), "布尔开关")
set_values <- mint_parse_set_flags(c("n=3", "b=false", "arr=[1,2]"))
ok(identical(set_values$n, 3) && identical(set_values$b, FALSE), "--set 解析数值与布尔")
ok(identical(as.numeric(unlist(set_values$arr)), c(1, 2)), "--set 解析数组")
fails_with(mint_parse_args(c("--nope"), flags), "UNKNOWN_FLAG", "未知参数报错")
parsed_set <- mint_parse_args(c("--set", "novalue"), flags)
fails_with(mint_parse_set_flags(parsed_set$values$set), "INVALID_VALUE", "--set 缺少等号报错")

## ── 图表注册表 ───────────────────────────────────────────
charts <- mint_all_charts()
ok(length(charts) >= 20, sprintf("注册图表数量 %d ≥ 20", length(charts)))
ok(all(vapply(charts, function(c) is.function(c$render), logical(1))), "每张图都有 render")
ok(all(vapply(charts, function(c) !is.null(c$example$data), logical(1))), "每张图都有示例数据")
ok(identical(mint_chart_by_id("column")$id, "bar"), "别名解析到正式 id")
