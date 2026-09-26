# 全部图表的加载入口。
#
# 每张图一个文件，文件里调用 mint_register() 把定义登记进注册表。
# 新增图表：写 R/charts/<id>.R，然后把它加进下面的清单。

MINT_CHART_FILES <- c(
  # 比较
  "bar.R", "radar.R", "radial-bar.R", "bullet.R", "lollipop.R",
  # 趋势
  "line.R", "stream.R", "bump.R",
  # 构成
  "pie.R", "waffle.R", "marimekko.R",
  # 关系
  "scatter.R", "parallel-coordinates.R", "architecture.R",
  # 分布
  "heatmap.R", "calendar.R", "histogram.R", "boxplot.R", "ridgeline.R",
  # 层级
  "treemap.R", "sunburst.R", "icicle.R", "circle-packing.R",
  # 流向
  "funnel.R", "sankey.R", "flowchart.R", "sequence.R"
)

#' 逐个加载图表定义（缺文件不报错，方便边写边跑）
mint_source_charts <- function(home = mint_home_dir) {
  dir <- file.path(home, "R", "charts")
  for (file in MINT_CHART_FILES) {
    path <- file.path(dir, file)
    if (file.exists(path)) source(path, local = FALSE, encoding = "UTF-8")
  }
  invisible(length(mint_all_charts()))
}
