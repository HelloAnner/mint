# 数据整形与格式化的小工具。
#
# 所有图表都通过这些函数把 JSON 归一化成 R 对象，
# 保证「同一个输入在 23 张图上语义一致」，错误提示也统一。

#' 数值/文本格式化：千分位、小数位、前后缀、紧凑计数
#'
#' @param x 数值向量
#' @param decimals 固定小数位；NULL 表示整数用千分位、非整数保留有效位
#' @param prefix,suffix 前后缀
#' @param compact TRUE 时把 12000 压成 12k
mint_format_number <- function(x, decimals = NULL, prefix = "", suffix = "", compact = FALSE) {
  if (length(x) == 0) return(character(0))
  fmt <- function(v) {
    if (is.na(v)) return("–")
    if (is.infinite(v)) return(if (v > 0) "∞" else "-∞")
    if (compact) {
      a <- abs(v)
      if (a >= 1e9) return(paste0(mint_trim(v / 1e9), "B"))
      if (a >= 1e6) return(paste0(mint_trim(v / 1e6), "M"))
      if (a >= 1e3) return(paste0(mint_trim(v / 1e3), "k"))
    }
    if (!is.null(decimals)) {
      return(formatC(v, format = "f", digits = decimals, big.mark = ","))
    }
    if (abs(v - round(v)) < 1e-9) {
      return(formatC(round(v), format = "d", big.mark = ","))
    }
    mint_trim(v)
  }
  paste0(prefix, vapply(x, fmt, character(1), USE.NAMES = FALSE), suffix)
}

#' 去掉浮点尾巴：1.50 -> 1.5，1.0 -> 1
mint_trim <- function(v, digits = 3) {
  out <- formatC(v, format = "f", digits = digits)
  out <- sub("0+$", "", out)
  sub("\\.$", "", out)
}

#' 按选项构造格式化函数
mint_formatter <- function(options = list()) {
  preset <- options$valueFormat %||% "number"
  decimals <- options$decimals
  prefix <- options$valuePrefix %||% ""
  suffix <- options$valueSuffix %||% ""
  compact <- identical(preset, "compact")
  force(prefix); force(suffix); force(decimals); force(compact)
  function(x) {
    if (identical(preset, "percent")) {
      return(mint_format_number(x * 100, decimals = decimals %||% 1, prefix = prefix, suffix = paste0(suffix, "%")))
    }
    mint_format_number(x, decimals = decimals, prefix = prefix, suffix = suffix, compact = compact)
  }
}

#' 缺省值运算符
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

#' 文本显示宽度：全角按 1.0 em、半角按 0.52 em 估算
#'
#' 这两个系数是量出来的，不是猜的：PingFang/Noto Sans CJK 下全角字元宽度 ≈ 字号本身，
#' 拉丁字母与小写数字平均 ≈ 0.52 em。早先按「全角 = 1.86」估会多留近一倍的空白，
#' 自绘图形（流程图/漏斗/架构图）会因此被挤出版心。
#'
#' 向量化：传多个字符串返回等长向量（传多行文本取 max 就是最宽行）。
mint_text_width <- function(text, size = 7) {
  if (length(text) == 0) return(numeric(0))
  vapply(text, function(value) {
    chars <- strsplit(as.character(value), "")[[1]]
    if (length(chars) == 0) return(0)
    wide <- grepl("[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFF60\uFFE0-\uFFE6]", chars)
    sum(ifelse(wide, 1, 0.52)) * size
  }, numeric(1), USE.NAMES = FALSE)
}

#' 超长文本截断（按显示宽度）
mint_ellipsize <- function(text, max_width, size = 7) {
  vapply(text, function(t) {
    if (mint_text_width(t, size) <= max_width) return(t)
    chars <- strsplit(t, "")[[1]]
    out <- ""
    for (ch in chars) {
      if (mint_text_width(paste0(out, ch, "…"), size) > max_width) break
      out <- paste0(out, ch)
    }
    paste0(out, "…")
  }, character(1), USE.NAMES = FALSE)
}

#' 按显示宽度折行（尽量在空格或标点处断开）
mint_wrap <- function(text, max_width, size = 7) {
  vapply(text, function(t) {
    if (mint_text_width(t, size) <= max_width) return(t)
    lines <- character(0)
    cur <- ""
    for (ch in strsplit(t, "")[[1]]) {
      if (mint_text_width(paste0(cur, ch), size) > max_width && nzchar(cur)) {
        lines <- c(lines, cur)
        cur <- ch
      } else {
        cur <- paste0(cur, ch)
      }
    }
    if (nzchar(cur)) lines <- c(lines, cur)
    paste(lines, collapse = "\n")
  }, character(1), USE.NAMES = FALSE)
}

#' 颜色：与白色按比例混合（amount = 1 为原色），用于生成同色系浅色
#'
#' 两个参数都会按需循环：mint_tint("#E64B35", c(0.2, 0.4)) 与
#' mint_tint(c("#E64B35", "#4DBBD5"), 0.2) 都成立。
mint_tint <- function(hex, amount) {
  n <- max(length(hex), length(amount))
  hex <- rep(hex, length.out = n)
  amount <- rep(amount, length.out = n)
  vapply(seq_len(n), function(i) {
    rgb <- grDevices::col2rgb(hex[i]) / 255
    mixed <- 1 - (1 - rgb) * amount[i]
    grDevices::rgb(mixed[1], mixed[2], mixed[3])
  }, character(1), USE.NAMES = FALSE)
}

#' 由主色生成浅->深的顺序色阶
mint_ramp <- function(color, steps = 7, from = 0.12, to = 1) {
  mint_tint(rep(color[1], steps), seq(from, to, length.out = steps))
}

#' 两个颜色的线性插值（t = 0 返回 a），三个参数都会按需循环
mint_mix <- function(a, b, t) {
  n <- max(length(a), length(b), length(t))
  a <- rep(a, length.out = n); b <- rep(b, length.out = n); t <- rep(t, length.out = n)
  vapply(seq_len(n), function(i) {
    ca <- grDevices::col2rgb(a[i]) / 255
    cb <- grDevices::col2rgb(b[i]) / 255
    m <- ca + (cb - ca) * t[i]
    grDevices::rgb(m[1], m[2], m[3])
  }, character(1), USE.NAMES = FALSE)
}

#' 生成连续的顺序色阶函数（用于热力图、日历图）
mint_seq_palette <- function(colors, domain = NULL) {
  force(colors)
  function(x) {
    if (is.null(domain)) domain <<- range(x, na.rm = TRUE)
    if (diff(domain) == 0) return(rep(colors[length(colors)], length(x)))
    t <- (x - domain[1]) / diff(domain)
    t <- pmin(pmax(t, 0), 1)
    n <- length(colors) - 1
    idx <- t * n
    lo <- floor(idx) + 1
    hi <- pmin(lo + 1, length(colors))
    frac <- idx - floor(idx)
    vapply(seq_along(x), function(i) mint_mix(colors[lo[i]], colors[hi[i]], frac[i]), character(1))
  }
}
