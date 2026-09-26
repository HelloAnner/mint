# 图表注册表。
#
# 每张图在自己的文件里调用 mint_register()，cli.R 只认 id。
# 图表声明自己需要哪些包，渲染前才加载 —— 这样 `mint list`、`mint palettes`
# 这类命令不需要把 ggplot2 拉起来。

mint_env <- new.env(parent = emptyenv())

mint_option <- function(key, type, description, default = NULL, values = NULL) {
  list(key = key, type = type, description = description, default = default, values = values)
}

#' 定义一个图表
#'
#' @param render function(ctx) 返回 ggplot/gtable/grob
#'   ctx 字段：data（原始 JSON 解析结果）、options（已合并默认值）、
#'             width/height（图表区尺寸，英寸）、family（字体家族）、
#'             style、palette、colors（已按系列数展开的颜色向量）、
#'             background/foreground/muted/text/grid（颜色 token）、
#'             formatter（取值格式化函数）
mint_chart <- function(id, name, english, category, description, data_shape,
                       aliases = character(), variants = character(),
                       options = list(), example = NULL, packages = character(),
                       aspect = NULL, respect = NULL, render) {
  list(
    id = id, name = name, english = english, category = category,
    description = description, data_shape = data_shape,
    aliases = aliases, variants = variants,
    options = options, example = example, packages = packages,
    # 图形天然有固定长宽比时（饼图、雷达、圆形打包）声明 aspect = 宽/高，
    # 这样用户不指定 --height 时画布会按内容撑成合适比例，而不是留一大片空白
    aspect = aspect,
    # respect = FALSE 表示「panel 铺满版心，宽高比由图表自己的 limits 保证」
    respect = respect,
    render = render
  )
}

mint_register <- function(chart) {
  if (is.null(mint_env$charts)) {
    mint_env$charts <- list()
    mint_env$alias <- list()
  }
  if (!is.null(mint_env$charts[[chart$id]])) {
    mint_fail("INTERNAL", sprintf("图表 id 重复注册：%s", chart$id))
  }
  mint_env$charts[[chart$id]] <- chart
  mint_env$alias[[tolower(chart$id)]] <- chart$id
  for (a in chart$aliases) mint_env$alias[[tolower(a)]] <- chart$id
  invisible(chart)
}

mint_all_charts <- function() {
  mint_env$charts %||% list()
}

mint_chart_ids <- function() names(mint_all_charts())

mint_chart_by_id <- function(id) {
  charts <- mint_all_charts()
  if (is.null(id)) return(NULL)
  key <- tolower(id)
  alias <- mint_env$alias %||% list()
  resolved <- alias[[key]] %||% id
  charts[[resolved]]
}

mint_require_chart <- function(id) {
  chart <- mint_chart_by_id(id)
  if (is.null(chart)) {
    available <- paste(mint_chart_ids(), collapse = ", ")
    mint_fail("UNKNOWN_CHART", sprintf("没有名为「%s」的图表", id),
              sprintf("可用图表：%s（用 mint list 查看详情）", available))
  }
  chart
}

#' 拼错时的近似匹配
mint_suggest_chart <- function(id) {
  target <- tolower(id)
  ids <- mint_chart_ids()
  hit <- ids[vapply(ids, function(x) grepl(target, x, fixed = TRUE) || grepl(x, target, fixed = TRUE), logical(1))]
  head(hit, 5)
}

#' 加载图表声明的包
mint_load_packages <- function(chart) {
  for (pkg in chart$packages) {
    ok <- suppressPackageStartupMessages(
      requireNamespace(pkg, quietly = TRUE)
    )
    if (!ok) {
      mint_fail("MISSING_PACKAGE",
                sprintf("图表 %s 需要 R 包「%s」，但它没有安装", chart$id, pkg),
                "运行 Rscript scripts/install-deps.R 安装依赖")
    }
  }
  invisible(chart)
}

#' 图表的完整选项表（含通用选项）
mint_chart_options <- function(chart) {
  common <- list(
    mint_option("legend", "boolean", "是否显示图例", default = TRUE)
  )
  c(chart$options, common)
}
