# 直方图 histogram
#
# 期刊里的直方图有个容易做错的地方：默认从 0 起 x 轴。
# 如果一个班级的成绩是 62–98，从 0 起会让所有柱子挤在右边一小块里；
# 所以这里默认按数据范围取轴，只在用户明确要 xZero 时才含 0。
#
# 另一个细节是柱间白缝：柱子直接贴在一起时相邻柱的边界会被读成一根粗线，
# 用背景色给每根柱描一圈极细的边，视觉上才是「一根一根」的。

MINT_HISTOGRAM_VALUE_KEYS <- c("value", "x", "v", "count", "score", "amount", "n", "num")
MINT_HISTOGRAM_GROUP_KEYS <- c("group", "category", "series", "label", "name")

mint_register(mint_chart(
  id = "histogram",
  name = "直方图",
  english = "Histogram",
  category = "distribution",
  description = "看一个数值变量的分布形态：集中、离散、偏态与多峰",
  data_shape = paste(
    "三种写法都支持：",
    "1) 一维数值数组：[ 12, 15, 15, 18, 21 ]",
    "2) 行式：[ { \"value\": 12 }, { \"value\": 15 } ]（value 也可写 x / count 等）",
    "3) 分组：[ { \"group\": \"对照组\", \"value\": 12 } ]，group 字段名可用 groupKey 改写",
    sep = "\n"
  ),
  variants = c("frequency 频数", "density 密度", "grouped 分组"),
  aliases = c("直方图", "频数分布", "分布图", "histogram", "hist", "distribution"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("valueKey", "string", "数值字段名，省略则自动识别 value / x 等"),
    mint_option("groupKey", "string", "分组字段名，省略则用第一个文本字段"),
    mint_option("bins", "number", "分组数，省略按 ceiling(sqrt(n)) 自动取"),
    mint_option("binwidth", "number", "组距，给了就以它为准（优先于 bins）"),
    mint_option("groupMode", "string", "多组的排布方式", default = "overlay", values = c("overlay", "stack")),
    mint_option("density", "boolean", "改用密度刻度并叠加核密度曲线", default = FALSE),
    mint_option("xZero", "boolean", "X 轴是否包含 0", default = FALSE),
    mint_option("xLegend", "string", "X 轴标题"),
    mint_option("yLegend", "string", "Y 轴标题"),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = local({
      # 用一组固定形状的分位数造两条略错开的钟形分布，n 合适、形态自然
      shape <- c(-1.9, -1.6, -1.5, -1.3, -1.2, -1.1, -1, -0.95, -0.9, -0.8, -0.75,
                 -0.7, -0.6, -0.5, -0.45, -0.4, -0.3, -0.25, -0.2, -0.1, 0, 0.05,
                 0.1, 0.2, 0.25, 0.3, 0.4, 0.45, 0.5, 0.6, 0.7, 0.75, 0.8, 0.9,
                 0.95, 1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.9)
      ctrl <- round(12.4 + shape * 2.6, 1)
      test <- round(13.4 + shape * 3.3, 1)
      c(lapply(ctrl, function(v) list(group = "对照组", value = v)),
        lapply(test, function(v) list(group = "实验组", value = v)))
    }),
    options = list(xLegend = "测量值（mm）", yLegend = "频数")
  ),
  render = function(ctx) {
    o <- ctx$options

    # --- 归一化成 (value, group) 两列 ---
    value_keys <- c(o$valueKey, MINT_HISTOGRAM_VALUE_KEYS)
    group_keys <- c(o$groupKey, MINT_HISTOGRAM_GROUP_KEYS)

    if (is.list(ctx$data) && is.null(names(ctx$data)) && length(ctx$data) > 0 &&
        all(vapply(ctx$data, function(v) is.numeric(v) && length(v) == 1, logical(1)))) {
      # 一维数值数组：最省事的写法，没有分组
      value <- as.numeric(unlist(ctx$data))
      group <- rep("", length(value))
    } else {
      rows <- ctx$data
      if (!is.list(rows) || length(rows) == 0 || !is.list(rows[[1]]) || is.null(names(rows[[1]]))) {
        mint_fail("INVALID_DATA", "histogram 需要数值数组或对象数组",
                  "形如 [12, 15, 18] 或 [{ \"value\": 12 }]")
      }
      value <- vapply(rows, function(it) {
        v <- mint_field(it, value_keys)
        if (is.numeric(v) && length(v) == 1) as.numeric(v) else NA_real_
      }, numeric(1))
      group <- vapply(rows, function(it) {
        g <- mint_field(it, group_keys)
        if (is.null(g)) "" else as.character(g)[1]
      }, character(1))
    }

    ok <- !is.na(value)
    if (!any(ok)) {
      mint_fail("INVALID_DATA", "histogram 里没有可用的数值",
                "每条形如 { \"value\": 12 }，或直接给 [12, 15, 18]")
    }
    value <- value[ok]; group <- group[ok]

    ids <- unique(group)
    has_group <- !(length(ids) == 1 && !nzchar(ids[1]))
    if (has_group && any(!nzchar(ids))) {
      mint_fail("INVALID_DATA", "histogram 的分组字段有空值",
                "要么每行都给 group，要么都不给")
    }
    if (!has_group) { ids <- "全部"; group <- rep("全部", length(value)) }

    data <- data.frame(value = value,
                       series = factor(group, levels = ids),
                       stringsAsFactors = FALSE)

    colors <- stats::setNames(mint_colors(length(ids), ctx$colors), ids)
    fmt <- ctx$formatter
    wide <- !identical(o$legend, FALSE) && length(ids) > 1

    as_density <- isTRUE(o$density)
    mode <- o$groupMode %||% "stack"
    # 密度刻度下各组的曲线必须叠着看，堆叠密度没有意义
    if (as_density) mode <- "overlay"

    rng <- range(data$value)
    nbins <- o$bins %||% ceiling(sqrt(nrow(data)))
    if (diff(rng) < 1e-12) {
      # 所有观测值都一样：只有一根柱子，手工给一个对称区间，否则算不出合法组距
      edges <- c(rng[1] - 0.5, rng[1] + 0.5)
    } else {
      binwidth <- o$binwidth %||% (diff(rng) / nbins)
      if (!is.finite(binwidth) || binwidth <= 0) binwidth <- diff(rng) / nbins
      # 分组边界从数据最小值起步（这样柱子的起点就是 x 轴起点），并算成显式 breaks：
      # 显式 breaks 不会被坐标轴范围反过来影响，xZero 打开时也不会改变分组方式
      edges <- rng[1] + (0:ceiling(diff(rng) / binwidth)) * binwidth
      if (utils::tail(edges, 1) < rng[2] - 1e-9) edges <- c(edges, utils::tail(edges, 1) + binwidth)
    }
    bin_args <- list(breaks = edges)

    overlay <- identical(mode, "overlay") && length(ids) > 1
    position <- if (identical(mode, "stack")) ggplot2::position_stack() else ggplot2::position_identity()
    # 叠放对比时半透明，否则后面的组完全被盖住
    fill_alpha <- if (overlay) 0.22 else 1

    mapping <- if (as_density) {
      ggplot2::aes(x = value, y = ggplot2::after_stat(density), fill = series)
    } else {
      ggplot2::aes(x = value, fill = series)
    }

    p <- ggplot2::ggplot(data, mapping) +
      do.call(ggplot2::geom_histogram, c(
        list(position = position, alpha = fill_alpha,
             colour = ctx$background, linewidth = 0.12),
        bin_args
      ))

    if (overlay) {
      # 半透明的柱子叠在一起会混出一块灰，沿柱顶再描一条阶梯线，
      # 每组的形状就不用靠猜颜色深浅来读了
      p <- p + do.call(ggplot2::geom_freqpoly, c(
        list(mapping = ggplot2::aes(x = value, colour = series),
             linewidth = ctx$style$geoms$line_width, show.legend = FALSE),
        bin_args
      ))
    }

    if (as_density) {
      # 核密度曲线用组的颜色描线、不填充，压在直方图上当「平滑后的形状」
      p <- p + ggplot2::geom_density(
        ggplot2::aes(colour = series, fill = NULL), alpha = 0,
        linewidth = ctx$style$geoms$line_width, show.legend = FALSE
      )
    }

    y_legend <- o$yLegend
    if (is.null(y_legend) && as_density) y_legend <- "密度"

    # x 轴默认贴着数据范围；只有 xZero 时才把 0 拉进来
    x_limits <- if (isTRUE(o$xZero)) c(min(0, rng[1]), NA) else NULL

    p +
      ggplot2::scale_fill_manual(values = colors, name = NULL,
                                 guide = mint_legend_guide(wide)) +
      ggplot2::scale_colour_manual(values = colors, guide = "none") +
      ggplot2::scale_x_continuous(labels = fmt, breaks = mint_breaks(6), limits = x_limits,
                                  expand = ggplot2::expansion(mult = c(0.01, 0.02))) +
      ggplot2::scale_y_continuous(
        labels = if (as_density) function(v) mint_format_number(v, decimals = 2) else fmt,
        breaks = mint_breaks(6),
        expand = ggplot2::expansion(mult = c(0, 0.08))
      ) +
      ggplot2::labs(x = o$xLegend, y = y_legend) +
      mint_theme(ctx$style, ctx$family, grid = "y",
                 legend_position = if (wide) "top" else "none")
  }
))