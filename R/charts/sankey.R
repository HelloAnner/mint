# 桑基图 sankey
#
# 自绘而不是用 ggalluvial 的原因：这张图的三条约束——「节点是细矩形、名字与数值直标在
# 节点旁、流按来源节点配色」——都要精确控制节点条的厚度、间距与锚点位置；
# 通用库自带一套 lode/stratum 排布，改到符合期刊样式反而更绕。
#
# 布局用「沿流向 u + 横跨 v」两个坐标算，最后按布局方向映射到画布 x/y，
# 横向与纵向因此共用同一套排版代码。数据单位与画布英寸是 1:1
# （用带精确 limits 的 coord_cartesian，不用会把 panel 压成正方形的 coord_fixed）。

mint_sankey_text_w <- function(text, size) {
  if (length(text) == 0) return(numeric(0))
  mint_text_width(text, size) / 72
}

mint_register(mint_chart(
  id = "sankey",
  name = "桑基图",
  english = "Sankey",
  category = "flow",
  description = "用带宽表示流向的规模，展示来源到去向的分配路径",
  data_shape = paste(
    "{",
    "  \"nodes\": [{ \"id\": \"搜索\" }, { \"id\": \"注册\" }, { \"id\": \"付费\" }],",
    "  \"links\": [{ \"source\": \"搜索\", \"target\": \"注册\", \"value\": 320 }]",
    "}",
    "nodes 可以省略，会从 links 的 source/target 自动推导。",
    "source/target 也支持写成 from/to，value 支持写成 weight。",
    sep = "\n"
  ),
  variants = c("horizontal 横向", "vertical 纵向"),
  aliases = c("桑基图", "sankey", "流向图", "流量图"),
  packages = c("ggplot2"),
  options = list(
    mint_option("layout", "string", "布局方向", default = "horizontal", values = c("horizontal", "vertical")),
    mint_option("nodeThickness", "number", "节点条厚度（pt）", default = 16),
    mint_option("nodeSpacing", "number", "同一阶段内节点之间的间距（pt）", default = 18),
    mint_option("linkOpacity", "number", "连线透明度", default = 0.28),
    mint_option("gradient", "boolean", "连线是否按来源→目标渐变色", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number",
                values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = list(
      nodes = list(
        list(id = "搜索广告"), list(id = "社交媒体"), list(id = "自然流量"),
        list(id = "注册"), list(id = "未转化"), list(id = "付费")
      ),
      links = list(
        list(source = "搜索广告", target = "注册", value = 320),
        list(source = "社交媒体", target = "注册", value = 210),
        list(source = "自然流量", target = "注册", value = 180),
        list(source = "搜索广告", target = "未转化", value = 140),
        list(source = "社交媒体", target = "未转化", value = 165),
        list(source = "自然流量", target = "未转化", value = 95),
        list(source = "注册", target = "付费", value = 246)
      )
    ),
    options = list(layout = "horizontal", linkOpacity = 0.3)
  ),
  render = function(ctx) {
    o <- ctx$options
    model <- mint_sankey_model(ctx$data)
    fmt <- ctx$formatter
    links <- model$links
    ids <- model$nodes
    n_node <- length(ids)

    if (sum(links$value) <= 0) {
      mint_fail("INVALID_DATA", "桑基图所有连线的 value 都是 0，画不出流量",
                "至少让一条连线的 value 大于 0")
    }

    horizontal <- !identical(o$layout, "vertical")
    alpha <- min(1, max(0.02, o$linkOpacity %||% 0.28))
    gradient <- !identical(o$gradient, FALSE)
    flow_len <- if (horizontal) ctx$width else ctx$height
    cross_len <- if (horizontal) ctx$height else ctx$width
    th <- (o$nodeThickness %||% 16) / 72
    node_gap <- (o$nodeSpacing %||% 18) / 72
    label_size <- ctx$style$type$data_label
    pad_cross <- 0.08

    # ── 阶段：沿流向做最长路径分层，保证每条流都是「从前一段流向后一段」
    stage <- mint_sankey_stages(links, ids)
    n_stage <- max(stage) + 1L

    # ── 节点流量取进出两端的较大值：中间节点若被小的一侧决定，带宽会突然缩水
    node_val <- pmax(
      mint_sankey_sum(links$value, links$target, ids),
      mint_sankey_sum(links$value, links$source, ids)
    )

    # ── 比例的公共比例尺：取最挤的一层来定，任何一层都不会顶出画布
    order_idx <- mint_sankey_order(stage, ids, links, node_val)
    unit_scale <- Inf
    for (k in sort(unique(stage))) {
      members <- order_idx[stage[order_idx] == k]
      if (length(members) == 0) next
      avail <- cross_len - 2 * pad_cross - (length(members) - 1) * node_gap
      total <- sum(node_val[members])
      if (total > 0) unit_scale <- min(unit_scale, avail / total)
    }
    if (!is.finite(unit_scale)) {
      mint_fail("CANVAS_TOO_SMALL", "桑基图的节点排不下",
                "调大 --width / --height，或减少节点数")
    }
    node_h <- pmax(node_val * unit_scale, 0.02)

    # ── 横跨方向：每层的节点整体居中
    v_top <- v_bot <- rep(0, n_node)
    for (k in sort(unique(stage))) {
      members <- order_idx[stage[order_idx] == k]
      if (length(members) == 0) next
      stack <- sum(node_h[members]) + (length(members) - 1) * node_gap
      cursor <- (cross_len - stack) / 2
      for (i in members) {
        v_top[i] <- cursor
        v_bot[i] <- cursor + node_h[i]
        cursor <- cursor + node_h[i] + node_gap
      }
    }

    # ── 先量文字：首尾两端的直标要占流向方向的空间，扣掉之后节点才有位置
    label_text <- paste0(ids, "  ", fmt(node_val))
    label_need <- if (horizontal) {
      max(mint_sankey_text_w(label_text, label_size)) + 0.10
    } else {
      label_size * 1.2 / 72 + 0.12
    }
    avail_flow <- flow_len - 2 * label_need
    if (avail_flow < n_stage * th + 0.4) {
      mint_fail("CANVAS_TOO_SMALL",
                sprintf("桑基图需要至少 %.2f in 的%s向空间，当前只有 %.2f in",
                        2 * label_need + n_stage * th + 0.4,
                        if (horizontal) "宽" else "高", flow_len),
                if (horizontal) "调大 --width，或缩短节点名称" else "调大 --height，或缩短节点名称")
    }
    gap_flow <- if (n_stage > 1) (avail_flow - n_stage * th) / (n_stage - 1) else 0
    # 阶段间距封顶：画布很宽而阶段很少时，流带拉得太长会变成一片扁平的色块，
    # 多余的空间留给两侧，流带保持一定斜率反而更容易读层次
    gap_flow <- min(gap_flow, 1.35)
    span_used <- n_stage * th + (n_stage - 1) * gap_flow
    stage_u <- (flow_len - span_used) / 2 + (seq_len(n_stage) - 1) * (th + gap_flow)

    # ── 锚点：同一节点上的多条流按对端节点的位置排开，彼此不压叠，
    #    读者才能从节点条的厚度直接读出「哪一股占多少」
    src_span <- matrix(0, nrow(links), 2)
    tgt_span <- matrix(0, nrow(links), 2)
    mid_v <- (v_top + v_bot) / 2
    for (i in seq_len(n_node)) {
      outs <- which(links$source == ids[i])
      if (length(outs) > 1) {
        peer <- match(links$target[outs], ids)
        outs <- outs[order(stage[peer], mid_v[peer])]
      }
      cursor <- v_top[i]
      for (k in outs) {
        src_span[k, ] <- c(cursor, cursor + links$value[k] * unit_scale)
        cursor <- cursor + links$value[k] * unit_scale
      }
      ins <- which(links$target == ids[i])
      if (length(ins) > 1) {
        peer <- match(links$source[ins], ids)
        ins <- ins[order(stage[peer], mid_v[peer])]
      }
      cursor <- v_top[i]
      for (k in ins) {
        tgt_span[k, ] <- c(cursor, cursor + links$value[k] * unit_scale)
        cursor <- cursor + links$value[k] * unit_scale
      }
    }

    to_xy <- function(u, v) {
      if (horizontal) list(x = u, y = cross_len - v) else list(x = v, y = flow_len - u)
    }

    # ── 节点条与直标
    node_colour <- mint_colors(n_node, ctx$colors)
    bars <- data.frame(u0 = stage_u[stage + 1L], u1 = stage_u[stage + 1L] + th,
                       v0 = v_top, v1 = v_bot)
    p0 <- to_xy(bars$u0, bars$v0)
    p1 <- to_xy(bars$u1, bars$v1)
    bars$xmin <- pmin(p0$x, p1$x); bars$xmax <- pmax(p0$x, p1$x)
    bars$ymin <- pmin(p0$y, p1$y); bars$ymax <- pmax(p0$y, p1$y)
    bars$fill <- node_colour

    labels <- data.frame(
      u = ifelse(stage == 0L, stage_u[1] - 0.06, stage_u[stage + 1L] + th + 0.06),
      v = mid_v, before = stage == 0L, text = label_text, stringsAsFactors = FALSE
    )
    lp <- to_xy(labels$u, labels$v)
    labels$x <- lp$x
    labels$y <- lp$y
    if (horizontal) {
      labels$hjust <- ifelse(labels$before, 1, 0)
      labels$vjust <- 0.5
    } else {
      # 纵向布局下标签压在节点条上方/下方，夹一下 x 免得顶出画布
      half <- mint_sankey_text_w(labels$text, label_size) / 2
      labels$x <- pmin(pmax(labels$x, half + 0.02), cross_len - half - 0.02)
      labels$hjust <- 0.5
      labels$vjust <- ifelse(labels$before, 0, 1)
    }

    # ── 流带：沿 v 用 smoothstep 缓入缓出（进出的切线都垂直于节点条），沿 u 线性推进；
    #    粗流先画、细流压在上层，细带子才不会被盖住
    k_pts <- 24L
    t <- seq(0, 1, length.out = k_pts)
    ease <- t * t * (3 - 2 * t)
    # 粗流先画、细流压在上层，细带子才不会被盖住；数据里有环时回流（目标层不更靠后）
    # 最先画，让正向的流盖在上面
    back_edge <- stage[match(links$target, ids)] <= stage[match(links$source, ids)]
    tokens <- order(back_edge, -links$value)

    p <- ggplot2::ggplot()
    for (k in tokens) {
      u0 <- stage_u[stage[match(links$source[k], ids)] + 1L] + th
      u1 <- stage_u[stage[match(links$target[k], ids)] + 1L]
      uu <- u0 + (u1 - u0) * t
      vtop <- src_span[k, 1] + (tgt_span[k, 1] - src_span[k, 1]) * ease
      vbot <- src_span[k, 2] + (tgt_span[k, 2] - src_span[k, 2]) * ease
      xy <- to_xy(c(uu, rev(uu)), c(vtop, rev(vbot)))
      poly <- data.frame(x = xy$x, y = xy$y)
      src <- node_colour[match(links$source[k], ids)]
      tgt <- node_colour[match(links$target[k], ids)]
      fill <- if (gradient) {
        grid::linearGradient(
          c(grDevices::adjustcolor(src, alpha.f = alpha),
            grDevices::adjustcolor(tgt, alpha.f = alpha)),
          x1 = 0, y1 = if (horizontal) 0 else 1,
          x2 = if (horizontal) 1 else 0, y2 = 0
        )
      } else {
        grDevices::adjustcolor(src, alpha.f = alpha)
      }
      p <- p + ggplot2::geom_polygon(data = poly, ggplot2::aes(x = x, y = y), fill = fill, colour = NA)
    }

    p +
      ggplot2::geom_rect(
        data = bars,
        ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
        fill = bars$fill, colour = NA
      ) +
      ggplot2::geom_text(
        data = labels,
        ggplot2::aes(x = x, y = y, label = text, hjust = hjust, vjust = vjust),
        size = label_size / ggplot2::.pt, colour = ctx$text
      ) +
      ggplot2::scale_x_continuous(limits = c(0, if (horizontal) flow_len else cross_len), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, if (horizontal) cross_len else flow_len), expand = c(0, 0)) +
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
))

#' 归一化桑基图数据（与旧实现 asGraph 的字段别名保持一致）
mint_sankey_model <- function(data, chart = "sankey") {
  if (!is.list(data) || is.null(names(data))) {
    mint_fail("INVALID_DATA", sprintf("%s 需要 { nodes: [...], links: [...] } 结构，收到数组", chart),
              "形如 { \"links\": [{ \"source\": \"搜索\", \"target\": \"注册\", \"value\": 320 }] }")
  }
  raw_links <- data$links
  if (is.null(raw_links) || length(raw_links) == 0) {
    mint_fail("INVALID_DATA", sprintf("%s 需要非空的 links 数组", chart),
              "形如 { \"source\": \"搜索\", \"target\": \"注册\", \"value\": 320 }")
  }

  source <- target <- character(0)
  value <- numeric(0)
  for (i in seq_along(raw_links)) {
    raw <- raw_links[[i]]
    if (!is.list(raw)) {
      mint_fail("INVALID_DATA", sprintf("%s 的第 %d 条连线不是对象", chart, i),
                "形如 { \"source\": \"搜索\", \"target\": \"注册\", \"value\": 320 }")
    }
    from <- raw$source %||% raw$from
    to <- raw$target %||% raw$to
    weight <- raw$value %||% raw$weight
    if (is.null(from) || is.null(to) || !is.numeric(weight) || length(weight) != 1) {
      mint_fail("INVALID_DATA",
                sprintf("%s 的第 %d 条连线缺少 source / target 或数值型 value", chart, i),
                "形如 { \"source\": \"搜索\", \"target\": \"注册\", \"value\": 320 }")
    }
    if (as.character(from) == as.character(to)) {
      mint_fail("INVALID_DATA",
                sprintf("%s 的第 %d 条连线指向了自己（%s）", chart, i, as.character(from)),
                "自环会让同一节点的进出流量互相抵消，请删掉这条连线")
    }
    if (as.numeric(weight) < 0) {
      mint_fail("INVALID_DATA", sprintf("%s 的第 %d 条连线的 value 不能为负", chart, i),
                "带宽是按数值画的，负值没有对应的宽度")
    }
    source <- c(source, as.character(from))
    target <- c(target, as.character(to))
    value <- c(value, as.numeric(weight))
  }

  ids <- character(0)
  for (node in data$nodes %||% list()) {
    id <- if (is.list(node)) (node$id %||% node$name %||% node$label) else node
    if (is.null(id)) {
      mint_fail("INVALID_DATA", sprintf("%s 的 nodes 里有缺少 id 的项", chart),
                "形如 { \"id\": \"搜索\" }")
    }
    if (!as.character(id) %in% ids) ids <- c(ids, as.character(id))
  }
  for (id in c(source, target)) if (!id %in% ids) ids <- c(ids, id)
  if (length(ids) == 0) {
    mint_fail("INVALID_DATA", sprintf("%s 没有解析出任何节点", chart),
              "检查 links 里的 source / target")
  }

  list(
    nodes = ids,
    links = data.frame(source = source, target = target, value = value, stringsAsFactors = FALSE)
  )
}

#' 沿流向分层：先按最长路径松弛（无环数据能得到正确的层号），
#' 最多迭代 n+2 轮；如果还在变说明数据里有环，就退回「从无入边的节点出发、
#' 每个节点只定一次层」的分层 —— 否则环会把节点一路推到最右边，整张图挤成一团
mint_sankey_stages <- function(links, ids) {
  n <- length(ids)
  idx <- stats::setNames(seq_len(n), ids)
  stage <- rep(0L, n)
  converged <- FALSE
  for (iter in seq_len(n + 2L)) {
    changed <- FALSE
    for (k in seq_len(nrow(links))) {
      s <- idx[[links$source[k]]]
      t <- idx[[links$target[k]]]
      if (stage[t] <= stage[s]) {
        stage[t] <- stage[s] + 1L
        changed <- TRUE
      }
    }
    if (!changed) {
      converged <- TRUE
      break
    }
  }
  if (converged) return(stage)

  indegree <- vapply(ids, function(id) sum(links$target == id), integer(1))
  stage <- rep(NA_integer_, n)
  roots <- which(indegree == 0)
  if (length(roots) == 0) roots <- 1L
  stage[roots] <- 0L
  queue <- roots
  while (length(queue) > 0) {
    i <- queue[1]
    queue <- queue[-1]
    for (k in which(links$source == ids[i])) {
      j <- idx[[links$target[k]]]
      if (is.na(stage[j])) {
        stage[j] <- stage[i] + 1L
        queue <- c(queue, j)
      }
    }
  }
  stage[is.na(stage)] <- 0L
  stage
}

#' 按节点汇总数值（节点没出现时记 0）
mint_sankey_sum <- function(value, key, ids) {
  if (length(key) == 0) return(numeric(length(ids)))
  out <- as.numeric(tapply(value, factor(key, levels = ids), sum))
  out[is.na(out)] <- 0
  out
}

#' 层内顺序：按相邻层邻居的重心排序（按流量加权），把互相连接的节点排到一起。
#' 优先用「上一层」（进来的流）定位：多对少再对少的漏斗型数据里，若把下一层的
#' 位置也算进来，汇合节点会被唯一的下游节点拉走，反而制造出新的交叉。
mint_sankey_order <- function(stage, ids, links, node_val) {
  n <- length(ids)
  order_idx <- seq_len(n)
  for (pass in seq_len(3)) {
    for (k in sort(unique(stage))) {
      members <- order_idx[stage[order_idx] == k]
      if (length(members) <= 1) next
      pos <- seq_along(order_idx)
      names(pos) <- as.character(order_idx)
      bary <- vapply(members, function(i) {
        inc <- which(links$target == ids[i])
        out <- which(links$source == ids[i])
        up <- match(links$source[inc], ids)
        upw <- links$value[inc]
        dn <- match(links$target[out], ids)
        dnw <- links$value[out]
        if (any(stage[up] < k)) {
          peer <- up[stage[up] < k]
          w <- upw[stage[up] < k]
        } else {
          peer <- dn[stage[dn] > k]
          w <- dnw[stage[dn] > k]
        }
        if (length(peer) == 0) return(unname(pos[[as.character(i)]]))
        stats::weighted.mean(pos[as.character(peer)], w)
      }, numeric(1))
      order_idx[order_idx %in% members] <- members[order(bary, -node_val[members])]
    }
  }
  order_idx
}
