# 架构图 architecture
#
# 自绘而不是用 DiagrammeR 的原因：它的默认样式、字体与边距都不受控，
# 而这张图要的是「细描边 + 极浅填充 + 小字号 + 克制的箭头」这套期刊语言。
#
# 排版在真实英寸坐标系里做：每层一条横向带（横向布局时是一列），层名占左侧/顶部一条带，
# 层内方块按可用宽度或高度等分，文字用 mint_wrap 折行后反推方块高度。
# 装不下时直接报 CANVAS_TOO_SMALL 给出所需尺寸，而不是缩到看不清或者裁掉。
#
# 与 funnel/sankey 一样不用 coord_fixed：本仓的版心会把 panel 的宽高归一，
# coord_fixed 会把 panel 压成正方形，导致 x 方向被压缩；精确 limits + coord_cartesian
# 才能让数据单位与画布英寸 1:1。

# 文字宽度直接走 mint_text_width（它按真实字宽估算：全角 1.0 em、半角 0.52 em）
mint_arch_text_pt <- function(text, size) {
  if (length(text) == 0) return(numeric(0))
  mint_text_width(text, size)
}

mint_register(mint_chart(
  id = "architecture",
  name = "架构图",
  english = "Architecture Diagram",
  category = "relation",
  description = "把系统画成分层方块图：层是带子，方块是组件，细箭头表示组件之间的调用或依赖",
  data_shape = paste(
    "{",
    "  \"layers\": [",
    "    { \"name\": \"客户端\", \"nodes\": [{ \"id\": \"web\", \"label\": \"Web 控制台\", \"description\": \"React SPA\" }] },",
    "    { \"name\": \"接入层\", \"nodes\": [{ \"id\": \"gateway\", \"label\": \"API 网关\" }] }",
    "  ],",
    "  \"edges\": [{ \"from\": \"web\", \"to\": \"gateway\", \"label\": \"HTTPS\" }]",
    "}",
    "nodes 里每一项可以是字符串（id 即名称）或对象；对象支持 label 显示名、description 小字说明。",
    "layers 也可以写成 { \"接入层\": [...], \"服务层\": [...] }；",
    "或者省略 layers，直接给 nodes，用每个节点的 layer / group 字段自动分层。",
    "edges 支持 from/to（也可写 source/target），label 是连线上的小标签。",
    sep = "\n"
  ),
  variants = c("vertical 纵向分层", "horizontal 横向分层"),
  aliases = c("架构图", "系统架构图", "架构", "architecture", "arch", "topology", "拓扑图", "部署图"),
  packages = c("ggplot2", "ggforce"),
  options = list(
    mint_option("direction", "string", "分层方向：纵向从上到下，横向从左到右", default = "vertical",
                values = c("vertical", "horizontal")),
    mint_option("edgeStyle", "string", "连线样式", default = "curve",
                values = c("curve", "straight", "elbow")),
    mint_option("showLayers", "boolean", "是否显示层名的底衬色带", default = TRUE),
    mint_option("showDescriptions", "boolean", "是否显示方块里的小字说明", default = TRUE),
    mint_option("edgeLabels", "boolean", "是否显示连线上的标签", default = TRUE),
    mint_option("nodeGap", "number", "同一层内方块的间距（英寸）", default = 0.14),
    mint_option("layerGap", "number", "层与层之间的间距（英寸）", default = 0.30),
    mint_option("detourGap", "number", "同层连线绕开中间方块时向外绕行的距离（英寸），0 表示不绕行", default = 0.20),
    mint_option("minNodeWidth", "number", "方块最小宽度（英寸）", default = 0.9),
    mint_option("maxNodeWidth", "number", "方块最大宽度（英寸）", default = 2.4),
    mint_option("labelSize", "number", "方块主标题字号（pt）", default = 7.5),
    mint_option("descriptionSize", "number", "方块说明文字字号（pt）", default = 6.5),
    mint_option("edgeLabelSize", "number", "连线标签字号（pt）", default = 6.5),
    mint_option("lineWidth", "number", "连线粗细（pt）", default = 0.6),
    mint_option("cornerRadius", "number", "方块圆角半径（pt），0 为直角（期刊风格默认直角）", default = 0)
  ),
  example = list(
    data = list(
      layers = list(
        list(name = "客户端", nodes = list(
          list(id = "web", label = "Web 控制台", description = "React SPA"),
          list(id = "mobile", label = "移动 App", description = "iOS / Android"),
          list(id = "sdk", label = "开放 SDK")
        )),
        list(name = "接入层", nodes = list(
          list(id = "cdn", label = "CDN", description = "静态资源"),
          list(id = "gateway", label = "API 网关", description = "鉴权 · 限流")
        )),
        list(name = "服务层", nodes = list(
          list(id = "user", label = "用户服务"),
          list(id = "order", label = "订单服务"),
          list(id = "report", label = "报表服务"),
          list(id = "worker", label = "异步任务")
        )),
        list(name = "数据层", nodes = list(
          list(id = "pg", label = "PostgreSQL", description = "主库"),
          list(id = "redis", label = "Redis", description = "缓存"),
          list(id = "mq", label = "Kafka", description = "消息队列"),
          list(id = "olap", label = "ClickHouse", description = "分析库")
        ))
      ),
      edges = list(
        list(from = "web", to = "cdn"),
        list(from = "mobile", to = "gateway"),
        list(from = "sdk", to = "gateway", label = "HTTPS"),
        list(from = "cdn", to = "gateway"),
        list(from = "gateway", to = "user", label = "gRPC"),
        list(from = "gateway", to = "order"),
        list(from = "gateway", to = "report"),
        list(from = "order", to = "worker", label = "事件"),
        list(from = "user", to = "pg"),
        list(from = "order", to = "pg"),
        list(from = "user", to = "redis"),
        list(from = "order", to = "mq"),
        list(from = "worker", to = "mq"),
        list(from = "report", to = "olap")
      )
    ),
    options = list(direction = "vertical", edgeStyle = "curve")
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_arch_model(ctx$data)
    layout <- mint_arch_layout(model, ctx, o)

    token <- ctx$style$tokens
    geoms <- ctx$style$geoms
    layer_colour <- mint_colors(length(model$layers), ctx$colors)

    bands <- layout$bands
    # 逐层算同色系深浅
    tint_of <- function(layer, amount) {
      vapply(layer, function(k) mint_tint(layer_colour[k], amount), character(1))
    }
    bands$fill <- tint_of(bands$layer, 0.11)

    nodes <- layout$nodes
    nodes$fill <- tint_of(nodes$layer, 0.16)
    nodes$stroke <- layer_colour[nodes$layer]

    edges <- layout$edges
    edge_colour <- token$muted
    arrow_pt <- max(1.6, (o$lineWidth %||% 0.6) * 3.2)
    line_mm <- (o$lineWidth %||% 0.6) / 2.845   # pt -> ggplot linewidth(mm)

    p <- ggplot2::ggplot()

    if (!identical(o$showLayers, FALSE) && nrow(bands) > 0) {
      p <- p + ggplot2::geom_rect(
        data = bands,
        ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
        fill = bands$fill, colour = NA
      )
    }

    # 连线画在方块下面：箭头只到方块边界，压住一点也看不出来
    if (nrow(edges) > 0) {
      p <- p + ggplot2::geom_path(
        data = edges, ggplot2::aes(x = x, y = y, group = id),
        colour = edge_colour, linewidth = line_mm, lineend = "round", linejoin = "round",
        arrow = ggplot2::arrow(length = grid::unit(arrow_pt, "pt"), type = "closed"),
        show.legend = FALSE
      )
    }

    if (nrow(nodes) > 0) {
      radius <- max(0, o$cornerRadius %||% 0)
      if (radius > 0) {
        # ggforce::geom_shape 吃的是多边形顶点（不是 xmin/xmax），所以把矩形展开成四角，
        # 圆角半径再夹一下，避免小方块被切成畸形的圆
        radius <- min(radius, 0.45 * min(nodes$xmax - nodes$xmin, nodes$ymax - nodes$ymin) * 72)
        poly <- do.call(rbind, lapply(seq_len(nrow(nodes)), function(i) {
          data.frame(
            id = nodes$id[i],
            x = nodes$xmin[i] + c(0, 1, 1, 0) * (nodes$xmax[i] - nodes$xmin[i]),
            y = nodes$ymin[i] + c(0, 0, 1, 1) * (nodes$ymax[i] - nodes$ymin[i]),
            fill = nodes$fill[i], stroke = nodes$stroke[i],
            stringsAsFactors = FALSE
          )
        }))
        p <- p + ggforce::geom_shape(
          data = poly, ggplot2::aes(x = x, y = y, group = id),
          radius = grid::unit(radius, "pt"),
          fill = poly$fill, colour = poly$stroke, linewidth = geoms$axis_width
        )
      } else {
        p <- p + ggplot2::geom_rect(
          data = nodes,
          ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
          fill = nodes$fill, colour = nodes$stroke, linewidth = geoms$axis_width
        )
      }
    }

    if (nrow(layout$labels) > 0) {
      labels <- layout$labels
      p <- p + ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = x, y = y, label = text, hjust = hjust, vjust = vjust),
        size = labels$size / ggplot2::.pt, colour = labels$colour,
        fontface = labels$face, lineheight = 1.15
      )
    }

    if (!identical(o$edgeLabels, FALSE) && nrow(layout$edge_labels) > 0) {
      el <- layout$edge_labels
      p <- p + ggplot2::geom_label(
        data = el, ggplot2::aes(x = x, y = y, label = text),
        size = (o$edgeLabelSize %||% ctx$style$type$data_label) / ggplot2::.pt,
        colour = token$muted, fill = ctx$background, linewidth = 0,
        label.padding = grid::unit(0.08, "lines"), show.legend = FALSE
      )
    }

    p +
      ggplot2::scale_x_continuous(limits = c(0, ctx$width), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, ctx$height), expand = c(0, 0)) +
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
))

#' 归一化架构图数据：兼容「layers 数组 / layers 对象 / nodes 带 layer 字段」三种写法
mint_arch_model <- function(data, chart = "architecture") {
  hint <- '推荐写法：{ "layers": [{ "name": "接入层", "nodes": [{ "id": "gateway" }] }], "edges": [{ "from": "web", "to": "gateway" }] }'
  if (!is.list(data) || is.null(names(data))) {
    mint_fail("INVALID_DATA", sprintf("%s 需要对象数据，收到%s", chart, mint_type_name(data)), hint)
  }

  read_node <- function(raw, where) {
    if (is.character(raw) || is.numeric(raw)) {
      id <- as.character(raw)
      return(list(id = id, label = id, description = NULL))
    }
    if (!is.list(raw)) {
      mint_fail("INVALID_DATA", sprintf("%s 必须是字符串或对象", where), hint)
    }
    raw_id <- raw$id %||% raw$name %||% raw$label
    if (is.null(raw_id)) {
      mint_fail("INVALID_DATA", sprintf("%s 缺少 id（也可以用 name / label）", where), hint)
    }
    id <- as.character(raw_id)
    desc <- raw$description %||% raw$desc %||% raw$detail %||% raw$note
    list(
      id = id,
      label = as.character(raw$label %||% raw$name %||% id),
      description = if (is.null(desc)) NULL else as.character(desc)
    )
  }

  layers <- list()
  push_layer <- function(name, raw_nodes, where) {
    if (!is.list(raw_nodes)) {
      mint_fail("INVALID_DATA", sprintf("%s 的 nodes 必须是数组", where), hint)
    }
    nodes <- lapply(seq_along(raw_nodes), function(i) read_node(raw_nodes[[i]], sprintf("%s 第 %d 个节点", where, i)))
    if (length(nodes) > 0) {
      layers[[length(layers) + 1L]] <<- list(name = as.character(name), nodes = nodes)
    }
  }

  raw_layers <- data$layers
  if (is.list(raw_layers) && length(raw_layers) > 0 && is.null(names(raw_layers))) {
    for (i in seq_along(raw_layers)) {
      layer <- raw_layers[[i]]
      if (!is.list(layer) || is.null(names(layer))) {
        mint_fail("INVALID_DATA", sprintf("layers 第 %d 项必须是对象", i),
                  '形如 { "name": "接入层", "nodes": [...] }')
      }
      push_layer(layer$name %||% layer$title %||% layer$label %||% sprintf("层级 %d", i),
                 layer$nodes %||% layer$items %||% layer$children,
                 sprintf("layers 第 %d 项", i))
    }
  } else if (is.list(raw_layers) && !is.null(names(raw_layers))) {
    for (name in names(raw_layers)) {
      push_layer(name, raw_layers[[name]], sprintf("layer「%s」", name))
    }
  }

  if (length(layers) == 0 && length(data$nodes) > 0) {
    # 没有 layers 时按节点自带的 layer / group 字段分层，顺序取首次出现
    order <- character(0)
    grouped <- list()
    for (i in seq_along(data$nodes)) {
      raw <- data$nodes[[i]]
      node <- read_node(raw, sprintf("第 %d 个节点", i))
      group <- if (is.list(raw)) as.character(raw$layer %||% raw$group %||% raw$tier %||% "默认") else "默认"
      if (!group %in% order) {
        order <- c(order, group)
        grouped[[group]] <- list()
      }
      grouped[[group]][[length(grouped[[group]]) + 1L]] <- node
    }
    for (name in order) layers[[length(layers) + 1L]] <- list(name = name, nodes = grouped[[name]])
  }

  if (length(layers) == 0) {
    mint_fail("INVALID_DATA", sprintf("%s 没有解析出任何节点", chart), hint)
  }

  ids <- unlist(lapply(layers, function(l) vapply(l$nodes, function(n) n$id, character(1))), use.names = FALSE)
  dup <- ids[duplicated(ids)]
  if (length(dup) > 0) {
    mint_fail("INVALID_DATA", sprintf("节点 id 重复：%s", dup[1]), "每个节点需要唯一 id")
  }

  raw_edges <- data$edges %||% data$links %||% list()
  if (!is.list(raw_edges)) {
    mint_fail("INVALID_DATA", "edges 必须是数组", '形如 [{ "from": "web", "to": "gateway" }]')
  }
  edges <- lapply(seq_along(raw_edges), function(i) {
    raw <- raw_edges[[i]]
    if (!is.list(raw)) {
      mint_fail("INVALID_DATA", sprintf("第 %d 条连线必须是对象", i), hint)
    }
    from <- raw$from %||% raw$source %||% raw$start
    to <- raw$to %||% raw$target %||% raw$end
    if (is.null(from) || is.null(to)) {
      mint_fail("INVALID_DATA", sprintf("第 %d 条连线缺少 from / to", i),
                '形如 { "from": "web", "to": "gateway" }')
    }
    for (pair in list(c("from", as.character(from)), c("to", as.character(to)))) {
      if (!pair[2] %in% ids) {
        mint_fail("INVALID_DATA",
                  sprintf("第 %d 条连线的 %s「%s」不是已定义的节点", i, pair[1], pair[2]),
                  sprintf("可用节点：%s", paste(ids, collapse = "、")))
      }
    }
    list(
      from = as.character(from), to = as.character(to),
      label = if (is.null(raw$label)) "" else as.character(raw$label)
    )
  })

  list(layers = layers, edges = edges)
}

#' 分层排版：在「沿层叠方向 u + 横跨方向 v」坐标系里算好所有几何
mint_arch_layout <- function(model, ctx, o) {
  vertical <- !identical(o$direction, "horizontal")
  node_gap <- max(0.04, o$nodeGap %||% 0.14)
  layer_gap <- max(0.06, o$layerGap %||% 0.30)
  min_w <- max(0.3, o$minNodeWidth %||% 0.9)
  max_w <- max(min_w, o$maxNodeWidth %||% 2.4)
  label_size <- o$labelSize %||% ctx$style$type$strip_text
  desc_size <- o$descriptionSize %||% ctx$style$type$data_label
  title_size <- ctx$style$type$axis_text
  show_layers <- !identical(o$showLayers, FALSE)
  show_desc <- !identical(o$showDescriptions, FALSE)
  edge_style <- o$edgeStyle %||% "curve"
  detour <- max(0, o$detourGap %||% 0.20)
  pad_x <- 0.07
  pad_y <- 0.05
  band_pad <- 0.07
  pad_edge <- 0.08

  n_layer <- length(model$layers)
  u_len <- if (vertical) ctx$height else ctx$width
  v_len <- if (vertical) ctx$width else ctx$height

  layer_names <- vapply(model$layers, function(l) l$name, character(1))
  # 层名占一条带：竖向布局在左侧，横向布局在顶部。
  # mint_text_width 只吃单个字符串，这里逐层量再取最大，别把整列传进去
  title_extent <- if (!show_layers) {
    0.06
  } else if (vertical) {
    max(mint_arch_text_pt(layer_names, title_size)) / 72 + 0.16
  } else {
    title_size * 1.2 / 72 + 0.16
  }
  v_content <- v_len - title_extent - 0.06
  if (v_content < 0.5) {
    mint_fail("CANVAS_TOO_SMALL",
              sprintf("架构图内容区只剩 %.2f in，放不下方块", v_content),
              if (vertical) "调大 --width，或减少每层的方块数" else "调大 --height")
  }

  # 方块里的文字一律沿画面的 x 轴排：折行宽度就是方块在 x 方向的可用宽度
  measure <- function(wrap_in, node) {
    wrap_pt <- max(20, (wrap_in - 2 * pad_x) * 72)
    label <- mint_wrap(node$label, wrap_pt, label_size)
    label_lines <- strsplit(label, "\n", fixed = TRUE)[[1]]
    desc <- NULL
    desc_lines <- character(0)
    if (show_desc && !is.null(node$description) && nzchar(node$description)) {
      desc <- mint_wrap(node$description, wrap_pt, desc_size)
      desc_lines <- strsplit(desc, "\n", fixed = TRUE)[[1]]
    }
    size <- pad_y * 2 + length(label_lines) * label_size * 1.22 / 72
    if (length(desc_lines) > 0) size <- size + 0.02 + length(desc_lines) * desc_size * 1.22 / 72
    list(label = label, desc = desc,
         label_lines = length(label_lines), desc_lines = length(desc_lines), size = size)
  }

  band_u <- numeric(n_layer)
  band_v0 <- numeric(n_layer)
  band_v1 <- numeric(n_layer)
  node_w <- numeric(n_layer)
  boxes <- vector("list", n_layer)

  if (vertical) {
    # 层是一条条横向的带子：层内方块等分可用宽度，文字折行反推带子厚度
    span <- v_content - 0.04
    for (k in seq_len(n_layer)) {
      nodes <- model$layers[[k]]$nodes
      kn <- length(nodes)
      share <- (span - 2 * band_pad - (kn - 1) * node_gap) / kn
      if (share < min_w) {
        mint_fail("CANVAS_TOO_SMALL",
                  sprintf("层「%s」有 %d 个方块，每个只剩 %.2f in 宽（至少需要 %.2f in）",
                          model$layers[[k]]$name, kn, share, min_w),
                  "调大 --width、减小 nodeGap，或把这一层拆成两层")
      }
      node_w[k] <- min(share, max_w)
      items <- lapply(nodes, function(nd) measure(node_w[k], nd))
      band_u[k] <- max(vapply(items, function(it) it$size, numeric(1))) + 2 * band_pad
      total_w <- kn * node_w[k] + (kn - 1) * node_gap
      cursor <- title_extent + 0.02 + (span - total_w) / 2
      band_v0[k] <- title_extent + 0.02
      band_v1[k] <- title_extent + 0.02 + span
      boxes[[k]] <- data.frame(
        id = vapply(nodes, function(nd) nd$id, character(1)),
        layer = k, v0 = cursor + (seq_len(kn) - 1) * (node_w[k] + node_gap),
        v1 = cursor + (seq_len(kn) - 1) * (node_w[k] + node_gap) + node_w[k],
        wrap = node_w[k],
        stringsAsFactors = FALSE
      )
      boxes[[k]]$label <- vapply(items, function(it) it$label, character(1))
      boxes[[k]]$desc <- vapply(items, function(it) if (is.null(it$desc)) "" else it$desc, character(1))
      boxes[[k]]$size <- vapply(items, function(it) it$size, numeric(1))
      boxes[[k]]$label_lines <- vapply(items, function(it) it$label_lines, numeric(1))
      boxes[[k]]$desc_lines <- vapply(items, function(it) it$desc_lines, numeric(1))
    }
    total_u <- sum(band_u) + (n_layer - 1) * layer_gap
    if (total_u > u_len - 2 * pad_edge) {
      need <- total_u + 2 * pad_edge
      mint_fail("CANVAS_TOO_SMALL",
                sprintf("架构图纵向需要 %.2f in，图表区只有 %.2f in（文字折行越多层越厚）", need, u_len),
                sprintf("调大 --height（图表区需要 %.2f in，标题还会另占一行），或减少层数 / 缩短方块文字", need))
    }
    cursor <- pad_edge + (u_len - 2 * pad_edge - total_u) / 2
    band_u0 <- numeric(n_layer)
    for (k in seq_len(n_layer)) {
      band_u0[k] <- cursor
      cursor <- cursor + band_u[k] + layer_gap
    }
    nodes <- do.call(rbind, lapply(seq_len(n_layer), function(k) {
      box <- boxes[[k]]
      box$u0 <- band_u0[k] + (band_u[k] - box$size) / 2
      box$u1 <- box$u0 + box$size
      box
    }))
    bands <- data.frame(
      layer = seq_len(n_layer),
      u0 = band_u0, u1 = band_u0 + band_u,
      v0 = band_v0, v1 = band_v1
    )
  } else {
    # 层是一列列：列的宽度等分，方块在列内沿 v 排开，高度由折行决定
    col_w <- (u_len - 2 * pad_edge - (n_layer - 1) * layer_gap) / n_layer
    if (col_w - 0.12 < min_w) {
      mint_fail("CANVAS_TOO_SMALL",
                sprintf("架构图横向有 %d 层，每列只剩 %.2f in 宽（至少需要 %.2f in）",
                        n_layer, col_w, min_w + 0.12),
                "调大 --width，或减少层数")
    }
    node_w[] <- min(col_w - 0.12, max_w)
    span <- v_content - 0.02
    for (k in seq_len(n_layer)) {
      nodes <- model$layers[[k]]$nodes
      kn <- length(nodes)
      items <- lapply(nodes, function(nd) measure(node_w[k], nd))
      sizes <- vapply(items, function(it) it$size, numeric(1))
      stack <- sum(sizes) + (kn - 1) * node_gap
      if (stack > span) {
        need <- stack + title_extent + 0.14
        mint_fail("CANVAS_TOO_SMALL",
                  sprintf("层「%s」的 %d 个方块纵向需要 %.2f in，图表区只有 %.2f in",
                          model$layers[[k]]$name, kn, need, v_len),
                  sprintf("调大 --height（图表区需要 %.2f in，标题还会另占一行），或减少这一层的方块数", need))
      }
      cursor <- title_extent + 0.02 + (span - stack) / 2
      box <- data.frame(
        id = vapply(nodes, function(nd) nd$id, character(1)),
        layer = k,
        v0 = cursor + c(0, cumsum(sizes[-kn] + node_gap)),
        v1 = cursor + c(0, cumsum(sizes[-kn] + node_gap)) + sizes,
        wrap = node_w[k], size = sizes,
        stringsAsFactors = FALSE
      )
      box$label <- vapply(items, function(it) it$label, character(1))
      box$desc <- vapply(items, function(it) if (is.null(it$desc)) "" else it$desc, character(1))
      box$label_lines <- vapply(items, function(it) it$label_lines, numeric(1))
      box$desc_lines <- vapply(items, function(it) it$desc_lines, numeric(1))
      boxes[[k]] <- box
    }
    band_u0 <- pad_edge + (seq_len(n_layer) - 1) * (col_w + layer_gap)
    band_u[] <- col_w
    band_v0[] <- title_extent + 0.02
    band_v1[] <- title_extent + 0.02 + span
    nodes <- do.call(rbind, lapply(seq_len(n_layer), function(k) {
      box <- boxes[[k]]
      box$u0 <- band_u0[k] + (col_w - node_w[k]) / 2
      box$u1 <- box$u0 + node_w[k]
      box
    }))
    bands <- data.frame(
      layer = seq_len(n_layer), u0 = band_u0, u1 = band_u0 + col_w,
      v0 = band_v0, v1 = band_v1
    )
  }
  rownames(nodes) <- NULL

  # u/v -> 画布坐标：纵向布局 u 向下，横向布局 u 向右
  to_xy <- function(u, v) if (vertical) list(x = v, y = ctx$height - u) else list(x = u, y = ctx$height - v)

  band_xy0 <- to_xy(bands$u0, bands$v0)
  band_xy1 <- to_xy(bands$u1, bands$v1)
  bands$xmin <- pmin(band_xy0$x, band_xy1$x); bands$xmax <- pmax(band_xy0$x, band_xy1$x)
  bands$ymin <- pmin(band_xy0$y, band_xy1$y); bands$ymax <- pmax(band_xy0$y, band_xy1$y)

  node_xy0 <- to_xy(nodes$u0, nodes$v0)
  node_xy1 <- to_xy(nodes$u1, nodes$v1)
  nodes$xmin <- pmin(node_xy0$x, node_xy1$x); nodes$xmax <- pmax(node_xy0$x, node_xy1$x)
  nodes$ymin <- pmin(node_xy0$y, node_xy1$y); nodes$ymax <- pmax(node_xy0$y, node_xy1$y)

  # 文字：主标题与说明各自作为整块居中，折行后整体也跟着居中。
  # 文字堆叠的方向固定是画面的 y 轴 —— 竖向布局里是 u，横向布局里是 v，别弄反。
  labels <- list()

  for (i in seq_len(nrow(nodes))) {
    content <- nodes$label_lines[i] * label_size * 1.22 / 72 +
      if (nodes$desc_lines[i] > 0) 0.02 + nodes$desc_lines[i] * desc_size * 1.22 / 72 else 0
    centre <- if (vertical) (nodes$u0[i] + nodes$u1[i]) / 2 else (nodes$v0[i] + nodes$v1[i]) / 2
    cross <- if (vertical) (nodes$v0[i] + nodes$v1[i]) / 2 else (nodes$u0[i] + nodes$u1[i]) / 2
    place <- function(along) if (vertical) to_xy(along, cross) else to_xy(cross, along)
    label_h <- nodes$label_lines[i] * label_size * 1.22 / 72
    lp <- place(centre - content / 2 + label_h / 2)
    labels[[length(labels) + 1L]] <- data.frame(
      x = lp$x, y = lp$y, text = nodes$label[i], size = label_size,
      colour = token_fg(ctx), face = "bold", hjust = 0.5, vjust = 0.5, stringsAsFactors = FALSE
    )
    if (nodes$desc_lines[i] > 0) {
      desc_h <- nodes$desc_lines[i] * desc_size * 1.22 / 72
      dp <- place(centre + content / 2 - desc_h / 2)
      labels[[length(labels) + 1L]] <- data.frame(
        x = dp$x, y = dp$y, text = nodes$desc[i], size = desc_size,
        colour = ctx$muted, face = "plain", hjust = 0.5, vjust = 0.5, stringsAsFactors = FALSE
      )
    }
  }
  if (show_layers) {
    for (k in seq_len(n_layer)) {
      u_mid <- (bands$u0[k] + bands$u1[k]) / 2
      if (vertical) {
        tp <- to_xy(u_mid, bands$v0[k] - 0.07)
        labels[[length(labels) + 1L]] <- data.frame(
          x = tp$x, y = tp$y, text = model$layers[[k]]$name, size = title_size,
          colour = layer_colour_at(ctx, k), face = "bold", hjust = 1, vjust = 0.5, stringsAsFactors = FALSE
        )
      } else {
        tp <- to_xy(u_mid, bands$v0[k] - 0.08)
        labels[[length(labels) + 1L]] <- data.frame(
          x = tp$x, y = tp$y, text = model$layers[[k]]$name, size = title_size,
          colour = layer_colour_at(ctx, k), face = "bold", hjust = 0.5, vjust = 0.5, stringsAsFactors = FALSE
        )
      }
    }
  }
  label_df <- do.call(rbind, labels)

  # 连线：跨层走 S 曲线/直角，同层绕到带子外面，避免从中间的方块身上压过去
  pos <- stats::setNames(seq_len(nrow(nodes)), nodes$id)
  paths <- list()
  edge_labels <- list()
  for (e in seq_along(model$edges)) {
    edge <- model$edges[[e]]
    ia <- pos[[edge$from]]; ib <- pos[[edge$to]]
    a <- nodes[ia, ]; b <- nodes[ib, ]
    va <- (a$v0 + a$v1) / 2
    vb <- (b$v0 + b$v1) / 2
    ku <- 24L
    tt <- seq(0, 1, length.out = ku)
    ease <- tt * tt * (3 - 2 * tt)
    if (a$layer == b$layer) {
      if (a$layer < n_layer) {
        hook <- a$u1; hook_b <- b$u1; u_edge <- bands$u1[a$layer]; dir <- 1
      } else {
        hook <- a$u0; hook_b <- b$u0; u_edge <- bands$u0[a$layer]; dir <- -1
      }
      d <- min(detour, layer_gap * 0.9)
      if (d <= 0) {
        uu <- c(hook, hook_b); vv <- c(va, vb)
      } else if (identical(edge$from, edge$to)) {
        lobe <- (a$v1 - a$v0) * 0.6
        uu <- c(hook, u_edge + dir * d * 0.6, u_edge + dir * d, u_edge + dir * d * 0.6, hook)
        vv <- c(va, va - lobe, va, va + lobe, va)
      } else {
        uu <- c(hook, u_edge + dir * d, u_edge + dir * d, hook_b)
        vv <- c(va, va, vb, vb)
      }
    } else {
      u0 <- a$u1; u1 <- b$u0
      if (identical(edge_style, "straight")) {
        uu <- c(u0, u1); vv <- c(va, vb)
      } else if (identical(edge_style, "elbow")) {
        # 中线错开一点：多条连线的中段否则会叠成一条，读者分不清谁连谁
        mid <- (u0 + u1) / 2 + 0.05 * ((e - 1) %% 3 - 1)
        uu <- c(u0, mid, mid, u1); vv <- c(va, va, vb, vb)
      } else {
        uu <- u0 + (u1 - u0) * tt
        vv <- va + (vb - va) * ease
      }
    }
    xy <- to_xy(uu, vv)
    paths[[length(paths) + 1L]] <- data.frame(
      id = sprintf("edge-%d", e), x = xy$x, y = xy$y,
      label = edge$label, stringsAsFactors = FALSE
    )
    if (nzchar(edge$label)) {
      mid <- ceiling(length(uu) / 2)
      edge_labels[[length(edge_labels) + 1L]] <- data.frame(
        x = xy$x[mid], y = xy$y[mid], text = edge$label, stringsAsFactors = FALSE
      )
    }
  }

  list(
    bands = bands, nodes = nodes, labels = label_df,
    edges = if (length(paths) > 0) do.call(rbind, paths) else data.frame(
      id = character(0), x = numeric(0), y = numeric(0), label = character(0)),
    edge_labels = if (length(edge_labels) > 0) do.call(rbind, edge_labels) else data.frame(
      x = numeric(0), y = numeric(0), text = character(0))
  )
}

#' 取画布前景色（节点主标题用）
token_fg <- function(ctx) ctx$style$tokens$fg

#' 取第 k 层的颜色（层名跟随层色，读者一眼能对上带子）
layer_colour_at <- function(ctx, k) mint_colors(max(k, 1), ctx$colors)[k]
