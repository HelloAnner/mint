# 日历热力图 calendar
#
# 为什么自己画而不用 ggcal：ggcal 只能画「一个完整的自然年」，
# 但真实数据常常是任意日期区间，而且它不给月份分块、不好控制格子间距。
# 这里按「周 × 星期」自己排布：
#   * 每列一周、每行一个星期几（周一在上、周日在最下），和纸质日历的读法一致；
#   * 月份按周分组，块与块之间插一个空列，让「一个月」在视觉上先成为一个整体；
#   * 没有数据的日期不画 —— 日历图上的空白本来就代表「这天没有记录」。

# 月份块之间的空列宽度（以格子宽为单位）
MINT_CALENDAR_GAP <- 0.6
# 格子的高宽比：略高于宽，行距才放得下 7pt 的星期文字
MINT_CALENDAR_CELL_RATIO <- 1.5

MINT_CALENDAR_WEEKDAYS <- c("周一", "周二", "周三", "周四", "周五", "周六", "周日")

# 内置示例：一年带季节节律与周末低谷的活跃度，让日历图不至于空着
mint_calendar_example_data <- local({
  dates <- seq(as.Date("2025-01-01"), as.Date("2025-12-31"), by = "day")
  n <- length(dates)
  idx <- seq_len(n)
  weekday <- as.integer(format(dates, "%u"))
  # 正弦做季节趋势 + 一个固定伪随机抖动；周末天然低一截
  seasonal <- sin((idx / n) * pi * 2 - 1.2) * 16 + 26
  wobble <- ((idx * 7919) %% 13) - 6
  weekend <- ifelse(weekday >= 6, -12, 6)
  value <- pmax(0, round(seasonal + wobble + weekend))
  lapply(which(value > 0), function(i) {
    list(day = format(dates[i], "%Y-%m-%d"), value = as.integer(value[i]))
  })
})

mint_register(mint_chart(
  id = "calendar",
  name = "日历热力图",
  english = "Calendar",
  category = "distribution",
  description = "按天着色，展示一整年的活跃度分布与周期性节律",
  data_shape = paste(
    "两种写法都支持：",
    "[ { \"day\": \"2025-01-15\", \"value\": 12 } ]",
    "{ \"2025-01-15\": 12 }",
    "from / to 可省略，会按数据里的最早/最晚日期自动确定范围。",
    sep = "\n"
  ),
  variants = c("calendar 日历", "year 整年"),
  # 一年 52 周天生是「宽条」：不给画布设一个宽扁的比例，格子就会被拉成细高条，
  # 读起来不像日历。aspect 只在用户没指定 --height 时生效，用户仍可自行覆盖。
  aspect = 4.5,
  aliases = c("日历图", "日历热力", "贡献图", "calendar", "github图"),
  packages = c("ggplot2", "scales"),
  options = list(
    mint_option("from", "string", "起始日期 YYYY-MM-DD"),
    mint_option("to", "string", "结束日期 YYYY-MM-DD"),
    mint_option("ramp", "string", "色阶调色板 id", default = "blue"),
    mint_option("reverse", "boolean", "色阶是否反向（浅=高）", default = FALSE),
    mint_option("monthLabel", "boolean", "是否显示月份标签", default = TRUE),
    mint_option("yearLegend", "boolean", "月份标签是否带上年份", default = TRUE),
    mint_option("valueFormat", "string", "数值格式", default = "number", values = c("number", "percent", "compact")),
    mint_option("decimals", "number", "小数位数"),
    mint_option("valuePrefix", "string", "数值前缀"),
    mint_option("valueSuffix", "string", "数值后缀")
  ),
  example = list(
    data = mint_calendar_example_data,
    options = list()
  ),
  render = function(ctx) {
    o <- ctx$options

    # --- 归一化成 (day, value) 两列 ---
    if (is.list(ctx$data) && !is.null(names(ctx$data))) {
      # {"2025-01-15": 12} 形式：只认数值项，其余（比如元信息）忽略
      vals <- vapply(ctx$data, function(v) is.numeric(v) && length(v) == 1, logical(1))
      if (!any(vals)) {
        mint_fail("INVALID_DATA", "calendar 的对象数据里没有数值项",
                  "形如 { \"2025-01-15\": 12, \"2025-01-16\": 8 }")
      }
      day <- names(ctx$data)[vals]
      value <- as.numeric(unlist(ctx$data[vals], use.names = FALSE))
    } else {
      rows <- mint_as_rows(ctx$data, "calendar")
      day_key <- intersect(c("day", "date", "x"), names(rows))[1]
      value_key <- intersect(c("value", "count", "y"), names(rows))[1]
      if (is.na(day_key) || is.na(value_key)) {
        mint_fail("INVALID_DATA", "calendar 需要 day（或 date）与 value 两个字段",
                  "形如 [{ \"day\": \"2025-01-15\", \"value\": 12 }]")
      }
      day <- as.character(rows[[day_key]])
      value <- suppressWarnings(as.numeric(rows[[value_key]]))
    }

    date <- as.Date(day, format = "%Y-%m-%d")
    # 日期解析不了就直说：静默丢掉「看不出是哪天」的记录只会让图少一块
    if (any(is.na(date))) {
      mint_fail("INVALID_DATA", sprintf("无法解析日期「%s」", day[which(is.na(date))[1]]),
                "日期必须是 YYYY-MM-DD，例如 2025-01-15")
    }
    if (all(is.na(value))) {
      mint_fail("INVALID_DATA", "calendar 的数值列里没有可用的数值",
                "每条形如 { \"day\": \"2025-01-15\", \"value\": 12 }")
    }
    date <- date[!is.na(value)]; value <- value[!is.na(value)]

    # 同一天出现多次就求和 —— 日历图问的是「这天发生了多少」
    agg <- stats::aggregate(list(value = value), by = list(date = date), FUN = sum)

    parse_day <- function(text, field) {
      if (is.null(text) || !nzchar(as.character(text)[1])) return(NULL)
      d <- as.Date(as.character(text)[1], format = "%Y-%m-%d")
      if (is.na(d)) {
        mint_fail("INVALID_DATA", sprintf("%s 不是合法日期：%s", field, text),
                  "用 YYYY-MM-DD，例如 2025-01-01")
      }
      d
    }
    from <- parse_day(o$from, "from") %||% min(agg$date)
    to <- parse_day(o$to, "to") %||% max(agg$date)
    if (to < from) {
      mint_fail("INVALID_DATA", "to 早于 from", "把 from / to 调成从小到大")
    }

    # --- 坐标网格：覆盖 from..to 的每一天（没有数据的那天只是不画格子）---
    # 一周从周一开始：把 from 所在周的周一当作第 0 列
    origin <- from - (as.integer(format(from, "%u")) - 1)
    grid <- data.frame(date = seq(from, to, by = "day"))
    grid$week <- as.integer(grid$date - origin) %/% 7
    # 每个整周归属到「它周一所在的月份」，跨月的零头周不会被劈成两半；
    # 区间开头那个不完整的周，其周一可能落在上个月，归到首月更符合直觉
    monday <- origin + grid$week * 7
    monday[monday < from] <- from
    grid$month_key <- format(monday, "%Y-%m")

    in_range <- agg$date >= from & agg$date <= to
    if (!any(in_range)) {
      mint_fail("INVALID_DATA", "from / to 指定的区间里没有任何数据",
                sprintf("数据落在 %s 到 %s 之间", format(min(agg$date)), format(max(agg$date))))
    }
    days <- agg[in_range, , drop = FALSE]
    days$wd <- as.integer(format(days$date, "%u"))    # 1 = 周一 … 7 = 周日

    months <- unique(grid$month_key[order(grid$week)])
    month_index <- match(grid$month_key, months)

    # 月份块之间插一个空列：越靠后的月份整体右移一点，
    # 于是「一个月」在视觉上先成为一个整体，而不是一片连续的色块
    grid$x <- grid$week - min(grid$week) + (month_index - 1) * MINT_CALENDAR_GAP
    days$x <- grid$x[match(days$date, grid$date)]

    legend <- !identical(o$legend, FALSE)
    show_month <- !identical(o$monthLabel, FALSE)

    # --- 版面：直接按英寸排，而不是让 ggplot 把数据范围拉伸到铺满面板 ---
    # 否则只有两三周数据时，格子会被拉成巨大的方块；这里先把格子定成
    # 「略高于宽、且宽高都放得下」的最大尺寸，再整体居中。
    left_in <- mint_text_width("周三", ctx$style$type$axis_text) / 72 + 0.04
    right_in <- if (legend) 0.66 else 0.02
    panel_w <- max(0.5, ctx$width - left_in - right_in)
    panel_h <- max(0.4, ctx$height - 0.04)
    label_h <- if (show_month) ctx$style$type$axis_text * 1.5 / 72 else 0

    ncol <- max(grid$x) - min(grid$x) + 1
    # 格子略高于宽：一周一行要放得下 7pt 的星期文字，正方形会把行距压得太紧
    cell_w <- min(panel_w / ncol, (panel_h - label_h) / (length(MINT_CALENDAR_WEEKDAYS) * MINT_CALENDAR_CELL_RATIO))
    cell_h <- cell_w * MINT_CALENDAR_CELL_RATIO
    block_w <- ncol * cell_w
    block_h <- length(MINT_CALENDAR_WEEKDAYS) * cell_h
    ox <- (panel_w - block_w) / 2
    oy <- (panel_h - label_h - block_h) / 2

    tiles <- data.frame(
      x = ox + (days$x - min(grid$x) + 0.5) * cell_w,
      y = oy + (7 - days$wd + 0.5) * cell_h,   # 周一在最上
      value = days$value
    )

    # 月份标签：排在顶部，对齐该月第一列
    month_df <- do.call(rbind, lapply(seq_along(months), function(i) {
      sel <- grid$month_key == months[i]
      first <- as.Date(paste0(months[i], "-01"), format = "%Y-%m-%d")
      year <- as.integer(format(first, "%Y"))
      month <- as.integer(format(first, "%m"))
      # 一年之内的日历只写「3月」；跨年时才把年份带上，免得 1 月出现两次分不清
      label <- if (!identical(o$yearLegend, FALSE) && (i == 1L || month == 1L)) {
        sprintf("%d年%d月", year, month)
      } else {
        sprintf("%d月", month)
      }
      data.frame(x = ox + (min(grid$x[sel]) - min(grid$x)) * cell_w, label = label, stringsAsFactors = FALSE)
    }))

    fmt <- ctx$formatter
    p <- ggplot2::ggplot(tiles, ggplot2::aes(x = x, y = y, fill = value)) +
      # 用背景色描边而不是画边框：格子之间只剩一圈极细的白缝，色块读起来是连续的
      ggplot2::geom_tile(width = cell_w, height = cell_h,
                         colour = ctx$background, linewidth = ctx$style$geoms$tile_border)

    if (show_month) {
      p <- p + ggplot2::geom_text(
        data = month_df, ggplot2::aes(x = x, y = oy + block_h + 0.03, label = label),
        inherit.aes = FALSE, hjust = 0, vjust = 0,
        size = ctx$style$type$axis_text / ggplot2::.pt, colour = ctx$text
      )
    }

    p +
      # 留一点点余量：格子正好压在坐标轴边界上时会被判成“超出范围”而被丢掉
      ggplot2::scale_x_continuous(breaks = NULL, limits = c(-0.02, panel_w + 0.02), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(
        breaks = oy + (6.5 - (0:6)) * cell_h, labels = MINT_CALENDAR_WEEKDAYS,
        limits = c(-0.02, panel_h + 0.02), expand = c(0, 0)
      ) +
      ggplot2::labs(x = NULL, y = NULL) +
      mint_theme(ctx$style, ctx$family, grid = "none",
                 legend_position = if (legend) "right" else "none") +
      mint_scale_fill_continuous(o$ramp %||% "blue", isTRUE(o$reverse),
                                 name = NULL, labels = fmt) +
      # 右侧图例要一条竖着的细色条，而不是默认的横条
      ggplot2::guides(fill = if (legend) {
        ggplot2::guide_colourbar(barwidth = grid::unit(5, "pt"), barheight = grid::unit(52, "pt"),
                                 frame.colour = NA, ticks.colour = "#BDBDBD")
      } else "none") +
      ggplot2::theme(
        axis.line = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_blank(),
        legend.margin = ggplot2::margin(0, 0, 0, 6)
      )
  }
))
