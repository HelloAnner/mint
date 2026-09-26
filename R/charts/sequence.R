# 时序图 sequence
#
# 用 ggplot2 直接画：参与者盒子 + 生命线 + 消息箭头 + 备注。
# 自己排版而不是调 DiagrammeR/PlantUML 的原因：字号、间距、线宽都要能对齐 mint 的
# 专业风格（细线、小字号、留白克制），外部布局引擎的默认样式改起来成本更高。

mint_register(mint_chart(
  id = "sequence",
  name = "时序图",
  english = "Sequence",
  category = "flow",
  description = "按时间顺序展示参与者之间的消息往返，支持返回虚线、自调用与备注",
  data_shape = paste(
    "{",
    "  \"participants\": [\"用户\", \"App\", \"服务端\"],",
    "  \"messages\": [",
    "    { \"from\": \"用户\", \"to\": \"App\", \"label\": \"提交订单\" },",
    "    { \"from\": \"App\", \"to\": \"服务端\", \"label\": \"创建订单\" },",
    "    { \"from\": \"服务端\", \"to\": \"App\", \"label\": \"订单号\", \"type\": \"dashed\" }",
    "  ],",
    "  \"notes\": [ { \"from\": \"App\", \"to\": \"服务端\", \"label\": \"同一事务内写入\" } ]",
    "}",
    "participants 可省略（按 messages 首次出现顺序推导）；type 为 dashed / return / reply 时画虚线返回。",
    sep = "\n"
  ),
  variants = c("solid 调用", "dashed 返回", "note 备注"),
  aliases = c("时序图", "顺序图", "序列图", "时序", "交互图", "uml时序", "sequence-diagram"),
  packages = c("ggplot2"),
  options = list(
    mint_option("number", "boolean", "是否给消息自动编号", default = FALSE),
    mint_option("labelSize", "number", "消息文字字号（pt）", default = 6.5),
    mint_option("noteSize", "number", "备注文字字号（pt）", default = 6.5),
    mint_option("boxWidth", "number", "参与者盒子宽度（相对列距）", default = 0.84),
    mint_option("lineWidth", "number", "消息箭头粗细（pt）", default = 0.45)
  ),
  example = list(
    data = list(
      participants = list("用户", "App", "订单服务", "支付网关"),
      messages = list(
        list(from = "用户", to = "App", label = "提交订单"),
        list(from = "App", to = "订单服务", label = "创建订单"),
        list(from = "订单服务", to = "App", label = "订单号", type = "dashed"),
        list(from = "App", to = "支付网关", label = "发起支付"),
        list(from = "支付网关", to = "App", label = "支付结果", type = "dashed"),
        list(from = "App", to = "用户", label = "下单成功", type = "dashed")
      ),
      notes = list(list(from = "订单服务", to = "支付网关", label = "同一事务内对账"))
    ),
    options = list(number = TRUE)
  ),
  render = function(ctx) {
    o <- ctx$options
    graph <- mint_sequence_model(ctx$data)
    n <- length(graph$participants)
    x_of <- stats::setNames(seq_len(n), graph$participants)

    box_width <- o$boxWidth %||% 0.84
    label_size <- (o$labelSize %||% ctx$style$type$data_label) / ggplot2::.pt
    note_size <- (o$noteSize %||% ctx$style$type$data_label) / ggplot2::.pt
    line_width <- (o$lineWidth %||% 0.45) / 2.13   # pt -> ggplot linewidth(mm)

    token_line <- ctx$style$tokens$axis
    dashed_colour <- "#6E6E6E"

    rects <- list(); segs <- list(); arrow_list <- list(); loops <- list(); texts <- list()
    add_rect <- function(xmin, xmax, ymin, ymax, fill, colour, lw) {
      rects[[length(rects) + 1L]] <<- data.frame(xmin = xmin, xmax = xmax, ymin = ymin,
                                                 ymax = ymax, fill = fill, colour = colour,
                                                 lw = lw, stringsAsFactors = FALSE)
    }
    add_seg <- function(x, xend, y, yend, colour, lw, linetype) {
      segs[[length(segs) + 1L]] <<- data.frame(x = x, xend = xend, y = y, yend = yend,
                                               colour = colour, lw = lw, linetype = linetype,
                                               stringsAsFactors = FALSE)
    }
    add_text <- function(x, y, label, size, colour, hjust = 0.5, vjust = 0.5, face = "plain") {
      texts[[length(texts) + 1L]] <<- data.frame(x = x, y = y, label = label, size = size,
                                                 colour = colour, hjust = hjust, vjust = vjust,
                                                 face = face, stringsAsFactors = FALSE)
    }

    box_y <- 1.0
    row_y <- -0.4
    step <- -1
    lifelines <- integer(0)

    # 1) 参与者盒子与生命线
    for (i in seq_len(n)) {
      half <- box_width / 2
      add_rect(i - half, i + half, box_y - 0.33, box_y + 0.33, "#FFFFFF", token_line, 0.45)
      add_text(i, box_y, graph$participants[[i]], ctx$style$type$axis_text / ggplot2::.pt,
               ctx$style$tokens$fg, face = "bold")
      add_seg(i, i, box_y - 0.33, 0, "#CFCFCF", 0.35, "solid")
      lifelines <- c(lifelines, length(segs))
    }
    bottom_lifeline <- 0

    # 2) 消息
    for (msg in graph$messages) {
      x_from <- x_of[[msg$from]]
      x_to <- x_of[[msg$to]]
      prefix <- if (isTRUE(o$number)) sprintf("%d. ", msg$index) else ""
      label <- paste0(prefix, msg$label)

      if (identical(msg$from, msg$to)) {
        w <- 0.28
        loops[[length(loops) + 1L]] <- data.frame(
          x = c(x_from, x_from + w, x_from + w, x_from),
          y = c(row_y, row_y, row_y - 0.36, row_y - 0.36)
        )
        if (nzchar(msg$label)) {
          add_text(x_from + w + 0.06, row_y - 0.18, label, label_size, ctx$text, hjust = 0, vjust = 0.5)
        }
      } else {
        dashed <- identical(msg$type, "dashed")
        arrow_list[[length(arrow_list) + 1L]] <- data.frame(
          x = x_from, xend = x_to, y = row_y, yend = row_y,
          colour = if (dashed) dashed_colour else token_line,
          lw = line_width, linetype = if (dashed) "dashed" else "solid",
          arrow_type = if (dashed) "open" else "closed", stringsAsFactors = FALSE
        )
        if (nzchar(msg$label)) {
          span <- abs(x_to - x_from)
          add_text((x_from + x_to) / 2, row_y + 0.14, label, label_size, ctx$text,
                   hjust = if (span < 1.1) 0 else 0.5, vjust = 0)
        }
      }
      bottom_lifeline <- row_y
      row_y <- row_y + step
    }

    # 3) 备注
    for (note in graph$notes) {
      x_from <- x_of[[note$from]]
      x_to <- if (is.null(note$to)) x_from else x_of[[note$to]]
      left <- min(x_from, x_to) - 0.44
      right <- max(x_from, x_to) + 0.44
      add_rect(left, right, row_y - 0.34, row_y + 0.16, "#F5F5F5", "#D5D5D5", 0.35)
      add_text(right - 0.12, row_y - 0.09, note$label, note_size, ctx$style$tokens$muted,
               hjust = 1, vjust = 0.5)
      bottom_lifeline <- row_y
      row_y <- row_y + step
    }

    # 生命线统一补到最底部
    for (i in lifelines) segs[[i]]$yend <- bottom_lifeline - 0.55

    p <- ggplot2::ggplot()
    rect_df <- do.call(rbind, rects)
    if (!is.null(rect_df)) {
      p <- p + ggplot2::geom_rect(
        data = rect_df,
        ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
        fill = rect_df$fill, colour = rect_df$colour, linewidth = rect_df$lw
      )
    }
    seg_df <- do.call(rbind, segs)
    if (!is.null(seg_df)) {
      p <- p + ggplot2::geom_segment(
        data = seg_df, ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
        colour = seg_df$colour, linewidth = seg_df$lw, linetype = seg_df$linetype
      )
    }
    arrow_df <- do.call(rbind, arrow_list)
    if (!is.null(arrow_df)) {
      for (kind in c("closed", "open")) {
        part <- arrow_df[arrow_df$arrow_type == kind, , drop = FALSE]
        if (nrow(part) == 0) next
        p <- p + ggplot2::geom_segment(
          data = part, ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
          colour = part$colour, linewidth = part$lw, linetype = part$linetype,
          arrow = ggplot2::arrow(length = grid::unit(1.8, "pt"), type = kind)
        )
      }
    }
    for (loop in loops) {
      p <- p + ggplot2::annotate(
        "path", x = loop$x, y = loop$y,
        colour = token_line, linewidth = line_width,
        arrow = ggplot2::arrow(length = grid::unit(1.8, "pt"), type = "closed")
      )
    }
    text_df <- do.call(rbind, texts)
    if (!is.null(text_df)) {
      p <- p + ggplot2::geom_text(
        data = text_df,
        ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust),
        size = text_df$size, colour = text_df$colour, fontface = text_df$face
      )
    }

    p +
      ggplot2::scale_x_continuous(limits = c(0.35, n + 0.65), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(bottom_lifeline - 0.6, box_y + 0.75), expand = c(0, 0)) +
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void(base_family = ctx$family) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = ctx$background, colour = NA),
        plot.margin = ggplot2::margin(0, 0, 0, 0)
      )
  }
))

#' 归一化时序图数据
mint_sequence_model <- function(data) {
  if (!is.list(data) || is.null(names(data))) {
    mint_fail("INVALID_DATA", "sequence 需要对象数据，收到数组",
              "形如 { \"participants\": [...], \"messages\": [...] }")
  }
  participants <- character(0)
  seen <- character(0)
  push <- function(id) {
    if (!id %in% seen) {
      seen <<- c(seen, id)
      participants <<- c(participants, id)
    }
  }

  if (length(data$participants) > 0) {
    for (item in data$participants) {
      push(as.character(if (is.list(item)) (item$id %||% item$name %||% item$label) else item))
    }
  }

  raw_messages <- data$messages %||% data$calls %||% list()
  if (length(raw_messages) == 0) {
    mint_fail("INVALID_DATA", "sequence 需要非空的 messages 数组",
              "形如 [{ \"from\": \"用户\", \"to\": \"App\", \"label\": \"提交订单\" }]")
  }

  messages <- list()
  for (i in seq_along(raw_messages)) {
    raw <- raw_messages[[i]]
    if (!is.list(raw)) mint_fail("INVALID_DATA", sprintf("messages 第 %d 项必须是对象", i))
    from <- raw$from %||% raw$source %||% raw$caller
    to <- raw$to %||% raw$target %||% raw$callee
    if (is.null(from) || is.null(to)) {
      mint_fail("INVALID_DATA", sprintf("messages 第 %d 项缺少 from / to", i),
                "形如 { \"from\": \"a\", \"to\": \"b\" }")
    }
    push(as.character(from)); push(as.character(to))
    type <- tolower(as.character(raw$type %||% "solid"))
    messages[[length(messages) + 1L]] <- list(
      index = i, from = as.character(from), to = as.character(to),
      label = as.character(raw$label %||% ""),
      type = if (type %in% c("dashed", "return", "reply", "response")) "dashed" else "solid"
    )
  }

  notes <- list()
  for (raw in data$notes %||% list()) {
    if (!is.list(raw)) next
    from <- raw$from %||% raw$participant
    if (is.null(from)) next
    to <- raw$to %||% from
    if (!as.character(from) %in% participants || !as.character(to) %in% participants) next
    notes[[length(notes) + 1L]] <- list(
      from = as.character(from), to = as.character(to),
      label = as.character(raw$label %||% raw$text %||% "")
    )
  }

  list(participants = participants, messages = messages, notes = notes,
       total_rows = length(messages) + length(notes))
}
