# 矩形树图 treemap
#
# 树图在期刊里的正确用法：面积表达占比，颜色只承担「归属」这一个信息 ——
# 顶层分组取调色板主色，组内各项再用父色的深浅区分，读者扫一眼就知道谁属于谁。
# 布局交给 treemapify（纯 grid 绘制，不需要浏览器），文字交给 ggfittext 自适应。
#
# 两个刻意的取舍：
#   1. 叶子之间用背景色描边留缝，顶层分组再用一道更粗的同色线框住 —— 分隔靠留白，不靠描边色；
#   2. 标签不是「能塞就塞」：先按 mint_text_width 估算能不能放进矩形，放不下就写空串，
#      宁可不标，也不让文字压到相邻色块上。

# 层级数据归一化：兼容 { name, children } / [ { name, value } ] / [ { path, value } ]
mint_treemap_model <- function(data, root = "总计") {
  # 数值 <= 0 的叶子在面积编码里没有意义，直接丢掉；整棵树都空才报错
  norm <- function(raw, depth) {
    if (!is.list(raw) || is.null(names(raw))) {
      mint_fail("INVALID_DATA", sprintf("层级结构第 %d 层不是对象", depth),
                "每个节点形如 { \"name\": \"华东\", \"value\": 320 } 或 { \"name\": \"线上\", \"children\": [...] }")
    }
    name <- as.character(mint_field(raw, c("name", "id", "label"), ""))[1]
    if (is.na(name) || !nzchar(name)) name <- sprintf("层级 %d", depth)

    kids_raw <- raw$children
    if (is.list(kids_raw) && length(kids_raw) > 0) {
      kids <- lapply(kids_raw, norm, depth = depth + 1L)
      kids <- Filter(function(k) !is.null(k), kids)
      if (length(kids) == 0) return(NULL)
      total <- sum(vapply(kids, function(k) k$value, numeric(1)))
      if (!is.finite(total) || total <= 0) return(NULL)
      # 同级按值降序：squarify 从大到小铺更好看，颜色深浅也就能跟着面积走（越大越饱和）
      kids <- kids[order(-vapply(kids, function(k) k$value, numeric(1)))]
      return(list(name = name, value = total, children = kids, depth = depth))
    }

    value <- raw$value
    if (!is.numeric(value) || length(value) != 1 || !is.finite(value) || value <= 0) return(NULL)
    list(name = name, value = as.numeric(value), children = NULL, depth = depth)
  }

  if (is.list(data) && !is.null(names(data))) {
    if (is.list(data$children) && length(data$children) > 0) return(norm(data, 1L))
    if (!is.null(data$name) && is.numeric(data$value)) return(norm(data, 1L))
  }

  if (is.list(data) && is.null(names(data)) && length(data) > 0) {
    rows <- data
    objects <- all(vapply(rows, function(r) is.list(r) && !is.null(names(r)), logical(1)))
    if (objects) {
      # 只有显式写了 path 才按 "/" 拆层：name 里的斜杠是普通字符
      has_path <- all(vapply(rows, function(r) is.character(r$path) && length(r$path) == 1, logical(1)))
      has_name <- all(vapply(rows, function(r) is.character(r$name) && length(r$name) == 1, logical(1)))
      if (has_path || has_name) {
        # 逐段插入建树；R 的 list 是值语义，所以让 insert() 返回更新后的节点而不是原地改
        insert <- function(node, segs, value) {
          if (length(segs) == 0) {
            node$value <- value
            return(node)
          }
          idx <- NA_integer_
          for (i in seq_along(node$children)) {
            if (identical(node$children[[i]]$name, segs[1])) { idx <- i; break }
          }
          if (is.na(idx)) {
            node$children[[length(node$children) + 1L]] <- list(name = segs[1], value = 0, children = list())
            idx <- length(node$children)
          }
          node$children[[idx]] <- insert(node$children[[idx]], segs[-1], value)
          node
        }
        tree <- list(name = as.character(root)[1], value = 0, children = list())
        for (row in rows) {
          raw <- as.character(if (has_path) row$path else row$name)[1]
          value <- row$value
          if (!is.numeric(value) || length(value) != 1 || !is.finite(value)) value <- 1
          segs <- trimws(if (has_path) strsplit(raw, "/", fixed = TRUE)[[1]] else raw)
          segs <- segs[nzchar(segs)]
          if (length(segs) == 0) next
          tree <- insert(tree, segs, as.numeric(value))
        }
        return(norm(tree, 1L))
      }
    }
  }

  mint_fail("INVALID_DATA", "无法把数据解析成层级结构",
            "可以是 { \"name\": ..., \"children\": [...] }，或 [{ \"name\"/\"path\": ..., \"value\": ... }]")
}

# 同一父节点下按序取同色系深浅：顶层用主色，组内最大的最接近父色，越小越浅
mint_treemap_shade <- function(parent_color, index, siblings, depth) {
  if (depth <= 1L) return(parent_color)
  if (siblings <= 1L) return(parent_color)
  # 深层的父色本身已经很浅，收窄深浅区间，整组才不会糊成一片白
  lo <- if (depth <= 2L) 0.35 else 0.52
  rev(mint_ramp(parent_color, siblings, from = lo, to = 0.88))[index]
}

# 底色深浅决定字色：浅底写深字，深底写白字，避免「白字压浅色」这类看不清的组合
mint_treemap_ink <- function(hex) {
  rgb <- grDevices::col2rgb(hex) / 255
  luma <- 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
  if (luma < 0.35) "#FFFFFF" else "#3D3D3D"
}

# 展平成叶子表：treemapify 只吃「一行一个叶子 + subgroup 列」的形状
mint_treemap_leaves <- function(model, palette) {
  out <- list()
  walk <- function(node, depth, parent_color, index, siblings, path) {
    color <- if (depth <= 1L) palette[((index - 1L) %% length(palette)) + 1L]
             else mint_treemap_shade(parent_color, index, siblings, depth)
    path <- c(path, node$name)
    if (is.null(node$children)) {
      out[[length(out) + 1L]] <<- list(
        id = paste(path, collapse = "\u001f"),
        name = node$name,
        value = node$value,
        path = path,
        color = color
      )
      return(invisible(NULL))
    }
    n <- length(node$children)
    for (i in seq_len(n)) walk(node$children[[i]], depth + 1L, color, i, n, path)
    invisible(NULL)
  }
  walk(model, 0L, NA_character_, 1L, 1L, character(0))

  ids <- vapply(out, function(l) l$id, character(1))
  # 最多三级分组：更深的层折进 subgroup3，只影响聚类层级，不影响面积与颜色
  group <- function(level) {
    vapply(out, function(l) {
      p <- l$path
      if (length(p) - 1L < level) return(l$name)
      if (level < 3L) return(p[level])
      paste(p[level:(length(p) - 1L)], collapse = " / ")
    }, character(1))
  }
  data.frame(
    id = ids,
    name = vapply(out, function(l) l$name, character(1)),
    value = vapply(out, function(l) l$value, numeric(1)),
    g1 = group(1L),
    g2 = group(2L),
    g3 = group(3L),
    fill = vapply(out, function(l) l$color, character(1)),
    stringsAsFactors = FALSE
  )
}

mint_register(mint_chart(
  id = "treemap",
  name = "矩形树图",
  english = "TreeMap",
  category = "hierarchy",
  description = "用矩形面积表达占比，支持多层嵌套，适合看大盘构成",
  data_shape = paste(
    "三种写法：",
    "1) 嵌套：{ \"name\": \"总计\", \"children\": [{ \"name\": \"华东\", \"value\": 300 }] }",
    "2) 平铺：[{ \"name\": \"华东\", \"value\": 300 }]（会自动套一个根节点）",
    "3) 路径：[{ \"path\": \"线上/华东/上海\", \"value\": 120 }]（用 / 自动建树）",
    sep = "\n"
  ),
  variants = c("squarify 方形", "sliceDice 切片"),
  aliases = c("树图", "矩形树图", "treemap", "占比方块"),
  packages = c("ggplot2", "treemapify", "ggfittext"),
  options = list(
    mint_option("tile", "string", "切分算法", default = "squarify",
                values = c("squarify", "slice", "dice", "sliceDice", "binary")),
    mint_option("innerPadding", "number", "子节点内边距", default = 3),
    mint_option("outerPadding", "number", "根节点外边距", default = 4),
    mint_option("labelSkipSize", "number", "小于该面积的矩形不显示标签", default = 26),
    mint_option("root", "string", "自动生成根节点时的名字", default = "总计"),
    mint_option("valueFormat", "string", "数值格式化方式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数，省略则用千分位整数"),
    mint_option("valuePrefix", "string", "数值前缀，如 ¥"),
    mint_option("valueSuffix", "string", "数值后缀，如 万")
  ),
  example = list(
    data = list(
      name = "总收入",
      children = list(
        list(name = "线上", children = list(
          list(name = "华东", value = 320), list(name = "华北", value = 240),
          list(name = "华南", value = 180), list(name = "西南", value = 96)
        )),
        list(name = "线下", children = list(
          list(name = "门店", value = 210), list(name = "经销", value = 150),
          list(name = "直营", value = 88)
        )),
        list(name = "海外", children = list(
          list(name = "东南亚", value = 132), list(name = "欧洲", value = 104),
          list(name = "北美", value = 76)
        ))
      )
    ),
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options
    fmt <- ctx$formatter
    model <- mint_treemap_model(ctx$data, o$root %||% "总计")
    if (is.null(model) || is.null(model$children)) {
      mint_fail("INVALID_DATA", "treemap 的数据里没有任何正的数值",
                "面积图只接受 value > 0 的叶子节点")
    }

    leaves <- mint_treemap_leaves(model, ctx$colors)
    total <- sum(leaves$value)
    font_size <- ctx$style$type$data_label
    ink <- vapply(leaves$fill, mint_treemap_ink, character(1))

    # 画布换算成毫米：矩形面积 ≈ 占比 × 画布面积，用它判断标签放不放得下。
    # labelSkipSize 沿用旧版 px² 语义，这里当面积下限（mm²）用：太小的格子直接不标。
    canvas_mm2 <- ctx$width * ctx$height * 645.16
    min_area_mm2 <- o$labelSkipSize %||% 26
    label_w_mm <- pmax(
      vapply(leaves$name, mint_text_width, numeric(1), size = font_size),
      vapply(fmt(leaves$value), mint_text_width, numeric(1), size = font_size)
    ) * 0.3528                                   # pt -> mm
    line_mm <- font_size * 1.3 * 0.3528
    tile_mm2 <- leaves$value / total * canvas_mm2
    # 面积下限乘 2.4 / 1.8 是给格子长宽比留的余量：squarify 出来的块不保证方正
    two_line <- tile_mm2 >= 2.4 * (label_w_mm * line_mm * 2) + min_area_mm2
    one_line <- tile_mm2 >= 1.8 * (label_w_mm * line_mm) + min_area_mm2
    leaves$label <- ifelse(two_line, paste0(leaves$name, "\n", fmt(leaves$value)),
                    ifelse(one_line, leaves$name, ""))

    # 旧版 tile 是 nivo 的切分算法名，translate 到 treemapify 的四种布局
    layout <- switch(o$tile %||% "squarify",
      "slice" = "srow", "dice" = "scol", "sliceDice" = "scol", "squarified")
    # innerPadding / outerPadding 沿用旧版 px 语义。treemapify 把 size 直接当 grid 的
    # lwd 用（1/96 英寸），所以这里按 px 折算：默认 3/4 对应 1.2 / 2.2 的缝宽。
    gap <- (o$innerPadding %||% 3) * 0.4
    group_gap <- (o$outerPadding %||% 4) * 0.55

    # treemapify 2.6.1 没把 subgroup* 登记成 aesthetic，ggplot2 会对这三个名字发
    # 「Ignoring unknown aesthetics」警告；但列本身照样传进 geom，分组是生效的，这里只压掉噪音。
    # 三个 geom 的 layout / start 必须一致，否则各画各的布局。
    geom <- function(...) suppressWarnings(...)
    layers <- list(
      geom(treemapify::geom_treemap(
        ggplot2::aes(area = value, fill = id, subgroup = g1, subgroup2 = g2, subgroup3 = g3),
        colour = ctx$background, size = gap, layout = layout, start = "topleft"
      )),
      geom(treemapify::geom_treemap_subgroup_border(
        ggplot2::aes(area = value, subgroup = g1, subgroup2 = g2, subgroup3 = g3),
        colour = ctx$background, size = group_gap, layout = layout, start = "topleft"
      )),
      geom(treemapify::geom_treemap_text(
        ggplot2::aes(area = value, label = label, colour = ink,
                     subgroup = g1, subgroup2 = g2, subgroup3 = g3),
        place = "centre", grow = FALSE, reflow = FALSE, min.size = 0,
        size = font_size, lineheight = 1.1, layout = layout, start = "topleft"
      ))
    )

    ggplot2::ggplot(leaves) +
      layers +
      ggplot2::scale_fill_manual(values = stats::setNames(leaves$fill, leaves$id), guide = "none") +
      ggplot2::scale_colour_identity() +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        panel.background = ggplot2::element_blank(),
        # 树图铺满整个版心：留一圈外边距，否则最外圈的块贴着裁切线，像被切掉了
        plot.margin = ggplot2::margin(5, 5, 5, 5)
      )
  }
))
